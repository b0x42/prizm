# Implementation Plan: Bitwarden macOS Client — Core Vault Browser

**Branch**: `001-vault-browser-ui` | **Date**: 2026-03-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-vault-browser-ui/spec.md`

---

## Summary

Build a read-only macOS Bitwarden vault browser with account login (email + master password +
TOTP 2FA), vault unlock, and a three-pane `NavigationSplitView` UI (sidebar / item list /
detail pane) with real-time search scoped to the active category.

The implementation follows Clean Architecture (Presentation → Domain ← Data) with BitwardenSdk
(`sdk-swift`) as the exclusive crypto and vault-decryption engine, wrapped entirely in the Data
layer. The app is a thin integration layer — no custom Bitwarden crypto.

---

## Technical Context

**Language/Version**: Swift 5.10 (latest stable as of 2026)
**UI Framework**: SwiftUI with `NavigationSplitView` (macOS 13+)
**Concurrency**: Swift async/await + Structured Concurrency
**Primary Dependencies**:
- `BitwardenSdk` (sdk-swift) — canonical crypto + vault entity library (SPM binary target)
- No other external dependencies in v1

**Storage**:
- macOS Keychain — session tokens, account metadata (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- In-memory only for decrypted vault data (SDK `Client` object holds key material)
- `UserDefaults` — non-sensitive UI preferences only (last sidebar selection, server region display)

**Testing**: XCTest (unit + integration), XCUITest (UI journeys)
**Target Platform**: macOS 14 (Sonoma, primary) + macOS 13 (Ventura, n-1 per constitution)
**Server Support**: Self-hosted Bitwarden and Vaultwarden only. Bitwarden cloud (US/EU) deferred to a future version. No client registration required for v1.
**Project Type**: macOS desktop application (App Sandbox + Hardened Runtime)
**Performance Goals**: Vault unlock + decrypt ≤5s for 1,000 items; search filter <100ms per keystroke
**Constraints**: ATS enabled; no iCloud secret sync; Keychain-only secret storage
**Scale/Scope**: Single user account, single vault, up to 1,000 items for v1

---

## Constitution Check

*GATE: Verified before Phase 0. Re-verified post Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Native-First: Swift + SwiftUI + async/await only | ✅ | `NavigationSplitView` for three-pane; AppKit not needed |
| II | Clean Architecture: Presentation → Domain ← Data (no layer bypass) | ✅ | See Project Structure; enforced via import rules |
| III | Security-First: BitwardenSdk for all Bitwarden-protocol crypto (no direct CryptoKit) | ✅ | SDK wraps all KDF, cipher decrypt, reprompt verify |
| IV | TDD: tests written & failing before implementation | ✅ | Domain use cases + Data mappers: test-first; UI: snapshot tests |
| V | Observability: structured os.Logger, no swallowed errors | ✅ | Auth, sync, and cipher errors all surface via typed `Error` |
| VI | Simplicity, YAGNI & Thin Layer: no custom code when a trusted library exists | ✅ | No custom crypto; no custom three-pane split (NavigationSplitView); no third-party networking (URLSession) |

**No violations. All gates pass.**

---

## Project Structure

### Documentation (this feature)

```text
specs/001-vault-browser-ui/
├── plan.md          ← this file
├── research.md      ← Phase 0 output
├── data-model.md    ← Phase 1 output
├── quickstart.md    ← Phase 1 output
├── contracts/
│   ├── AuthRepository.md
│   ├── VaultRepository.md
│   └── SyncRepository.md
└── tasks.md         ← Phase 2 output (created by /speckit.tasks)
```

### Source Code

```text
Bitwarden_MacOS/
├── Bitwarden_MacOS.xcodeproj/
└── Bitwarden_MacOS/
    ├── App/
    │   ├── BitwardenMacOSApp.swift      # @main, window setup, DI wiring
    │   ├── AppContainer.swift           # Manual dependency injection container
    │   └── Config.swift                 # clientName, deviceType, appVersion, deploymentTarget
    │
    ├── Domain/                          # Pure Swift. No SDK/UIKit/SwiftUI imports.
    │   ├── Entities/
    │   │   ├── Account.swift
    │   │   ├── ServerEnvironment.swift
    │   │   ├── VaultItem.swift          # + ItemContent, LoginContent, CardContent, etc.
    │   │   ├── CustomField.swift
    │   │   └── SidebarSelection.swift
    │   ├── Repositories/               # Protocol definitions only
    │   │   ├── AuthRepository.swift
    │   │   ├── VaultRepository.swift
    │   │   └── SyncRepository.swift
    │   └── UseCases/
    │       ├── LoginUseCase.swift       # orchestrates preLogin → login → sync
    │       ├── UnlockUseCase.swift      # orchestrates unlock → decrypt
    │       ├── SyncUseCase.swift        # calls SyncRepository.sync()
    │       └── SearchVaultUseCase.swift
    │
    ├── Data/                            # SDK, network, Keychain. No SwiftUI imports.
    │   ├── SDK/
    │   │   └── BitwardenClientService.swift  # owns Client; wraps all SDK calls
    │   ├── Network/
    │   │   ├── BitwardenAPIClient.swift      # URLSession-based; sync endpoint
    │   │   └── FaviconLoader.swift           # actor; NSCache + URLCache
    │   ├── Keychain/
    │   │   └── KeychainService.swift         # read/write/delete helpers
    │   ├── Mappers/
    │   │   └── CipherMapper.swift            # SDK Cipher → Domain VaultItem
    │   └── Repositories/
    │       ├── AuthRepositoryImpl.swift
    │       ├── VaultRepositoryImpl.swift
    │       └── SyncRepositoryImpl.swift
    │
    ├── Presentation/                    # SwiftUI + ViewModels. No SDK/Data imports.
    │   ├── Auth/
    │   │   ├── LoginView.swift
    │   │   ├── LoginViewModel.swift
    │   │   ├── UnlockView.swift
    │   │   ├── UnlockViewModel.swift
    │   │   ├── SyncProgressView.swift
    │   │   └── ServerSelectionView.swift
    │   ├── Vault/
    │   │   ├── VaultBrowserView.swift         # NavigationSplitView root
    │   │   ├── VaultBrowserViewModel.swift    # owns sidebar + item + search state
    │   │   ├── Sidebar/
    │   │   │   └── SidebarView.swift
    │   │   ├── ItemList/
    │   │   │   ├── ItemListView.swift
    │   │   │   └── ItemRowView.swift          # favicon, name, subtitle, star indicator
    │   │   └── Detail/
    │   │       ├── ItemDetailView.swift       # dispatcher to type-specific view
    │   │       ├── LoginDetailView.swift
    │   │       ├── CardDetailView.swift
    │   │       ├── IdentityDetailView.swift
    │   │       ├── SecureNoteDetailView.swift
    │   │       └── SSHKeyDetailView.swift
    │   └── Components/
    │       ├── FieldRowView.swift             # hover-reveal row (FR-023)
    │       ├── MaskedFieldView.swift          # fixed 8-dot masking (FR-026)
    │       ├── FaviconView.swift              # async favicon + SF Symbol fallback
    │
    └── Tests/
        ├── DomainTests/
        │   ├── UseCases/
        │   └── Entities/
        ├── DataTests/
        │   ├── Repositories/
        │   ├── Mappers/
        │   └── Network/
        └── UITests/

```

**Structure Decision**: Single-target macOS app. No separate Swift packages per layer — YAGNI.
Source directory layout enforces Clean Architecture separation; Xcode group structure mirrors
the source tree. A second target (autofill extension) may be added in a future version.

---

## Phase 0: Research

*Completed. See [research.md](research.md) for full findings.*

**Key decisions resolved**:

| Topic | Decision |
|-------|----------|
| BitwardenSdk macOS support | **No prebuilt macOS slice exists** — must build XCFramework from Rust source; fork sdk-swift (OI-001, BLOCKER) |
| Auth API shape | App makes all HTTP calls; SDK handles local crypto only. Flow: `preLogin` HTTP → `client.auth().hashPassword()` → `/connect/token` HTTP → `client.crypto().initializeUserCrypto()` (no `initializeOrgCrypto` in v1) |
| Vault decrypt | Two-phase: `decryptList()` on sync for personal ciphers only (list view), `decrypt(cipher:)` on selection (detail view) |
| Reprompt | Deferred to future version. Not implemented in v1. |
| Three-pane layout | `NavigationSplitView` (macOS 13+) — native, no custom code; reset `itemSelection` on sidebar change |
| Keychain storage | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, userId-namespaced keys, no iCloud sync |
| Favicon caching | Bitwarden icon service `{ICONS_BASE}/{domain}/icon.png` + `NSCache` + `URLCache` |
| Clipboard auto-clear | Cancellable `Task.sleep(for: .seconds(30))` |
| Search | In-memory `Array.filter` — no index needed for ≤1,000 items |
| Masked fields | Fixed 8-dot placeholder (`••••••••`) regardless of value length |

---

## Phase 1: Design & Contracts

*Completed.*

**Artifacts generated**:
- [data-model.md](data-model.md) — all Domain entities with Swift type definitions
- [contracts/AuthRepository.md](contracts/AuthRepository.md) — auth, session, reprompt protocol
- [contracts/VaultRepository.md](contracts/VaultRepository.md) — read-only vault access protocol
- [contracts/SyncRepository.md](contracts/SyncRepository.md) — vault sync protocol
- [quickstart.md](quickstart.md) — project setup, structure, and developer guide

**Post-design Constitution re-check**: All 6 principles still pass. Design introduces no
new violations.

---

## Implementation Strategy

The feature is implemented in strict vertical slices, ordered by user story priority:

### Slice 1 — Xcode Project Scaffold (no user-facing code)

Create the Xcode project, add `BitwardenSdk` as an SPM dependency, verify macOS slice, create
directory structure, add `Config.swift` with placeholder client identifier.

**Gate**: `lipo -info` confirms macOS slice. Build succeeds. All tests pass (empty test suite).

### Slice 2 — Domain Layer

Define all entities (`VaultItem`, `Account`, `ServerEnvironment`, etc.) and repository
protocols (`AuthRepository`, `VaultRepository`, `SyncRepository`) exactly as per `data-model.md`
and `contracts/`. Define use cases as protocol-only stubs.

**Gate**: Compiles with no imports other than `Foundation`. 100% test coverage of entity
validation rules.

### Slice 3 — Data Layer: Keychain + SDK Wrapper

Implement `KeychainService`, `BitwardenClientService` (wraps `Client`), and the SDK entity
mapper (`CipherMapper` — personal ciphers only in v1).

**Gate**: Unit tests for all mappers. Integration test for Keychain write/read/delete.

### Slice 4 — US1: Login Flow (Data + Presentation)

Implement `AuthRepositoryImpl` (pre-login, login, TOTP), `SyncRepositoryImpl`, `LoginUseCase`,
`SyncUseCase`. Build `LoginView`, `ServerSelectionView`, `SyncProgressView`.

**Gate**: Can log in to a real self-hosted Bitwarden or Vaultwarden account, reach the
vault browser. SC-001 passes (≤60s end-to-end).

### Slice 5 — US2: Unlock Flow

Implement `UnlockUseCase`, `UnlockRepositoryImpl` (local KDF only), `UnlockView`. Implement
`AuthRepositoryImpl.lockVault()` and `signOut()`.

**Gate**: App quit + relaunch shows unlock screen. Correct password unlocks. Wrong password
shows error without locking. "Sign in with different account" clears session.

### Slice 6 — US3: Three-Pane Vault Browser

Implement `VaultRepositoryImpl` with all filter/category logic. Build `VaultBrowserView` +
`VaultBrowserViewModel` + `SidebarView` + `ItemListView` + `ItemRowView` + all five
`*DetailView` files + `FieldRowView` + `MaskedFieldView` + `FaviconView`.

**Gate**: All US3 acceptance scenarios pass. Vault with 1,000 items renders without perceptible
lag (SC-003, SC-005).

### Slice 7 — US4: Search

Implement `SearchVaultUseCase`. Wire search bar into `VaultBrowserViewModel`. Scope search to
active sidebar selection.

**Gate**: All US4 acceptance scenarios pass. SC-008 (<100ms per keystroke).

### Slice 8 — Final Polish & Sign-Out

Wire Sign Out menu item with confirmation dialog (FR-014) — on confirm, call
`AuthRepository.signOut()`, clear Keychain, release SDK Client, return to login screen.
Implement clipboard auto-clear (FR-011). Add `os.Logger` calls to all auth/sync/vault
code paths. Final constitution check.

**Gate**: SC-004 (clipboard clears in 30s). No swallowed errors in any code path.

---

## Complexity Tracking

*No constitution violations in this plan.*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| — | — | — |

---

## Open Items

| ID | Priority | Item |
|----|----------|------|
| OI-001 | **BLOCKER** | No prebuilt macOS XCFramework slice exists. See [sdk-macos-build.md](sdk-macos-build.md) for step-by-step instructions. Must complete before Slice 3. |
| OI-002 | FUTURE | Client registration with Bitwarden required when cloud (US/EU) support is added in a future version. Not needed for v1 (self-hosted only). |
| OI-003 | FUTURE | EU cloud icons base URL needs verification when cloud support is added. Not applicable for v1. |
| OI-004 | SHOULD | Evaluate TLS certificate pinning for `api.bitwarden.com` and `identity.bitwarden.com`. |
