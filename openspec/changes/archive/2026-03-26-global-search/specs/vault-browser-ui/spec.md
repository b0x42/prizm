## MODIFIED Requirements

### Requirement: Real-time search filters the item list within the active category
The system SHALL provide search via the native `.searchable(text:placement:prompt:)` modifier with `.sidebar` placement on the content column. Search SHALL filter the item list in real time on every keystroke, scoped to the currently selected sidebar category.

When global search is active (triggered by ⌘F), search SHALL be scoped to `.allItems` regardless of the current sidebar selection.

Fields searched per type: Login (name, username, URIs, notes), Card (name, cardholderName, notes), Identity (name, firstName, lastName, email, company, notes), Secure Note (name, notes), SSH Key (name only).

When the sidebar selection changes to Trash, the search query SHALL be cleared so that no invisible filter is applied to the trash item list.

#### Scenario: Real-time filtering
- **WHEN** the user types in the search field
- **THEN** the item list immediately updates to show only matching items within the active category

#### Scenario: Global search overrides category scope
- **GIVEN** global search mode is active
- **WHEN** the user types in the search field
- **THEN** the item list shows matching items from all categories (excluding Trash)

#### Scenario: Empty search results
- **WHEN** the search term matches no items
- **THEN** a clear "no results" empty state is shown

#### Scenario: Clear search restores full list
- **WHEN** the user clears the search field
- **THEN** the middle pane shows all items for the active category

#### Scenario: Search query cleared on entering Trash
- **WHEN** the user selects Trash in the sidebar while a search query is active
- **THEN** the search query is cleared
