### Requirement: User can unlock the vault with biometrics
The system SHALL provide a biometric unlock path that re-opens the vault without requiring the master password, using the platform biometric authenticator (Touch ID on macOS, Face ID on iOS). The system SHALL store the derived vault symmetric key (`CryptoKeys`) in a Keychain item protected by `kSecAccessControl` with `.biometryCurrentSet`. The master password path SHALL always remain available as a fallback.

#### Scenario: Successful Touch ID unlock
- **GIVEN** biometric unlock is enabled and the vault is locked
- **WHEN** the lock screen appears
- **THEN** the system SHALL automatically trigger the biometric prompt
- **AND** on successful biometric evaluation the vault SHALL unlock and the vault browser SHALL be shown without the user entering a password

#### Scenario: Touch ID badge is shown when biometric unlock is enabled
- **GIVEN** biometric unlock is enabled and the vault is locked
- **WHEN** the lock screen is shown
- **THEN** a Touch ID fingerprint badge SHALL be overlaid on the lock screen icon
- **AND** the subtitle SHALL read "Touch ID or enter the password for [email] to unlock."
- **AND** no separate Touch ID button SHALL be present

#### Scenario: Touch ID badge is absent when biometric unlock is disabled
- **GIVEN** biometric unlock is not enabled
- **WHEN** the lock screen is shown
- **THEN** no Touch ID badge SHALL appear on the lock screen icon
- **AND** the subtitle SHALL read "Enter the password for [email] to unlock."
- **AND** only the master password field SHALL be available

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
- **THEN** the system SHALL display a modal sheet with the heading "Enable Touch ID to unlock faster" and the body "You can also enable this in Settings at any time."

#### Scenario: Enrollment prompt is never shown a second time
- **GIVEN** the enrollment prompt has previously been shown (regardless of the user's choice)
- **WHEN** the user successfully unlocks the vault with their master password
- **THEN** the enrollment prompt SHALL NOT appear

#### Scenario: User accepts enrollment prompt
- **WHEN** the user taps "Enable Touch ID" on the enrollment prompt
- **THEN** the system SHALL store the vault key in a biometric-protected Keychain item AND set `biometricUnlockEnabled = true` AND set `biometricEnrollmentPromptShown = true` AND transition away from the enrollment view

#### Scenario: User dismisses enrollment prompt
- **WHEN** the user taps "Not now" on the enrollment prompt
- **THEN** the enrollment view SHALL be dismissed AND `biometricEnrollmentPromptShown` SHALL be set to `true`
- **AND** biometric unlock SHALL remain disabled

---

### Requirement: Biometric unlock degrades gracefully when Keychain item is deleted externally
If the `biometricUnlockEnabled` UserDefaults flag is `true` but the biometric Keychain item no longer exists (e.g. deleted via Keychain Access.app, `security` CLI, or app reinstall with preserved UserDefaults), the system SHALL fall back to the password path and clear the stale flag.

#### Scenario: Biometric unlock attempt with externally deleted Keychain item
- **GIVEN** `biometricUnlockEnabled` is `true` AND the biometric Keychain item has been deleted outside the app
- **WHEN** the vault locks and the biometric unlock is attempted
- **THEN** the biometric unlock SHALL fail with an `.itemNotFound` error
- **AND** the system SHALL set `biometricUnlockEnabled = false`, remove the Touch ID badge and update the subtitle to the password-only copy, and fall back to the password path without showing an error message to the user
