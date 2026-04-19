## Context

The biometric-vault-unlock change shipped a working Touch ID unlock path. The unlock logic (`triggerBiometricUnlockIfAvailable`, `unlockWithBiometrics`, `.biometryCurrentSet` Keychain gating) is complete and correct. What remains is a UI polish pass:

- The Touch ID button is a plain-text link sitting below the Unlock button — visually an afterthought.
- The enrollment offer fires as a `.sheet` modal — disruptive and inconsistent with macOS conventions.

Reference design: macOS Passwords app. Its unlock screen shows the app icon with a fingerprint badge overlay, a single sentence of copy that mentions both Touch ID and password, and one password field. No separate Touch ID button. Touch ID fires silently on appear.

Current `UnlockFlowState`:
```swift
enum UnlockFlowState: Equatable {
    case unlock, loading, syncing(message: String), vault, login
}
```

Current `UnlockViewModel` published state related to enrollment:
```swift
@Published var showEnrollmentPrompt: Bool = false
@Published private(set) var enrollmentReason: EnrollmentReason = .firstTime
```

## Goals / Non-Goals

**Goals:**
- Icon badge overlay when Touch ID enabled; absent when disabled
- Subtitle copy reflects biometric state
- Remove the standalone Touch ID plain-text button
- Enrollment offer rendered inline on the unlock screen (no sheet)
- No ViewModel logic changes — only how state is surfaced to the view

**Non-Goals:**
- Changes to biometric Keychain logic, `AuthRepository`, or any Data/Domain layer
- Changing when or how Touch ID auto-prompts (already correct)
- Changing enrollment logic (when prompt fires, UserDefaults flags, re-enrollment)
- Accessibility or VoiceOver improvements beyond what the layout change naturally provides

## Decisions

### 1. Icon badge via `ZStack` overlay, not a composite asset

**Decision**: Render the app icon (`Image("AppIcon")` or the lock SF symbol) in a `ZStack` with a `touchid` SF Symbol badge offset to the bottom-trailing corner. Show the badge conditionally on `viewModel.biometricUnlockAvailable`.

**Rationale**: Keeps the asset count at zero. SF Symbol `touchid` matches the system's own Touch ID iconography. The overlay approach mirrors how macOS Passwords renders its badge — a small circular glyph over the app icon.

**Alternative rejected**: A single composite image asset per state. Requires Xcode asset work and doesn't adapt to tint changes.

---

### 2. Subtitle copy replaces the Touch ID button; Touch ID stays always-armed

**Decision**: Remove `biometricButton` from `UnlockView` entirely. Replace with a single subtitle line beneath the title:
- Biometrics enabled: `"Touch ID or enter the password for [email] to unlock."`
- Biometrics disabled: `"Enter the password for [email] to unlock."`

Touch ID evaluation is kept **always armed**: after any user cancellation, `unlockWithBiometrics()` immediately re-calls `triggerBiometricUnlockIfAvailable()` so the sensor is ready again without any user action. The user can place their finger at any time while the password field is simultaneously available.

The re-arm loop stops on:
- **Success** — screen transitions away
- **Lockout** (`LAError.biometryLockout`) — show error, stop; password is the only path
- **Invalidation** (`.biometryCurrentSet`) — show error, stop; re-enrollment offered after next password unlock
- **Item not found** — clear stale flag, stop; fall back to password silently
- **Password unlock** — screen transitions away, any in-flight biometric evaluation cancels cleanly

**Rationale**: This is how macOS Passwords behaves. The sensor is passive hardware — re-arming after cancellation costs nothing and means the user never has to think about "trying Touch ID again". The password field works in parallel; whichever path completes first wins.

**Alternative rejected**: One-shot prompt (original design). Requires user to consciously switch to Touch ID after cancellation — worse UX, inconsistent with platform convention.

---

### 3. Inline enrollment via `UnlockFlowState.enrollmentPrompt(reason:)`

**Decision**: Add a new case to `UnlockFlowState`:
```swift
case enrollmentPrompt(reason: EnrollmentReason)
```

In `checkEnrollmentOrSync()`, replace:
```swift
showEnrollmentPrompt = true
```
with:
```swift
flowState = .enrollmentPrompt(reason: ...)
```

`UnlockView` switches on `flowState` to render an inline enrollment view instead of the normal unlock form. `confirmEnrollBiometric()` and `dismissEnrollmentPrompt()` set `flowState = .loading` before proceeding to sync (same as today, just without the sheet dismiss).

Remove `showEnrollmentPrompt` and `enrollmentReason` published properties from `UnlockViewModel`.

**Rationale**: The sheet approach requires two separate pieces of state (`showEnrollmentPrompt` bool + `enrollmentReason` enum) that are always set together. `flowState` is already the authoritative state machine for this screen — enrollment is just another state in that machine. One source of truth, fewer published properties, easier to test.

**Equatable conformance**: `EnrollmentReason` already conforms to `Equatable`. The new `flowState` case will synthesize `Equatable` automatically.

**Alternative rejected**: Keep the `.sheet` but style it as a full-screen overlay. Still a modal; still breaks the "one screen" mental model.

---

### 4. `BiometricEnrollmentPromptView` deleted, content inlined

**Decision**: Delete `BiometricEnrollmentPromptView.swift`. Its content (icon, heading, body, two buttons) is extracted into a private `enrollmentView` computed property or `@ViewBuilder` func inside `UnlockView`.

**Rationale**: The view is ~90 lines, has no reuse outside `UnlockView`, and only exists because the sheet pattern required a standalone `View` conformance. Inlining it removes a file with no loss of clarity.

**`AccessibilityID.Unlock.enrollmentPrompt`**: Was used as the sheet's root identifier. Repurpose it as the identifier for the inline enrollment container `VStack`.

---

### 5. Password field always visible when `flowState == .unlock`

**Decision**: The password field is not hidden or collapsed when Touch ID is enabled. It is always present in the `.unlock` state, same as today. The icon badge + subtitle are the only additions.

**Rationale**: The reference design (Apple Passwords) shows a single password field regardless of biometric state. Users can type their password at any time without an extra interaction. This is the simplest layout — no conditional show/hide of the form.

## Risks / Trade-offs

**`UnlockFlowState.Equatable` with associated value** → `EnrollmentReason` is already `Equatable`; the compiler synthesises conformance for the new case automatically. No manual `==` implementation needed.

**Tests asserting `showEnrollmentPrompt == true`** → `UnlockViewModelBiometricTests` has one test (`testDismissEnrollmentPrompt_callsPerformSync`) that directly sets `sut.showEnrollmentPrompt = true` as test setup. This won't compile after the property is removed. That test must be restructured to drive the enrollment state through the real `unlock()` flow with the right `UserDefaults` preconditions. It is not a simple find-and-replace.

**`BiometricEnrollmentJourneyTests` element lookups** → Uses `app.sheets.firstMatch` (not the accessibility identifier). After the sheet is removed, these queries return nothing. Every occurrence must be replaced with `app.otherElements[AccessibilityID.Unlock.enrollmentPrompt].firstMatch`.

**`BiometricUnlockJourneyTests` button query** → `testBiometricAutoPrompt_firesOnUnlockScreen` queries `app.buttons["unlock.biometric"]`. That button is deleted by this change. The test must be updated to assert badge or subtitle presence instead.

**App icon asset**: `UnlockView` currently uses `Image(systemName: "lock.fill")` as the header icon, not the actual app icon. The badge overlay applies to whatever icon is used. If the actual `AppIcon` asset is preferred over the SF Symbol, that is a separate decision — this change works with either.
