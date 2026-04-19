## Why

Prizm currently silently discards all Bitwarden organization ciphers and has no concept of collections, meaning users who store passwords in shared org vaults cannot access them. This change unlocks that data and gives users full CRUD parity with the personal vault.

## What Changes

- Decrypt and display org ciphers alongside personal items (requires RSA-OAEP org key unwrap — new crypto primitive)
- Decode `organizations[]` and `collections[]` arrays from the Bitwarden `/sync` response (currently dropped)
- Add `Organization` and `Collection` domain entities
- `VaultItem` gains `organizationId` and `collectionIds` fields (**BREAKING**: mapper, DraftVaultItem, and all write paths updated)
- `SidebarSelection` gains `.organization(id)` and `.collection(id)` cases; sidebar renders org sections with nested collections
- Full item CRUD in org context: create (`POST /ciphers/create`), edit, delete, restore, permanent-delete
- Collection CRUD: create, rename, delete — role-gated (Admin/Owner/Manager only)
- New button is context-aware: `+` in org section creates collection; `+` in collection creates item assigned to that collection
- Item editor gains collection picker (org selector + collection selector)

## Capabilities

### New Capabilities

- `org-key-crypto`: RSA-OAEP-SHA1 unwrap of organization symmetric keys using the user's RSA private key; per-org key cache (`OrgKeyCache`) parallel to `VaultKeyCache`
- `org-collections`: Organization and Collection domain entities, sync decoding, sidebar rendering, and collection CRUD (create/rename/delete with role gate)
- `org-vault-items`: Full CRUD for org-scoped ciphers — read, create, edit, delete, restore, permanent-delete; collection assignment in item editor

### Modified Capabilities

- `vault-browser-ui`: Sidebar gains organization sections with nested collections; `SidebarSelection` extended; item rows badge org membership
- `vault-item-create`: Create flow gains org/collection picker; routes to `POST /ciphers/create` for org items
- `vault-folder-organization`: `+` button becomes context-aware (folder vs collection depending on sidebar context)

## Impact

- **Domain**: `VaultItem`, `DraftVaultItem`, `SidebarSelection`, new `Organization` + `Collection` entities, new use case protocols
- **Data/Crypto**: `PrizmCryptoService` gains RSA decrypt; new `OrgKeyCache`; `CipherMapper` selects key by `organizationId`; `SyncResponse` decodes two new arrays; `SyncRepositoryImpl` populates org/collection state
- **Data/Network**: new API calls — `POST /ciphers/create`, `POST/PUT/DELETE /organizations/{orgId}/collections/{id}`
- **Presentation**: `VaultBrowserViewModel`, `SidebarView`, `ItemEditView`/`ItemEditViewModel`, `ItemDetailView` all updated
- **No new dependencies**: RSA via `Security.framework` (already imported in Data layer)
