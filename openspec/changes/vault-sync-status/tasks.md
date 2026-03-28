## 1. Domain Layer

- [ ] 1.1 Define `SyncTimestampRepository` protocol in `Domain/` with `lastSyncDate: Date?` getter and `recordSuccessfulSync()` mutator
- [ ] 1.2 Define `GetLastSyncDateUseCase` in `Domain/UseCases/` that reads from `SyncTimestampRepository`
- [ ] 1.3 Write unit tests for `GetLastSyncDateUseCase` with a mock repository (nil case, valid date case, future date clamping)

## 2. Data Layer

- [ ] 2.1 Implement `SyncTimestampRepositoryImpl` in `Data/` using `UserDefaults`, storing the timestamp as an ISO-8601 string under a stable key (e.g. `com.macwarden.lastSyncDate`)
- [ ] 2.2 Write unit tests for `SyncTimestampRepositoryImpl` covering write, read-back, nil-before-first-write, and persistence across init

## 3. Sync Integration

- [ ] 3.1 Locate the existing sync completion path (post-login sync and post-unlock sync)
- [ ] 3.2 Inject `SyncTimestampRepository` and call `recordSuccessfulSync()` on the success path only — ensure error paths do not update the timestamp

## 4. DI / AppContainer

- [ ] 4.1 Register `SyncTimestampRepositoryImpl` in `AppContainer` and wire it into `GetLastSyncDateUseCase` and the sync completion caller

## 5. Presentation Layer

- [ ] 5.1 Add a `lastSyncDate: Date?` published property to the vault browser ViewModel; populate it from `GetLastSyncDateUseCase` on appear and update it when sync completes
- [ ] 5.2 Add a helper (on `Date` or in the ViewModel) that formats the relative label: "Synced just now" / "Synced X minutes ago" / "Synced X hours ago" / "Synced yesterday" / "Synced [Month Day]"; clamp future timestamps to "Synced just now"
- [ ] 5.3a Add a 60-second repeating timer in the ViewModel to refresh the relative label while the app is open
- [ ] 5.3 Add a `SyncStatusView` pinned to the very bottom of the sidebar (outside the scroll area) displaying the formatted timestamp using `Typography.listSubtitle`
- [ ] 5.4 Show "Never synced" when `lastSyncDate` is nil

## 6. Tests & Verification

- [ ] 6.1 Write unit tests for the relative-label formatter covering all tiers: nil → "Never synced", < 1 min → "just now", 2 min, 59 min, 1 hr, 23 hrs, yesterday (24–48 hrs), older (date only), and future date → "just now"
- [ ] 6.2 Verify end-to-end: unlock vault → sync completes → sidebar footer updates live without view reload
