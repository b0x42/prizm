## Context

Macwarden currently uses the standard macOS unified toolbar pattern: `.windowStyle(.titleBar)` + `.windowToolbarStyle(.unified)` gives a single combined title/toolbar bar across the top. Search (`searchable`) and the "Last synced" label live in that toolbar. Edit/Delete/Restore/Permanent Delete buttons live in `ItemDetailView`'s own `.toolbar {}` block.

Apple's Passwords app on macOS 26 uses a different chrome: no visible title bar, no toolbar bar — all controls are embedded directly in column headers. This is achieved via `.windowStyle(.hiddenTitleBar)`, with traffic light buttons floating over the sidebar.

The goal is to replicate this layout. Three surfaces change:
1. **Window level** — strip chrome
2. **List column** — new header with title, count, and `[+]`
3. **Detail column** — new header with action buttons and search field

## Goals / Non-Goals

**Goals:**
- Remove toolbar chrome entirely (hidden title bar, no unified toolbar bar)
- Replace `.searchable()` with `NSSearchField` in the detail column header
- Show bold category title + item count above the item list
- Show contextual action buttons (Edit/Delete or Restore/Perm.Delete) left-aligned in the detail header
- Show search field right-aligned in the detail header
- ⌘F jumps focus to the search field

**Non-Goals:**
- Sort button or sort functionality (explicitly out of scope)
- Any changes to the sidebar, item list rows, or detail content views
- Animation or transition polish beyond what SwiftUI provides by default

## Decisions

### 1. `.windowStyle(.hiddenTitleBar)` — not `.plain`

`.plain` removes the traffic lights entirely, which is too bare. `.hiddenTitleBar` keeps the traffic lights floating over the content (exactly what Passwords does) while eliminating the title bar chrome. Drop `.windowToolbarStyle(.unified)` alongside it — it has no effect without `.titleBar` but is noisy to keep.

### 2. Use `NSSearchField` via `NSViewRepresentable` for the search field

`.searchable()` places its field in the toolbar/navigation bar; without a unified toolbar there is no natural SwiftUI host in the detail column header. A plain SwiftUI `TextField` replicates the visual but loses native macOS focus restoration (the system restores the field's first-responder status when navigating back) and the built-in clear animation.

`NSSearchField` wrapped in `NSViewRepresentable` gives the full native experience — correct focus restoration, native clear button animation, correct search-field bezeling — while being placeable exactly where the detail column header needs it. This is the approach used to get identical behaviour to `.searchable()` without being tied to the toolbar.

**AppKit justification** (Constitution §I — AppKit permitted only when SwiftUI has no equivalent API): SwiftUI provides no API to place a `searchable`-quality search field at an arbitrary position within a view hierarchy on macOS. `NSViewRepresentable` wrapping `NSSearchField` is the only way to achieve native focus restoration and animation outside a toolbar context. Usage is limited to this one wrapper component.

### 3. Edit/Delete buttons and confirmation alerts move to `VaultBrowserView`

`ItemDetailView` currently owns its Edit/Delete toolbar buttons and the associated confirmation alert state. Both move to `VaultBrowserView`:
- The header bar is owned by `VaultBrowserView`, which already holds `viewModel` with access to `performSoftDelete`, `triggerEdit`, etc.
- The existing `editTrigger` pattern already lets the menu bar drive edit from outside `ItemDetailView` — the header Edit button uses the same path.
- Confirmation alerts (`showSoftDeleteAlert`, `showPermanentDeleteAlert`) move to `VaultBrowserView` alongside the buttons that trigger them. Keeping alerts in `ItemDetailView` while the buttons are in `VaultBrowserView` would require a trigger-Int pattern for each destructive action — unnecessary complexity when the state can simply move with the buttons.
- `ItemDetailView` retains `onSoftDelete` / `onPermanentDelete` / `onRestore` callback props (used by the trash banner) but its own `showSoftDeleteAlert` / `showPermanentDeleteAlert` `@State` vars are removed.

### 4. Trash column header omits search

When `sidebarSelection == .trash`, the detail header shows `[Restore]` and `[Delete Permanently]` with no search field. This matches Passwords and avoids the complexity of searching across trash separately.

### 5. List column header replaces `newItemBar`

`newItemBar` is a thin `.background(.bar)` strip with only the `+` button. It is replaced by `listColumnHeader`: a taller area with a `VStack` (bold name + caption count) on the left and a bordered `[+]` button on the right. The `.background(.bar)` material is retained so it blurs the list content when scrolled beneath it — the same visual as before, just taller.

## Risks / Trade-offs

- **UITest accessibility IDs on toolbar buttons** → The `AccessibilityID.Edit.editButton` is currently on the `ItemDetailView` toolbar `Button("Edit")`. After the move it will be on the header button in `VaultBrowserView`. XCUITests that query `app.buttons[AccessibilityID.Edit.editButton]` will still find the button — no ID change needed, just verify the UI tests pass.
- **`NSSearchField` focus behaviour** → `NSViewRepresentable` components require careful `makeNSView`/`updateNSView` implementation to avoid double-update cycles. Verify first-responder handoff works correctly with `NavigationSplitView` column focus changes.
- **⌘F conflicts** → ⌘F is used by some system services (e.g. browser find). In a sandboxed macOS app it is generally safe to claim, but verify no conflict with existing app shortcuts.
- **Traffic lights overlap sidebar content** → `NavigationSplitView` respects `.safeAreaInset` for the traffic light area automatically on macOS 26. No manual padding needed, but verify visually.
- **`newItemBar` height change** → The list column header is taller than the old `newItemBar` (28pt). XCUITests that measure geometry will need re-baselining; behaviour tests are unaffected.

## Migration Plan

Pure SwiftUI changes — no data model, no keychain, no network. No migration needed. The change is self-contained and ships as a single PR.

Rollback: revert the three modified files (`MacwardenApp.swift`, `VaultBrowserView.swift`, `ItemDetailView.swift`).

## Open Questions

- None — all decisions made during explore session.
