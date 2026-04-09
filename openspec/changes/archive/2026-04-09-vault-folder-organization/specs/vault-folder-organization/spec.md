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
The system SHALL support dragging a single item from the item list onto a folder row in the sidebar using `PUT /ciphers/{id}/partial` with the target `folderId`. The drop target folder row SHALL show SwiftUI's default `isTargeted` highlight during the drag. After a successful drop, item counts SHALL refresh for both the source and target folders. Drag-and-drop SHALL only be available from the active item list — trashed items SHALL NOT be draggable. Multi-select drag-and-drop is deferred to a follow-up change.

#### Scenario: Drag single item to folder
- **GIVEN** an item is displayed in the item list
- **WHEN** the user drags the item onto a folder row in the sidebar
- **THEN** the item SHALL be moved to that folder via `PUT /ciphers/{id}/partial`
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
The system SHALL display a folder picker in the item edit and create sheets when folders exist. The picker SHALL list all folders sorted alphabetically, plus a "None" option to remove folder assignment. Selecting a folder SHALL set the `folderId` on the draft. The `folderId` SHALL be included in the cipher payload when saving via `PUT /ciphers/{id}` or `POST /api/ciphers`. When no folders exist, the picker SHALL NOT be displayed.

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

---

### Requirement: Sidebar displays nested folders as a collapsible tree

The system SHALL parse folder names using `/` as a hierarchy delimiter and render nested folders as a tree in the sidebar. A folder named `"Work/Projects"` SHALL appear as a child node under `"Work"`. If a parent path (e.g. `"Work"`) has no corresponding flat folder entry, it SHALL be rendered as a non-selectable virtual parent node — it cannot be selected or receive drag-and-drop. Real parent folders (where the flat entry exists) ARE selectable and receive drops. Parent nodes with at least one child SHALL display a disclosure arrow. Clicking the disclosure arrow collapses or expands child folder rows. Collapse state is per-session. Selecting a folder (real or virtual) shows only items whose `folderId` matches that exact folder — child folder items are NOT included.

#### Scenario: Slash-delimited names render as nested tree
- **GIVEN** the user has folders "Work" and "Work/Projects"
- **WHEN** the sidebar renders
- **THEN** "Work" SHALL appear as a parent row with a disclosure arrow
- **AND** "Work/Projects" SHALL appear indented beneath "Work"

#### Scenario: Virtual parent is non-selectable
- **GIVEN** the user has a folder "Finance/Tax" but no "Finance" folder
- **WHEN** the sidebar renders
- **THEN** "Finance" SHALL appear as a non-selectable virtual parent with a disclosure arrow
- **AND** "Finance/Tax" SHALL appear indented beneath "Finance"

#### Scenario: Collapse hides child rows
- **GIVEN** a parent folder "Work" is expanded and shows "Work/Projects" beneath it
- **WHEN** the user clicks the disclosure arrow on "Work"
- **THEN** "Work/Projects" SHALL be hidden from the sidebar

#### Scenario: Expand restores child rows
- **GIVEN** a parent folder "Work" is collapsed
- **WHEN** the user clicks its disclosure arrow
- **THEN** all child folders of "Work" SHALL reappear in the sidebar

#### Scenario: Selecting a folder does not include child items
- **GIVEN** folder "Work" has 2 items and folder "Work/Projects" has 3 items
- **WHEN** the user selects "Work" in the sidebar
- **THEN** the item list SHALL show only the 2 items directly assigned to "Work"

#### Scenario: Badge count reflects direct assignments only
- **GIVEN** folder "Work" has 2 directly assigned items and folder "Work/Projects" has 3 items
- **WHEN** the sidebar renders
- **THEN** the "Work" badge SHALL show 2 and the "Work/Projects" badge SHALL show 3

#### Scenario: Nesting hint shown during folder creation
- **WHEN** the inline folder creation text field is active
- **THEN** the placeholder text SHALL read `"Name or Parent/Name"`
- **AND** a help tooltip or accessible hint SHALL explain: `"Nest a folder by adding the parent folder's name followed by a /. Example: Social/Forums"`

#### Scenario: Nesting hint shown during folder rename
- **WHEN** the inline folder rename text field is active
- **THEN** the same placeholder and help hint SHALL be present

---

### Requirement: Folder picker in item edit sheet matches field-row style

The folder picker in the item edit and create sheets SHALL follow the same visual style as other field rows — a label above a value, with consistent horizontal padding, a separator, and no visible bordered button chrome. The picker SHALL use a menu presentation style so the label reads the selected folder name (or "None") inline in the field area. When no folders exist the picker row SHALL NOT be displayed (unchanged from existing behaviour).

#### Scenario: Folder picker matches field row appearance
- **WHEN** the user opens the edit sheet for an item that has folders available
- **THEN** the "Folder" row SHALL visually match the other field rows in the sheet (label on top, value below, consistent padding)

#### Scenario: Picker shows selected folder name inline
- **GIVEN** an item is assigned to folder "Work"
- **WHEN** the edit sheet opens
- **THEN** the folder field SHALL display "Work" as the current value inline in the field row

#### Scenario: Picker shows "None" when no folder assigned
- **GIVEN** an item has no folder assigned
- **WHEN** the edit sheet opens
- **THEN** the folder field SHALL display "None" as the current value

---

### Requirement: Cmd+F search preserves active sidebar selection scope

When the user activates the search field (via Cmd+F or clicking the search bar) while a sidebar item is selected, the search SHALL be scoped to that selection — including folder selections. The sidebar selection SHALL NOT be reset to All Items on search activation. Search results SHALL reflect the active `SidebarSelection` (folder, type, all items, etc.) exactly as defined in the existing folder-scoped search requirement.

#### Scenario: Cmd+F preserves folder scope
- **GIVEN** the user has selected folder "Work" in the sidebar
- **WHEN** the user presses Cmd+F
- **THEN** the search field SHALL become focused
- **AND** search results SHALL be scoped to items in "Work"
- **AND** the sidebar selection SHALL remain on "Work"

#### Scenario: Search results update within folder scope
- **GIVEN** the user has selected folder "Work" and typed a query in the search field
- **WHEN** the query changes
- **THEN** results SHALL be filtered within "Work" only, not across the full vault

#### Scenario: Clearing search restores full folder item list
- **GIVEN** the user is searching within folder "Work"
- **WHEN** the user clears the search query
- **THEN** all items in "Work" SHALL be shown (scope remains "Work")

---

### Requirement: Item detail view shows folder assignment

The item detail pane SHALL display the assigned folder name in a read-only field row when the item has a `folderId`. The row SHALL appear after the last content section. The resolved folder name SHALL be looked up from the in-memory folder list by `folderId`. When `folderId` is nil the row SHALL be omitted entirely. The field row SHALL follow the same label-above-value visual style as other detail rows.

#### Scenario: Detail view shows folder name for assigned item
- **GIVEN** an item is assigned to folder "Work"
- **WHEN** the user views the item in the detail pane
- **THEN** a "Folder" row SHALL appear showing "Work"

#### Scenario: Detail view omits folder row for unfoldered item
- **GIVEN** an item has no folder assigned (`folderId` is nil)
- **WHEN** the user views the item in the detail pane
- **THEN** no "Folder" row SHALL appear

#### Scenario: Folder name resolves from in-memory list
- **GIVEN** an item has `folderId` matching folder "Finance"
- **WHEN** the detail pane renders
- **THEN** the folder row SHALL display "Finance" (resolved name, not the raw ID)
