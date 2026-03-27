## MODIFIED Requirements

### Requirement: ⌘N opens the new item picker (MODIFIED)
The system's default "New Window" command SHALL be remapped to ⌥⌘N. The ⌘N shortcut SHALL exclusively trigger the "New Item" type picker in the vault browser, regardless of keyboard focus.

#### Scenario: ⌘N opens the new item picker from anywhere in the vault
- **GIVEN** the vault browser is visible
- **WHEN** the user presses ⌘N
- **THEN** the new item type picker SHALL open

#### Scenario: ⌥⌘N opens a new window
- **WHEN** the user presses ⌥⌘N
- **THEN** a new application window SHALL open
