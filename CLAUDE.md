# Bitwarden macOS Development Guidelines

Auto-generated from feature plans. Last updated: 2026-03-15
Constitution: [CONSTITUTION.md](CONSTITUTION.md) (v1.4.0)

## Active Technologies
- Swift 5.10 (latest stable) + SwiftUI, CommonCrypto, CryptoKit, Security.framework, `Argon2Swift` 1.0.1-bw2 (local vendored at `LocalPackages/Argon2Swift/`) (001-vault-browser-ui)
- macOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), UserDefaults (UI prefs), in-memory (decrypted vault) (001-vault-browser-ui)

- **Language**: Swift 5.10 (latest stable)
- **UI Framework**: SwiftUI (`NavigationSplitView` for three-pane layout)
- **Concurrency**: Swift async/await + Structured Concurrency
- **Platform**: macOS 14 (Sonoma) + macOS 13 (Ventura, n-1)
- **Project type**: macOS desktop app (App Sandbox + Hardened Runtime)
- **Crypto/Vault**: CommonCrypto + CryptoKit + Security.framework + `Argon2Swift` (Argon2id only) — Data layer only, behind `BitwardenCryptoService` protocol. sdk-swift has no macOS slice.
- **Storage**: macOS Keychain (secrets), UserDefaults (UI prefs), in-memory (decrypted vault)
- **Networking**: `URLSession` (no third-party networking library)
- **Testing**: XCTest (unit + integration), XCUITest (UI journeys)
- **Logging**: `os.Logger` with subsystem `com.bitwarden-macos`

## Project Structure

```text
Bitwarden_MacOS/
├── Bitwarden_MacOS.xcodeproj/
└── Bitwarden_MacOS/
    ├── App/            # @main, AppContainer (DI), Config
    ├── Domain/         # Pure Swift: Entities, UseCases, Repository protocols
    ├── Data/           # Crypto, Network, Keychain, Repository impls, Mappers
    ├── Presentation/   # SwiftUI Views + ViewModels
    └── Tests/          # DomainTests/, DataTests/, UITests/

specs/
└── 001-vault-browser-ui/
    ├── spec.md         # Feature specification
    ├── plan.md         # Implementation plan (this feature)
    ├── research.md     # Phase 0 research findings
    ├── data-model.md   # Domain entity definitions
    ├── quickstart.md   # Developer setup guide
    └── contracts/      # Repository protocol specs
```

## Commands

```bash
# Open project
open "Bitwarden MacOS/Bitwarden MacOS.xcodeproj"

# Build
xcodebuild -project "Bitwarden MacOS/Bitwarden MacOS.xcodeproj" \
           -scheme "Bitwarden MacOS" -configuration Debug build

# Run all tests
xcodebuild test \
  -project "Bitwarden MacOS/Bitwarden MacOS.xcodeproj" \
  -scheme "Bitwarden MacOS" \
  -destination "platform=macOS"
```

## Architecture Rules

1. **Domain layer** — `import Foundation` only. No crypto imports, no `SwiftUI`, no `AppKit`.
2. **Data layer** — Only place that imports CommonCrypto, CryptoKit, Security, or `Argon2Swift`.
   All crypto behind `BitwardenCryptoService` protocol. Translate types to Domain entities via
   mappers in `Data/Mappers/`.
3. **Presentation layer** — Only place that imports `SwiftUI`. Uses Domain use cases; never
   imports Data layer or crypto modules directly.
4. **TDD enforced** — Write failing test before writing implementation. Domain use cases and
   Data mappers require unit tests. Critical UI journeys require XCUITest.
5. **No swallowed errors** — Every `catch {}` must either rethrow or log + surface to Presentation
   via a typed `Error`.

## Code Style (Swift)

- `async/await` for all async code — no callbacks or Combine publishers in new code
- `struct` over `class` for Domain entities (value semantics)
- `actor` for shared mutable state in Data layer (e.g. `FaviconLoader`)
- `protocol` + `impl` naming: protocol = `AuthRepository`, impl = `AuthRepositoryImpl`
- Constants in `enum` namespaces, not loose `let` at file scope
- `os.Logger` levels: `.debug` trace, `.info` normal flow, `.error` recoverable, `.fault` unrecoverable
- Secrets MUST NOT appear in log output

## Recent Changes
- 001-vault-browser-ui: Added Swift 5.10 (latest stable) + SwiftUI, CommonCrypto, CryptoKit, Security.framework, `Argon2Swift` 1.0.1-bw2 (local vendored at `LocalPackages/Argon2Swift/`)

### 001-vault-browser-ui (2026-03-15)
Added: full project scaffold, three-pane vault browser, login/unlock flows, search.
Technologies introduced: native Bitwarden crypto (CommonCrypto + CryptoKit + Argon2Swift),
`NavigationSplitView`, macOS Keychain integration.
Note: sdk-swift rejected (iOS-only XCFramework); native crypto adopted per CONSTITUTION.md §III.

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
