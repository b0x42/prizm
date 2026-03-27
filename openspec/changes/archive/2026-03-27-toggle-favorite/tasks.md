## 1. VaultBrowserViewModel — toggle favorite

- [x] 1.1 Add `toggleFavorite(item:)` method that creates a `DraftVaultItem` with flipped `isFavorite`, calls `update()` on the vault repository, and refreshes items + counts
- [x] 1.2 Add unit test: `toggleFavorite` flips `isFavorite` and calls `update()` on the repository

## 2. Detail View — star toggle button

- [x] 2.1 Add a star toggle button to `ItemDetailView` toolbar (empty star / filled star based on `isFavorite`)
- [x] 2.2 Hide the star button for trashed items
- [x] 2.3 Wire button to call `toggleFavorite` and update the selected item

## 3. List Context Menu — favorite/unfavorite

- [x] 3.1 Add "Favorite" / "Unfavorite" (label adapts) to the item list row context menu
- [x] 3.2 Wire context menu action to call `toggleFavorite`

## 4. Remove star from list rows

- [x] 4.1 Remove the `star.fill` icon from `ItemRowView` for favorited items
