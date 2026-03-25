## Requirements

### Requirement: User can log in to a self-hosted Bitwarden or Vaultwarden server
The system SHALL provide a login screen with a server URL field, email field, and master password field. The server URL field SHALL be empty by default with a placeholder ("https://vault.example.com"). There SHALL be no default cloud server. The app SHALL derive all service endpoints (API, identity, icons) from the base URL. TOTP two-factor authentication SHALL be supported as the only 2FA method in v1.

#### Scenario: Login screen shows required fields
- **WHEN** the app is launched with no stored account
- **THEN** a server URL field, email field, and master password field are visible; the server URL field is empty with a placeholder

#### Scenario: Server URL validated on submission
- **WHEN** the user submits with an invalid server URL (missing scheme, malformed)
- **THEN** login is blocked and a clear inline error message is shown; trailing slashes are stripped from valid URLs

#### Scenario: Successful login
- **GIVEN** a valid self-hosted server URL and correct credentials
- **WHEN** the user confirms
- **THEN** the app transitions to a full-screen progress view ("Syncing vault…", "Decrypting…") and then to the vault browser

#### Scenario: Invalid password
- **WHEN** the user enters an incorrect master password
- **THEN** an inline error is shown and the user may retry without closing the app

#### Scenario: Server unreachable
- **WHEN** the server cannot be reached
- **THEN** a clear error explains the server is unreachable and prompts the user to check the address

#### Scenario: Empty fields submitted
- **WHEN** the user submits with an empty email or password
- **THEN** the field is highlighted with a validation message before any network request

#### Scenario: TOTP two-factor authentication required
- **WHEN** the server responds with a TOTP challenge
- **THEN** a TOTP input prompt is shown with a "Remember this device" checkbox (defaulting to unchecked); the checkbox suppresses future 2FA prompts for this device when checked

#### Scenario: Unsupported 2FA method
- **WHEN** the server requires a non-TOTP 2FA method
- **THEN** a clear message explains the limitation

---

### Requirement: User can unlock the vault without a full login
The system SHALL provide an unlock screen for returning users. The unlock screen SHALL display the stored account email as read-only. The vault SHALL decrypt locally using the stored encrypted keys — no network request for the KDF step. A re-sync SHALL be performed after unlock to refresh vault data. A "Sign in with a different account" option SHALL be provided.

#### Scenario: Unlock with correct password
- **GIVEN** the app is reopened with a stored locked session
- **WHEN** the user enters the correct master password
- **THEN** the app decrypts locally, re-syncs, and shows the vault browser

#### Scenario: Unlock with incorrect password
- **WHEN** the user enters an incorrect master password
- **THEN** an inline error is shown; the user may retry

#### Scenario: Switch to different account
- **WHEN** the user selects "Sign in with a different account"
- **THEN** all stored session data is cleared and the login screen is shown

#### Scenario: Vault locks on quit
- **GIVEN** the vault is unlocked and the user quits the app
- **WHEN** the app is relaunched
- **THEN** the vault is locked and the unlock screen is shown

---

### Requirement: User can browse their vault in a three-pane layout
The system SHALL display a `NavigationSplitView` with a sidebar (categories + counts), a middle item list, and a detail pane. The sidebar SHALL be organised into two sections: *Menu Items* (All Items, Favorites) and *Types* (Login, Card, Identity, Secure Note, SSH Key), each with a live item count. Soft-deleted items (Trash) SHALL be excluded from all views in v1.

#### Scenario: Sidebar shows all categories with counts
- **WHEN** the vault browser opens
- **THEN** the sidebar shows both sections; each entry displays its item count; entries are shown even when the count is zero

#### Scenario: Selecting a sidebar category updates the item list
- **WHEN** the user selects a sidebar entry
- **THEN** the middle pane shows only items belonging to that category; the detail pane resets to its empty state

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

---

### Requirement: Secret fields are masked with a reveal toggle
The system SHALL mask password, card number, security code, and SSH private key fields by default showing exactly 8 bullet dots (••••••••) regardless of actual value length. A reveal toggle SHALL show the plaintext value. All fields SHALL reset to masked state when the user navigates to a different item. Additionally, holding the Option (⌥) key SHALL temporarily reveal all masked fields; releasing the key SHALL immediately re-mask them without changing the toggle state.

#### Scenario: Masked field shows exactly 8 dots
- **WHEN** a secret field renders in its masked state
- **THEN** exactly 8 bullet dots are shown regardless of the actual value length

#### Scenario: Reveal toggle shows plaintext
- **WHEN** the user clicks the reveal button
- **THEN** the actual plaintext value is shown; clicking again returns to the masked state

#### Scenario: Navigation resets all reveals
- **WHEN** the user selects a different item
- **THEN** all previously revealed fields on the previous item return to their masked state

#### Scenario: Option key peek reveals masked fields
- **WHEN** the user holds the Option (⌥) key while a masked field is visible
- **THEN** the field SHALL display its plaintext value without changing the toggle state

#### Scenario: Releasing Option key re-masks fields
- **GIVEN** the Option key is held and masked fields are showing plaintext via peek
- **WHEN** the user releases the Option key
- **THEN** all fields SHALL return to their prior state (masked if toggle was hidden, revealed if toggle was revealed)

---

### Requirement: Field action buttons appear on hover
The system SHALL follow a hover-reveal pattern for action buttons (copy, reveal, open in browser): buttons are hidden by default and appear only when the pointer is over the field row. The hovered row SHALL receive a background highlight.

#### Scenario: Action buttons appear on row hover
- **WHEN** the user moves the pointer over a field row
- **THEN** the row is highlighted and available action buttons appear

#### Scenario: Action buttons hide on pointer leave
- **WHEN** the pointer leaves the row
- **THEN** action buttons are hidden again

#### Scenario: Login URIs — copy and open in browser
- **WHEN** the user hovers over a URI field row on a Login item
- **THEN** both a Copy button and an Open in Browser button appear; clicking Open in Browser opens the URL in the system default browser

#### Scenario: Multiple URIs shown as independent rows
- **GIVEN** a Login item with multiple URIs
- **WHEN** the detail pane renders
- **THEN** each URI is shown as a separate field row with its own copy and open-in-browser actions

---

### Requirement: Copied secrets are automatically cleared from the clipboard
The system SHALL clear copied secret values from the clipboard no more than 30 seconds after copying. A new copy SHALL cancel the previous 30-second timer and start a fresh countdown. Clipboard auto-clear is best-effort on app quit.

#### Scenario: Clipboard auto-clears after 30 seconds
- **WHEN** the user copies a secret field value
- **THEN** the value is removed from the clipboard within 30 seconds

#### Scenario: New copy resets the timer
- **WHEN** the user copies a second value before the first timer expires
- **THEN** the first timer is cancelled and a new 30-second timer starts for the new value

---

### Requirement: Custom fields render according to their subtype
Text custom fields SHALL show a plain copyable value. Hidden fields SHALL show a masked value with reveal toggle and copy. Boolean fields SHALL show a read-only checkbox. Linked fields SHALL display the name of the native field they reference with no copy or resolve action.

---

### Requirement: Real-time search filters the item list within the active category
The system SHALL provide search via the native `.searchable(text:placement:prompt:)` modifier with `.sidebar` placement on the content column. Search SHALL filter the item list in real time on every keystroke, scoped to the currently selected sidebar category.

Fields searched per type: Login (name, username, URIs, notes), Card (name, cardholderName, notes), Identity (name, firstName, lastName, email, company, notes), Secure Note (name, notes), SSH Key (name only).

When the sidebar selection changes to Trash, the search query SHALL be cleared so that no invisible filter is applied to the trash item list.

#### Scenario: Real-time filtering
- **WHEN** the user types in the search field
- **THEN** the item list immediately updates to show only matching items within the active category

#### Scenario: Empty search results
- **WHEN** the search term matches no items
- **THEN** a clear "no results" empty state is shown

#### Scenario: Clear search restores full list
- **WHEN** the user clears the search field
- **THEN** the middle pane shows all items for the active category

#### Scenario: Search query cleared on entering Trash
- **WHEN** the user selects Trash in the sidebar while a search query is active
- **THEN** the search query is cleared

---

### Requirement: Favicons fetched from the Bitwarden icon service
The system SHALL fetch favicons via `{ICONS_BASE}/{domain}/icon.png`. Fetched favicons SHALL be cached in-memory and on disk. On fetch failure or when no URI is present, a type-specific SF Symbol SHALL be shown as fallback.

---

### Requirement: Sync error banner shown on mid-session failure
If vault data cannot be refreshed during an active session, the system SHALL display a dismissible, informational error banner at the top of the content area (spanning item list and detail columns, not the sidebar). The banner SHALL use a warning-style visual treatment (system yellow tint) and compact height (≤44pt). The banner SHALL auto-dismiss when a subsequent sync succeeds. No retry button is provided.

---

### Requirement: Sign Out clears all local data
The system SHALL provide a Sign Out option in the application menu. Selecting it SHALL present a confirmation dialog warning that all locally stored session data and vault content will be cleared. On confirmation, all data is cleared and the login screen is shown completely blank (no pre-filled email or server URL).

---

## Success Criteria

- **SC-001**: New user completes login and reaches the vault browser in under 60 seconds on standard broadband.
- **SC-002**: Returning user unlocks the vault and views items in under 5 seconds from app launch.
- **SC-003**: Selecting a sidebar entry or item updates the relevant pane in ≤200ms for vaults up to 1,000 items.
- **SC-004**: 100% of copyable secret fields auto-clear from the clipboard within 30 seconds.
- **SC-005**: App remains responsive (no spinning cursor, no freeze) during vault decryption for vaults up to 1,000 items.
- **SC-006**: Authentication errors, network failures, and incorrect passwords are communicated with a clear, human-readable message in 100% of failure cases.
- **SC-007**: The three-pane layout is fully navigable by keyboard alone (Tab between panes, arrow keys in lists).
- **SC-008**: Search results update within 100ms of each keystroke for vaults up to 1,000 items.
