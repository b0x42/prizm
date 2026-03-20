# Research: 001-vault-browser-ui

**Phase**: 0 — Outline & Research
**Date**: 2026-03-13 (updated post-agent verification)
**Branch**: `001-vault-browser-ui`

---

## 1. BitwardenSdk (sdk-swift) — macOS Support

**Decision**: Implement Bitwarden crypto natively using CommonCrypto + CryptoKit + Security.framework.
No `sdk-swift` dependency. OI-001 is closed.

**Findings** (confirmed 2026-03-15):
- `sdk-swift` distributes `BitwardenFFI.xcframework` — iOS-only (`ios-arm64`, `ios-arm64_x86_64-simulator`).
  No macOS slice exists in any release.
- `bitwarden/sdk-internal` (private) contains the UniFFI Swift bindings and `build.sh`. Access is not available.
- `bitwarden/sdk` (public) has no `bitwarden-uniffi` crate. The public `bitwarden-c` and `bitwarden-json`
  crates only cover Secrets Manager — no vault cipher operations.
- All Bitwarden crypto algorithms are standard and fully documented in the Bitwarden Security Whitepaper:
  PBKDF2-SHA256 / Argon2id (key derivation), HKDF (key stretching), AES-256-CBC + HMAC-SHA256
  (symmetric encryption), RSA-OAEP (asymmetric). All are available in Apple frameworks.

**Approach**:
- `BitwardenCryptoService` protocol + `BitwardenCryptoServiceImpl` actor in the Data layer.
- `EncString` value type parses and decrypts Bitwarden's `{type}.{iv}|{ct}|{mac}` format.
- KDF: `CCKeyDerivationPBKDF` (CommonCrypto) for PBKDF2-SHA256; Argon2id via `Argon2Swift` package.
- HKDF: `HKDF<SHA256>` (CryptoKit) for key stretching.
- AES-256-CBC: `kCCAlgorithmAES` (CommonCrypto).
- HMAC-SHA256: `HMAC<SHA256>` (CryptoKit).
- RSA-OAEP: `SecKeyCreateDecryptedData` (Security.framework).
- Sync response parsed directly from JSON via `Codable` types in `Data/Network/Models/`.
- `CipherMapper` maps from those Codable types → Domain `VaultItem`.

**No OI-001 blocker. Implementation can proceed immediately.**

---

## 2. Bitwarden Crypto — Native Implementation API Shape

**Decision**: `BitwardenCryptoService` protocol in the Data layer replaces the SDK `Client` object.
All crypto is implemented using Apple frameworks. The Data layer owns the service as an `actor`.

**Service protocol**:

```swift
/// Data layer only. Owns in-memory key material. Released on lock/sign-out.
actor BitwardenCryptoServiceImpl: BitwardenCryptoService {
    // Key derivation for network authentication
    func hashPassword(email: String, password: String, kdfParams: KdfParams, purpose: HashPurpose) async throws -> String

    // Initialise vault key material from master password + stored encrypted keys
    func initializeUserCrypto(masterPassword: String, email: String, kdfParams: KdfParams,
                               encUserKey: String, encPrivateKey: String) async throws

    // Decrypt raw cipher list from sync response (personal ciphers only)
    func decryptList(ciphers: [RawCipher]) async throws -> [VaultItem]

    // Decrypt a single cipher for detail view (called on item selection)
    func decrypt(cipher: RawCipher) async throws -> VaultItem

    // Lock: wipe all key material from memory
    func lockVault()
}
```

**Crypto algorithm mapping**:

| Operation | Algorithm | Apple framework |
|-----------|-----------|-----------------|
| Master key derivation (PBKDF2) | PBKDF2-SHA256 | CommonCrypto `CCKeyDerivationPBKDF` |
| Master key derivation (Argon2id) | Argon2id | `Argon2Swift` SPM package |
| Key stretching | HKDF-SHA256 | CryptoKit `HKDF<SHA256>` |
| Symmetric decrypt | AES-256-CBC + HMAC-SHA256 | CommonCrypto `kCCAlgorithmAES` + CryptoKit `HMAC<SHA256>` |
| RSA key unwrap | RSA-OAEP-SHA1 | Security.framework `SecKeyCreateDecryptedData` |

**EncString format** (Bitwarden wire format):

| Type | Format | Usage |
|------|--------|-------|
| 0 | `{base64_iv}|{base64_ct}` | AES-CBC-256, no MAC (legacy) |
| 2 | `{base64_iv}|{base64_ct}|{base64_mac}` | AES-CBC-256 + HMAC-SHA256 (common) |
| 4 | `{base64_ct}` | RSA-2048-OAEP-SHA1 (org keys — not used in v1) |
| 6 | `{base64_ct}` | RSA-2048-OAEP-SHA256 (user key encrypted by public key) |

**Key derivation flow** (replaces SDK `hashPassword` + `initializeUserCrypto`):

```
1. masterKey = PBKDF2-SHA256(password=masterPassword, salt=email.lowercased().utf8,
                              iterations=kdfParams.iterations, keyLen=32)

2a. serverHash = PBKDF2-SHA256(password=masterKey, salt=masterPassword.utf8, iterations=1, keyLen=32)
    → base64(serverHash) → sent as `password` field in /connect/token

2b. stretchedKey[0..31] = HKDF-SHA256-expand(prk=masterKey, info="enc", len=32)  // AES key
    stretchedKey[32..63] = HKDF-SHA256-expand(prk=masterKey, info="mac", len=32) // MAC key

3. symmetricKey (64 bytes) = AES-CBC-256-decrypt(encUserKey, key=stretchedKey[0..31],
                                                  mac_key=stretchedKey[32..63])
   // encUserKey is the EncString type-2 `Key` field from the token response

4. Each vault field = AES-CBC-256-decrypt(encField, key=symmetricKey[0..31],
                                          mac_key=symmetricKey[32..63])
   // Verify HMAC-SHA256 before decrypt; discard item on MAC failure
```

**Unlock flow** (no network; uses stored Keychain values):
```
initializeUserCrypto(masterPassword, email, kdfParams, encUserKey, encPrivateKey)
  → re-derive stretchedKey from masterPassword
  → re-decrypt symmetricKey from encUserKey
  → vault is now unlocked in memory
```

**Reprompt** (deferred to future version): not implemented.

**Notes**:
- KDF params (`kdfParams`) are stored in Keychain at login time (`bw.macos:{userId}:kdfParams`)
  so unlock works offline without a network preLogin call.
- Most Bitwarden accounts use PBKDF2-SHA256. Argon2id accounts are supported via `Argon2Swift`.
- The `encPrivateKey` (RSA private key) is decrypted from Keychain but not actively used in v1
  since org ciphers are excluded. It is decrypted as part of `initializeUserCrypto` for
  completeness and forward-compat; the result is held in memory and discarded on lock.
- `RawCipher` is a `Codable` struct in `Data/Network/Models/` that mirrors the sync API cipher JSON.

---

## 3. Bitwarden REST API Endpoints

**Decision**: All network calls via a thin `BitwardenAPIClient` actor in the Data layer.
v1 supports self-hosted Bitwarden and Vaultwarden only — no cloud endpoints needed.

**Endpoints for v1**:

| Purpose | Method | URL |
|---------|--------|-----|
| KDF params | POST | `{API_BASE}/accounts/prelogin` ← API base, not identity |
| Authenticate | POST | `{IDENTITY_BASE}/connect/token` |
| Sync vault | GET | `{API_BASE}/sync?excludeDomains=true` |
| Favicon | GET | `{ICONS_BASE}/{domain}/icon.png` |

**Self-hosted base URL derivation** (from user-supplied `{base}`):

| Service | Derived URL |
|---------|-------------|
| API base | `{base}/api` |
| Identity base | `{base}/identity` |
| Icons base | `{base}/icons` |

Vaultwarden uses the same endpoint structure and is fully compatible.

**No client registration required for v1.** Self-hosted servers do not enforce a
client whitelist. Use `client_id = "desktop"` and `deviceType = 7` (macOS Desktop)
as the fixed values for v1 — the self-hosted server stores these as metadata only.
Do not use `deviceType = 14` (macOS CLI); that is for the Bitwarden CLI tool.
Bitwarden cloud registration is required when cloud support is added in a future version.

**Identity token request** — `application/x-www-form-urlencoded`:

| Field | Value |
|-------|-------|
| `grant_type` | `password` |
| `username` | user email |
| `password` | master password hash (from `BitwardenCryptoServiceImpl.hashPassword(..., purpose: .serverAuthorization)`) |
| `scope` | `api offline_access` |
| `client_id` | registered client string (e.g. `desktop`) — **requires Bitwarden registration** |
| `deviceType` | `7` (macOS Desktop) — **pending official registration** |
| `deviceIdentifier` | stable UUID, generated once per install, stored in Keychain |
| `deviceName` | human-readable device name (e.g. `"MacBook Pro"`) |
| `twoFactorToken` | TOTP code (only on 2FA challenge) |
| `twoFactorProvider` | `0` (authenticator app, only on 2FA challenge) |

**Required headers for all authenticated API calls**:
```
Authorization:              Bearer {access_token}
Bitwarden-Client-Name:      desktop          (or registered name)
Bitwarden-Client-Version:   {appVersion}
Device-Type:                7
X-Device-Identifier:        {stableInstallUUID}
User-Agent:                 Macwarden/{version} (macOS)
```

**2FA flow**: If `/connect/token` returns HTTP 400 with `"TwoFactorProviders": [0, ...]`, prompt
the user for the TOTP code and re-POST with `twoFactorToken` + `twoFactorProvider=0`.
If `TwoFactorProviders` contains only unsupported methods (anything other than `0`), show a
clear error per FR-016.

> **Prerequisite**: Register the macOS client with Bitwarden Customer Success before connecting
> to production. See constitution "Bitwarden API Integration Requirements". In development,
> device type `14` (macOS CLI) may be used as a temporary stand-in.

**Alternatives considered**:
- Delegate all HTTP to a library — not applicable; all network calls use URLSession directly.

---

## 4. SwiftUI Three-Pane Layout (macOS)

**Decision**: `NavigationSplitView` (macOS 13+), `.balanced` style. State reset on sidebar
selection change is the key implementation concern.

**Pattern** (confirmed correct by agent research):
```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    SidebarView(selection: $sidebarSelection)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
} content: {
    ItemListView(
        category: sidebarSelection,
        selection: $itemSelection,
        searchText: $searchText
    )
    .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 450)
    .onChange(of: sidebarSelection) { _ in
        itemSelection = nil   // reset detail pane on category change
    }
} detail: {
    if let item = itemSelection {
        ItemDetailView(item: item)
    } else {
        NoSelectionView()    // FR-034: empty state
    }
}
.navigationSplitViewStyle(.balanced)
```

**Column visibility**: `NavigationSplitViewVisibility` — `.all`, `.doubleColumn`, `.detailOnly`.
System `⌘⌃S` shortcut for Hide/Show Sidebar works automatically with the binding.

**Keyboard navigation**: Natively handled by `NavigationSplitView` on macOS (satisfies SC-007).

**Alternatives considered**:
- Custom `HSplitView` — rejected (more work, accessibility harder, no native keyboard nav).
- `NavigationView` (deprecated macOS 13) — rejected.

---

## 5. Keychain Storage

**Decision**: Two-layer pattern matching the Bitwarden iOS reference — `KeychainService` (raw
Security framework) + `KeychainRepository` (semantic API). Both are Data layer only.

**Protection level**: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for all items (constitution
§III mandates this; stricter than the iOS reference which uses `AfterFirstUnlock` for tokens).

**Item key naming** (namespaced by userId to support future multi-account):

| Key | Content |
|-----|---------|
| `bw.macos:{userId}:accessToken` | OAuth2 access token |
| `bw.macos:{userId}:refreshToken` | OAuth2 refresh token |
| `bw.macos:{userId}:encUserKey` | Encrypted user symmetric key (from token response `Key`) |
| `bw.macos:{userId}:encPrivateKey` | Encrypted RSA private key (from token response `PrivateKey`) |
| `bw.macos:{userId}:kdfParams` | Serialised KDF params (for local unlock without network) |
| `bw.macos:{userId}:email` | User email (for display on unlock screen) |
| `bw.macos:deviceIdentifier` | Stable install UUID (not scoped to userId) |
| `bw.macos:activeUserId` | The currently active user's GUID (global — not userId-scoped) |

**No `kSecAttrSynchronizable`** (constitution §III: no iCloud sync of secrets).

---

## 6. Favicon Fetching & Caching

**Decision**: Fetch via Bitwarden icon service (FR-032). URL format: `{ICONS_BASE}/{domain}/icon.png`
(domain only — e.g. `icons.bitwarden.net/github.com/icon.png`, not `/icons/` prefix).

**Cache**: `NSCache<NSString, NSImage>` in-memory + `URLCache` disk cache via `URLSession`.
Cache policy: `returnCacheDataElseLoad` — stale favicons are acceptable.

**Fallback**: SF Symbol per item type when fetch fails or no URI present.
Row icon priority: favicon → type SF Symbol. Attachment presence does not affect the row icon.

**Implementation**: Lightweight `FaviconLoader` actor in the Data layer.

---

## 7. Clipboard Auto-Clear

**Decision**: Cancellable `Task` with `Task.sleep(for: .seconds(30))`.

```swift
private var clearTask: Task<Void, Never>?

func copyToClipboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    clearTask?.cancel()
    clearTask = Task {
        try? await Task.sleep(for: .seconds(30))
        guard !Task.isCancelled else { return }
        NSPasteboard.general.clearContents()
    }
}
```

**Vault lock**: the timer runs to completion when the vault locks mid-session.
**App quit**: a Swift `Task` is cancelled by the OS when the process exits — the 30-second
timer will not fire after quit. This is acceptable; clipboard auto-clear is best-effort on
quit only. The spec does not guarantee clipboard is cleared after quit (FR-011).

---

## 8. Masked Field Display

**Decision**: Fixed 8-dot placeholder (`••••••••`) regardless of actual value length (FR-026).
`@State var isRevealed: Bool` toggles between the placeholder and the real value in a `Text` view.

---

## 9. Search Implementation

**Decision**: In-memory `Array.filter` over decrypted `[VaultItem]`. No index needed.

**Filter logic**: Case-insensitive `localizedCaseInsensitiveContains`. Scoped to active
`SidebarSelection` (FR-012). Fields matched per item type:

| Type | Fields searched |
|------|----------------|
| Login | name, username, uris[].uri, notes |
| Card | name, cardholderName, notes |
| Identity | name, firstName, lastName, email, company, notes |
| Secure Note | name, notes |
| SSH Key | name only |

**Category switch behaviour**: Search term is preserved when the user switches sidebar
categories. The filter is re-applied to the new category's items. The search bar is not
cleared (FR-012).

**No debounce**: `Array.filter` on 1,000 items completes in <1ms. Filter runs on every
keystroke with no delay. Satisfies SC-008 (<100ms per keystroke).

---

## 10. Item List Sort Order

**Decision**: Alphabetical by `name`, case-insensitive (`localizedCaseInsensitiveCompare`).
Applied to all sidebar selections, including search results (FR-040).

```swift
items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
```

---

## 11. Device Identifier

**Decision**: A stable UUID (v4) generated on first app launch and stored in Keychain
under `bw.macos:deviceIdentifier`. Sent as `X-Device-Identifier` and `deviceName` headers
on all API requests.

```swift
// Generate on first launch:
let deviceId = UUID().uuidString   // UUID v4
// Store in Keychain: "bw.macos:deviceIdentifier"
// Re-read on every subsequent launch
```

The device name sent to the server is `Host.current().localizedName ?? "Mac"` (from `Foundation`).

---

## 12. iOS Reference Architecture — Applicable Patterns

From `bitwarden/ios` (confirmed by agent research):

| Pattern | Directly reusable for macOS |
|---------|----------------------------|
| `ClientService` protocol + `DefaultClientService` actor | Partial — actor-per-service pattern reused; `BitwardenCryptoServiceImpl` replaces SDK `Client` |
| `KeychainService` (raw SecItem) + `KeychainRepository` (semantic) | Yes — same Security framework APIs on macOS |
| `ServiceContainer` + `Has<X>` protocol-composition DI | Yes — zero platform code |
| `SyncService` → `CipherService` layer | Yes — pattern applies; Core Data works on macOS |
| List decrypt (`decryptList`) + detail decrypt on demand | Yes — follow the same two-phase pattern |
| Co-located test files | Yes |

**Not applicable**: UIKit navigation (`UINavigationController`, `UITabBarController`),
`UIApplicationDelegate`, iOS extensions lifecycle.

---

## 13. Project Structure Decision

**Decision**: Single Xcode app target. No separate Swift packages per layer for v1 (YAGNI).
Source directory layout enforces Clean Architecture; import discipline enforces layer boundaries.

A second target (autofill extension) may be added in a future version, at which point extracting
a shared `BitwardenShared` framework (mirroring the iOS approach) would be appropriate.

---

## Open Items (pre-implementation verification)

| ID | Priority | Item |
|----|----------|------|
| OI-001 | ~~CLOSED~~ | Native crypto approach adopted — CommonCrypto + CryptoKit + Security.framework. No XCFramework build required. |
| OI-002 | FUTURE | Client registration with Bitwarden required when cloud (US/EU) support is added. Not needed for v1 (self-hosted only). |
| OI-003 | FUTURE | EU cloud icons base URL needs verification when cloud support is added. Not applicable for v1. |
| OI-004 | SHOULD | Evaluate TLS certificate pinning for self-hosted endpoints (user-supplied URLs). |
