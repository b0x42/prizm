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

### Requirement: Last sync timestamp is displayed in the vault browser UI
The system SHALL display the last successful sync timestamp in the vault browser sidebar footer area. The display SHALL use a human-friendly relative label (e.g. "Synced 2 minutes ago"). The full ISO-8601 datetime SHALL be shown as a tooltip on hover. If no sync has occurred in this session or ever, the label SHALL read "Never synced".

#### Scenario: Relative label shown after sync
- **WHEN** the vault browser is open and a successful sync has occurred
- **THEN** the sidebar footer shows a label such as "Synced X minutes ago" (or "Synced just now" for very recent syncs)

#### Scenario: Full timestamp shown on hover
- **WHEN** the user hovers over the last-sync label
- **THEN** a tooltip displays the full date and time (ISO-8601 or locale-formatted datetime)

#### Scenario: Never synced state
- **WHEN** no successful sync timestamp is stored
- **THEN** the sidebar footer shows "Never synced"

#### Scenario: Future timestamp clamped to "just now"
- **WHEN** the stored timestamp appears to be in the future (e.g. due to clock adjustment)
- **THEN** the label displays "Synced just now" rather than a nonsensical future label

#### Scenario: Label updates live after sync completes
- **WHEN** a sync completes while the vault browser is open
- **THEN** the sidebar footer label updates to reflect the new timestamp without requiring a view reload
