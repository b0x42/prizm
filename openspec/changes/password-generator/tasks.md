## 1. Domain — PasswordGenerator Utility

- [ ] 1.1 Add `eff-large-wordlist.txt` to the app bundle (resource target membership in Xcode)
- [ ] 1.2 Create `RandomnessProvider` protocol in `Domain/Utilities/RandomnessProvider.swift` — single method `randomBytes(count: Int) throws -> [UInt8]`
- [ ] 1.3 Implement `CryptographicRandomnessProvider: RandomnessProvider` in `Data/` — backed by `SecRandomCopyBytes`; document security goal and RFC reference per CLAUDE.md security-critical code standard
- [ ] 1.4 Write failing unit tests for `PasswordGenerator` — random mode: length bounds (5, 128), uppercase-only pool, all-sets pool, at least-one-per-set guarantee, avoid-ambiguous exclusion, last-set lock prevents empty pool; inject a deterministic `MockRandomnessProvider` for test reproducibility
- [ ] 1.5 Write failing unit tests for `PasswordGenerator` — passphrase mode: word count (3, 10), default word count is 6, separator injection, capitalize toggle, include-number toggle, all words from EFF list
- [ ] 1.6 Implement `PasswordGeneratorConfig` value type — `enum Mode` (default `.password`), all option fields with defaults (passphrase word count default = 6), `UserDefaults` persistence helpers
- [ ] 1.7 Implement `PasswordGenerator` struct — `generatePassword(config:provider:)` and `generatePassphrase(config:provider:)` accepting `RandomnessProvider`; lazy EFF word list loading; Fisher-Yates shuffle; all-sets-disabled guard

## 2. Presentation — PasswordGeneratorViewModel

- [ ] 2.1 Write failing unit tests for `PasswordGeneratorViewModel` — config changes trigger regeneration, copy writes to clipboard, `applyToField` writes through binding, settings persisted to UserDefaults, defaults restored on first launch; inject `CryptographicRandomnessProvider` via `AppContainer`
- [ ] 2.2 Implement `PasswordGeneratorViewModel: ObservableObject` — owns `PasswordGeneratorConfig`, `generatedValue: String`, `generate()`, `copyToClipboard()` (30 s auto-clear via `VaultBrowserViewModel`-style `Task`), `applyToField(binding:)`
- [ ] 2.3 Wire `generate()` call on every `@Published` config property change via `didSet`

## 3. Presentation — PasswordGeneratorView

- [ ] 3.1 Build `PasswordGeneratorView` SwiftUI popover — mode picker (Password / Passphrase) with `.segmented` style at top
- [ ] 3.2 Build password-mode controls section — length `Slider` (5–128) + numeric label, four character-set `Toggle` rows (uppercase, lowercase, digits, symbols), avoid-ambiguous `Toggle`; lock last-enabled toggle per spec
- [ ] 3.3 Build passphrase-mode controls section — word count `Stepper` (3–10), separator `TextField`, capitalize `Toggle`, include-number `Toggle`
- [ ] 3.4 Build preview area — monospaced `Text` showing `generatedValue`; refresh `Button` (SF Symbol `arrow.clockwise`); minimum height to avoid layout jump on value change
- [ ] 3.5 Build action row — "Copy" `Button` and mode-dependent Use `Button` ("Use Password" / "Use Passphrase"); Use writes through `Binding<String?>` and calls `dismiss`
- [ ] 3.6 Add accessibility identifiers to all interactive elements in `AccessibilityIdentifiers.swift`

## 4. Edit Form Integration

- [ ] 4.1 Add optional `generatorBinding: Binding<String?>?` parameter to `EditFieldRow` (default `nil`); render wand SF Symbol button (`wand.and.stars`) when non-nil — always visible, NOT hover-only (contrast with copy/reveal buttons); existing callers unaffected
- [ ] 4.2 Wire generator popover in `LoginEditForm` — pass `$draft.login.password` binding to the password `EditFieldRow`
- [ ] 4.3 Wire generator popover in `SSHKeyEditForm` — pass `$draft.sshKey.privateKey` binding to the private key `EditFieldRow`

## 5. Tests & Constitution Check

- [ ] 5.1 XCUITest: open Login edit sheet → tap generator button → verify popover opens; change length slider → verify preview updates; tap Use → verify password field updated; dismiss sheet
- [ ] 5.2 XCUITest: open Login edit sheet → tap generator button → switch to Passphrase mode → change word count → verify preview updates
- [ ] 5.3 Verify `PasswordGenerator` imports Foundation only (Domain layer boundary — no Security, no SwiftUI, no AppKit, no CryptoKit); verify `SecRandomCopyBytes` is confined to `CryptographicRandomnessProvider` in Data layer
- [ ] 5.4 Constitution check: confirm `CryptographicRandomnessProvider` documents security goal, algorithm reference (`SecRandomCopyBytes`, Security.framework), and rationale per CLAUDE.md security-critical code standard
- [ ] 5.5 Constitution check: audit no swallowed `catch {}` blocks; verify generated values never appear in log output (`privacy: .private` or scrubbed)
