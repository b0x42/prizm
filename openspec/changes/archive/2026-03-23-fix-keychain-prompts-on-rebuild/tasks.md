## 0. Tests (write before implementation — Constitution §IV)

- [x] 0.1 Add `readKeys: [String]` tracking to `MockKeychainService.read(key:)` (parallel to the existing `writtenKeys` array), then write a test in `AuthRepositoryImplTests` that verifies `email` appears exactly once in `readKeys` after a successful `unlockWithPassword` call
- [x] 0.2 In `KeychainServiceTests`, add a note/comment that `kSecUseDataProtectionKeychain` correctness is verified at the integration level (the unit mock cannot exercise real keychain attributes) — no new unit test needed for this, but confirm the existing integration test suite covers a real read/write cycle

## 1. xcconfig signing setup

- [x] 1.1 Create `LocalConfig.xcconfig.template` at repo root with a `DEVELOPMENT_TEAM =` placeholder and instructions
- [x] 1.2 Create `LocalConfig.xcconfig` (gitignored) filled with the developer's own Team ID
- [x] 1.3 Add `LocalConfig.xcconfig` to `.gitignore`
- [x] 1.4 Wire `LocalConfig.xcconfig` into the Xcode project (Project settings → Configurations → Debug/Release) so `DEVELOPMENT_TEAM` is read from it
- [x] 1.5 Clear `DEVELOPMENT_TEAM` from `project.pbxproj` (verify it no longer appears after wiring xcconfig)

## 2. Keychain entitlement

- [x] 2.1 Add `keychain-access-groups` key to `Macwarden.entitlements` with value `$(AppIdentifierPrefix)com.macwarden`

## 3. KeychainService — data protection keychain

- [x] 3.1 Add `kSecUseDataProtectionKeychain: true` to `baseQuery(for:)` in `KeychainServiceImpl`. Do NOT set `kSecAttrAccessGroup` as a Swift string literal — the system automatically uses the first group from the `keychain-access-groups` entitlement for sandboxed apps
- [x] 3.2 Verify all read/write/delete operations inherit the new attribute (they all call `baseQuery`, so no other changes needed)
- [x] 3.3 Update the `KeychainServiceImpl` doc comment to reflect the data protection keychain and access group

## 4. Fix duplicate keychain reads in unlock

- [x] 4.1 Refactor `unlockWithPassword` in `AuthRepositoryImpl` to call `account(for:)` once and reuse the result for `email`, `name`, and `serverEnvironment` instead of reading them separately first

## 5. Clear old login-keychain items

- [x] 5.1 Open Keychain Access.app, find items under service `com.macwarden`, delete them (or simply sign out of the app before building)

## 6. Verify

- [x] 6.1 Build and run — confirm zero keychain password dialogs appear on startup
- [x] 6.2 Sign in and unlock — confirm zero keychain password dialogs appear
- [x] 6.3 Rebuild without changing code — confirm still zero prompts
- [x] 6.4 Confirm `project.pbxproj` contains no Team ID (`grep DEVELOPMENT_TEAM Macwarden/Macwarden.xcodeproj/project.pbxproj` should return empty or only a blank assignment)
- [x] 6.5 Run existing `KeychainServiceTests` — confirm they pass
