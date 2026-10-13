# Spec Delta

<!-- Note: the requirement below already matches the live spec at
     openspec/specs/settings-screen/spec.md — it was applied directly during
     a pre-implementation spec-quality review (/opsx-review-spec) rather than
     through this change's own artifact flow. Archiving this change is a
     documentation no-op for this file; included here for traceability of
     what this change is responsible for. -->

## MODIFIED Requirements

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
