## 1. DesignSystem

- [ ] 1.1 Add `Typography.columnHeader` token to `DesignSystem.swift` for the bold category title in the list column header (new role — no existing token fits)

## 2. Window Chrome

- [ ] 2.1 In `MacwardenApp.swift`, change `.windowStyle(.titleBar)` to `.windowStyle(.hiddenTitleBar)`
- [ ] 2.2 Remove `.windowToolbarStyle(.unified)` from the `WindowGroup` scene

## 3. List Column Header — tests first

- [ ] 3.1 Write failing UI test: list column header title matches the active sidebar selection
- [ ] 3.2 Write failing UI test: item count reads "42 items" (plural) and "1 item" (singular)
- [ ] 3.3 Write failing UI test: item count updates when search filters the list
- [ ] 3.4 Write failing UI test: [+] button absent and ⌘N has no effect when Trash is selected
- [ ] 3.5 Implement `listColumnHeader` in `VaultBrowserView.swift`: `VStack` of bold title (`Typography.columnHeader`) + caption count (`Typography.listSubtitle`) left, bordered `[+]` button right
- [ ] 3.6 Bind title to `viewModel.sidebarSelection.displayName`; bind count to `viewModel.displayedItems.count` with singular/plural formatting
- [ ] 3.7 Conditionally render `[+]` using `if viewModel.sidebarSelection != .trash { … }` — `.hidden()` is insufficient as keyboard shortcuts still fire on hidden buttons
- [ ] 3.8 Retain `NewItemTypePickerView` popover, `⌘N` shortcut, and `AccessibilityID.Create.newItemButton` on the `[+]` button

## 4. Detail Column Header — tests first

- [ ] 4.1 Write failing UI test: [Edit] and [Delete] visible and left-aligned for active item selection
- [ ] 4.2 Write failing UI test: [Edit] disabled while edit sheet is open
- [ ] 4.3 Write failing UI test: ⌘E opens edit sheet from the header button
- [ ] 4.4 Write failing UI test: [Delete] shows confirmation alert before moving to Trash
- [ ] 4.5 Write failing UI test: [Restore] and [Delete Permanently] visible for trashed item; no search field shown
- [ ] 4.6 Write failing UI test: [Restore] executes immediately without confirmation
- [ ] 4.7 Write failing UI test: search field filters the item list in real time
- [ ] 4.8 Write failing UI test: search query is cleared when the user navigates to Trash
- [ ] 4.9 Add `AccessibilityID.Vault.searchField` to `AccessibilityIdentifiers.swift`
- [ ] 4.10 Implement `detailColumnHeader` subview in `VaultBrowserView.swift` — `.background(.bar)` bar with `Divider` below
- [ ] 4.11 Left side: show `[Delete]` + `[Edit]` for active item; `[Restore]` + `[Delete Permanently]` for trashed item; nothing when no item selected
- [ ] 4.12 Add `.keyboardShortcut("e", modifiers: .command)` and `AccessibilityID.Edit.editButton` to `[Edit]`; disable when `viewModel.editSheetOpen` is true
- [ ] 4.13 Wire `[Edit]` → `viewModel.triggerEdit()`, `[Restore]` → `viewModel.performRestore`
- [ ] 4.14 Add `showSoftDeleteAlert` and `showPermanentDeleteAlert` `@State` vars to `VaultBrowserView`; wire `[Delete]` and `[Delete Permanently]` to set them; add `.alert` modifiers on `VaultBrowserView` that call `viewModel.performSoftDelete` / `viewModel.performPermanentDelete` on confirm
- [ ] 4.15 Create `NativeSearchField: NSViewRepresentable` wrapper around `NSSearchField` in `Presentation/Components/`; bind its string value to a `Binding<String>`; forward `controlTextDidChange` to the binding so filtering is live per keystroke; expose a `focus()` method that captures `window?.firstResponder` into a local var then calls `window?.makeFirstResponder(nsView)`; subclass `NSSearchField` to override `cancelOperation(_:)` — restore the captured previous responder via `window?.makeFirstResponder(previousResponder)` when ESC is pressed
- [ ] 4.16 Place `NativeSearchField` right-aligned in `detailColumnHeader`; conditionally render using `if viewModel.sidebarSelection != .trash { … }`; set `AccessibilityID.Vault.searchField` via `NSAccessibility`
- [ ] 4.17 Write failing UI test: ⌘F moves focus into the search field when a non-Trash category is active
- [ ] 4.18 Write failing UI test: ESC while search field is focused returns focus to its previous location
- [ ] 4.19 Add a zero-size hidden `Button` with `.keyboardShortcut("f", modifiers: .command)` that calls `NativeSearchField.focus()`; conditionally render alongside the search field so ⌘F is inactive in Trash
- [ ] 4.20 Clear `viewModel.searchQuery` when `viewModel.sidebarSelection` changes to `.trash` (use `.onChange`)
- [ ] 4.21 Compose `detailColumnHeader` into the detail column `VStack` in `VaultBrowserView`

## 5. Remove Old Toolbar

- [ ] 5.1 Remove `.searchable(text: $viewModel.searchQuery, prompt:)` from `VaultBrowserView`
- [ ] 5.2 Remove the `.toolbar { ToolbarItem { lastSyncedLabel } }` block from `VaultBrowserView`
- [ ] 5.3 Delete the `lastSyncedLabel` computed property from `VaultBrowserView`
- [ ] 5.4 Remove the `.toolbar {}` block from `ItemDetailView`
- [ ] 5.5 Remove `showSoftDeleteAlert` and `showPermanentDeleteAlert` `@State` vars from `ItemDetailView`

## 6. Update Existing Tests

- [ ] 6.1 Update `CreateItemJourneyTests` — verify [+] button still found by `AccessibilityID.Create.newItemButton` in its new location
- [ ] 6.2 Update `VaultBrowserJourneyTests` — re-query Edit/Delete buttons by their existing accessibility IDs (now in the detail column header)
- [ ] 6.3 Update `EditItemJourneyTests` — re-query Edit button by `AccessibilityID.Edit.editButton` in its new location
- [ ] 6.4 Run the full UI test suite; fix any geometry-based assertions broken by the taller list column header
