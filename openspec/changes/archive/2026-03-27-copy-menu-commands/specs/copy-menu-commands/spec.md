## ADDED Requirements

### Requirement: Copy field commands in Item menu
The Item menu SHALL provide Copy Username (⇧⌘C), Copy Password (⌥⌘C), Copy Code (⌃⌘C), and Copy Website (⌥⇧⌘C) commands. Each command SHALL copy the corresponding field from the selected Login item to the clipboard with 30-second auto-clear. Commands SHALL be disabled when the selected item does not have the corresponding field or is not a Login item.

#### Scenario: Copy Username copies username to clipboard
- **GIVEN** a Login item with a username is selected
- **WHEN** the user presses ⇧⌘C or selects Copy Username from the Item menu
- **THEN** the username SHALL be copied to the clipboard with 30s auto-clear

#### Scenario: Copy Password copies password to clipboard
- **GIVEN** a Login item with a password is selected
- **WHEN** the user presses ⌥⌘C
- **THEN** the password SHALL be copied to the clipboard with 30s auto-clear

#### Scenario: Copy Code copies TOTP seed to clipboard
- **GIVEN** a Login item with a TOTP seed is selected
- **WHEN** the user presses ⌃⌘C
- **THEN** the TOTP seed SHALL be copied to the clipboard with 30s auto-clear

#### Scenario: Copy Website copies first URI to clipboard
- **GIVEN** a Login item with at least one URI is selected
- **WHEN** the user presses ⌥⇧⌘C
- **THEN** the first URI SHALL be copied to the clipboard with 30s auto-clear

#### Scenario: Commands disabled when field unavailable
- **GIVEN** the selected item is not a Login or the Login item lacks the field
- **THEN** the corresponding copy command SHALL be disabled (grayed out)

#### Scenario: Commands disabled when no item selected
- **GIVEN** no item is selected in the item list
- **THEN** all four copy commands SHALL be disabled
