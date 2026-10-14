# Feature Specification: TOTP Verification Codes

**Feature Branch**: `001-totp-verification-codes`

**Created**: 2026-10-14

**Status**: Draft

**Input**: User description: "I want to be able to list all items with TOTP with current code." Assessment: `.specify/assessments/totp-code-list/` (verdict: go; the requester wants both per-item display and the cross-item list).

## Clarifications

### Session 2026-10-14

- Q: In what order should the rows in the Verification Codes list appear? → A: Alphabetical by item name
- Q: Should the existing search box filter the Verification Codes list by item name? → A: Yes
- Q: Should codes be shown grouped, such as "123 456"? → A: Yes, grouped in the middle; the copied value has no space
- Q: Should a code get a visual warning in its last few seconds? → A: Yes, the time indicator changes appearance in the last 5 seconds

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the current code for one item (Priority: P1)

A user opens a Login item that has a stored TOTP seed and sees the currently valid six-digit code with the time left before it changes. They copy the code and use it to sign in to the service. When the code rotates, the new one appears without the user doing anything.

**Why this priority**: This is the core capability and the roadmap's "TOTP code display". It is useful on its own and the list in Story 2 builds on it.

**Independent Test**: Sync a vault containing a Login with a known seed, open the item, and compare the shown code with a reference authenticator using the same seed at the same moment.

**Acceptance Scenarios**:

1. **Given** a Login item with a valid TOTP seed, **When** the user opens it, **Then** the current code and the seconds remaining are shown.
2. **Given** the item is open, **When** the code's validity period ends, **Then** the new code replaces the old one without user action.
3. **Given** the item is open, **When** the user chooses to copy the code, **Then** the current code is on the clipboard and is cleared automatically within 30 seconds.
4. **Given** a Login item without a TOTP seed, **When** the user opens it, **Then** no code section appears.
5. **Given** an item whose seed cannot be used to produce a code, **When** the user opens it, **Then** the item shows a clear message that the code is unavailable, and no wrong code is shown.

---

### User Story 2 - List every item that has a code (Priority: P2)

A user opens a dedicated "Verification Codes" entry in the sidebar and sees every item that has a TOTP seed, one row per item, each with the item name, the current code, and the time remaining. They copy a code straight from the row.

**Why this priority**: This is what the requester asked for. It depends on Story 1 for code display, and it carries the main exposure question (many live codes at once).

**Independent Test**: Sync a vault with several items with seeds and several without. Open the list and check that exactly the items with seeds appear, each with a correct code.

**Acceptance Scenarios**:

1. **Given** a vault with N items that have seeds, **When** the user opens the list, **Then** exactly those N items appear, each with its current code and time remaining.
2. **Given** the list is open, **When** a code's period ends, **Then** that row updates to the new code without user action.
3. **Given** the list is open, **When** the user copies a code from a row, **Then** that item's current code is on the clipboard and is cleared automatically within 30 seconds.
4. **Given** an item in the trash that has a seed, **When** the user opens the list, **Then** that item does not appear.
5. **Given** the vault has no items with seeds, **When** the user opens the list, **Then** an empty state explains that no items have a verification code.
6. **Given** the list is open, **When** the user selects a row, **Then** the full item opens in the detail pane.

---

### User Story 3 - Codes disappear when the vault locks (Priority: P2)

A user locks the vault, by hand or by the app's existing lock behavior, while codes are on screen. All codes are removed and none can be seen or generated until the vault is unlocked again.

**Why this priority**: Codes are secrets. Showing them after lock would break the app's core security promise.

**Independent Test**: Open the list, lock the vault, and confirm that no code is visible and that unlocking shows current codes again.

**Acceptance Scenarios**:

1. **Given** codes are visible, **When** the vault locks, **Then** no code remains visible.
2. **Given** the vault was locked and is unlocked again, **When** the user returns to a code view, **Then** the codes shown are current, not stale ones from before the lock.

---

### Edge Cases

- A seed in a format the app does not support: the item appears with an "unavailable" message instead of a code (see FR-008). It still appears in the list so the user can see it exists.
- The device clock is wrong: codes will not match the service. The app shows codes based on the device clock and does not claim to correct it.
- A code is about to expire while the user is copying it: the copied value is the code that was displayed at the moment of the copy action.
- A very large number of items with seeds: the list stays usable and every row keeps updating on time.
- The app window is hidden or the app is in the background: codes are not shown, and when the window returns, the codes shown are current.
- A seed that is empty or contains only whitespace is treated as no seed.
- Screen readers: rapidly changing codes must not flood spoken output (see FR-014).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST show, for a Login item with a usable TOTP seed, the current code (grouped as in FR-005) and the time remaining until it changes.
- **FR-001a**: The time indicator MUST change appearance during the last 5 seconds of a code's validity, in both the item view and the list. The change MUST NOT rely on color alone.
- **FR-002**: The system MUST replace a displayed code with the next one when its validity period ends, without user action.
- **FR-003**: The system MUST produce codes that match those of any standards-conforming authenticator for the same seed at the same moment.
- **FR-004**: The system MUST provide a "Verification Codes" entry in the sidebar that lists every non-trashed item with a TOTP seed, one row per item.
- **FR-004a**: Rows MUST be sorted alphabetically by item name.
- **FR-004b**: The existing search MUST filter the Verification Codes list by item name.
- **FR-005**: Each row MUST show the item name, the current code, and the time remaining. Six-digit codes MUST be displayed grouped in the middle (for example "123 456"); the copied value MUST contain no space.
- **FR-006**: The user MUST be able to copy an item's current code from the item view and from a list row. A copied code MUST be cleared from the clipboard automatically within 30 seconds.
- **FR-007**: Selecting a row MUST open that item in the detail pane.
- **FR-008**: When an item's seed cannot be used, the system MUST show a clear "unavailable" message for it and MUST NOT show a code. Supported seeds are the standard six-digit, 30-second form given either as a plain secret or as a standard `otpauth` link, including links that set a different digit count, period, or hash algorithm.
- **FR-009**: Items in the trash MUST NOT appear in the list.
- **FR-010**: The system MUST remove all visible codes when the vault locks, and MUST NOT retain generated codes after lock.
- **FR-011**: The system MUST NOT generate or refresh codes while the vault is locked or while no code view is on screen.
- **FR-012**: The system MUST NOT log seeds or codes.
- **FR-013**: The list and the per-item display MUST follow the app's existing visual styles and spacing.
- **FR-014**: Code text MUST be readable by screen readers, and rotation MUST NOT trigger a new spoken announcement every period unless the user is focused on that code.
- **FR-015**: Codes MUST be visible by default in both the item view and the list while the vault is unlocked and the code view is on screen.
- **FR-016**: The existing "Copy Code" command MUST copy the current generated code. Copying the stored secret MUST no longer be offered anywhere, and no shortcut is assigned to it.
- **FR-017**: Items for which the app previously never displayed the seed MUST continue not to display the raw seed anywhere new; only the generated code is shown.

### Key Entities

- **Verification code**: A short-lived six-digit (or configured-length) number derived from an item's seed and the current time. It is shown, copied, and discarded; it is never stored.
- **TOTP seed**: The secret stored with a Login item. It already exists in the vault and is not edited by this feature.
- **Login item**: An existing vault item that may carry a seed. Items with a usable seed appear in the list.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every supported seed form, the displayed code matches a reference authenticator in 100% of checks across at least 20 consecutive periods.
- **SC-002**: A user can go from the sidebar to a copied code for a chosen item in under 10 seconds.
- **SC-003**: A user can see which items have verification codes in one view, without opening any item.
- **SC-004**: After a code's period ends, the new code is displayed within 1 second.
- **SC-005**: After the vault locks, no code is visible in 100% of checks, and none reappears until after unlock.
- **SC-006**: A copied code is gone from the clipboard within 30 seconds in 100% of checks.
- **SC-007**: The requester can sign in to a TOTP-protected service using only a code from Prizm.

## Assumptions

- Users already have items with TOTP seeds in a synced vault; this feature does not create, edit, or import seeds.
- The earlier decision that a stored seed is "never displayed in v1" (referenced as FR-038 in the code, definition not found) is superseded for generated codes only. Displaying the raw seed stays out of scope.
- The Steam-style seed form is not supported in this feature; such items show the "unavailable" message.
- The device clock is the time source; the app does not compensate for clock error.
- Code generation uses only the platform's vetted cryptography (Constitution §III); no new third-party cryptography is added.
- Items the user cannot currently see (for example, trashed items) are excluded from the list.
- Organization and collection item support stays whatever the vault already offers.
- No usage metrics are collected (the app has no telemetry).

## Out of Scope

- Editing, creating, scanning, or importing seeds.
- Changes to the login two-factor challenge.
- Autofill and browser integration.
- HOTP, passkeys, and other one-time methods.
