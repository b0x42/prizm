## Why

Delete buttons across the app (toolbar, context menus, confirmation alerts) rely on SwiftUI's `.destructive` button role for styling, which renders as the system default. The text should be explicitly red to provide a stronger visual safety cue that the action is irreversible or significant.

## What Changes

- Apply explicit `.foregroundStyle(.red)` to delete button labels in the detail toolbar, list context menus, and trash context menus so the text is always red regardless of system theme or platform defaults.

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `vault-item-delete`: Delete button text must render in red across all delete actions (toolbar, context menu, trash).

## Impact

- `VaultBrowserView.swift` — toolbar Delete and Delete Permanently buttons
- `ItemListView.swift` — context menu Delete button
- `TrashView.swift` — context menu Delete Permanently button
- No API, dependency, or architectural changes.
