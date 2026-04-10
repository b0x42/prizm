## 1. Biometric Keychain Service

- [ ] 1.1 Write failing tests for `BiometricKeychainServiceImpl` — `writeBiometric`, `readBiometric`, `deleteBiometric`; include `.itemNotFound` and biometric-unavailable error cases
- [ ] 1.2 Define `BiometricKeychainService` protocol (`writeBiometric(data:key:) throws`, `readBiometric(key:) throws -> Data`, `deleteBiometric(key:) throws`)
- [ ] 1.3 Implement `BiometricKeychainServiceImpl` using `kSecAccessControl` + `.biometryCurrentSet` + `kSecUseDataProtectionKeychain: true`; no `kSecAttrAccessible`. Explicitly scope to the app's `keychain-access-groups` entitlement so the item is not accessible to other apps or processes (Constitution Security Requirement property 3)
- [ ] 1.4 Add `bw.macos:<userId>:biometricVaultKey` key constant to `KeychainKey` enum in `AuthRepositoryImpl.swift`
- [ ] 1.5 Register `BiometricKeychainService` / `BiometricKeychainServiceImpl` in `AppContainer`

## 2. AuthRepository — Biometric Unlock Protocol

- [ ] 2.1 Write failing tests for new `AuthRepository` biometric methods on `MockAuthRepository`
- [ ] 2.2 Add to `AuthRepository` protocol: `var biometricUnlockAvailable: Bool { get }`, `func enableBiometricUnlock() async throws`, `func disableBiometricUnlock() async throws`, `func unlockWithBiometrics() async throws -> Account`
- [ ] 2.3 Update `MockAuthRepository` to satisfy the extended protocol (for tests)

## 3. AuthRepositoryImpl — Biometric Unlock Implementation

- [ ] 3.1 Write failing unit tests for `AuthRepositoryImpl` biometric methods (mock `BiometricKeychainService`)
- [ ] 3.2 Implement `biometricUnlockAvailable` — check `LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` AND biometric Keychain item exists
- [ ] 3.3 Implement `enableBiometricUnlock()` — guard that `PrizmCryptoService` has keys in memory (vault is unlocked), throwing `AuthError.biometricUnavailable` if not; serialize `CryptoKeys` as 64-byte blob (`encryptionKey || macKey`), write to biometric Keychain
- [ ] 3.4 Implement `disableBiometricUnlock()` — delete biometric Keychain item, set `UserDefaults.biometricUnlockEnabled = false`
- [ ] 3.5 Implement `unlockWithBiometrics()` — read biometric Keychain item, deserialize `CryptoKeys`, call `crypto.unlockWith(keys:)`, restore API client state, return `Account`; on `.biometryCurrentSet` invalidation error → delete Keychain item, set `biometricUnlockEnabled = false`, reset `biometricEnrollmentPromptShown = false`, throw `AuthError.biometricInvalidated`
- [ ] 3.6 Add `AuthError.biometricInvalidated` and `AuthError.biometricUnavailable` cases with localized descriptions
- [ ] 3.7 Update `signOut()` in `AuthRepositoryImpl` to call `disableBiometricUnlock()` (delete biometric Keychain item + clear preference)

## 4. PrizmCryptoService — Key Serialisation

- [ ] 4.1 Write failing tests for `CryptoKeys` encode/decode round-trip (64-byte `Data`)
- [ ] 4.2 Add `CryptoKeys.toData() -> Data` (concatenate `encryptionKey + macKey`) and `CryptoKeys.init?(data: Data)` (split at byte 32) helpers in the Data layer

## 5. UnlockViewModel — Biometric Unlock

- [ ] 5.1 Write failing tests for `UnlockViewModel.unlockWithBiometrics()` — success, cancellation (no error shown), lockout error, invalidation error
- [ ] 5.2 Add `unlockWithBiometrics()` to `UnlockViewModel` — call `auth.unlockWithBiometrics()`, on success call `performSync()`, on `.biometricInvalidated` show invalidation message, on cancellation show no error
- [ ] 5.3 Add `var biometricUnlockAvailable: Bool` computed property to `UnlockViewModel`
- [ ] 5.4 Add `triggerBiometricUnlockIfAvailable()` to `UnlockViewModel` — calls `unlockWithBiometrics()` only if available; no-op otherwise
- [ ] 5.5 Add `showEnrollmentPrompt: Bool` and `enrollmentReason: EnrollmentReason` published properties to `UnlockViewModel`; set after successful password unlock when biometrics are available AND `biometricUnlockEnabled` is `false` AND `biometricEnrollmentPromptShown` is `false`; reason is `.reEnrollAfterInvalidation` if `AuthError.biometricInvalidated` was thrown on the previous unlock attempt, otherwise `.firstTime`
- [ ] 5.6 Add `confirmEnrollBiometric()` and `dismissEnrollmentPrompt()` actions to `UnlockViewModel`; both set `UserDefaults.biometricEnrollmentPromptShown = true` before dismissing

## 6. UnlockView — Biometric UI

- [ ] 6.1 Add Touch ID / Face ID button to `UnlockView` below the Unlock button (visible only when `viewModel.biometricUnlockAvailable`); label from `LAContext().biometryType`
- [ ] 6.2 Add `.task { viewModel.triggerBiometricUnlockIfAvailable() }` to `UnlockView` to auto-prompt on appearance
- [ ] 6.3 Add biometric invalidation error message display (distinct from generic error — shows the "Touch ID settings have changed" copy)
- [ ] 6.4 Present `BiometricEnrollmentPromptView` as a sheet when `viewModel.showEnrollmentPrompt` is `true`
- [ ] 6.5 Add `AccessibilityID.Unlock.biometricButton` and `AccessibilityID.Unlock.enrollmentPrompt` identifiers

## 7. BiometricEnrollmentPromptView

- [ ] 7.1 Create `BiometricEnrollmentPromptView` with a `reason: EnrollmentReason` parameter (`.firstTime` / `.reEnrollAfterInvalidation`); first-time copy: heading "Enable Touch ID to unlock faster", body "You can also enable this in Settings at any time."; re-enroll copy: heading "Re-enable Touch ID", body "Your Touch ID settings changed — a fingerprint was added or removed. For your security, Prizm disabled Touch ID unlock. Would you like to re-enable it?"; both show `[Enable Touch ID]` / `[Re-enable Touch ID]` and `[Not now]` buttons wired to `UnlockViewModel`
- [ ] 7.2 Write UI tests for enrollment prompt — first-time copy, re-enroll copy, accept path, dismiss path

## 8. Settings Screen & Toolbar Button

- [ ] 8.1 Add a SwiftUI `Settings { SettingsView() }` scene to `PrizmApp.swift` — this gives ⌘, for free via macOS conventions
- [ ] 8.2 Create `SettingsView` with a Security section containing `BiometricUnlockToggle`; hidden entirely when device has no biometrics
- [ ] 8.3 Add gear `ToolbarItem` to the detail column toolbar in `VaultBrowserView` (next to the search field); wire to `openSettings` environment action
- [ ] 8.4 Add `AccessibilityID.Vault.settingsButton` identifier to the gear toolbar button
- [ ] 8.5 Create `BiometricUnlockToggle` component — visible when biometrics available; disabled with explanatory label when vault is locked; reads/writes `biometricUnlockEnabled` via `AuthRepository`
- [ ] 8.6 Write unit tests for `BiometricUnlockToggle` enable/disable paths and vault-locked disabled state

## 9. UI Journey Tests

- [ ] 9.1 Write `BiometricUnlockJourneyTests` — mock biometric service; test auto-prompt, successful unlock, cancellation fallback, lockout message
- [ ] 9.2 Extend `UnlockJourneyTests` to cover invalidation message after biometric failure

## 10. Wiring & Cleanup

- [ ] 10.1 Inject `BiometricKeychainService` into `AuthRepositoryImpl` via `AppContainer`
- [ ] 10.2 Remove any `TODO: biometric unlock` comments from existing code
- [ ] 10.3 Verify build compiles in Swift 6 strict concurrency mode with no warnings
- [ ] 10.4 Manual smoke test: enable Touch ID, lock vault, confirm auto-prompt fires, confirm unlock succeeds
- [ ] 10.5 Update `SECURITY.md` — document biometric Keychain item: what is stored (`CryptoKeys`, 64 bytes), access control (`.biometryCurrentSet`, Secure Enclave-backed), conditions under which the item is created (user opt-in, vault unlocked) and deleted (sign-out, disable toggle, biometric invalidation), and that `kSecAttrSynchronizable` is not set (device-only, never backed up)
