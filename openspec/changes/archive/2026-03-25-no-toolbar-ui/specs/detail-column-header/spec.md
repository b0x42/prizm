## MODIFIED Requirements

### Requirement: Detail pane toolbar shows contextual action buttons
The detail column SHALL display contextual action buttons in the toolbar. Button visibility depends on the current state:

**Active item selected (not trash):**
- `[Edit]` button via `ToolbarItem(placement: .primaryAction)` — opens the edit sheet for the selected item; disabled while the edit sheet is already open. SHALL carry `.keyboardShortcut("e", modifiers: .command)` and `AccessibilityID.Edit.editButton`.
- `[Delete]` button via `ToolbarItem(placement: .destructiveAction)` — triggers a confirmation alert before moving the item to Trash. The confirmation alert state SHALL live in `VaultBrowserView`.

**Trashed item selected:**
- `[Restore]` button via `ToolbarItem(placement: .primaryAction)` — restores the item to the active vault immediately, with no confirmation alert (non-destructive). SHALL carry `AccessibilityID.Trash.restoreButton`.
- `[Delete Permanently]` button via `ToolbarItem(placement: .destructiveAction)` — triggers a confirmation alert before permanent deletion. SHALL carry `AccessibilityID.Trash.permanentDeleteButton`.

**No item selected:**
- No action buttons shown.

#### Scenario: Active item — Edit and Delete visible
- **WHEN** an active (non-trashed) vault item is selected
- **THEN** both [Edit] and [Delete] buttons are visible in the toolbar

#### Scenario: Edit disabled while sheet is open
- **WHEN** the edit sheet is currently open
- **THEN** the [Edit] button is disabled

#### Scenario: Edit button carries ⌘E shortcut
- **WHEN** the user presses ⌘E with an active item selected and the edit sheet closed
- **THEN** the edit sheet opens for the selected item

#### Scenario: Delete triggers confirmation
- **WHEN** the user clicks [Delete]
- **THEN** a confirmation alert is shown before the item is moved to Trash

#### Scenario: Permanent delete triggers confirmation
- **WHEN** the user clicks [Delete Permanently]
- **THEN** a confirmation alert is shown before the item is permanently deleted

#### Scenario: Restore executes immediately
- **WHEN** the user clicks [Restore]
- **THEN** the item is restored to the active vault without a confirmation alert

#### Scenario: Trashed item — Restore and Delete Permanently visible
- **WHEN** a trashed vault item is selected
- **THEN** [Restore] and [Delete Permanently] buttons are visible
