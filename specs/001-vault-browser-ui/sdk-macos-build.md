# Building BitwardenFFI.xcframework with macOS Support

> **STATUS: ARCHIVED — Not used in v1.**
>
> This document is preserved for historical reference and in case a future version
> migrates to the official `sdk-swift` package.
>
> **Why archived**: `bitwarden/sdk-internal` (which contains the UniFFI Swift bindings
> and `build.sh`) is a private Bitwarden repository and is not accessible. The public
> `bitwarden/sdk` repo has no `bitwarden-uniffi` crate. The official `sdk-swift` release
> ships an iOS-only XCFramework with no macOS slice.
>
> **Current approach**: Native Bitwarden crypto implemented using CommonCrypto + CryptoKit
> + Security.framework + `swift-argon2` (Argon2id only), wrapped behind a
> `BitwardenCryptoService` protocol in the Data layer. See `research.md §1` and
> `CONSTITUTION.md §III`.
>
> **Revisit trigger**: If Bitwarden officially packages a macOS slice of
> `BitwardenFFI.xcframework` in a future `sdk-swift` release, migrating to the SDK
> SHOULD be evaluated. The `BitwardenCryptoService` protocol boundary makes the swap
> straightforward — only `BitwardenCryptoServiceImpl` would need to change.

---

## Original Steps (Preserved for Reference)

The steps below were written assuming access to `sdk-internal`. They are retained here
because they document the correct approach for building a macOS slice if access becomes
available, and may be useful as the basis for an upstream PR to `bitwarden/sdk-swift`.

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

```bash
# Requires sdk-internal access (private Bitwarden repository)
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

---

## Step 4 — Patch `Package.swift` to declare macOS platform

```swift
platforms: [
    .macOS(.v13),
    .iOS(.v16),
],
```

---

## Step 5 — Build

```bash
# From crates/bitwarden-uniffi/swift/
./build.sh
```

Expected output structure:

```
BitwardenFFI.xcframework/
├── Info.plist
├── ios-arm64/
├── ios-arm64_x86_64-simulator/
└── macos-arm64_x86_64/          ← new
```

Verify the macOS slice:

```bash
lipo -info BitwardenFFI.xcframework/macos-arm64_x86_64/BitwardenFFI.framework/BitwardenFFI
# Expected: Architectures in the fat file: ... are: x86_64 arm64
```

---

## Step 6 — Fork `sdk-swift` and point it to the new XCFramework

Fork `bitwarden/sdk-swift`, copy in the new XCFramework, update `Package.swift` to use a
local `.binaryTarget(name:path:)` pointing to the built framework, then push.

---

## Step 7 — Open the upstream PR

Key points for the PR description:
- The Rust core already supports macOS targets — this is purely a packaging change
- `IPHONEOS_DEPLOYMENT_TARGET` is scoped to iOS; macOS builds use `MACOSX_DEPLOYMENT_TARGET`
- The Swift bindings generated by uniffi-bindgen are platform-agnostic — no regeneration needed
- `DeviceType.macOsDesktop` already exists in the SDK — clear signal of intended macOS support
- Other community macOS Bitwarden clients currently roll their own crypto because the SDK
  doesn't package macOS — merging this removes that incentive
