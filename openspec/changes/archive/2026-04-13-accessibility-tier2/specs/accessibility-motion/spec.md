## ADDED Requirements

### Requirement: Animations SHALL be suppressed when Reduce Motion is enabled
When the macOS "Reduce motion" accessibility setting is enabled, all `withAnimation` and `.animation` calls SHALL apply state changes immediately without animation.

#### Scenario: Hover transitions are instant with Reduce Motion
- **GIVEN** the user has enabled "Reduce motion" in System Settings → Accessibility → Display
- **WHEN** the user hovers over a field row or attachment row
- **THEN** the hover state SHALL change immediately without an animated transition

#### Scenario: Copy feedback is instant with Reduce Motion
- **GIVEN** the user has enabled "Reduce motion"
- **WHEN** the user copies a field value
- **THEN** the "copied" feedback SHALL appear and disappear immediately without animation

#### Scenario: Match type toggle is instant with Reduce Motion
- **GIVEN** the user has enabled "Reduce motion"
- **WHEN** the user toggles the match type settings on a URI row
- **THEN** the match type picker SHALL appear immediately without animation

#### Scenario: Animations play normally without Reduce Motion
- **GIVEN** the user has NOT enabled "Reduce motion"
- **WHEN** any animated transition occurs
- **THEN** the animation SHALL play as designed
