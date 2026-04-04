## ADDED Requirements

### Requirement: SyncService coordinates all vault sync operations
The system SHALL provide a centralised `SyncService` that is the sole entry point for triggering vault sync operations. All callers (login flow, unlock flow, mutation operations) SHALL use `SyncService.trigger()` instead of calling `SyncRepository` directly. `SyncService` SHALL own and publish the current sync state (`.idle`, `.syncing`, `.error(Error)`).

#### Scenario: Trigger from idle starts a sync
- **WHEN** `trigger()` is called while state is `.idle`
- **THEN** state transitions to `.syncing` and a background network sync begins

#### Scenario: Trigger while syncing queues one retry
- **WHEN** `trigger()` is called while state is `.syncing`
- **THEN** a single pending trigger is noted; no second concurrent sync is started; after the in-flight sync completes, one additional sync runs immediately

#### Scenario: Multiple triggers while syncing collapse to one retry
- **WHEN** `trigger()` is called three or more times while a sync is in-flight
- **THEN** exactly one additional sync runs after the in-flight sync completes; no further syncs are queued

#### Scenario: Successful sync returns to idle
- **WHEN** a sync completes without error
- **THEN** state transitions to `.idle` and `lastError` is nil

#### Scenario: Failed sync enters error state
- **WHEN** a sync throws an error
- **THEN** state transitions to `.error(error)` with the thrown error stored in `lastError`; any pending trigger is discarded

#### Scenario: Trigger in error state clears error and starts fresh sync
- **WHEN** `trigger()` is called while state is `.error`
- **THEN** state transitions to `.syncing`, `lastError` is cleared, and a new sync begins

---

### Requirement: SyncService error can be explicitly cleared
The system SHALL provide `SyncService.clearError()` that resets state from `.error` to `.idle`. Calling `clearError()` while not in the `.error` state SHALL be a no-op.

#### Scenario: clearError in error state returns to idle
- **WHEN** `clearError()` is called while state is `.error`
- **THEN** state transitions to `.idle` and `lastError` is nil

#### Scenario: clearError in non-error state is a no-op
- **WHEN** `clearError()` is called while state is `.idle` or `.syncing`
- **THEN** no state change occurs

---

### Requirement: All mutation operations trigger a background sync
The system SHALL trigger `SyncService.trigger()` after each successful vault mutation: save/edit, soft-delete, permanent delete, restore, and toggle-favorite. The trigger SHALL fire after the local in-memory store has already been updated optimistically.

#### Scenario: Sync triggered after save
- **WHEN** an item is successfully saved or edited
- **THEN** `SyncService.trigger()` is called after the local store reflects the change

#### Scenario: Sync triggered after delete
- **WHEN** an item is successfully soft-deleted or permanently deleted
- **THEN** `SyncService.trigger()` is called after the local store reflects the change

#### Scenario: Sync triggered after restore
- **WHEN** an item is successfully restored from trash
- **THEN** `SyncService.trigger()` is called after the local store reflects the change

#### Scenario: Sync triggered after toggle-favorite
- **WHEN** an item's favorite state is successfully toggled
- **THEN** `SyncService.trigger()` is called after the local store reflects the change

#### Scenario: No sync triggered on mutation failure
- **WHEN** a mutation throws an error
- **THEN** `SyncService.trigger()` is NOT called

---

### Requirement: SyncService exposes state via a Domain protocol
The system SHALL define a `SyncStatusProviding` protocol in the Domain layer exposing `state: SyncState`, `lastError: Error?`, `trigger()`, `clearError()`, and `reset()`. `SyncState` SHALL be a Domain-layer type. `SyncService` (Data layer) SHALL conform to `SyncStatusProviding`. Presentation layer code SHALL depend only on `SyncStatusProviding`, never on `SyncService` directly.

#### Scenario: Presentation depends only on Domain protocol
- **WHEN** `SidebarFooterView` or `VaultBrowserViewModel` references sync state
- **THEN** the reference SHALL be typed as `any SyncStatusProviding`, with no import of the Data layer

---

### Requirement: Sync state is reset when the vault locks
The system SHALL call `SyncService.reset()` as part of the vault lock operation. `reset()` SHALL cancel any in-flight sync task, transition state to `.idle`, and clear `lastError`. `CancellationError` from a cancelled task SHALL NOT transition state to `.error`.

#### Scenario: Lock while syncing cancels the sync cleanly
- **WHEN** the vault is locked while a background sync is in progress
- **THEN** the in-flight sync task is cancelled, state transitions to `.idle`, and no error is shown

#### Scenario: Lock while in error state clears the error
- **WHEN** the vault is locked while `SyncService.state` is `.error`
- **THEN** `reset()` clears `lastError` and transitions state to `.idle`; the red error icon SHALL NOT appear on the next unlock

#### Scenario: Post-unlock trigger starts fresh
- **GIVEN** the vault was locked and `SyncService` was reset
- **WHEN** the vault is unlocked and `trigger()` is called
- **THEN** a new sync starts from `.idle` state with no residual error
