# Tasks

## 1. Toggle disabled-state fix

- [ ] 1.1 Write a failing XCUITest journey covering the `settings-screen` spec scenario "Biometric toggle re-enables after the vault is unlocked": lock the vault, open Settings, trigger the vault-locked toggle failure, unlock the vault while Settings stays open, assert the toggle becomes enabled and the hint text disappears — verify it fails against current code.
- [ ] 1.2 Add `Notification.Name.vaultDidUnlock` (Domain layer, Foundation-only) and post it from `AuthRepositoryImpl` immediately after any successful vault unlock (password or biometric) — verify with a unit test that unlocking triggers exactly one post of the notification.
- [ ] 1.3 In `BiometricUnlockToggle.swift`, subscribe via `.onReceive(NotificationCenter.default.publisher(for: .vaultDidUnlock))` and clear `showVaultLockedHint = false` on receipt, replacing the current one-way latch that only clears on a successful toggle retry (per design.md - Decisions) — verify the XCUITest from 1.1 now passes.
- [ ] 1.4 Add/extend a unit test (or XCUITest, matching whatever test type 1.1 used) for the existing scenario "Biometric toggle is disabled when vault is locked" to confirm it still passes unchanged — verify no regression.

## 2. Availability-check logging

- [ ] 2.1 Add `os.Logger` (subsystem `com.prizm`) error-level logging of the discarded `NSError` at `AuthRepositoryImpl.swift:441` and `:448`, without changing the returned boolean — verify by triggering a biometric-unavailable condition in a simulator/device without enrolled biometrics and confirming the log line appears in Console.app.
- [ ] 2.2 Add the same logging at `SettingsView.swift:13` — verify the same way as 2.1.
- [ ] 2.3 Confirm no biometric or vault data appears in the logged output, only the `NSError` domain/code (per design.md - Risks: no secrets in logs) — verify by reading the log line text.

## 3. Spec conformance check

- [ ] 3.1 Run `openspec validate fix-touch-id-toggle-disabled --type change --strict` and confirm it passes.
- [ ] 3.2 Run the full XCUITest suite (`xcodebuild test -project "Prizm/Prizm.xcodeproj" -scheme "Prizm" -destination "platform=macOS"`) and confirm no regressions in other `biometric-unlock`/`settings-screen`/`vault-lock` journeys.
