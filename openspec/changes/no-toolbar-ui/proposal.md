## Why

The current vault browser uses a standard macOS unified toolbar with a floating search bar and toolbar buttons, which feels generic and dated. Adopting the borderless, column-header-driven layout used by Apple's Passwords app creates a cleaner, more native macOS 26 experience that aligns with what users expect from a modern password manager.

## What Changes

- Remove the macOS title bar and unified toolbar chrome (hidden title bar window style)
- Remove `.searchable()` toolbar search; replace with a custom search field in the detail column header
- Replace the minimal `+` icon bar above the item list with a proper list column header: bold category title, item count below it, and a bordered `[+]` button top-right
- Move Edit and Delete toolbar buttons from `ItemDetailView`'s `.toolbar {}` block into a new detail column header bar (left-aligned), with the search field right-aligned
- Trash state: detail header shows `[Restore]` and `[Delete Permanently]` instead of Edit/Delete, no search field
- Remove "Last synced" toolbar label entirely
- **BREAKING**: `ItemDetailView` no longer owns its Edit/Delete/Restore/Permanent Delete toolbar buttons — callers must render them via the new detail header

## Capabilities

### New Capabilities
- `list-column-header`: Bold category title + item count label + bordered [+] button rendered above the item list, replacing the old `newItemBar`
- `detail-column-header`: Contextual action bar above the detail pane — shows Edit/Delete (active items), Restore/Permanent Delete (trash items), and a search field; replaces toolbar buttons from `ItemDetailView`

### Modified Capabilities
- `vault-browser-ui`: Window chrome changes (hidden title bar), removal of `.searchable()` and `.toolbar` modifiers, integration of the two new column headers

## Impact

- `MacwardenApp.swift`: window style + toolbar style modifiers
- `VaultBrowserView.swift`: remove `.searchable()`, `.toolbar`, `newItemBar`, `lastSyncedLabel`; add `listColumnHeader` and `detailColumnHeader` subviews
- `ItemDetailView.swift`: remove `.toolbar {}` block; Edit/Delete/Restore/Permanent Delete actions now driven by parent via existing callback props (`onSoftDelete`, `onRestore`, `onPermanentDelete`) and `editTrigger`
- `VaultBrowserViewModel.swift`: `sidebarSelection.displayName` used for header title; `displayedItems.count` used for item count
- No new dependencies; no data layer changes
