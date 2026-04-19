## MODIFIED Requirements

### Requirement: User can browse their vault in a three-pane layout
The system SHALL display a `NavigationSplitView` with a sidebar (categories + counts), a middle item list, and a detail pane. The sidebar SHALL be organised into sections: *Menu Items* (All Items, Favorites), *Folders* (section header always visible; folder rows shown when folders exist), *Types* (Login, Card, Identity, Secure Note, SSH Key), *Organizations* (section visible only when the user belongs to at least one org; each org is a disclosure group containing its collections), and *Trash*, each with a live item count. Soft-deleted items (Trash) SHALL be excluded from all non-Trash views.

#### Scenario: Sidebar shows all categories with counts
- **WHEN** the vault browser opens
- **THEN** the sidebar shows Menu Items, Folders (header always visible; rows when folders exist), Types, Organizations (only when orgs exist), and Trash sections; each entry displays its item count; type entries are shown even when the count is zero

#### Scenario: Selecting a sidebar category updates the item list
- **WHEN** the user selects a sidebar entry (category, folder, type, org, or collection)
- **THEN** the middle pane shows only items belonging to that selection; the detail pane resets to its empty state

#### Scenario: No item selected — empty detail state
- **WHEN** no item is selected in the middle pane
- **THEN** the detail pane shows a "No item selected" empty state

#### Scenario: Selecting an item shows its full content
- **GIVEN** an item is selected
- **WHEN** the detail pane renders
- **THEN** all fields for that item type are displayed, along with creation date and last-modified date

#### Scenario: Item list shows type-specific subtitles and icons
- **WHEN** the item list renders
- **THEN** each row shows: favicon (or type-icon fallback), item name, type-specific subtitle (Login=username; Card=`*`+last 4 digits; Identity=first+last name; Secure Note=first 30 chars truncated; SSH Key=fingerprint), and a favorite star if marked as favorite

#### Scenario: Item list is sorted alphabetically
- **WHEN** any category is selected
- **THEN** the item list is sorted alphabetically by item name, case-insensitive

#### Scenario: Org item rows show org membership badge
- **WHEN** an org item appears in the item list (e.g., under All Items or a type selection)
- **THEN** the item row SHALL display a small badge or secondary label indicating the organization name

#### Scenario: Organizations section absent when user has no orgs
- **WHEN** the user belongs to no organizations
- **THEN** no "Organizations" section SHALL appear in the sidebar

---

### Requirement: Focus SHALL return to a logical element after dismissals
When a sheet, alert, or destructive action completes, keyboard and VoiceOver focus SHALL return to a logical element rather than being lost.

#### Scenario: Focus returns after edit sheet dismiss
- **WHEN** the user dismisses the edit sheet (save or discard)
- **THEN** focus SHALL return to the detail pane or the previously selected item

#### Scenario: Focus returns after delete confirmation
- **WHEN** the user confirms a soft delete and the item is removed from the list
- **THEN** focus SHALL move to the next item in the list, or the empty state if no items remain

#### Scenario: Focus returns after alert dismiss
- **WHEN** the user dismisses an error alert via the OK button
- **THEN** focus SHALL return to the element that was focused before the alert appeared