## 1. Domain & DesignSystem

- [x] 1.1 Add `displayName: String` computed property to `SidebarSelection`
- [x] 1.2 Add `Typography.columnHeader` token to `DesignSystem.swift`

## 2. Window Chrome

- [x] 2.1 Change `.windowStyle(.titleBar)` to `.windowStyle(.hiddenTitleBar)` in `PrizmApp.swift`
- [x] 2.2 Remove `.windowToolbarStyle(.unified)` from the `WindowGroup` scene

## 3. VaultBrowserView Rewrite

- [x] 3.1 Remove custom `listColumnHeader` subview
- [x] 3.2 Remove custom `detailColumnHeader` subview
- [x] 3.3 Remove `NativeSearchField` usage; replace with `.searchable(text:placement:prompt:)` using `.sidebar` placement
- [x] 3.4 Add `+` button in content pane via `ToolbarItem(placement: .primaryAction)` with `Menu` for item type selection
- [x] 3.5 Conditionally remove `+` button when Trash is selected (not hidden — removed from view tree so ⌘N is disabled)
- [x] 3.6 Add Edit button in detail pane via `ToolbarItem(placement: .primaryAction)` with ⌘E shortcut and `AccessibilityID.Edit.editButton`
- [x] 3.7 Add Delete button in detail pane via `ToolbarItem(placement: .destructiveAction)`
- [x] 3.8 Add Restore and Delete Permanently buttons for trashed items, replacing Edit/Delete
- [x] 3.9 Move `showSoftDeleteAlert` and `showPermanentDeleteAlert` state to `VaultBrowserView`
- [x] 3.10 Clear search query via `.onChange` when sidebar selection changes to Trash
- [x] 3.11 Remove `ignoresSafeArea` / `toolbarBackgroundVisibility` hacks

## 4. ItemDetailView Cleanup

- [x] 4.1 Remove `.toolbar {}` block from `ItemDetailView`
- [x] 4.2 Remove `showSoftDeleteAlert` and `showPermanentDeleteAlert` `@State` vars from `ItemDetailView`

## 5. Delete Unused Files

- [x] 5.1 Delete `NativeSearchField.swift`
- [x] 5.2 Delete `DetailColumnHeaderTests.swift`
- [x] 5.3 Delete `ListColumnHeaderTests.swift`
- [x] 5.4 Remove `NativeSearchField.swift` reference from `.pbxproj`
