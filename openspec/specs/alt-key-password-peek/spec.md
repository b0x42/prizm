## ADDED Requirements

### Requirement: Option-key peek temporarily reveals masked fields
The system SHALL temporarily reveal all masked field values while the user holds the Option (⌥) key. Releasing the key SHALL immediately return all fields to their masked state. The peek SHALL NOT alter the persisted reveal/hide toggle state of any field.

#### Scenario: Holding Option reveals masked password
- **WHEN** a Login item is selected and the password field is masked
- **AND** the user presses and holds the Option key
- **THEN** the password field SHALL display its plaintext value

#### Scenario: Releasing Option re-masks the field
- **GIVEN** the Option key is held and a masked field is showing plaintext via peek
- **WHEN** the user releases the Option key
- **THEN** the field SHALL immediately return to its masked state (8 bullet dots)

#### Scenario: Peek does not affect click-toggle state
- **GIVEN** a masked field whose reveal toggle is in the hidden state
- **WHEN** the user holds and then releases the Option key
- **THEN** the field's reveal toggle state SHALL remain hidden (unchanged)

#### Scenario: Peek combined with already-revealed field
- **GIVEN** a masked field that the user has already revealed via the eye toggle
- **WHEN** the user holds and then releases the Option key
- **THEN** the field SHALL remain revealed (the toggle state is still "revealed")

#### Scenario: Peek applies to all masked field types
- **WHEN** the user holds the Option key while viewing a Card item with a masked security code
- **THEN** the security code field SHALL display its plaintext value

#### Scenario: Peek only active while app is focused
- **WHEN** the app is not the frontmost application
- **THEN** holding the Option key SHALL NOT reveal any masked fields
