## Why

`VaultRepositoryImpl` is `@MainActor`, so every vault read — `itemCounts()`, `items(for:)`, `searchItems()`, `populate()` — runs on the main thread. For large shared org vaults (2,000+ items across many collections) these O(n) operations can exceed 16 ms per frame, causing dropped frames during sync and sidebar navigation (issue #46).

## What Changes

- Move `VaultRepositoryImpl` from `@MainActor` to a dedicated `actor` so heavy work runs off the main thread.
- Pre-compute derived data (counts, per-org/collection/folder indexes) once in `populate()` and store as cached dictionaries; reads become O(1) lookups.
- All currently-synchronous `VaultRepository` protocol methods (reads + `populate()` + `clearVault()`) gain `async`; callers add `await`.
- `searchItems()` runs on the actor's executor, off the main thread, using the pre-cached base list.
- No behaviour change visible to users; concurrency contract only.

## Capabilities

### New Capabilities

- `vault-actor-isolation`: `VaultRepositoryImpl` becomes a dedicated `actor`; O(1) indexed reads replace O(n) scans; all synchronous protocol methods gain `async`.

### Modified Capabilities

<!-- No spec-level requirement changes — vault behaviour is identical; only the threading model and internal data structures change. -->

## Impact

- **`Prizm/Data/Repositories/VaultRepositoryImpl.swift`** — actor conversion + index caching
- **`Prizm/Domain/Repositories/VaultRepository.swift`** — protocol methods become `async` where currently synchronous
- **`Prizm/Presentation/Vault/VaultBrowserViewModel.swift`** — consumes `VaultSnapshot` via async calls
- **`Prizm/PrizmTests/Data/VaultRepositoryImplTests.swift`** and related mocks — updated for `async` protocol
- **`Prizm/PrizmTests/Mocks/MockVaultRepository.swift`** — updated signatures
- No dependency additions; uses Swift Structured Concurrency only
