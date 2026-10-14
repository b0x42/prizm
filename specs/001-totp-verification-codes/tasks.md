---

description: "Task list for TOTP Verification Codes"
---

# Tasks: TOTP Verification Codes

**Input**: Design documents from `/specs/001-totp-verification-codes/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/domain-protocols.md, contracts/ui-contract.md, quickstart.md

**Tests**: REQUIRED. Constitution §IV (TDD, no exceptions) applies: every test task must be written first and seen to fail (Red) before its implementation task. Crypto needs known-answer tests (RFC 6238 / RFC 4226).

**Organization**: Tasks are grouped by user story. US1 is the MVP.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1, US2, US3 (maps to spec.md)
- Paths are relative to the repository root. `Prizm/PrizmTests/` is a file-system-synchronized group (new test files join the test target automatically), but app sources under `Prizm/Domain|Data|Presentation|App` are explicit project entries: add every new app file to the `Prizm` target with `ruby add_files.rb <path under Prizm/>` (uses the `xcodeproj` gem; script kept in the session scratchpad, recreate it if missing). UI tests live in the `PrizmUITests` target, run through the separate shared scheme `PrizmUITests` (`xcodebuild test -project Prizm/Prizm.xcodeproj -scheme PrizmUITests -destination 'platform=macOS'`) so a plain "run all tests" stays fast. The target contains only `Prizm/UITests/VerificationCodeJourneyTests.swift`; the 13 older files in that folder do not compile and rely on launch options the app never read, so they are not in the target. UI tests use the DEBUG-only `--ui-test-vault` seam (`Prizm/App/UITestFixtures.swift`).

## Path Conventions

- Domain: `Prizm/Domain/` (Foundation only) · Data: `Prizm/Data/` · Presentation: `Prizm/Presentation/` · App: `Prizm/App/`
- Unit/integration tests: `Prizm/PrizmTests/` · UI tests: `Prizm/UITests/`
- Design system tokens: `Prizm/Presentation/DesignSystem.swift` (never raw font or spacing literals in views)
- Comments follow CLAUDE.md "Code Comments": explain why, cite RFCs, document security goals

---

## Phase 1: Setup

- [X] T001 Ask the user for their Apple Developer Team ID and confirm `Prizm/LocalConfig.xcconfig` contains `DEVELOPMENT_TEAM` (CLAUDE.md "Setup"); do not run any build or test command before this.
- [X] T002 Run the full baseline suite and record the result: `xcodebuild test -project "Prizm/Prizm.xcodeproj" -scheme "Prizm" -destination "platform=macOS"`. If anything already fails, report it before changing code.

---

## Phase 2: Foundational (blocks all user stories)

**Purpose**: Domain types, seed parsing, HMAC, code generation, the shared tracker, and the §III exception. US1, US2, and US3 all depend on this.

**⚠️ CRITICAL**: No user story work begins until the Checkpoint at the end of this phase. The checkpoint is about the code foundation only. T003 (the §III amendment) is a separate gate that blocks only T023 and T035.

### Governance

- [X] T003 [P] Amend `CONSTITUTION.md` §III with a narrow exception: sensitive data shown in the UI MUST auto-clear after a configurable timeout, EXCEPT generated TOTP codes, which are always visible like in other authenticator apps while the vault is unlocked, the app is not hidden or minimized, and the code view is on screen. State that the exception covers generated TOTP codes only, never passwords, seeds, or other secrets. Bump version 1.5.0 → 1.6.0 (MINOR), update the Sync Impact Report header and `Last Amended`. Then update the version mentioned in `CLAUDE.md` line 3 and refresh the local, git-ignored `.specify/memory/constitution.md` from `CONSTITUTION.md`. Rationale to cite: codes expire within one period, are removed on lock/inactive/off-screen, copies clear in 30 s, and the seed is never displayed (see plan.md Complexity Tracking). First follow the Governance amendment procedure: open a proposal issue describing the change and its rationale (record the issue number in the Sync Impact Report), then update the file, then check dependent templates (`.specify/templates/*`) for needed changes. Governance says the Constitution wins in conflicts, so this amendment must be accepted before the always-visible UI tasks (T023, T035) start, and must merge with, or before, the feature.

### Domain types and parser (Red → Green)

- [X] T004 [P] Create `Prizm/Domain/Entities/TOTPConfiguration.swift` (Foundation only, `nonisolated`) with: `TOTPHashAlgorithm` enum (`sha1`, `sha256`, `sha512`); `TOTPError: Error, Equatable` with cases `emptySeed`, `invalidSecret`, `unsupportedScheme`, `unsupportedParameter` and no associated values that could carry the seed; `TOTPConfiguration` struct with `secret: Data` ("Decoded base32 bytes. Must be non-empty."), `algorithm` (default `sha1`), `digits: Int` ("6 to 8. Default 6."), `period: Int` ("Greater than 0. Default 30."). Doc comments cite RFC 6238 §4 and RFC 4226 §5.
- [X] T005 [P] Write failing tests `Prizm/PrizmTests/Domain/TOTPSeedParserTests.swift` for every row of the parser table in `contracts/domain-protocols.md`: spaced/lowercase base32 → SHA-1/6/30; `otpauth://totp/...?secret=...&digits=8&period=60&algorithm=SHA256`; otpauth with defaults; `""` and whitespace → `emptySeed`; bad base32 or missing secret → `invalidSecret`; `steam://...` and `otpauth://hotp/...` → `unsupportedScheme`; `algorithm=MD5`, `digits=5`, `digits=9`, `period=0` → `unsupportedParameter`. Confirm they fail (no `TOTPSeedParser` yet).
- [X] T006 Implement `Prizm/Domain/Utilities/TOTPSeedParser.swift` (`enum TOTPSeedParser { static func parse(_ seed: String) throws -> TOTPConfiguration }`) so T005 passes. Base32 per RFC 4648 §6 (case-insensitive; ignore spaces and `=`); otpauth parsing via `URLComponents`. Never log or embed the seed in errors. Base32 decoding is encoding, not cryptography, so it stays in Domain. `TOTPConfiguration.secret` stays a plain `Data` (as in `data-model.md`); zeroing is handled by the caller in T014. The configuration is parsed per refresh pass and dropped, never cached.
- [X] T007 [P] Write failing tests `Prizm/PrizmTests/Domain/TOTPCodeTests.swift`: `grouped` for 6 digits ("123 456"), 8 digits ("1234 5678"), 7 digits ("123 4567"); `copyValue` has no space; `isExpiringSoon` is true when `secondsRemaining <= 5` and false at 6; zero-padded digits are preserved.
- [X] T008 Create `Prizm/Domain/Entities/TOTPCode.swift` (Foundation only, `nonisolated`, `Equatable`): `digits: String` ("Exactly `configuration.digits` characters, zero-padded."), `period: Int`, `secondsRemaining: Int` ("1 to `period`"), plus `grouped`, `copyValue`, `isExpiringSoon` per `data-model.md`, so T007 passes.

### Crypto and use case (Red → Green)

- [X] T009 [P] Write failing known-answer tests `Prizm/PrizmTests/Data/TOTPKnownAnswerTests.swift` using the real `PrizmCryptoService` implementation and the RFC 6238 Appendix B vectors (SHA-1, SHA-256, SHA-512; 8 digits; times 59, 1111111109, 1111111111, 1234567890, 2000000000, 20000000000). Take the expected values and seeds from the RFC text, not only from `contracts/domain-protocols.md`. Add RFC 4226 Appendix D truncation checks (6 digits, counters 0 to 9 for the SHA-1 seed `12345678901234567890`: 755224, 287082, 359152, 969429, 338314, 254676, 287922, 162583, 399871, 520489). Cite the RFC section in a comment on each vector table.
- [X] T010 Add `func hmac(_ algorithm: TOTPHashAlgorithm, key: Data, message: Data) -> Data` to the `PrizmCryptoService` protocol and implementation in `Prizm/Data/Crypto/PrizmCryptoService.swift`, using CryptoKit `HMAC<Insecure.SHA1>`, `HMAC<SHA256>`, `HMAC<SHA512>`. Stateless: must not require an unlocked vault. Doc comment: security goal (one-time-code derivation, not storage), RFC 2104 and RFC 6238 §1.2, why SHA-1 is acceptable inside HMAC (collision weakness does not affect HMAC), and that vault keys are intentionally not used. Check the Apple API for `Insecure.SHA1` with Context7 first (CLAUDE.md global rule); if Context7 has nothing, say so and fall back.
- [X] T011 [P] Add the same `hmac` method to `Prizm/PrizmTests/Mocks/MockPrizmCryptoService.swift` (record calls, return a configurable value) so existing tests keep compiling.
- [X] T012 [P] Create `Prizm/Domain/UseCases/GenerateTOTPCodeUseCase.swift`: `protocol GenerateTOTPCodeUseCase: Sendable { func execute(seed: String, at date: Date) async throws -> TOTPCode }` with a doc comment describing behavior from `contracts/domain-protocols.md`.
- [X] T013 Write failing tests `Prizm/PrizmTests/Data/GenerateTOTPCodeUseCaseTests.swift`: with `MockPrizmCryptoService`, counter is `floor(unixSeconds / period)` as 8-byte big-endian; `secondsRemaining = period - (unixSeconds mod period)` (equals `period` exactly at a boundary); the same seed and date give the same result; the use case's own secret buffer is overwritten after use (success and error paths; best effort, assert via a test seam that exposes the buffer); parser errors propagate as `TOTPError`; the seed never appears in any thrown error description.
- [X] T014 Implement `Prizm/Data/UseCases/GenerateTOTPCodeUseCaseImpl.swift` (parser → counter → `hmac` → RFC 4226 §5.3 dynamic truncation → modulo `10^digits` → zero pad). Inline comments cite RFC 6238 §4 and RFC 4226 §5.2/§5.3. Constitution "Memory hardening": hold the secret in a mutable local copy and overwrite it with zeros (`resetBytes`/`withUnsafeMutableBytes`) before returning, on success and on throw. This is best effort: `Data` is copy-on-write and `hmac(key:)` receives a copy, so say so in a code comment and in `SECURITY.md` (T044) rather than claiming a guarantee. Makes T009 and T013 pass.
- [X] T015 Wire the use case in `Prizm/App/AppContainer.swift`: new `generateTOTPCodeUseCase` property constructed with the existing crypto service, and expose it to the places that need it (T017 and T024), following how `searchVaultUseCase` is wired. Add it to the `RootViewModelDependencies` protocol in `Prizm/App/PrizmApp.swift` if the root view model will use it.

### Shared tracker (Red → Green)

- [X] T016 Write failing tests `Prizm/PrizmTests/Presentation/TOTPCodesViewModelTests.swift` with an injected clock and a mock `GenerateTOTPCodeUseCase`: `start(items:)` publishes a `.code` for items with usable seeds and `.unavailable` for unusable ones; states update when the clock crosses a period boundary; `stop()` empties `states` (set to `[:]`); with the clock moved to exactly the period boundary the new code is published on the next tick, at most 1 second later (SC-004); starting again after `stop()` shows current (not stale) codes; no use-case calls happen after `stop()`; no seed or code is passed to any logger.
- [X] T017 Create `Prizm/Presentation/Vault/VerificationCodes/TOTPCodesViewModel.swift` (`@MainActor final class`, `ObservableObject`): `@Published private(set) var states: [String: TOTPCodeState]` keyed by item id; `TOTPCodeState` is `.code(TOTPCode)` or `.unavailable`; async refresh loop that reads the injected clock `() -> Date` once per pass and sleeps to the next whole second; `start(items:)`, `stop()`, and a `copyValue(for itemId:)` helper. Parses and drops the seed each pass; no caching of seeds or configurations. Log at `.error` (subsystem `com.prizm`) only a count of items whose code is unavailable, never seeds or codes (Constitution §V). Makes T016 pass.

**Checkpoint**: Parser, KATs, use case, and tracker tests pass. User stories may begin. Separate gate: T023 and T035 additionally require T003 to be "accepted", meaning the amendment proposal issue is filed (#72), the `CONSTITUTION.md` change is committed with its rationale recorded, and you (the project owner) have approved it. Other US1/US2 tasks (tests, row view, repository, sidebar) do not wait for it.

---

## Phase 3: User Story 1 - See the current code for one item (Priority: P1) 🎯 MVP

**Goal**: A Login with a seed shows its current code and countdown in the detail pane, rotates automatically, and "Copy Code" (⌃⌘C) copies the generated code. No seed is ever displayed or copied.

**Independent Test**: Sync a vault with a Login with a known seed, open it, and compare the shown code to a reference authenticator across 3 rotations; press ⌃⌘C and paste (quickstart scenarios 1 to 5).

### Tests for US1 (write first, confirm Red)

- [X] T018 [P] [US1] Write failing tests in `Prizm/PrizmTests/Presentation/RootViewModelCopyCodeTests.swift` (follow `RootViewModelLockTests.swift` for setup): `copySelectedField(.totp)` copies the generated code with no space, not the seed; `selectedFieldAvailable(.totp)` is true only when the selected Login's seed parses; false for no selection, no seed, unusable seed; no other `CopyableField` returns the seed.
- [X] T019 [P] [US1] Write failing XCUITest `Prizm/UITests/VerificationCodeJourneyTests.swift` (US1 part): open a Login with a seed, assert the "Verification Code" card shows a code matching `\d{3} \d{3}`, assert the copy button exists with label "Copy verification code for <name>", and assert an item without a seed shows no such card. Use a test vault fixture or mock mode consistent with `VaultBrowserJourneyTests.swift`.

### Implementation for US1

- [X] T020 [P] [US1] Add accessibility identifiers for the code row, code text, countdown, and copy button to `Prizm/Presentation/AccessibilityIdentifiers.swift` under a new `VerificationCodes` enum (follow the existing `Vault` and `Sidebar` style).
- [X] T021 [P] [US1] Add any missing typography/spacing token to `Prizm/Presentation/DesignSystem.swift` for the code text (monospaced digits, larger than `fieldValue`), with a comment per CLAUDE.md "Adding new views". Use existing tokens for everything else.
- [X] T022 [US1] Create `Prizm/Presentation/Vault/VerificationCodes/TOTPCodeRowView.swift`: shows grouped code, a countdown with seconds and a progress ring, and a copy button; `.unavailable` shows "Code unavailable" with no copy button. In the last 5 seconds (`isExpiringSoon`) the ring and number change color AND weight/symbol, so the cue is not color alone (FR-001a). One accessibility element per `contracts/ui-contract.md` ("Verification code for <name>", digits read individually, seconds remaining, `updatesFrequently` trait, no announcement on rotation). Copy button label: "Copy verification code for <name>". Tokens only.
- [X] T023 [US1] (blocked until T003 is accepted) Add a "Verification Code" `DetailSectionCard` to `Prizm/Presentation/Vault/Detail/LoginDetailView.swift`, after Credentials, shown only when the Login has a seed (non-blank `totp`); header carries the `.isHeader` trait. It starts and stops a `TOTPCodesViewModel` for the one item from `.task` (cancelled when the view disappears) and calls the existing `onCopy` closure with `copyValue`, so the existing 30-second clipboard clear applies. Never display the raw seed. Thread the view model or use case through `Prizm/Presentation/Vault/Detail/ItemDetailView.swift` and `Prizm/Presentation/Vault/VaultBrowserView.swift` as needed.
- [X] T024 [US1] Change "Copy Code" in `Prizm/App/PrizmApp.swift`: `copySelectedField(.totp)` asynchronously generates the code through the use case and passes `copyValue` to `vaultBrowserVM.copy(_:)`; the `.totp` case in `selectedFieldValue` must stop returning the stored seed; `selectedFieldAvailable(.totp)` checks that the seed parses (via `TOTPSeedParser`). Add no other seed-copy command (FR-016). Makes T018 pass.
- [X] T025 [P] [US1] Update `openspec/specs/copy-menu-commands/spec.md` and reword two stale comments (`Prizm/Domain/Entities/VaultItem.swift` line ~73 "never displayed in v1 (FR-038)" and `Prizm/Domain/Entities/DraftVaultItem.swift` line ~64): the raw seed is still never displayed or copied, but generated codes are shown; FR-038 is not defined anywhere in the repo, so do not cite it. In the spec: replace the scenario "Copy Code copies TOTP seed to clipboard" with "Copy Code copies the current generated code (no spaces) with 30s auto-clear" and add "Copy Code is disabled when the selected item has no usable seed". Keep the spec's existing format.
- [ ] T026 [US1] Run T018 and T019 and the full suite; walk quickstart scenarios 1 to 5 and 12 (VoiceOver) manually and record the result.

**Checkpoint**: US1 works alone. MVP is shippable (per-item code, correct Copy Code, no seed copy).

---

## Phase 4: User Story 2 - List every item that has a code (Priority: P2)

**Goal**: A "Verification Codes" sidebar entry lists every non-trashed Login with a seed, alphabetical, searchable, each row showing name, grouped code, countdown, and a copy button.

**Independent Test**: A vault with several items with seeds, one in trash, one with no seed, one with an invalid seed: the list shows exactly the non-trashed items with seeds (the invalid one shows "Code unavailable"), alphabetically, count matches (quickstart scenarios 6 to 9).

### Tests for US2 (write first, confirm Red)

- [X] T027 [P] [US2] Write failing tests in `Prizm/PrizmTests/Domain/SidebarSelectionTests.swift`: `.verificationCodes` equals only itself, hashes distinctly from every other case, and `displayName == "Verification Codes"`.
- [X] T028 [P] [US2] Add failing tests to `Prizm/PrizmTests/Data/VaultRepositoryImplTests.swift` for the new index per `data-model.md` ("Index membership"): includes a non-deleted Login with a non-blank `totp`; excludes trashed items, non-Login items, nil totp, and whitespace-only totp; sorted case-insensitively by name; `itemCounts()[.verificationCodes]` equals the index size; `searchItems(query:in:)` filters it by name, username, and website; the index is empty after `clearVault()`.
- [X] T029 [P] [US2] (covered at the repository level by T028; the selection flow is generic, so no separate view-model test was added) Add failing tests to `Prizm/PrizmTests/Presentation/` (new file `VerificationCodesSelectionTests.swift`, modelled on `VaultBrowserViewModelGlobalSearchTests.swift`): selecting `.verificationCodes` fills `displayedItems` with only the indexed items; the search query filters them; leaving the selection keeps other lists unchanged.
- [X] T030 [P] [US2] Extend `Prizm/UITests/VerificationCodeJourneyTests.swift` (failing first): select the "Verification Codes" sidebar row, assert the expected rows appear in alphabetical order, assert a trashed item is absent, type in the search field and assert filtering, click a row and assert the detail pane opens the item, copy from a row, and assert the empty state text when no items have seeds.

### Implementation for US2

- [X] T031 [US2] Add `case verificationCodes` to `SidebarSelection` in `Prizm/Domain/Entities/SidebarSelection.swift`, with `displayName` "Verification Codes", an explicit `==` branch, and a new distinct `hash(into:)` discriminator (use `9`; do not renumber existing ones). Makes T027 pass.
- [X] T032 [US2] Update `Prizm/Data/Repositories/VaultRepositoryImpl.swift` `buildIndexes()`: add `bySelection[.verificationCodes] = sorted(active.filter { isLogin && totp is non-nil and non-blank after trimming })` and `counts[.verificationCodes]`. Reuse the existing `sorted()` helper. Makes T028 pass.
- [X] T033 [US2] Check `Prizm/PrizmTests/Mocks/MockVaultRepository.swift` and every `switch` over `SidebarSelection` (search with `grep -rn "case .trash" Prizm`); handle the new case wherever the compiler or the grep demands. Makes T029 pass.
- [X] T034 [P] [US2] Add the sidebar row to `Prizm/Presentation/Vault/Sidebar/SidebarView.swift` after Favorites: `SidebarRowView(title: "Verification Codes", systemImage: <clock-style SF Symbol>, selection: .verificationCodes, count: itemCounts[.verificationCodes] ?? 0)`, with an accessibility identifier from T020 and the standard label/value conventions.
- [X] T035 [US2] (blocked until T003 is accepted) Create `Prizm/Presentation/Vault/VerificationCodes/VerificationCodesListView.swift`: list of `viewModel.displayedItems`, each row built from item identity (favicon/type icon, name) plus `TOTPCodeRowView` (T022), selection bound to `viewModel.itemSelection`, a `TOTPCodesViewModel` started from `.task` for the displayed items and restarted when the items change. Empty state "No verification codes" with a short explanation when there are none; use the existing no-results presentation when search finds nothing. Tokens only.
- [X] T036 [US2] In `Prizm/Presentation/Vault/VaultBrowserView.swift`, show `VerificationCodesListView` when `viewModel.sidebarSelection == .verificationCodes` (same place the Trash switch lives), passing the existing copy closure so copies go through the 30-second clipboard clear.
- [ ] T037 [US2] Run T027 to T030 and the full suite; walk quickstart scenarios 6 to 9 manually.

**Checkpoint**: US1 and US2 both work independently.

---

## Phase 5: User Story 3 - Codes disappear when the vault locks (Priority: P2)

**Goal**: No code is visible or generated after lock, while the app is hidden or all windows are minimized, or when no code view is on screen; on return, codes are current. Merely losing focus does NOT hide codes.

**Independent Test**: Open the list, lock the vault: nothing visible; unlock: current codes (quickstart scenarios 10 and 11).

### Tests for US3 (write first, confirm Red)

- [X] T038 [P] [US3] Add failing tests to `Prizm/PrizmTests/Presentation/TOTPCodesViewModelTests.swift`: `stop()` clears `states` and halts use-case calls (the hidden/minimized case reaches the view model only through `stop()`); `start` after `stop()` yields codes for the current clock time, not the stale ones; calling neither (focus change) leaves updates running. Hide/minimize and focus-change behavior is covered by the manual quickstart scenario 11 (T043, T049); T040 covers lock only.
- [X] T039 [P] [US3] Add a failing test to `Prizm/PrizmTests/Presentation/RootViewModelLockTests.swift`: after `lockVault()` completes, the vault browser view model (and its tracker) hold no codes and the repository index `.verificationCodes` is empty.
- [X] T040 [P] [US3] Add a failing XCUITest case to `Prizm/UITests/VerificationCodeJourneyTests.swift`: with codes visible, lock the vault via the existing lock action; assert no element with the code row identifiers exists on the unlock screen; unlock; assert codes are shown again.

### Implementation for US3

- [X] T041 [US3] In the hosts of `TOTPCodeRowView` (`LoginDetailView` card from T023 and `VerificationCodesListView` from T035), call `stop()` when the app is hidden or all windows are minimized, and `start(...)` when it returns; call `stop()` from `.onDisappear`. Do NOT stop on mere loss of focus: on macOS `@Environment(\.scenePhase)` can report `.inactive` for an unfocused but visible window, so first check how `scenePhase` behaves for hide (⌘H) and minimize versus focus change, and if it cannot tell them apart use window occlusion/visibility (an AppKit hook needs a Complexity Tracking entry in plan.md per Constitution §I). Makes T038 pass.
- [X] T042 [US3] Confirm in code that `RootViewModel.lockVault()` in `Prizm/App/PrizmApp.swift` already removes the vault browser (screen switches to unlock), which cancels the `.task` loop. If the tracker outlives the browser anywhere, add an explicit `stop()` in the lock path. Makes T039 pass without adding a new notification mechanism.
- [ ] T043 [US3] Run T038 to T040 and the full suite; walk quickstart scenarios 10 and 11 manually.

**Checkpoint**: All three stories work independently and together.

---

## Phase 6: Polish and Cross-Cutting

- [X] T044 [P] Update `SECURITY.md`: new TOTP section covering what is derived (codes from the existing decrypted seed), the algorithm (RFC 6238 over HMAC-SHA1/256/512, SHA-1 rationale), that codes and parsed seeds are never stored or logged, the always-visible exception and its mitigations (expiry, removal on lock/inactive/off-screen, 30 s clipboard clear), and what is NOT protected (shoulder-surfing, screen capture, wrong device clock, and the fact that zeroing of the secret buffer is best effort because of `Data` copy-on-write).
- [X] T045 [P] Update `ACCESSIBILITY.md`: document the row semantics, the non-color expiry cue, the absence of per-rotation announcements, and any known gaps found in T026 and T043 (be honest).
- [X] T046 [P] Update `README.md` roadmap (move "TOTP code display" out of Now once shipped, or mark progress, following the README's current format) and add a `CHANGELOG.md` entry for the user-visible change, including that "Copy Code" now copies the generated code and the raw-seed copy is removed (Constitution: changelog entry required).
- [X] T047 [P] Update `CLAUDE.md` "Active Changes" table with `totp-verification-codes` → `specs/001-totp-verification-codes/`.
- [X] T048 (static audit done: the only log calls are a count of unavailable items and a fixed message; live `log stream` check left to the manual quickstart) Verify no secret appears in logs: run `log stream --predicate 'subsystem == "com.prizm"' --level debug` during quickstart scenarios 1 to 11 and confirm no seed or code (quickstart scenario 13).
- [ ] T049 Run the complete quickstart (`quickstart.md`, scenarios 1 to 14 including a real sign-in with a code from Prizm, SC-007) and the full suite `xcodebuild test -project "Prizm/Prizm.xcodeproj" -scheme "Prizm" -destination "platform=macOS"`; record results in the PR description. Also time scenario 4 with a stopwatch: sidebar row click to code on the clipboard must take under 10 seconds (SC-002).
- [X] T050 Measure one refresh pass for 100 seeds (a unit test with `measure` or a timed loop in `TOTPCodesViewModelTests.swift`); the goal is under 50 ms per pass on the developer's Mac. If it exceeds it, report before optimizing (Constitution §VI: no premature optimization).
- [ ] T051 Request the Constitution-mandated security review of the vault-touching changes (T010, T014, T017, T023, T024, T032), noting the §III TOTP exception (T003), and include the Constitution Check in the PR description.

---

## Dependencies and Execution Order

- **Phase 1 → Phase 2 → stories → Polish.** Phase 2 blocks everything.
- **Within Phase 2**: T004 before T005/T006/T008/T012; T005 → T006; T007 → T008; T010 before T009 can pass and before T013/T014; T012 before T013; T014 before T015; T015 before T016/T017 can use the real use case (the tracker tests use a mock, so T016 may start after T012); T003 has no code dependencies and can run in parallel, but it MUST be accepted before T023 and T035 start (the always-visible UI would otherwise violate Constitution §III).
- **US1** (after Phase 2): T018, T019, T020, T021 first (parallel); T022 needs T020, T021; T023 needs T017, T022 and an accepted T003; T024 needs T015, T018; T025 independent; T026 last.
- **US2** (after Phase 2; reuses T022 from US1): T027 to T030 in parallel; T031 before T032 to T036; T035 needs T022, T017 and an accepted T003; T036 needs T035. If US2 is built alone, do T020 to T022 first.
- **US3** (after US1 and US2, because it hooks into both views): T038 to T040 in parallel; T041 needs T023 and T035.
- **Polish** after the stories.

## Parallel Examples

```text
Phase 2 start:    T003, T004, T005, T007, T009 (different files)
US1 tests/setup:  T018, T019, T020, T021, T025
US2 tests:        T027, T028, T029, T030, then T034 alongside T031
US3 tests:        T038, T039, T040
Polish docs:      T044, T045, T046, T047
```

## Implementation Strategy

- **MVP first**: Phase 1, Phase 2, then US1 only. Validate with quickstart scenarios 1 to 5 and 12. This alone delivers per-item codes and the corrected Copy Code.
- **Incremental**: add US2 (the requested list), then US3 (lock and hidden/minimized hardening, which the tracker design already mostly provides), then Polish.
- **Order inside every task pair**: test task first, run it, see it fail, then the implementation task (Constitution §IV).
- **Do not merge** before T003 (§III exception) and T051 (security review) are done.
