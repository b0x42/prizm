## Purpose

Defines the macOS Settings window: how it opens and what controls live in it. Biometric
toggle presence and lock-state gating are covered here; the toggle's label, biometry-type
detection, and enable/disable behavior are owned by `biometric-unlock`.

## Requirements

### Requirement: Settings window opens via ⌘, and gear toolbar button
The system SHALL provide a macOS Settings window using the SwiftUI `Settings` scene, accessible via ⌘, (standard macOS keyboard shortcut) and via a gear icon button in the vault browser toolbar placed next to the search field. The Settings window SHALL open as a separate native macOS window.

#### Scenario: Settings opens via keyboard shortcut
- **WHEN** the user presses ⌘, while the vault browser is visible
- **THEN** the Settings window SHALL open

#### Scenario: Settings opens via toolbar button
- **GIVEN** the vault browser is visible
- **WHEN** the user clicks the gear icon button in the toolbar
- **THEN** the Settings window SHALL open

#### Scenario: Gear button is visible in the vault browser toolbar
- **GIVEN** the vault is unlocked and the vault browser is shown
- **WHEN** the detail column toolbar is rendered
- **THEN** a gear icon button SHALL be visible next to the search field

---

### Requirement: Settings window contains the biometric unlock toggle
The Settings window SHALL display a Security section containing the biometric unlock toggle. The toggle SHALL be visible only when the device supports biometric authentication. The toggle's label and biometry-type detection (Touch ID vs Face ID) are owned by `biometric-unlock`; this requirement only covers the control's presence and visibility in Settings.

#### Scenario: Biometric toggle is visible when device supports biometrics
- **GIVEN** the device has Touch ID or Face ID available
- **WHEN** the user opens the Settings window
- **THEN** a Security section SHALL be visible containing a "Touch ID unlock" (or "Face ID unlock") toggle

#### Scenario: Biometric toggle reflects current enabled state
- **GIVEN** the Settings window is open
- **WHEN** biometric unlock is enabled
- **THEN** the toggle SHALL be on; when disabled the toggle SHALL be off

#### Scenario: Biometric toggle is hidden when device has no biometrics
- **GIVEN** the device does not support biometric authentication
- **WHEN** the user opens the Settings window
- **THEN** the Security section and biometric toggle SHALL NOT be shown

---

### Requirement: Biometric unlock toggle is disabled only while the vault is actually locked
The toggle SHALL be disabled while the vault is locked (enabling biometric unlock requires the vault key to be in memory) or while an enable/disable request is in flight, and SHALL become interactable again as soon as neither condition holds. The disabled state SHALL NOT persist past the condition that caused it — in particular, a toggle attempt that fails because the vault was locked SHALL NOT leave the control permanently disabled once the vault is subsequently unlocked.

#### Scenario: Biometric toggle is disabled when vault is locked
- **GIVEN** the vault is currently locked
- **WHEN** the user opens the Settings window
- **THEN** the biometric toggle SHALL be visible but disabled with a note: "Unlock your vault to change this setting"

#### Scenario: Biometric toggle re-enables after the vault is unlocked
- **GIVEN** the toggle is disabled with the "Unlock your vault to change this setting" note, because a previous toggle attempt failed while the vault was locked
- **WHEN** the user subsequently unlocks the vault (via password or biometrics) while the Settings window remains open
- **THEN** the toggle SHALL become enabled and the note SHALL be removed, without requiring the Settings window to be closed and reopened
