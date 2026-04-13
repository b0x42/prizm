## ADDED Requirements

### Requirement: Focus SHALL return to a logical element after dismissals
When a sheet, alert, or destructive action completes, keyboard and VoiceOver focus SHALL return to a logical element rather than being lost.

#### Scenario: Focus returns after edit sheet dismiss
- **WHEN** the user dismisses the edit sheet (save or discard)
- **THEN** focus SHALL return to the detail pane or the previously selected item

#### Scenario: Focus returns after delete confirmation
- **WHEN** the user confirms a soft delete and the item is removed from the list
- **THEN** focus SHALL move to the next item in the list, or the empty state if no items remain

#### Scenario: Focus returns after alert dismiss
- **WHEN** the user dismisses an error alert via the OK button
- **THEN** focus SHALL return to the element that was focused before the alert appeared
