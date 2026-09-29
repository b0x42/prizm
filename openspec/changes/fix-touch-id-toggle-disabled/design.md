# Design

## Context

`BiometricUnlockToggle` (`Prizm/Presentation/Settings/BiometricUnlockToggle.swift`) owns three `@State` flags: `isEnabled`, `isProcessing`, `showVaultLockedHint`. The toggle is `.disabled(isProcessing || showVaultLockedHint)`. `showVaultLockedHint` is set `true` in the `catch` branch of `toggleBiometric(enabled:)` when `enableBiometricUnlock()` throws `AuthError.biometricUnavailable`, and is only ever cleared on a subsequent *successful* toggle call (line 49). Since `SettingsView` lives inside a SwiftUI `Settings { }` scene (`PrizmApp.swift:127-129`) that macOS keeps alive across window close/reopen, this `@State` persists for the app session — so once the flag latches, the toggle is stuck disabled with no way for the user to trigger the success path that would clear it. See proposal.md - Why.

Separately, `LAContext.canEvaluatePolicy` is called at three sites (`SettingsView.swift:13`, `AuthRepositoryImpl.swift:441`, `:448`) always with `error: nil`, discarding the `NSError` that would explain *why* biometrics are considered unavailable.

## Goals / Non-Goals

**Goals:**
- Toggle's disabled state tracks live vault-lock status, not a one-shot latch.
- A failed `canEvaluatePolicy` check is diagnosable via `os.Logger` instead of silently swallowed.
- The re-enable behavior is unit-testable without requiring XCUITest app-launch infrastructure (investigation found `--ui-testing`/`--inject-session`/`--mock-biometrics` are referenced only in test files today and parsed nowhere in app code — building that plumbing is out of scope for this fix).

**Non-Goals:**
- Not reworking `AuthRepository`'s biometric enable/disable flow or error taxonomy.
- Not adding a general-purpose loading/error state framework to Settings — this fix stays local to the one control.
- Concurrent-request serialization (added to the `biometric-unlock` spec during spec review) is a pre-existing gap unrelated to #67; not implemented by this change unless it surfaces during implementation.

## Decisions

**Clear `showVaultLockedHint` on a `vaultDidUnlock` NotificationCenter notification instead of latching on catch.**
Investigation confirmed no existing live vault-lock signal reaches the Settings scene: `RootViewModel.screen` (`PrizmApp.swift:247`) is the only live-updating lock-state publisher, but it is never injected into the Settings scene (`PrizmApp.swift:127-129` passes only `container.authRepository`, and the Settings `WindowGroup` does not inherit the main window's environment, per the comment at `PrizmApp.swift:125-126`). `AuthRepository` exposes no lock-state publisher either — only throwing calls.

Add a `Notification.Name.vaultDidUnlock` posted by `AuthRepositoryImpl` immediately after any successful vault unlock (password or biometric). Define it in `Prizm/App/Config.swift`, next to the existing `.vaultDidLock` (`Config.swift:16`) — same file, same convention, not a new pattern. `BiometricUnlockToggle` subscribes and clears `showVaultLockedHint = false`, re-enabling the toggle. This mirrors `lockVault()` (`AuthRepositoryImpl.swift:429-436`), which already posts `.vaultDidLock` on the main thread after locking, observed by `ItemEditViewModel.subscribeToVaultLock()` (`ItemEditViewModel.swift:185-197`) — `.vaultDidUnlock` is the direct counterpart of an already-established pattern.

Alternatives considered:
- *Inject `RootViewModel` into the Settings scene.* Rejected — requires wiring environment into a scene that currently deliberately doesn't inherit it (`PrizmApp.swift:125-126`), a broader change than this bug fix warrants (see Non-Goals).
- *Add a new lock-state publisher to `AuthRepository`.* Rejected — a larger Domain-protocol surface change for a small, localized bug fix; NotificationCenter achieves the same observable outcome without touching the protocol.
- *Reset `showVaultLockedHint = false` in `.onAppear`/`.onDisappear` of the Settings window.* Rejected — doesn't cover the case where the user unlocks the vault while the Settings window stays open (spec scenario "Biometric toggle re-enables after the vault is unlocked" requires this without closing the window).

**Extract the toggle's state (`isEnabled`, `isProcessing`, `showVaultLockedHint`) out of `BiometricUnlockToggle`'s `@State` into a small `@MainActor @Observable BiometricUnlockToggleViewModel`** owned by the view, with a `toggleBiometric(enabled:)` method and the `.vaultDidUnlock` subscription living on the view model instead of the View. This makes the fix directly unit-testable (instantiate the view model with a mock `AuthRepository`, call `toggleBiometric`, post `.vaultDidUnlock`, assert `showVaultLockedHint`) without XCUITest app-launch plumbing that doesn't exist yet (see Goals). Stays local to this one control — not a general Settings state framework (see Non-Goals).

**Log discarded `NSError` at the three `canEvaluatePolicy` call sites via `os.Logger` at `.error` level**, subsystem `com.prizm`, matching the existing pattern in `BiometricKeychainServiceImpl`. No behavior change to the boolean return value — only adds observability per the Constitution's Observability principle (no silent failures).

## Risks / Trade-offs

- [Wiring the toggle to live vault-lock state could introduce a new observation path in a Presentation-layer view that previously had none] → Reuse whatever lock-state source already drives the unlock screen transition (Domain-layer use case output) rather than inventing a new one; keep the toggle a passive observer, not a new source of truth.
- [Logging biometric-availability failures could risk leaking sensitive detail] → Log only the `NSError` domain/code from `LAContext`, never any biometric or vault data; consistent with "Secrets MUST NOT appear in log output."
