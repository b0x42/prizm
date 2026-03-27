## Context

Sync today is fire-and-block: login and unlock show a full `SyncProgressView` screen and wait for the network round-trip before the vault appears. Mutations (save, delete, restore, favorite) never trigger a sync at all — the vault grows stale until the next unlock cycle. Sync logic is scattered: `LoginUseCaseImpl`, `UnlockUseCaseImpl`, and `UnlockViewModel` each own pieces of the sync lifecycle.

The goal is a single, injectable `SyncService` that all callers delegate to, with no blocking UI and a lightweight sidebar indicator as the only visible status surface.

## Goals / Non-Goals

**Goals:**
- All sync runs in the background — vault appears immediately after auth
- One authoritative owner of sync state (`SyncService`), injected via `AppContainer`
- Sidebar footer shows vault name + live sync status (spinner / error mark)
- Error detail available via tap-to-open sheet; dismissing clears the error
- Concurrent trigger deduplication: at most one sync in-flight + one queued
- Sync state cleared when the vault locks

**Non-Goals:**
- Periodic background polling (no timer-based sync)
- Conflict resolution (server is source of truth; local optimistic state is always overwritten)
- Push notifications or WebSocket-driven sync
- Per-operation progress messages in the footer (single spinner is sufficient)

## Decisions

### 1. `SyncState` and `SyncStatusProviding` belong in Domain

**Chosen:** `SyncState` and the `SyncStatusProviding` protocol live in `Domain/`. `SyncService` (Data layer) conforms to `SyncStatusProviding`. Presentation only imports Domain types.

**Why:** Constitution §II prohibits Presentation from importing Data directly. `SidebarFooterView` and `SidebarView` need to read `SyncState` and call `clearError()` — if these types lived in Data, that would be a blocking §II violation. Moving them to Domain keeps the dependency arrows pointing inward and makes `SyncService` fully mockable in Presentation tests.

```
Domain/                          Data/
  SyncState (enum)          ◀──  SyncService (conforms to SyncStatusProviding)
  SyncStatusProviding (protocol)
       ▲
Presentation/
  SidebarFooterView (reads SyncState via SyncStatusProviding)
  VaultBrowserViewModel (holds any SyncStatusProviding)
```

### 2. `SyncService` as a `@MainActor` `@Observable` class, not a Swift `actor`

**Chosen:** `@MainActor final class SyncService: SyncStatusProviding` with `@Observable`.

**Why over `actor`:** SwiftUI observation requires property access on the main actor. A plain `actor` would require `await syncService.state` in every view, making `@Observable` impossible without hopping to main. A `@MainActor` class owns all state on the main actor and dispatches the actual network work with `Task { [weak self] in ... }` where the network call runs off-main and writes back via `@MainActor` properties.

**Why over `ObservableObject` / `@Published`:** `@Observable` (Swift 5.9+/macOS 26) avoids the `objectWillChange` boilerplate and is the project's forward direction.

### 3. Deduplication: in-flight guard + single pending slot

```
state machine:
  idle     → trigger() → syncing
  syncing  → trigger() → set pendingTrigger = true  (drop extras)
  syncing  → done      → if pendingTrigger: syncing again, else idle
  syncing  → error     → error state (pendingTrigger cleared)
  error    → clearError() → idle
  error    → trigger() → syncing (clears error, starts fresh)
  any      → reset()   → idle   (called on vault lock)
```

One pending slot is enough — any number of concurrent triggers collapse to "do one more sync after this one". This avoids unbounded queuing while ensuring the vault is eventually consistent after rapid mutations.

### 4. Login/unlock use cases no longer call sync

`LoginUseCaseImpl` and `UnlockUseCaseImpl` return as soon as auth succeeds. The caller (`LoginViewModel`, `UnlockViewModel`) signals success, `RootViewModel` / `AppContainer` transitions to `.vault` and immediately calls `syncService.trigger()`. This keeps use cases focused on auth and removes their dependency on `SyncRepository`.

`SyncService` is initialised with `SyncUseCase` (the Domain protocol), not `SyncUseCaseImpl` or `SyncRepository`, so it remains independently testable.

### 5. `.syncing` screen state is deleted

`RootViewModel.Screen.syncing` and `SyncProgressView` are removed entirely. The vault is shown immediately; the sidebar footer is the only sync indicator. Users who were relying on the progress screen to know "sync is done" now see the spinner clear in the sidebar footer.

### 6. Sidebar footer via `.safeAreaInset(edge: .bottom)`

SwiftUI's `.safeAreaInset` attaches a view below the scroll area without disturbing the List's insets or safe area. The footer receives `account` (for the vault name) and a `SyncStatusProviding` reference from `VaultBrowserView` via the sidebar closure.

### 7. Error sheet is local state in `SidebarFooterView`

The error sheet is triggered by tapping the `exclamationmark.triangle.fill` icon. Sheet dismissal calls `syncService.clearError()`. No VM needed — the error message comes directly from `syncService.lastError` via the `SyncStatusProviding` protocol.

### 8. Sync state is reset on vault lock

When `lockVault()` is called, `SyncService.reset()` transitions state to `.idle` and clears `lastError`. This prevents a stale error icon persisting across lock/unlock cycles. Any in-flight sync task is cancelled via structured concurrency (the `Task` handle is stored and cancelled in `reset()`).

## Risks / Trade-offs

- **Vault appears before sync completes** → user may briefly see stale data after unlock. Acceptable: the spinner communicates that fresh data is loading. Considered showing a "Loading…" skeleton but rejected as over-engineered for typical sync times.
- **Background sync fails silently on first login** → user sees red error mark immediately after entering the vault. This is more honest than the old behaviour (blocking progress screen that also showed an error). The error sheet provides the message.
- **`SyncService` on `@MainActor`** → the `SyncUseCase.execute()` network call runs inside a `Task` but the `Task` closure itself is `@MainActor`-isolated. The actual `URLSession` work happens off-main inside `SyncRepositoryImpl`; `SyncService` only awaits the result. No main-thread blocking in practice.
- **In-flight sync on lock** → `reset()` cancels the active `Task`. The cancelled sync throws `CancellationError`; `SyncService` must handle this without transitioning to `.error` state (treat cancellation as a clean reset, not a failure).

## Migration Plan

1. Add `SyncState.swift`, `SyncStatusProviding.swift` to `Domain/`
2. Add `SyncService.swift` to `Data/` — conforms to `SyncStatusProviding`, takes `SyncUseCase` (protocol)
3. Wire `AppContainer` — create `SyncService(sync: syncUseCase)`, pass to `VaultBrowserViewModel` and auth VMs as `SyncStatusProviding`
4. Remove `performSync()` from `UnlockViewModel`; remove `sync.sync()` from use cases
5. Remove `.syncing` case from `RootViewModel.Screen`; delete `SyncProgressView.swift`
6. Call `syncService.reset()` inside `lockVault()` in `MacwardenApp`/`RootViewModel`
7. Add `SidebarFooterView`; wire into `SidebarView` via `.safeAreaInset`
8. Remove `syncErrorBanner` from `VaultBrowserView`; remove `syncErrorMessage` / `dismissSyncError()` from `VaultBrowserViewModel`
9. Update all call sites in `VaultBrowserViewModel` to call `syncService.trigger()`

No data migration needed — sync state is ephemeral (in-memory only).

## Open Questions

- Should `.login` and `.unlock` triggers skip the deduplication queue and always run fresh? (Current design: they follow the same dedup path — safe since auth guarantees a fresh session.)
