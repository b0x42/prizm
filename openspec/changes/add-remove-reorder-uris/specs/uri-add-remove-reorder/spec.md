## ADDED Requirements

### Requirement: User can add a new website URI to a Login item
The edit form for Login items SHALL always display a "Websites" section, even when no URIs exist. The section SHALL contain an "Add Website" button that appends a new blank URI row with an empty URI string and no match type (default). The new row SHALL be immediately editable.

#### Scenario: Add Website button visible with no URIs
- **WHEN** the user opens the edit form for a Login item with zero URIs
- **THEN** the Websites section SHALL be visible with an "Add Website" button

#### Scenario: Add Website button visible with existing URIs
- **WHEN** the user opens the edit form for a Login item with one or more URIs
- **THEN** the "Add Website" button SHALL appear below the existing URI rows

#### Scenario: Adding a new URI
- **WHEN** the user clicks "Add Website"
- **THEN** a new URI row SHALL be appended with an empty URI field and match type set to Default

### Requirement: User can remove a website URI from a Login item
Each URI row in the Login edit form SHALL display an inline remove button. Clicking the remove button SHALL immediately remove that URI row from the list. Removal is not persisted until the user saves the edit form.

#### Scenario: Remove button shown on each URI row
- **WHEN** the edit form displays one or more URI rows
- **THEN** each row SHALL have a visible remove button

#### Scenario: Removing a URI
- **WHEN** the user clicks the remove button on a URI row
- **THEN** that URI row SHALL be removed from the list immediately

#### Scenario: Removing all URIs
- **WHEN** the user removes the last remaining URI
- **THEN** the Websites section SHALL remain visible with only the "Add Website" button

### Requirement: User can reorder website URIs on a Login item
Each URI row in the Login edit form SHALL display move-up (▲) and move-down (▼) buttons. The move-up button on the first row SHALL be disabled. The move-down button on the last row SHALL be disabled. When only one URI exists, both buttons SHALL be hidden. Clicking a move button SHALL swap the URI with its neighbor in the indicated direction.

#### Scenario: Reorder buttons shown when multiple URIs exist
- **GIVEN** a Login item with two or more URIs
- **WHEN** the edit form renders
- **THEN** each URI row SHALL display ▲ and ▼ buttons

#### Scenario: Reorder buttons hidden for single URI
- **GIVEN** a Login item with exactly one URI
- **WHEN** the edit form renders
- **THEN** the ▲ and ▼ buttons SHALL NOT be displayed

#### Scenario: First row move-up disabled
- **GIVEN** a Login item with multiple URIs
- **WHEN** the edit form renders
- **THEN** the ▲ button on the first URI row SHALL be disabled

#### Scenario: Last row move-down disabled
- **GIVEN** a Login item with multiple URIs
- **WHEN** the edit form renders
- **THEN** the ▼ button on the last URI row SHALL be disabled

#### Scenario: Moving a URI up
- **WHEN** the user clicks ▲ on a URI row that is not the first
- **THEN** that URI SHALL swap positions with the URI above it

#### Scenario: Moving a URI down
- **WHEN** the user clicks ▼ on a URI row that is not the last
- **THEN** that URI SHALL swap positions with the URI below it
