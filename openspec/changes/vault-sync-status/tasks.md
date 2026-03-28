## 1. Domain Layer — Tests First (§IV TDD)

- [ ] 1.1 Define `SyncTimestampRepository` protocol in `Domain/` with `lastSyncDate: Date?` getter and `recordSuccessfulSync()` mutator
- [ ] 1.2 Write failing unit tests for `GetLastSyncDateUseCase` with a mock repository (nil case, valid date case, future date clamping) — tests must fail before 1.3
- [ ] 1.3 Implement `GetLastSyncDateUseCase` in `Domain/UseCases/` until tests pass

## 2. Data Layer — Tests First (§IV TDD)

- [ ] 2.1 Write failing unit tests for `SyncTimestampRepositoryImpl` covering write, read-back, nil-before-first-write, persistence across init, and isolation between two different account emails — tests must fail before 2.2
- [ ] 2.2 Implement `SyncTimestampRepositoryImpl` in `Data/` using `UserDefaults`, storing the timestamp as an ISO-8601 string under a per-account key (`com.macwarden.lastSyncDate.<email>`) until tests pass

## 3. Presentation — Tests First (§IV TDD)

- [ ] 3.1 Write failing unit tests for the relative-label formatter covering all tiers: nil → "Never synced", 30s → "just now", 60s → "1 minute ago", 2 min, 59 min, 1 hr, 23 hrs, previous calendar day → "yesterday", older same year → "Month Day", older different year → "Month Day, Year", future date → "just now" — tests must fail before 3.2
- [ ] 3.2 Implement the relative-label formatter using calendar-day comparison in the user's local timezone until tests pass

## 4. Sync Integration

- [ ] 4.1 Locate the existing sync completion path (post-login sync and post-unlock sync)
- [ ] 4.2 Inject `SyncTimestampRepository` and call `recordSuccessfulSync()` on the success path only — ensure error paths do not update the timestamp
- [ ] 4.3 Add `os.Logger` `.info` log call when `recordSuccessfulSync()` is invoked (§V Observability); scrub any sensitive data before logging

## 5. DI / AppContainer

- [ ] 5.1 Register `SyncTimestampRepositoryImpl` in `AppContainer` and wire it into `GetLastSyncDateUseCase` and the sync completion caller

## 6. Presentation Layer

- [ ] 6.1 Expose an `AsyncStream<Date>` on the sync use case that emits each time a sync completes successfully
- [ ] 6.2 Add a `lastSyncDate: Date?` published property to the vault browser ViewModel; populate it from `GetLastSyncDateUseCase` on appear and update it by consuming the `AsyncStream<Date>` with `for await` in a `Task`
- [ ] 6.3 Write unit tests for the ViewModel covering: initial load from use case, update on stream emission, and nil state
- [ ] 6.4 Add a 60-second repeating timer in the ViewModel to re-evaluate the relative label while the app is open
- [ ] 6.5 Add a `SyncStatusView` pinned to the very bottom of the sidebar (outside the scroll area) displaying the relative label using `Typography.listSubtitle`; hide the view when the vault is locked
- [ ] 6.6 Show "Never synced" when `lastSyncDate` is nil

## 7. Verification

- [ ] 7.1 Verify end-to-end: unlock vault → sync completes → sidebar bottom label updates live without view reload
