## Context

Prizm is a Bitwarden-compatible macOS vault client. All ciphers belong to either a personal vault or an organization vault. Personal ciphers are encrypted with the user's symmetric vault key. Org ciphers are encrypted with an organization-level symmetric key, which is itself wrapped (RSA-encrypted) for each org member using their RSA public key. The user's RSA private key is stored in the sync response's `profile.privateKey` field, encrypted with the vault symmetric key.

Today, Prizm parses `organizationId` on `RawCipher` but throws `organisationCipherSkipped` at map time, discarding all org data. `SyncResponse` does not decode `organizations[]` or `collections[]` at all. There is zero RSA code in the project. `VaultItem`, `DraftVaultItem`, and `SidebarSelection` have no org/collection concepts.

## Goals / Non-Goals

**Goals:**
- Unlock org ciphers using RSA-OAEP-SHA1 key unwrap via `Security.framework`
- Decode and cache organizations and collections from `/sync`
- Display org items in the vault browser (alongside personal items in All Items; filterable by org/collection in sidebar)
- Full item CRUD in org context (read, create, edit, delete, restore, permanent-delete)
- Collection CRUD (create, rename, delete) with org-role gate
- Context-aware `+` button for creating collections vs items based on sidebar selection

**Non-Goals:**
- Multi-account support (one Bitwarden account at a time — unchanged)
- Organization management (inviting members, changing roles, org settings)
- Collection access control per user (accept whatever the server returns)
- Offline creation of org items (requires network like personal items)
- Bitwarden collection "groups" feature

## Decisions

### 1. RSA via `Security.framework`, no new dependencies

`Security.framework` already imported in the Data layer. `SecKeyCreateDecryptedData` with `kSecKeyAlgorithmRSAEncryptionOAEPSHA1` implements the Bitwarden org key unwrap exactly. CryptoKit does not expose RSA; adding a third-party library is ruled out by Constitution §III ("vetted crypto only"). `Security.framework` is the platform-native, App Sandbox-compatible path.

**Alternative considered**: `swift-crypto` — rejected; adds a dependency for a single operation already available natively.

### 2. OrgKeyCache parallel to VaultKeyCache

A new `OrgKeyCache` actor stores `[orgId: CryptoKeys]`, populated at sync time when org symmetric keys are unwrapped. `VaultKeyCache` stores per-cipher effective keys (unchanged). At lock time both caches are cleared together. This mirrors the existing architecture without coupling org key lifecycle to per-cipher key lifecycle.

**Alternative considered**: folding org keys into `VaultKeyCache` — rejected; different granularity (one per org vs one per cipher) and different derivation path would muddy the existing abstraction.

### 3. Org key unwrap at sync time, not on-demand

Org keys are unwrapped once during `SyncRepositoryImpl.sync()` (same timing as cipher key population in `VaultKeyCache`). All org ciphers are then decrypted immediately (eager, matching existing personal cipher behaviour). This keeps `VaultItem` as a plain decrypted struct and avoids deferred crypto in the Presentation layer.

**Alternative considered**: lazy unwrap per cipher access — rejected; inconsistent with existing eager-decrypt pattern, adds async complexity in read paths.

### 4. VaultItem gains organizationId + collectionIds; DraftVaultItem mirrors

`VaultItem` adds `organizationId: String?` and `collectionIds: [String]`. `DraftVaultItem` mirrors these. `CipherMapper.toRawCipher` round-trips both fields unchanged for org items (instead of hardcoding `organizationId: nil`). Personal items continue to pass `organizationId: nil` and `collectionIds: []`.

### 5. Separate create endpoint for org items

Bitwarden uses `POST /api/ciphers` for personal items and `POST /api/ciphers/create` for org items (the latter accepts `collectionIds[]`). `CreateVaultItemUseCaseImpl` / `VaultRepositoryImpl.create` will route based on whether `draft.organizationId` is non-nil.

### 6. Context-aware `+` button via SidebarSelection

The `+` button already resolves its action from the active `SidebarSelection`. Extending `SidebarSelection` with `.organization(id)` and `.collection(id)` is sufficient: when the selection is `.organization`, `+` opens inline collection creation; when `.collection`, `+` opens item creation pre-filled with that collection. No structural change to the button itself.

### 7. Role gate as a computed property on Organization entity

`Organization` exposes `var canManageCollections: Bool` derived from its `role` field. The sidebar `+` button on the organization section is hidden when `canManageCollections == false`. This is a pure Domain-layer check — no network call.

## Risks / Trade-offs

- **RSA key import** — `SecKeyCreateWithData` requires the DER-encoded RSA private key (not PEM). Bitwarden stores the private key as an EncString; after decrypting we get PKCS#8 DER bytes. Need to strip PKCS#8 wrapper to get the raw RSA key for `Security.framework`. → Mitigation: unit-test key import with a known test vector before integration.

- **Org key unavailable mid-session** — If an org key fails to unwrap (e.g. corrupted EncString), the org's ciphers are skipped with a logged fault. Users see no org items rather than a crash. → Acceptable degradation; matches the existing `organisationCipherSkipped` pattern.

- **Collection many-to-many** — A cipher can belong to multiple collections. `SidebarSelection.collection(id)` filters to ciphers whose `collectionIds` contains the selected id. Item counts in sidebar reflect this (a cipher in 2 collections increments both counts). This is consistent with Bitwarden's data model.

- **CipherMapper breaking change** — Adding `organizationId` and `collectionIds` to `VaultItem` is a compile-time breaking change across all call sites. All existing tests and use cases will need updates. → Mitigated by the defaulted memberwise `init` pattern already established on `VaultItem`.

## Open Questions

- Should items belonging to an org show a visible badge (org name / icon) in the item list row, or just appear mixed with personal items? Decision needed before Presentation work. (Lean: yes, small badge — differentiates shared items visually.)
- Bitwarden supports "hide passwords" per collection (admin-set). Ignore for v1 or surface as read-only flag? (Lean: ignore v1.)
