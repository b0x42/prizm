## Context

Macwarden currently allows users to view and edit vault items but provides no way to delete or restore them. Bitwarden's server already implements a soft-delete model: deleting a cipher moves it to a trash collection (sets `deletedDate`); it can be restored or permanently purged. The macOS client needs to expose these actions through the existing `VaultRepository` abstraction, map the new `deletedDate` field, and surface trash management UI.

The existing architecture — Domain use cases, Data repository implementations, and SwiftUI Presentation — is a clean fit for this change with no architectural deviation needed.

## Goals / Non-Goals

**Goals:**
- Soft-delete vault items via `DELETE /ciphers/{id}` (move to trash).
- Permanently delete a single trashed item via `DELETE /ciphers/{id}` when already in trash.
- Restore a trashed item via `PUT /ciphers/{id}/restore`.
- Surface trashed items in a Trash sidebar section.
- Provide empty-trash bulk action via `DELETE /ciphers/purge`.
- Confirmation alerts before destructive actions (permanent delete, empty trash).
- Full undo path: user can always restore before choosing permanent delete.

**Non-Goals:**
- Offline / queued delete (requires sync engine — future work).
- Bulk soft-delete of multiple items in one action (single-item scope for this change).
- Folder / collection delete (cipher-level only).
- Attachment delete.

## Decisions

### D1: Reuse `VaultRepository` protocol — add three new methods

Add `deleteItem(id:)`, `restoreItem(id:)`, and `emptyTrash()` to the existing `VaultRepository` protocol rather than creating a separate `TrashRepository`. The operations are semantically vault mutations, and keeping them co-located reduces protocol proliferation.

*Alternative considered*: Separate `TrashRepository` protocol. Rejected — overkill for three closely related methods; the vault is the single source of truth.

### D2: `deletedDate: Date?` on `VaultItem` entity to represent trash state

Adding an optional `deletedDate` to the `VaultItem` Domain entity is the minimal change to convey trash state. Views filter or section by `deletedDate != nil`.

*Alternative considered*: Separate `TrashedVaultItem` type. Rejected — doubles mapping code; a nil-able date is idiomatic Swift for optional presence.

### D3: Soft-delete is the default; hard-delete requires a second confirmation

Following Bitwarden's UX convention: the first Delete action is always a soft-delete to trash. Hard-delete (permanent) is a separate explicit action available only on trashed items. Empty-trash presents a confirmation alert before purging all.

### D4: Trash shown as a sidebar section below the main vault list

A dedicated "Trash" entry in the sidebar `NavigationSplitView` sidebar column keeps trash visually distinct without requiring a separate navigation stack. Selecting it shows a filtered list of items where `deletedDate != nil`.

*Alternative considered*: A toolbar filter toggle. Rejected — trash is a fundamentally different state from filtered active items; a sidebar entry matches Bitwarden's web/desktop convention.

### D5: Network errors surface as typed errors via existing error-handling pattern

No new error types needed. Existing `VaultRepositoryError` (or equivalent) covers HTTP 4xx/5xx. The Presentation layer displays these via the standard alert mechanism already used for edit/unlock failures.

## Risks / Trade-offs

- **Stale local state after delete** → Mitigation: invalidate/refetch the in-memory vault cache after each mutating operation; navigate back to the list if the detail view's item is deleted.
- **Empty trash is irreversible** → Mitigation: two-step confirmation alert with clear destructive wording ("Permanently delete all X items?").
- **`deletedDate` absent from older cached sync responses** → Mitigation: treat missing field as `nil` (item is active); JSON decoder already uses optional mapping.
- **Race between soft-delete and background sync** → Mitigation: local optimistic remove from active list on success; next sync reconciles server state.

## Migration Plan

1. Add `deletedDate: Date?` to `VaultItem` entity and update JSON mapper (additive, non-breaking).
2. Add three methods to `VaultRepository` protocol; stub `VaultRepositoryImpl` to compile.
3. Implement API calls in `VaultRepositoryImpl`.
4. Implement Domain use cases (`DeleteVaultItemUseCase`, `RestoreVaultItemUseCase`, `EmptyTrashUseCase`).
5. Update `VaultListViewModel` to split items by `deletedDate`.
6. Add Trash sidebar entry and `TrashView`.
7. Wire context-menu and toolbar actions.
8. Write unit tests for use cases and mappers; XCUITest for delete/restore journey.

No migration of persisted data — `deletedDate` is server-side state fetched on sync.
