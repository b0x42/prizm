## Why

Users accumulate stale or unwanted entries in their vault and currently have no way to remove them from within Prizm. Bitwarden's soft-delete model (trash / restore) already exists server-side — this change surfaces those actions in the app so users can clean up their vault and safely undo accidental deletions.

## What Changes

- Vault list items gain a context-menu **Delete** action that soft-deletes the item (moves to Bitwarden trash).
- Detail view gains a **Delete** toolbar button with a confirmation alert.
- A **Trash** section or filter appears in the sidebar so users can see soft-deleted items.
- Trashed items in the list show a **Restore** action that moves them back to the active vault.
- Trashed items show a **Delete Permanently** action for hard-delete (requires a second confirmation).
- Empty-trash bulk action clears all trashed items permanently.

## Capabilities

### New Capabilities

- `vault-item-delete`: Soft-delete a vault item by moving it to trash; hard-delete a trashed item permanently; empty trash (bulk hard-delete).
- `vault-item-restore`: Restore a soft-deleted vault item from trash back to the active vault.

### Modified Capabilities

<!-- No existing spec-level behavior changes required -->

## Impact

- **Domain**: New use-case protocols (`DeleteVaultItemUseCase`, `RestoreVaultItemUseCase`, `EmptyTrashUseCase`); `VaultItem` entity needs a `deletedDate: Date?` field to represent trash state.
- **Data**: Two new API calls — `DELETE /ciphers/{id}` (soft-delete) and `PUT /ciphers/{id}/restore`; plus `DELETE /ciphers/purge` for empty-trash. Existing `VaultRepository` protocol gains corresponding methods.
- **Presentation**: `VaultListView` context menus, `ItemDetailView` toolbar, new `TrashView` (or sidebar filter), confirmation alerts.
- **No new dependencies** — existing `URLSession` networking and Keychain/crypto stack unchanged.
