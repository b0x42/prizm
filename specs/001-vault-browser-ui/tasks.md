# Tasks: Bitwarden macOS Client — Core Vault Browser

**Input**: `specs/001-vault-browser-ui/` (plan.md, spec.md, data-model.md, contracts/, research.md)
**Branch**: `001-vault-browser-ui`
**TDD**: Tests are written first and must fail before implementation begins (constitution §IV)

## Terminology

| Term | Layer | Meaning |
|------|-------|---------|
| `VaultItem` | Domain | Decrypted domain entity (Swift type) |
| `RawCipher` | Data | Encrypted API model (Codable); input to CipherMapper |
| "item" | UI | User-facing label for a vault entry |
| "cipher" | API/docs | Bitwarden API term for an encrypted vault record; maps to `RawCipher` in code |

Use `VaultItem` in domain/presentation context. Use `RawCipher` / "cipher" only in Data layer (network models, mapper, crypto service).

---

## Format: `[ID] [P?] [Story?] Description — file path`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[US#]**: User story this task belongs to
- Write failing test → commit → implement → commit

---

## Phase 1: Setup (Slice 1 — no user-facing code)

**Purpose**: Xcode project, Argon2Swift dependency, directory structure.
No XCFramework required — crypto implemented natively via CommonCrypto + CryptoKit.

- [X] T001 Create Xcode project with App Sandbox + Hardened Runtime — `Bitwarden MacOS/Bitwarden MacOS.xcodeproj`
- [X] T002 Add Argon2Swift as vendored local SPM package (`LocalPackages/Argon2Swift/`) via `XCLocalSwiftPackageReference` in Xcode — `LocalPackages/Argon2Swift/Package.swift`
- [X] T003 [P] Create App layer files — `Bitwarden_MacOS/App/BitwardenMacOSApp.swift`, `AppContainer.swift`, `Config.swift`
- [X] T004 [P] Create directory structure — `Domain/`, `Data/Crypto/`, `Data/Network/Models/`, `Data/Keychain/`, `Data/Mappers/`, `Data/Repositories/`, `Presentation/`, `Tests/DomainTests/`, `Tests/DataTests/Crypto/`, `Tests/PresentationTests/Components/`, `Tests/UITests/` groups in Xcode

**Checkpoint**: Build succeeds. Empty test suite passes.

---

## Phase 2: Foundational — Domain Layer (Slice 2)

**Purpose**: All Domain entities and repository protocols. No SDK/SwiftUI imports. Must compile
with `Foundation` only. Blocks all user story work.

- [X] T005 [P] Create Account + ServerEnvironment entities — `Domain/Entities/Account.swift`, `Domain/Entities/ServerEnvironment.swift`
- [X] T005b [P] Create KdfParams entity (KdfType enum: pbkdf2/argon2id; KdfParams struct: type, iterations, memory?, parallelism?) — `Domain/Entities/KdfParams.swift`
- [X] T006 [P] Create VaultItem entity + ItemContent sum type + all content structs (LoginContent, CardContent, IdentityContent, SecureNoteContent, SSHKeyContent, LoginURI, URIMatchType) — `Domain/Entities/VaultItem.swift`
- [X] T007 [P] Create CustomField entity + CustomFieldType + LinkedFieldId with displayName — `Domain/Entities/CustomField.swift`
- [X] T008 [P] Create SidebarSelection enum + ItemType enum — `Domain/Entities/SidebarSelection.swift`
- [X] T009 [P] Create AuthRepository protocol + LoginResult + TwoFactorMethod + AuthError — `Domain/Repositories/AuthRepository.swift`
- [X] T010 [P] Create VaultRepository protocol + VaultError — `Domain/Repositories/VaultRepository.swift`
- [X] T011 [P] Create SyncRepository protocol + SyncResult + SyncError — `Domain/Repositories/SyncRepository.swift`
- [X] T012 Create UseCase protocol stubs (LoginUseCase, UnlockUseCase, SyncUseCase, SearchVaultUseCase) — `Domain/UseCases/`
- [X] T013 [P] Unit tests for Domain entity validation rules (ServerEnvironment URL validation, Account email format, CustomField non-empty name) — `Tests/DomainTests/Entities/`

**Checkpoint**: Domain compiles with `import Foundation` only. 100% of entity validation tests pass.

---

## Phase 3: Data Layer Foundation (Slice 3)

**Purpose**: Keychain service, EncString parser, native crypto service, cipher mapper.
Blocks all repository implementations. No external SDK dependency.

- [X] T014 [P] Write failing unit tests for KeychainService (read/write/delete/notFound) — `BitwardenMacOSTests/KeychainServiceTests.swift`
- [X] T015 [P] Write failing unit tests for EncString parser (type-0, type-2, type-4 parse; MAC verify; decrypt round-trip with known test vectors from Bitwarden security whitepaper) — `BitwardenMacOSTests/EncStringTests.swift`
- [X] T016 [P] Write failing unit tests for BitwardenCryptoServiceImpl (PBKDF2-SHA256 key derivation, HKDF stretching, serverHash, symmetricKey decrypt from encUserKey, field decrypt round-trip) — `BitwardenMacOSTests/BitwardenCryptoServiceTests.swift`
- [X] T017 [P] Write failing unit tests for CipherMapper (RawCipher → VaultItem for all 5 item types; personal cipher only; org cipher filtered) — `BitwardenMacOSTests/CipherMapperTests.swift`
- [X] T018 Implement KeychainService (SecItem read/write/delete, userId-namespaced keys, kSecAttrAccessibleWhenUnlockedThisDeviceOnly) — `Data/Keychain/KeychainService.swift`
- [X] T019 Implement EncString (parser for types 0, 2, 4, 6; AES-CBC-256 decrypt + HMAC-SHA256 verify; RSA-OAEP decrypt; each function MUST have doc comment citing Bitwarden Security Whitepaper section + RFC/NIST ref per §VII) — `Data/Crypto/EncString.swift`, `Data/Crypto/CryptoKeys.swift`
- [X] T020 Implement RawCipher + SyncResponse Codable models — `Data/Network/Models/RawCipher.swift`, `Data/Network/Models/SyncResponse.swift`
- [X] T021 Implement CipherMapper (RawCipher → VaultItem; personal ciphers only — skip organizationId != nil; per-type field mapping for all 5 types; doc comment on class explaining mapper role per §VII) — `Data/Mappers/CipherMapper.swift`
- [X] T022 Implement BitwardenCryptoServiceImpl actor (PBKDF2/Argon2id KDF, HKDF key stretching, encUserKey → symmetricKey, encPrivateKey → RSAPrivateKey; decryptList + decrypt via CipherMapper; lockVault zeroes key material; opening doc comment + per-function comments citing Bitwarden Security Whitepaper + RFC 5869 + NIST SP 800-132 per §VII) — `Data/Crypto/BitwardenCryptoService.swift`

**Checkpoint**: All crypto unit tests pass (including known-answer tests). Keychain integration test passes. CipherMapper tests pass for all 5 item types.

---

## Phase 4: User Story 1 — Account Login (Priority: P1) 🎯 MVP

**Goal**: First-time user enters self-hosted server URL + email + master password, completes TOTP
2FA if required, and reaches the vault browser.

**Independent Test**: Launch app with no stored session. Enter a valid self-hosted server URL,
log in with valid credentials (with and without TOTP), and reach the vault browser showing decrypted items.

### Tests (write first, must fail)

- [X] T023 [P] [US1] Failing unit test: AuthRepositoryImpl.loginWithPassword — preLogin HTTP → hashPassword → identityToken → initializeUserCrypto — `BitwardenMacOSTests/AuthRepositoryImplTests.swift`
- [X] T024 [P] [US1] Failing unit test: AuthRepositoryImpl.loginWithTOTP — TOTP challenge flow + rememberDevice flag — `BitwardenMacOSTests/AuthRepositoryImplTests.swift`
- [X] T025 [P] [US1] Failing unit test: SyncRepositoryImpl.sync() — progress callbacks, personal-cipher-only decryptList, SyncResult — `BitwardenMacOSTests/SyncRepositoryImplTests.swift`
- [X] T026 [P] [US1] Failing unit test: LoginUseCase — full orchestration (preLogin → login → optional TOTP → sync) — `BitwardenMacOSTests/LoginUseCaseTests.swift`

### Implementation

- [X] T027 [US1] Implement BitwardenAPIClient (URLSession; preLogin POST, identityToken POST form-encoded, sync GET; all required headers including Device-Type + X-Device-Identifier) — `Data/Network/BitwardenAPIClient.swift`
- [X] T028 [US1] Implement device identifier generation (UUID v4 on first launch, Keychain key `bw.macos:deviceIdentifier`) — `Data/Repositories/AuthRepositoryImpl.swift`
- [X] T029 [US1] Implement AuthRepositoryImpl: validateServerURL, setServerEnvironment, loginWithPassword, loginWithTOTP — `Data/Repositories/AuthRepositoryImpl.swift`
- [X] T030 [US1] Implement SyncRepositoryImpl: sync() with "Syncing vault…" + "Decrypting…" progress callbacks; personal ciphers only (skip org ciphers); graceful per-cipher failure — `Data/Repositories/SyncRepositoryImpl.swift`
- [X] T031 [US1] Implement LoginUseCaseImpl + SyncUseCaseImpl — `Data/UseCases/LoginUseCaseImpl.swift`, `Data/UseCases/SyncUseCaseImpl.swift`
- [X] T032 [P] [US1] Build LoginView + LoginViewModel — `Presentation/Login/LoginView.swift`, `Presentation/Login/LoginViewModel.swift`
- [X] T033 [P] [US1] Build TOTPPromptView (TOTP code input + "Remember this device" checkbox) — `Presentation/Login/TOTPPromptView.swift`
- [X] T034 [US1] Build SyncProgressView (full-screen, sequential status messages) — `Presentation/Sync/SyncProgressView.swift`
- [X] T035 [US1] Wire app state machine in AppContainer + BitwardenMacOSApp — `App/AppContainer.swift`, `App/Bitwarden_MacOSApp.swift`
- [ ] T036 [US1] XCUITest: full US1 login journey — blank login screen, enter server URL + credentials, reach vault browser (SC-001 ≤60s) — `Tests/UITests/LoginJourneyTests.swift`

**Checkpoint**: US1 acceptance scenarios 1–7 all pass. SC-001 passes. SC-006 passes (all error states covered).

---

## Phase 5: User Story 2 — Vault Unlock (Priority: P1)

**Goal**: Returning user quits and relaunches the app, sees the unlock screen with their stored
email, enters master password, and reaches the vault browser without a network request.

**Independent Test**: With a stored session, quit and relaunch the app. Confirm unlock screen
shows stored email. Enter correct password → vault browser. Enter wrong password → error without lock.

### Tests (write first, must fail)

- [ ] T037 [P] [US2] Failing unit test: AuthRepositoryImpl.unlockWithPassword — local KDF only, no network, encrypted keys from Keychain — `Tests/DataTests/Repositories/AuthRepositoryImplTests.swift`
- [ ] T038 [P] [US2] Failing unit test: AuthRepositoryImpl.signOut — all per-user Keychain keys cleared, activeUserId cleared, login screen blank — `Tests/DataTests/Repositories/AuthRepositoryImplTests.swift`
- [ ] T039 [P] [US2] Failing unit test: UnlockUseCase — unlock orchestration, wrong password returns error without locking vault — `Tests/DomainTests/UseCases/UnlockUseCaseTests.swift`

### Implementation

- [ ] T040 [US2] Implement AuthRepositoryImpl: unlockWithPassword (initializeUserCrypto from Keychain keys; no network), signOut (clear all per-user keys + activeUserId), lockVault (release crypto service key material) — `Data/Repositories/AuthRepositoryImpl.swift`
- [ ] T041 [US2] Implement UnlockUseCase — `Domain/UseCases/UnlockUseCase.swift`
- [ ] T042 [US2] Build UnlockView + UnlockViewModel (stored email read-only per FR-003, master password field, "Sign in with a different account" link per FR-039, error on wrong password without vault lock) — `Presentation/Auth/UnlockView.swift`, `Presentation/Auth/UnlockViewModel.swift`
- [ ] T043 [US2] XCUITest: US2 unlock journey — quit + relaunch, email shown, correct password unlocks, wrong password shows error, "different account" clears session — `Tests/UITests/UnlockJourneyTests.swift`

**Checkpoint**: US2 acceptance scenarios 1–4 pass. SC-002 passes (≤5s unlock). Vault locks on quit.

---

## Phase 6: User Story 3 — Three-Pane Vault Browser (Priority: P1)

**Goal**: Authenticated user navigates all items through a NavigationSplitView (sidebar / item list
/ detail), reveals and copies secret fields, and sees relative timestamps.

**Independent Test**: With a populated vault, select each sidebar entry, select items, confirm
all field types render correctly. Reveal/mask secrets. Copy fields, verify clipboard clears in 30s.

### Tests (write first, must fail)

- [ ] T044 [P] [US3] Failing unit tests: VaultRepositoryImpl — allItems (excludes isDeleted), items(for: .favorites), items(for: .type(.login)), itemCounts — `Tests/DataTests/Repositories/VaultRepositoryImplTests.swift`
- [ ] T045 [P] [US3] Failing unit tests: MaskedFieldView — always renders 8 dots; reveal toggle shows plaintext; item-change resets to masked — `Tests/PresentationTests/Components/MaskedFieldViewTests.swift`

### Implementation

- [ ] T046 [US3] Implement VaultRepositoryImpl: in-memory store populated by SyncRepositoryImpl; allItems (excludes isDeleted); items(for:) — .allItems, .favorites, .type; itemDetail (calls BitwardenCryptoServiceImpl.decrypt on demand); itemCounts cached post-sync; lastSyncedAt — `Data/Repositories/VaultRepositoryImpl.swift`
- [ ] T047 [P] [US3] Build MaskedFieldView (exactly 8 dots when masked; plaintext on reveal; @State isRevealed resets when item changes per FR-026, FR-027) — `Presentation/Components/MaskedFieldView.swift`
- [ ] T048 [P] [US3] Build FieldRowView (hover-reveal for copy/reveal/open-in-browser actions; background highlight on hover per FR-023) — `Presentation/Components/FieldRowView.swift`
- [ ] T049 [P] [US3] Implement FaviconLoader actor (GET {ICONS_BASE}/{domain}/icon.png; NSCache + URLCache; silent fallback on failure per research.md §6) — `Data/Network/FaviconLoader.swift`
- [ ] T050 [P] [US3] Build FaviconView (loads via FaviconLoader; SF Symbol fallback per item type per FR-009) — `Presentation/Components/FaviconView.swift`
- [ ] T051 [US3] Build VaultBrowserView + VaultBrowserViewModel (NavigationSplitView .balanced; .onChange(of: sidebarSelection) resets itemSelection; search state; sync error banner state) — `Presentation/Vault/VaultBrowserView.swift`, `Presentation/Vault/VaultBrowserViewModel.swift`
- [ ] T052 [US3] Build SidebarView (Menu Items: All Items + Favorites; Types: Login/Card/Identity/SecureNote/SSHKey; live item counts; always visible even when empty per FR-006, FR-042) — `Presentation/Vault/Sidebar/SidebarView.swift`
- [ ] T053 [US3] Build ItemListView + ItemRowView (sorted alphabetical case-insensitive per FR-040; subtitle per type per FR-021; favicon; favorite star per FR-022; empty-state message per FR-042) — `Presentation/Vault/ItemList/ItemListView.swift`, `Presentation/Vault/ItemList/ItemRowView.swift`
- [ ] T054 [P] [US3] Build LoginDetailView (username, password masked, each URI as independent row with copy + open-in-browser per FR-025; notes; custom fields per FR-029) — `Presentation/Vault/Detail/LoginDetailView.swift`
- [ ] T055 [P] [US3] Build CardDetailView (cardholder name, number masked, brand, expiry MM/YYYY, security code masked, notes, custom fields) — `Presentation/Vault/Detail/CardDetailView.swift`
- [ ] T056 [P] [US3] Build IdentityDetailView (all fields per data-model.md; subtitle fallback chain firstName+lastName → email → blank per FR-046; copy on hover per FR-030) — `Presentation/Vault/Detail/IdentityDetailView.swift`
- [ ] T057 [P] [US3] Build SecureNoteDetailView (note body, custom fields) — `Presentation/Vault/Detail/SecureNoteDetailView.swift`
- [ ] T058 [P] [US3] Build SSHKeyDetailView (public key + fingerprint visible; private key masked; "[No fingerprint]" placeholder per FR-047) — `Presentation/Vault/Detail/SSHKeyDetailView.swift`
- [ ] T059 [US3] Build ItemDetailView dispatcher (routes to type-specific view; "No item selected" empty state per FR-034; creation + revision dates per FR-031) — `Presentation/Vault/Detail/ItemDetailView.swift`
- [ ] T060 [US3] Implement clipboard auto-clear: cancellable Task.sleep 30s; new copy cancels previous task; vault lock does not cancel (best-effort on quit per FR-011) — `Presentation/Vault/VaultBrowserViewModel.swift`
- [ ] T061 [US3] Add "Last synced: [time]" relative timestamp to toolbar (RelativeDateTimeFormatter; updates on successful sync only per FR-037, FR-041) — `Presentation/Vault/VaultBrowserView.swift`
- [ ] T062 [US3] XCUITest: US3 vault browser journey — sidebar nav, item select, field reveal/mask, copy + clipboard clear, all item types render correctly (SC-003, SC-005 at 1,000 items) — `Tests/UITests/VaultBrowserJourneyTests.swift`

**Checkpoint**: All 14 US3 acceptance scenarios pass. SC-003, SC-004, SC-005 pass. 1,000-item vault renders without lag.

---

## Phase 7: User Story 4 — Search (Priority: P1)

**Goal**: User types in the search bar and the item list immediately filters to matching results
within the active sidebar category, with the term preserved on category switch.

**Independent Test**: With a populated vault, type a partial item name. Confirm only matching
items appear instantly. Switch category — term preserved, results re-filtered. Clear bar — all items restored.

### Tests (write first, must fail)

- [ ] T063 [P] [US4] Failing unit tests: SearchVaultUseCase — per-type field matching (Login: username+URI, Card: cardholderName, Identity: email+company, SSH Key: name only), category scoping, empty results, term preservation — `Tests/DomainTests/UseCases/SearchVaultUseCaseTests.swift`

### Implementation

- [ ] T064 [US4] Implement SearchVaultUseCase (in-memory Array.filter with localizedCaseInsensitiveContains; per-type fields per FR-012; scoped to active SidebarSelection; no debounce) — `Domain/UseCases/SearchVaultUseCase.swift`
- [ ] T065 [US4] Wire search bar into VaultBrowserViewModel (real-time filtering on every keystroke; search term preserved on .onChange(of: sidebarSelection); re-filter against new category) — `Presentation/Vault/VaultBrowserViewModel.swift`
- [ ] T066 [US4] XCUITest: US4 search journey — type to filter, category switch preserves term, clear bar restores full list, empty state on no match (SC-008 <100ms per keystroke) — `Tests/UITests/SearchJourneyTests.swift`

**Checkpoint**: All 6 US4 acceptance scenarios pass. SC-008 passes (<100ms per keystroke, 1,000 items).

---

## Phase 8: Polish & Cross-Cutting Concerns (Slice 8)

**Purpose**: Sign-out, sync error banner, observability, final constitution check.

- [ ] T067 Wire Sign Out in macOS menu (File or app menu) + NSAlert confirmation dialog ("All local data will be cleared"); on confirm → AuthRepository.signOut() → blank LoginView (FR-014) — `App/AppContainer.swift`
- [ ] T068 [P] Build sync error banner (systemYellow tint, ≤44pt height, spans item list + detail columns, explicit × dismiss button, auto-dismiss on next successful sync; no retry button per FR-049) — `Presentation/Vault/VaultBrowserView.swift`
- [ ] T069 [P] Add os.Logger calls to all auth, sync, vault, and network code paths (subsystem `com.bitwarden-macos`; .debug trace, .info flow, .error recoverable, .fault unrecoverable; secrets MUST NOT appear in logs) — all Data/ files
- [ ] T070 Constitution check: audit every `catch {}` block — each must rethrow or log + surface via typed Error; audit every file import — Domain must have no crypto/SwiftUI, Presentation must have no Data; verify all crypto files have doc comments citing standards per §VII — all source files
- [ ] T071 [P] Create SECURITY.md at repo root (same level as CLAUDE.md and CONSTITUTION.md, not in specs/): what data is encrypted + algorithm; where keys are stored + access conditions; threat model; explicit non-goals (per CONSTITUTION.md §VII) — `SECURITY.md`
- [ ] T072 [P] Validate quickstart.md end-to-end from clean checkout (build + run all tests) — `specs/001-vault-browser-ui/quickstart.md`
- [ ] T073 [P] XCUITest: keyboard-only navigation — Tab cycles between sidebar/list/detail panes; arrow keys navigate the item list; Enter selects focused item; Escape returns focus to list; verify all interactive elements (buttons, fields) are keyboard-accessible (SC-007) — `Tests/UITests/KeyboardNavigationTests.swift`

**Checkpoint**: SC-004 passes (clipboard clears ≤30s). No swallowed errors. All import rules respected. Sign-out clears all data and shows blank login screen.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    └── Phase 2 (Domain)
            └── Phase 3 (Data Foundation)
                    └── Phase 4 (US1 Login)
                            └── Phase 5 (US2 Unlock)
                                    └── Phase 6 (US3 Browser)
                                            └── Phase 7 (US4 Search)
                                                    └── Phase 8 (Polish)
```

User stories build sequentially — each story depends on the previous (US3 browser requires
US1+US2 auth to complete; US4 search is wired into the US3 browser). This is inherent to the
architecture: the vault browser cannot exist without authentication.

### Parallel Opportunities Per Phase

All [P]-marked tasks within a phase can be launched simultaneously:

```
# Phase 2 — all Domain entities in parallel:
T005 Account.swift  |  T005b KdfParams.swift  |  T006 VaultItem.swift  |  T007 CustomField.swift
T008 SidebarSelection.swift  |  T009 AuthRepository.swift
T010 VaultRepository.swift  |  T011 SyncRepository.swift

# Phase 4 — tests first in parallel, then implementation:
T023 + T024 + T025 + T026 (failing tests)  →  T027 → T028 → T029 ...
T032 LoginView  |  T033 TOTPPromptView  (parallel after T031)

# Phase 6 — components in parallel after T046 VaultRepositoryImpl:
T047 MaskedFieldView  |  T048 FieldRowView  |  T049 FaviconLoader  |  T050 FaviconView
T054 LoginDetailView  |  T055 CardDetailView  |  T056 IdentityDetailView
T057 SecureNoteDetailView  |  T058 SSHKeyDetailView
```

---

## Implementation Strategy

### MVP First (Slices 1–4: login only)

1. Complete Phase 1 — Xcode scaffold + Argon2Swift SPM dependency (unblocks everything)
2. Complete Phase 2 — Domain layer (pure Swift, no dependencies)
3. Complete Phase 3 — Data foundation (Keychain + native crypto + mapper)
4. Complete Phase 4 — US1 login flow
5. **STOP AND VALIDATE**: Can log in and reach a stub vault browser
6. Proceed to US2, US3, US4 in order

### TDD Discipline (constitution §IV)

For each phase: write all failing tests first → commit → implement → confirm tests pass → commit.
Never write implementation before the test exists and fails.

---

## Task Summary

| Phase | Tasks | [P] tasks | Story |
|-------|-------|-----------|-------|
| Phase 1: Setup | T001–T004 | 2 | — |
| Phase 2: Domain | T005, T005b, T006–T013 | 10 | — |
| Phase 3: Data Foundation | T014–T022 | 4 | — |
| Phase 4: US1 Login | T023–T036 | 8 | US1 |
| Phase 5: US2 Unlock | T037–T043 | 3 | US2 |
| Phase 6: US3 Browser | T044–T062 | 13 | US3 |
| Phase 7: US4 Search | T063–T066 | 1 | US4 |
| Phase 8: Polish | T067–T072 | 4 | — |
| **Total** | **74** | **44** | |
