# Data Model: 001-vault-browser-ui

**Phase**: 1 — Design & Contracts
**Date**: 2026-03-13
**Branch**: `001-vault-browser-ui`
**Input**: `spec.md` Key Entities + `research.md`

---

## Overview

All entities below are **Domain layer** types — pure Swift, no crypto imports, no UI imports.
They are produced by the Data layer (which decrypts `RawCipher` Codable types via
`CipherMapper`) and consumed by the Presentation layer (via Use Cases).

---

## Core Entities

### ServerEnvironment

```swift
/// The self-hosted Bitwarden or Vaultwarden server the app authenticates against.
/// Bitwarden cloud (US/EU) is not supported in v1.
struct ServerEnvironment: Equatable, Codable {
    let baseURL: URL                     // user-supplied, e.g. https://vault.example.com
    let overrides: ServerURLOverrides    // optional per-service overrides

    /// Derived endpoints — explicit override takes priority over baseURL derivation.
    var apiURL: URL { overrides.apiURL ?? baseURL.appendingPathComponent("api") }
    var identityURL: URL { overrides.identityURL ?? baseURL.appendingPathComponent("identity") }
    var iconsURL: URL { overrides.iconsURL ?? baseURL.appendingPathComponent("icons") }
}

struct ServerURLOverrides: Equatable, Codable {
    var apiURL: URL?
    var identityURL: URL?
    var iconsURL: URL?
}
```

---

### Account

```swift
/// Authenticated Bitwarden user identity.
struct Account: Identifiable, Equatable {
    let id: String           // Bitwarden user GUID
    let email: String
    let name: String?
    let serverEnvironment: ServerEnvironment
}
```

---

### VaultItem (Cipher)

```swift
/// A single decrypted vault entry.
struct VaultItem: Identifiable, Equatable {
    let id: String

    let name: String
    let isFavorite: Bool
    let isDeleted: Bool          // true = soft-deleted (Trash); excluded from all views in v1

    let creationDate: Date
    let revisionDate: Date

    let content: ItemContent
}
```

---

### ItemContent (Sum Type)

```swift
/// Type-discriminated content for a vault item.
enum ItemContent: Equatable {
    case login(LoginContent)
    case secureNote(SecureNoteContent)
    case card(CardContent)
    case identity(IdentityContent)
    case sshKey(SSHKeyContent)
}
```

---

### LoginContent

```swift
struct LoginContent: Equatable {
    let username: String?
    let password: String?        // masked in UI; nil if absent
    let uris: [LoginURI]
    let notes: String?
    let customFields: [CustomField]

    // Stored but NOT displayed in v1:
    let totpKey: String?         // FR-038: TOTP code display deferred
}

struct LoginURI: Equatable {
    let uri: String
    let matchType: URIMatchType?  // stored per FR-035; not displayed in v1
}

enum URIMatchType: Int, Equatable {
    case domain = 0
    case host = 1
    case startsWith = 2
    case exact = 3
    case regex = 4
    case never = 5
}

```

---

### SecureNoteContent

```swift
struct SecureNoteContent: Equatable {
    let notes: String?
    let customFields: [CustomField]
}
```

---

### CardContent

```swift
struct CardContent: Equatable {
    let cardholderName: String?
    let number: String?          // masked; last 4 digits used for subtitle
    let brand: String?
    let expiryMonth: String?     // "MM"
    let expiryYear: String?      // "YYYY"
    let securityCode: String?    // masked
    let notes: String?
    let customFields: [CustomField]
}
```

---

### IdentityContent

```swift
struct IdentityContent: Equatable {
    // Name
    let title: IdentityTitle?
    let firstName: String?
    let middleName: String?
    let lastName: String?

    // Organisation
    let company: String?

    // Contact
    let email: String?
    let phone: String?

    // Address
    let address1: String?
    let address2: String?
    let address3: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?

    // Government IDs
    let ssn: String?
    let passportNumber: String?
    let licenseNumber: String?

    let notes: String?
    let customFields: [CustomField]
}

enum IdentityTitle: String, Equatable {
    case mr = "Mr"
    case mrs = "Mrs"
    case ms = "Ms"
    case mx = "Mx"
    case dr = "Dr"
}
```

---

### SSHKeyContent

```swift
struct SSHKeyContent: Equatable {
    let privateKey: String?      // masked by default (FR-020)
    let publicKey: String?       // visible
    let keyFingerprint: String?  // visible; used as subtitle
}
```

---

### CustomField

```swift
struct CustomField: Equatable {
    let name: String
    let value: String?
    let type: CustomFieldType
    let linkedId: LinkedFieldId?  // only meaningful when type == .linked
}

enum CustomFieldType: Int, Equatable {
    case text = 0
    case hidden = 1
    case boolean = 2
    case linked = 3
}

/// The native item field that a Linked custom field maps to.
/// Only the display name is shown in v1 (see display name table below); no resolve/copy action.
enum LinkedFieldId: Int, Equatable {
    // Login-linked
    case loginUsername = 100
    case loginPassword = 101

    // Identity-linked
    case identityTitle = 300
    case identityMiddleName = 301
    case identityAddress1 = 302
    case identityAddress2 = 303
    case identityAddress3 = 304
    case identityCity = 305
    case identityState = 306
    case identityPostalCode = 307
    case identityCountry = 308
    case identityCompany = 309
    case identityEmail = 310
    case identityPhone = 311
    case identitySSN = 312
    case identityUsername = 313
    case identityPassportNumber = 314
    case identityLicenseNumber = 315
    case identityFirstName = 316
    case identityLastName = 317
    case identityFullName = 318

    /// Human-readable display name shown in the detail pane (English only, v1).
    var displayName: String {
        switch self {
        case .loginUsername:        return "Username"
        case .loginPassword:        return "Password"
        case .identityTitle:        return "Title"
        case .identityFirstName:    return "First Name"
        case .identityMiddleName:   return "Middle Name"
        case .identityLastName:     return "Last Name"
        case .identityFullName:     return "Full Name"
        case .identityCompany:      return "Company"
        case .identityEmail:        return "Email"
        case .identityPhone:        return "Phone"
        case .identityAddress1:     return "Address 1"
        case .identityAddress2:     return "Address 2"
        case .identityAddress3:     return "Address 3"
        case .identityCity:         return "City"
        case .identityState:        return "State / Province"
        case .identityPostalCode:   return "Postal Code"
        case .identityCountry:      return "Country"
        case .identitySSN:          return "Social Security Number"
        case .identityPassportNumber: return "Passport Number"
        case .identityLicenseNumber: return "Licence Number"
        case .identityUsername:     return "Username"
        }
    }
}
```

---

### SidebarSelection

```swift
/// What the user has selected in the sidebar — drives the item list filter.
/// Folders, Collections, and Trash are deferred to future versions.
enum SidebarSelection: Hashable {
    // Menu Items
    case allItems
    case favorites

    // Types
    case type(ItemType)
}

/// Discriminator for item type (used for sidebar Type section).
enum ItemType: Equatable, Hashable, CaseIterable {
    case login
    case card
    case identity
    case secureNote
    case sshKey
}
```

---

### KdfParams

```swift
/// Key derivation function parameters returned by /accounts/prelogin.
/// Stored in Keychain at login time so unlock works offline.
enum KdfType: Int, Codable {
    case pbkdf2   = 0   // PBKDF2-SHA256 — older/migrated accounts
    case argon2id = 1   // Argon2id — default for new accounts since 2023
}

struct KdfParams: Codable {
    let type: KdfType
    let iterations: Int          // PBKDF2: typically 600,000. Argon2id: typically 3.
    let memory: Int?             // Argon2id only — memory in MB (e.g. 64). nil for PBKDF2.
    let parallelism: Int?        // Argon2id only — thread count (e.g. 4). nil for PBKDF2.
}
```

---

### AuthSession (Keychain-persisted)

```swift
/// Opaque session tokens stored in the macOS Keychain.
/// Key material (master key, symmetric key) is held in BitwardenCryptoServiceImpl
/// in-memory only — never persisted.
struct AuthSession {
    let accessToken: String    // Keychain key: "bw.macos:{userId}:accessToken"
    let refreshToken: String   // Keychain key: "bw.macos:{userId}:refreshToken"
    let accountId: String      // Keychain key: "bw.macos:activeUserId" (global)
}
```

---

## State Transitions

```
App Launch
    │
    ├─ No Keychain session found ──► LoginScreen
    │                                     │
    │                                     ▼
    │                               Auth (network)
    │                                     │
    │                          ┌──────────┴─────────────┐
    │                          │ 2FA required           │ No 2FA
    │                          ▼                        ▼
    │                    TOTPPrompt ──────────► SyncProgress
    │
    └─ Keychain session found ───► UnlockScreen
                                        │
                                        ▼
                                   KDF (local only — no network)
                                        │
                                        ▼
                                  SyncProgress (network — vault re-fetched)
                                        │
                                        ▼
                                  VaultBrowser (three-pane)
                                        │
                                   App Quits
                                        │
                                   Vault Locks
                                   (key material zeroed from memory)
```

---

## Vault Decryption Flow

Two-phase decrypt: lightweight list on sync, full detail on item selection.

```
── LOGIN PATH ──────────────────────────────────────────────────────────────

HTTP POST /accounts/prelogin  →  KDF params
    │
    ▼
BitwardenCryptoServiceImpl.hashPassword(email:password:kdfParams:purpose:.serverAuthorization)
    │
    ▼
HTTP POST /connect/token  →  { access_token, refresh_token, Key, PrivateKey, ... }
    │
    ▼
BitwardenCryptoServiceImpl.initializeUserCrypto(masterPassword:email:kdfParams:encUserKey:encPrivateKey:)
    │   (org crypto is NOT called in v1 — org ciphers are excluded)
    │
    ▼
HTTP GET /sync?excludeDomains=true  →  raw SyncResponse JSON
    │
    ▼
BitwardenCryptoServiceImpl.decryptList(ciphers: syncResponse.ciphers)
    │   Returns [VaultItem] — lightweight summaries for item list rows (list-weight fields only).
    │   Only personal ciphers (organizationId == nil) are decrypted; org ciphers skipped.
    │
    ▼
(mapping already applied by crypto service via CipherMapper)
    │
    ▼
VaultRepository stores [VaultItem] in memory

── UNLOCK PATH (relaunch after quit — in-memory vault is gone) ─────────────

BitwardenCryptoServiceImpl.initializeUserCrypto(masterPassword:email:kdfParams:encUserKey:encPrivateKey:)
    │   (KDF is local — no network; uses stored encUserKey + encPrivateKey from Keychain)
    │   (org crypto is NOT called in v1)
    │
    ▼
HTTP GET /sync?excludeDomains=true  →  raw SyncResponse JSON
    │   (vault must be re-fetched; in-memory data was cleared on quit)
    │
    ▼
BitwardenCryptoServiceImpl.decryptList(ciphers: syncResponse.ciphers)
    │
    ▼
VaultRepository stores [VaultItem] in memory

── ON ITEM SELECTION (detail pane) ─────────────────────────────────────────

BitwardenCryptoServiceImpl.decrypt(cipher: selectedRawCipher)
    │   Returns VaultItem — full detail including passwords and custom fields.
    │   Called lazily: only for the currently selected item.
    │
    ▼
(mapping already applied by crypto service via CipherMapper)
    │
    ▼
ItemDetailView renders full content
```

**Note**: `SyncResult` and `SyncError` supporting types are defined in `contracts/SyncRepository.md`.
`VaultRepository.lastSyncedAt` is updated to `SyncResult.syncedAt` only on a **successful** sync;
it is not modified on sync failure.

---

## Validation Rules

| Entity | Rule |
|--------|------|
| `ServerEnvironment` (self-hosted) | `baseURL` must parse as a valid URL with scheme `https` or `http`; trailing slashes stripped (FR-001b) |
| `Account.email` | Non-empty, basic email format (contains `@`) |
| `Account.masterPassword` | Non-empty (login-time only; never stored) |
| `LoginURI.uri` | Stored as-is; no validation (display only in v1) |
| `CustomField.name` | Non-empty string |
