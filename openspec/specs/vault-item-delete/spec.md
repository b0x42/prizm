## ADDED Requirements

### Requirement: User can soft-delete an active vault item
The system SHALL allow the user to move an active vault item to trash via a Delete action available in the vault list context menu and in the item detail view toolbar. Soft-delete SHALL call `DELETE /ciphers/{id}` and set `deletedDate` on the item without permanently removing it from the server.

#### Scenario: Soft-delete from list context menu
- **WHEN** the user right-clicks an active item in the vault list and selects "Delete"
- **THEN** a confirmation alert appears asking the user to confirm moving the item to trash

#### Scenario: Soft-delete from detail view
- **WHEN** the user clicks the "Delete" toolbar button in the item detail view
- **THEN** a confirmation alert appears warning the item will be moved to trash

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
The system SHALL allow the user to permanently delete a single item that is already in trash. Permanent delete SHALL call `DELETE /ciphers/{id}` on a trashed item and remove it from the server entirely. A second confirmation alert with destructive styling SHALL be required.

#### Scenario: Permanent delete action available only on trashed items
- **WHEN** the user views the Trash list
- **THEN** each item shows a "Delete Permanently" action in its context menu

#### Scenario: Permanent delete confirmation required
- **WHEN** the user selects "Delete Permanently" for a trashed item
- **THEN** a confirmation alert with destructive button wording ("Delete Permanently") is shown before proceeding

#### Scenario: Permanent delete confirmed
- **WHEN** the user confirms the permanent delete alert
- **THEN** the system removes the item from the server and the item disappears from the Trash list

#### Scenario: Permanent delete network failure
- **WHEN** the API call fails
- **THEN** an error alert is shown and the item remains in the Trash list

### Requirement: User can empty trash
The system SHALL provide an "Empty Trash" action that permanently deletes all items in the trash via `DELETE /ciphers/purge`. A confirmation alert displaying the number of items to be deleted SHALL be required before proceeding.

#### Scenario: Empty trash action is available when trash contains items
- **WHEN** the Trash view is selected and there is at least one trashed item
- **THEN** an "Empty Trash" button is visible in the toolbar

#### Scenario: Empty trash action is disabled when trash is empty
- **WHEN** the Trash view contains no items
- **THEN** the "Empty Trash" button is absent or disabled

#### Scenario: Empty trash confirmation required
- **WHEN** the user clicks "Empty Trash"
- **THEN** a confirmation alert states the number of items that will be permanently deleted

#### Scenario: Empty trash confirmed
- **WHEN** the user confirms empty-trash
- **THEN** the system calls `DELETE /ciphers/purge`, all trashed items are removed, and the Trash list becomes empty

#### Scenario: Empty trash network failure
- **WHEN** the API call fails
- **THEN** an error alert is shown and the Trash list is unchanged

### Requirement: Trash sidebar section displays soft-deleted items
The system SHALL display a "Trash" entry in the sidebar that, when selected, shows all vault items whose `deletedDate` is non-nil. Trashed items SHALL NOT appear in the main active vault list.

#### Scenario: Trash entry in sidebar
- **WHEN** the vault is unlocked
- **THEN** a "Trash" entry appears in the sidebar below the main item categories

#### Scenario: Active items exclude trashed items
- **WHEN** the main vault list is displayed
- **THEN** items with a non-nil `deletedDate` are NOT shown

#### Scenario: Trash list shows only trashed items
- **WHEN** the user selects the Trash sidebar entry
- **THEN** only items with a non-nil `deletedDate` are shown

#### Scenario: Empty trash view shows empty state
- **WHEN** the user selects the Trash sidebar entry and no items are in trash
- **THEN** the Trash view displays the message "No items in trash" as a heading and "Items you delete will appear here" as supporting text, with no list content

> **Note on auto-purge copy**: Bitwarden (official cloud) permanently deletes trashed items after 30 days server-side. Vaultwarden (self-hosted) does **not** auto-purge by default — it requires the admin to set `TRASH_AUTO_DELETE_DAYS`, and the period is configurable. Because Macwarden targets both servers, the supporting text intentionally omits the "30 days" timeframe to avoid a misleading promise on self-hosted instances.
