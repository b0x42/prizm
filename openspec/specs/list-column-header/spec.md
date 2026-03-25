## MODIFIED Requirements

### Requirement: Content pane provides new item creation via toolbar button
The content column SHALL display a `+` button in the toolbar via `ToolbarItem(placement: .primaryAction)`. The button SHALL open a `Menu` listing all `ItemType` cases. Selecting a type opens the create sheet for that type. The button SHALL carry `AccessibilityID.Create.newItemButton`.

The `+` button SHALL be conditionally rendered (not merely hidden) when `Trash` is selected — it must be absent from the view tree so that the ⌘N keyboard shortcut is also disabled in Trash.

#### Scenario: Plus button opens type menu
- **WHEN** the user clicks [+] in the content toolbar
- **THEN** a menu appears listing all item types (Login, Card, Identity, Secure Note, SSH Key)

#### Scenario: ⌘N creates Login outside Trash
- **WHEN** the user presses ⌘N while a non-Trash category is selected
- **THEN** the create sheet opens for a new Login item

#### Scenario: Plus button absent in Trash
- **WHEN** the user selects "Trash" in the sidebar
- **THEN** no [+] button is present and ⌘N has no effect
