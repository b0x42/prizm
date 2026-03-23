## Context

Masked fields (`MaskedFieldView`) currently require a click on the eye toggle to reveal, then another click to hide. The reveal state is tracked per-field in `MaskedFieldState.isRevealed` and resets when the selected item changes (FR-027). There is no keyboard-driven reveal mechanism.

macOS provides `NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)` to observe modifier key presses at the app level. SwiftUI does not natively expose a "modifier key held" binding, so an AppKit bridge is needed.

## Goals / Non-Goals

**Goals:**
- Let users peek at any masked field by holding the Option (⌥) key — zero clicks
- Release immediately re-masks — no residual revealed state
- Coexist with the existing click-to-toggle reveal without interference

**Non-Goals:**
- Configurable modifier key (hardcoded to Option)
- Peek while the app is in the background or locked
- Peek on custom hidden fields in edit mode (`MaskedEditFieldRow`)

## Decisions

1. **App-level `NSEvent` local monitor over per-view `onKeyPress`**
   SwiftUI's `onKeyPress` requires focus on the specific view and doesn't fire for bare modifier keys. A single `NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)` handler publishes an `@Observable` boolean consumed by any `MaskedFieldView` instance. This avoids duplicating monitors per field.

   *Alternative considered*: `CGEvent` tap — requires Accessibility permissions, rejected for UX friction.

2. **Separate "peek" state from persisted `isRevealed` toggle**
   The Option-key peek is a transient overlay: `displayValue` returns plaintext when *either* `isRevealed` is true *or* the Option key is held. Releasing the key does not flip `isRevealed`, so the click-toggle state is preserved.

3. **Single shared `OptionKeyMonitor` observable object**
   One instance created at app level and injected via SwiftUI environment. Avoids multiple monitors and ensures consistent state across all masked fields.

## Risks / Trade-offs

- **[Risk] Monitor not removed on deinit** → `OptionKeyMonitor` removes the monitor in `deinit`/`cancel` to prevent leaks.
- **[Risk] Option key held across item navigation reveals new item's password** → Acceptable; the user is explicitly holding the key. Consistent with the "peek while held" mental model.
- **[Trade-off] AppKit dependency in Presentation layer** → Already present (clipboard, window management). Contained to a single small utility.
