## MODIFIED Requirements

### Requirement: User can soft-delete an active vault item
The system SHALL allow the user to move an active vault item to trash via a Delete action available in the vault list context menu and in the item edit sheet. Soft-delete SHALL call `DELETE /ciphers/{id}` and set `deletedDate` on the item without permanently removing it from the server. The Delete button in the edit sheet SHALL render in red.

#### Scenario: Soft-delete from list context menu
- **WHEN** the user right-clicks an active item in the vault list and selects "Delete"
- **THEN** a confirmation alert appears asking the user to confirm moving the item to trash

#### Scenario: Soft-delete from edit sheet
- **WHEN** the user opens the edit sheet for an active item
- **THEN** a "Delete Item" button with red text SHALL appear at the bottom of the form

#### Scenario: Soft-delete edit sheet button triggers confirmation
- **WHEN** the user clicks the "Delete Item" button in the edit sheet
- **THEN** a confirmation alert appears warning the item will be moved to trash

#### Scenario: Soft-delete edit sheet button hidden during item creation
- **WHEN** the user opens the edit sheet to create a new item
- **THEN** no "Delete Item" button SHALL appear

#### Scenario: Soft-delete button text is red
- **WHEN** the edit sheet displays the "Delete Item" button for an active item
- **THEN** the button text SHALL be red

#### Scenario: Soft-delete confirmed from edit sheet
- **WHEN** the user confirms the delete alert from the edit sheet
- **THEN** the edit sheet SHALL dismiss, the system calls `DELETE /ciphers/{id}`, the item is removed from the active list, and the detail pane returns to the empty state

#### Scenario: Soft-delete cancelled
- **WHEN** the user dismisses the delete confirmation alert
- **THEN** no change is made and the item remains in the active vault

#### Scenario: Soft-delete network failure
- **WHEN** the API call fails (network error or non-2xx response)
- **THEN** an error alert is shown and the item remains in the active vault list

#### Scenario: Soft-delete not available from detail toolbar
- **WHEN** the user views an active item in the detail pane
- **THEN** no Delete button SHALL appear in the detail toolbar

#### Scenario: Delete Item button has accessibility identifier
- **WHEN** the edit sheet renders the "Delete Item" button
- **THEN** the button SHALL have an `accessibilityIdentifier` for UI test targeting

#### Scenario: Focus after delete from edit sheet
- **WHEN** the user confirms soft-delete from the edit sheet
- **THEN** the edit sheet SHALL dismiss, the item SHALL be removed, and focus SHALL move to the next item in the list or the empty state if no items remain
