## ADDED Requirements

### Requirement: Icon-only buttons SHALL have accessibility labels
Every `Button` whose visible content is only an `Image(systemName:)` SHALL have an `.accessibilityLabel` that describes the action. The label SHALL match the existing `.help()` tooltip text where one exists.

#### Scenario: VoiceOver announces gear button
- **WHEN** VoiceOver focus lands on the settings gear button in the sidebar toolbar
- **THEN** VoiceOver SHALL announce "Settings, button"

#### Scenario: VoiceOver announces copy button
- **WHEN** VoiceOver focus lands on a copy button in a field row
- **THEN** VoiceOver SHALL announce "Copy [field name], button" (e.g. "Copy Username, button")

#### Scenario: VoiceOver announces reveal button
- **WHEN** VoiceOver focus lands on a reveal/hide toggle on a masked field
- **THEN** VoiceOver SHALL announce "Reveal [field name], button" or "Hide [field name], button" depending on current state

#### Scenario: VoiceOver announces favorite button
- **WHEN** VoiceOver focus lands on the star button in the detail toolbar
- **THEN** VoiceOver SHALL announce "Favorite, button" or "Unfavorite, button" depending on current state

#### Scenario: VoiceOver announces new item button
- **WHEN** VoiceOver focus lands on the plus button in the content column toolbar
- **THEN** VoiceOver SHALL announce "New Item, pop up button"

#### Scenario: VoiceOver announces delete button on attachment row
- **WHEN** VoiceOver focus lands on a delete button on an attachment row
- **THEN** VoiceOver SHALL announce "Delete, button"

#### Scenario: VoiceOver announces open button on attachment row
- **WHEN** VoiceOver focus lands on an open button on an attachment row
- **THEN** VoiceOver SHALL announce "Open, button"

#### Scenario: VoiceOver announces refresh button in password generator
- **WHEN** VoiceOver focus lands on the refresh button in the password generator
- **THEN** VoiceOver SHALL announce "Generate new password, button"

#### Scenario: VoiceOver announces new folder button
- **WHEN** VoiceOver focus lands on the folder.badge.plus button in the sidebar
- **THEN** VoiceOver SHALL announce "New Folder, button"

---

### Requirement: Accessibility hints SHALL describe non-obvious actions
Interactive controls whose purpose is not fully conveyed by the label alone SHALL have an `.accessibilityHint` describing the result of activation.

#### Scenario: Copy button has hint
- **WHEN** VoiceOver focus lands on a copy button
- **THEN** VoiceOver SHALL announce the hint "Copies to clipboard" after a pause

#### Scenario: Open URL button has hint
- **WHEN** VoiceOver focus lands on an open-URL button in a field row
- **THEN** VoiceOver SHALL announce the hint "Opens in browser" after a pause

#### Scenario: Save to Disk button has hint
- **WHEN** VoiceOver focus lands on a Save to Disk button on an attachment row
- **THEN** VoiceOver SHALL announce the hint "Saves file to your chosen location" after a pause

---

### Requirement: Stateful controls SHALL announce current value
Controls that toggle between states SHALL use `.accessibilityValue` to announce the current state.

#### Scenario: Favorite star announces value
- **WHEN** VoiceOver focus lands on the favorite star button
- **THEN** VoiceOver SHALL announce the value "Favorited" when the item is a favorite, or "Not favorited" when it is not

#### Scenario: Favorite star value updates on toggle
- **GIVEN** VoiceOver focus is on the favorite star button
- **WHEN** the user activates the button
- **THEN** VoiceOver SHALL announce the updated value

---

### Requirement: Section headers SHALL have heading traits
Section header labels in the detail view (e.g. "Credentials", "Websites", "Notes", "Attachments", "Custom Fields") SHALL have `.accessibilityAddTraits(.isHeader)` so VoiceOver users can navigate by heading.

#### Scenario: VoiceOver heading navigation finds section headers
- **WHEN** a VoiceOver user presses VO+Command+H in the detail view
- **THEN** VoiceOver focus SHALL move to the next section header

#### Scenario: Section header is announced as heading
- **WHEN** VoiceOver focus lands on a section header label
- **THEN** VoiceOver SHALL announce it with the "heading" trait (e.g. "Credentials, heading")

---

### Requirement: Decorative images SHALL be hidden from accessibility tree
Images that are purely decorative and do not convey information beyond what is already available in adjacent text SHALL have `.accessibilityHidden(true)`.

#### Scenario: Favicon is hidden when item name is announced
- **WHEN** VoiceOver navigates an item row in the list
- **THEN** the favicon image SHALL NOT be announced separately; only the item name and subtitle SHALL be announced

#### Scenario: Screen icons on auth screens are hidden
- **WHEN** VoiceOver navigates the Login, Unlock, or TOTP screen
- **THEN** the large decorative icon (keyhole, shield) SHALL NOT be announced

#### Scenario: Status indicator icons in batch/confirm sheets are hidden
- **WHEN** VoiceOver navigates an attachment batch upload sheet or confirm sheet
- **THEN** status indicator icons (checkmark, xmark, warning triangle, info circle) SHALL NOT be announced separately; only the associated status text SHALL be announced

---

### Requirement: Error banners and status changes SHALL be announced to VoiceOver
When an error banner appears or sync status changes, the system SHALL post an `AccessibilityNotification.Announcement` so VoiceOver users are informed without navigating to the banner.

#### Scenario: Sync error banner is announced
- **WHEN** a sync error banner appears in the content column
- **THEN** VoiceOver SHALL announce the error message text

#### Scenario: Action error alert is announced
- **WHEN** an action error alert appears (e.g. delete failed, restore failed)
- **THEN** VoiceOver SHALL announce the error via the standard alert accessibility behaviour

#### Scenario: Sync error dismissal does not announce
- **WHEN** the user dismisses a sync error banner
- **THEN** no additional VoiceOver announcement SHALL be posted
