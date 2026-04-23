## Context

`VaultRepositoryImpl` is `@MainActor` (see line 13, `VaultRepositoryImpl.swift`). Its comment on line 12 already anticipates this migration: _"If a background sync path is added in a future phase, the store should become an `actor`."_ That future phase is now.

The three hot paths identified in issue #46:

| Method | Complexity | Called from |
|---|---|---|
| `populate()` | O(items) replace + O(n) index build | `SyncRepositoryImpl` after every sync |
| `itemCounts()` | O(items × categories) — 4–6 full passes | `VaultBrowserViewModel` on every sidebar change |
| `items(for: .organization)` | 2× full scan + Set alloc | `VaultBrowserViewModel` on selection change |
| `searchItems()` | O(items) substring scan | Every keystroke in search field |

For a 2,000-item org vault, `itemCounts()` makes ~8 passes = ~16,000 comparisons per call. At 60fps that is 16ms budget — tight.

The `VaultRepository` protocol (line 6) already declares `Sendable`. Read methods are currently synchronous `throws`; write paths (`update`, `create`, etc.) are `async throws`. Callers are ViewModels via use cases and directly.

## Goals / Non-Goals

**Goals:**
- Move vault reads off the main thread: `VaultRepositoryImpl` becomes a dedicated `actor`.
- Eliminate repeated O(n) scans: pre-compute `itemCounts` and per-selection item lists once in `populate()`.
- Keep all existing behaviours identical — no user-visible changes.
- Maintain full test coverage; update mocks and unit tests to match `async` signatures.

**Non-Goals:**
- Profiling with Instruments (issue #46 step 1) — this change implements the fix; profiling is pre-work the issue suggests but is not a code deliverable.
- Lazy / incremental filtering — pre-computation in `populate()` is sufficient for expected vault sizes (< 10,000 items). Incremental filtering adds complexity with no current need.
- Changing the sync architecture or adding background sync — out of scope.
- UI changes.

## Decisions

### D1 — Dedicated `actor`, not `@MainActor`

**Chosen**: Convert `VaultRepositoryImpl` to `actor VaultRepositoryImpl`.

**Alternatives**:
- Keep `@MainActor`, pre-compute in `populate()` — reads stay synchronous but still block main thread during `populate()`. Large vaults still cause a jank spike on every sync.
- `@MainActor` + background Task for heavy reads — awkward; callers need `await` anyway, actor is cleaner.
- `NSOperationQueue` / `DispatchQueue` — pre-Swift Concurrency; violates Constitution's concurrency rule (`async/await` only in new code).

The dedicated `actor` gives us Swift's built-in isolation guarantee with zero additional locking code, and moves all work (including `populate()`) to the actor's cooperative thread pool.

### D2 — Pre-compute read indexes in `populate()`

**Chosen**: `populate()` builds four indexes after storing raw data:
- `_counts: [SidebarSelection: Int]` — replaces `itemCounts()` O(n×k) with O(1) lookup.
- `_activeItems: [VaultItem]` — non-deleted, sorted; replaces repeated `filter { !$0.isDeleted }`.
- `_bySelection: [SidebarSelection: [VaultItem]]` — pre-filtered lists for all static selections (`.allItems`, `.favorites`, `.trash`, `.type`, `.folder`, `.collection`, `.organization`). Dynamic selections (`.newFolder`, `.newCollection`) return `[]` and need no cache.
- `_orgCollectionIds: [String: Set<String>]` — maps `orgId → Set<collectionId>` for O(1) org-membership tests.

`searchItems()` cannot be pre-computed (query-dependent) but runs on the actor's executor, off the main thread.

**Alternatives**:
- Pre-compute only `itemCounts`, keep `items(for:)` as O(n) — partial fix. The `items(for: .organization)` double-scan is equally problematic on large vaults.
- Store a sorted `[VaultItem]` + use `BinarySearch` — gains sort stability but adds complexity; `localizedCaseInsensitiveCompare` sort is already O(n log n) only once at populate time.

### D3 — ALL synchronous protocol methods become `async`

**Chosen**: Every currently-synchronous method on `VaultRepository` gains `async`: all read methods (`allItems()`, `folders()`, `organizations()`, `collections()`, `items(for:)`, `searchItems()`, `itemCounts()`) plus the two synchronous mutations (`populate()` and `clearVault()`).

**Why**: In Swift 6 strict concurrency, a dedicated `actor` can conform to a synchronous protocol requirement only if the method is `nonisolated` — but `nonisolated` methods cannot access actor-isolated state. Since both `populate()` and `clearVault()` mutate `self.items` and the index stores, they cannot be `nonisolated`. Marking them `async` in the protocol is the correct contract and matches what callers already express at the call site (`SyncRepositoryImpl` already `await`s `populate()`; `PrizmApp.signOut`/`lockVault` call `clearVault()` inside `Task {}` blocks that can `await`).

**Alternatives**:
- `VaultSnapshot` value type pushed via `@Published` — adds indirection and a publisher not needed elsewhere; over-engineered.
- Keep protocol synchronous, add `nonisolated` wrappers — impossible: wrappers need actor state access.
- Keep `populate()`/`clearVault()` sync via a `Mutex` shim — introduces lock-based synchronisation, violating Constitution §I (Swift async/await only in new code).

**Caller impact**: `VaultBrowserViewModel` and use cases add `await` to reads (already in async contexts). `SyncRepositoryImpl` already `await`s `populate()` — no change needed there. `PrizmApp.signOut`/`lockVault` already run inside `Task {}` — add `await` to `clearVault()` calls. `SearchVaultUseCaseImpl.execute()` becomes `async throws` and the `SearchVaultUseCase` protocol is updated to match. `VaultBrowserViewModel.refreshItems()`, `refreshCounts()`, and `refreshItemSelection()` are currently synchronous — they must be converted to fire-and-forget wrappers that dispatch to `Task { [weak self] in await ... }` internally.

**`lastSyncedAt` removal**: `var lastSyncedAt: Date? { get }` is removed from the protocol. An actor-isolated stored property cannot satisfy a synchronous `{ get }` protocol requirement without being `nonisolated`, which is illegal for stored properties on actors. `GetLastSyncDateUseCase` already serves as the primary source; the `?? vault.lastSyncedAt` fallback in `VaultBrowserViewModel` is dropped.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| First `await` on a cold actor can briefly block the calling task | Acceptable — actor hops are cooperative; the main thread is not blocked. |
| `populate()` index build is O(items × selections) — still synchronous on the actor | For 2,000 items and ~20 sidebar entries this is ~40,000 comparisons once per sync, well under 1ms. Only `searchItems()` scales with keystrokes. |
| `_bySelection` cache grows linearly with folders + collections | Each cached list is a slice of the items array (value-type copy); memory overhead is acceptable for expected vault sizes. |
| Mock `VaultRepository` in tests requires `async` implementations | All mocks are in `PrizmTests/Mocks/`; they are updated as part of this change (task T-5). |
| Callers that called synchronous methods inside a `@MainActor` context need `await` | Compile-time error — the compiler catches every missed call site. Zero risk of silent regression. |

## Migration Plan

1. Update `VaultRepository` protocol — add `async` to all synchronous methods; remove `lastSyncedAt` property.
2. Convert `VaultRepositoryImpl` from `@MainActor final class` to `actor`.
3. Add index properties; build indexes in `populate()`.
4. Rewrite read methods to use indexes.
5. Update all callers (ViewModels, use cases) — follow compiler errors.
6. Update `MockVaultRepository` and all unit tests.
7. Verify build + full test suite green.

No runtime migration or data migration needed — all state is in-memory and rebuilt on every sync.

**Rollback**: revert the branch. No persistent state is changed.

## Open Questions

- None blocking implementation. Issue #46 recommends profiling first; the design is low-risk enough that the fix can proceed without profiling data. If post-implementation profiling reveals `populate()` index build is a bottleneck at extreme vault sizes (> 10,000 items), incremental indexing can be added as a follow-on.
