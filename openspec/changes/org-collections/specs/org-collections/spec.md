## ADDED Requirements

### Requirement: Organization and Collection domain entities exist
The Domain layer SHALL define an `Organization` struct with fields: `id: String`, `name: String`, `role: OrgRole`, and `canManageCollections: Bool` (derived from role). `OrgRole` SHALL be an enum: `.owner`, `.admin`, `.manager`, `.user`, `.custom`. The Domain layer SHALL define a `Collection` struct with fields: `id: String`, `organizationId: String`, `name: String`. Both are value types (`struct`). No crypto imports in the Domain layer.

#### Scenario: Organization entity accessible from Domain layer
- **WHEN** a use case or repository protocol references `Organization`
- **THEN** it SHALL compile with `import Foundation` only (no crypto, no SwiftUI)

#### Scenario: canManageCollections reflects role
- **GIVEN** an `Organization` with role `.user`
- **WHEN** `canManageCollections` is read
- **THEN** it SHALL return `false`

#### Scenario: canManageCollections true for admin roles
- **GIVEN** an `Organization` with role `.owner`, `.admin`, or `.manager`
- **WHEN** `canManageCollections` is read
- **THEN** it SHALL return `true`

---

### Requirement: Organizations and collections are decoded from sync response
`SyncResponse` SHALL decode `organizations: [RawOrganization]` and `collections: [RawCollection]` arrays from the Bitwarden `/sync` endpoint. Both arrays SHALL default to `[]` when absent (for Vaultwarden instances without org support). `RawOrganization` SHALL include: `id`, `name`, `key` (RSA-encrypted EncString), `type` (Int: 0=Owner, 1=Admin, 2=Manager, 3=User, 4=Custom). `RawCollection` SHALL include: `id`, `organizationId`, `name` (EncString encrypted with org key).

#### Scenario: Sync response with organizations decoded
- **WHEN** the `/sync` endpoint returns an `Organizations` array
- **THEN** `SyncResponse.organizations` SHALL contain the decoded entries

#### Scenario: Sync response without organizations defaults to empty
- **WHEN** the `/sync` endpoint omits the `Organizations` key
- **THEN** `SyncResponse.organizations` SHALL be `[]` without throwing

#### Scenario: Collection names decrypted with org key
- **WHEN** sync populates collections
- **THEN** each collection's name SHALL be decrypted using the org's symmetric key from `OrgKeyCache`

---

### Requirement: Sidebar displays an Organizations section with nested collections
The sidebar SHALL display an "Organizations" section below the Folders section. Each organization SHALL appear as a disclosure group showing the org name. Within each org, each collection the user has access to SHALL appear as a child row showing the collection name and a badge with the count of items assigned to it. Selecting an org row SHALL show all items across all of that org's collections. Selecting a collection row SHALL show only items whose `collectionIds` contains that collection's id.

#### Scenario: Organizations section appears below Folders
- **WHEN** the vault browser opens and the user belongs to at least one organization
- **THEN** an "Organizations" section SHALL appear in the sidebar below the Folders section

#### Scenario: Selecting an org shows all its items
- **WHEN** the user selects an organization row in the sidebar
- **THEN** the item list SHALL show all items belonging to any collection in that org

#### Scenario: Selecting a collection filters to that collection
- **WHEN** the user selects a collection row under an org
- **THEN** the item list SHALL show only items whose `collectionIds` contains that collection's id

#### Scenario: Collection item count badge is accurate
- **GIVEN** a collection contains 5 items
- **WHEN** the sidebar renders
- **THEN** the collection row SHALL display a badge showing 5

#### Scenario: No Organizations section when user has no orgs
- **WHEN** the user belongs to no organizations
- **THEN** no "Organizations" section SHALL appear in the sidebar

---

### Requirement: User can create a collection (role-gated)
The Organizations section header SHALL display a `+` button when the active sidebar selection is `.organization(id)` and the user's role in that org has `canManageCollections == true`. Clicking the button SHALL create an inline editable row for the collection name (matching the folder creation UX pattern). Committing a non-empty name SHALL encrypt it with the org key and call `POST /organizations/{orgId}/collections`. Pressing Escape or submitting an empty name SHALL cancel without an API call.

#### Scenario: Create button visible for admin role
- **GIVEN** the user has role Admin or Owner in the org
- **WHEN** the user selects that org in the sidebar
- **THEN** a `+` button SHALL appear on the Organizations section or org disclosure header

#### Scenario: Create button hidden for user role
- **GIVEN** the user has role User in the org
- **WHEN** the sidebar renders
- **THEN** no collection `+` button SHALL be displayed for that org

#### Scenario: Commit creates collection via API
- **GIVEN** the user types "Dev Tools" in the inline collection name field
- **WHEN** the user presses Enter
- **THEN** the name SHALL be encrypted with the org key and sent via `POST /organizations/{orgId}/collections`
- **AND** the new collection SHALL appear in the sidebar sorted alphabetically

#### Scenario: Escape cancels collection creation
- **WHEN** the user presses Escape while editing a new collection name
- **THEN** the row SHALL be removed with no API call

---

### Requirement: User can rename a collection (role-gated)
Right-clicking a collection row SHALL show a context menu with "Rename" (only if `canManageCollections == true` for that org). Selecting Rename SHALL activate inline editing. Committing a non-empty name SHALL encrypt it with the org key and call `PUT /organizations/{orgId}/collections/{id}`.

#### Scenario: Rename available for admin role
- **GIVEN** the user has role Admin or Owner in the org
- **WHEN** the user right-clicks a collection
- **THEN** a "Rename" option SHALL appear in the context menu

#### Scenario: Rename not available for user role
- **GIVEN** the user has role User in the org
- **WHEN** the user right-clicks a collection
- **THEN** no "Rename" option SHALL appear

#### Scenario: Commit rename updates collection name
- **GIVEN** the user is renaming a collection to "Infrastructure"
- **WHEN** the user presses Enter
- **THEN** the name SHALL be encrypted and sent via `PUT /organizations/{orgId}/collections/{id}`
- **AND** the collection SHALL re-sort alphabetically

---

### Requirement: User can delete a collection (role-gated)
Right-clicking a collection row SHALL show a context menu with "Delete Collection" (only if `canManageCollections == true`). Confirming deletion SHALL call `DELETE /organizations/{orgId}/collections/{id}`. Items that were in the deleted collection SHALL remain in the vault (they are not deleted — their `collectionIds` simply no longer matches a known collection).

#### Scenario: Delete option available for admin role
- **GIVEN** the user has role Admin or Owner in the org
- **WHEN** the user right-clicks a collection
- **THEN** a "Delete Collection" option SHALL appear in the context menu

#### Scenario: Confirmation required before delete
- **WHEN** the user selects "Delete Collection"
- **THEN** a confirmation alert SHALL appear before the API call is made

#### Scenario: Collection removed from sidebar after delete
- **GIVEN** the user confirms deletion
- **WHEN** `DELETE /organizations/{orgId}/collections/{id}` succeeds
- **THEN** the collection row SHALL be removed from the sidebar
