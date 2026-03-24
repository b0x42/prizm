## ADDED Requirements

### Requirement: List column header shows category title and item count
The list column SHALL display a persistent header above the item list containing:
- A bold category title reflecting the currently selected sidebar entry (e.g. "All Items", "Logins", "Trash"), styled with `Typography.columnHeader` (a new token to be added to `DesignSystem.swift`)
- A secondary item count label below the title showing the number of items currently displayed (after any active search filter), styled with `Typography.listSubtitle`
- A bordered `[+]` button right-aligned on the title row to create a new item

The header SHALL use `.background(.bar)` so list content blurs beneath it on scroll. The `[+]` button SHALL be conditionally rendered (not merely hidden) when `Trash` is selected — it must be absent from the view tree so that the ⌘N keyboard shortcut is also disabled in Trash. The `[+]` button SHALL carry `AccessibilityID.Create.newItemButton` to preserve existing UI test queries.

The item count label SHALL use the correct grammatical number: "1 item" (singular) and "N items" (plural). The app is English-only in v1; a simple ternary is sufficient — no `LocalizedStringResource` required at this stage.

#### Scenario: Header reflects sidebar selection
- **WHEN** the user selects "Logins" in the sidebar
- **THEN** the list column header title reads "Logins"

#### Scenario: Item count reflects displayed items
- **WHEN** the item list shows 42 items
- **THEN** the count label reads "42 items"

#### Scenario: Item count singular form
- **WHEN** the item list shows exactly 1 item
- **THEN** the count label reads "1 item" (not "1 items")

#### Scenario: Item count updates when search filters the list
- **WHEN** a search term reduces the displayed items from 42 to 2
- **THEN** the count label updates to "2 items"

#### Scenario: Plus button absent in Trash
- **WHEN** the user selects "Trash" in the sidebar
- **THEN** no [+] button is present in the list column header and ⌘N has no effect

#### Scenario: Plus button triggers new item picker
- **WHEN** the user clicks [+] in the list column header
- **THEN** the new item type picker popover opens (same behaviour as previous newItemBar)

#### Scenario: ⌘N opens type picker outside Trash
- **WHEN** the user presses ⌘N while a non-Trash category is selected
- **THEN** the new item type picker popover opens with Login pre-selected
