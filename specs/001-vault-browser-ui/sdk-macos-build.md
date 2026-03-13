# Building BitwardenFFI.xcframework with macOS Support

**Why**: `bitwarden/sdk-swift` ships iOS slices only. A native macOS app needs a macOS slice.
**Effort**: ~1–2 hours first time; fully scriptable after that.
**Result**: A drop-in `BitwardenFFI.xcframework` that works in both iOS and macOS SPM targets.

---

## Prerequisites

```bash
# Rust toolchain (install via https://rustup.rs if not present)
rustup --version   # need 1.75+

# macOS build tools
xcode-select --install   # if not already installed
xcodebuild -version      # need Xcode 15+
```

---

## Step 1 — Clone the SDK source

The build scripts live in `bitwarden/sdk-internal` (not the public `bitwarden/sdk`).
If you only have access to the public repo, it also works — the `build.sh` structure is identical.

```bash
# Option A: public repo
git clone https://github.com/bitwarden/sdk.git bitwarden-sdk
cd bitwarden-sdk

# Option B: sdk-internal (if you have access)
git clone https://github.com/bitwarden/sdk-internal.git bitwarden-sdk
cd bitwarden-sdk
```

---

## Step 2 — Install all required Rust targets

```bash
# Existing iOS targets (already in the build script)
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# New macOS targets
rustup target add aarch64-apple-darwin   # Apple Silicon Mac
rustup target add x86_64-apple-darwin    # Intel Mac
```

---

## Step 3 — Patch `build.sh` to add the macOS slice

The build script is at `crates/bitwarden-uniffi/swift/build.sh`.

Apply this diff:

```diff
--- a/crates/bitwarden-uniffi/swift/build.sh
+++ b/crates/bitwarden-uniffi/swift/build.sh
@@ -10,6 +10,7 @@
 # Build native library
 export IPHONEOS_DEPLOYMENT_TARGET="13.0"
+export MACOSX_DEPLOYMENT_TARGET="13.0"
 export RUSTFLAGS="-C link-arg=-Wl,-application_extension"
 if [[ $DEBUG_MODE = "true" ]]; then
   PROFILE="debug"
@@ -20,9 +20,15 @@
 cargo build --package bitwarden-uniffi --target aarch64-apple-ios-sim $PROFILE_FLAG
 cargo build --package bitwarden-uniffi --target aarch64-apple-ios $PROFILE_FLAG
 cargo build --package bitwarden-uniffi --target x86_64-apple-ios $PROFILE_FLAG
+cargo build --package bitwarden-uniffi --target aarch64-apple-darwin $PROFILE_FLAG
+cargo build --package bitwarden-uniffi --target x86_64-apple-darwin $PROFILE_FLAG

 mkdir -p tmp/target/universal-ios-sim/$PROFILE
+mkdir -p tmp/target/universal-macos/$PROFILE

 # Create universal libraries
 lipo -create ../../../target/aarch64-apple-ios-sim/$PROFILE/libbitwarden_uniffi.a \
   ../../../target/x86_64-apple-ios/$PROFILE/libbitwarden_uniffi.a \
   -output ./tmp/target/universal-ios-sim/$PROFILE/libbitwarden_uniffi.a

+lipo -create ../../../target/aarch64-apple-darwin/$PROFILE/libbitwarden_uniffi.a \
+  ../../../target/x86_64-apple-darwin/$PROFILE/libbitwarden_uniffi.a \
+  -output ./tmp/target/universal-macos/$PROFILE/libbitwarden_uniffi.a

 # Generate swift bindings (unchanged — uses iOS sim dylib)
 cargo run -p uniffi-bindgen generate \
@@ -40,6 +52,9 @@
 xcodebuild -create-xcframework \
   -library ../../../target/aarch64-apple-ios/$PROFILE/libbitwarden_uniffi.a \
   -headers ./tmp/Headers \
   -library ./tmp/target/universal-ios-sim/$PROFILE/libbitwarden_uniffi.a \
   -headers ./tmp/Headers \
+  -library ./tmp/target/universal-macos/$PROFILE/libbitwarden_uniffi.a \
+  -headers ./tmp/Headers \
   -output ./BitwardenFFI.xcframework
```

Or apply it directly:

```bash
cd crates/bitwarden-uniffi/swift

# Make a backup
cp build.sh build.sh.orig

# Apply the patch
patch -p4 << 'PATCH'
--- a/crates/bitwarden-uniffi/swift/build.sh
+++ b/crates/bitwarden-uniffi/swift/build.sh
@@ -10,6 +10,7 @@ cd "$(dirname "$0")"
 # Build native library
 export IPHONEOS_DEPLOYMENT_TARGET="13.0"
+export MACOSX_DEPLOYMENT_TARGET="13.0"
 export RUSTFLAGS="-C link-arg=-Wl,-application_extension"
 if [[ $DEBUG_MODE = "true" ]]; then
   PROFILE="debug"
@@ -20,8 +21,14 @@ fi
 cargo build --package bitwarden-uniffi --target aarch64-apple-ios-sim $PROFILE_FLAG
 cargo build --package bitwarden-uniffi --target aarch64-apple-ios $PROFILE_FLAG
 cargo build --package bitwarden-uniffi --target x86_64-apple-ios $PROFILE_FLAG
+cargo build --package bitwarden-uniffi --target aarch64-apple-darwin $PROFILE_FLAG
+cargo build --package bitwarden-uniffi --target x86_64-apple-darwin $PROFILE_FLAG

 mkdir -p tmp/target/universal-ios-sim/$PROFILE
+mkdir -p tmp/target/universal-macos/$PROFILE

 # Create universal libraries
 lipo -create ../../../target/aarch64-apple-ios-sim/$PROFILE/libbitwarden_uniffi.a \
   ../../../target/x86_64-apple-ios/$PROFILE/libbitwarden_uniffi.a \
   -output ./tmp/target/universal-ios-sim/$PROFILE/libbitwarden_uniffi.a

+lipo -create ../../../target/aarch64-apple-darwin/$PROFILE/libbitwarden_uniffi.a \
+  ../../../target/x86_64-apple-darwin/$PROFILE/libbitwarden_uniffi.a \
+  -output ./tmp/target/universal-macos/$PROFILE/libbitwarden_uniffi.a

 # Generate swift bindings
 cargo run -p uniffi-bindgen generate \
   ../../../target/aarch64-apple-ios-sim/$PROFILE/libbitwarden_uniffi.dylib \
@@ -40,6 +47,8 @@ xcodebuild -create-xcframework \
   -library ../../../target/aarch64-apple-ios/$PROFILE/libbitwarden_uniffi.a \
   -headers ./tmp/Headers \
   -library ./tmp/target/universal-ios-sim/$PROFILE/libbitwarden_uniffi.a \
   -headers ./tmp/Headers \
+  -library ./tmp/target/universal-macos/$PROFILE/libbitwarden_uniffi.a \
+  -headers ./tmp/Headers \
   -output ./BitwardenFFI.xcframework
PATCH
```

---

## Step 4 — Patch `Package.swift` to declare macOS platform

```bash
# File: crates/bitwarden-uniffi/swift/Package.swift
sed -i '' 's/platforms: \[/platforms: [\n        .macOS(.v13),/' Package.swift
```

Verify the result looks like:

```swift
platforms: [
    .macOS(.v13),
    .iOS(.v13),
],
```

---

## Step 5 — Build

```bash
# From crates/bitwarden-uniffi/swift/
./build.sh
```

This takes 5–15 minutes on first run (Rust compiles 5 targets). Subsequent builds are faster
due to incremental compilation.

**Expected output**:

```
BitwardenFFI.xcframework/
├── Info.plist
├── ios-arm64/
│   └── BitwardenFFI.framework/
├── ios-arm64_x86_64-simulator/
│   └── BitwardenFFI.framework/
└── macos-arm64_x86_64/          ← new
    └── BitwardenFFI.framework/
```

**Verify the macOS slice**:

```bash
lipo -info BitwardenFFI.xcframework/macos-arm64_x86_64/BitwardenFFI.framework/BitwardenFFI
# Expected: Architectures in the fat file: ... are: x86_64 arm64
```

---

## Step 6 — Fork `sdk-swift` and point it to the new XCFramework

```bash
# 1. Fork https://github.com/bitwarden/sdk-swift on GitHub, then:
git clone https://github.com/YOUR_USERNAME/sdk-swift.git
cd sdk-swift

# 2. Copy in the new XCFramework and updated Swift sources
cp -R /path/to/bitwarden-sdk/crates/bitwarden-uniffi/swift/BitwardenFFI.xcframework .
cp /path/to/bitwarden-sdk/crates/bitwarden-uniffi/swift/Sources/BitwardenSdk/*.swift \
   Sources/BitwardenSdk/

# 3. Update Package.swift — local path (for development)
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BitwardenSdk",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "BitwardenSdk",
            targets: ["BitwardenSdk", "BitwardenFFI"]),
    ],
    targets: [
        .target(
            name: "BitwardenSdk",
            dependencies: ["BitwardenFFI"],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]),
        .testTarget(
            name: "BitwardenSdkTests",
            dependencies: ["BitwardenSdk"]),
        .binaryTarget(name: "BitwardenFFI", path: "BitwardenFFI.xcframework")
    ]
)
EOF

# 4. Commit and push to your fork
git add -A
git commit -m "feat: add macOS platform support (arm64 + x86_64)"
git push
```

---

## Step 7 — Point your Bitwarden macOS app to the fork

In Xcode:
1. **File → Add Package Dependencies**
2. Enter your fork URL: `https://github.com/YOUR_USERNAME/sdk-swift`
3. Set the branch to `main` (or pin to the commit you pushed)
4. Replace any existing `BitwardenSdk` reference

Or in a local `Package.swift` if you're using SPM for the app:

```swift
.package(url: "https://github.com/YOUR_USERNAME/sdk-swift", branch: "main"),
```

---

## Step 8 — Open the upstream PR

```bash
# In your sdk-swift fork, open a PR to bitwarden/sdk-swift
# In your sdk (or sdk-internal) fork, open a PR with the build.sh + Package.swift changes
gh pr create \
  --repo bitwarden/sdk-swift \
  --title "feat: add macOS platform support" \
  --body "Adds macOS arm64 + x86_64 slices to BitwardenFFI.xcframework and declares .macOS(.v13) in Package.swift. Enables native macOS Bitwarden clients to use the official SDK without Mac Catalyst."
```

---

## Troubleshooting

**`error: cannot find -lbitwarden_uniffi`**
→ Make sure the `cargo build` step completed for both macOS targets before running `lipo`.
Run `ls ../../../target/aarch64-apple-darwin/release/` to confirm `libbitwarden_uniffi.a` exists.

**`XCFramework: could not find a slice for the current platform`**
→ Clean DerivedData (`⌘⇧K` in Xcode, or `rm -rf ~/Library/Developer/Xcode/DerivedData`), then re-resolve packages.

**`uniffi-bindgen: dylib not found`**
→ The Swift binding generation uses the iOS Simulator dylib — it does not need to be re-run for macOS. The generated `.swift` and `.h` files are platform-agnostic; same bindings work for iOS and macOS.

**`Sandbox: deny(1) file-read`** at runtime
→ Check App Sandbox entitlements. The SDK uses in-memory operations only; no extra entitlements needed for the SDK itself.

---

## Notes for the upstream PR

Key points to include in the PR description:
- The Rust core already supports macOS targets — this is purely a packaging change
- `IPHONEOS_DEPLOYMENT_TARGET` env var is scoped to iOS builds only; macOS builds use `MACOSX_DEPLOYMENT_TARGET`
- The Swift bindings (generated by uniffi-bindgen) are platform-agnostic — no regeneration needed for macOS
- `DeviceType.macOsDesktop` already exists in the SDK — clear signal of intended macOS support
- Other community macOS Bitwarden clients (e.g. Swiftwarden) currently roll their own crypto because the SDK doesn't package macOS — merging this PR removes that incentive
