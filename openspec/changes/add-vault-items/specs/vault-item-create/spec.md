## ADDED Requirements

### Requirement: User can create a new vault item from the vault browser
The system SHALL provide a "+" button permanently anchored at the top of the content column, immediately above the item list rows, in `VaultBrowserView`. The button SHALL be embedded in the content column's view body — not in the window toolbar — so its position is completely fixed regardless of which sidebar category is selected, whether an item is selected in the item list, or which column holds keyboard focus. It SHALL not be rendered at all when the Trash category is active, and SHALL reappear in the same fixed position when the user leaves Trash. Clicking the button OR pressing ⌘N SHALL present a menu listing all five item types: Login, Card, Identity, Secure Note, and SSH Key. Selecting a type SHALL open the edit sheet pre-populated with a blank draft of that type. The edit sheet SHALL reuse the same form fields, validation, and save flow as the existing item edit feature. Once the type picker is open, the user SHALL be able to navigate types with ↑/↓ arrow keys and confirm with Enter, without touching the mouse.

#### Scenario: New Item button is always above the item list regardless of selection or focus state
- **WHEN** the vault browser is displayed with any category selected except Trash
- **THEN** a "+" button (SF Symbol `plus`) SHALL be visible immediately above the item list rows
- **AND** the button SHALL be in the same position whether or not an item is selected in the item list
- **AND** the button SHALL be in the same position whether a sidebar category (All Items, Favorites, Login, etc.) or an item list row was last clicked

#### Scenario: New Item button is not rendered when Trash is selected
- **WHEN** the user selects the Trash category
- **THEN** the "+" button SHALL NOT be rendered at all — no button frame, no icon, no chrome of any kind

#### Scenario: New Item button reappears after leaving Trash
- **GIVEN** the user has the Trash category selected
- **WHEN** the user navigates to any non-Trash category
- **THEN** the "+" button SHALL be visible in the content column toolbar above the item list

#### Scenario: ⌘N opens the type picker in a non-Trash category
- **WHEN** the user presses ⌘N with any non-Trash category selected
- **THEN** the New Item type picker menu SHALL open, listing Login, Card, Identity, Secure Note, and SSH Key

#### Scenario: ⌘N is a no-op in Trash
- **WHEN** the user presses ⌘N with the Trash category selected
- **THEN** nothing SHALL happen — the type picker SHALL NOT open

#### Scenario: Arrow keys navigate the type picker, Enter confirms
- **GIVEN** the type picker menu is open
- **WHEN** the user presses ↓ to move the highlight then presses Enter
- **THEN** the edit sheet for the highlighted item type SHALL open

#### Scenario: ⌘N then immediate Enter opens the Login edit sheet
- **WHEN** the user presses ⌘N and then immediately presses Enter without pressing any arrow key
- **THEN** the Login edit sheet SHALL open (Login is the first type in the list)

#### Scenario: Escape dismisses the type picker without creating an item
- **GIVEN** the type picker menu is open
- **WHEN** the user presses Escape
- **THEN** the menu SHALL close and no edit sheet SHALL open

#### Scenario: Type picker shows all five item types
- **WHEN** the user clicks the New Item button
- **THEN** a menu SHALL appear listing Login, Card, Identity, Secure Note, and SSH Key

#### Scenario: Selecting a type opens a blank edit sheet
- **WHEN** the user selects "Login" from the type picker
- **THEN** the edit sheet SHALL open with an empty Login draft (blank name, blank username, blank password, one empty URI row with match type hidden, no notes, no custom fields)

#### Scenario: Selecting Card opens a blank Card edit sheet
- **WHEN** the user selects "Card" from the type picker
- **THEN** the edit sheet SHALL open with an empty Card draft (blank cardholder name, blank number, no expiry, no CVV, no notes, no custom fields)

#### Scenario: Selecting Identity opens a blank Identity edit sheet
- **WHEN** the user selects "Identity" from the type picker
- **THEN** the edit sheet SHALL open with an empty Identity draft (all identity fields blank, no notes, no custom fields)

#### Scenario: Selecting Secure Note opens a blank Secure Note edit sheet
- **WHEN** the user selects "Secure Note" from the type picker
- **THEN** the edit sheet SHALL open with an empty Secure Note draft (blank notes, no custom fields)

#### Scenario: Selecting SSH Key opens a blank SSH Key edit sheet
- **WHEN** the user selects "SSH Key" from the type picker
- **THEN** the edit sheet SHALL open with an empty SSH Key draft (blank private key, blank public key, no notes, no custom fields)

---

### Requirement: Saving a new item creates it on the server and adds it to the local vault
The system SHALL encrypt all sensitive fields of the new item using the vault's symmetric keys and send a `POST /api/ciphers` request to the server. On success, the server-returned item (with server-assigned ID and timestamps) SHALL be inserted into the in-memory vault cache. The item list SHALL update immediately without requiring a full re-sync. The edit sheet SHALL dismiss on successful save.

#### Scenario: Successful creation persists to server
- **WHEN** the user fills in the Name field and clicks Save
- **THEN** the system SHALL encrypt the draft, POST it to the server, insert the server-confirmed item into the cache, and dismiss the sheet

#### Scenario: Created item appears in the item list immediately
- **WHEN** a new item is successfully created
- **THEN** the item SHALL appear in the vault item list sorted alphabetically without a manual refresh or re-sync

#### Scenario: Name is required for creation
- **WHEN** the user attempts to save a new item with a blank Name field
- **THEN** the Save button SHALL be disabled and an inline validation message ("Name is required") SHALL be shown

#### Scenario: Save failure shows inline error
- **WHEN** the server returns an error during creation
- **THEN** the edit sheet SHALL remain open with an inline error banner displaying the error message

#### Scenario: Vault lock during creation dismisses the sheet
- **WHEN** the vault locks while the create edit sheet is open
- **THEN** the sheet SHALL dismiss immediately without a discard confirmation prompt and the draft SHALL be cleared from memory

---

### Requirement: Discarding an unsaved new item prompts for confirmation if changes were made
The system SHALL track whether the user has modified any field from the blank default state. If changes exist and the user attempts to dismiss the sheet (Escape key, Discard button, or clicking outside), a confirmation alert SHALL be shown. If no changes were made, the sheet SHALL dismiss without confirmation.

#### Scenario: Discard with changes shows confirmation
- **WHEN** the user has typed into any field of a new item and presses Escape
- **THEN** a confirmation alert SHALL ask whether to discard changes

#### Scenario: Discard without changes dismisses silently
- **WHEN** the user opens a new item sheet and immediately presses Escape without editing
- **THEN** the sheet SHALL dismiss without a confirmation prompt

#### Scenario: Confirming discard clears the draft from memory
- **WHEN** the user confirms the discard prompt
- **THEN** the draft's plaintext field values SHALL be cleared from memory and the sheet SHALL dismiss
