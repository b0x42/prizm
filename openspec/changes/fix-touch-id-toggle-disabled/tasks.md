# Tasks

## 1. Toggle disabled-state fix

- [x] 1.1 Add `Notification.Name.vaultDidUnlock` in `Prizm/App/Config.swift` next to the existing `.vaultDidLock`, and post it from `AuthRepositoryImpl` immediately after any successful vault unlock (password unlock and both biometric unlock paths) — verify with a unit test that each successful unlock method posts it exactly once.
- [x] 1.2 Write a failing unit test for `BiometricUnlockToggleViewModel` (new type, doesn't exist yet) covering the `settings-screen` spec scenario "Biometric toggle re-enables after the vault is unlocked": call `toggleBiometric(enabled:)` with a mock `AuthRepository` that throws `.biometricUnavailable`, assert `showVaultLockedHint == true`, post `.vaultDidUnlock`, assert `showVaultLockedHint == false` — verify it fails to compile/fails against current code (the type doesn't exist yet).
- [x] 1.3 Extract `isEnabled`/`isProcessing`/`showVaultLockedHint` and `toggleBiometric(enabled:)` out of `BiometricUnlockToggle`'s `@State` into `BiometricUnlockToggleViewModel` (`@MainActor @Observable`, Presentation layer), subscribing to `.vaultDidUnlock` in its initializer and clearing `showVaultLockedHint` on receipt. Update `BiometricUnlockToggle` to own and bind to the view model instead of raw `@State` — verify the unit test from 1.2 now passes.
- [x] 1.4 Add a unit test for the existing scenario "Biometric toggle is disabled when vault is locked" against `BiometricUnlockToggleViewModel` to confirm it still passes unchanged — verify no regression.

## 2. Availability-check logging

- [x] 2.1 Add `os.Logger` (subsystem `com.prizm`) error-level logging of the discarded `NSError` at `AuthRepositoryImpl.swift` `deviceBiometricCapable`/`biometricUnlockAvailable`, without changing the returned boolean. Skips the routine `.biometryNotAvailable`/`.biometryNotEnrolled`/`.passcodeNotSet` cases (normal device states, not failures) to avoid log spam on every render — verify by triggering a biometric-unavailable condition in a simulator/device without enrolled biometrics and confirming the log line appears in Console.app.
- [x] 2.2 Add the same logging (same routine-state filter) at `SettingsView.swift` `deviceHasBiometrics` — verify the same way as 2.1.
- [x] 2.3 Confirm no biometric or vault data appears in the logged output, only the `NSError` domain/code/description (per design.md - Risks: no secrets in logs) — verified by code review of both log call sites; automated capture of `os.Logger` output requires `OSLogStore` device/hardware access and is left to manual Console.app verification per 2.1/2.2.

## 3. Spec conformance check

- [x] 3.1 Run `openspec validate fix-touch-id-toggle-disabled --type change --strict` and confirm it passes.
- [x] 3.2 Ran `xcodebuild test -project "Prizm/Prizm.xcodeproj" -scheme "Prizm" -destination "platform=macOS" -only-testing:PrizmTests` — **TEST SUCCEEDED**, full PrizmTests suite passes including the new `BiometricUnlockToggleViewModelTests` and `.vaultDidUnlock`-posting tests. (XCUITest journeys under `Prizm/UITests/` were not run — separate scheme target, unaffected by this change's files.)

## 4. Manual verification (found and fixed a real crash)

- [x] 4.1 Manually ran the built app: enabled Touch ID, locked vault, unlocked vault — reproduced two `libmalloc` heap-corruption crashes (`BUG IN CLIENT OF LIBMALLOC: memory corruption of free block`) around the lock/unlock cycle.
- [x] 4.2 Root-caused to `BiometricUnlockToggle` constructing `BiometricUnlockToggleViewModel` (a side-effecting `NotificationCenter.addObserver`/`removeObserver` construction) inside a `State(initialValue:)` expression in the View's `init` — re-evaluated on every View struct init instead of once, causing observer-registration churn. Fixed by making `viewModel` optional `@State`, populated once in `.onAppear` (see design.md - Decisions).
- [x] 4.3 Re-ran full `PrizmTests` suite after the fix — **TEST SUCCEEDED**. Re-built and manually re-ran the disable→lock→unlock repro — no crash.
