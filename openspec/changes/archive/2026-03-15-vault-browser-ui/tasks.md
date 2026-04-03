## 1. Project Setup

- [x] 1.1 Create Xcode project with App Sandbox + Hardened Runtime
- [x] 1.2 Add Argon2Swift as vendored local SPM package (`LocalPackages/Argon2Swift/`) via `XCLocalSwiftPackageReference`
- [x] 1.3 Create App layer files (`PrizmApp.swift`, `AppContainer.swift`, `Config.swift`)
- [x] 1.4 Create directory structure (`Domain/`, `Data/Crypto/`, `Data/Network/Models/`, `Data/Keychain/`, `Data/Mappers/`, `Data/Repositories/`, `Presentation/`, `Tests/`)

## 2. Domain Layer — Entities & Protocols

- [x] 2.1 Create `Account` + `ServerEnvironment` entities
- [x] 2.2 Create `KdfParams` entity (`KdfType` enum: pbkdf2/argon2id; iterations, memory?, parallelism?)
- [x] 2.3 Create `VaultItem` entity + `ItemContent` sum type + all content structs (`LoginContent`, `CardContent`, `IdentityContent`, `SecureNoteContent`, `SSHKeyContent`, `LoginURI`, `URIMatchType`)
- [x] 2.4 Create `CustomField` entity + `CustomFieldType` + `LinkedFieldId` with `displayName`
- [x] 2.5 Create `SidebarSelection` enum + `ItemType` enum
- [x] 2.6 Create `AuthRepository` protocol + `LoginResult` + `TwoFactorMethod` + `AuthError`
- [x] 2.7 Create `VaultRepository` protocol + `VaultError`
- [x] 2.8 Create `SyncRepository` protocol + `SyncResult` + `SyncError`
- [x] 2.9 Create use-case protocol stubs (`LoginUseCase`, `UnlockUseCase`, `SyncUseCase`, `SearchVaultUseCase`)
- [x] 2.10 Write unit tests for Domain entity validation rules (`ServerEnvironment` URL validation, `Account` email format, `CustomField` non-empty name)

## 3. Data Layer Foundation — Crypto, Keychain, Mapper

- [x] 3.1 Write failing unit tests for `KeychainService` (read/write/delete/notFound)
- [x] 3.2 Write failing unit tests for `EncString` parser (type-0, type-2, type-4 parse; MAC verify; decrypt round-trip with known test vectors)
- [x] 3.3 Write failing unit tests for `BitwardenCryptoServiceImpl` (PBKDF2-SHA256 key derivation, HKDF stretching, serverHash, symmetricKey decrypt from encUserKey, field decrypt round-trip)
- [x] 3.4 Write failing unit tests for `CipherMapper` (`RawCipher` → `VaultItem` for all 5 item types; personal cipher only; org cipher filtered)
- [x] 3.5 Implement `KeychainService` (SecItem read/write/delete, userId-namespaced keys, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- [x] 3.6 Implement `EncString` (parser for types 0, 2, 4, 6; AES-CBC-256 decrypt + HMAC-SHA256 verify; RSA-OAEP decrypt)
- [x] 3.7 Implement `RawCipher` + `SyncResponse` Codable models
- [x] 3.8 Implement `CipherMapper` (`RawCipher` → `VaultItem`; personal ciphers only; per-type field mapping for all 5 types)
- [x] 3.9 Implement `BitwardenCryptoServiceImpl` actor (PBKDF2/Argon2id KDF, HKDF key stretching, encUserKey → symmetricKey, encPrivateKey → RSAPrivateKey; `decryptList` + `decrypt` via `CipherMapper`; `lockVault` zeroes key material)

## 4. User Story 1 — Account Login

- [x] 4.1 Write failing unit tests: `AuthRepositoryImpl.loginWithPassword` (preLogin HTTP → hashPassword → identityToken → initializeUserCrypto)
- [x] 4.2 Write failing unit tests: `AuthRepositoryImpl.loginWithTOTP` (TOTP challenge flow + rememberDevice flag)
- [x] 4.3 Write failing unit tests: `SyncRepositoryImpl.sync()` (progress callbacks, personal-cipher-only `decryptList`, `SyncResult`)
- [x] 4.4 Write failing unit tests: `LoginUseCase` (full orchestration: preLogin → login → optional TOTP → sync)
- [x] 4.5 Implement `PrizmAPIClient` (URLSession; preLogin POST, identityToken POST form-encoded, sync GET; all required headers including `Device-Type` + `X-Device-Identifier`)
- [x] 4.6 Implement device identifier generation (UUID v4 on first launch, Keychain key `bw.macos:deviceIdentifier`)
- [x] 4.7 Implement `AuthRepositoryImpl`: `validateServerURL`, `setServerEnvironment`, `loginWithPassword`, `loginWithTOTP`
- [x] 4.8 Implement `SyncRepositoryImpl`: `sync()` with progress callbacks; personal ciphers only; graceful per-cipher failure
- [x] 4.9 Implement `LoginUseCaseImpl` + `SyncUseCaseImpl`
- [x] 4.10 Build `LoginView` + `LoginViewModel`
- [x] 4.11 Build `TOTPPromptView` (TOTP code input + "Remember this device" checkbox)
- [x] 4.12 Build `SyncProgressView` (full-screen, sequential status messages)
- [x] 4.13 Wire app state machine in `AppContainer` + `PrizmApp`
- [x] 4.14 XCUITest: full login journey (blank login screen → server URL + credentials → vault browser)

## 5. User Story 2 — Vault Unlock

- [x] 5.1 Write failing unit tests: `AuthRepositoryImpl.unlockWithPassword`
- [x] 5.2 Write failing unit tests: `AuthRepositoryImpl.signOut` (comprehensive)
- [x] 5.3 Write failing unit tests: `UnlockUseCase` (unlock orchestration, wrong password without vault lock)
- [x] 5.4 Implement `UnlockUseCaseImpl`
- [x] 5.5 Build `UnlockView` + `UnlockViewModel` + `RootViewModel` app state machine
- [x] 5.6 XCUITest: unlock journey (stored session → unlock screen → enter password → vault browser)

## 6. User Story 3 — Three-Pane Vault Browser

- [x] 6.1 Write failing unit tests: `VaultRepositoryImpl` — `allItems` (excludes isDeleted), `items(for: .favorites)`, `items(for: .type(.login))`, `itemCounts`
- [x] 6.2 Write failing unit tests: `MaskedFieldView` — always renders 8 dots; reveal toggle shows plaintext; item-change resets to masked
- [x] 6.3 Build `MaskedFieldView` + `MaskedFieldState` (exactly 8 dots when masked; plaintext on reveal; reset on item change)
- [x] 6.4 Build `FieldRowView` (hover-reveal for copy/reveal/open-in-browser actions; background highlight on hover)
- [x] 6.5 Implement `FaviconLoader` actor (GET `{ICONS_BASE}/{domain}/icon.png`; `NSCache` + `URLCache`; silent fallback on failure)
- [x] 6.6 Build `FaviconView` (loads via `FaviconLoader`; SF Symbol fallback per item type)
- [x] 6.7 Build `VaultBrowserView` + `VaultBrowserViewModel` (`NavigationSplitView` `.balanced`; sidebarSelection change resets itemSelection; search state; sync error banner state)
- [x] 6.8 Build `SidebarView` (All Items, Favorites; Types: Login/Card/Identity/SecureNote/SSHKey; live item counts; always visible)
- [x] 6.9 Build `ItemListView` + `ItemRowView` (sorted alphabetical case-insensitive; subtitle per type; favicon; favorite star; empty-state)
- [x] 6.10 Build `LoginDetailView` (username, password masked, each URI as independent row with copy + open-in-browser; notes; custom fields)
- [x] 6.11 Build `CardDetailView` (cardholder name, number masked, brand, expiry MM/YYYY, security code masked, notes, custom fields)
- [x] 6.12 Build `IdentityDetailView` (all fields; subtitle fallback chain firstName+lastName → email → blank; copy on hover)
- [x] 6.13 Build `SecureNoteDetailView` (note body, custom fields)
- [x] 6.14 Build `SSHKeyDetailView` (public key + fingerprint visible; private key masked; "[No fingerprint]" placeholder)
- [x] 6.15 Build `ItemDetailView` dispatcher + `CustomFieldsSection` (routes to type-specific view; "No item selected" empty state; creation + revision dates)
- [x] 6.16 Implement clipboard auto-clear (cancellable `Task.sleep` 30s; new copy cancels previous task)
- [x] 6.17 Add "Last synced: [time]" relative timestamp to toolbar
- [x] 6.18 XCUITest: vault browser journey (sidebar nav, item select, field reveal/mask, copy + clipboard clear, all item types)

## 7. User Story 4 — Search

- [x] 7.1 Write failing unit tests: `SearchVaultUseCase` (per-type field matching, category scoping, empty results, term preservation)
- [x] 7.2 Implement `SearchVaultUseCase` (in-memory `Array.filter` with `localizedCaseInsensitiveContains`; per-type fields; scoped to active `SidebarSelection`; no debounce)
- [x] 7.3 Wire search bar into `VaultBrowserViewModel` (real-time filtering; search term preserved on sidebar category change)
- [x] 7.4 XCUITest: search journey (type to filter, category switch preserves term, clear bar restores full list, empty state)

## 8. Polish & Cross-Cutting

- [x] 8.1 Wire Sign Out in macOS menu (File menu) + `NSAlert` confirmation; on confirm → `AuthRepository.signOut()` → blank `LoginView`
- [x] 8.2 Build sync error banner (system yellow tint, ≤44pt height, spans item list + detail columns, explicit × dismiss button, auto-dismiss on next successful sync)
- [x] 8.3 Add `os.Logger` calls to all auth, sync, vault, and network code paths (subsystem `com.prizm`; secrets MUST NOT appear in logs)
- [x] 8.4 Constitution check: audit every `catch {}` block; audit every file import for layer boundary violations; verify all crypto files have doc comments citing standards
- [x] 8.5 Create `SECURITY.md` at repo root (encrypted data + algorithms; key storage + access conditions; threat model; non-goals)
- [x] 8.6 Validate quickstart.md end-to-end from clean checkout (build + run all tests)
- [x] 8.7 XCUITest: keyboard-only navigation (Tab cycles panes; arrow keys navigate list; Enter selects; Escape returns focus)
