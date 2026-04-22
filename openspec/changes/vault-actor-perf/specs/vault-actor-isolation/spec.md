## ADDED Requirements

### Requirement: VaultRepositoryImpl runs on a dedicated actor
`VaultRepositoryImpl` SHALL be declared as a Swift `actor` (not `@MainActor`). All mutations and reads execute on the actor's cooperative-thread-pool executor, never on the main thread.

#### Scenario: Populate does not block the main thread
- **WHEN** `SyncRepositoryImpl` calls `populate()` after a successful sync
- **THEN** the store mutation and index build execute on the `VaultRepositoryImpl` actor executor, not the main thread

#### Scenario: Read methods do not block the main thread
- **WHEN** a ViewModel calls any read method (`allItems()`, `itemCounts()`, `items(for:)`, `searchItems()`)
- **THEN** the method body executes on the actor executor; the main thread is free while awaiting the result

---

### Requirement: Read protocol methods are async
All synchronous read methods on the `VaultRepository` protocol SHALL be marked `async`: `allItems()`, `folders()`, `organizations()`, `collections()`, `items(for selection:)`, `items(for collection:)`, `searchItems(query:in:)`, and `itemCounts()`.

#### Scenario: Caller must await read results
- **WHEN** a caller invokes any read method on a `VaultRepository` reference
- **THEN** the compiler requires `await` at the call site, enforcing explicit async context

#### Scenario: Write paths remain async throws
- **WHEN** a caller invokes a write method (`update(_:)`, `create(_:)`, `deleteItem(id:)`, etc.)
- **THEN** the method signature is unchanged (`async throws`); no regression in write-path callers

---

### Requirement: itemCounts is O(1) after populate
`VaultRepositoryImpl` SHALL pre-compute `[SidebarSelection: Int]` counts in `populate()` and return them directly from `itemCounts()` without iterating items.

#### Scenario: itemCounts returns immediately from cache
- **WHEN** `itemCounts()` is called after `populate()` has completed
- **THEN** the result is returned from an in-memory dictionary with no additional filtering or iteration

#### Scenario: itemCounts reflects the most recent populate
- **WHEN** `populate()` is called twice (e.g., two successive syncs)
- **THEN** `itemCounts()` returns counts matching the second call's data

---

### Requirement: items(for selection:) is O(1) for static selections
`VaultRepositoryImpl` SHALL pre-compute filtered and sorted item lists for all static `SidebarSelection` cases (`.allItems`, `.favorites`, `.trash`, `.type`, `.folder`, `.collection`, `.organization`) in `populate()`.

#### Scenario: items(for: .allItems) returns cached list
- **WHEN** `items(for: .allItems)` is called after populate
- **THEN** a pre-sorted list is returned with no filtering pass over the raw items array

#### Scenario: items(for: .organization) uses pre-built org collection index
- **WHEN** `items(for: .organization(id))` is called
- **THEN** the result uses a pre-computed `orgId → Set<collectionId>` index; no O(n) Set construction occurs at call time

#### Scenario: Dynamic selections return empty without crashing
- **WHEN** `items(for: .newFolder)` or `items(for: .newCollection)` is called
- **THEN** an empty array is returned immediately

---

### Requirement: searchItems runs off the main thread
`searchItems(query:in:)` SHALL execute entirely on the `VaultRepositoryImpl` actor executor. The main thread is not involved in the substring matching loop.

#### Scenario: Empty query returns pre-cached selection list
- **WHEN** `searchItems(query: "", in: selection)` is called
- **THEN** the pre-cached list for `selection` is returned with no substring scan

#### Scenario: Non-empty query filters from cached base list
- **WHEN** `searchItems(query: "acme", in: .allItems)` is called
- **THEN** the cached `.allItems` list is filtered by `matchesSearch(query:)` on the actor executor; the main thread is not blocked

---

### Requirement: Indexes rebuild after every write mutation
Every method that mutates `items`, `folderStore`, or `collectionStore` (`update(_:)`, `create(_:)`, `deleteItem(id:)`, `permanentDeleteItem(id:)`, `restoreItem(id:)`, `updateAttachments(_:for:)`, `createFolder(name:)`, `renameFolder(id:name:)`, `deleteFolder(id:)`, `createCollection(name:organizationId:)`, `renameCollection(id:organizationId:name:)`, `deleteCollection(id:organizationId:)`, `moveItemToFolder(itemId:folderId:)`, `moveItemsToFolder(itemIds:folderId:)`) SHALL call `buildIndexes()` after completing the mutation so that subsequent reads return fresh data without waiting for the next `populate()`.

#### Scenario: Read reflects item creation immediately
- **WHEN** `create(_:)` completes and `items(for: .allItems)` is called
- **THEN** the new item appears in the result

#### Scenario: Read reflects soft-delete immediately
- **WHEN** `deleteItem(id:)` completes and `items(for: .trash)` is called
- **THEN** the deleted item appears in the trash list and is absent from `items(for: .allItems)`

#### Scenario: Counts reflect folder creation immediately
- **WHEN** `createFolder(name:)` completes and `itemCounts()` is called
- **THEN** the new folder key is present in the returned dictionary (with count 0)

---

### Requirement: clearVault resets all indexes
`clearVault()` SHALL clear the raw stores and all pre-computed indexes atomically on the actor.

#### Scenario: Read methods after clearVault return empty results
- **WHEN** `clearVault()` is called and then `allItems()` or `itemCounts()` is called
- **THEN** both return empty results (empty array / empty dictionary respectively)
