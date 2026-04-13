## ADDED Requirements

### Requirement: Background tint colours SHALL meet WCAG non-text contrast ratio
All custom `Color.opacity()` values used as background tints on banners, borders, and interactive indicators SHALL produce a minimum 3:1 contrast ratio against the adjacent background in both light and dark mode.

#### Scenario: Sync error banner background meets contrast
- **WHEN** a sync error banner is displayed
- **THEN** the yellow background tint SHALL have a minimum 3:1 contrast ratio against the content column background

#### Scenario: Card border meets contrast
- **WHEN** a detail section card is displayed
- **THEN** the border stroke SHALL be visible with a minimum 3:1 contrast ratio against the card and window backgrounds

#### Scenario: Trash banner background meets contrast
- **WHEN** a trashed item is selected and the trash banner is displayed
- **THEN** the secondary background tint SHALL have a minimum 3:1 contrast ratio against the detail pane background

#### Scenario: Error banner backgrounds meet contrast
- **WHEN** an error banner is displayed in the edit form or attachment confirm sheet
- **THEN** the red background tint SHALL have a minimum 3:1 contrast ratio against the surrounding background

---

### Requirement: Increase Contrast preference SHALL raise opacity values
When the macOS "Increase contrast" accessibility setting is enabled, all custom background tint opacity values SHALL be increased to provide stronger visual distinction.

#### Scenario: Increase Contrast raises banner opacity
- **GIVEN** the user has enabled "Increase contrast" in System Settings → Accessibility → Display
- **WHEN** a sync error banner is displayed
- **THEN** the background tint opacity SHALL be higher than the default value

#### Scenario: Increase Contrast raises card border opacity
- **GIVEN** the user has enabled "Increase contrast"
- **WHEN** a detail section card is displayed
- **THEN** the border stroke opacity SHALL be higher than the default value
