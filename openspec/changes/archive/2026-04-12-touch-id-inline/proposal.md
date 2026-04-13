## Why

The current unlock screen presents Touch ID as a small plain-text link below the password form, and surfaces the enrollment offer as a `.sheet` modal — both feel out of place on macOS. Touch ID should be the primary unlock action when enabled, with password as an available fallback, matching the interaction model of Apple Passwords and other first-party macOS apps.

## What Changes

- When biometric unlock is **enabled**: overlay a Touch ID fingerprint badge on the app icon; subtitle reads "Touch ID or enter the password for [email] to unlock."; Touch ID auto-prompts on appearance. Password field is always visible — no separate Touch ID button.
- When biometric unlock is **disabled**: no badge; subtitle reads "Enter the password for [email] to unlock."; password field only (current behavior, unchanged).
- Remove the standalone Touch ID plain-text button entirely.
- Replace the `.sheet` enrollment prompt with an inline view rendered directly on the unlock screen via a new `UnlockFlowState.enrollmentPrompt(reason:)` case. No modal backdrop, no sheet animation.
- Remove `showEnrollmentPrompt: Bool` and `enrollmentReason: EnrollmentReason` published properties from `UnlockViewModel`; enrollment state is expressed through `flowState` instead.
- `BiometricEnrollmentPromptView` is no longer a standalone sheet — its content is folded inline into `UnlockView`.

## Capabilities

### New Capabilities
_None._

### Modified Capabilities
- `biometric-unlock`: Enrollment prompt presentation changes from modal sheet to inline view. Touch ID unlock button changes from secondary plain-text link to primary hero action. Layout switches based on whether biometric unlock is enabled.

## Impact

- `Prizm/Presentation/Unlock/UnlockView.swift` — layout restructure; remove `.sheet` modifier
- `Prizm/Presentation/Unlock/UnlockViewModel.swift` — replace `showEnrollmentPrompt`/`enrollmentReason` with `flowState = .enrollmentPrompt(reason:)`
- `Prizm/Presentation/Unlock/UnlockFlowState` (inside `UnlockViewModel.swift`) — add `.enrollmentPrompt(reason: EnrollmentReason)` case
- `Prizm/Presentation/Unlock/BiometricEnrollmentPromptView.swift` — repurposed as an internal subview or deleted; content folds into `UnlockView`
- `Prizm/PrizmTests/Presentation/UnlockViewModelBiometricTests.swift` — assertions updated from `showEnrollmentPrompt` to `flowState`
- `Prizm/UITests/BiometricEnrollmentJourneyTests.swift` — element lookups updated for inline layout
- No Data or Domain layer changes. No crypto changes. No new dependencies.
