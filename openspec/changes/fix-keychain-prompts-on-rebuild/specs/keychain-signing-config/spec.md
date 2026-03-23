## ADDED Requirements

### Requirement: Data protection keychain access
The app SHALL store and retrieve all keychain items using the data protection keychain (`kSecUseDataProtectionKeychain: true`) scoped to the `$(AppIdentifierPrefix)com.macwarden` access group, so that access is controlled by the app's entitlements rather than per-binary code-signature ACLs.

#### Scenario: New build reads keychain without prompt
- **WHEN** a developer builds and runs a new version of the app
- **THEN** no macOS keychain password dialog appears on startup or unlock

#### Scenario: Items scoped to access group
- **WHEN** a keychain item is written
- **THEN** it is stored with `kSecAttrAccessGroup` set to the resolved `$(AppIdentifierPrefix)com.macwarden` value

### Requirement: Team ID excluded from repo
The git repository SHALL NOT contain the developer's Team ID or Apple ID in any committed file.

#### Scenario: Fresh clone builds without personal credentials
- **WHEN** a contributor clones the repo and opens the project
- **THEN** Xcode prompts them to set their own signing identity rather than using a committed Team ID

#### Scenario: Template guides setup
- **WHEN** a contributor needs to configure signing
- **THEN** a committed `LocalConfig.xcconfig.template` file tells them exactly what to copy and fill in

### Requirement: No duplicate keychain reads on unlock
The unlock flow SHALL read each keychain item at most once per unlock operation.

#### Scenario: Unlock reads email once
- **WHEN** the user unlocks the vault with their master password
- **THEN** `email`, `name`, and `serverEnvironment` are each read from keychain exactly once
