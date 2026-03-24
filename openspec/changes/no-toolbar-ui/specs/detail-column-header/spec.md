## ADDED Requirements

### Requirement: Detail column header shows contextual action buttons and search
The detail column SHALL display a persistent header bar above the item detail content. Its contents SHALL depend on the current state:

**Active item selected (not trash):**
- `[Delete]` button left-aligned — soft-deletes the item (moves to Trash); triggers a confirmation alert before executing. The confirmation alert state SHALL live in `VaultBrowserView` (not `ItemDetailView`).
- `[Edit]` button left-aligned (to the right of Delete) — opens the edit sheet for the selected item; disabled while the edit sheet is already open. SHALL carry `.keyboardShortcut("e", modifiers: .command)` and `AccessibilityID.Edit.editButton`.
- Search field right-aligned — filters the item list in real time. SHALL be implemented as `NSSearchField` via `NSViewRepresentable` to preserve native macOS focus restoration and clear-button animation. SHALL carry `AccessibilityID.Vault.searchField`.

**Trashed item selected:**
- `[Restore]` button left-aligned — restores the item to the active vault immediately, with no confirmation alert required (non-destructive).
- `[Delete Permanently]` button left-aligned — permanently deletes the item; triggers a confirmation alert before executing. The confirmation alert state SHALL live in `VaultBrowserView`.
- No search field.

**No item selected:**
- No action buttons.
- Search field right-aligned.

The `[+]` button in the list column header, `[Delete]`, `[Edit]`, `[Restore]`, and `[Delete Permanently]` SHALL all be styled as bordered buttons (consistent visual weight).

When the sidebar selection changes to `Trash`, `searchQuery` SHALL be cleared so that no invisible filter is applied to the trash item list.

#### Scenario: Active item — Edit and Delete visible
- **WHEN** an active (non-trashed) vault item is selected
- **THEN** both [Delete] and [Edit] buttons are visible in the detail column header, left-aligned

#### Scenario: Edit disabled while sheet is open
- **WHEN** the edit sheet is currently open
- **THEN** the [Edit] button is disabled

#### Scenario: Edit button carries ⌘E shortcut
- **WHEN** the user presses ⌘E with an active item selected and the edit sheet closed
- **THEN** the edit sheet opens for the selected item

#### Scenario: Delete triggers confirmation
- **WHEN** the user clicks [Delete] in the detail column header
- **THEN** a confirmation alert is shown in `VaultBrowserView` before the item is moved to Trash

#### Scenario: Permanent delete triggers confirmation
- **WHEN** the user clicks [Delete Permanently] in the detail column header
- **THEN** a confirmation alert is shown in `VaultBrowserView` before the item is permanently deleted

#### Scenario: Restore executes immediately
- **WHEN** the user clicks [Restore] in the detail column header
- **THEN** the item is restored to the active vault without a confirmation alert

#### Scenario: Trashed item — Restore and Delete Permanently visible
- **WHEN** a trashed vault item is selected
- **THEN** [Restore] and [Delete Permanently] buttons are visible; no search field is shown

#### Scenario: No selection — only search visible
- **WHEN** no item is selected
- **THEN** no action buttons are shown; the search field is visible right-aligned

#### Scenario: Search field filters item list in real time
- **WHEN** the user types in the detail column header search field
- **THEN** the item list filters in real time on every keystroke, scoped to the active category

#### Scenario: ⌘F jumps focus to search field
- **WHEN** the user presses ⌘F while a non-Trash category is selected
- **THEN** the search field gains first-responder focus and the cursor is placed inside it

#### Scenario: ESC from search field restores previous focus
- **WHEN** the user pressed ⌘F to enter the search field and then presses ESC
- **THEN** focus returns to the element that held first-responder status before ⌘F was pressed (e.g. the item list or the detail pane)

#### Scenario: ⌘F has no effect in Trash
- **WHEN** the user presses ⌘F while Trash is selected
- **THEN** nothing happens (search field is not present in the Trash state)

#### Scenario: Search query cleared on entering Trash
- **WHEN** the user selects Trash in the sidebar while a search query is active
- **THEN** the search query is cleared and the full trash item list is shown

#### Scenario: Search field reappears after leaving Trash
- **WHEN** the user navigates from Trash to any non-Trash category
- **THEN** the search field is visible again in the detail column header
