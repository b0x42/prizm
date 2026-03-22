## ADDED Requirements

### Requirement: Edit button on item detail pane
The system SHALL display an "Edit" toolbar button in the detail pane whenever a vault item is selected.

#### Scenario: Edit button visible with item selected
- **WHEN** the user selects any vault item in the list pane
- **THEN** an "Edit" button SHALL appear in the detail pane toolbar

#### Scenario: Edit button not visible with no selection
- **WHEN** no vault item is selected
- **THEN** no "Edit" button SHALL be visible

### Requirement: Edit sheet presented for all item types
Clicking the Edit button SHALL open a modal edit sheet containing fields pre-populated with the selected item's current values, for all five item types (Login, Card, Identity, Secure Note, SSH Key).

#### Scenario: Login edit sheet pre-populated
- **WHEN** the user clicks Edit on a Login item
- **THEN** an edit sheet SHALL open with the item name, username, password, URIs, notes, and custom fields pre-populated with their current values

#### Scenario: Card edit sheet pre-populated
- **WHEN** the user clicks Edit on a Card item
- **THEN** an edit sheet SHALL open with the item name, cardholder name, brand, number, expiry month, expiry year, security code, notes, and custom fields pre-populated

#### Scenario: Identity edit sheet pre-populated
- **WHEN** the user clicks Edit on an Identity item
- **THEN** an edit sheet SHALL open with the item name, title, first name, middle name, last name, company, email, phone, SSN, username, passport number, license number, address line 1, address line 2, address line 3, city, state, postal code, country, notes, and custom fields pre-populated

#### Scenario: Secure Note edit sheet pre-populated
- **WHEN** the user clicks Edit on a Secure Note item
- **THEN** an edit sheet SHALL open with the item name, note text, and custom fields pre-populated

#### Scenario: SSH Key edit sheet pre-populated
- **WHEN** the user clicks Edit on an SSH Key item
- **THEN** an edit sheet SHALL open with the item name, private key, public key, and notes editable, and the key fingerprint displayed as a read-only field; custom fields SHALL be pre-populated

### Requirement: Item name is editable for all types
The system SHALL include an editable "Name" field at the top of the edit sheet regardless of item type.

#### Scenario: Name field present and pre-populated
- **WHEN** the edit sheet opens for any item type
- **THEN** the first field SHALL be an editable text field labelled "Name" containing the current item name

#### Scenario: Save blocked live when name is empty
- **WHEN** the Name field becomes empty while the edit sheet is open
- **THEN** the Save button, ⌘S, and the menu bar Save action SHALL all be disabled immediately and a validation error "Name is required" SHALL be shown inline

### Requirement: Login URIs editable in edit sheet
The system SHALL display all existing URI entries as editable rows within the Login edit sheet. Adding and removing URIs is out of scope for this change.

#### Scenario: Existing URIs listed and editable
- **WHEN** the Login edit sheet opens for an item with URIs
- **THEN** all existing URIs SHALL be listed as editable text fields

#### Scenario: URI match type selectable
- **WHEN** a URI row is displayed in the edit sheet
- **THEN** a picker SHALL allow the user to select from all six URI match type options (Domain, Host, Starts With, Exact, Regular Expression, Never) or a "Default" option representing nil

### Requirement: Existing custom field values editable in edit sheet
The system SHALL display all existing custom fields as editable rows showing the field name (read-only label) and an editable value. Adding, removing, and reordering custom fields is out of scope for this change. Custom field names are structural and SHALL NOT be editable.

#### Scenario: Existing custom fields listed with editable values
- **WHEN** the edit sheet opens for an item with custom fields
- **THEN** all custom fields SHALL be shown with their name as a read-only label and their value as an editable field

#### Scenario: Hidden custom field value masked by default
- **WHEN** a custom field of type Hidden is displayed in the edit sheet
- **THEN** its value SHALL be masked by default with a toggle to reveal it

### Requirement: Sensitive fields masked by default in edit sheet
The Login password field and the SSH Key private key field SHALL be masked by default in the edit sheet, consistent with the treatment of Hidden custom fields. Revealed values SHALL auto-mask after the app's configured sensitive-field timeout (Constitution §III).

#### Scenario: Password masked in Login edit sheet
- **WHEN** the Login edit sheet is open
- **THEN** the password field SHALL display its value masked by default

#### Scenario: Password revealed on toggle
- **WHEN** the user clicks the reveal toggle on the password field
- **THEN** the password value SHALL be shown in plain text

#### Scenario: Revealed password auto-masks after timeout
- **WHEN** the password field has been revealed and the sensitive-field timeout elapses
- **THEN** the password field SHALL revert to masked automatically

#### Scenario: Private key masked in SSH Key edit sheet
- **WHEN** the SSH Key edit sheet is open
- **THEN** the private key field SHALL display its value masked by default

#### Scenario: Private key revealed on toggle
- **WHEN** the user clicks the reveal toggle on the private key field
- **THEN** the private key value SHALL be shown in plain text

#### Scenario: Revealed private key auto-masks after timeout
- **WHEN** the private key field has been revealed and the sensitive-field timeout elapses
- **THEN** the private key field SHALL revert to masked automatically

### Requirement: Save action re-encrypts and persists the item
The Save action (button, ⌘S, or menu bar) SHALL re-encrypt the edited item, call `PUT /ciphers/{id}` on the Bitwarden API, and on success update the in-memory vault and dismiss the edit sheet.

#### Scenario: Successful save updates detail pane
- **WHEN** the user edits fields and triggers Save
- **AND** the API call succeeds
- **THEN** the edit sheet SHALL dismiss and the detail pane SHALL reflect the updated values

#### Scenario: Successful save updates list pane
- **WHEN** the user changes the item name and triggers Save
- **AND** the API call succeeds
- **THEN** the item row in the list pane SHALL show the updated name

#### Scenario: Save failure shows inline error
- **WHEN** the user triggers Save
- **AND** the API call fails (network error or server error)
- **THEN** the edit sheet SHALL remain open and display an inline error message describing the failure

#### Scenario: All save triggers disabled during in-flight request
- **WHEN** a save request is in progress
- **THEN** the Save button SHALL change its label to "Saving…" and be disabled, ⌘S and the menu bar Save action SHALL be disabled, the Discard button SHALL be disabled, and a progress indicator SHALL be shown

### Requirement: Discard unsaved edits
The edit sheet toolbar SHALL display a "Discard" button alongside the Save button. The button SHALL have a tooltip "Discard changes (Esc)". Clicking it or pressing Esc are equivalent and follow the same confirmation logic. The confirmation prompt SHALL offer two actions: "Discard Changes" (confirms discard) and "Keep Editing" (returns to the edit sheet).

#### Scenario: Discard button visible in edit sheet toolbar
- **WHEN** the edit sheet is open
- **THEN** a "Discard" button SHALL be visible in the toolbar alongside the Save button

#### Scenario: Discard button shows tooltip
- **WHEN** the user hovers over the Discard button
- **THEN** a tooltip reading "Discard changes (Esc)" SHALL appear

#### Scenario: Discard with no changes — immediate dismiss
- **WHEN** the edit sheet is open, the user has made no changes, and clicks Discard or presses Esc
- **THEN** the edit sheet SHALL dismiss immediately without a confirmation prompt

#### Scenario: Discard with unsaved changes — confirmation required
- **WHEN** the edit sheet is open, the user has made at least one change, and clicks Discard or presses Esc
- **THEN** a confirmation prompt SHALL appear with "Discard Changes" and "Keep Editing" buttons

#### Scenario: Confirming discard closes edit sheet
- **WHEN** the confirmation prompt is shown and the user clicks "Discard Changes"
- **THEN** the edit sheet SHALL dismiss and the item SHALL retain its original values

#### Scenario: Keep Editing dismisses prompt
- **WHEN** the confirmation prompt is shown and the user clicks "Keep Editing"
- **THEN** the prompt SHALL dismiss and the edit sheet SHALL remain open with all edits intact

#### Scenario: DraftVaultItem cleared from memory on dismiss
- **WHEN** the edit sheet is dismissed (whether by saving, discarding, or vault lock)
- **THEN** the `DraftVaultItem` holding plaintext field values SHALL be cleared from memory

#### Scenario: Edit sheet dismissed when vault locks
- **WHEN** the vault is locked while the edit sheet is open
- **THEN** the edit sheet SHALL be dismissed immediately without a confirmation prompt and all unsaved edits SHALL be discarded

### Requirement: Keyboard shortcut to open edit sheet
The system SHALL open the edit sheet for the currently selected item when the user presses `⌘E`. If the edit sheet is already open, `⌘E` SHALL have no effect.

#### Scenario: ⌘E opens edit sheet with item selected
- **WHEN** a vault item is selected, the edit sheet is not open, and the user presses `⌘E`
- **THEN** the edit sheet SHALL open pre-populated with that item's fields

#### Scenario: ⌘E does nothing with no selection
- **WHEN** no vault item is selected and the user presses `⌘E`
- **THEN** no edit sheet SHALL open

#### Scenario: ⌘E does nothing when edit sheet is already open
- **WHEN** the edit sheet is already open and the user presses `⌘E`
- **THEN** the edit sheet SHALL remain open unchanged

### Requirement: Keyboard shortcut to save changes
The system SHALL trigger the save action when the user presses `⌘S` while the edit sheet is open and the Name field is non-empty.

#### Scenario: ⌘S triggers save
- **WHEN** the edit sheet is open, the Name field is non-empty, and the user presses `⌘S`
- **THEN** the save action SHALL be triggered

#### Scenario: ⌘S ignored when name is empty or save in progress
- **WHEN** the Name field is empty or a save request is already in progress
- **THEN** pressing `⌘S` SHALL have no effect

### Requirement: "Item" menu bar extra with Edit and Save actions
The system SHALL display a `MenuBarExtra` labelled "Item" in the macOS system menu bar while the vault is unlocked. Its dropdown SHALL contain Edit (⌘E) and Save (⌘S) actions that operate on the currently selected vault item.

#### Scenario: Menu bar extra visible when vault is unlocked
- **WHEN** the vault is unlocked
- **THEN** an "Item" entry SHALL appear in the macOS menu bar

#### Scenario: Menu bar extra absent when vault is locked
- **WHEN** the vault is locked or no session is active
- **THEN** no "Item" entry SHALL appear in the macOS menu bar

#### Scenario: Edit and Save actions show keyboard shortcuts in dropdown
- **WHEN** the user opens the "Item" menu
- **THEN** the "Edit" menu item SHALL display `⌘E` and the "Save" menu item SHALL display `⌘S` as their keyboard shortcuts

#### Scenario: Edit action opens edit sheet
- **WHEN** the user clicks "Item" → "Edit" in the menu bar
- **THEN** the edit sheet SHALL open for the currently selected vault item

#### Scenario: Edit action disabled with no selection
- **WHEN** no vault item is selected
- **THEN** the "Edit" menu item SHALL be disabled

#### Scenario: Edit action does nothing when edit sheet is already open
- **WHEN** the edit sheet is already open and the user clicks "Item" → "Edit"
- **THEN** the edit sheet SHALL remain open unchanged

#### Scenario: Save action saves current edits
- **WHEN** the edit sheet is open, the Name field is non-empty, and the user clicks "Item" → "Save"
- **THEN** the save action SHALL be triggered

#### Scenario: Save action disabled when name is empty or no edit in progress
- **WHEN** the edit sheet is not open, the Name field is empty, or a save is already in progress
- **THEN** the "Save" menu item SHALL be disabled

### Requirement: DraftVaultItem mutable value type
The system SHALL provide a `DraftVaultItem` struct with `var` fields mirroring the `VaultItem` entity, used exclusively within the edit flow.

#### Scenario: DraftVaultItem initialised from VaultItem
- **WHEN** `DraftVaultItem.init(_ item: VaultItem)` is called
- **THEN** all fields in the draft SHALL match the corresponding fields of the source item

#### Scenario: VaultItem reconstructed from DraftVaultItem
- **WHEN** `VaultItem.init(_ draft: DraftVaultItem)` is called after a successful save
- **THEN** the resulting VaultItem SHALL reflect all edits made in the draft

### Requirement: Reverse cipher mapper (domain → wire)
`CipherMapper` SHALL provide a method to convert a `DraftVaultItem` into an encrypted `RawCipher` suitable for the PUT /ciphers/{id} API request body.

#### Scenario: Reverse mapping round-trip
- **WHEN** a `VaultItem` is converted to `DraftVaultItem`, then to `RawCipher` (re-encrypted), then decrypted and mapped back to `VaultItem`
- **THEN** the resulting `VaultItem` SHALL equal the original

#### Scenario: All five item types are supported
- **WHEN** the reverse mapper is called with a draft of any of the five item types
- **THEN** it SHALL produce a correctly structured `RawCipher` without throwing

### Requirement: VaultRepository update operation
`VaultRepository` SHALL expose an `update(_ draft: DraftVaultItem) async throws -> VaultItem` method that persists the change via the API and returns the server-confirmed `VaultItem`.

#### Scenario: Successful update returns server item
- **WHEN** `update` is called with a valid draft
- **AND** the API returns a 200 response with the updated cipher body
- **THEN** the method SHALL return a `VaultItem` decoded from the server response

#### Scenario: API error is thrown
- **WHEN** `update` is called and the API returns a non-2xx response
- **THEN** the method SHALL throw a typed error that the Presentation layer can display
