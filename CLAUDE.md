# Macwarden Development Guidelines

Auto-generated from feature plans. Last updated: 2026-03-21
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
- **Logging**: `os.Logger` with subsystem `com.macwarden`

## Project Structure

```text
Macwarden/
├── Macwarden.xcodeproj/
└── Macwarden/
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

## Recent Changes
- 001-vault-browser-ui: Added Swift 5.10 (latest stable) + SwiftUI, CommonCrypto, CryptoKit, Security.framework, `Argon2Swift` 1.0.1-bw2 (local vendored at `LocalPackages/Argon2Swift/`)

### 001-vault-browser-ui (2026-03-15)
Added: full project scaffold, three-pane vault browser, login/unlock flows, search.
Technologies introduced: native Bitwarden crypto (CommonCrypto + CryptoKit + Argon2Swift),
`NavigationSplitView`, macOS Keychain integration.
Note: sdk-swift rejected (iOS-only XCFramework); native crypto adopted per CONSTITUTION.md §III.

### 002-open-source-prep (2026-03-21)
Added: Code Comments section (open source standard) with nine rules from Stack Overflow best
practices guide, plus security-critical code documentation requirements.
