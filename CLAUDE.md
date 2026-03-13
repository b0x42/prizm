# Bitwarden macOS Development Guidelines

Auto-generated from feature plans. Last updated: 2026-03-13

## Active Technologies

- **Language**: Swift 5.10 (latest stable)
- **UI Framework**: SwiftUI (`NavigationSplitView` for three-pane layout)
- **Concurrency**: Swift async/await + Structured Concurrency
- **Platform**: macOS 14 (Sonoma) + macOS 13 (Ventura, n-1)
- **Project type**: macOS desktop app (App Sandbox + Hardened Runtime)
- **Crypto/Vault**: `BitwardenSdk` (sdk-swift) — SPM binary target; Data layer only
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
    ├── Data/           # SDK wrapper, Network, Keychain, Repository impls, Mappers
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
open Bitwarden_MacOS/Bitwarden_MacOS.xcodeproj

# Build
xcodebuild -project Bitwarden_MacOS/Bitwarden_MacOS.xcodeproj \
           -scheme "Bitwarden MacOS" -configuration Debug build

# Run all tests
xcodebuild test \
  -project Bitwarden_MacOS/Bitwarden_MacOS.xcodeproj \
  -scheme "Bitwarden MacOS" \
  -destination "platform=macOS"

# Verify BitwardenSdk macOS slice (run after SPM resolves)
lipo -info <path-to>/BitwardenSdk.xcframework/macos-arm64_x86_64/BitwardenSdk.framework/BitwardenSdk
```

## Architecture Rules

1. **Domain layer** — `import Foundation` only. No `BitwardenSdk`, no `SwiftUI`, no `AppKit`.
2. **Data layer** — Only place that imports `BitwardenSdk`. Translate all SDK types to Domain
   entities at the Data/Domain boundary via mappers in `Data/Mappers/`.
3. **Presentation layer** — Only place that imports `SwiftUI`. Uses Domain use cases; never
   imports Data layer or `BitwardenSdk`.
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

### 001-vault-browser-ui (2026-03-13)
Added: full project scaffold, three-pane vault browser, login/unlock flows, search.
Technologies introduced: `BitwardenSdk`, `NavigationSplitView`, macOS Keychain integration.

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
