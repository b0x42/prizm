## 1. Domain Layer — Tests First (§IV TDD)

- [x] 1.1 Define `SyncTimestampRepository` protocol in `Domain/` with `lastSyncDate: Date?` getter and `recordSuccessfulSync()` mutator (no account parameters — email is an impl concern)
- [x] 1.2 Write failing unit tests for `GetLastSyncDateUseCase` with a mock repository (nil case, valid date case, future date clamping) — tests must fail before 1.3
- [x] 1.3 Implement `GetLastSyncDateUseCase` in `Domain/UseCases/` until tests pass

## 2. Data Layer — Tests First (§IV TDD)

- [x] 2.1 Write failing unit tests for `SyncTimestampRepositoryImpl` covering: write, read-back, nil-before-first-write, persistence across init, and isolation between two instances initialized with different emails — tests must fail before 2.2
- [x] 2.2 Implement `SyncTimestampRepositoryImpl` as an `actor` in `Data/` (CLAUDE.md: actor for shared mutable state); initialized with account email; stores ISO-8601 string under `com.prizm.lastSyncDate.<email>` in UserDefaults

## 3. Presentation Formatter — Tests First (§IV TDD)

- [x] 3.1 Write failing unit tests for the relative-label formatter covering all tiers in order: future date → "just now", previous year → "Month Day, Year", 2+ days ago same year → "Month Day", previous calendar day → "yesterday", 0–59s → "just now", 60s → "1 minute ago", 2–59 min → "X minutes ago", 1 hr → "1 hour ago", 23 hrs same day → "X hours ago", nil → "Never synced" — tests must fail before 3.2
- [x] 3.2 Implement the relative-label formatter evaluating calendar day first, then elapsed time for same-day syncs, in the user's local timezone — until tests pass

## 4. Sync Integration

- [x] 4.1 Inject `SyncTimestampRepository` into `VaultBrowserViewModel`; in `handleSyncCompleted(syncedAt:)` call `syncTimestampRepository.recordSuccessfulSync()` — error paths must not call it
- [x] 4.2 Add `os.Logger` `.info` log call when `recordSuccessfulSync()` is invoked (§V Observability); no sensitive data in log output
- [x] 4.3 On ViewModel init, load persisted `lastSyncedAt` from `GetLastSyncDateUseCase` (falls back to `vault.lastSyncedAt` for in-memory value if use case returns nil)

## 5. DI / AppContainer

- [x] 5.1 Register `SyncTimestampRepositoryImpl(email:)` in `AppContainer` using the active session email; wire into `GetLastSyncDateUseCase` and `VaultBrowserViewModel`

## 6. Presentation Layer — Tests First (§IV TDD)

- [x] 6.1 Write failing unit tests for the vault browser ViewModel covering: `lastSyncedAt` loaded from use case on init, updated via `handleSyncCompleted`, and nil state — tests must fail before 6.2
- [x] 6.2 Update ViewModel init to accept `SyncTimestampRepository` and `GetLastSyncDateUseCase`; load persisted timestamp on init; save on `handleSyncCompleted`
- [x] 6.3 Add a 60-second repeating `Timer` in the ViewModel to publish a `relativeLabel: String` computed from `lastSyncedAt`; invalidate on deinit
- [x] 6.4 Add a `SyncStatusView` pinned to the very bottom of the sidebar (outside the scroll area) displaying `relativeLabel` using `Typography.listSubtitle`; the view is only shown when the vault browser is active (vault lock hides the entire screen)
- [x] 6.5 Show "Never synced" when `lastSyncedAt` is nil

## 7. Verification

- [x] 7.1 Verify end-to-end: unlock vault → sync completes → sidebar bottom label updates live without view reload
