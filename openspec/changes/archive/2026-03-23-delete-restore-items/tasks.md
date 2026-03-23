## 1. Domain Layer

- [x] 1.1 Add `deletedDate: Date?` field to `VaultItem` entity
- [x] 1.2 Add `deleteItem(id: String) async throws` to `VaultRepository` protocol
- [x] 1.3 Add `restoreItem(id: String) async throws` to `VaultRepository` protocol
- [x] 1.4 Add `emptyTrash() async throws` to `VaultRepository` protocol
- [x] 1.5 Implement `DeleteVaultItemUseCase` (soft-delete; delegates to repository)
- [x] 1.6 Implement `RestoreVaultItemUseCase` (delegates to repository)
- [x] 1.7 Implement `EmptyTrashUseCase` (delegates to repository)
- [x] 1.8 Write unit tests for `DeleteVaultItemUseCase`, `RestoreVaultItemUseCase`, and `EmptyTrashUseCase`

## 2. Data Layer — Mapper & Repository

- [x] 2.1 Update `VaultItemMapper` to decode `deletedDate` from JSON (`deletedDate` ISO-8601 string, nullable)
- [x] 2.2 Write mapper unit tests for items with and without `deletedDate`
- [x] 2.3 Implement `deleteItem(id:)` in `VaultRepositoryImpl` — calls `DELETE /ciphers/{id}`
- [x] 2.4 Implement `restoreItem(id:)` in `VaultRepositoryImpl` — calls `PUT /ciphers/{id}/restore`
- [x] 2.5 Implement `emptyTrash()` in `VaultRepositoryImpl` — calls `DELETE /ciphers/purge`
- [x] 2.6 Write integration tests (or mock-URLSession tests) for all three API calls

## 3. Presentation — Sidebar & Trash View

- [x] 3.1 Add a "Trash" sidebar entry in `NavigationSplitView` sidebar column
- [x] 3.2 Create `TrashView` (filtered list of items where `deletedDate != nil`)
- [x] 3.3 Ensure active vault list excludes items with non-nil `deletedDate`
- [x] 3.4 Add empty state to `TrashView`: heading "No items in trash" + body "Items you delete will appear here"
- [x] 3.5 Add "Empty Trash" toolbar button to `TrashView` (disabled when list is empty)
- [x] 3.6 Show confirmation alert for "Empty Trash" with item count and destructive button

## 4. Presentation — Delete Actions

- [x] 4.1 Add "Delete" context-menu action on active vault list rows
- [x] 4.2 Add "Delete" toolbar button to `ItemDetailView` for active items
- [x] 4.3 Show confirmation alert before soft-delete (with cancel / Move to Trash buttons)
- [x] 4.4 On confirmed soft-delete: call use case, remove item from active list, navigate back to list
- [x] 4.5 Show error alert on soft-delete failure
- [x] 4.6 Add "Delete Permanently" context-menu action on Trash list rows
- [x] 4.7 Show destructive confirmation alert before permanent delete
- [x] 4.8 On confirmed permanent delete: call use case, remove item from Trash list
- [x] 4.9 Show error alert on permanent delete failure

## 5. Presentation — Restore Actions

- [x] 5.1 Add "Restore" context-menu action on Trash list rows
- [x] 5.2 On restore: call use case, move item back to active list, remove from Trash list
- [x] 5.3 Show error alert on restore failure
- [x] 5.4 Add "Restore" toolbar button to `ItemDetailView` when item is trashed
- [x] 5.5 Show trash-status banner in `ItemDetailView` for trashed items
- [x] 5.6 Disable Edit button in `ItemDetailView` for trashed items

## 6. Observability & Security Review (§V / §III Constitution)

- [x] 6.1 Add `os.Logger` (category: `vault`) calls for soft-delete, permanent delete, restore, and empty-trash operations — log item ID at `.info`, errors at `.error`; MUST NOT log item name or any secret fields
- [x] 6.2 Constitution §III security review sign-off: confirm no secrets flow through delete/restore paths and API calls are HTTPS-only

## 7. UI Tests

- [x] 7.1 XCUITest: soft-delete an item from the list and verify it appears in Trash
- [x] 7.2 XCUITest: restore an item from Trash and verify it reappears in active vault
- [x] 7.3 XCUITest: permanently delete a trashed item and verify it is gone
- [x] 7.4 XCUITest: empty trash and verify Trash list is empty
