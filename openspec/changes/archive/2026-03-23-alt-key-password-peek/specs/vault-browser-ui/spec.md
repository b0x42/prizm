## MODIFIED Requirements

### Requirement: Secret fields are masked with a reveal toggle
The system SHALL mask password, card number, security code, and SSH private key fields by default showing exactly 8 bullet dots (••••••••) regardless of actual value length. A reveal toggle SHALL show the plaintext value. All fields SHALL reset to masked state when the user navigates to a different item. Additionally, holding the Option (⌥) key SHALL temporarily reveal all masked fields; releasing the key SHALL immediately re-mask them without changing the toggle state.

#### Scenario: Masked field shows exactly 8 dots
- **WHEN** a secret field renders in its masked state
- **THEN** exactly 8 bullet dots are shown regardless of the actual value length

#### Scenario: Reveal toggle shows plaintext
- **WHEN** the user clicks the reveal button
- **THEN** the actual plaintext value is shown; clicking again returns to the masked state

#### Scenario: Navigation resets all reveals
- **WHEN** the user selects a different item
- **THEN** all previously revealed fields on the previous item return to their masked state

#### Scenario: Option key peek reveals masked fields
- **WHEN** the user holds the Option (⌥) key while a masked field is visible
- **THEN** the field SHALL display its plaintext value without changing the toggle state

#### Scenario: Releasing Option key re-masks fields
- **GIVEN** the Option key is held and masked fields are showing plaintext via peek
- **WHEN** the user releases the Option key
- **THEN** all fields SHALL return to their prior state (masked if toggle was hidden, revealed if toggle was revealed)
