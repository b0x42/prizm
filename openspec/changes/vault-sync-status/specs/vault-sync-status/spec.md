## ADDED Requirements

### Requirement: Last sync timestamp is persisted after a successful sync
The system SHALL record the date and time of the most recent successful vault sync per account. The timestamp SHALL be persisted to UserDefaults under a key scoped to the account email (e.g. `com.macwarden.lastSyncDate.<email>`) so that it survives app restarts and does not bleed across accounts. The timestamp SHALL be updated each time a sync completes successfully and SHALL NOT be updated when a sync fails.

#### Scenario: Timestamp written on successful sync
- **WHEN** a vault sync completes successfully
- **THEN** the last-sync timestamp is saved to UserDefaults with the current date and time

#### Scenario: Timestamp not written on failed sync
- **WHEN** a vault sync fails (network error, auth error, or any other error)
- **THEN** the previously stored last-sync timestamp is unchanged

#### Scenario: Timestamp survives app restart
- **WHEN** the app is relaunched after a successful sync
- **THEN** the persisted last-sync timestamp is readable and matches the value written at sync completion

#### Scenario: No timestamp before first sync
- **WHEN** the app is launched for the first time with no stored timestamp
- **THEN** the timestamp is nil and no stale value is shown

---

### Requirement: Last sync timestamp is displayed at the bottom of the sidebar
The system SHALL display the last successful sync timestamp pinned to the very bottom of the vault browser sidebar, below all list content and always visible regardless of scroll position. The element SHALL be hidden when the vault is locked. The element SHALL use a human-friendly relative label that updates over time, evaluated in the user's local timezone:
- 0–59 seconds ago → "Synced just now"
- 60 seconds–59 minutes ago → "Synced X minute(s) ago"
- 1–23 hours ago → "Synced X hour(s) ago"
- Previous calendar day (local timezone) → "Synced yesterday"
- Older, same year → "Synced [Month Day]" (e.g. "Synced Mar 26")
- Older, different year → "Synced [Month Day, Year]" (e.g. "Synced Mar 26, 2025")

If no sync has occurred, the element SHALL read "Never synced". The display SHALL use `Typography.listSubtitle` styling to remain visually unobtrusive.

#### Scenario: Sync status shown at sidebar bottom
- **WHEN** the vault browser is open
- **THEN** a sync status element is pinned to the very bottom of the sidebar, below all vault list items, always visible

#### Scenario: Relative label shown just after sync
- **WHEN** a sync completed less than 1 minute ago
- **THEN** the label reads "Synced just now"

#### Scenario: Relative label shown at exactly 1 minute
- **WHEN** a sync completed 60–119 seconds ago
- **THEN** the label reads "Synced 1 minute ago"

#### Scenario: Relative label shown minutes after sync
- **WHEN** a sync completed 2–59 minutes ago
- **THEN** the label reads "Synced X minutes ago"

#### Scenario: Relative label shown hours after sync
- **WHEN** a sync completed 1–23 hours ago
- **THEN** the label reads "Synced X hours ago"

#### Scenario: Relative label shows "yesterday" for previous calendar day
- **WHEN** the sync timestamp falls on the previous calendar day in the user's local timezone
- **THEN** the label reads "Synced yesterday"

#### Scenario: Relative label shown for older syncs, same year
- **WHEN** a sync occurred before yesterday and within the current calendar year
- **THEN** the label reads "Synced [Month Day]" (e.g. "Synced Mar 26")

#### Scenario: Relative label shown for older syncs, different year
- **WHEN** a sync occurred in a previous calendar year
- **THEN** the label reads "Synced [Month Day, Year]" (e.g. "Synced Mar 26, 2025")

#### Scenario: Never synced state
- **WHEN** no successful sync timestamp is stored
- **THEN** the sidebar bottom element shows "Never synced"

#### Scenario: Future timestamp clamped to "just now"
- **WHEN** the stored timestamp appears to be in the future (e.g. due to clock adjustment)
- **THEN** the label displays "Synced just now"

#### Scenario: Element hidden when vault is locked
- **WHEN** the vault is locked
- **THEN** the sync status element is not visible

#### Scenario: Label updates live after sync completes
- **WHEN** a sync completes while the vault browser is open
- **THEN** the sidebar bottom label updates to reflect the new timestamp without requiring a view reload
