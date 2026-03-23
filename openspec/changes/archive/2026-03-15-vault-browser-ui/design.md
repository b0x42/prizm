## Context

Macwarden is a native macOS client for self-hosted Bitwarden and Vaultwarden. It must implement the full Bitwarden client protocol from scratch — no official SDK supports macOS. All cryptographic operations must run locally; the master password must never leave the device. The architecture follows Clean Architecture with three layers (Domain, Data, Presentation) and strict dependency direction enforced by import rules.

v1 is read-only (browse and copy only). Editing, deleting, and creating items are deferred to future versions.

## Goals / Non-Goals

**Goals:**
- Login and unlock flows against any self-hosted Bitwarden or Vaultwarden instance.
- Full vault sync and decryption (personal ciphers only).
- Three-pane browser with sidebar categories, item list, and per-type detail views.
- Real-time in-memory search scoped to the active sidebar category.
- Clipboard auto-clear (30 seconds) for copied secrets.
- Favicon fetching via the Bitwarden icon service with caching.
- TOTP-based two-factor login authentication.

**Non-Goals (v1):**
- Editing, creating, deleting, or favoriting items.
- Organisation/collection ciphers (personal ciphers only).
- Bitwarden cloud (US/EU) — self-hosted only.
- Auto-lock on idle, Touch ID / Face ID unlock.
- TOTP code generation and display for vault items.
- FIDO2/passkey display, password history, attachment display.
- Folder and Collection sidebar entries.
- Trash sidebar entry and soft-deleted item management.
- Master password re-prompt per item.

## Decisions

### D1: Native crypto — no SDK dependency

`sdk-swift` distributes `BitwardenFFI.xcframework` with iOS-only slices (`ios-arm64`, `ios-arm64_x86_64-simulator`). No macOS slice exists. The public `bitwarden/sdk` has no vault cipher operations.

All Bitwarden crypto algorithms are standard and fully documented in the Bitwarden Security Whitepaper: PBKDF2-SHA256 / Argon2id (key derivation), HKDF (key stretching), AES-256-CBC + HMAC-SHA256 (symmetric encryption), RSA-OAEP (asymmetric). All are available in Apple frameworks.

**Approach**: `BitwardenCryptoService` protocol + `BitwardenCryptoServiceImpl` actor in the Data layer. `Argon2Swift` (local vendored SPM package at `LocalPackages/Argon2Swift/`) provides Argon2id KDF; all other crypto via CommonCrypto + CryptoKit + Security.framework.

### D2: `NavigationSplitView` with `.balanced` column style

Three-pane layout uses `NavigationSplitView` (macOS 13+) in `.balanced` mode. Sidebar column width: min 180 / ideal 210; content column: min 220 / ideal 280. Selecting a sidebar entry resets `itemSelection` to `nil` so the detail pane returns to its empty state.

*Alternative considered*: Custom `HSplitView` — rejected (more work, accessibility harder, no native keyboard navigation).

### D3: In-memory vault store; two-phase decrypt

Decrypted vault items are held in `VaultRepositoryImpl` (in-memory `[VaultItem]` array). There is no Core Data or SQLite layer in v1. The vault is re-synced and re-decrypted on every login and unlock.

Two-phase decrypt: `decryptList` produces lightweight summaries for list rows; full field decrypt is also applied at list time (no lazy per-item detail decrypt in v1 — all fields are available immediately).

### D4: Keychain storage — `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

All secrets (access token, refresh token, encrypted user key, encrypted private key, KDF params) are stored in the macOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. No iCloud sync (`kSecAttrSynchronizable` is not set). Keys are namespaced by userId (`bw.macos:{userId}:{key}`) to support future multi-account.

### D5: Clipboard auto-clear via cancellable Task

```swift
clearTask?.cancel()
clearTask = Task {
    try? await Task.sleep(for: .seconds(30))
    if pasteboard.string(forType: .string) == value { pasteboard.clearContents() }
}
```

A new copy cancels the previous timer and starts a fresh 30-second countdown. On app quit the OS cancels the task — clipboard clear is best-effort on quit only (FR-011 explicitly permits this).

### D6: In-memory search — no index, no debounce

`Array.filter` with `localizedCaseInsensitiveContains` on `[VaultItem]` runs in <1ms for 1,000 items. No debounce is needed. Search is scoped to the active `SidebarSelection`; the search term is preserved across category switches.

### D7: Favicon fetching via icon service

URL format: `{ICONS_BASE}/{domain}/icon.png`. `FaviconLoader` is a Data-layer actor with `NSCache<NSString, NSImage>` in-memory cache and `URLCache` disk cache (policy: `returnCacheDataElseLoad`). Failures fall back silently to the SF Symbol for the item type.

### D8: Single Xcode target, no separate Swift packages per layer

Source directory layout enforces Clean Architecture; import discipline enforces layer boundaries (`import Foundation` only in Domain; `import SwiftUI` only in Presentation; crypto imports only in Data). A second target (autofill extension) may be added later — extracting a shared framework would be appropriate at that point.

## Crypto Key Derivation Flow

```
1. masterKey = PBKDF2-SHA256(password=masterPassword, salt=email.lowercased().utf8,
                              iterations=kdfParams.iterations, keyLen=32)
   — or Argon2id(password, salt, memory, iterations, parallelism) for Argon2id accounts

2a. serverHash = PBKDF2-SHA256(prk=masterKey, salt=masterPassword.utf8, iterations=1, keyLen=32)
    → base64(serverHash) — sent as `password` field in /connect/token

2b. stretchedKey[0..31] = HKDF-SHA256-expand(prk=masterKey, info="enc", len=32)   // AES key
    stretchedKey[32..63] = HKDF-SHA256-expand(prk=masterKey, info="mac", len=32)  // MAC key

3. symmetricKey (64 bytes) = AES-CBC-256-decrypt(encUserKey, key=stretchedKey[0..31],
                                                  mac_key=stretchedKey[32..63])

4. Each vault field = AES-CBC-256-decrypt(encField, key=symmetricKey[0..31],
                                          mac_key=symmetricKey[32..63])
   — Verify HMAC-SHA256 before decrypt; discard item on MAC failure
```

## App State Machine

```
App Launch
├─ No Keychain session → LoginView
│                            └─ Auth → (2FA?) → SyncProgressView → VaultBrowserView
└─ Session found     → UnlockView
                          └─ KDF (local) → SyncProgressView → VaultBrowserView
                                                               └─ Quit → Vault locked
```

## Risks / Trade-offs

- **No background sync** → vault data is as fresh as the last login/unlock. Accepted for v1; mid-session sync failure surfaces a dismissible error banner (FR-049).
- **In-memory vault only** → app quit clears the vault; re-sync required on every unlock. Accepted for v1; fast with URLSession + native crypto.
- **Personal ciphers only** → org/collection ciphers silently skipped. Accepted; org support deferred.
- **`sdk-swift` iOS-only** → native crypto adds implementation complexity. Mitigated by native Apple APIs being well-documented and auditable.
