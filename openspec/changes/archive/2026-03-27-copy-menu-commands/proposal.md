## Why

Users need to copy credentials quickly without navigating into the detail view and hovering over individual fields. 1Password provides Copy Username/Password/Code/Website in the menu bar with keyboard shortcuts — Prizm should match this for power users.

## What Changes

- Add Copy Username (⇧⌘C), Copy Password (⌥⌘C), Copy Code (⌃⌘C), Copy Website (⌥⇧⌘C) to the Item menu
- Commands are disabled when the selected item doesn't have the corresponding field
- Uses existing clipboard copy with 30s auto-clear

## Capabilities

### New Capabilities

- `copy-menu-commands`: Keyboard-driven copy of Login fields from the menu bar

### Modified Capabilities

*(none)*

## Impact

- `PrizmApp.swift` — new menu commands + helper methods on `RootViewModel`
