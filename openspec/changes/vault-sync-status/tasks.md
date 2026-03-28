## 1. Domain Layer — Tests First (§IV TDD)

- [ ] 1.1 Define `SyncTimestampRepository` protocol in `Domain/` with `lastSyncDate: Date?` getter and `recordSuccessfulSync()` mutator (no account parameters — email is an impl concern)
- [ ] 1.2 Write failing unit tests for `GetLastSyncDateUseCase` with a mock repository (nil case, valid date case, future date clamping) — tests must fail before 1.3
- [ ] 1.3 Implement `GetLastSyncDateUseCase` in `Domain/UseCases/` until tests pass

## 2. Data Layer — Tests First (§IV TDD)

- [ ] 2.1 Write failing unit tests for `SyncTimestampRepositoryImpl` covering: write, read-back, nil-before-first-write, persistence across init, and isolation between two instances initialized with different emails — tests must fail before 2.2
- [ ] 2.2 Implement `SyncTimestampRepositoryImpl` as an `actor` in `Data/` (CLAUDE.md: actor for shared mutable state); initialized with account email; stores ISO-8601 string under `com.macwarden.lastSyncDate.<email>` in UserDefaults

## 3. Presentation Formatter — Tests First (§IV TDD)

- [ ] 3.1 Write failing unit tests for the relative-label formatter covering all tiers in order: future date → "just now", previous year → "Month Day, Year", 2+ days ago same year → "Month Day", previous calendar day → "yesterday", 0–59s → "just now", 60s → "1 minute ago", 2–59 min → "X minutes ago", 1 hr → "1 hour ago", 23 hrs same day → "X hours ago", nil → "Never synced" — tests must fail before 3.2
- [ ] 3.2 Implement the relative-label formatter evaluating calendar day first, then elapsed time for same-day syncs, in the user's local timezone — until tests pass

## 4. Sync Integration

- [ ] 4.1 Locate the existing sync completion path (post-login sync and post-unlock sync)
- [ ] 4.2 Expose an `AsyncStream<Date>` on the sync use case that emits the current date each time a sync completes successfully
- [ ] 4.3 Inject `SyncTimestampRepository` and call `recordSuccessfulSync()` on the success path only — ensure error paths do not update the timestamp
- [ ] 4.4 Add `os.Logger` `.info` log call when `recordSuccessfulSync()` is invoked (§V Observability); no sensitive data in log output

## 5. DI / AppContainer

- [ ] 5.1 Register `SyncTimestampRepositoryImpl(email:)` in `AppContainer` using the active session email; wire into `GetLastSyncDateUseCase` and the sync use case

## 6. Presentation Layer — Tests First (§IV TDD)

- [ ] 6.1 Write failing unit tests for the vault browser ViewModel covering: initial `lastSyncDate` loaded from use case on appear, update on `AsyncStream` emission, and nil state — tests must fail before 6.2
- [ ] 6.2 Add `lastSyncDate: Date?` published property to the vault browser ViewModel; load from `GetLastSyncDateUseCase` on appear; update via `for await` on the sync use case's `AsyncStream<Date>` in a stored `Task`
- [ ] 6.3 Cancel the stored `Task` on ViewModel deinit to prevent stream task leak
- [ ] 6.4 Add a 60-second repeating timer in the ViewModel to re-evaluate the relative label while the app is open; cancel on deinit
- [ ] 6.5 Add a `SyncStatusView` pinned to the very bottom of the sidebar (outside the scroll area) displaying the relative label using `Typography.listSubtitle`; hidden when vault is locked
- [ ] 6.6 Show "Never synced" when `lastSyncDate` is nil

## 7. Verification

- [ ] 7.1 Verify end-to-end: unlock vault → sync completes → sidebar bottom label updates live without view reload
