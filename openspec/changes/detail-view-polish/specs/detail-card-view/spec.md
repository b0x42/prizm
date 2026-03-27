## MODIFIED Requirements

### Requirement: CardBackground ViewModifier (MODIFIED)
The system SHALL provide a `CardBackground` `ViewModifier` that applies a white/dark-gray background (`Color("CardBackground")`) and rounded corners (radius 10) to any view. The modifier SHALL NOT apply a drop shadow. A `.cardBackground()` `View` extension SHALL expose it ergonomically.

#### Scenario: Card is visually distinct in light mode
- **WHEN** the detail pane is displayed in light mode
- **THEN** each card SHALL render with a white background and rounded corners (radius 10), with no drop shadow

#### Scenario: Card is visually distinct in dark mode
- **WHEN** the detail pane is displayed in dark mode
- **THEN** each card SHALL render with a dark gray background and rounded corners (radius 10), with no drop shadow

---

### Requirement: FieldRowView uses horizontal layout for single-line fields (MODIFIED)
The system SHALL display single-line field rows with the label on the left and the value on the right. Multi-line fields (notes, freeform text) SHALL use a stacked layout with the label above the value.

#### Scenario: Single-line field renders horizontally
- **WHEN** a `FieldRowView` is displayed with `isMultiLine` set to false (default)
- **THEN** the label SHALL appear on the left and the value SHALL appear on the right, on the same line

#### Scenario: Multi-line field renders stacked
- **WHEN** a `FieldRowView` is displayed with `isMultiLine` set to true
- **THEN** the label SHALL appear above the value in a vertical stack

#### Scenario: Masked fields remain unchanged
- **WHEN** a `FieldRowView` is displayed with `isMasked` set to true
- **THEN** the `MaskedFieldView` layout SHALL be used regardless of `isMultiLine`
