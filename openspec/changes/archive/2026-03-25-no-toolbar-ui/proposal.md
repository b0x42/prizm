## Why

The current vault browser uses a standard macOS unified toolbar with a floating search bar and toolbar buttons, which feels generic and dated. Adopting a cleaner layout with native SwiftUI toolbar and searchable APIs creates a simpler, more native macOS experience while removing unnecessary custom chrome.

## What Changes

- Remove the macOS title bar and unified toolbar chrome (hidden title bar window style)
- Replace `.searchable()` toolbar placement with `.searchable(placement: .sidebar)` on the content column for native search
- Remove the custom `listColumnHeader` and `detailColumnHeader` subviews
- Remove the custom `NativeSearchField` (`NSViewRepresentable` wrapper)
- Place `[+]` button in the content pane toolbar via `ToolbarItem(placement: .primaryAction)`
- Place Edit/Delete/Restore/Permanent Delete buttons in the detail pane toolbar via `ToolbarItem`
- Move confirmation alert state from `ItemDetailView` to `VaultBrowserView`
- Remove "Last synced" toolbar label entirely
- Remove `DetailColumnHeaderTests` and `ListColumnHeaderTests` (tested removed custom headers)

## Capabilities

### Modified Capabilities
- `vault-browser-ui`: Window chrome changes (hidden title bar), native `.searchable` on content column, toolbar-based action buttons on detail column, removal of custom column headers and `NativeSearchField`

## Impact

- `MacwardenApp.swift`: window style + toolbar style modifiers
- `VaultBrowserView.swift`: remove custom `listColumnHeader`, `detailColumnHeader`, `NativeSearchField` usage; use native `.searchable` and `.toolbar` for all controls
- `ItemDetailView.swift`: remove `.toolbar {}` block; actions driven by parent via existing callback props and `editTrigger`
- `NativeSearchField.swift`: deleted (replaced by native `.searchable`)
- `DetailColumnHeaderTests.swift`: deleted (tested removed custom header)
- `ListColumnHeaderTests.swift`: deleted (tested removed custom header)
- No new dependencies; no data layer changes
