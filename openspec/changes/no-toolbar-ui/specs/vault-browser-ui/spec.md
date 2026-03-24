## MODIFIED Requirements

### Requirement: Real-time search filters the item list within the active category
The system SHALL provide a persistent search field in the detail column header that filters the item list in real time on every keystroke. Search SHALL be scoped to the currently selected sidebar category. The search term SHALL be preserved when the user switches categories and re-filtered against the new category's items.

Fields searched per type: Login (name, username, URIs, notes), Card (name, cardholderName, notes), Identity (name, firstName, lastName, email, company, notes), Secure Note (name, notes), SSH Key (name only).

#### Scenario: Search filters item list
- **WHEN** the user types in the detail column header search field
- **THEN** the item list updates in real time to show only matching items

#### Scenario: Empty search results
- **WHEN** the search term matches no items
- **THEN** the item list shows an empty state message

#### Scenario: Clear search restores full list
- **WHEN** the user clears the search field
- **THEN** the full item list for the active category is restored

#### Scenario: Search term preserved across category switches
- **WHEN** a search is active and the user selects a different sidebar category
- **THEN** the search term is preserved and results are re-filtered against the new category

## REMOVED Requirements

### Requirement: "Last synced" timestamp shown in toolbar
**Reason**: The toolbar is removed as part of the no-toolbar UI redesign. The "Last synced" label has no appropriate host in the new column-header layout and is removed entirely from the UI.
**Migration**: No user-facing migration needed. The underlying `lastSyncedAt` state in `VaultBrowserViewModel` is retained for potential future use.
