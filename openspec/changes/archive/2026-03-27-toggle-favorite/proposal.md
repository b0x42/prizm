## Why

The Favorites sidebar category exists and items display a star icon when favorited, but there's no way to favorite or unfavorite an item from the UI. Users need a quick way to mark frequently-used items so they appear in the Favorites section.

## What Changes

- Add a favorite/unfavorite toggle to the item detail toolbar (star icon)
- Add a favorite/unfavorite option to the item list row context menu
- Toggling favorite calls the existing `VaultRepository.update()` API path (the reverse mapper already sends `isFavorite`)
- Sidebar Favorites count updates immediately after toggle

## Capabilities

### New Capabilities

- `toggle-favorite`: Toggle favorite status on vault items from the detail view or list context menu

### Modified Capabilities

*(none — the Favorites sidebar filter and star display already exist)*

## Impact

- `ItemDetailView.swift` — star toggle button in toolbar
- `ItemListView.swift` — "Favorite" / "Unfavorite" in context menu
- `VaultBrowserViewModel.swift` — `toggleFavorite()` method that updates via `VaultRepository`
- No new API calls — uses existing `PUT /ciphers/{id}` via `VaultRepository.update()`
