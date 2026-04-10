## MODIFIED Requirements

### Requirement: User can lock the vault manually with ⌘L
The system SHALL provide a **Lock Vault** command in the application menu with the keyboard shortcut ⌘L. The command SHALL be enabled only when the vault is unlocked (vault browser visible or sync in progress). Activating the command SHALL immediately zero all in-memory key material, clear the vault item cache, and transition to the unlock screen. If biometric unlock is enabled, the system SHALL automatically trigger the biometric prompt as soon as the unlock screen appears. The user SHALL always be able to unlock by entering their master password.

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

#### Scenario: Biometric prompt fires automatically after manual lock
- **GIVEN** biometric unlock is enabled AND the vault browser is visible
- **WHEN** the user locks the vault via ⌘L or the menu
- **THEN** the unlock screen SHALL appear AND the biometric prompt SHALL fire automatically without requiring any additional user interaction

#### Scenario: Vault can be unlocked after manual lock
- **GIVEN** the vault has been manually locked
- **WHEN** the user enters the correct master password on the unlock screen
- **THEN** the vault SHALL unlock and the vault browser SHALL be shown
