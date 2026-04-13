## MODIFIED Requirements

### Requirement: Edit and create sheets include a folder picker
The system SHALL display a "Folder" picker in both the item edit sheet and the item create sheet when folders exist AND the item is a personal vault item (`organizationId == nil`). The picker SHALL list all folders sorted alphabetically by name, plus a "None" option at the top. For existing items, the picker SHALL pre-select the item's current folder (or "None" if unfoldered). For new items, the picker SHALL default to "None". The selected folder SHALL be included as `folderId` in the cipher payload when saving. When no folders exist, or when the item belongs to an org, the folder picker SHALL NOT be displayed.

#### Scenario: Folder picker shown in edit sheet for personal item
- **WHEN** the user opens the edit sheet for an existing personal item
- **THEN** a "Folder" picker SHALL be displayed listing "None" followed by all folders alphabetically

#### Scenario: Folder picker shown in create sheet for personal item
- **WHEN** the user opens the create sheet for a new personal item
- **THEN** a "Folder" picker SHALL be displayed with "None" pre-selected

#### Scenario: Folder picker hidden for org items
- **GIVEN** the user opens the edit or create sheet for an item belonging to an organization
- **WHEN** the sheet renders
- **THEN** no folder picker SHALL be displayed (org items use collection picker instead)

#### Scenario: Current folder pre-selected on edit
- **GIVEN** a personal item is assigned to folder "Work"
- **WHEN** the edit sheet opens
- **THEN** "Work" SHALL be pre-selected in the folder picker

#### Scenario: Folder selection included in save payload
- **GIVEN** the user selects folder "Personal" in the picker
- **WHEN** the user saves the item
- **THEN** the cipher payload SHALL include `folderId` set to the "Personal" folder's ID

## ADDED Requirements

### Requirement: Create and edit sheets include an org collection picker for org items
The system SHALL display an organization name (read-only) and a "Collection" picker in the item edit sheet when the item belongs to an organization. In the create sheet, when the sidebar context is `.collection(id)`, the org and collection SHALL be pre-selected. The collection picker SHALL list all collections in the item's organization, sorted alphabetically. The selected collection's id SHALL be included in `collectionIds[]` in the cipher payload when saving.

#### Scenario: Collection picker shown in edit sheet for org item
- **WHEN** the user opens the edit sheet for an org item
- **THEN** a "Collection" picker SHALL be displayed showing collections from the item's organization

#### Scenario: Collection pre-selected when creating from collection context
- **GIVEN** the user clicked `+` with `.collection("col1")` active in the sidebar
- **WHEN** the create sheet opens
- **THEN** the org and collection "col1" SHALL be pre-selected

#### Scenario: Collection selection included in save payload
- **GIVEN** the user selects collection "Infrastructure" in the picker
- **WHEN** the user saves
- **THEN** the cipher payload SHALL include `collectionIds = ["<infrastructure-id>"]`

#### Scenario: Org items route to POST /ciphers/create
- **GIVEN** the user saves a new item with a non-nil organizationId
- **WHEN** the create use case executes
- **THEN** `POST /api/ciphers/create` SHALL be called (not `POST /api/ciphers`)
