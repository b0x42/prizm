## 1. Copy Menu Commands

- [x] 1.1 Add `CopyableField` enum to `RootViewModel` with cases `username`, `password`, `totp`, `website`
- [x] 1.2 Add `copySelectedField(_:)` and `selectedFieldAvailable(_:)` methods to `RootViewModel`
- [x] 1.3 Add Copy Username (⇧⌘C), Copy Password (⌥⌘C), Copy Code (⌃⌘C), Copy Website (⌥⇧⌘C) to Item `CommandMenu`
- [x] 1.4 Disable each command when the corresponding field is unavailable
