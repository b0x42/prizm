## ADDED Requirements

### Requirement: CardBackground ViewModifier
The system SHALL provide a `CardBackground` `ViewModifier` that applies a white/dark-gray background (`Color("CardBackground")`), `cornerRadius(20)`, and a subtle drop shadow (`black` at 20% opacity, radius 4) to any view. A `.cardBackground()` `View` extension SHALL expose it ergonomically.

#### Scenario: Card is visually distinct in light mode
- **WHEN** the detail pane is displayed in light mode
- **THEN** each card SHALL render with a white background, rounded corners (radius 20), and a visible shadow

#### Scenario: Card is visually distinct in dark mode
- **WHEN** the detail pane is displayed in dark mode
- **THEN** each card SHALL render with a dark gray (#212121) background so the shadow remains effective against the dark pane background

### Requirement: DetailSectionCard wrapper view
The system SHALL provide a `DetailSectionCard` SwiftUI view that accepts an optional section title and a `@ViewBuilder` content closure, rendering the content inside a `.cardBackground()` card with the title displayed above it when non-empty.

#### Scenario: Card renders with header
- **WHEN** a `DetailSectionCard` is initialised with a non-empty title string
- **THEN** the section header SHALL be visible above the card content

#### Scenario: Card renders without header
- **WHEN** a `DetailSectionCard` is initialised with no title (or empty string)
- **THEN** no header label SHALL be rendered

### Requirement: Login item detail grouped into cards
The system SHALL display Login item fields grouped into labelled card sections.

#### Scenario: Credentials card shown when username or password present
- **WHEN** a Login item has a username or password
- **THEN** a "Credentials" card SHALL be shown containing those fields

#### Scenario: Websites card shown when URIs present
- **WHEN** a Login item has one or more URIs
- **THEN** a "Websites" card SHALL be shown containing each URI as a copyable row

#### Scenario: Notes card shown when notes non-empty
- **WHEN** a Login item has non-empty notes
- **THEN** a "Notes" card SHALL be shown containing the notes field

#### Scenario: Custom fields card shown when custom fields present
- **WHEN** a Login item has one or more custom fields
- **THEN** a "Custom Fields" card SHALL be shown

#### Scenario: Empty sections are hidden
- **WHEN** a Login item has no URIs
- **THEN** the "Websites" card SHALL NOT be rendered

### Requirement: Card item detail grouped into cards
The system SHALL display Card item fields grouped into labelled card sections.

#### Scenario: Card details section shown
- **WHEN** a Card item is displayed
- **THEN** a "Card Details" section SHALL group cardholder name, brand, card number, expiry, and security code

#### Scenario: Empty card fields are hidden within the card
- **WHEN** a Card item is missing an optional field (e.g. no security code)
- **THEN** that field row SHALL NOT appear in the card

#### Scenario: Notes card hidden when empty
- **WHEN** a Card item has no notes
- **THEN** the "Notes" card SHALL NOT be rendered

#### Scenario: Custom fields card hidden when empty
- **WHEN** a Card item has no custom fields
- **THEN** the "Custom Fields" card SHALL NOT be rendered

### Requirement: Identity item detail grouped into cards
The system SHALL display Identity item fields grouped into labelled card sections: Personal Info, ID Numbers, Contact, Address, Notes, and Custom Fields.

#### Scenario: Personal Info card
- **WHEN** an Identity item has any name or company fields
- **THEN** a "Personal Info" card SHALL group title, first name, middle name, last name, and company

#### Scenario: Address card hidden when all address fields nil
- **WHEN** an Identity item has no address fields
- **THEN** the "Address" card SHALL NOT be rendered

#### Scenario: Notes card hidden when empty
- **WHEN** an Identity item has no notes
- **THEN** the "Notes" card SHALL NOT be rendered

#### Scenario: Custom fields card hidden when empty
- **WHEN** an Identity item has no custom fields
- **THEN** the "Custom Fields" card SHALL NOT be rendered

### Requirement: Secure Note detail uses card layout
The system SHALL display Secure Note fields in card sections.

#### Scenario: Secure Note renders in a card
- **WHEN** a Secure Note item is displayed
- **THEN** the note body SHALL be wrapped in a "Note" card

#### Scenario: Secure Note custom fields card hidden when empty
- **WHEN** a Secure Note item has no custom fields
- **THEN** the "Custom Fields" card SHALL NOT be rendered

### Requirement: SSH Key detail uses card layout
The system SHALL display SSH Key fields in card sections.

#### Scenario: SSH Key fields rendered in a card
- **WHEN** an SSH Key item is displayed
- **THEN** the public key, private key, and fingerprint fields SHALL be grouped in a "Key" card

#### Scenario: SSH Key notes card hidden when empty
- **WHEN** an SSH Key item has no notes
- **THEN** the "Notes" card SHALL NOT be rendered

#### Scenario: SSH Key custom fields card hidden when empty
- **WHEN** an SSH Key item has no custom fields
- **THEN** the "Custom Fields" card SHALL NOT be rendered

### Requirement: Existing copy-on-hover behaviour preserved
All field rows within cards SHALL retain the existing copy-on-hover button and masked-field toggle behaviour provided by `FieldRowView`.

#### Scenario: Copy button available inside card
- **WHEN** the user hovers over a field row inside a `DetailSectionCard`
- **THEN** the copy button SHALL appear and SHALL copy the field value to the clipboard when clicked
