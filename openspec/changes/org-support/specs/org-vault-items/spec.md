## ADDED Requirements

### Requirement: VaultItem carries organizationId and collectionIds
`VaultItem` SHALL include `organizationId: String?` (nil for personal items) and `collectionIds: [String]` (empty for personal items). `DraftVaultItem` SHALL mirror these fields. `CipherMapper.toRawCipher` SHALL round-trip `organizationId` and `collectionIds` unchanged for org items. All existing `VaultItem` init call sites SHALL continue to compile via default parameter values (`organizationId: nil`, `collectionIds: []`).

#### Scenario: Personal item has nil organizationId
- **GIVEN** a personal vault item is decrypted
- **WHEN** `VaultItem` is created by `CipherMapper`
- **THEN** `organizationId` SHALL be nil and `collectionIds` SHALL be `[]`

#### Scenario: Org item carries organizationId and collectionIds
- **GIVEN** a cipher with `organizationId = "abc"` and `collectionIds = ["col1", "col2"]`
- **WHEN** `CipherMapper.map` is called
- **THEN** the resulting `VaultItem` SHALL have `organizationId = "abc"` and `collectionIds = ["col1", "col2"]`

---

### Requirement: Org items appear in All Items and in their collection sidebar selection
Org items SHALL be included in the "All Items" sidebar selection alongside personal items. Org items SHALL appear when the user selects `.collection(id)` where `id` is in the item's `collectionIds`. Org items SHALL be excluded from folder selections (personal folders are not org collections). Org items SHALL appear in type-based sidebar selections (Login, Card, etc.) regardless of org membership.

#### Scenario: Org items visible in All Items
- **GIVEN** the user has 3 personal items and 2 org items
- **WHEN** the user selects All Items
- **THEN** all 5 items SHALL appear in the item list

#### Scenario: Org items filterable by collection
- **GIVEN** item X has `collectionIds = ["col1"]`
- **WHEN** the user selects `.collection("col1")` in the sidebar
- **THEN** item X SHALL appear in the item list

#### Scenario: Org items excluded from folder selections
- **GIVEN** an org item exists with `organizationId = "org1"`
- **WHEN** the user selects a personal folder in the sidebar
- **THEN** the org item SHALL NOT appear in the item list

#### Scenario: Org item detail pane shows organization badge
- **GIVEN** the user selects an org item in the item list
- **WHEN** the detail pane renders
- **THEN** the item's organization name SHALL be displayed as a read-only badge or field row

---

### Requirement: Org items support full CRUD
The system SHALL support create, edit, delete, restore, and permanent-delete operations for org-scoped ciphers. These operations SHALL use the org's symmetric key for encryption/decryption. Delete, restore, and permanent-delete SHALL use the same endpoints as personal items (`PUT /ciphers/{id}/delete`, `PUT /ciphers/{id}/restore`, `DELETE /ciphers/{id}`).

#### Scenario: Delete org item
- **GIVEN** the user initiates delete on an org item
- **WHEN** confirmed
- **THEN** `PUT /ciphers/{id}/delete` SHALL be called and the item SHALL move to Trash

#### Scenario: Restore org item
- **GIVEN** an org item is in Trash
- **WHEN** the user restores it
- **THEN** `PUT /ciphers/{id}/restore` SHALL be called and the item SHALL return to the active vault

#### Scenario: Permanently delete org item
- **GIVEN** an org item is in Trash
- **WHEN** the user permanently deletes it
- **THEN** `DELETE /ciphers/{id}` SHALL be called and the item SHALL be removed from the vault

---

### Requirement: Create org item uses the correct endpoint and encrypts with org key
Creating a new item assigned to an org SHALL call `POST /api/ciphers/create` (not `POST /api/ciphers`). The request body SHALL include `organizationId`, `collectionIds[]`, and all cipher fields encrypted with the org's symmetric key. The item editor SHALL route to this endpoint when `draft.organizationId` is non-nil.

#### Scenario: Org item creation routes to /ciphers/create
- **GIVEN** the user creates an item with `organizationId = "org1"` and `collectionIds = ["col1"]`
- **WHEN** the user saves
- **THEN** the system SHALL call `POST /api/ciphers/create` with `organizationId` and `collectionIds` in the body

#### Scenario: Org item fields encrypted with org key
- **GIVEN** the user saves an org item
- **WHEN** `CipherMapper.toRawCipher` is called
- **THEN** all EncString fields SHALL be encrypted using the org's `CryptoKeys` (not the personal vault key)

#### Scenario: Personal item creation unaffected
- **GIVEN** the user creates an item with no org selected
- **WHEN** the user saves
- **THEN** the system SHALL call `POST /api/ciphers` and encrypt with the personal vault key

---

### Requirement: Edit org item round-trips organizationId and collectionIds
Editing an org item SHALL call `PUT /ciphers/{id}` with `organizationId` and `collectionIds` preserved in the request body. The item editor SHALL allow changing the collection assignment within the same org. Moving an item between orgs is not supported (out of scope).

#### Scenario: Edit org item encrypts fields with org key
- **GIVEN** the user edits an org item belonging to org "org1"
- **WHEN** `CipherMapper.toRawCipher` is called by `VaultRepositoryImpl.update`
- **THEN** the caller SHALL look up "org1"'s `CryptoKeys` from `OrgKeyCache` and pass them to `toRawCipher` (not the personal vault key); all EncString fields SHALL be encrypted with the org key

#### Scenario: Edit org item preserves organizationId
- **GIVEN** the user edits an org item belonging to org "org1"
- **WHEN** the user saves
- **THEN** the `PUT /ciphers/{id}` body SHALL include `organizationId = "org1"`

#### Scenario: Collection assignment editable in item editor
- **GIVEN** the user opens the edit sheet for an org item
- **WHEN** the collection picker is displayed
- **THEN** the user SHALL be able to change the collection assignment within the same org

---

### Requirement: Item editor shows org and collection pickers
When the user opens the create sheet with `.collection(id)` sidebar context, the editor SHALL pre-select that collection. When editing an existing org item, the editor SHALL show the org name (read-only) and a collection picker populated with collections from that org. For new items created from All Items or type selections, an optional org picker SHALL allow assigning to an org + collection.

#### Scenario: Pre-selected collection when creating from collection context
- **GIVEN** the user clicks `+` while a collection is selected in the sidebar
- **WHEN** the create sheet opens
- **THEN** the org and collection SHALL be pre-selected in the picker

#### Scenario: Collection picker shown for org items in edit sheet
- **GIVEN** the user opens the edit sheet for an org item
- **WHEN** the sheet renders
- **THEN** a collection picker SHALL be displayed showing collections from the item's org

#### Scenario: No org picker shown for personal items
- **GIVEN** the user opens the edit or create sheet for a personal item
- **WHEN** the sheet renders
- **THEN** no organization picker SHALL appear
