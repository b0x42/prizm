## 0. Tests First (TDD — Red phase before any implementation)

- [x] 0.1 In `UnlockViewModelBiometricTests`, restructure `testDismissEnrollmentPrompt_callsPerformSync`: remove the direct `sut.showEnrollmentPrompt = true` setup (property will not exist); instead set `UserDefaults.biometricEnrollmentPromptShown = false`, stub `mockAuth.unlockWithPasswordResult` to succeed, call `sut.unlock()`, and await `flowState == .enrollmentPrompt(...)` before calling `dismissEnrollmentPrompt()`. Add parallel test for `confirmEnrollBiometric()`. Assert `flowState == .vault` after each. These tests must fail to compile until sections 1–2 are done.
- [x] 0.2 In `UnlockViewModelBiometricTests`, replace all remaining assertions on `showEnrollmentPrompt` and `enrollmentReason` properties with `flowState` pattern matches; leave tests failing until implementation is complete.
- [x] 0.3 In `BiometricEnrollmentJourneyTests`, replace every `app.sheets.firstMatch` with `app.otherElements["unlock.enrollmentPrompt"].firstMatch` — sheets will not exist after the change. Tests must fail until section 4 is done.
- [x] 0.4 In `BiometricUnlockJourneyTests`, update `testBiometricAutoPrompt_firesOnUnlockScreen`: remove `app.buttons["unlock.biometric"]` check (button is deleted); replace with an assertion that the subtitle static text containing "Touch ID" exists when biometrics are enabled. Test must fail until section 3 is done.
- [x] 0.5 In `UnlockViewModelBiometricTests`, add `testUnlockWithBiometrics_cancellation_rearmsImmediately`: after a cancellation error, assert `mockAuth.unlockWithBiometricsCalled` count is ≥ 2 (initial call + re-arm). Test must fail until task 2.5 is done.

## 1. UnlockFlowState — Add Enrollment Case

- [x] 1.1 Add `case enrollmentPrompt(reason: EnrollmentReason)` to `UnlockFlowState` in `UnlockViewModel.swift`; verify `Equatable` synthesises correctly (no manual `==` needed since `EnrollmentReason` is already `Equatable`)

## 2. UnlockViewModel — Replace Sheet State with Flow State + Always-Armed Loop

- [x] 2.1 Remove `@Published var showEnrollmentPrompt: Bool` and `@Published private(set) var enrollmentReason: EnrollmentReason` from `UnlockViewModel`
- [x] 2.2 In `checkEnrollmentOrSync()`, replace `showEnrollmentPrompt = true` / setting `enrollmentReason` with `flowState = .enrollmentPrompt(reason: ...)`
- [x] 2.3 In `confirmEnrollBiometric()`, replace `showEnrollmentPrompt = false` with `flowState = .loading` before calling `performSync()`
- [x] 2.4 In `dismissEnrollmentPrompt()`, replace `showEnrollmentPrompt = false` with `flowState = .loading` before calling `performSync()`
- [x] 2.5 In `unlockWithBiometrics()`, update the user-cancellation catch branch: after setting `flowState = .unlock`, call `triggerBiometricUnlockIfAvailable()` to re-arm the sensor immediately; do NOT re-arm on lockout, invalidation, or item-not-found errors

## 3. UnlockView — Icon Badge + Subtitle

- [x] 3.1 Replace the `Image(systemName: "lock.fill")` header icon with a `ZStack` that overlays a `touchid` SF Symbol badge (bottom-trailing, small) when `viewModel.biometricUnlockAvailable`; no badge otherwise
- [x] 3.2 Replace the static subtitle "Enter your master password to unlock." with a computed string: `"Touch ID or enter the password for \(viewModel.email) to unlock."` when biometrics available, `"Enter the password for \(viewModel.email) to unlock."` otherwise
- [x] 3.3 Remove the `biometricButton` section (`if viewModel.biometricUnlockAvailable { Button { ... } ... }`) entirely
- [x] 3.4 Remove the `.sheet(isPresented: $viewModel.showEnrollmentPrompt)` modifier and its `BiometricEnrollmentPromptView` content

## 4. UnlockView — Inline Enrollment State

- [x] 4.1 Add a `switch viewModel.flowState` (or `if case`) branch for `.enrollmentPrompt(let reason)` that renders the enrollment content inline — icon, heading, body copy, `[Enable Touch ID]` / `[Re-enable Touch ID]` button, and `[Not now]` button; wire buttons to `viewModel.confirmEnrollBiometric()` / `viewModel.dismissEnrollmentPrompt()`
- [x] 4.2 Apply `AccessibilityID.Unlock.enrollmentPrompt` to the inline enrollment container `VStack`

## 5. Delete BiometricEnrollmentPromptView

- [x] 5.1 Delete `Prizm/Presentation/Unlock/BiometricEnrollmentPromptView.swift`
- [x] 5.2 Remove `BiometricEnrollmentPromptView` from `Prizm.xcodeproj/project.pbxproj` (file reference + build phase entry)

## 6. AccessibilityIdentifiers Cleanup

- [x] 6.1 Remove `biometricButton = "unlock.biometric"` from `AccessibilityID.Unlock` in `AccessibilityIdentifiers.swift`
- [x] 6.2 Add `biometricBadge = "unlock.biometricBadge"` to `AccessibilityID.Unlock`; apply it to the badge overlay in task 3.1 so future tests can assert badge presence/absence

## 7. Verify Tests Green

- [x] 7.1 Run `UnlockViewModelBiometricTests` — all pass
- [x] 7.2 Run `BiometricEnrollmentJourneyTests` — all pass; confirm no `app.sheets` queries remain
- [x] 7.3 Run `BiometricUnlockJourneyTests` — all pass; confirm no `unlock.biometric` button queries remain

## 8. Smoke Test

- [x] 8.1 Build and run; lock vault; confirm Touch ID badge appears on icon and subtitle shows Touch ID copy; confirm auto-prompt fires on appear
- [x] 8.2 Cancel Touch ID prompt; confirm password field is focused, no error shown, badge still visible
- [x] 8.3 Disable biometric unlock in Settings; confirm badge disappears and subtitle switches to password-only copy
- [x] 8.4 Reset `biometricEnrollmentPromptShown` to `false`; unlock with password; confirm inline enrollment view appears (no sheet)
- [x] 8.5 Accept enrollment; confirm flow proceeds to vault without a sheet dismiss animation
- [x] 8.6 Repeat 8.4; tap "Not now"; confirm flow proceeds to vault without a sheet dismiss animation
