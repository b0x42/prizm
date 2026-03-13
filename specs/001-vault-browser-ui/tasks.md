# Tasks: Bitwarden macOS Client — Core Vault Browser

**Input**: `specs/001-vault-browser-ui/` (plan.md, spec.md, data-model.md, contracts/, research.md)
**Branch**: `001-vault-browser-ui`
**TDD**: Tests are written first and must fail before implementation begins (constitution §IV)

## Format: `[ID] [P?] [Story?] Description — file path`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[US#]**: User story this task belongs to
- Write failing test → commit → implement → commit

---

## Phase 1: Setup (Slice 1 — no user-facing code)

**Purpose**: Xcode project, BitwardenSdk macOS XCFramework, directory structure.

**⚠️ OI-001 BLOCKER**: The official `sdk-swift` package has no macOS slice. Task T001 must
complete before any Data layer work begins. See `specs/001-vault-browser-ui/sdk-macos-build.md`.

- [ ] T001 Build macOS XCFramework from Rust source and fork sdk-swift — `sdk-macos-build.md` steps 1–8
- [ ] T002 Create Xcode project with App Sandbox + Hardened Runtime — `Bitwarden_MacOS/Bitwarden_MacOS.xcodeproj`
- [ ] T003 Add forked BitwardenSdk as SPM binary target in Xcode — project Package Dependencies
- [ ] T004 [P] Verify macOS XCFramework slice — `lipo -info` must show `arm64 x86_64` (plan.md gate)
- [ ] T005 [P] Create App layer files — `Bitwarden_MacOS/App/BitwardenMacOSApp.swift`, `AppContainer.swift`, `Config.swift`

**Checkpoint**: `lipo -info` passes. Project builds. Empty test suite passes.

---

## Phase 2: Foundational — Domain Layer (Slice 2)

**Purpose**: All Domain entities and repository protocols. No SDK/SwiftUI imports. Must compile
with `Foundation` only. Blocks all user story work.

- [ ] T006 [P] Create Account + ServerEnvironment entities — `Domain/Entities/Account.swift`, `Domain/Entities/ServerEnvironment.swift`
- [ ] T007 [P] Create VaultItem entity + ItemContent sum type + all content structs (LoginContent, CardContent, IdentityContent, SecureNoteContent, SSHKeyContent, LoginURI, URIMatchType) — `Domain/Entities/VaultItem.swift`
- [ ] T008 [P] Create CustomField entity + CustomFieldType + LinkedFieldId with displayName — `Domain/Entities/CustomField.swift`
- [ ] T009 [P] Create SidebarSelection enum + ItemType enum — `Domain/Entities/SidebarSelection.swift`
- [ ] T010 [P] Create AuthRepository protocol + LoginResult + TwoFactorMethod + AuthError — `Domain/Repositories/AuthRepository.swift`
- [ ] T011 [P] Create VaultRepository protocol + VaultError — `Domain/Repositories/VaultRepository.swift`
- [ ] T012 [P] Create SyncRepository protocol + SyncResult + SyncError — `Domain/Repositories/SyncRepository.swift`
- [ ] T013 Create UseCase protocol stubs (LoginUseCase, UnlockUseCase, SyncUseCase, SearchVaultUseCase) — `Domain/UseCases/`
- [ ] T014 [P] Unit tests for Domain entity validation rules (ServerEnvironment URL validation, Account email format, CustomField non-empty name) — `Tests/DomainTests/Entities/`

**Checkpoint**: Domain compiles with `import Foundation` only. 100% of entity validation tests pass.

---

## Phase 3: Data Layer Foundation (Slice 3)

**Purpose**: Keychain service, SDK client wrapper, cipher mapper. Blocks all repository implementations.
Requires T001 (XCFramework) to be complete.

- [ ] T015 [P] Write failing unit test for KeychainService (read/write/delete/notFound) — `Tests/DataTests/Repositories/KeychainServiceTests.swift`
- [ ] T016 [P] Write failing unit tests for CipherMapper (CipherListView → VaultItem, CipherView → VaultItem detail, all 5 item types) — `Tests/DataTests/Mappers/CipherMapperTests.swift`
- [ ] T017 [P] Implement KeychainService (SecItem read/write/delete, userId-namespaced keys, kSecAttrAccessibleWhenUnlockedThisDeviceOnly) — `Data/Keychain/KeychainService.swift`
- [ ] T018 [P] Implement BitwardenClientService actor (owns SDK Client, initializeUserCrypto, lockVault releases Client to nil) — `Data/SDK/BitwardenClientService.swift`
- [ ] T019 Implement CipherMapper (CipherListView → VaultItem list weight; CipherView → VaultItem detail; personal ciphers only — skip organizationId != nil) — `Data/Mappers/CipherMapper.swift`

**Checkpoint**: KeychainService and CipherMapper unit tests pass. SDK Client lifecycle verified in integration test.

---

## Phase 4: User Story 1 — Account Login (Priority: P1) 🎯 MVP

**Goal**: First-time user enters self-hosted server URL + email + master password, completes TOTP
2FA if required, and reaches the vault browser.

**Independent Test**: Launch app with no stored session. Enter a valid self-hosted server URL,
log in with valid credentials (with and without TOTP), and reach the vault browser showing decrypted items.

### Tests (write first, must fail)

- [ ] T020 [P] [US1] Failing unit test: AuthRepositoryImpl.loginWithPassword — preLogin HTTP → hashPassword → identityToken → initializeUserCrypto — `Tests/DataTests/Repositories/AuthRepositoryImplTests.swift`
- [ ] T021 [P] [US1] Failing unit test: AuthRepositoryImpl.loginWithTOTP — TOTP challenge flow + rememberDevice flag — `Tests/DataTests/Repositories/AuthRepositoryImplTests.swift`
- [ ] T022 [P] [US1] Failing unit test: SyncRepositoryImpl.sync() — progress callbacks, personal-cipher-only decryptList, SyncResult — `Tests/DataTests/Repositories/SyncRepositoryImplTests.swift`
- [ ] T023 [P] [US1] Failing unit test: LoginUseCase — full orchestration (preLogin → login → optional TOTP → sync) — `Tests/DomainTests/UseCases/LoginUseCaseTests.swift`

### Implementation

- [ ] T024 [US1] Implement BitwardenAPIClient (URLSession; preLogin POST, identityToken POST form-encoded, sync GET; all required headers including Device-Type + X-Device-Identifier) — `Data/Network/BitwardenAPIClient.swift`
- [ ] T025 [US1] Implement device identifier generation (UUID v4 on first launch, Keychain key `bw.macos:deviceIdentifier`) — `Data/Repositories/AuthRepositoryImpl.swift`
- [ ] T026 [US1] Implement AuthRepositoryImpl: validateServerURL, setServerEnvironment, loginWithPassword, loginWithTOTP — `Data/Repositories/AuthRepositoryImpl.swift`
- [ ] T027 [US1] Implement SyncRepositoryImpl: sync() with "Syncing vault…" + "Decrypting…" progress callbacks; personal ciphers only (skip org ciphers); graceful per-cipher failure — `Data/Repositories/SyncRepositoryImpl.swift`
- [ ] T028 [US1] Implement LoginUseCase + SyncUseCase — `Domain/UseCases/LoginUseCase.swift`, `Domain/UseCases/SyncUseCase.swift`
- [ ] T029 [P] [US1] Build LoginView + LoginViewModel (server URL field with validation on blur, email, master password, inline error states per FR-001, FR-013) — `Presentation/Auth/LoginView.swift`, `Presentation/Auth/LoginViewModel.swift`
- [ ] T030 [P] [US1] Build TOTPPromptView (TOTP code input + "Remember this device" checkbox defaulting to unchecked per FR-050; unsupported 2FA method error state per FR-016) — `Presentation/Auth/TOTPPromptView.swift`
- [ ] T031 [US1] Build SyncProgressView (full-screen, sequential status messages, replaces login screen, error state with retry on failure per FR-036) — `Presentation/Auth/SyncProgressView.swift`
- [ ] T032 [US1] Wire app state machine in AppContainer + BitwardenMacOSApp (no session → LoginView; session exists → UnlockView; post-login → SyncProgressView → VaultBrowserView) — `App/AppContainer.swift`, `App/BitwardenMacOSApp.swift`
- [ ] T033 [US1] XCUITest: full US1 login journey — blank login screen, enter server URL + credentials, reach vault browser (SC-001 ≤60s) — `Tests/UITests/LoginJourneyTests.swift`

**Checkpoint**: US1 acceptance scenarios 1–7 all pass. SC-001 passes. SC-006 passes (all error states covered).

---

## Phase 5: User Story 2 — Vault Unlock (Priority: P1)

**Goal**: Returning user quits and relaunches the app, sees the unlock screen with their stored
email, enters master password, and reaches the vault browser without a network request.

**Independent Test**: With a stored session, quit and relaunch the app. Confirm unlock screen
shows stored email. Enter correct password → vault browser. Enter wrong password → error without lock.

### Tests (write first, must fail)

- [ ] T034 [P] [US2] Failing unit test: AuthRepositoryImpl.unlockWithPassword — local KDF only, no network, encrypted keys from Keychain — `Tests/DataTests/Repositories/AuthRepositoryImplTests.swift`
- [ ] T035 [P] [US2] Failing unit test: AuthRepositoryImpl.signOut — all per-user Keychain keys cleared, activeUserId cleared, login screen blank — `Tests/DataTests/Repositories/AuthRepositoryImplTests.swift`
- [ ] T036 [P] [US2] Failing unit test: UnlockUseCase — unlock orchestration, wrong password returns error without locking vault — `Tests/DomainTests/UseCases/UnlockUseCaseTests.swift`

### Implementation

- [ ] T037 [US2] Implement AuthRepositoryImpl: unlockWithPassword (initializeUserCrypto from Keychain keys; no network), signOut (clear all per-user keys + activeUserId), lockVault (release SDK Client) — `Data/Repositories/AuthRepositoryImpl.swift`
- [ ] T038 [US2] Implement UnlockUseCase — `Domain/UseCases/UnlockUseCase.swift`
- [ ] T039 [US2] Build UnlockView + UnlockViewModel (stored email read-only per FR-003, master password field, "Sign in with a different account" link per FR-039, error on wrong password without vault lock) — `Presentation/Auth/UnlockView.swift`, `Presentation/Auth/UnlockViewModel.swift`
- [ ] T040 [US2] XCUITest: US2 unlock journey — quit + relaunch, email shown, correct password unlocks, wrong password shows error, "different account" clears session — `Tests/UITests/UnlockJourneyTests.swift`

**Checkpoint**: US2 acceptance scenarios 1–4 pass. SC-002 passes (≤5s unlock). Vault locks on quit.

---

## Phase 6: User Story 3 — Three-Pane Vault Browser (Priority: P1)

**Goal**: Authenticated user navigates all items through a NavigationSplitView (sidebar / item list
/ detail), reveals and copies secret fields, and sees relative timestamps.

**Independent Test**: With a populated vault, select each sidebar entry, select items, confirm
all field types render correctly. Reveal/mask secrets. Copy fields, verify clipboard clears in 30s.

### Tests (write first, must fail)

- [ ] T041 [P] [US3] Failing unit tests: VaultRepositoryImpl — allItems (excludes isDeleted), items(for: .favorites), items(for: .type(.login)), itemCounts — `Tests/DataTests/Repositories/VaultRepositoryImplTests.swift`
- [ ] T042 [P] [US3] Failing unit tests: MaskedFieldView — always renders 8 dots; reveal toggle shows plaintext; item-change resets to masked — `Tests/DomainTests/Entities/MaskedFieldTests.swift`

### Implementation

- [ ] T043 [US3] Implement VaultRepositoryImpl: in-memory store populated by SyncRepositoryImpl; allItems (excludes isDeleted); items(for:) — .allItems, .favorites, .type; itemDetail (calls SDK decrypt on demand); itemCounts cached post-sync; lastSyncedAt — `Data/Repositories/VaultRepositoryImpl.swift`
- [ ] T044 [P] [US3] Build MaskedFieldView (exactly 8 dots when masked; plaintext on reveal; @State isRevealed resets when item changes per FR-026, FR-027) — `Presentation/Components/MaskedFieldView.swift`
- [ ] T045 [P] [US3] Build FieldRowView (hover-reveal for copy/reveal/open-in-browser actions; background highlight on hover per FR-023) — `Presentation/Components/FieldRowView.swift`
- [ ] T046 [P] [US3] Implement FaviconLoader actor (GET {ICONS_BASE}/{domain}/icon.png; NSCache + URLCache; silent fallback on failure per research.md §6) — `Data/Network/FaviconLoader.swift`
- [ ] T047 [P] [US3] Build FaviconView (loads via FaviconLoader; SF Symbol fallback per item type per FR-009) — `Presentation/Components/FaviconView.swift`
- [ ] T048 [US3] Build VaultBrowserView + VaultBrowserViewModel (NavigationSplitView .balanced; .onChange(of: sidebarSelection) resets itemSelection; search state; sync error banner state) — `Presentation/Vault/VaultBrowserView.swift`, `Presentation/Vault/VaultBrowserViewModel.swift`
- [ ] T049 [US3] Build SidebarView (Menu Items: All Items + Favorites; Types: Login/Card/Identity/SecureNote/SSHKey; live item counts; always visible even when empty per FR-006, FR-042) — `Presentation/Vault/Sidebar/SidebarView.swift`
- [ ] T050 [US3] Build ItemListView + ItemRowView (sorted alphabetical case-insensitive per FR-040; subtitle per type per FR-021; favicon; favorite star per FR-022; empty-state message per FR-042) — `Presentation/Vault/ItemList/ItemListView.swift`, `Presentation/Vault/ItemList/ItemRowView.swift`
- [ ] T051 [P] [US3] Build LoginDetailView (username, password masked, each URI as independent row with copy + open-in-browser per FR-025; notes; custom fields per FR-029) — `Presentation/Vault/Detail/LoginDetailView.swift`
- [ ] T052 [P] [US3] Build CardDetailView (cardholder name, number masked, brand, expiry MM/YYYY, security code masked, notes, custom fields) — `Presentation/Vault/Detail/CardDetailView.swift`
- [ ] T053 [P] [US3] Build IdentityDetailView (all fields per data-model.md; subtitle fallback chain firstName+lastName → email → blank per FR-046; copy on hover per FR-030) — `Presentation/Vault/Detail/IdentityDetailView.swift`
- [ ] T054 [P] [US3] Build SecureNoteDetailView (note body, custom fields) — `Presentation/Vault/Detail/SecureNoteDetailView.swift`
- [ ] T055 [P] [US3] Build SSHKeyDetailView (public key + fingerprint visible; private key masked; "[No fingerprint]" placeholder per FR-047) — `Presentation/Vault/Detail/SSHKeyDetailView.swift`
- [ ] T056 [US3] Build ItemDetailView dispatcher (routes to type-specific view; "No item selected" empty state per FR-034; creation + revision dates per FR-031) — `Presentation/Vault/Detail/ItemDetailView.swift`
- [ ] T057 [US3] Implement clipboard auto-clear: cancellable Task.sleep 30s; new copy cancels previous task; vault lock does not cancel (best-effort on quit per FR-011) — `Presentation/Vault/VaultBrowserViewModel.swift`
- [ ] T058 [US3] Add "Last synced: [time]" relative timestamp to toolbar (RelativeDateTimeFormatter; updates on successful sync only per FR-037, FR-041) — `Presentation/Vault/VaultBrowserView.swift`
- [ ] T059 [US3] XCUITest: US3 vault browser journey — sidebar nav, item select, field reveal/mask, copy + clipboard clear, all item types render correctly (SC-003, SC-005 at 1,000 items) — `Tests/UITests/VaultBrowserJourneyTests.swift`

**Checkpoint**: All 14 US3 acceptance scenarios pass. SC-003, SC-004, SC-005 pass. 1,000-item vault renders without lag.

---

## Phase 7: User Story 4 — Search (Priority: P1)

**Goal**: User types in the search bar and the item list immediately filters to matching results
within the active sidebar category, with the term preserved on category switch.

**Independent Test**: With a populated vault, type a partial item name. Confirm only matching
items appear instantly. Switch category — term preserved, results re-filtered. Clear bar — all items restored.

### Tests (write first, must fail)

- [ ] T060 [P] [US4] Failing unit tests: SearchVaultUseCase — per-type field matching (Login: username+URI, Card: cardholderName, Identity: email+company, SSH Key: name only), category scoping, empty results, term preservation — `Tests/DomainTests/UseCases/SearchVaultUseCaseTests.swift`

### Implementation

- [ ] T061 [US4] Implement SearchVaultUseCase (in-memory Array.filter with localizedCaseInsensitiveContains; per-type fields per FR-012; scoped to active SidebarSelection; no debounce) — `Domain/UseCases/SearchVaultUseCase.swift`
- [ ] T062 [US4] Wire search bar into VaultBrowserViewModel (real-time filtering on every keystroke; search term preserved on .onChange(of: sidebarSelection); re-filter against new category) — `Presentation/Vault/VaultBrowserViewModel.swift`
- [ ] T063 [US4] XCUITest: US4 search journey — type to filter, category switch preserves term, clear bar restores full list, empty state on no match (SC-008 <100ms per keystroke) — `Tests/UITests/SearchJourneyTests.swift`

**Checkpoint**: All 6 US4 acceptance scenarios pass. SC-008 passes (<100ms per keystroke, 1,000 items).

---

## Phase 8: Polish & Cross-Cutting Concerns (Slice 8)

**Purpose**: Sign-out, sync error banner, observability, final constitution check.

- [ ] T064 Wire Sign Out in macOS menu (File or app menu) + NSAlert confirmation dialog ("All local data will be cleared"); on confirm → AuthRepository.signOut() → blank LoginView (FR-014) — `App/AppContainer.swift`
- [ ] T065 [P] Build sync error banner (systemYellow tint, ≤44pt height, spans item list + detail columns, explicit × dismiss button, auto-dismiss on next successful sync; no retry button per FR-049) — `Presentation/Vault/VaultBrowserView.swift`
- [ ] T066 [P] Add os.Logger calls to all auth, sync, vault, and network code paths (subsystem `com.bitwarden-macos`; .debug trace, .info flow, .error recoverable, .fault unrecoverable; secrets MUST NOT appear in logs) — all Data/ files
- [ ] T067 Constitution check: audit every `catch {}` block — each must rethrow or log + surface via typed Error; audit every file import — Domain must have no SDK/SwiftUI, Presentation must have no Data/SDK — all source files
- [ ] T068 [P] Validate quickstart.md end-to-end from clean checkout (build + run all tests) — `specs/001-vault-browser-ui/quickstart.md`

**Checkpoint**: SC-004 passes (clipboard clears ≤30s). No swallowed errors. All import rules respected. Sign-out clears all data and shows blank login screen.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    └── Phase 2 (Domain)
            └── Phase 3 (Data Foundation)  ← also requires T001 (XCFramework)
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
T006 Account.swift  |  T007 VaultItem.swift  |  T008 CustomField.swift
T009 SidebarSelection.swift  |  T010 AuthRepository.swift
T011 VaultRepository.swift  |  T012 SyncRepository.swift

# Phase 4 — tests first in parallel, then implementation:
T020 + T021 + T022 + T023 (failing tests)  →  T024 → T025 → T026 ...
T029 LoginView  |  T030 TOTPPromptView  (parallel after T028)

# Phase 6 — components in parallel after T043 VaultRepositoryImpl:
T044 MaskedFieldView  |  T045 FieldRowView  |  T046 FaviconLoader  |  T047 FaviconView
T051 LoginDetailView  |  T052 CardDetailView  |  T053 IdentityDetailView
T054 SecureNoteDetailView  |  T055 SSHKeyDetailView
```

---

## Implementation Strategy

### MVP First (Slices 1–4: login only)

1. Complete Phase 1 — Xcode scaffold + XCFramework (unblocks everything)
2. Complete Phase 2 — Domain layer (pure Swift, no dependencies)
3. Complete Phase 3 — Data foundation (Keychain + SDK + Mapper)
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
| Phase 1: Setup | T001–T005 | 2 | — |
| Phase 2: Domain | T006–T014 | 9 | — |
| Phase 3: Data Foundation | T015–T019 | 4 | — |
| Phase 4: US1 Login | T020–T033 | 8 | US1 |
| Phase 5: US2 Unlock | T034–T040 | 3 | US2 |
| Phase 6: US3 Browser | T041–T059 | 13 | US3 |
| Phase 7: US4 Search | T060–T063 | 1 | US4 |
| Phase 8: Polish | T064–T068 | 3 | — |
| **Total** | **68** | **43** | |
