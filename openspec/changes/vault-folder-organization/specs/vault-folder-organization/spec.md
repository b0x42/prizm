## ADDED Requirements

### Requirement: User can browse vault items by folder
The system SHALL display a "Folders" section in the sidebar between the Menu section and the Types section. The "Folders" section header SHALL always be visible (even when no folders exist) to provide access to the create button. Each folder row SHALL display the folder name and a badge with the count of items assigned to that folder. Folders SHALL be sorted alphabetically by decrypted name (case-insensitive). Selecting a folder SHALL display all items assigned to that folder in the item list, regardless of item type. The item list SHALL be sorted alphabetically by name, consistent with other sidebar selections. Items without a `folderId` SHALL NOT appear under any folder — they remain accessible via All Items, Favorites, and Type filters only.

#### Scenario: Folders section appears in sidebar with correct counts
- **WHEN** the vault browser opens and the user has folders
- **THEN** a "Folders" section SHALL appear between Menu and Types, with each folder showing its name and item count badge

#### Scenario: Selecting a folder filters the item list
- **WHEN** the user selects a folder in the sidebar
- **THEN** the item list SHALL show only items assigned to that folder, sorted alphabetically by name

#### Scenario: Folders are sorted alphabetically
- **GIVEN** the user has folders named "Work", "Finance", "Personal"
- **WHEN** the sidebar renders
- **THEN** folders SHALL appear in order: Finance, Personal, Work

#### Scenario: Empty folder shows zero count
- **GIVEN** a folder exists with no items assigned
- **WHEN** the sidebar renders
- **THEN** the folder row SHALL display a count of 0

#### Scenario: Folders section header always visible
- **WHEN** the user has no folders
- **THEN** the "Folders" section header with the create button SHALL still appear, but with no folder rows beneath it

#### Scenario: Search scopes to selected folder
- **GIVEN** the user has selected a folder in the sidebar
- **WHEN** the user types a search query
- **THEN** search results SHALL be scoped to items within that folder

---

### Requirement: User can create a folder
The system SHALL provide a button (SF Symbol `folder.badge.plus`) on the "Folders" section header. Clicking the button SHALL create a new folder with a default name "New Folder" and immediately enter inline rename mode so the user can type the desired name. Pressing Enter SHALL commit the name, encrypt it as an EncString type-2, and send `POST /api/folders` to the server. Pressing Escape SHALL cancel creation and remove the uncommitted folder row. The folder name SHALL be encrypted client-side before being sent to the server. Empty or whitespace-only names SHALL be treated as a cancel (the folder row is removed without an API call).

#### Scenario: Create folder via header button
- **WHEN** the user clicks the folder-plus button on the Folders section header
- **THEN** a new folder row SHALL appear with an editable text field containing "New Folder"
- **AND** the text field SHALL be focused for immediate editing

#### Scenario: Commit folder name with Enter
- **GIVEN** the user is editing a new folder name with a non-empty value
- **WHEN** the user presses Enter
- **THEN** the folder name SHALL be encrypted and sent to the server via `POST /api/folders`
- **AND** the folder SHALL appear in the sidebar sorted alphabetically

#### Scenario: Cancel folder creation with Escape
- **GIVEN** the user is editing a new folder name
- **WHEN** the user presses Escape
- **THEN** the new folder row SHALL be removed without making any API call

#### Scenario: Empty name treated as cancel
- **GIVEN** the user is editing a new folder name
- **WHEN** the user clears the name to empty or whitespace-only and presses Enter
- **THEN** the new folder row SHALL be removed without making any API call

#### Scenario: Server error during folder creation
- **GIVEN** the user commits a valid folder name
- **WHEN** the server returns an error
- **THEN** the uncommitted folder row SHALL be removed and an error alert SHALL be shown

---

### Requirement: User can rename a folder
The system SHALL support inline rename of a folder via right-click context menu → "Rename". Selecting "Rename" SHALL activate an inline editable text field on the folder row. Pressing Enter or clicking away SHALL commit the new name, encrypt it, and send `PUT /api/folders/{id}` to the server. Pressing Escape SHALL cancel the rename and restore the previous name. Empty or whitespace-only names SHALL be treated as a cancel.

#### Scenario: Rename via context menu
- **WHEN** the user right-clicks a folder and selects "Rename"
- **THEN** the folder name SHALL become an editable text field with the current name selected

#### Scenario: Commit rename
- **GIVEN** the user is editing a folder name with a non-empty value
- **WHEN** the user presses Enter
- **THEN** the new name SHALL be encrypted and sent to the server via `PUT /api/folders/{id}`
- **AND** the folder SHALL re-sort alphabetically in the sidebar

#### Scenario: Cancel rename
- **GIVEN** the user is editing a folder name
- **WHEN** the user presses Escape
- **THEN** the folder name SHALL revert to its previous value without making any API call

#### Scenario: Empty name on rename treated as cancel
- **GIVEN** the user is editing a folder name
- **WHEN** the user clears the name to empty or whitespace-only and presses Enter
- **THEN** the folder name SHALL revert to its previous value without making any API call

#### Scenario: Server error during rename
- **GIVEN** the user commits a valid new folder name
- **WHEN** the server returns an error
- **THEN** the folder name SHALL revert to its previous value and an error alert SHALL be shown

---

### Requirement: User can delete a folder
The system SHALL allow folder deletion via right-click context menu → "Delete Folder". Deleting a folder SHALL show a confirmation alert explaining that items in the folder will not be deleted but will become unfoldered. Confirming SHALL send `DELETE /api/folders/{id}` to the server. Items previously in the deleted folder SHALL have their `folderId` cleared in the local cache and remain accessible via All Items and Type filters.

#### Scenario: Delete folder via context menu
- **WHEN** the user right-clicks a folder and selects "Delete Folder"
- **THEN** a confirmation alert SHALL appear stating the folder will be deleted and items will be unfoldered

#### Scenario: Confirm folder deletion
- **GIVEN** the delete confirmation alert is shown
- **WHEN** the user confirms
- **THEN** the folder SHALL be removed from the server via `DELETE /api/folders/{id}`
- **AND** the folder SHALL be removed from the sidebar
- **AND** items that were in the folder SHALL have their `folderId` cleared in the local cache

#### Scenario: Cancel folder deletion
- **GIVEN** the delete confirmation alert is shown
- **WHEN** the user cancels
- **THEN** no API call SHALL be made and the folder SHALL remain unchanged

#### Scenario: Server error during folder deletion
- **GIVEN** the user confirms folder deletion
- **WHEN** the server returns an error
- **THEN** the folder SHALL remain in the sidebar unchanged and an error alert SHALL be shown

---

### Requirement: User can assign items to folders via drag-and-drop
The system SHALL support dragging one or more items from the item list onto a folder row in the sidebar. Single-item drops SHALL use `PUT /ciphers/{id}/partial` with the target `folderId`. Multi-item drops SHALL use `PUT /ciphers/move` with the list of item IDs and the target `folderId`. The drop target folder row SHALL show SwiftUI's default `isTargeted` highlight during the drag. After a successful drop, item counts SHALL refresh for both the source and target folders. Drag-and-drop SHALL only be available from the active item list — trashed items SHALL NOT be draggable.

#### Scenario: Drag single item to folder
- **GIVEN** an item is displayed in the item list
- **WHEN** the user drags the item onto a folder row in the sidebar
- **THEN** the item SHALL be moved to that folder via `PUT /ciphers/{id}/partial`
- **AND** sidebar folder counts SHALL refresh

#### Scenario: Drag multiple items to folder
- **GIVEN** multiple items are selected in the item list
- **WHEN** the user drags the selection onto a folder row
- **THEN** all selected items SHALL be moved to that folder via `PUT /ciphers/move`
- **AND** sidebar folder counts SHALL refresh

#### Scenario: Drop target highlights during drag
- **WHEN** the user drags an item over a folder row
- **THEN** the folder row SHALL show the default SwiftUI drop target highlight

#### Scenario: Drag to move between folders
- **GIVEN** an item is in folder "Work"
- **WHEN** the user drags it onto folder "Personal"
- **THEN** the item's `folderId` SHALL change to "Personal" and counts for both folders SHALL update

#### Scenario: Trashed items are not draggable
- **GIVEN** the user is viewing the Trash
- **THEN** items in the Trash SHALL NOT be draggable to folders

#### Scenario: Server error during drag-and-drop move
- **GIVEN** the user drops an item onto a folder
- **WHEN** the server returns an error
- **THEN** the local cache SHALL NOT be updated and an error alert SHALL be shown

---

### Requirement: User can assign a folder via the item edit sheet
The system SHALL display a folder picker in the item edit and create sheets. The picker SHALL list all folders sorted alphabetically, plus a "None" option to remove folder assignment. Selecting a folder SHALL set the `folderId` on the draft. The `folderId` SHALL be included in the cipher payload when saving via `PUT /ciphers/{id}` or `POST /api/ciphers`.

#### Scenario: Folder picker shown in edit sheet
- **WHEN** the user opens the edit sheet for an item
- **THEN** a "Folder" picker SHALL be displayed with all folders and a "None" option

#### Scenario: Current folder is pre-selected
- **GIVEN** an item is assigned to folder "Work"
- **WHEN** the edit sheet opens
- **THEN** "Work" SHALL be pre-selected in the folder picker

#### Scenario: Change folder via picker
- **GIVEN** the edit sheet is open
- **WHEN** the user selects a different folder and saves
- **THEN** the item's `folderId` SHALL be updated on the server

#### Scenario: Remove folder assignment
- **GIVEN** an item is assigned to a folder
- **WHEN** the user selects "None" in the folder picker and saves
- **THEN** the item's `folderId` SHALL be set to nil on the server

#### Scenario: Assign folder on new item creation
- **WHEN** the user creates a new item and selects a folder in the picker
- **THEN** the new item SHALL be created with the selected `folderId`
