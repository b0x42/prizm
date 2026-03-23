## MODIFIED Requirements

### Requirement: Edit button on item detail pane
The system SHALL display an "Edit" toolbar button in the detail pane whenever a vault item is selected. Tapping it SHALL open the edit sheet described in the `vault-item-edit` capability.

#### Scenario: Edit button visible with item selected
- **WHEN** the user selects any vault item in the list pane
- **THEN** an "Edit" toolbar button SHALL appear in the detail pane

#### Scenario: Edit button absent with no selection
- **WHEN** no vault item is selected (empty detail pane)
- **THEN** no "Edit" button SHALL be visible
