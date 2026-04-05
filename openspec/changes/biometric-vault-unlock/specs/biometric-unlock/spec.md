## ADDED Requirements

### Requirement: User can unlock the vault with biometrics
The system SHALL provide a biometric unlock path that re-opens the vault without requiring the master password, using the platform biometric authenticator (Touch ID on macOS, Face ID on iOS). The system SHALL store the derived vault symmetric key (`CryptoKeys`) in a Keychain item protected by `kSecAccessControl` with `.biometryCurrentSet`. The master password path SHALL always remain available as a fallback.

#### Scenario: Successful Touch ID unlock
- **GIVEN** biometric unlock is enabled and the vault is locked
- **WHEN** the lock screen appears
- **THEN** the system SHALL automatically trigger the biometric prompt
- **AND** on successful biometric evaluation the vault SHALL unlock and the vault browser SHALL be shown without the user entering a password

#### Scenario: Touch ID button is present when biometric unlock is enabled
- **GIVEN** biometric unlock is enabled and the vault is locked
- **WHEN** the lock screen is shown
- **THEN** a button labelled with the current biometric type ("Unlock with Touch ID" / "Unlock with Face ID") SHALL be visible

#### Scenario: Touch ID button is absent when biometric unlock is disabled
- **GIVEN** biometric unlock is not enabled
- **WHEN** the lock screen is shown
- **THEN** no biometric unlock button SHALL appear and only the master password path SHALL be available

#### Scenario: Biometric unlock falls back to password on cancellation
- **GIVEN** biometric unlock is enabled and the auto-prompt fires
- **WHEN** the user cancels or dismisses the biometric prompt
- **THEN** the lock screen SHALL remain visible with the password field focused and no error message shown

#### Scenario: Biometric lockout shows an error message
- **GIVEN** biometric unlock is enabled
- **WHEN** the biometric prompt fails with a lockout error (too many failed attempts)
- **THEN** the system SHALL display the message "Too many failed Touch ID attempts — enter your master password" and fall back to the password path

---

### Requirement: User can enroll in biometric unlock after a successful password unlock
After a successful password unlock, the system SHALL check whether biometric unlock is available on the device and has not yet been enabled. If both conditions are met, the system SHALL present a one-time enrollment prompt offering to enable biometric unlock. The user SHALL be able to accept or dismiss the prompt. Dismissal SHALL be remembered so the prompt does not appear again in the same session.

#### Scenario: Enrollment prompt appears after first successful password unlock
- **GIVEN** biometrics are available on the device AND biometric unlock is not currently enabled AND the prompt has not been shown this session
- **WHEN** the user successfully unlocks the vault with their master password
- **THEN** the system SHALL present an enrollment prompt: "Enable Touch ID to unlock faster"

#### Scenario: User accepts enrollment prompt
- **WHEN** the user taps "Enable Touch ID" on the enrollment prompt
- **THEN** the system SHALL store the vault key in a biometric-protected Keychain item AND set `biometricUnlockEnabled = true` AND the prompt SHALL be dismissed

#### Scenario: User dismisses enrollment prompt
- **WHEN** the user taps "Not now" on the enrollment prompt
- **THEN** the prompt SHALL be dismissed and SHALL NOT appear again this session
- **AND** biometric unlock SHALL remain disabled

---

### Requirement: User can enable and disable biometric unlock from Settings
The system SHALL provide a toggle in Settings to enable or disable biometric unlock at any time. Enabling SHALL store the vault key in a biometric-protected Keychain item; disabling SHALL delete that item.

#### Scenario: Enable biometric unlock from Settings
- **GIVEN** the vault is unlocked and biometric unlock is currently disabled
- **WHEN** the user enables the biometric toggle in Settings
- **THEN** the system SHALL store the vault key in the biometric Keychain item and set `biometricUnlockEnabled = true`

#### Scenario: Disable biometric unlock from Settings
- **GIVEN** biometric unlock is currently enabled
- **WHEN** the user disables the toggle in Settings
- **THEN** the system SHALL delete the biometric Keychain item and set `biometricUnlockEnabled = false`

#### Scenario: Biometric toggle is hidden when device has no biometrics
- **GIVEN** the current device has no enrolled biometrics or does not support biometric authentication
- **WHEN** the user opens Settings
- **THEN** the biometric unlock toggle SHALL NOT be visible

---

### Requirement: Biometric unlock is invalidated gracefully when fingerprint enrollment changes
When the system reports that the biometric Keychain item is no longer accessible (`.biometryCurrentSet` invalidated due to enrollment change), the system SHALL inform the user, clear the biometric preference, and re-offer enrollment after the next successful password unlock.

#### Scenario: Biometric unlock fails due to enrollment change
- **GIVEN** biometric unlock was previously enabled AND the user has since added or removed a fingerprint
- **WHEN** the vault locks and the biometric prompt fires
- **THEN** the biometric unlock SHALL fail and the system SHALL display: "Your Touch ID settings have changed. Please enter your master password to continue."
- **AND** `biometricUnlockEnabled` SHALL be set to `false` and the biometric Keychain item SHALL be deleted

#### Scenario: Re-enrollment is offered after invalidation
- **GIVEN** biometric unlock was invalidated on the previous lock/unlock cycle
- **WHEN** the user successfully unlocks the vault with their master password
- **THEN** the enrollment prompt SHALL be shown again (same as first-time enrollment)

---

### Requirement: Biometric Keychain item is cleared on sign-out
When the user signs out, the biometric-protected Keychain item SHALL be deleted along with all other per-user session data. The `biometricUnlockEnabled` preference SHALL be reset to `false`.

#### Scenario: Sign-out deletes biometric Keychain item
- **GIVEN** biometric unlock is enabled
- **WHEN** the user taps "Sign in with a different account" and signs out
- **THEN** the biometric Keychain item SHALL be deleted AND `biometricUnlockEnabled` SHALL be `false`
