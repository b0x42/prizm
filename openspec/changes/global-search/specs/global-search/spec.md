## ADDED Requirements

### Requirement: User can activate global search with ⌘F
The system SHALL provide a ⌘F keyboard shortcut that activates global search mode. When global search is active, the search field SHALL be focused and all vault items (excluding Trash) SHALL be searchable regardless of the current sidebar selection. The sidebar selection SHALL be visually deselected while global search is active.

#### Scenario: ⌘F activates global search and focuses the search field
- **WHEN** the user presses ⌘F from the vault browser
- **THEN** the search field is focused, global search mode is active, and the sidebar selection is visually deselected

#### Scenario: Global search returns results across all item types
- **GIVEN** global search is active
- **WHEN** the user types a query that matches items of different types (e.g., a Login and a Card)
- **THEN** both items appear in the item list

#### Scenario: Global search excludes trashed items
- **GIVEN** global search is active and the vault contains trashed items matching the query
- **WHEN** the user types a query
- **THEN** trashed items SHALL NOT appear in the results

#### Scenario: Escape exits global search and restores sidebar selection
- **GIVEN** global search is active
- **WHEN** the user presses Escape or clears the search field
- **THEN** global search mode is deactivated, the previous sidebar selection is restored, and the item list shows items for that selection

#### Scenario: Selecting a sidebar entry exits global search
- **GIVEN** global search is active
- **WHEN** the user clicks a sidebar entry
- **THEN** global search mode is deactivated and the selected category's items are shown

---

### Requirement: Matching text is highlighted in item list rows during search
The system SHALL highlight matching substrings in the item name and subtitle when a search query is active (both global and category-scoped). Highlighting SHALL use bold text weight to distinguish matched fragments from surrounding text.

#### Scenario: Name match is highlighted
- **GIVEN** a search query is active
- **WHEN** an item's name contains the query as a substring
- **THEN** the matching portion of the name is rendered in bold

#### Scenario: Subtitle match is highlighted
- **GIVEN** a search query is active
- **WHEN** an item's subtitle (username, cardholder, etc.) contains the query as a substring
- **THEN** the matching portion of the subtitle is rendered in bold

#### Scenario: No highlight when search is empty
- **WHEN** the search field is empty
- **THEN** item names and subtitles render with their default text weight

#### Scenario: Highlighting is case-insensitive
- **GIVEN** a search query "alice"
- **WHEN** an item's name is "Alice's Bank"
- **THEN** "Alice" is highlighted despite the case difference
