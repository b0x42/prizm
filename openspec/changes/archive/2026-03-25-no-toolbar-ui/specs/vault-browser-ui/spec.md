## MODIFIED Requirements

### Requirement: Real-time search filters the item list within the active category
The system SHALL provide search via the native `.searchable(text:placement:prompt:)` modifier with `.sidebar` placement on the content column. Search SHALL filter the item list in real time on every keystroke, scoped to the currently selected sidebar category.

Fields searched per type: Login (name, username, URIs, notes), Card (name, cardholderName, notes), Identity (name, firstName, lastName, email, company, notes), Secure Note (name, notes), SSH Key (name only).

When the sidebar selection changes to Trash, the search query SHALL be cleared so that no invisible filter is applied to the trash item list.

#### Scenario: Search filters item list
- **WHEN** the user types in the search field
- **THEN** the item list updates in real time to show only matching items

#### Scenario: Empty search results
- **WHEN** the search term matches no items
- **THEN** the item list shows an empty state message

#### Scenario: Clear search restores full list
- **WHEN** the user clears the search field
- **THEN** the full item list for the active category is restored

#### Scenario: Search query cleared on entering Trash
- **WHEN** the user selects Trash in the sidebar while a search query is active
- **THEN** the search query is cleared

## REMOVED Requirements

### Requirement: "Last synced" timestamp shown in toolbar
**Reason**: The toolbar is simplified as part of the no-toolbar UI redesign. The "Last synced" label is removed from the UI.
**Migration**: The underlying `lastSyncedAt` state in `VaultBrowserViewModel` is retained for potential future use.

### Requirement: Custom NativeSearchField with focus restoration
**Reason**: Replaced by native `.searchable` modifier. The custom `NSSearchField` wrapper, `FocusRestoringSearchField` subclass, and ⌘F focus hack are no longer needed.
**Migration**: `NativeSearchField.swift` deleted. Search is handled entirely by SwiftUI.
