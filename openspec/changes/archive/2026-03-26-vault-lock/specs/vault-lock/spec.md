## ADDED Requirements

### Requirement: User can lock the vault manually with ⌘L
The system SHALL provide a **Lock Vault** command in the application menu with the keyboard shortcut ⌘L. The command SHALL be enabled only when the vault is unlocked (vault browser visible or sync in progress). Activating the command SHALL immediately zero all in-memory key material, clear the vault item cache, and transition to the unlock screen. The user SHALL be able to unlock again by entering their master password.

#### Scenario: Lock Vault command is available in the vault browser
- **WHEN** the vault browser is visible or a vault sync is in progress
- **THEN** the Lock Vault command in the application menu SHALL be enabled and show the ⌘L shortcut

#### Scenario: Lock Vault command is disabled outside the vault browser
- **WHEN** the login screen, unlock screen, or loading screen is visible
- **THEN** the Lock Vault command SHALL be disabled

#### Scenario: Manual lock transitions to the unlock screen
- **GIVEN** the vault browser is visible
- **WHEN** the user presses ⌘L or selects Lock Vault from the menu
- **THEN** the vault SHALL be locked immediately, all in-memory key material SHALL be zeroed, the vault item cache SHALL be cleared, and the unlock screen SHALL be shown

#### Scenario: Vault can be unlocked after manual lock
- **GIVEN** the vault has been manually locked
- **WHEN** the user enters the correct master password on the unlock screen
- **THEN** the vault SHALL unlock and the vault browser SHALL be shown

---

### Requirement: Vault locks automatically when the Mac goes to sleep
The system SHALL observe the Mac sleep event and lock the vault automatically before the system sleeps. No user interaction is required. The lock SHALL fire whenever the vault is unlocked — including during an active vault sync — not only when the vault browser is fully loaded.

#### Scenario: Vault locks on Mac sleep
- **GIVEN** the vault browser is visible
- **WHEN** the Mac goes to sleep (lid close, sleep menu item, or inactivity sleep)
- **THEN** the vault SHALL be locked immediately, all in-memory key material SHALL be zeroed, the vault item cache SHALL be cleared, and the unlock screen SHALL be visible when the Mac wakes

#### Scenario: Sleep while vault is already locked is a no-op
- **GIVEN** the vault is not currently unlocked (unlock screen or login screen is shown)
- **WHEN** the Mac goes to sleep
- **THEN** no state change SHALL occur

---

### Requirement: Vault locks automatically when the screensaver starts
The system SHALL observe the screensaver start event and lock the vault automatically. The lock SHALL fire whenever the vault is unlocked — including during an active vault sync — not only when the vault browser is fully loaded.

#### Scenario: Vault locks when screensaver starts
- **GIVEN** the vault browser is visible
- **WHEN** the macOS screensaver activates
- **THEN** the vault SHALL be locked immediately, all in-memory key material SHALL be zeroed, the vault item cache SHALL be cleared, and the unlock screen SHALL be visible when the screensaver is dismissed

#### Scenario: Screensaver start while vault is already locked is a no-op
- **GIVEN** the vault is not currently unlocked (unlock screen or login screen is shown)
- **WHEN** the screensaver activates
- **THEN** no state change SHALL occur
