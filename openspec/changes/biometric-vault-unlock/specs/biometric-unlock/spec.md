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

### Requirement: User is offered biometric unlock once after their first successful password unlock
After a successful password unlock, if biometric authentication is available on the device and the enrollment prompt has never been shown before, the system SHALL present the prompt exactly once. The prompt SHALL inform the user that the setting is also accessible in Settings. After the prompt is shown — regardless of the user's choice — it SHALL never appear again. Biometric unlock can still be enabled at any time via the Settings toggle.

#### Scenario: Enrollment prompt appears after first successful password unlock
- **GIVEN** biometrics are available on the device AND biometric unlock is not currently enabled AND the enrollment prompt has never been shown before (`biometricEnrollmentPromptShown` is `false`)
- **WHEN** the user successfully unlocks the vault with their master password
- **THEN** the system SHALL present an enrollment prompt with the heading "Enable Touch ID to unlock faster" and the body "You can also enable this in Settings at any time."

#### Scenario: Enrollment prompt is never shown a second time
- **GIVEN** the enrollment prompt has previously been shown (regardless of the user's choice)
- **WHEN** the user successfully unlocks the vault with their master password
- **THEN** the enrollment prompt SHALL NOT appear

#### Scenario: User accepts enrollment prompt
- **WHEN** the user taps "Enable Touch ID" on the enrollment prompt
- **THEN** the system SHALL store the vault key in a biometric-protected Keychain item AND set `biometricUnlockEnabled = true` AND set `biometricEnrollmentPromptShown = true` AND dismiss the prompt

#### Scenario: User dismisses enrollment prompt
- **WHEN** the user taps "Not now" on the enrollment prompt
- **THEN** the prompt SHALL be dismissed AND `biometricEnrollmentPromptShown` SHALL be set to `true`
- **AND** biometric unlock SHALL remain disabled

---

### Requirement: User can enable and disable biometric unlock from Settings
The system SHALL provide a toggle in Settings to enable or disable biometric unlock at any time. Enabling SHALL store the vault key in a biometric-protected Keychain item; disabling SHALL delete that item. Enabling requires the vault to be unlocked — the vault symmetric key must be in memory to be stored.

#### Scenario: Cannot enable biometric unlock while vault is locked
- **GIVEN** the vault is currently locked
- **WHEN** `enableBiometricUnlock()` is called (e.g. via the Settings toggle)
- **THEN** the system SHALL throw `AuthError.biometricUnavailable` and the biometric Keychain item SHALL NOT be written

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
When the system reports that the biometric Keychain item is no longer accessible (`.biometryCurrentSet` invalidated due to enrollment change), the system SHALL inform the user, clear the biometric preference, and re-offer re-enrollment after the next successful password unlock using a distinct prompt that explains why re-enrollment is needed.

#### Scenario: Biometric unlock fails due to enrollment change
- **GIVEN** biometric unlock was previously enabled AND the user has since added or removed a fingerprint
- **WHEN** the vault locks and the biometric prompt fires
- **THEN** the biometric unlock SHALL fail and the system SHALL display: "Your Touch ID settings have changed. Please enter your master password to continue."
- **AND** `biometricUnlockEnabled` SHALL be set to `false`, the biometric Keychain item SHALL be deleted, and `biometricEnrollmentPromptShown` SHALL be reset to `false`

#### Scenario: Re-enrollment prompt is offered after invalidation
- **GIVEN** biometric unlock was invalidated on the previous lock/unlock cycle (`biometricEnrollmentPromptShown` was reset to `false`)
- **WHEN** the user successfully unlocks the vault with their master password
- **THEN** the system SHALL present a re-enrollment prompt with the heading "Re-enable Touch ID" and the body "Your Touch ID settings changed — a fingerprint was added or removed. For your security, Prizm disabled Touch ID unlock. Would you like to re-enable it?"
- **AND** the prompt SHALL offer `[Re-enable Touch ID]` and `[Not now]` actions

#### Scenario: Re-enrollment prompt behaves identically to first-time enrollment on accept or dismiss
- **WHEN** the user taps "Re-enable Touch ID"
- **THEN** the system SHALL store the vault key in a biometric-protected Keychain item, set `biometricUnlockEnabled = true`, and set `biometricEnrollmentPromptShown = true`
- **WHEN** the user taps "Not now"
- **THEN** the prompt SHALL be dismissed, `biometricEnrollmentPromptShown` SHALL be set to `true`, and biometric unlock SHALL remain disabled

---

### Requirement: Biometric Keychain item is cleared on sign-out
When the user signs out, the biometric-protected Keychain item SHALL be deleted along with all other per-user session data. The `biometricUnlockEnabled` preference SHALL be reset to `false`.

#### Scenario: Sign-out deletes biometric Keychain item
- **GIVEN** biometric unlock is enabled
- **WHEN** the user taps "Sign in with a different account" and signs out
- **THEN** the biometric Keychain item SHALL be deleted AND `biometricUnlockEnabled` SHALL be `false`
