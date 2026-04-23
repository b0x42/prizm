## 0. TDD — Write failing tests (Red phase)

- [x] 0.1 In `VaultRepositoryImplTests.swift`, add `async` tests for: populate → itemCounts O(1), populate twice → counts reflect second call, clearVault → allItems returns empty, items(for: .organization) uses index (verify no Set alloc by testing correctness). Mark all tests `async throws`. They fail to compile until task 2 is done.
- [x] 0.2 In a new `SearchVaultUseCaseImplTests.swift` (or existing), add `async throws` test: execute with empty query returns all items, execute with query filters correctly. Fails until task 3.3 done.
- [x] 0.3 Verify all new tests fail (Red) before proceeding to task group 1.

## 1. Protocol — make all synchronous methods async

- [x] 1.1 In `VaultRepository.swift`, add `async` to: `allItems()`, `folders()`, `organizations()`, `collections()`, `items(for selection:)`, `items(for collection:)`, `searchItems(query:in:)`, `itemCounts()`, `populate(items:folders:organizations:collections:syncedAt:)`, `clearVault()`
- [x] 1.2 Update the doc-comment on `VaultRepository` to state the impl is a dedicated `actor`; remove the `@MainActor` reference
- [x] 1.3 In `Domain/UseCases/SearchVaultUseCase.swift`, change `func execute(query:in:) throws` to `func execute(query:in:) async throws`
- [x] 1.4 Remove `var lastSyncedAt: Date? { get }` from `VaultRepository` protocol entirely — callers must use `GetLastSyncDateUseCase` as the sole source; the actor-isolated stored property cannot satisfy a synchronous protocol requirement

## 2. Implementation — convert VaultRepositoryImpl to actor

- [x] 2.1 Change `@MainActor final class VaultRepositoryImpl` to `actor VaultRepositoryImpl`
- [x] 2.2 Add index storage properties: `_counts: [SidebarSelection: Int]`, `_bySelection: [SidebarSelection: [VaultItem]]`, `_orgCollectionIds: [String: Set<String>]` (do NOT add `_activeItems` as a stored property — it duplicates `_bySelection[.allItems]` and violates YAGNI; use it as a local variable inside `buildIndexes()` only)
- [x] 2.3 Extract a private `buildIndexes()` method; use a local `let active = items.filter { !$0.isDeleted }` as the staging variable for building all three indexes from `items`, `folderStore`, `organizationStore`, `collectionStore`
- [x] 2.4 Call `buildIndexes()` at the end of `populate()` and inline-reset all three index properties in `clearVault()`. Also add `buildIndexes()` at the end of every write method that mutates `items`, `folderStore`, or `collectionStore`: `update(_:)`, `create(_:)`, `deleteItem(id:)`, `permanentDeleteItem(id:)`, `restoreItem(id:)`, `updateAttachments(_:for:)`, `createFolder(name:)`, `renameFolder(id:name:)`, `deleteFolder(id:)`, `createCollection(name:organizationId:)`, `renameCollection(id:organizationId:name:)`, `deleteCollection(id:organizationId:)`, `moveItemToFolder(itemId:folderId:)`, `moveItemsToFolder(itemIds:folderId:)`
- [x] 2.5 Rewrite `allItems()` to return `_bySelection[.allItems] ?? []` (add `async` keyword)
- [x] 2.6 Rewrite `items(for selection:)` to return `_bySelection[selection] ?? []` for all static cases; keep `.newFolder`/`.newCollection` returning `[]` (add `async` keyword)
- [x] 2.7 Rewrite `itemCounts()` to return `_counts` directly (add `async` keyword)
- [x] 2.8 Rewrite `searchItems(query:in:)`: empty query returns `_bySelection[selection] ?? []`; non-empty filters that cached list via `matchesSearch(query:)` (add `async` keyword)
- [x] 2.9 Add `async` to `folders()`, `organizations()`, `collections()` — bodies unchanged, just add keyword
- [x] 2.10 Remove the `@MainActor` class-level annotation and the stale thread-safety comment (lines 11–13 in current file)

## 3. SearchVaultUseCase cascade

- [x] 3.1 In `SearchVaultUseCaseImpl.swift`, change `func execute(query:in:) throws` to `async throws`; add `await` to the two `vault.*` calls inside
- [x] 3.2 Find all callers of `searchVaultUseCase.execute()` (or equivalent); add `await` as required — follow compiler errors

## 4. Callers — update ViewModels, use cases, app layer

- [x] 4.1 In `VaultBrowserViewModel.swift`, add `await` to all calls of `vault.allItems()`, `vault.itemCounts()`, `vault.items(for:)`, `vault.searchItems()`, `vault.folders()`, `vault.organizations()`, `vault.collections()` — follow compiler errors
- [x] 4.2 In `PrizmApp.swift` `signOut()` and `lockVault()`, add `await` before `vaultRepo.clearVault()`
- [x] 4.3 In `SyncRepositoryImpl.swift`, verify the existing `await vaultRepository.populate(...)` still compiles (no change needed — it already awaits)
- [x] 4.4 In `AttachmentRepositoryImpl.swift` lines 143 and 207, change `try? vaultRepository.allItems()` to `try? await vaultRepository.allItems()` (callers are already in `async` functions)
- [x] 4.5 Change `AppContainer.makeItemEditViewModel(for:)` and `makeItemCreateViewModel(for:folderId:collectionId:)` to accept `folders: [Folder]`, `organizations: [Organization]`, `collections: [OrgCollection]` as parameters; remove the synchronous `vaultStore.*` calls from these methods
- [x] 4.6 In `PrizmApp.swift`, update the `makeCreateViewModel` closure and the `makeItemEditViewModel` call site to pass `vaultBrowserVM.folders`, `vaultBrowserVM.organizations`, `vaultBrowserVM.collections` as arguments; remove the inline `try? vaultStore.collections()` call at line 168
- [x] 4.7 In `VaultBrowserViewModel`, convert `refreshItems()`, `refreshCounts()`, and `refreshItemSelection()` from synchronous functions to async-body wrappers: keep the sync signature but move the vault/search calls into `Task { [weak self] in ... }` blocks with `await`, updating `@Published` properties inside the task (the ViewModel is `@MainActor` so `@Published` writes are safe inside a `Task` on the main actor)
- [x] 4.8 In `VaultBrowserViewModel` lines 167 and 296, remove the `?? vault.lastSyncedAt` fallback — `GetLastSyncDateUseCase` is already the primary source; the fallback accessed the now-removed protocol property
- [x] 4.9 Verify no remaining call site uses a synchronous wrapper or `try!`/`try?` that masks the actor hop — compile with `-strict-concurrency=complete` to surface any remaining sites

## 5. Tests — update mocks and unit tests

- [x] 5.1 In `MockVaultRepository.swift`, add `async` to ALL mocked method signatures updated in task 1.1 (reads + `populate()` + `clearVault()`)
- [x] 5.2 In `VaultRepositoryImplTests.swift`, add `await` to all read and write method call sites; confirm the Red-phase tests from task 0.1 now pass (Green)
- [x] 5.3 In `VaultBrowserViewModelGlobalSearchTests.swift` and `VaultBrowserViewModelSyncStatusTests.swift`, update any synchronous mock read calls to `await`
- [x] 5.4 In `SearchVaultUseCaseImplTests.swift`, confirm the Red-phase tests from task 0.2 now pass (Green)
- [x] 5.5 Run the full test suite and confirm zero failures and zero concurrency warnings under Swift 6 strict concurrency

## 6. Validation

- [x] 6.1 Build with `-strict-concurrency=complete` (already active in Swift 6 mode); confirm zero new warnings
- [x] 6.2 Manually launch the app, trigger a sync, confirm sidebar badge counts and item lists are correct
- [x] 6.3 Verify lock and sign-out leave the sidebar empty (clearVault resets all indexes)

