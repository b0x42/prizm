## ADDED Requirements

### Requirement: Last sync timestamp is persisted after a successful sync
The system SHALL record the date and time of the most recent successful vault sync. The timestamp SHALL be persisted to UserDefaults so that it survives app restarts. The timestamp SHALL be updated each time a sync completes successfully and SHALL NOT be updated when a sync fails.

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
The system SHALL display the last successful sync timestamp pinned to the very bottom of the vault browser sidebar, below all list content and always visible regardless of scroll position. The element SHALL use a human-friendly relative label that updates over time:
- Less than 1 minute ago → "Synced just now"
- 2–59 minutes ago → "Synced X minutes ago"
- 1–23 hours ago → "Synced X hours ago"
- 24–48 hours ago → "Synced yesterday"
- Older → "Synced [Month Day]" (e.g. "Synced Mar 26")

If no sync has occurred, the element SHALL read "Never synced". The display SHALL use `Typography.listSubtitle` styling to remain visually unobtrusive.

#### Scenario: Sync status shown at sidebar bottom
- **WHEN** the vault browser is open
- **THEN** a sync status element is pinned to the very bottom of the sidebar, below all vault list items, always visible

#### Scenario: Relative label shown just after sync
- **WHEN** a sync completed less than 1 minute ago
- **THEN** the label reads "Synced just now"

#### Scenario: Relative label shown minutes after sync
- **WHEN** a sync completed 2–59 minutes ago
- **THEN** the label reads "Synced X minutes ago"

#### Scenario: Relative label shown hours after sync
- **WHEN** a sync completed 1–23 hours ago
- **THEN** the label reads "Synced X hours ago"

#### Scenario: Relative label shown the day after sync
- **WHEN** a sync completed 24–48 hours ago
- **THEN** the label reads "Synced yesterday"

#### Scenario: Relative label shown for older syncs
- **WHEN** a sync completed more than 48 hours ago
- **THEN** the label reads "Synced [Month Day]" (e.g. "Synced Mar 26")

#### Scenario: Never synced state
- **WHEN** no successful sync timestamp is stored
- **THEN** the sidebar bottom element shows "Never synced"

#### Scenario: Future timestamp clamped to "just now"
- **WHEN** the stored timestamp appears to be in the future (e.g. due to clock adjustment)
- **THEN** the label displays "Synced just now"

#### Scenario: Label updates live after sync completes
- **WHEN** a sync completes while the vault browser is open
- **THEN** the sidebar bottom label updates to reflect the new timestamp without requiring a view reload
