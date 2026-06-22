# Prizm Development Guidelines

**Constitution: [CONSTITUTION.md](CONSTITUTION.md) (v1.4.0) — READ THIS FIRST.**
The Constitution defines seven non-negotiable principles that govern every decision in this
codebase: Native-First (SwiftUI only), Clean Architecture (strict layer boundaries), Security-First
(vetted crypto only, no hand-rolled algorithms), TDD (Red→Green→Refactor, no exceptions),
Observability (no silent failures), Simplicity/YAGNI, and Radical Transparency (all crypto must be
publicly auditable). Before implementing any feature, adding a dependency, or making an
architectural decision, consult the Constitution. Violations are blocking PR rejections.

## Active Technologies

- **Language**: Swift 6.2 (Swift 6 language mode)
- **UI Framework**: SwiftUI (`NavigationSplitView` for three-pane layout)
- **Concurrency**: Swift async/await + Structured Concurrency
- **Platform**: macOS 26+
- **Project type**: macOS desktop app (App Sandbox + Hardened Runtime)
- **Crypto/Vault**: CommonCrypto + CryptoKit + Security.framework + `Argon2Swift` (Argon2id only) — Data layer only, behind `BitwardenCryptoService` protocol.
- **Storage**: macOS Keychain (secrets), UserDefaults (UI prefs), in-memory (decrypted vault)
- **Networking**: `URLSession` (no third-party networking library)
- **Testing**: XCTest (unit + integration), XCUITest (UI journeys)
- **Logging**: `os.Logger` with subsystem `com.prizm`

## Project Structure

```text
Prizm/
├── Prizm.xcodeproj/
├── App/                # @main, AppContainer (DI), Config
├── Domain/             # Entities, UseCase protocols, Repository protocols, Utilities
├── Data/               # Crypto, Network, Keychain, Repository impls, UseCase impls, Mappers
├── Presentation/       # SwiftUI Views, ViewModels, Components
├── PrizmTests/     # Unit + integration tests (XCTest)
└── Tests/UITests/      # UI journey tests (XCUITest)

openspec/
├── changes/            # Active and archived change specs (one dir per feature)
└── specs/              # Approved specs awaiting or under implementation
```

## Setup

**Team ID required:** Always ask the user for their Apple Developer Team ID before running any build or test command. The build will fail without `Prizm/LocalConfig.xcconfig` containing a valid `DEVELOPMENT_TEAM`. See `DEVELOPMENT.md` for full setup instructions.

## Commands

```bash
# Open project
open "Prizm/Prizm.xcodeproj"

# Build
xcodebuild -project "Prizm/Prizm.xcodeproj" \
           -scheme "Prizm" -configuration Debug build

# Run all tests
xcodebuild test \
  -project "Prizm/Prizm.xcodeproj" \
  -scheme "Prizm" \
  -destination "platform=macOS"
```

## Active Changes

| Change | Dir |
|---|---|
| vault-document-storage | `openspec/changes/vault-document-storage/` |
| vault-sync-status | `openspec/changes/vault-sync-status/` |
| hosted-cloud-support | `openspec/changes/hosted-cloud-support/` |

## Change Workflow (openspec)

Feature changes live under `openspec/changes/<name>/`. Each change has design, spec, and task
artifacts. Use `/opsx:new` to start a change, `/opsx:apply` to implement tasks, `/opsx:verify`
then `/opsx:archive` when done. Archived changes move to `openspec/changes/archive/`.

## Design System

All Presentation layer typography and spacing is defined in one place:
`Prizm/Presentation/DesignSystem.swift`

**Never use raw font or spacing literals in views.** Always reference the tokens below.

### Typography tokens (`Typography.*`)

| Token | Font | Approx pt (macOS) | Role |
|---|---|---|---|
| `pageTitle` | `.largeTitle.bold()` | 26pt | Item name in detail pane |
| `sectionHeader` | `.title3` | 15pt | Card section headings ("Credentials", "Websites") |
| `fieldValue` | `.body` | 13pt | Primary field content |
| `fieldLabel` | `.subheadline` | 11pt | Small label above a field value |
| `utility` | `.caption` | 10pt | COPY button, footer dates, metadata |
| `listTitle` | `.body` | 13pt | Item name in the list pane |
| `listSubtitle` | `.caption` | 10pt | Secondary subtitle in list rows |

### Spacing tokens (`Spacing.*`)

| Token | Value | Role |
|---|---|---|
| `pageMargin` | 20pt | Horizontal edges of the detail pane |
| `pageTop` | 28pt | Above the item title |
| `pageHeaderBottom` | 12pt | Below the item title |
| `cardTop` | 12pt | Above each section card |
| `cardBottom` | 18pt | Below each section card |
| `headerGap` | 8pt | Between section header label and card |
| `rowVertical` | 9pt | Field row top/bottom padding |
| `rowHorizontal` | 12pt | Field row left/right padding |

### Adding new views

When building a new view that needs fonts or spacing:
1. Check if an existing token fits — use it.
2. If a genuinely new role is needed, add it to `DesignSystem.swift` with a comment.
3. Never hardcode a size that should be consistent with existing UI.

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

## Code Comments (Open Source Standard)

Comments are a first-class public artifact — explain *why*, not *what*. Key rules:

- Don't restate the code; add information the code can't express on its own.
- Don't excuse unclear code with a comment — rename the variable or refactor.
- Explain non-obvious or unidiomatic code (platform quirks, intentional no-ops, workarounds).
- Link RFCs and specs at the point of use: `// Argon2id per RFC 9106 §4`
- Link bug fixes to their issue: `// Fix: keychain returned nil on first launch — #42`
- Mark gaps: `// TODO: what + why deferred` / `// FIXME: what is broken + workaround`

**Security-critical functions** (crypto, keychain, auth) must document:
- Security goal (what threat this defends against)
- Algorithm + spec reference
- Any deviation from the standard and why it is safe
- What is intentionally NOT done (if the omission could look like a bug)
