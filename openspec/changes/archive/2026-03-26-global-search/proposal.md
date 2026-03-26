## Why

The current search is scoped to the active sidebar category and only accessible from the vault browser's `.searchable` modifier. Users who want to find an item quickly — regardless of which category they're viewing — must manually switch categories or select "All Items" first. A global ⌘F shortcut that searches across all item types from any screen, with result highlighting, removes this friction and matches the behavior users expect from native macOS apps.

## What Changes

- Add a global ⌘F keyboard shortcut that activates search from any vault screen, overriding the current sidebar-scoped search
- When global search is active, search across all vault items regardless of the current sidebar selection
- Highlight matching text fragments in the item list rows (name, subtitle) so users can see *why* an item matched
- Pressing Escape or clearing the query exits global search and restores the previous sidebar selection and scope
- The existing category-scoped search (typing in the search field without ⌘F) continues to work as before

## Capabilities

### New Capabilities
- `global-search`: Global ⌘F search across all vault items with match highlighting in the item list

### Modified Capabilities
- `vault-browser-ui`: Search requirement updated to support a global search mode alongside the existing category-scoped search

## Impact

- `Presentation/Vault/VaultBrowserView.swift` — search field activation via ⌘F, global vs scoped mode toggle
- `Presentation/Vault/VaultBrowserViewModel.swift` — new global search state, mode switching
- `Presentation/Vault/ItemList/ItemRowView.swift` — highlighted match fragments in name/subtitle
- `Domain/UseCases/SearchVaultUseCase.swift` — support unscoped (all-items) search
- `Data/UseCases/SearchVaultUseCaseImpl.swift` — implementation of unscoped search
- No new dependencies or API changes; all data is already available locally after sync
