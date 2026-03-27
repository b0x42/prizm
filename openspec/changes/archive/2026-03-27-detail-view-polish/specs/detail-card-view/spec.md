## MODIFIED Requirements

### Requirement: CardBackground ViewModifier (MODIFIED)
The system SHALL provide a `CardBackground` `ViewModifier` that applies a `#FAFAFA` (light) / `#2C2C2C` (dark) background via the `CardBackground` color asset, rounded corners (radius 10), and a subtle 0.5pt border at 8% opacity. The modifier SHALL NOT apply a drop shadow. A `.cardBackground()` `View` extension SHALL expose it ergonomically.

#### Scenario: Card is visually distinct in light mode
- **WHEN** the detail pane is displayed in light mode
- **THEN** each card SHALL render with a `#FAFAFA` background, rounded corners (radius 10), a subtle border, and no drop shadow

#### Scenario: Card is visually distinct in dark mode
- **WHEN** the detail pane is displayed in dark mode
- **THEN** each card SHALL render with a `#2C2C2C` background, rounded corners (radius 10), a subtle border, and no drop shadow

---

### Requirement: DetailSectionCard header style (MODIFIED)
Section headers ("Credentials", "Websites", etc.) SHALL use `.headline` font (13pt semibold) with default text color. Spacing between the header and the card content SHALL be 12pt.

#### Scenario: Section header renders with headline style
- **WHEN** a `DetailSectionCard` is displayed with a non-empty title
- **THEN** the title SHALL render in `.headline` font with default (primary) text color

---

### Requirement: FieldRowView uses horizontal layout for all field types (MODIFIED)
The system SHALL display field rows with the label on the left and the value on the right. Multi-line fields (notes) SHALL use a stacked layout. Masked fields SHALL display the label on the left with the masked value and eye toggle on the right. All field values SHALL use monospaced font. All field labels SHALL use default (primary) text color.

#### Scenario: Single-line field renders horizontally
- **WHEN** a `FieldRowView` is displayed with `isMultiLine` false (default) and `isMasked` false
- **THEN** the label SHALL appear on the left and the value on the right, on the same line

#### Scenario: Multi-line field renders stacked
- **WHEN** a `FieldRowView` is displayed with `isMultiLine` true
- **THEN** the label SHALL appear above the value in a vertical stack

#### Scenario: Masked field renders horizontally
- **WHEN** a `FieldRowView` is displayed with `isMasked` true
- **THEN** the label SHALL appear on the left, and the masked value with eye toggle SHALL appear on the right

---

### Requirement: Copy on hover with feedback (MODIFIED)
The system SHALL show a "COPY" label (displayed uppercase via `.textCase(.uppercase)`) when the user hovers over a field row. Clicking anywhere on a hovered row SHALL copy the field value. After copying, the label SHALL change to "COPIED" for 0.8 seconds. The COPY label SHALL use `.headline` font and the system accent color. The COPY label SHALL appear to the left of the field value.

#### Scenario: COPY appears on hover
- **WHEN** the user hovers over a field row with a non-empty value
- **THEN** a "COPY" label SHALL appear to the left of the value

#### Scenario: COPY hidden when not hovered
- **WHEN** the user is not hovering over a field row
- **THEN** no COPY label SHALL be visible

#### Scenario: Click row copies value
- **WHEN** the user clicks anywhere on a hovered field row
- **THEN** the field value SHALL be copied to the clipboard

#### Scenario: COPIED feedback after copy
- **GIVEN** the user has clicked a field row to copy
- **THEN** the label SHALL change to "COPIED" for 0.8 seconds, then revert to "COPY"

---

### Requirement: Open-in-browser icon always visible (MODIFIED)
For field rows with a URL, the system SHALL always display an open-in-browser icon (`arrow.up.right.square`) at the trailing edge of the row. The icon SHALL use the system accent color, `.medium` image scale, and `.semibold` font weight.

#### Scenario: Browser icon visible on URL fields
- **WHEN** a `FieldRowView` has a non-nil `url`
- **THEN** the open-in-browser icon SHALL be visible at all times (not only on hover)

---

### Requirement: Eye toggle icon style (MODIFIED)
The reveal/hide eye icon on masked fields SHALL use the system accent color and `.medium` image scale.

#### Scenario: Eye icon uses accent color
- **WHEN** a masked field is displayed
- **THEN** the eye toggle icon SHALL use the system accent color and medium size

---

### Requirement: Duplicate labels removed from card sections (MODIFIED)
When a `DetailSectionCard` provides a section header (e.g. "Notes", "Custom Fields"), the field rows inside SHALL NOT render a redundant label matching the section header.

#### Scenario: Notes card has no inner label
- **WHEN** a Notes section is displayed inside a `DetailSectionCard("Notes")`
- **THEN** only the note text SHALL appear inside the card, with no "Notes" label

#### Scenario: Custom Fields card has no inner header
- **WHEN** a Custom Fields section is displayed inside a `DetailSectionCard("Custom Fields")`
- **THEN** no duplicate "Custom Fields" header SHALL appear inside the card

---

### Requirement: Metadata footer displays created and updated dates (MODIFIED)
The system SHALL display "Updated" and "Created" dates below the last card section, left-aligned, stacked vertically, using default field text style with secondary (gray) color. Dates SHALL use `dd.MM.yyyy` format. Labels and dates SHALL be column-aligned.

#### Scenario: Dates render below cards
- **WHEN** an item detail is displayed
- **THEN** "Updated: dd.MM.yyyy" and "Created: dd.MM.yyyy" SHALL appear below the last card, left-aligned, in gray text
