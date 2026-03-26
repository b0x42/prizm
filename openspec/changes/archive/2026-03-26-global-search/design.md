## Context

Search is currently implemented via SwiftUI's `.searchable` modifier with `.sidebar` placement. It filters the item list within the active `SidebarSelection` — if the user is viewing Logins, search only returns Logins. The `SearchVaultUseCase` delegates to `VaultRepository.searchItems(query:in:)` which handles per-type field matching. There is no way to search across all types without first selecting "All Items" in the sidebar.

## Goals / Non-Goals

**Goals:**
- ⌘F activates a global search mode that searches across all vault items regardless of sidebar selection
- Matching text fragments are highlighted in item list rows so users see why an item matched
- Escape or clearing the query exits global search and restores the prior sidebar state
- Existing category-scoped search continues to work unchanged

**Non-Goals:**
- Fuzzy/typo-tolerant search — exact substring matching is sufficient for v1
- Search history or recent searches
- Searching inside custom field values or notes content beyond what's already matched
- Spotlight or system-level search integration

## Decisions

**1. Global search as a mode flag, not a new view**

Add an `isGlobalSearch: Bool` flag to `VaultBrowserViewModel`. When true, search passes `.allItems` to the use case regardless of the current sidebar selection. The sidebar selection is preserved and restored on exit.

Alternative considered: a separate search overlay/sheet. Rejected because it breaks the three-pane mental model and adds navigation complexity.

**2. ⌘F via SwiftUI `.onKeyPress` or `keyboardShortcut`**

Use a hidden `Button` with `.keyboardShortcut("f")` to activate global search mode and focus the search field. This is the standard SwiftUI pattern and avoids `NSEvent` monitors.

Alternative considered: `NSEvent.addLocalMonitorForEvents`. Rejected — unnecessary AppKit dependency when SwiftUI provides the mechanism.

**3. Match highlighting via `AttributedString` in `ItemRowView`**

When a search query is active, `ItemRowView` receives the query string and uses `AttributedString` to apply bold text weight to matching substrings in the name and subtitle. This is computed per-row at render time — no caching needed given the filtered result set is small.

Alternative considered: returning match ranges from the repository layer. Rejected — adds complexity to the domain layer for a purely presentational concern.

**4. Reuse existing `SearchVaultUseCase` with `.allItems` selection**

No new use case needed. Global search simply calls `execute(query:in: .allItems)`. The repository already supports `.allItems` which searches across all types.

## Risks / Trade-offs

- **[Risk] ⌘F conflicts with system Find** → Mitigation: macOS apps commonly override ⌘F. The `.searchable` modifier's built-in ⌘F behavior may already handle focus; we may only need to set the global flag. Test for conflicts with the Edit menu's Find command.
- **[Risk] Highlight computation on every keystroke** → Mitigation: `AttributedString` substring matching is O(n) per row on an already-filtered list (typically <50 items). No performance concern at vault sizes up to 1,000 items.
- **[Risk] Sidebar selection state confusion** → Mitigation: Store `previousSelection` before entering global mode. On exit, restore it. Visual indicator (e.g., sidebar deselects or dims) signals global mode is active.
