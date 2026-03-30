# Macwarden Development Guidelines

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
- **Crypto/Vault**: CommonCrypto + CryptoKit + Security.framework + `Argon2Swift` (Argon2id only) — Data layer only, behind `BitwardenCryptoService` protocol. sdk-swift has no macOS slice.
- **Storage**: macOS Keychain (secrets), UserDefaults (UI prefs), in-memory (decrypted vault)
- **Networking**: `URLSession` (no third-party networking library)
- **Testing**: XCTest (unit + integration), XCUITest (UI journeys)
- **Logging**: `os.Logger` with subsystem `com.macwarden`

## Project Structure

```text
Macwarden/
├── Macwarden.xcodeproj/
├── App/                # @main, AppContainer (DI), Config
├── Domain/             # Entities, UseCase protocols, Repository protocols, Utilities
├── Data/               # Crypto, Network, Keychain, Repository impls, UseCase impls, Mappers
├── Presentation/       # SwiftUI Views, ViewModels, Components
├── MacwardenTests/     # Unit + integration tests (XCTest)
└── Tests/UITests/      # UI journey tests (XCUITest)

openspec/
├── changes/            # Active and archived change specs (one dir per feature)
└── specs/              # Approved specs awaiting or under implementation
```

## Setup

**Local config:** Copy `Macwarden/LocalConfig.xcconfig.template` → `Macwarden/LocalConfig.xcconfig`
and fill in your Team ID. This file is gitignored. **Build will fail without it.**

**Team ID (code signing):** The Xcode project requires a valid Apple Developer Team ID for code signing. If the Team ID is not set (empty or `""` in the project file), **ask the user for their Team ID before running any build or test commands** — do not attempt to build without it, as the build will fail with a signing error.

## Commands

```bash
# Open project
open "Macwarden/Macwarden.xcodeproj"

# Build
xcodebuild -project "Macwarden/Macwarden.xcodeproj" \
           -scheme "Macwarden" -configuration Debug build

# Run all tests
xcodebuild test \
  -project "Macwarden/Macwarden.xcodeproj" \
  -scheme "Macwarden" \
  -destination "platform=macOS"
```

## Change Workflow (openspec)

Feature changes live under `openspec/changes/<name>/`. Each change has design, spec, and task
artifacts. Use `/opsx:new` to start a change, `/opsx:apply` to implement tasks, `/opsx:verify`
then `/opsx:archive` when done. Archived changes move to `openspec/changes/archive/`.

## Design System

All Presentation layer typography and spacing is defined in one place:
`Macwarden/Presentation/DesignSystem.swift`

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

This project is open source. Comments are a first-class public artifact — they help contributors
understand not just *what* the code does, but *why* it exists and *how* decisions were made.
Follow these rules for all new and modified code.

Reference: https://stackoverflow.blog/2021/12/23/best-practices-for-writing-code-comments/

### Rules

**1. Don't duplicate the code.**
A comment that restates what the code already says adds noise and gets out of sync.
Write comments that add information the code cannot express on its own.

```swift
// BAD: increments retryCount by one
retryCount += 1

// GOOD: back off after three consecutive failures to avoid hammering the server
retryCount += 1
```

**2. Don't use comments to excuse unclear code — rewrite it.**
If a variable name needs a comment to be understandable, rename the variable instead.
Comments should never be a crutch for poor naming or convoluted logic.

**3. If you can't write a clear comment, the code may be the problem.**
Struggling to explain what a block does is a signal to refactor it, not to write a longer comment.

**4. Comments must dispel confusion, not cause it.**
Avoid abbreviations without definition, ambiguous pronouns, or references to context the reader
cannot access. If you are unsure a reader will know what you mean, spell it out.

**5. Explain unidiomatic or non-obvious code.**
When code deviates from the expected pattern — a workaround, a platform quirk, an intentional
no-op — say why. Future contributors (including you) will otherwise assume it is a bug.

```swift
// kSecUseDataProtectionKeychain is intentionally omitted here: adding it caused per-item
// access prompts on macOS 13 (Ventura) even with kSecAttrAccessible set. The data-protection
// keychain class is set via the entitlement instead (see .entitlements).
```

**6. Link to the original source of copied or adapted code.**
Include a URL comment at the point of use. This lets contributors check for upstream fixes,
understand the original context, and avoid re-discovering the same solution.

```swift
// Adapted from: https://example.com/source
```

**7. Link to external standards and specs at the point of use.**
Crypto, protocol, and API code must cite the relevant RFC, spec section, or documentation page
directly in the comment next to the implementation — not just in a README.

```swift
// PBKDF2 key stretching per NIST SP 800-132 §5.3
// Argon2id per RFC 9106 §4 — memory-hard KDF chosen for resistance to GPU/ASIC attacks
```

**8. Comment bug fixes with the issue reference.**
When fixing a non-obvious bug, explain what was wrong and reference the issue or PR number.
This helps future maintainers understand whether a workaround is still needed after an OS update.

```swift
// Fix: keychain items returned nil on first launch because the access group was not set.
// See: github.com/org/repo/issues/42
```

**9. Mark incomplete implementations with TODO/FIXME.**
Use `// TODO:` for known missing work and `// FIXME:` for known broken behaviour.
Always include *what* needs to be done and, where possible, *why* it is deferred.

```swift
// TODO: implement biometric unlock (Touch ID / Face ID) — blocked on entitlement approval
// FIXME: cipher list does not refresh after background sync; force-quit workaround for now
```

### Security-critical code

All crypto, keychain, and authentication code requires an additional level of documentation
because this project is security software that users must be able to audit and decide to trust.

For every security-critical function or block:
- State the **security goal** (what threat this defends against)
- Name the **algorithm or standard** with a spec reference
- Call out **any deviation** from the standard and why it is safe
- Note **what is NOT done** if the omission could look like a bug

```swift
/// Derives the master key from the user's password and email-based salt.
///
/// - Algorithm: Argon2id (RFC 9106) — memory-hard to resist offline brute-force
/// - Parameters: 64 MiB memory, 3 iterations, 4 threads (Bitwarden defaults, §4.4)
/// - Note: email is lowercased and UTF-8 encoded before use as salt, matching
///   the Bitwarden server implementation. Changing this would break existing vaults.
/// - Security goal: makes dictionary and GPU-accelerated attacks computationally infeasible
func deriveKey(password: String, email: String) async throws -> SymmetricKey { ... }
```
