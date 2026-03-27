## 1. Domain Types

- [ ] 1.1 Add `SyncState` enum (`.idle`, `.syncing`, `.error(Error)`) to `Domain/`
- [ ] 1.2 Add `SyncStatusProviding` protocol to `Domain/` — exposes `state: SyncState`, `lastError: Error?`, `trigger()`, `clearError()`, `reset()`

## 2. SyncService — Core Implementation

- [ ] 2.1 Write unit tests for `SyncService` state machine (red phase): idle→syncing→idle, idle→syncing→error, error→trigger→syncing, deduplication (multiple triggers collapse to one retry), clearError no-op in non-error state, reset() cancels in-flight task
- [ ] 2.2 Create `Data/SyncService.swift` as `@MainActor @Observable final class` conforming to `SyncStatusProviding`; initialise with `SyncUseCase` (protocol, not impl)
- [ ] 2.3 Implement `trigger()`: idle→syncing, log `.info`; dispatch network work in a stored `Task`; on completion check `pendingTrigger`
- [ ] 2.4 Implement deduplication: if `.syncing` on trigger, set `pendingTrigger = true`; after sync completes run once more if pending
- [ ] 2.5 Implement `trigger()` from `.error` state: clear error, transition to `.syncing`, start fresh sync
- [ ] 2.6 Implement `reset()`: cancel stored task, transition to `.idle`, clear `lastError` and `pendingTrigger` — treat `CancellationError` as clean reset, not failure
- [ ] 2.7 Implement `clearError()`: no-op unless state is `.error`; transitions to `.idle`
- [ ] 2.8 Add `os.Logger` (subsystem `com.macwarden`, category `SyncService`); log `.info` on trigger, `.info` on success, `.error` on failure (no secrets in output)

## 3. Remove Blocking Sync Screen

- [ ] 3.1 Delete `Presentation/Sync/SyncProgressView.swift`
- [ ] 3.2 Remove `.syncing(message:)` case from the screen enum in `MacwardenApp`
- [ ] 3.3 Remove all `.syncing` branches from `MacwardenApp` view switches, menu-enable guards, and lock-condition checks
- [ ] 3.4 Update `isVaultUnlocked` and Lock Vault enabled predicate to check `.vault` only (remove `.syncing`)
- [ ] 3.5 Call `syncService.reset()` inside `lockVault()` so sync state is cleared on every lock
- [ ] 3.6 Remove `UnlockViewModel.performSync()` and the `sync: SyncUseCase` dependency from `UnlockViewModel`
- [ ] 3.7 Remove `sync.sync()` calls from `LoginUseCaseImpl` (normal login and TOTP paths)
- [ ] 3.8 Remove `sync.sync()` call from `UnlockUseCaseImpl`
- [ ] 3.9 Remove `SyncUseCase` parameter from `LoginUseCaseImpl` and `UnlockUseCaseImpl` initialisers

## 4. Wire SyncService into Auth Flows

- [ ] 4.1 Update `LoginUseCaseTests` and `UnlockUseCaseTests` to assert sync is NOT called from use cases (red phase before 4.4–4.5)
- [ ] 4.2 Update `LoginViewModelTests` and `UnlockViewModelTests` to assert `syncService.trigger` is called on success and NOT called on failure (red phase before 4.4–4.5)
- [ ] 4.3 Add `SyncService` to `AppContainer`; construct as `SyncService(sync: syncUseCase)` where `syncUseCase` is the existing `SyncUseCaseImpl` instance
- [ ] 4.4 Call `syncService.trigger()` in `LoginViewModel` (or `RootViewModel`) immediately after auth success transitions to `.vault`
- [ ] 4.5 Call `syncService.trigger()` in `UnlockViewModel` immediately after unlock success transitions to `.vault`

## 5. Wire SyncService into Mutation Operations

- [ ] 5.1 Write `VaultBrowserViewModelSyncTests` asserting `trigger()` fires after each successful mutation and does NOT fire on failure (red phase before 5.3–5.7)
- [ ] 5.2 Inject `SyncStatusProviding` into `VaultBrowserViewModel` (add parameter, update `AppContainer` factory)
- [ ] 5.3 Call `syncService.trigger()` in `toggleFavorite` after `handleItemSaved`
- [ ] 5.4 Call `syncService.trigger()` in `performSoftDelete` after `refreshItems()`
- [ ] 5.5 Call `syncService.trigger()` in `performPermanentDelete` after `refreshItems()`
- [ ] 5.6 Call `syncService.trigger()` in `performRestore` after `refreshItems()`
- [ ] 5.7 Call `syncService.trigger()` in `handleItemSaved` after `refreshItems()`

## 6. Remove Existing Sync Error Banner

- [ ] 6.1 Remove `syncErrorBanner` computed property and its `@ViewBuilder` from `VaultBrowserView`
- [ ] 6.2 Remove `syncErrorMessage: String?` and `dismissSyncError()` from `VaultBrowserViewModel`
- [ ] 6.3 Remove `AccessibilityID.Vault.syncErrorBanner` and `syncErrorDismiss` identifiers
- [ ] 6.4 Remove the `syncErrorBanner` call from `VaultBrowserView.body`

## 7. Sidebar Footer — SidebarFooterView

- [ ] 7.1 Write `SidebarFooterViewTests` for all three states: idle (no icon), syncing (spinner), error (red mark, sheet opens, dismiss clears state) — red phase before 7.2
- [ ] 7.2 Create `Presentation/Vault/Sidebar/SidebarFooterView.swift` — accepts `vaultName: String` and `syncService: any SyncStatusProviding`
- [ ] 7.3 Implement idle state: vault name only, no icon
- [ ] 7.4 Implement syncing state: vault name + `arrow.clockwise` with continuous `rotationEffect` animation
- [ ] 7.5 Implement error state: vault name + red `exclamationmark.triangle.fill` button; tapping sets `showErrorSheet = true`
- [ ] 7.6 Add error sheet: `.sheet(isPresented: $showErrorSheet)` showing localised error message and a Dismiss button that calls `syncService.clearError()`
- [ ] 7.7 Update `SidebarView` signature to accept `account: Account` and `syncService: any SyncStatusProviding`
- [ ] 7.8 Attach `SidebarFooterView` to `SidebarView` via `.safeAreaInset(edge: .bottom)`
- [ ] 7.9 Pass `account` and `syncService` from `VaultBrowserView` through to `SidebarView`
