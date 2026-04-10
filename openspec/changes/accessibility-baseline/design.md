## Context

Prizm's Presentation layer uses `accessibilityIdentifier` extensively (81 instances across 19 files) for UI testing, but has zero VoiceOver-facing modifiers (`accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, `accessibilityAddTraits`). SwiftUI provides default VoiceOver behaviour for standard controls (buttons with text labels, toggles, text fields), but icon-only buttons — which Prizm uses heavily — are announced as "button" with no description. The app has 34 `Image(systemName:)` usages across 20 Presentation files, many inside buttons.

## Goals / Non-Goals

**Goals:**
- Every interactive control is usable via VoiceOver with a meaningful spoken description
- Stateful controls announce their current value
- Section structure is conveyed via heading traits
- Decorative images are hidden from the accessibility tree
- Error states and status changes are announced
- An EN 301 549 / WCAG 2.1 AA conformance statement documents current support

**Non-Goals:**
- Colour contrast audit and fixes (Tier 2 — separate change)
- Keyboard-only navigation improvements beyond what SwiftUI provides by default (Tier 2)
- Keyboard alternatives for drag-and-drop folder operations (Tier 2)
- Reduced Motion support (Tier 3)
- Switch Control testing (Tier 3)
- Full VoiceOver end-to-end test automation (future)

## Decisions

### Decision 1: Use `accessibilityLabel` on icon-only buttons, not `Label` replacement

Icon-only buttons use `Image(systemName:)` directly. Rather than refactoring to `Label("text", systemImage:)` (which would change visual layout), add `.accessibilityLabel("text")` to the enclosing `Button`. This is additive-only and cannot break existing UI.

Alternative considered: Replacing `Image(systemName:)` with `Label` and hiding the text via `.labelStyle(.iconOnly)`. Rejected because it changes the view hierarchy and could affect layout in toolbars and compact spaces.

### Decision 2: `accessibilityValue` for binary state controls

The favorite star button and biometric toggle need `.accessibilityValue()` to announce their current state. For the star: `"Favorited"` / `"Not favorited"`. For the biometric toggle: SwiftUI `Toggle` already announces on/off, so no additional work needed — only the star button requires explicit value.

The password generator mode picker (`Picker`) also announces its selection natively. No additional work needed.

### Decision 3: `accessibilityAddTraits(.isHeader)` on `DetailSectionCard` headers

The detail view uses `CardBackground` with section headers ("Credentials", "Websites", "Notes", "Attachments", "Custom Fields"). Adding `.isHeader` trait to these labels lets VoiceOver users navigate by heading (VO+Command+H), matching standard macOS document navigation.

### Decision 4: `accessibilityHidden(true)` on decorative images

Favicons in `FaviconView` are decorative when the item name is already in the accessibility tree (the row label announces the item name). The large keyhole/shield icons on Login, Unlock, and TOTP screens are decorative. Mark these hidden.

### Decision 5: VoiceOver announcements for transient state changes

Error banners (sync error, save error, action error) and sync status changes should post `AccessibilityNotification.Announcement` so VoiceOver users are informed without needing to navigate to the banner. Use `.announcement` on the text content when the banner appears.

### Decision 6: VPAT-style conformance statement in `ACCESSIBILITY.md`

The conformance statement follows the VPAT 2.4 Rev format (Voluntary Product Accessibility Template), mapping EN 301 549 Chapter 11 criteria (which references WCAG 2.1) to Prizm's current support level. Each criterion gets a status: Supports / Partially Supports / Does Not Support / Not Applicable, with remarks explaining the current state.

This lives at the repo root as `ACCESSIBILITY.md`, linked from `README.md`.

## Risks / Trade-offs

- **Label accuracy**: Accessibility labels must match the visual intent. A mislabelled button is worse than no label. Mitigation: labels are derived from existing `.help()` tooltip text where available, ensuring consistency.
- **Maintenance burden**: Every new icon-only button must get a label. Mitigation: add a note to `CONTRIBUTING.md` or `DEVELOPMENT.md` requiring accessibility labels on all interactive controls.
- **Conformance statement accuracy**: The VPAT is a self-assessment, not a third-party audit. Mitigation: document honestly — mark criteria as "Partially Supports" or "Does Not Support" where gaps exist (contrast, keyboard alternatives for drag-and-drop).
