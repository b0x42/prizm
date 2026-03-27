## ADDED Requirements

### Requirement: Sidebar footer shows vault name and sync status
The system SHALL display a persistent footer at the bottom of the sidebar column containing the authenticated account's vault name (from `Account.name`, falling back to `Account.email`) on the left and a sync status indicator on the right. The footer SHALL always be visible while the vault browser is shown, even when the item list is scrolled.

#### Scenario: Footer shows vault name
- **WHEN** the vault browser is visible
- **THEN** the sidebar footer SHALL show the account name (or email if name is nil) in the left-hand area using the `listSubtitle` typography token

#### Scenario: Footer is always visible regardless of list scroll position
- **WHEN** the user scrolls the sidebar item list
- **THEN** the footer remains anchored to the bottom of the sidebar column

---

### Requirement: Sync status indicator reflects live SyncService state
The footer sync indicator SHALL reflect the current `SyncService.state`:
- `.idle` → no icon shown (indicator area is empty)
- `.syncing` → animated `arrow.clockwise` SF Symbol rotating continuously
- `.error` → `exclamationmark.triangle.fill` SF Symbol in red, tappable

#### Scenario: No icon shown in idle state
- **WHEN** `SyncService.state` is `.idle`
- **THEN** the sync indicator area in the footer is empty

#### Scenario: Spinner shown and animating while syncing
- **WHEN** `SyncService.state` is `.syncing`
- **THEN** an `arrow.clockwise` icon is shown with a continuous rotation animation

#### Scenario: Red error icon shown on sync failure
- **WHEN** `SyncService.state` is `.error`
- **THEN** a red `exclamationmark.triangle.fill` icon is shown in the footer indicator area

---

### Requirement: Tapping the error icon opens a sync error sheet
The system SHALL open a modal sheet when the user taps the red error icon in the sidebar footer. The sheet SHALL display the localised error message from `SyncService.lastError`. The sheet SHALL include a single **Dismiss** button. Dismissing the sheet SHALL call `SyncService.clearError()`, returning the indicator to the idle state (no icon).

#### Scenario: Tapping error icon opens sheet with error message
- **WHEN** the user taps the red `exclamationmark.triangle.fill` icon
- **THEN** a sheet is presented showing the localised error message

#### Scenario: Dismissing the sheet clears the error
- **WHEN** the user taps the Dismiss button in the error sheet
- **THEN** the sheet is dismissed, `SyncService.clearError()` is called, and the footer indicator returns to the idle (no icon) state
