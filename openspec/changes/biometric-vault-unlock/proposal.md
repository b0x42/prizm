## Why

Typing the master password every time the vault locks is slow and creates friction — especially on a MacBook with Touch ID available. Biometric unlock lets users re-open their vault instantly while preserving the same cryptographic security guarantees.

## What Changes

- **New**: Biometric (Touch ID) unlock path on the lock screen — fires automatically when the vault locks
- **New**: Post-unlock prompt after first successful password unlock offering to enable Touch ID
- **New**: Settings toggle to enable / disable biometric unlock at any time
- **New**: Graceful degradation when biometric enrollment changes — explains why Touch ID stopped working and re-offers enrollment after next successful password unlock
- **New**: Biometric-protected Keychain item storing the derived vault symmetric key (`CryptoKeys`), gated by `.biometryCurrentSet`
- **New**: `BiometricKeychainService` — a separate Keychain write/read path using `kSecAccessControl` (incompatible with the existing `kSecAttrAccessible` path)

## Capabilities

### New Capabilities

- `biometric-unlock`: End-to-end biometric vault unlock — enrollment, auto-prompt on lock, invalidation handling, and settings toggle

### Modified Capabilities

- `vault-lock`: Lock screen gains biometric auto-prompt and Touch ID button; existing password path unchanged

## Impact

- **New framework**: `LocalAuthentication` (no additional entitlement required for macOS sandbox)
- **Data layer**: `KeychainService` protocol + `KeychainServiceImpl` extended with biometric read/write; `AuthRepositoryImpl` gains biometric unlock methods
- **Domain layer**: `AuthRepository` protocol gains `biometricUnlockAvailable`, `enableBiometricUnlock()`, `disableBiometricUnlock()`, `unlockWithBiometrics()`
- **Presentation layer**: `UnlockView` / `UnlockViewModel` gain auto-prompt behaviour and biometric button; new `BiometricEnrollmentPrompt` component; Settings screen gains toggle
- **Persistence**: New Keychain key `bw.macos:<userId>:biometricVaultKey`; new UserDefaults keys `biometricUnlockEnabled`, `biometricPromptShown`
