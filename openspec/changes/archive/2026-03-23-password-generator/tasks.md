## 1. Domain — PasswordGenerator Utility

- [x] 1.1 Add `eff-large-wordlist.txt` to the app bundle (resource target membership in Xcode)
- [x] 1.2 Create `RandomnessProvider` protocol in `Domain/Utilities/RandomnessProvider.swift` — single method `randomBytes(count: Int) throws -> [UInt8]`
- [x] 1.3 Implement `CryptographicRandomnessProvider: RandomnessProvider` in `Data/` — backed by `SecRandomCopyBytes`; document security goal and RFC reference per CLAUDE.md security-critical code standard
- [x] 1.4 Create `MockRandomnessProvider: RandomnessProvider` in `MacwardenTests/Mocks/` — deterministic byte sequence for reproducible tests
- [x] 1.5 Write failing unit tests for `PasswordGenerator` — random mode: length bounds (5, 128), uppercase-only pool, all-sets pool, at least-one-per-set guarantee, avoid-ambiguous exclusion, last-set lock prevents empty pool; use `MockRandomnessProvider`
- [x] 1.6 Write failing unit tests for `PasswordGenerator` — passphrase mode: word count bounds (3, 10), default word count is 6, separator injection, capitalize toggle, include-number toggle, all words from EFF list; use `MockRandomnessProvider`
- [x] 1.7 Implement `PasswordGeneratorConfig` value type — `enum Mode` (default `.password`), all option fields with defaults (passphrase word count default = 6), `UserDefaults` persistence helpers
- [x] 1.8 Implement `PasswordGenerator` struct — `generatePassword(config:provider:)` and `generatePassphrase(config:provider:)` accepting `RandomnessProvider`; `static let` EFF word list cache; Fisher-Yates shuffle via `provider.randomBytes(count:)`; all-sets-disabled guard

## 2. Presentation — PasswordGeneratorViewModel

- [x] 2.1 Write failing unit tests for `PasswordGeneratorViewModel` in `MacwardenTests/PasswordGeneratorViewModelTests.swift` — config changes trigger regeneration, copy writes to clipboard, settings persisted to UserDefaults, defaults restored on first launch; inject `MockRandomnessProvider` in tests
- [x] 2.2 Implement `PasswordGeneratorViewModel: ObservableObject` — owns `PasswordGeneratorConfig`, `generatedValue: String`, `generate()`, `copyToClipboard()` (30 s auto-clear via `VaultBrowserViewModel`-style `Task`); no `applyToField` method — the View writes through its `Binding<String?>` directly (see design D5)
- [x] 2.3 Wire `generate()` call on every `@Published` config property change via `didSet`
- [x] 2.4 Wire `CryptographicRandomnessProvider` into `AppContainer` — instantiate once and inject into `PasswordGeneratorViewModel` factory closure; add `makePasswordGeneratorViewModel` factory to `AppContainer`
- [x] 2.5 Instantiate `PasswordGeneratorViewModel` as `@StateObject` inside `EditFieldRow` (not in a parent ViewModel) — ensures `generatedValue` plaintext is released when the popover closes, per design D7 and Constitution §III

## 3. Presentation — PasswordGeneratorView

- [x] 3.1 Build `PasswordGeneratorView` SwiftUI popover — mode picker (Password / Passphrase) with `.segmented` style at top
- [x] 3.2 Build password-mode controls section — length `Slider` (5–128) + numeric label, four character-set `Toggle` rows (uppercase, lowercase, digits, symbols), avoid-ambiguous `Toggle`; lock last-enabled toggle per spec
- [x] 3.3 Build passphrase-mode controls section — word count `Stepper` (3–10), separator `TextField`, capitalize `Toggle`, include-number `Toggle`
- [x] 3.4 Build preview area — monospaced `Text` showing `generatedValue`; refresh `Button` (SF Symbol `arrow.clockwise`); minimum height to avoid layout jump on value change
- [x] 3.5 Build action row — "Copy" `Button` and mode-dependent Use `Button` ("Use Password" / "Use Passphrase"); Use writes through `Binding<String?>` and calls `dismiss`
- [x] 3.6 Add accessibility identifiers to all interactive elements in `AccessibilityIdentifiers.swift`

## 4. Edit Form Integration

- [x] 4.1 Add optional `generatorBinding: Binding<String?>?` parameter to `EditFieldRow` (default `nil`); render wand SF Symbol button (`wand.and.stars`) when non-nil — always visible, NOT hover-only (contrast with copy/reveal buttons); existing callers unaffected
- [x] 4.2 Wire generator popover in `LoginEditForm` — pass `$draft.login.password` binding to the password `EditFieldRow`

## 5. Tests & Constitution Check

- [x] 5.1 XCUITest: open Login edit sheet → tap generator button → verify popover opens; change length slider → verify preview updates; tap Use → verify password field updated; dismiss sheet
- [x] 5.2 XCUITest: open Login edit sheet → tap generator button → switch to Passphrase mode → change word count → verify preview updates
- [x] 5.3 Verify `PasswordGenerator` imports Foundation only (Domain layer boundary — no Security, no SwiftUI, no AppKit, no CryptoKit); verify `SecRandomCopyBytes` is confined to `CryptographicRandomnessProvider` in Data layer
- [x] 5.4 Constitution check: confirm `CryptographicRandomnessProvider` documents security goal, algorithm reference (`SecRandomCopyBytes`, Security.framework), and rationale per CLAUDE.md security-critical code standard
- [x] 5.5 Constitution check: audit no swallowed `catch {}` blocks; verify generated values never appear in log output (`privacy: .private` or scrubbed)
