## MODIFIED Requirements

### Requirement: Item list row styling (MODIFIED)
Item list rows SHALL use `.headline` font (13pt semibold) for the item name and `.callout` font (12pt) for the subtitle. Rows SHALL have 8pt vertical padding and 3pt spacing between name and subtitle. The favicon/type icon SHALL be 26pt and vertically centered. HStack spacing SHALL be 10pt.

#### Scenario: Item name uses headline font
- **WHEN** an item row is displayed in the list
- **THEN** the item name SHALL render in `.headline` font

#### Scenario: Subtitle uses callout font
- **WHEN** an item row has a subtitle
- **THEN** the subtitle SHALL render in `.callout` font with secondary color

#### Scenario: Rows have adequate vertical spacing
- **WHEN** the item list is displayed
- **THEN** each row SHALL have 8pt vertical padding, 3pt spacing between name and subtitle, and a 26pt vertically-centered icon

---

### Requirement: Item list grouped by letter (ADDED)
The item list SHALL group items into alphabetical sections with sticky letter headers (A, B, C … Z). Items whose names begin with a non-letter character SHALL be grouped under "#". Section grouping SHALL be applied to all sidebar categories including search results.

#### Scenario: Items grouped under correct letter
- **WHEN** the item list is displayed
- **THEN** each item SHALL appear under the section header matching the first letter of its name (uppercased)

#### Scenario: Non-letter names grouped under #
- **WHEN** an item name begins with a digit or symbol
- **THEN** the item SHALL appear under the "#" section header
