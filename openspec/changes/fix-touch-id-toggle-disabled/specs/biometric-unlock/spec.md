# Spec Delta

<!-- Note: the requirement below already matches the live spec at
     openspec/specs/biometric-unlock/spec.md — it was applied directly during
     a pre-implementation spec-quality review (/opsx-review-spec) rather than
     through this change's own artifact flow. Archiving this change is a
     documentation no-op for this file; included here for traceability of
     what this change is responsible for. -->

## ADDED Requirements

### Requirement: Biometric availability check failures are logged
When the platform biometric availability check (`LAContext.canEvaluatePolicy`) fails, the system SHALL log the underlying error via `os.Logger` at `.error` level instead of discarding it, so the reason biometrics are considered unavailable is diagnosable.

#### Scenario: Biometric availability check fails transiently
- **GIVEN** the platform biometric availability check (`LAContext.canEvaluatePolicy`) returns an error other than a missing enrollment (e.g. a transient `LAError` from the biometry daemon)
- **WHEN** the check is performed
- **THEN** the system SHALL log the underlying error via `os.Logger` at `.error` level
- **AND** SHALL treat biometrics as unavailable for that check without crashing or silently discarding the failure reason
