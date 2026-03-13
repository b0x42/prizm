# Research: 001-vault-browser-ui

**Phase**: 0 — Outline & Research
**Date**: 2026-03-13 (updated post-agent verification)
**Branch**: `001-vault-browser-ui`

---

## 1. BitwardenSdk (sdk-swift) — macOS Support

**Decision**: Proceed with sdk-swift as the canonical crypto/vault library. Building a macOS
XCFramework slice is a **hard blocker** that must be resolved before Slice 3 (Data layer).

**Findings** (confirmed by research agent, `Package.swift` at tag `v2.0.0-4975-625c9bc`):
- `sdk-swift` distributes a binary `BitwardenFFI.xcframework` via SPM `.binaryTarget`.
  Current version: `v2.0.0-4975-625c9bc` (2026-03-13). Tags are continuous CI builds
  (format `v2.0.0-{build}-{sha}`); the iOS client pins to a specific commit revision.
- `Package.swift` declares **`.iOS(.v16)` only** — there is **no macOS slice** in the
  prebuilt XCFramework. This is confirmed; not merely a packaging omission.
- The underlying Rust SDK (`bitwarden/sdk`) cross-compiles to macOS targets
  (`x86_64-apple-macosx`, `aarch64-apple-macosx`) and the Swift DeviceType enum includes
  `macOsDesktop` — so macOS support exists at the Rust level, just not packaged.
- No open issues about macOS support; this is uncharted territory for the SDK team.

**Rationale**: The SDK is mandated by constitution §III. Since no prebuilt macOS slice exists,
the XCFramework must be built from the Rust SDK source. This is technically feasible.

**Alternatives considered**:
- Custom KDF / cipher decryption using CryptoKit — **rejected** (constitution §III prohibits this).
- Wait for upstream to package macOS — **rejected** (no timeline; blocks all progress).

**Action items** (**BLOCKERS** — must resolve before Slice 3):
1. Clone `bitwarden/sdk`, add macOS targets to the XCFramework build script,
   build `BitwardenFFI.xcframework` with `macos-arm64_x86_64` slice.
2. Fork `bitwarden/sdk-swift`, add `.macOS(.v13)` to `Package.swift`, point to the
   locally built XCFramework. Use this fork until upstream accepts a PR.
3. Open a GitHub issue on `bitwarden/sdk-swift` documenting the macOS use case.

---

## 2. BitwardenSdk Auth & Vault API Shape

**Decision**: Use the SDK's `Client` object as the top-level entry point, initialised once and
owned by the Data layer as a `BitwardenClientService` actor.

**Corrected API flow** (verified against SDK source + Bitwarden iOS reference at `bitwarden/ios`):

The SDK does **not** handle HTTP calls. The app makes all network requests; the SDK handles
only local cryptography. The correct call sequence is:

```
// Step 1 — App makes HTTP POST {API_BASE}/accounts/prelogin → gets KDF params
let preLoginResponse = try await networkClient.preLogin(email: email)
// preLoginResponse: { kdf: 0, kdfIterations: 600000 }

// Step 2 — SDK derives master password hash (for network login)
let masterPasswordHash = try client.auth().hashPassword(
    email: email,
    password: masterPassword,
    kdfParams: preLoginResponse.kdf,    // Kdf enum: .pbkdf2 or .argon2id
    purpose: .serverAuthorization
)

// Step 3 — App makes HTTP POST {IDENTITY_BASE}/connect/token (form-encoded)
// Body: grant_type=password, username={email}, password={masterPasswordHash},
//       client_id={registered}, deviceType={7}, deviceIdentifier={stableUUID}, ...
// Response: { access_token, refresh_token, Key (encUserKey), PrivateKey (encPrivateKey), ... }
let tokenResponse = try await networkClient.identityToken(...)

// Step 4 — SDK initialises user crypto (unlocks vault key material)
try await client.crypto().initializeUserCrypto(req: InitUserCryptoRequest(
    kdfParams: tokenResponse.kdf,
    email: email,
    privateKey: tokenResponse.privateKey,      // user's encrypted RSA private key
    method: .password(
        password: masterPassword,
        userKey: tokenResponse.key             // encrypted user symmetric key
    )
))

// Step 5 — NOT CALLED IN V1: initializeOrgCrypto would be called here for org ciphers.
// In v1, org ciphers are excluded (see FR-033); only personal ciphers are decrypted.

// Step 6 — App makes HTTP GET {API_BASE}/sync → encrypted vault JSON
// Step 7 — SDK decrypts vault (personal ciphers only — list view, for item list)
let cipherListViews = try client.vault().ciphers().decryptList(ciphers: syncResponse.ciphers)

// Step 8 — SDK decrypts individual cipher (full detail view, on demand)
let cipherView = try client.vault().ciphers().decrypt(cipher: selectedCipher)
```

**Unlock flow** (existing session, no network needed):
```
// SDK re-initialises from stored encrypted keys
try await client.crypto().initializeUserCrypto(req: InitUserCryptoRequest(
    kdfParams: storedKdfParams,
    email: storedEmail,
    privateKey: storedEncPrivateKey,
    method: .password(password: enteredMasterPassword, userKey: storedEncUserKey)
))
// No HTTP call needed. Vault is now unlocked in memory.
```

**Reprompt verification** (no network needed):
```swift
// Store local hash at login time:
let localHash = try client.auth().hashPassword(
    email: email,
    password: masterPassword,
    kdfParams: kdfParams,
    purpose: .localAuthorization
)
// Store localHash in Keychain as "bw.macos:{userId}:localPasswordHash"

// At reprompt time:
let isValid = try client.auth().validatePassword(
    password: enteredPassword,
    passwordHash: storedLocalHash
)
```

**Notes**:
- `client.crypto().initializeUserCrypto` and `initializeOrgCrypto` must both be called before
  any cipher decryption. Org crypto initialization requires the sync response (org keys).
- The `Client` object holds in-memory key material. Release it on lock/sign-out.
- `client.vault().ciphers().decryptList()` returns `[CipherListView]` (summary — efficient for
  the item list). `decrypt(cipher:)` returns `CipherView` (full detail — call on selection).
- The iOS reference uses a two-phase decrypt: list on sync, detail on demand. Follow this pattern.

**Alternatives considered**:
- Direct Bitwarden API calls + manual AES-CBC decryption — **rejected** (constitution §III).

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
| `password` | master password hash (from SDK `hashPassword(..., purpose: .serverAuthorization)`) |
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
User-Agent:                 Bitwarden_MacOS/{version} (macOS)
```

**2FA flow**: If `/connect/token` returns HTTP 400 with `"TwoFactorProviders": [0, ...]`, prompt
the user for the TOTP code and re-POST with `twoFactorToken` + `twoFactorProvider=0`.
If `TwoFactorProviders` contains only unsupported methods (anything other than `0`), show a
clear error per FR-016.

> **Prerequisite**: Register the macOS client with Bitwarden Customer Success before connecting
> to production. See constitution "Bitwarden API Integration Requirements". In development,
> device type `14` (macOS CLI) may be used as a temporary stand-in.

**Alternatives considered**:
- Delegate all HTTP to the SDK — not applicable; SDK has no network layer.

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
| `ClientService` protocol + `DefaultClientService` actor | Yes — wraps `Client` per userId; only instantiation changes |
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
| OI-001 | **BLOCKER** | Build `BitwardenFFI.xcframework` with macOS slices from `bitwarden/sdk` Rust source; fork `sdk-swift` to add `.macOS(.v13)`. Open upstream issue. |
| OI-002 | FUTURE | Client registration with Bitwarden required when cloud (US/EU) support is added. Not needed for v1 (self-hosted only). |
| OI-003 | FUTURE | EU cloud icons base URL needs verification when cloud support is added. Not applicable for v1. |
| OI-004 | SHOULD | Evaluate TLS certificate pinning for self-hosted endpoints (user-supplied URLs). |
