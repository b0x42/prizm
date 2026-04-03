## Context

SwiftUI's `WindowGroup` automatically provides a "New Window" menu item bound to ⌘N. Prizm's vault browser binds ⌘N to "New Item" via `.keyboardShortcut("n", modifiers: .command)` on the toolbar button. When focus is outside the toolbar, the system command wins and opens a duplicate window.

## Goals / Non-Goals

**Goals:**
- Remap "New Window" to ⌥⌘N so ⌘N is exclusively "New Item"

**Non-Goals:**
- Disabling multi-window entirely
- Changing the "New Item" shortcut

## Decisions

### Decision 1: Use `CommandGroup(replacing: .newItem)` with ⌥⌘N

**Chosen:** Replace the default "New Window" command group with a custom button that uses `.keyboardShortcut("n", modifiers: [.command, .option])`.

**Rationale:** This is the standard SwiftUI mechanism for overriding built-in menu commands. It keeps "New Window" available for users who want it, just on a less prominent shortcut.

## Risks / Trade-offs

- Users accustomed to ⌘N for new windows in other apps may be surprised. This is acceptable — password managers universally use ⌘N for new items (1Password, Keychain Access).
