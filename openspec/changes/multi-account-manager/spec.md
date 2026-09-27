# Multi-account manager specification

## Account storage

- The app shall retain multiple account profiles.
- A profile shall be identified locally by `profileId` and remotely by server origin plus user ID.
- Secrets and biometric preferences shall be scoped by `profileId`.
- Existing single-account Keychain data shall migrate without requiring a new sign-in.

## Switching

- The Account menu shall list stored profiles and mark the active profile.
- Selecting another profile shall not delete either profile.
- Before activation, the app shall clear decrypted vault data, key caches, temporary plaintext
  files, favicons, revealed-secret state, and account-bound presentation state.
- The target profile shall require password or its own biometric credential before sync.
- Results from work started under a previous session shall not populate the active vault.

## Removal

- Removing a profile shall require confirmation and delete only that profile's local credentials.
- If another profile remains, it shall become active and remain locked.
- If no profile remains, the login screen shall be shown.
