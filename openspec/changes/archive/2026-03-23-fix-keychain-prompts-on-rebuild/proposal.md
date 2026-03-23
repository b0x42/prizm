## Why

Every new Xcode build changes the app's code signature, invalidating the per-item ACLs on all login keychain items and triggering 4–9 macOS password prompts per test run. This makes iterative development painful and slows testing.

## What Changes

- Add `keychain-access-groups` entitlement so keychain access is controlled by entitlement (stable across rebuilds) rather than per-binary code-signature ACLs
- Add `kSecUseDataProtectionKeychain: true` to all keychain queries in `KeychainService` to route items through the data protection keychain
- Introduce `LocalConfig.xcconfig` (gitignored) for per-developer signing settings so no Team ID is committed to the repo
- Add `LocalConfig.xcconfig.template` (committed) so contributors know how to set up signing locally
- Clear `DEVELOPMENT_TEAM` from `project.pbxproj` so it is read from xcconfig instead
- Fix duplicate keychain reads in `unlockWithPassword` (email, name, serverEnvironment are fetched twice — once directly, once via `account(for:)`)

## Capabilities

### New Capabilities

- `keychain-signing-config`: Per-developer xcconfig signing setup that keeps Team ID out of the repo while enabling keychain access groups

### Modified Capabilities

- (none — keychain storage requirements are unchanged; only the access-control mechanism and plumbing change)

## Impact

- `Macwarden/Macwarden/Macwarden.entitlements` — add `keychain-access-groups`
- `Macwarden/Data/Keychain/KeychainService.swift` — add `kSecUseDataProtectionKeychain` and `kSecAttrAccessGroup` to all queries
- `Macwarden/Data/Repositories/AuthRepositoryImpl.swift` — remove duplicate keychain reads in `unlockWithPassword`
- `Macwarden/Macwarden.xcodeproj/project.pbxproj` — clear `DEVELOPMENT_TEAM`, wire xcconfig
- New files: `LocalConfig.xcconfig.template`, `LocalConfig.xcconfig` (gitignored), `.gitignore` update
- Existing keychain items (login keychain) will not auto-migrate — fresh login required after the change (one-time)
