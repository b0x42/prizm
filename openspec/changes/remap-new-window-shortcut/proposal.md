## Why

macOS assigns ⌘N to "New Window" by default in `WindowGroup`. Macwarden uses ⌘N for "New Item" in the vault browser. Both compete for the same shortcut — the system command wins when focus is outside the toolbar, opening a duplicate window instead of the item picker. Remapping "New Window" to ⌥⌘N eliminates the conflict.

## What Changes

- Override the default "New Window" command in `MacwardenApp.commands` to use ⌥⌘N instead of ⌘N
- ⌘N remains exclusively for "New Item" in the vault browser

## Capabilities

### New Capabilities

*(none)*

### Modified Capabilities

- `vault-item-create`: ⌘N is no longer intercepted by the system "New Window" command

## Impact

- `MacwardenApp.swift` — add a `CommandGroup(replacing: .newItem)` to remap the shortcut
