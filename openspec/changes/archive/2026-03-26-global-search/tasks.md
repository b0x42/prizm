## 1. Tests — Global Search State

- [x] 1.1 Add unit tests for `VaultBrowserViewModel`: `activateGlobalSearch` stores previous selection and sets flag
- [x] 1.2 Add unit test: `deactivateGlobalSearch` restores previous selection, clears query, resets flag
- [x] 1.3 Add unit test: search passes `.allItems` to `SearchVaultUseCase` when `isGlobalSearch` is true
- [x] 1.4 Add unit test: sidebar selection change during global search deactivates global search
- [x] 1.5 Add unit test: escape/clear during global search deactivates global search and restores selection

## 2. Global Search State in ViewModel

- [x] 2.1 Add `isGlobalSearch: Bool` and `previousSelection: SidebarSelection?` properties to `VaultBrowserViewModel`
- [x] 2.2 Add `activateGlobalSearch()` method that stores the current sidebar selection, sets `isGlobalSearch = true`, and focuses the search field
- [x] 2.3 Add `deactivateGlobalSearch()` method that restores `previousSelection`, clears the query, and sets `isGlobalSearch = false`
- [x] 2.4 Update the existing search filtering logic to pass `.allItems` to `SearchVaultUseCase` when `isGlobalSearch` is true

## 3. ⌘F Keyboard Shortcut

- [x] 3.1 Add a hidden `Button` with `.keyboardShortcut("f")` in `VaultBrowserView` that calls `activateGlobalSearch()`
- [x] 3.2 Wire Escape key or search field clearing to call `deactivateGlobalSearch()`
- [x] 3.3 Wire sidebar selection changes during global search to call `deactivateGlobalSearch()` before applying the new selection

## 4. Sidebar Visual Feedback

- [x] 4.1 Deselect the sidebar (set selection to `nil` or equivalent) while `isGlobalSearch` is active so no category appears highlighted

## 5. Tests — Match Highlighting

- [x] 5.1 Add unit tests for `highlightedText` helper: match applies bold, no match returns plain, case-insensitive matching, empty query returns plain

## 6. Match Highlighting in Item Rows

- [x] 6.1 Add a `highlightedText(_:query:)` helper that returns an `AttributedString` with bold applied to case-insensitive substring matches
- [x] 6.2 Update `ItemRowView` to accept an optional `searchQuery: String?` parameter
- [x] 6.3 Apply `highlightedText` to the item name and subtitle `Text` views when `searchQuery` is non-empty
- [x] 6.4 Pass the active search query from `ItemListView` down to each `ItemRowView`

## 7. Documentation

- [x] 7.1 Update README.md keyboard shortcuts table to include ⌘F for global search
