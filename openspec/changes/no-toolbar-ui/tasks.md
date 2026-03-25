## 1. Domain & DesignSystem

- [x] 1.1 Add `displayName: String` computed property to `SidebarSelection` in `Domain/Entities/`; return "All Items", "Favorites", the underlying `ItemType.displayName` for `.type`, and "Trash" — this property is pure Swift with no imports
- [x] 1.2 Add `Typography.columnHeader: Font = .headline` token to `DesignSystem.swift` with comment: "Bold category title in the list column header — smaller than pageTitle, heavier than listTitle"

## 2. Window Chrome

- [x] 2.1 In `MacwardenApp.swift`, change `.windowStyle(.titleBar)` to `.windowStyle(.hiddenTitleBar)`
- [x] 2.2 Remove `.windowToolbarStyle(.unified)` from the `WindowGroup` scene
- [ ] 2.3 Visually verify traffic lights float correctly over the sidebar with no visible title bar chrome; confirm `NavigationSplitView` safe area insets prevent content from underlapping the buttons

## 3. List Column Header — tests first

- [x] 3.1 Write failing UI test: list column header title matches the active sidebar selection
- [x] 3.2 Write failing UI test: item count reads "42 items" (plural) and "1 item" (singular)
- [x] 3.3 Write failing UI test: item count updates when search filters the list
- [x] 3.4 Write failing UI test: [+] button absent and ⌘N has no effect when Trash is selected
- [x] 3.5 Implement `listColumnHeader` in `VaultBrowserView.swift`: `VStack` of bold title (`Typography.columnHeader`) + caption count (`Typography.listSubtitle`) left, bordered `[+]` button right; `NewItemTypePickerView` remains a private struct at the bottom of `VaultBrowserView.swift` (no file move in this change)
- [x] 3.6 Bind title to `viewModel.sidebarSelection.displayName`; bind count to `viewModel.displayedItems.count` using a ternary for singular/plural — `count == 1 ? "1 item" : "\(count) items"` (English-only; localisation deferred)
- [x] 3.7 Conditionally render `[+]` using `if viewModel.sidebarSelection != .trash { … }` — `.hidden()` is insufficient as keyboard shortcuts still fire on hidden buttons
- [x] 3.8 Retain `NewItemTypePickerView` popover, `⌘N` shortcut, and `AccessibilityID.Create.newItemButton` on the `[+]` button

## 4. Detail Column Header — tests first

- [x] 4.1 Write failing UI test: [Edit] and [Delete] visible and left-aligned for active item selection
- [x] 4.2 Write failing UI test: [Edit] disabled while edit sheet is open
- [x] 4.3 Write failing UI test: ⌘E opens edit sheet from the header button
- [x] 4.4 Write failing UI test: [Delete] shows confirmation alert before moving to Trash
- [x] 4.5 Write failing UI test: [Restore] and [Delete Permanently] visible for trashed item; no search field shown
- [x] 4.6 Write failing UI test: [Restore] executes immediately without confirmation
- [x] 4.7 Write failing UI test: search field filters the item list in real time
- [x] 4.8 Write failing UI test: search query is cleared when the user navigates to Trash
- [x] 4.9 Write failing UI test: search field reappears when navigating from Trash back to a non-Trash category
- [x] 4.10 Implement `detailColumnHeader` subview in `VaultBrowserView.swift` — `.background(.bar)` bar with `Divider` below
- [x] 4.11 Left side: show `[Delete]` + `[Edit]` for active item; `[Restore]` + `[Delete Permanently]` for trashed item; nothing when no item selected
- [x] 4.12 Add `.keyboardShortcut("e", modifiers: .command)` and `AccessibilityID.Edit.editButton` to `[Edit]`; disable when `viewModel.editSheetOpen` is true; add a unit test verifying `editSheetOpen` and `ItemDetailView.isEditSheetPresented` remain in lockstep
- [x] 4.13 Wire `[Edit]` → `viewModel.triggerEdit()`, `[Restore]` → `viewModel.performRestore`
- [x] 4.14 Add `showSoftDeleteAlert` and `showPermanentDeleteAlert` `@State` vars to `VaultBrowserView`; wire `[Delete]` and `[Delete Permanently]` to set them; add `.alert` modifiers on `VaultBrowserView` that call `viewModel.performSoftDelete` / `viewModel.performPermanentDelete` on confirm
- [x] 4.15 Create `NativeSearchField: NSViewRepresentable` in `Presentation/Components/`; bind to `Binding<String>`; forward `controlTextDidChange` for live-per-keystroke filtering; all `NSView` interactions (delegate, first-responder calls) MUST occur on the main thread — do not capture `NSView` references in closures that may execute off-main; guard `updateNSView` with a string equality check before setting `stringValue` to prevent update cycles; subclass `NSSearchField` to override `cancelOperation(_:)` — capture `window?.firstResponder` in `focus()` before calling `makeFirstResponder`, restore it in `cancelOperation`
- [x] 4.16 Place `NativeSearchField` right-aligned in `detailColumnHeader`; conditionally render using `if viewModel.sidebarSelection != .trash { … }`; set `AccessibilityID.Vault.searchField` (already defined as `"vault.search"` in `AccessibilityIdentifiers.swift` — use the existing constant, do not add a duplicate)
- [x] 4.17 Write failing UI test: ⌘F moves focus into the search field when a non-Trash category is active
- [x] 4.18 Write failing UI test: ESC while search field is focused returns focus to its previous location
- [x] 4.19 Add a zero-size hidden `Button` with `.keyboardShortcut("f", modifiers: .command)` that calls `NativeSearchField.focus()`; conditionally render alongside the search field so ⌘F is inactive in Trash
- [x] 4.20 Clear `viewModel.searchQuery` when `viewModel.sidebarSelection` changes to `.trash` (use `.onChange`)
- [x] 4.21 Compose `detailColumnHeader` into the detail column `VStack` in `VaultBrowserView`
- [x] 4.22 Add `os.Logger` calls in `VaultBrowserView` for: search query becoming active/inactive (`.info`, no query content — log only active/inactive state to avoid logging secrets), soft-delete triggered, permanent-delete triggered, restore triggered; use category `"UI.VaultBrowser"`

## 5. Remove Old Toolbar

- [x] 5.1 Remove `.searchable(text: $viewModel.searchQuery, prompt:)` from `VaultBrowserView`
- [x] 5.2 Remove the `.toolbar { ToolbarItem { lastSyncedLabel } }` block from `VaultBrowserView`
- [x] 5.3 Delete the `lastSyncedLabel` computed property from `VaultBrowserView`
- [x] 5.4 Remove the `.toolbar {}` block from `ItemDetailView`
- [x] 5.5 Remove `showSoftDeleteAlert` and `showPermanentDeleteAlert` `@State` vars from `ItemDetailView`

## 6. Update Existing Tests

- [x] 6.1 Update `CreateItemJourneyTests` — verify [+] button still found by `AccessibilityID.Create.newItemButton` in its new location
- [x] 6.2 Update `VaultBrowserJourneyTests` — re-query Edit/Delete buttons by their existing accessibility IDs (now in the detail column header); adjust any query chains that assumed toolbar placement
- [x] 6.3 Update `EditItemJourneyTests` — re-query Edit button by `AccessibilityID.Edit.editButton` in its new location
- [ ] 6.4 Run the full UI test suite; fix any geometry-based assertions broken by the taller list column header
