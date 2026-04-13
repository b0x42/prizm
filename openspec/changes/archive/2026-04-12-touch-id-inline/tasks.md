## 0. Tests First (TDD — Red phase before any implementation)

- [x] 0.1 In `UnlockViewModelBiometricTests`, restructure enrollment tests: drive state through real `unlock()` flow (set UserDefaults preconditions, call `sut.unlock()`, await `showEnrollmentPrompt == true`), then call `dismissEnrollmentPrompt()` / `confirmEnrollBiometric()` and assert `flowState == .vault`.
- [x] 0.2 In `UnlockViewModelBiometricTests`, assert on `showEnrollmentPrompt: Bool` and `enrollmentReason` properties (sheet-based state — no `flowState.enrollmentPrompt` pattern match).
- [x] 0.3 In `BiometricEnrollmentJourneyTests`, replace every `app.sheets.firstMatch` with `app.otherElements["unlock.enrollmentPrompt"].firstMatch` — the accessibility identifier is applied to the sheet's root view.
- [x] 0.4 In `BiometricUnlockJourneyTests`, update `testBiometricAutoPrompt_firesOnUnlockScreen`: remove `app.buttons["unlock.biometric"]` check (button is deleted); replace with an assertion that the subtitle static text containing "Touch ID" exists when biometrics are enabled.
- [x] 0.5 In `UnlockViewModelBiometricTests`, add `testUnlockWithBiometrics_cancellation_rearmsImmediately`: after a cancellation error, assert `mockAuth.unlockWithBiometricsCallCount` is ≥ 2 (initial call + re-arm).

## 1. UnlockViewModel — Keep Sheet State, Add Always-Armed Loop

- [x] 1.1 Keep `@Published var showEnrollmentPrompt: Bool` and `@Published private(set) var enrollmentReason: EnrollmentReason` in `UnlockViewModel`; no `UnlockFlowState.enrollmentPrompt` case needed.
- [x] 1.2 In `unlockWithBiometrics()`, update the user-cancellation catch branch: after setting `flowState = .unlock`, call `triggerBiometricUnlockIfAvailable()` to re-arm the sensor immediately; do NOT re-arm on lockout, invalidation, or item-not-found errors.

## 2. UnlockView — Icon Badge + Subtitle

- [x] 2.1 Replace the `Image(systemName: "lock.fill")` header icon with a `ZStack` that overlays `EmbeddedTouchIDView` (LAAuthenticationView) badge (bottom-trailing) when `viewModel.biometricUnlockAvailable`; no badge otherwise.
- [x] 2.2 Replace the static subtitle with a computed string: `"Touch ID or enter the password for \(viewModel.email) to unlock."` when biometrics available, `"Enter the password for \(viewModel.email) to unlock."` otherwise.
- [x] 2.3 Remove the `biometricButton` section entirely.
- [x] 2.4 Keep the `.sheet(isPresented: $viewModel.showEnrollmentPrompt)` modifier presenting `BiometricEnrollmentPromptView`; apply `AccessibilityID.Unlock.enrollmentPrompt` to the sheet root.

## 3. LAAuthenticationView Inline Biometric (no system modal)

- [x] 3.1 Add `EmbeddedTouchIDView` (`NSViewRepresentable` wrapping `LAAuthenticationView`) to `Presentation/Components/`.
- [x] 3.2 Add `EmbeddedBiometricUnlock` protocol (Data layer) keeping `LAContext` out of Domain.
- [x] 3.3 Add `biometricContext: LAContext` and `biometricContextVersion: Int` published properties to `UnlockViewModel`; add `rearmBiometrics()` and `triggerEmbeddedBiometricIfAvailable()`.
- [x] 3.4 Wire `.task(id: viewModel.biometricContextVersion)` in `UnlockView` to call `triggerEmbeddedBiometricIfAvailable()`; use `.id(biometricContextVersion)` on `EmbeddedTouchIDView` to force recreation on re-arm.

## 4. AccessibilityIdentifiers Cleanup

- [x] 4.1 Remove `biometricButton = "unlock.biometric"` from `AccessibilityID.Unlock`.
- [x] 4.2 Add `biometricBadge = "unlock.biometricBadge"` to `AccessibilityID.Unlock`; apply it to the badge overlay.

## 5. AuthError — Silent Degradation

- [x] 5.1 Add `AuthError.biometricItemNotFound`; throw it from `AuthRepositoryImpl` when Keychain returns `itemNotFound`; handle silently in `UnlockViewModel` (no error message, no re-arm).

## 6. Verify Tests Green

- [x] 6.1 Run `UnlockViewModelBiometricTests` — all 10 pass.
- [x] 6.2 Run `BiometricEnrollmentJourneyTests` — all pass; confirm `app.otherElements["unlock.enrollmentPrompt"]` resolves inside the sheet.
- [x] 6.3 Run `BiometricUnlockJourneyTests` — all pass; confirm no `unlock.biometric` button queries remain.

## 7. Smoke Test

- [x] 7.1 Build and run; lock vault; confirm Touch ID badge appears on icon and subtitle shows Touch ID copy; confirm auto-prompt fires on appear with no system modal.
- [x] 7.2 Cancel Touch ID prompt; confirm password field is focused, no error shown, badge still visible, sensor re-arms.
- [x] 7.3 Disable biometric unlock in Settings; confirm badge disappears and subtitle switches to password-only copy.
- [x] 7.4 Reset `biometricEnrollmentPromptShown` to `false`; unlock with password; confirm modal sheet appears.
- [x] 7.5 Accept enrollment; confirm flow proceeds to vault.
- [x] 7.6 Repeat 7.4; tap "Not now"; confirm flow proceeds to vault.
