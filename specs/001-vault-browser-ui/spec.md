# Feature Specification: Bitwarden macOS Client — Core Vault Browser

**Feature Branch**: `001-vault-browser-ui`
**Created**: 2026-03-13
**Status**: Draft

## Scope Boundary

**v1 is strictly read-only.** The user can view, copy, and navigate vault contents.
Creating, editing, deleting, and favoriting items are out of scope for v1.
**Touch ID, biometric unlock, auto-lock timeout, TOTP field display on vault items,
FIDO2/passkey display, and multiple account support (multi-vault) are deferred to future
versions.** Master password is the only unlock mechanism in v1. The vault locks only when
the app quits; it remains unlocked for the duration of the session. TOTP and FIDO2/passkey
fields on login items MUST be hidden entirely in v1.

Note: **TOTP login two-factor authentication is required in v1** (FR-016) — this is the
2FA prompt shown during the login flow. What is deferred is TOTP *code generation and
display* for stored vault items (FR-038).

**Additionally deferred to future versions**: master password re-prompt, password history
on login items, folder organisation (Folders sidebar section), the Trash sidebar entry,
Collections and organisation-owned ciphers, and attachment indicators. All secret fields
are accessible without re-prompt once the vault is unlocked. Soft-deleted items are
excluded from all views in v1; organisation-owned ciphers are skipped during vault sync.

**v1 supports self-hosted Bitwarden and Vaultwarden instances only.** Bitwarden cloud
(US: bitwarden.com, EU: bitwarden.eu) support is deferred to a future version. The login
screen requires the user to supply a server URL; there is no default cloud server.

---

## Clarifications

### Session 2026-03-13

- Q: When does the vault sync? → A: On login/unlock only. No background refresh or foreground-triggered re-sync in v1.
- Q: What does the TOTP field show in the detail pane? → A: Deferred to future version. TOTP fields are hidden in v1 even if present on a login item.
- Q: Should org collections appear in the sidebar? → A: Deferred to future version. Collections and organisation-owned ciphers are not supported in v1.
- Q: What does the user see while the vault is downloading and decrypting? → A: Full-screen progress indicator with status messages ("Syncing vault…", "Decrypting…") replacing the login/unlock screen until the browser is ready.
- Q: Unified performance scale target (SC-003 said 500, SC-005 said 1,000)? → A: 1,000 items across all performance criteria.
- Q: Search scope — global or category-scoped? → A: Scoped to the currently selected sidebar category.
- Q: Which server environments are supported in v1? → A: Self-hosted Bitwarden and Vaultwarden only. Bitwarden cloud (US/EU) is deferred to a future version. No client registration with Bitwarden is required for v1.
- Q: Search term behaviour when switching sidebar categories? → A: Keep the search term; re-filter results against the new category. Do not clear the search bar.
- Q: Should empty sidebar entries be shown? → A: Trash, Folders, and Collections are deferred to future versions. The remaining entries (All Items, Favorites, and all Type entries) are always shown even when empty. Empty state shown in the middle pane when selected.
- Q: Where is the attachment indicator shown? → A: Deferred to future version. No attachment indicator in v1.
- Q: Password history sort order? → A: Deferred to future version. Password history is not displayed in v1.
- Q: Password history entry date format? → A: Deferred to future version.
- Q: "Last synced" timestamp format? → A: Relative (e.g. "2 minutes ago"). Update to absolute on hover if needed — deferred; relative only for v1.
- Q: Item name empty — show placeholder or leave blank? → A: Leave blank (no "[No Name]" placeholder).
- Q: Identity subtitle when both first and last name are empty? → A: Fall back to email address. If email also empty, show blank subtitle.
- Q: SSH Key subtitle when fingerprint is absent? → A: Show "[No fingerprint]".
- Q: Clipboard cleared immediately on vault lock/quit? → A: No — let the 30-second timer run to completion on vault lock. On app quit, the OS may cancel the timer; this is acceptable behaviour — the timer is best-effort on quit only.
- Q: TOTP two-factor retry limits? → A: Deferred to server — the server enforces account lockout; the app makes no independent limit.
- Q: Item in multiple collections — shown in all? → A: Deferred to future version. Collections are not supported in v1.
- Q: Sync failure after initial login (mid-session) — what UI? → A: Show a non-blocking error banner in the vault browser. Stale data remains visible.
- Q: Item list sort order? → A: Alphabetical by item name, case-insensitive. Applied to all sidebar selections including search results.
- Q: Should the TOTP two-factor screen offer a "Remember this device" option? → A: Yes — show a checkbox. When checked, the server suppresses 2FA prompts for this device in future logins.
- Q: Mid-session sync error banner — dismissible or persistent? Retry button? → A: Dismissible (user can close it). Informational only — no retry button in v1.
- Q: Reprompt — per item or per field? → A: Deferred to future version. Master password re-prompt is not implemented in v1. All secret fields are freely accessible once the vault is unlocked.
- Q: Row icon priority when favicon unavailable? → A: favicon → type icon (SF Symbol). Attachment presence does not affect the row icon.
- Q: Search term when switching to a category with no matching results? → A: Show empty state with search term preserved. Expected behaviour — user can edit or clear the term.
- Q: Sidebar item counts — when updated? → A: Computed once after vault sync, cached in memory for the session. Counts do not update mid-session.
- Q: Masked field dot count — exactly how many? → A: Always exactly 8 dots (••••••••). No variation per field type or value length.
- Q: App language / localisation in v1? → A: English only. All literal strings (e.g. "[No fingerprint]", "No item selected") are hard-coded English. Localisation is deferred to a future version.
- Q: After sign-out, does the login screen show the previous email/server URL? → A: No — sign-out clears all session data including email and server URL. The login screen is completely blank after sign-out.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Account Login (Priority: P1)

A first-time user (or a user who has signed out) opens the app and sees a login screen.
They enter the base URL of their self-hosted Bitwarden or Vaultwarden instance, then
their email and master password, and are granted access to their encrypted vault.

**Why this priority**: Without authentication, no other feature is accessible. This is
the entry point for all new users and the fallback after a sign-out.

**Independent Test**: Launch the app with no stored session. Enter a valid self-hosted
server URL, log in with a valid account, and reach the vault browser.

**Acceptance Scenarios**:

1. **Given** the app is launched with no stored account, **When** the login screen
   appears, **Then** a server URL field, an email field, and a master password field
   are visible; the server URL field is empty with a placeholder (e.g.
   "https://vault.example.com").
2. **Given** the login screen is visible, **When** the user enters a server URL and
   moves focus away, **Then** the URL is validated: a scheme (`https://` or `http://`)
   is required, trailing slashes are stripped, and an inline error is shown if the
   format is invalid.
3. **Given** a valid server URL and valid credentials are entered, **When** the user
   confirms, **Then** the login screen transitions to a full-screen progress view
   showing sequential status messages ("Syncing vault…", "Decrypting…"); once
   complete, the vault browser is shown.
4. **Given** the login screen is visible, **When** the user enters an incorrect
   password, **Then** an inline error message is shown and the user may retry without
   the app closing.
5. **Given** the login screen is visible, **When** there is no network connection,
   **Then** the app shows a clear "no connection" message and does not crash or hang.
6. **Given** the login screen is visible, **When** the user submits an empty email or
   password field, **Then** the relevant field is highlighted with a validation message
   before any network request is made.
7. **Given** a server URL is entered but the server cannot be reached, **When** the
   user attempts to log in, **Then** a clear error explains the server is unreachable
   or unrecognized, with guidance to check the address.

---

### User Story 2 — Vault Unlock (Priority: P1)

A returning user who has previously signed in opens the app. Their session is stored
locally but the vault is locked. They enter their master password to unlock and access
their vault without signing in again.

**Why this priority**: Returning users — the majority of daily interactions — should
never be required to go through the full login flow again. Unlock is the primary
day-to-day entry point.

**Independent Test**: Close and reopen the app with a stored, locked session. Enter the
master password. The vault browser appears with all items accessible.

**Acceptance Scenarios**:

1. **Given** the app is reopened with a stored locked session, **When** the user enters
   the correct master password on the unlock screen, **Then** the unlock screen
   transitions to a full-screen progress view ("Decrypting…") while the vault is
   decrypted locally; the vault browser is shown once complete.
2. **Given** the unlock screen is visible, **When** the user enters an incorrect master
   password, **Then** an inline error is shown and the attempt is logged; the user may
   retry.
3. **Given** the unlock screen is visible, **When** the user chooses "Sign in with a
   different account", **Then** the stored session is cleared and the login screen is
   shown.
4. **Given** the vault is unlocked and the user quits the app, **When** the app is
   relaunched, **Then** the vault is locked and the unlock screen is shown.

---

### User Story 3 — Three-Pane Vault Browser (Priority: P1)

An authenticated user with an unlocked vault navigates their items through a
three-column layout: a left sidebar organised into sections, a middle column listing
items within the selected category, and a right detail pane showing the full content
of the selected item.

**Why this priority**: This is the entire purpose of the v1 client — browsing and
reading vault contents. Without it there is no usable product.

**Independent Test**: With a vault containing items across categories and folders,
select each sidebar entry in turn, select items from the list, and confirm the correct
details appear in the detail pane. Deliverable: user can find and read any vault item.

**Acceptance Scenarios**:

1. **Given** the vault is unlocked, **When** the vault browser opens, **Then** the
   left sidebar shows two named sections:
   - *Menu Items*: All Items, Favorites — each with item count
   - *Types*: Login, Card, Identity, Secure Note, SSH Key — each with item count
2. **Given** a sidebar entry is selected, **When** the middle pane renders, **Then**
   only items belonging to that selection are listed; each row shows the item's
   favicon (or type-icon fallback), its name, a type-specific subtitle, and a
   favorite star indicator if the item is marked as favorite:
   - *Login*: subtitle = username
   - *Card*: subtitle = `*` + last 4 digits of card number
   - *Identity*: subtitle = first name + space + last name (e.g. "John Doe")
   - *Secure Note*: subtitle = first 30 characters of note body, truncated with `…`
   - *SSH Key*: subtitle = key fingerprint
3. **Given** no item is selected in the middle pane, **When** the detail pane renders,
   **Then** a clear "No item selected" empty state is shown.
4. **Given** an item is selected in the middle pane, **When** the right detail pane
   renders, **Then** all fields for that item type are shown along with the item's
   creation date and last-modified date:
   - *Login*: username, password (masked), URIs (one row per URI), notes, custom
     fields (TOTP, FIDO2/passkeys, and password history hidden — deferred to future version)
   - *Card*: cardholder name, number (masked), brand, expiry (combined MM/YYYY),
     security code (masked), notes, custom fields
   - *Identity*: all personal, contact, and address fields, notes, custom fields
   - *Secure Note*: note body, custom fields
   - *SSH Key*: public key, fingerprint (both visible); private key masked by default
5. **Given** the detail pane is showing an item, **When** the user moves the pointer
   over a field row, **Then** the row is highlighted and any available action buttons
   (copy, reveal, open in browser) appear; **When** the pointer leaves the row,
   **Then** the buttons are hidden again.
6. **Given** the detail pane shows a Login item with one or more URIs, **When** the
   user hovers over a URI field row, **Then** both a Copy button and an Open in
   Browser button appear; clicking Open in Browser opens the URL in the system default
   browser.
7. **Given** a Login item has multiple URIs, **When** the detail pane renders,
   **Then** each URI is shown as a separate field row, each independently copyable
   and openable.
8. **Given** the detail pane shows a masked field (password, card number, security
   code, private key), **When** the user clicks the reveal button, **Then** the
   actual plaintext value is shown; clicking again returns the field to its masked
   state (exactly 8 bullet dots — not the actual character count).
9. **Given** the user navigates from one item to another, **When** the new item's
   detail pane renders, **Then** all previously revealed fields are masked again
   automatically.
10. **Given** the detail pane shows custom fields, **When** each custom field renders,
    **Then** the display matches the field's subtype:
    - *Text*: plain label + value + copy button
    - *Hidden*: label + masked value + reveal toggle + copy button
    - *Boolean*: label + read-only checkbox/toggle
    - *Linked*: label + the name of the native field it references (no copy action)
11. **Given** the detail pane shows a copyable field (password, username, URL, card
    number, security code, private key, text/hidden custom field), **When** the user
    clicks the copy button, **Then** the value is copied to the clipboard and the
    clipboard is automatically cleared after 30 seconds.
12. **Given** a sidebar entry contains no items, **When** it is selected, **Then** the
    middle pane shows a clear empty-state message.
13. **Given** the vault contains up to 1,000 items, **When** a category is selected,
    **Then** the list renders and is scrollable without perceptible lag.
14. **Given** the Favorites sidebar entry is selected, **When** the middle pane
    renders, **Then** only items the user has previously marked as favorite (in any
    Bitwarden client) are shown.

---

### User Story 4 — Search (Priority: P1)

A user with an unlocked vault wants to quickly find a specific item without manually
browsing categories. They type in a search bar and the item list immediately filters
to matching results.

**Why this priority**: A vault without search is barely usable beyond a handful of
items. Most users will search first, browse second.

**Independent Test**: With a vault containing items across multiple categories, type
a partial item name or username into the search bar. Confirm only matching items
appear instantly. Value delivered: user can locate any item in seconds.

**Acceptance Scenarios**:

1. **Given** the vault browser is open, **When** the user types in the search bar,
   **Then** the middle pane immediately filters to show only items within the
   currently selected sidebar category whose name, username, URL, or notes contain
   the search term (case-insensitive).
2. **Given** a search is active, **When** the user selects a result in the middle
   pane, **Then** the full item detail is shown in the right pane as normal.
3. **Given** a search is active, **When** the search term matches no items, **Then**
   a clear "no results" empty state is shown in the middle pane.
4. **Given** a search is active, **When** the user clears the search bar, **Then**
   the middle pane returns to showing all items for the currently selected sidebar entry.
5. **Given** a search is active, **When** the user switches to a different sidebar
   category, **Then** the search term is preserved and the middle pane re-filters
   results against the new category. The search bar is not cleared.
6. **Given** the user is typing a search term, **When** each character is entered,
   **Then** results update in real time with no perceptible delay.

---

### Edge Cases

- What happens when the vault sync fails mid-session (stale data shown, error surfaced)?
- How does the app behave when the Bitwarden server is unreachable after initial login?
- What if a vault item has no name or empty required fields?
- What if a login item has no associated URL — which icon is shown as fallback?
- What if a search term matches items across multiple types — are they all shown together?
- What if the user enters a self-hosted URL without a scheme? *(deferred to future release)*
- What if a self-hosted server uses a self-signed TLS certificate? *(deferred to future release)*

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The login screen MUST display a server URL input field, an email field,
  and a master password field. The server URL field MUST be empty by default with a
  descriptive placeholder (e.g. "https://vault.example.com"). There is no default
  cloud server. Bitwarden cloud (US/EU) support is deferred to a future version.
- **FR-001a**: The app MUST automatically derive all service endpoints (API, identity,
  icons) from the entered base server URL. Optionally, the user MAY override individual
  service URLs (API, identity, icons) for advanced configurations.
- **FR-001b**: The server URL MUST be validated on focus-loss and at login time: it
  must be a syntactically valid URL including a scheme (`https://` or `http://`);
  trailing slashes MUST be stripped. If the URL is invalid, login MUST be blocked with
  a clear inline error message. Automatic scheme inference and self-signed certificate
  support are out of scope for v1.
- **FR-001c**: On successful authentication against the configured server, the vault
  is downloaded, decrypted, and the vault browser is shown. Both self-hosted Bitwarden
  and Vaultwarden instances MUST be supported.
- **FR-002**: The app MUST store the authenticated session securely so that subsequent
  launches present an unlock screen rather than the full login flow.
- **FR-003**: The app MUST provide an unlock screen that accepts the master password to
  decrypt the locally stored vault without a network request. The unlock screen MUST
  display the stored account email address as read-only text, so the user knows which
  account they are unlocking.
- **FR-005**: The vault MUST lock when the app quits. While the app is running the
  vault remains unlocked for the full session. Auto-lock on idle and configurable
  timeout are out of scope for v1.
- **FR-006**: The left sidebar MUST be organised into two named sections:
  *Menu Items* (All Items, Favorites) and *Types* (Login, Card, Identity,
  Secure Note, SSH Key). Each entry MUST display a live item count.
  Folders, Collections, and the Trash sidebar entry are deferred to a future version.
- **FR-007**: Selecting any sidebar entry MUST update the middle pane to show only
  items belonging to that selection.
- **FR-008**: Selecting an item in the middle pane MUST update the right detail pane
  with the full item content for that item's type.
- **FR-009**: Each item row in the middle pane MUST display the website's favicon as
  its icon; when no favicon is available, a generic type icon MUST be shown as
  fallback.
- **FR-010**: Password fields in the detail pane MUST be masked by default and
  revealable on explicit user action.
- **FR-011**: All copyable fields MUST provide a one-click copy action; clipboard
  content containing a secret MUST be automatically cleared after no more than
  30 seconds. On app quit, the timer is best-effort — the OS may cancel the Task
  before it fires; this is acceptable.
- **FR-012**: The app MUST provide a persistent search bar that filters the item list
  in real time, scoped to the currently selected sidebar category. Search always operates
  on the items already in the active category — e.g. when Favorites is selected, only
  favorites are searched; the search term does not broaden the scope to the full vault.
  When the user switches sidebar categories, the search term MUST be preserved and results
  MUST be re-filtered against the new category. The search bar MUST NOT be cleared on
  category change. Fields matched per item type:
  - *Login*: name, username, URIs, notes
  - *Card*: name, cardholder name, notes
  - *Identity*: name, first name, last name, email, company, notes
  - *Secure Note*: name, notes
  - *SSH Key*: name only
- **FR-013**: The app MUST display a clear error state when authentication fails,
  network is unavailable, the master password is incorrect, or the configured server
  is unreachable or unrecognized — with actionable guidance for the user. The error
  MUST indicate the server could not be reached and prompt the user to verify the
  server URL.
- **FR-014**: The app MUST provide a Sign Out option accessible from the application
  menu (e.g. File or account menu). Selecting it MUST show a confirmation dialog
  warning that all locally stored session data and vault content will be cleared.
  On confirmation, the app clears all local data and returns to the login screen.
  On cancellation, nothing changes.
- **FR-015**: *(Deferred to future version.)* Attachment indicators are not shown in v1.
- **FR-016**: The app MUST support TOTP-based two-step login (authenticator app codes)
  as part of the v1 login flow. Other 2FA methods (email OTP, SMS, YubiKey, Duo) are
  out of scope for v1. If the user's account uses a non-TOTP 2FA method, the app MUST
  display a clear message explaining the limitation.
- **FR-017**: v1 is strictly read-only. Creating, editing, deleting, and toggling
  favorites on items are out of scope. No such controls MUST appear in the UI.
  Soft-deleted items (Trash) are excluded from all views in v1; the Trash sidebar
  entry is deferred to a future version.
- **FR-018**: *(Deferred to future version.)* Master password re-prompt is not
  implemented in v1. All secret fields are accessible once the vault is unlocked,
  regardless of the item's reprompt flag.
- **FR-019**: *(Deferred to future version.)* Password history is not displayed in v1.
- **FR-020**: SSH Key items MUST be displayed in the detail pane showing the public
  key and key fingerprint as visible text, and the private key masked by default
  and revealable on explicit user action.
- **FR-021**: Each item row in the middle pane MUST show a type-specific subtitle:
  Login = username; Card = `*` + last 4 digits; Identity = first name + space + last name (e.g. "John Doe");
  Secure Note = first 30 characters of note body truncated with `…`;
  SSH Key = key fingerprint.
- **FR-022**: Item rows where the cipher's favorite flag is true MUST display a
  visible favorite indicator (e.g. a star icon) in the row. This is a display-only
  indicator; toggling favorites is out of scope for v1.
- **FR-023**: Field action buttons (copy, reveal, open in browser) in the detail pane
  MUST follow a hover-reveal pattern: hidden by default, visible only when the pointer
  is over the field row. The hovered row MUST receive a background highlight.
- **FR-024**: Each URI field on a Login item MUST provide an Open in Browser action
  that opens the URL in the system default browser. This is distinct from the copy
  action on the same field.
- **FR-025**: Login items with multiple URIs MUST render each URI as an independent
  field row, each with its own copy and open-in-browser actions.
- **FR-026**: Masked fields MUST display exactly 8 bullet dots (••••••••) regardless
  of the actual value length and regardless of field type. The true character count
  MUST NOT be inferrable from the masked display.
- **FR-027**: When the user navigates away from a detail pane item to another item,
  all previously revealed fields MUST automatically return to their masked state.
- **FR-028**: *(Deferred to future version — see FR-018.)*
- **FR-029**: Custom fields MUST be rendered according to their subtype: text fields
  show a plain copyable value; hidden fields show a masked value with reveal toggle
  and copy; boolean fields show a read-only toggle/checkbox; linked fields display
  the name of the native field they reference with no copy or resolve action.
- **FR-030**: All copyable fields on Identity items (name, email, phone, address,
  SSN, passport number, licence number, etc.) MUST provide copy buttons on hover,
  consistent with Login and Card fields.
- **FR-031**: The detail pane MUST display the item's creation date and last-modified
  date for all item types.
- **FR-032**: Favicons MUST be fetched via the Bitwarden icon service endpoint
  (derived from the configured server environment), not directly from the item's
  domain. Fetched favicons MUST be cached locally.
- **FR-033**: On vault sync, the app MUST decrypt personal ciphers using the user's
  own symmetric key. Organisation-owned ciphers are excluded from v1 — they are skipped
  during sync without error (Collections and organisation support is deferred to a future
  version). Failure to decrypt an individual personal cipher MUST be handled gracefully
  without crashing or hiding other items.
- **FR-034**: The detail pane MUST display a clear empty state when no item is
  selected.
- **FR-035**: Each URI's match strategy (domain, host, starts-with, exact, regex,
  never) MUST be stored and preserved in the data model but is NOT required to be
  displayed in the v1 read-only detail view.
- **FR-036**: After successful login or unlock, the app MUST display a full-screen
  progress view with sequential status messages (e.g. "Syncing vault…",
  "Decrypting…") while the vault is being downloaded and decrypted. This screen
  MUST replace the login/unlock screen and MUST NOT show a partially loaded vault.
  If the process fails, an error MUST be shown with a retry option.
- **FR-037**: The vault MUST be synced from the server exactly once — on successful
  login or unlock. No background refresh, periodic polling, or foreground-triggered
  re-sync is performed in v1. The vault browser toolbar MUST display a right-aligned
  "Last synced: [time]" label showing when the vault was last synced.
- **FR-038**: TOTP fields on login items MUST be hidden entirely in v1, regardless
  of whether the item has a TOTP seed stored. TOTP code display is deferred to a
  future version.
- **FR-039**: The unlock screen MUST provide a "Sign in with a different account"
  option. Selecting it MUST clear all locally stored session data and return the
  user to the login screen without requiring a confirmation dialog.
- **FR-040**: All item lists (sidebar category, search results) MUST be sorted
  alphabetically by item name, case-insensitive. This order applies to all sidebar
  selections.
- **FR-041**: The "Last synced: [time]" toolbar label MUST display a relative
  timestamp (e.g. "2 minutes ago", "just now"). Absolute time display is out of
  scope for v1.
- **FR-042**: All sidebar entries (All Items, Favorites, Login, Card, Identity, Secure
  Note, SSH Key) MUST always be visible regardless of item count. An empty-state message
  is shown in the middle pane when an empty entry is selected.
- **FR-043**: *(Deferred to future version — see FR-015.)*
- **FR-044**: *(Deferred to future version — see FR-019.)*
- **FR-045**: An item whose name field is empty MUST be displayed with a blank name
  in the item list and detail pane. No placeholder text is shown.
- **FR-046**: An Identity item's subtitle in the item list MUST fall back to the
  email address if both first name and last name are empty. If email is also empty,
  the subtitle is blank.
- **FR-047**: An SSH Key item's subtitle MUST display "[No fingerprint]" when the
  key fingerprint field is absent or empty.
- **FR-048**: *(Deferred to future version — see FR-033.)*
- **FR-049**: If vault data cannot be refreshed during an active session (e.g. network
  loss after initial sync), the app MUST show a dismissible, informational error banner
  in the vault browser. The banner MUST be placed at the top of the content area (item
  list and detail columns combined), directly below the toolbar, spanning the full content
  area but NOT the sidebar — following the macOS HIG Mail.app offline-indicator pattern.
  The banner MUST use a warning-style visual treatment (system yellow tint) and compact
  height (≤44 pt). It spans both the item list and detail columns in all states —
  whether or not an item is selected. The banner MUST be closeable by the user via an
  explicit dismiss (×) button. The banner MUST auto-dismiss when a subsequent sync
  succeeds. No retry button is provided in v1. Previously synced data remains visible
  and usable.
- **FR-050**: When the login flow requires TOTP two-factor authentication, the app MUST
  display a "Remember this device" checkbox alongside the TOTP input. When checked and
  the login succeeds, the server suppresses future 2FA prompts for this device. The
  checkbox MUST default to unchecked.

### Key Entities

- **Account**: Bitwarden user identity — email, encrypted profile data, and the
  self-hosted server it belongs to.
- **Server Environment**: The configured self-hosted Bitwarden or Vaultwarden instance
  the app authenticates against. Defined by a user-supplied base URL with optional
  per-service URL overrides for API, identity, and icons. Bitwarden cloud (US/EU) is
  not supported in v1.
- **Vault**: The encrypted container of all items belonging to an account.
- **Item**: A single vault entry. Has a type (Login, Secure Note, Card, Identity,
  SSH Key), a name, a favorite flag, a soft-deleted flag (used to exclude Trash
  items; Trash sidebar is deferred), and type-specific fields.
  - *Login*: username, password, URIs (each with a match strategy), TOTP seed
    (stored but not displayed in v1), passkeys/FIDO2 credentials (stored but not
    displayed in v1), notes, custom fields.
  - *Secure Note*: note body, custom fields.
  - *Card*: cardholder name, number, brand, expiry month/year, security code,
    notes, custom fields.
  - *Identity*: title (Mr/Mrs/Ms/Mx/Dr), first/middle/last name, company, email,
    phone, address (3 lines, city, state, postal code, country), SSN, passport
    number, licence number, notes, custom fields.
  - *SSH Key*: private key, public key, key fingerprint.
- **Custom Field**: An item-level extension field with one of four types: text
  (visible), hidden (masked), boolean (checkbox), or linked (autofill alias that
  maps a named HTML field to a native item field).
- **Category**: A built-in grouping — All Items, Favorites, or by type (Login,
  Card, Identity, Secure Note, SSH Key). Trash is deferred to a future version.
- **Session**: The authenticated state linking the app to the user's Bitwarden
  account; persisted securely between launches.
- **Favicon**: A website's icon image, fetched from the Bitwarden icon service and
  cached locally per domain, used to visually identify login items in the list.
- **URI**: A URL entry on a Login item. Each URI has a value and an optional match
  strategy (domain, host, starts-with, exact, regex, never) stored in the data model
  but not displayed in the v1 read-only view.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete account login and reach the vault browser in
  under 60 seconds on a standard broadband connection.
- **SC-002**: A returning user can unlock the vault and view their items in under
  5 seconds from app launch.
- **SC-003**: Selecting any sidebar entry or item updates the corresponding pane with
  no perceptible delay (subjectively instant for vaults up to 1,000 items).
- **SC-004**: 100% of copyable secret fields auto-clear from the clipboard within
  30 seconds of copying.
- **SC-005**: The app remains responsive (no spinning cursor, no freeze) during vault
  decryption on launch for vaults containing up to 1,000 items.
- **SC-006**: Authentication errors, network failures, and incorrect passwords are
  communicated to the user with a clear, human-readable message in 100% of failure
  cases.
- **SC-007**: The three-pane layout is fully navigable by keyboard alone (tab between
  panes, arrow keys to move through lists).
- **SC-008**: Search results update within 100ms of each keystroke for vaults up to
  1,000 items.
