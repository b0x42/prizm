## MODIFIED Requirements

### Requirement: User can soft-delete an active vault item
The system SHALL allow the user to move an active vault item to trash via a Delete action available in the vault list context menu and in the item detail view toolbar. Soft-delete SHALL call `DELETE /ciphers/{id}` and set `deletedDate` on the item without permanently removing it from the server. The Delete button text in the detail toolbar SHALL render in red.

#### Scenario: Soft-delete from list context menu
- **WHEN** the user right-clicks an active item in the vault list and selects "Delete"
- **THEN** a confirmation alert appears asking the user to confirm moving the item to trash

#### Scenario: Soft-delete from detail view
- **WHEN** the user clicks the "Delete" toolbar button in the item detail view
- **THEN** a confirmation alert appears warning the item will be moved to trash

#### Scenario: Soft-delete toolbar button text is red
- **WHEN** the detail toolbar displays the "Delete" button for an active item
- **THEN** the button text SHALL be red

#### Scenario: Soft-delete confirmed
- **WHEN** the user confirms the delete alert
- **THEN** the system calls `DELETE /ciphers/{id}`, the item is removed from the active list, and the detail pane returns to the empty state

#### Scenario: Soft-delete cancelled
- **WHEN** the user dismisses the delete confirmation alert
- **THEN** no change is made and the item remains in the active vault

#### Scenario: Soft-delete network failure
- **WHEN** the API call fails (network error or non-2xx response)
- **THEN** an error alert is shown and the item remains in the active vault list

### Requirement: User can permanently delete a trashed vault item
The system SHALL allow the user to permanently delete a single item that is already in trash. Permanent delete SHALL call `DELETE /ciphers/{id}` on a trashed item and remove it from the server entirely. A second confirmation alert with destructive styling SHALL be required. The "Delete Permanently" button text in the detail toolbar SHALL render in red.

#### Scenario: Permanent delete action available only on trashed items
- **WHEN** the user views the Trash list
- **THEN** each item shows a "Delete Permanently" action in its context menu

#### Scenario: Permanent delete confirmation required
- **WHEN** the user selects "Delete Permanently" for a trashed item
- **THEN** a confirmation alert with destructive button wording ("Delete Permanently") is shown before proceeding

#### Scenario: Permanent delete toolbar button text is red
- **WHEN** the detail toolbar displays the "Delete Permanently" button for a trashed item
- **THEN** the button text SHALL be red

#### Scenario: Permanent delete confirmed
- **WHEN** the user confirms the permanent delete alert
- **THEN** the system removes the item from the server and the item disappears from the Trash list

#### Scenario: Permanent delete network failure
- **WHEN** the API call fails
- **THEN** an error alert is shown and the item remains in the Trash list
