## Why

Sync currently blocks the UI on login and unlock (dedicated progress screen), and never runs after mutations — leaving the vault stale until the next unlock. A background sync service eliminates the blocking screen and ensures the vault is always refreshed after any state-changing operation.

## What Changes

- **Add** `SyncService` (`@MainActor @Observable` class) — centralised sync coordinator with deduplication, owned by `AppContainer`
- **Add** `SyncState` and `SyncStatusProviding` protocol to the Domain layer so Presentation can observe sync state without importing Data
- **Add** `SidebarFooterView` — vault name + animated sync icon, red error mark on failure, error sheet on tap
- **Remove** `SyncProgressView` and the `.syncing` screen state entirely
- **Remove** `UnlockViewModel.performSync()` and direct `sync.sync()` calls from `LoginUseCaseImpl` / `UnlockUseCaseImpl`
- **Remove** existing `syncErrorBanner` in `VaultBrowserView` and related VM properties
- **Modify** login and unlock flows — navigate to vault immediately after auth succeeds; `SyncService.trigger()` runs in background
- **Modify** `VaultBrowserViewModel` — all mutation operations (`toggleFavorite`, `performSoftDelete`, `performRestore`, `handleItemSaved`, `performPermanentDelete`) call `SyncService.trigger()` after local update

## Capabilities

### New Capabilities

- `background-sync-service`: Centralised `SyncService` (`@MainActor @Observable` class) — state machine (idle/syncing/error), trigger API, deduplication of concurrent triggers
- `sidebar-sync-status`: Sidebar footer showing vault name and live sync status (spinner, error mark, dismiss sheet)

### Modified Capabilities

- `vault-lock`: Login and unlock flows no longer block on sync; `SyncProgressView` removed; vault is shown immediately after auth
- `vault-browser-ui`: Sync error banner removed from content column; sync status moves to sidebar footer

## Impact

- `Domain/UseCases/` or `Domain/Sync/`: new `SyncState.swift`, `SyncStatusProviding.swift` (protocol)
- `Data/`: new `SyncService.swift` (conforms to `SyncStatusProviding`)
- `Presentation/Sync/SyncProgressView.swift` — deleted
- `Presentation/Vault/Sidebar/SidebarView.swift` — add footer
- `App/MacwardenApp.swift` — remove `.syncing` screen state and related transitions
- `App/AppContainer.swift` — add `SyncService` instance, inject into ViewModels
- `Presentation/Login/LoginViewModel.swift`, `Presentation/Unlock/UnlockViewModel.swift` — navigate to vault without waiting for sync
- `Presentation/Vault/VaultBrowserViewModel.swift` — inject `SyncStatusProviding`, trigger after mutations, remove error banner properties
- `Data/UseCases/LoginUseCaseImpl.swift`, `UnlockUseCaseImpl.swift` — remove `sync.sync()` calls
- All existing `SyncUseCase` / `SyncUseCaseImpl` wiring remains; `SyncService` calls `SyncUseCase` (protocol) internally
