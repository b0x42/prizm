## Why

Prizm has zero `accessibilityLabel`, `accessibilityHint`, or `accessibilityValue` modifiers anywhere in the Presentation layer. VoiceOver users hear "button" for every icon-only control with no description of what it does. Stateful controls (favorite toggle, biometric toggle) don't announce their current value. There is no accessibility conformance statement. This is the baseline pass to make Prizm usable with assistive technology and document conformance against EN 301 549 / WCAG 2.1 AA.

## What Changes

- **New**: `accessibilityLabel` on all icon-only buttons across every view (gear, star, copy, reveal, open, delete, plus, refresh, eye, xmark — ~34 instances across 20 files)
- **New**: `accessibilityHint` on non-obvious actions (copy, reveal, open URL, drag-and-drop targets)
- **New**: `accessibilityValue` on stateful controls (favorite toggle, biometric toggle, password generator mode picker)
- **New**: `accessibilityAddTraits(.isHeader)` on section titles in detail view card headers
- **New**: `accessibilityHidden(true)` on decorative images (favicons when item name is already announced, screen icons on login/unlock)
- **New**: VoiceOver announcements for error banners and sync status changes via `AccessibilityNotification.Announcement`
- **New**: `ACCESSIBILITY.md` — EN 301 549 / WCAG 2.1 AA conformance statement (VPAT format) documenting current support level per criterion

## Capabilities

### New Capabilities

- `voiceover-labels`: Accessibility labels, hints, values, and traits across all Presentation layer views
- `accessibility-conformance`: EN 301 549 / WCAG 2.1 AA conformance statement document

### Modified Capabilities

## Impact

- **Presentation layer only**: All changes are SwiftUI modifier additions — no Data or Domain layer changes
- **20 view files** gain accessibility modifiers (identified via `Image(systemName:)` audit)
- **AccessibilityIdentifiers.swift** unchanged — existing identifiers are for UI testing, not VoiceOver
- **No new dependencies** — all APIs are built into SwiftUI (`accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, `accessibilityAddTraits`, `accessibilityHidden`, `AccessibilityNotification`)
- **New root-level doc**: `ACCESSIBILITY.md`
