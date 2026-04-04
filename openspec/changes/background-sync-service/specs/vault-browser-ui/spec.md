## MODIFIED Requirements

### Requirement: User can log in to a self-hosted Bitwarden or Vaultwarden server
The system SHALL provide a login screen with a server URL field, email field, and master password field. The server URL field SHALL be empty by default with a placeholder ("https://vault.example.com"). There SHALL be no default cloud server. The app SHALL derive all service endpoints (API, identity, icons) from the base URL. TOTP two-factor authentication SHALL be supported as the only 2FA method in v1.

#### Scenario: Login screen shows required fields
- **WHEN** the app is launched with no stored account
- **THEN** a server URL field, email field, and master password field are visible; the server URL field is empty with a placeholder

#### Scenario: Server URL validated on submission
- **WHEN** the user submits with an invalid server URL (missing scheme, malformed)
- **THEN** login is blocked and a clear inline error message is shown; trailing slashes are stripped from valid URLs

#### Scenario: Successful login navigates directly to vault browser
- **GIVEN** a valid self-hosted server URL and correct credentials
- **WHEN** the user confirms
- **THEN** the app transitions directly to the vault browser; background sync begins immediately and is reflected in the sidebar footer indicator

#### Scenario: Invalid password
- **WHEN** the user enters an incorrect master password
- **THEN** an inline error is shown and the user may retry without closing the app

#### Scenario: Server unreachable
- **WHEN** the server cannot be reached
- **THEN** a clear error explains the server is unreachable and prompts the user to check the address

#### Scenario: Empty fields submitted
- **WHEN** the user submits with an empty email or password
- **THEN** the field is highlighted with a validation message before any network request

#### Scenario: TOTP two-factor authentication required
- **WHEN** the server responds with a TOTP challenge
- **THEN** a TOTP input prompt is shown with a "Remember this device" checkbox (defaulting to unchecked); the checkbox suppresses future 2FA prompts for this device when checked

#### Scenario: Unsupported 2FA method
- **WHEN** the server requires a non-TOTP 2FA method
- **THEN** a clear message explains the limitation

---

### Requirement: User can unlock the vault without a full login
The system SHALL provide an unlock screen for returning users. The unlock screen SHALL display the stored account email as read-only. The vault SHALL decrypt locally using the stored encrypted keys — no network request for the KDF step. After unlock, the vault browser is shown immediately and a background sync begins. A "Sign in with a different account" option SHALL be provided.

#### Scenario: Unlock with correct password navigates directly to vault browser
- **GIVEN** the app is reopened with a stored locked session
- **WHEN** the user enters the correct master password
- **THEN** the app decrypts locally and immediately shows the vault browser; background sync begins and is reflected in the sidebar footer indicator

#### Scenario: Unlock with incorrect password
- **WHEN** the user enters an incorrect master password
- **THEN** an inline error is shown; the user may retry

#### Scenario: Switch to different account
- **WHEN** the user selects "Sign in with a different account"
- **THEN** all stored session data is cleared and the login screen is shown

#### Scenario: Vault locks on quit
- **GIVEN** the vault is unlocked and the user quits the app
- **WHEN** the app is relaunched
- **THEN** the vault is locked and the unlock screen is shown

## REMOVED Requirements

### Requirement: Sync error banner shown on mid-session failure
**Reason**: Replaced by the sidebar footer sync status indicator (`sidebar-sync-status` capability). The footer shows a red error icon on sync failure; tapping opens a sheet with the error message and a Dismiss button.
**Migration**: Remove `syncErrorBanner` from `VaultBrowserView`, remove `syncErrorMessage` and `dismissSyncError()` from `VaultBrowserViewModel`. Sync error state is now owned by `SyncService` and surfaced via `SidebarFooterView`.
