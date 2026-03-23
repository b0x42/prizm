## ADDED Requirements

### Requirement: User can restore a trashed vault item
The system SHALL allow the user to restore a trashed vault item back to the active vault via `PUT /ciphers/{id}/restore`. The Restore action SHALL be available in the Trash list context menu and in the detail view of a trashed item.

#### Scenario: Restore action available on trashed items
- **WHEN** the user views the Trash list
- **THEN** each item shows a "Restore" action in its context menu

#### Scenario: Restore from trash list
- **WHEN** the user selects "Restore" from a trashed item's context menu
- **THEN** the system calls `PUT /ciphers/{id}/restore`, the item's `deletedDate` is cleared, and the item disappears from the Trash list

#### Scenario: Restored item reappears in active vault
- **WHEN** an item is successfully restored
- **THEN** it reappears in the main active vault list under its original category

#### Scenario: Restore from detail view of trashed item
- **WHEN** the user opens the detail view of a trashed item
- **THEN** a "Restore" toolbar button is visible alongside "Delete Permanently"

#### Scenario: Restore confirmed from detail view
- **WHEN** the user clicks "Restore" in the detail view of a trashed item
- **THEN** the system calls `PUT /ciphers/{id}/restore` and navigates back to the Trash list (now without that item)

#### Scenario: Restore network failure
- **WHEN** the API call fails (network error or non-2xx response)
- **THEN** an error alert is shown and the item remains in the Trash list with its `deletedDate` intact

### Requirement: Trashed item detail view indicates trash status
The system SHALL visually indicate when a vault item is in trash so users understand its state before choosing to restore or permanently delete it.

#### Scenario: Trash status banner in detail view
- **WHEN** the user opens the detail view of a trashed item
- **THEN** a banner or label is shown stating that the item is in trash and can be restored or permanently deleted

#### Scenario: Edit is disabled for trashed items
- **WHEN** the user views a trashed item's detail pane
- **THEN** the Edit button is absent or disabled, since editing a trashed item is not permitted by the Bitwarden API
