## 1. Domain Entities

- [x] 1.1 Add `OrgRole` enum (`.owner`, `.admin`, `.manager`, `.user`, `.custom`) to Domain layer
- [x] 1.2 Add `Organization` struct (`id`, `name`, `role`, `canManageCollections`) to Domain layer
- [x] 1.3 Add `Collection` struct (`id`, `organizationId`, `name`) to Domain layer
- [x] 1.4 Extend `VaultItem` with `organizationId: String?` and `collectionIds: [String]` (defaulted in init)
- [x] 1.5 Extend `DraftVaultItem` with `organizationId: String?` and `collectionIds: [String]`
- [x] 1.6 Extend `SidebarSelection` with `.organization(String)` and `.collection(String)` cases; update `==`, `hash`, `displayName`
- [x] 1.7 Extend `VaultRepository` protocol with `organizations()`, `collections()`, `items(for collection: String)` methods
- [x] 1.8 Add `CreateCollectionUseCase`, `RenameCollectionUseCase`, `DeleteCollectionUseCase` protocols to Domain layer

## 2. Wire Models & Sync Decoding

- [x] 2.0 Write failing unit tests for `SyncResponse` decoding: orgs + collections present; orgs + collections absent (default `[]`) — RED before any wire model code (Constitution §IV)
- [x] 2.1 Add `RawOrganization` Codable struct (`id`, `name`, `key`, `type`)
- [x] 2.2 Add `RawCollection` Codable struct (`id`, `organizationId`, `name`)
- [x] 2.3 Extend `SyncResponse` to decode `organizations: [RawOrganization]` and `collections: [RawCollection]` (default `[]`, support both camelCase and PascalCase keys)
- [x] 2.4 Add `collectionIds: [String]` to `RawCipher` (Bitwarden sync returns `CollectionIds` array on each cipher; required to populate `VaultItem.collectionIds`)
- [ ] 2.5 Verify tests from 2.0 are GREEN

## 3. Org Key Crypto (Phase 1 — the hard part)

- [x] 3.0 Write failing KATs BEFORE any crypto implementation (Constitution §IV — Red first):
  - KAT: RSA org key unwrap using a known Bitwarden test vector
  - KAT: org cipher field decryption (org key → AES-CBC): known fixture → assert plaintext
  - KAT: collection name encryption with org key: known plaintext → EncString round-trip
  - Unit test: `OrgKeyCache` cleared and key bytes zeroed on lock
  - Unit test: `CipherMapper` org cipher path (org key selected, per-item key with org key, missing org key → skip)
- [x] 3.1 Add `OrgKeyCache` actor (`[orgId: CryptoKeys]`); on clear, zero each `CryptoKeys` entry's underlying `Data` bytes before removing (Constitution §III); clear in `lockVault()` alongside `VaultKeyCache`
- [x] 3.2 Extend `PrizmCryptoService` protocol with `decryptRSAPrivateKey(encPrivateKey:vaultKeys:) -> Data` and `unwrapOrgKey(encOrgKey:rsaPrivateKey:) -> CryptoKeys`
- [x] 3.3 Implement `decryptRSAPrivateKey` in `PrizmCryptoServiceImpl`: decrypt profile `privateKey` EncString with vault symmetric key; hold result in actor state using a zeroing `Data` wrapper; zero on lock (Constitution §III)
- [x] 3.4 Implement `unwrapOrgKey` in `PrizmCryptoServiceImpl`: strip PKCS#8 wrapper from decrypted private key bytes to obtain raw RSA key; import via `SecKeyCreateWithData`; decrypt org key EncString via `SecKeyCreateDecryptedData` with `kSecKeyAlgorithmRSAEncryptionOAEPSHA1`
- [ ] 3.5 Verify KATs from 3.0 are GREEN
- [x] 3.6 Update `SyncRepositoryImpl.sync()` to: (a) decrypt RSA private key, (b) unwrap each org key into `OrgKeyCache`, (c) populate `VaultRepository` with organizations and collections; pass `OrgKeyCache` snapshot (not actor reference) into `CipherMapper` to keep `map()` synchronous
- [x] 3.7 Update `CipherMapper.map(raw:keys:)` to accept `orgKeys: [String: CryptoKeys]` snapshot; select org `CryptoKeys` when `raw.organizationId != nil`; decrypt per-item key with org key when both present
- [x] 3.8 Update `CipherMapper.map` to set `organizationId` and `collectionIds` (from `raw.collectionIds`) on the resulting `VaultItem`
- [x] 3.9 Update `CipherMapper.toRawCipher` to accept `keys: CryptoKeys` (caller responsibility to pass org key for org items, vault key for personal); round-trip `organizationId` and `collectionIds` (remove hardcoded `nil`)
- [x] 3.10 Update `VaultRepositoryImpl.update` and `VaultRepositoryImpl.create` to look up org key from `OrgKeyCache` when `draft.organizationId != nil` and pass it to `toRawCipher`; personal items continue to use vault key

## 4. Repository & Use Case Implementations

- [x] 4.0 Write failing unit tests BEFORE implementation (Constitution §IV — Red first):
  - `VaultRepository` `.collection(id)` filtering returns only items with matching `collectionIds`
  - `VaultRepository` `.organization(id)` filtering returns items from all org collections
  - `CreateCollectionUseCase` encrypts name with org key (not vault key)
  - `RenameCollectionUseCase` encrypts new name with org key
  - `DeleteCollectionUseCase` removes collection from local cache
  - Personal item create routes to `POST /api/ciphers`; org item routes to `POST /api/ciphers/create`
- [x] 4.1 Extend `VaultRepositoryImpl` to store and serve `[Organization]` and `[Collection]`; implement `organizations()`, `collections()`, `items(for collection:)`
- [x] 4.2 Update `VaultRepositoryImpl.items(for selection:)` to handle `.organization(id)` and `.collection(id)` cases; update `itemCounts()` to include org/collection counts
- [x] 4.3 Implement `CreateCollectionUseCaseImpl`: encrypt name with org key → `POST /organizations/{orgId}/collections`; insert into local cache
- [x] 4.4 Implement `RenameCollectionUseCaseImpl`: encrypt name with org key → `PUT /organizations/{orgId}/collections/{id}`; update local cache
- [x] 4.5 Implement `DeleteCollectionUseCaseImpl`: `DELETE /organizations/{orgId}/collections/{id}`; remove from local cache
- [x] 4.6 Update `VaultRepositoryImpl.create` to route to `POST /api/ciphers/create` when `draft.organizationId != nil`, including `collectionIds` in body
- [x] 4.7 Update `VaultRepositoryImpl.update` to include `organizationId` and `collectionIds` in `PUT /ciphers/{id}` body
- [x] 4.8 Wire new use cases into `AppContainer`
- [ ] 4.9 Verify tests from 4.0 are GREEN

## 5. Sidebar — Organizations Section

- [x] 5.1 Update `SidebarView` to render an "Organizations" section below Folders (hidden when no orgs)
- [x] 5.2 Render each org as a `DisclosureGroup` with its name; child rows for each collection with item count badge
- [x] 5.3 Wire `.organization(id)` and `.collection(id)` selections to `VaultBrowserViewModel.selection`
- [x] 5.4 Add context-aware `+` button to org disclosure header: hidden when `canManageCollections == false`; triggers inline collection creation when visible
- [x] 5.5 Implement inline collection creation UX (matching existing inline folder creation pattern): Enter commits, Escape cancels, empty name cancels
- [x] 5.6 Add right-click context menu on collection rows: "Rename" and "Delete Collection" (role-gated)
- [x] 5.7 Implement inline collection rename (matching folder rename pattern)
- [x] 5.8 Implement collection delete with confirmation alert
- [x] 5.9 Update `+` button in collection context to open item create sheet pre-filled with that collection

## 6. Item List & Detail

- [x] 6.1 Add org membership badge to item list rows (small secondary label showing org name) when `organizationId != nil`
- [x] 6.2 Update item detail pane to show "Organization" read-only field row when `organizationId != nil`
- [x] 6.3 Verify delete/restore/permanent-delete work for org items (endpoints are identical — confirm no mapper regressions)

## 7. Item Create / Edit — Collection Picker

- [x] 7.1 Add `organizationId` and `collectionIds` to `ItemEditViewModel`
- [x] 7.2 In create sheet: when context is `.collection(id)`, pre-populate `organizationId` and `collectionIds` in the view model
- [x] 7.3 Add collection picker to item edit/create sheet (shown only for org items; hidden for personal items)
- [x] 7.4 Hide folder picker for org items (collection picker replaces it)
- [x] 7.5 Wire collection picker selection back to `DraftVaultItem.collectionIds`

## 8. Tests

- [x] 8.1 XCTest: `OrgKeyCache` cleared on lock
- [x] 8.2 XCTest: `SyncRepositoryImpl` populates orgs and collections after sync
- [x] 8.3 XCTest: `VaultRepository` `.collection(id)` filtering returns only items with matching `collectionIds`
- [x] 8.4 XCTest: `VaultRepository` `.organization(id)` filtering returns items from all org collections
- [x] 8.5 XCTest: `CreateCollectionUseCase` encrypts name with org key (not vault key)
- [x] 8.6 XCTest: Personal item create still routes to `POST /api/ciphers`
- [x] 8.7 XCTest: Org item create routes to `POST /api/ciphers/create` with correct body

## 9. Constitution Compliance

- [x] 9.1 Add doc comment block to every new Data/Crypto file (`OrgKeyCache`, RSA unwrap implementation): document purpose, algorithm (RSA-OAEP-SHA1), spec reference (Bitwarden Security Whitepaper §4), and known limitations (Constitution §VII)
- [x] 9.2 Add inline comments to `unwrapOrgKey`: explain PKCS#8 stripping, `kSecKeyAlgorithmRSAEncryptionOAEPSHA1` selection, and why SHA-1 is used here (Bitwarden protocol requirement, not a free choice) (Constitution §VII)
- [x] 9.3 Update `SECURITY.md`: document org symmetric key lifecycle (RSA-wrapped in sync response, unwrapped into `OrgKeyCache`, zeroed on lock), and RSA private key lifecycle (Constitution §VII)
