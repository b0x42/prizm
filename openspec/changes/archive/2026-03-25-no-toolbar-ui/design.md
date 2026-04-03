## Context

Prizm previously used custom column headers (`listColumnHeader`, `detailColumnHeader`) with a custom `NativeSearchField` (`NSViewRepresentable` wrapping `NSSearchField`) and manually positioned action buttons. This added complexity without meaningful UX benefit over native SwiftUI APIs.

The implementation now uses native SwiftUI `.searchable(placement: .sidebar)` for search and `.toolbar` with `ToolbarItem` for action buttons, which is simpler, more maintainable, and automatically adapts to macOS conventions.

## Goals / Non-Goals

**Goals:**
- Use native `.searchable` modifier for search (no custom `NSSearchField` wrapper)
- Use native `.toolbar` with `ToolbarItem` for `+`, Edit, Delete, Restore, and Permanent Delete buttons
- Keep hidden title bar window style for clean chrome
- Maintain all existing functionality: search, create, edit, delete, restore, permanent delete

**Non-Goals:**
- Sort button or sort functionality
- Custom column header styling or translucent material effects
- Any changes to the sidebar, item list rows, or detail content views

## Decisions

### 1. `.windowStyle(.hiddenTitleBar)` — not `.plain`

`.plain` removes the traffic lights entirely. `.hiddenTitleBar` keeps them floating over the sidebar while eliminating title bar chrome.

### 2. Native `.searchable` instead of custom `NSSearchField`

The original design used `NSSearchField` via `NSViewRepresentable` to get native focus restoration outside a toolbar. With the simplified approach, `.searchable(text:placement:prompt:)` with `.sidebar` placement provides the standard macOS search experience with zero custom code. The `NativeSearchField.swift` component and its `FocusRestoringSearchField` subclass are deleted.

### 3. Native `.toolbar` for action buttons

Instead of manually positioning buttons in custom header views, all action buttons use `ToolbarItem`:
- Content pane: `+` button via `ToolbarItem(placement: .primaryAction)`
- Detail pane: Edit/Delete via `ToolbarItem(placement: .primaryAction)` and `ToolbarItem(placement: .destructiveAction)`
- Trash state: Restore/Permanent Delete replace Edit/Delete

### 4. Confirmation alerts owned by `VaultBrowserView`

`showSoftDeleteAlert` and `showPermanentDeleteAlert` state lives in `VaultBrowserView` alongside the toolbar buttons that trigger them. `ItemDetailView` retains callback props but no longer owns alert state.

### 5. Trash hides search and `+` button

When `sidebarSelection == .trash`, the `+` button is conditionally removed from the view tree (not hidden) so ⌘N is also disabled. Search query is cleared via `.onChange` when entering Trash.

## Risks / Trade-offs

- **Toolbar button placement**: macOS `NavigationSplitView` shares a single window toolbar across columns. Button placement is controlled by the system based on which column's `.toolbar` block defines them, but exact positioning may vary across macOS versions.
- **No custom search field styling**: Native `.searchable` doesn't support custom positioning within a column header. The search field appears in the system-determined location for `.sidebar` placement.

## Migration Plan

Pure SwiftUI changes — no data model, no keychain, no network. No migration needed. Rollback: revert modified files and restore deleted files from git.
