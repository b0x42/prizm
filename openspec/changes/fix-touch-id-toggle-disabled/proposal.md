# Proposal

## Why

The "Touch ID unlock" toggle in Settings → Security can become permanently grayed out and unresponsive for the rest of the app session, even when Touch ID hardware is present and fingerprints are enrolled (GitHub #67). This makes biometric unlock impossible to enable without relaunching the app, with no explanation of why the control is stuck.

## What Changes

- Add a `Notification.Name.vaultDidUnlock` notification, posted by `AuthRepositoryImpl` after any successful vault unlock. `BiometricUnlockToggle` (`Prizm/Presentation/Settings/BiometricUnlockToggle.swift`) subscribes to it and clears the `showVaultLockedHint` flag that disables the toggle, instead of only clearing it on a successful toggle retry. The toggle must remain interactable so the user can retry once the vault is unlocked, even while the Settings window stays open.
- Log the discarded `NSError` from `LAContext.canEvaluatePolicy` at the three call sites (`SettingsView.swift:13`, `AuthRepositoryImpl.swift:441`, `:448`) via `os.Logger`, so future biometric-availability failures are diagnosable instead of silently swallowed as a boolean.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `settings-screen`: the biometric toggle's disabled state SHALL track current vault-lock status rather than latching permanently after one failed attempt while locked.
- `biometric-unlock`: adds a requirement that a failed `LAContext.canEvaluatePolicy` check SHALL be logged via `os.Logger` instead of the error being discarded silently.

## Impact

- `Prizm/Presentation/Settings/BiometricUnlockToggle.swift` — subscribe to `vaultDidUnlock`, drop the one-way latch
- `Prizm/Data/Repositories/AuthRepositoryImpl.swift` — post `vaultDidUnlock` on successful unlock; add logging around `canEvaluatePolicy` calls (lines 441, 448)
- `Prizm/Presentation/Settings/SettingsView.swift` — add logging around `canEvaluatePolicy` call (line 13)
- New: a `Notification.Name.vaultDidUnlock` definition in the Domain layer (Foundation-only, no layer violation)
- No API, storage, or crypto changes.
