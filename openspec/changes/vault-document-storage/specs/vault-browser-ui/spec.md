## ADDED Requirements

### Requirement: Detail pane includes an Attachments section
The vault item detail pane SHALL include an "Attachments" section rendered below all existing field cards (credentials, card details, identity, notes, custom fields, etc.) for every cipher type. The section SHALL use the standard section card layout defined in the design system (`sectionHeader` typography, `cardTop`/`cardBottom` spacing). When the cipher has attachments, each SHALL appear as a row (see `attachment-view-flow`). The section SHALL always include an "Add Attachment" button at the bottom of the card regardless of whether any attachments exist.

#### Scenario: Attachments section appears below existing field cards
- **WHEN** any vault item detail pane is displayed
- **THEN** an Attachments section SHALL be rendered below all other field cards

#### Scenario: Attachments section uses design system tokens
- **WHEN** the Attachments section is rendered
- **THEN** the section header SHALL use `Typography.sectionHeader`, section spacing SHALL use `Spacing.cardTop` and `Spacing.cardBottom`, and row padding SHALL use `Spacing.rowVertical` and `Spacing.rowHorizontal`
