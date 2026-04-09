## MODIFIED Requirements

### Requirement: User can browse their vault in a three-pane layout
The system SHALL display a `NavigationSplitView` with a sidebar (categories + counts), a middle item list, and a detail pane. The sidebar SHALL be organised into sections: *Menu Items* (All Items, Favorites), *Folders* (section header always visible; folder rows shown when folders exist), *Types* (Login, Card, Identity, Secure Note, SSH Key), and *Trash*, each with a live item count. Soft-deleted items (Trash) SHALL be excluded from all non-Trash views.

#### Scenario: Sidebar shows all categories with counts
- **WHEN** the vault browser opens
- **THEN** the sidebar shows Menu Items, Folders (header always visible; rows when folders exist), Types, and Trash sections; each entry displays its item count; type entries are shown even when the count is zero

#### Scenario: Selecting a sidebar category updates the item list
- **WHEN** the user selects a sidebar entry (category, folder, or type)
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
