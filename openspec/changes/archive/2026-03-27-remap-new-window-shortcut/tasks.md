## 1. Remap New Window shortcut

- [x] 1.1 Add `CommandGroup(replacing: .newItem)` in `PrizmApp.commands` with a "New Window" button using `.keyboardShortcut("n", modifiers: [.command, .option])` that calls `openWindow(id:)`
- [x] 1.2 Update the help text on the New Item toolbar button from `"New Item (⌘N)"` to reflect that ⌘N now works globally

## 2. Documentation

- [x] 2.1 Add ⌥⌘N (New Window) to the keyboard shortcuts table in README.md
