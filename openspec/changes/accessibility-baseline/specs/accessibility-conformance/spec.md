## ADDED Requirements

### Requirement: Accessibility conformance statement SHALL exist at repo root
The project SHALL include an `ACCESSIBILITY.md` file at the repository root documenting the current accessibility conformance level against EN 301 549 Chapter 11 (which maps WCAG 2.1 criteria to native software).

#### Scenario: ACCESSIBILITY.md exists
- **WHEN** a user or auditor visits the repository
- **THEN** an `ACCESSIBILITY.md` file SHALL be present at the repository root

#### Scenario: Document follows VPAT 2.4 Rev format
- **WHEN** a user reads `ACCESSIBILITY.md`
- **THEN** the document SHALL contain a table mapping EN 301 549 / WCAG 2.1 AA criteria to conformance levels using the standard VPAT statuses: "Supports", "Partially Supports", "Does Not Support", "Not Applicable"

#### Scenario: Each criterion includes remarks
- **WHEN** a criterion is listed in the conformance table
- **THEN** it SHALL include a "Remarks" column explaining the current support level with specific details about what works and what does not

---

### Requirement: Conformance statement SHALL be linked from README
The `README.md` SHALL link to `ACCESSIBILITY.md` so users can discover the accessibility information.

#### Scenario: README contains accessibility link
- **WHEN** a user reads the README
- **THEN** a link to `ACCESSIBILITY.md` SHALL be present in an appropriate section

---

### Requirement: Conformance statement SHALL document known gaps honestly
The conformance statement SHALL not overstate compliance. Criteria that are not fully met SHALL be marked "Partially Supports" or "Does Not Support" with clear remarks about what is missing.

#### Scenario: Contrast criteria marked as not audited
- **WHEN** the conformance statement lists WCAG 1.4.3 (Contrast Minimum) and 1.4.11 (Non-text Contrast)
- **THEN** the status SHALL be "Partially Supports" with a remark that a formal contrast audit has not been performed

#### Scenario: Keyboard alternative for drag-and-drop marked as gap
- **WHEN** the conformance statement lists WCAG 2.1.1 (Keyboard)
- **THEN** the status SHALL note that drag-and-drop folder operations do not have a keyboard-only alternative
