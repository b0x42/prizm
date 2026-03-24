## Context

Macwarden already has a complete edit flow: `DraftVaultItem` → `CipherMapper.toRawCipher` → `PUT /api/ciphers/{id}` → cache splice. Item creation follows the same data path except:
1. There is no existing `VaultItem` to initialise the draft from — a blank draft is needed.
2. The API endpoint is `POST /api/ciphers` (no `{id}` in the path) and the server assigns the ID.
3. The response item is appended to the cache rather than spliced in-place.

The edit sheet (`ItemEditView`) and all per-type edit forms (`LoginEditForm`, `CardEditForm`, etc.) are fully reusable — they bind to `DraftVaultItem` and don't care whether it originated from an existing item or a blank factory.

## Goals / Non-Goals

**Goals:**
- Allow users to create new items of all five types from the vault browser
- Reuse the existing edit sheet and cipher mapper — no duplication
- Insert created items into the local cache immediately (no full re-sync)

**Non-Goals:**
- Folder/collection assignment (not supported in v1 edit either)
- Organisation-owned items (personal vault only)
- Offline creation queue (same limitation as edit)
- Attachments or file uploads

## Decisions

- **Reuse `ItemEditView` in a "create" mode** rather than building a separate creation form. The view model receives an optional `VaultItem?` — `nil` means create mode. This avoids duplicating form UI and validation logic. Alternative: a separate `ItemCreateView` — rejected because the fields are identical.

- **Blank draft factory on `DraftVaultItem`** (`DraftVaultItem.blank(type:)`) rather than on the view model. This keeps the domain layer responsible for default values and makes it testable without UI. The factory generates a temporary UUID as the `id` which is discarded when the server assigns the real one.

- **New `CreateVaultItemUseCase`** rather than overloading `EditVaultItemUseCase`. Create and update are semantically different operations (POST vs PUT, no pre-existing ID). Keeping them separate follows the existing single-responsibility pattern.

- **Type picker as a `+` button in the content column toolbar** (above the item list, alongside the search bar) rather than in the main window toolbar or a multi-step wizard. This keeps the action close to the list it affects. The button opens a menu listing all five types; selecting one opens the edit sheet immediately.

## Risks / Trade-offs

- [Low] `DraftVaultItem` currently requires an `id` at init. The blank factory will use `UUID().uuidString` as a placeholder. The server response provides the real ID. → The `create` method on `VaultRepository` must use the server-returned item (not the draft) when inserting into the cache, same as `update` already does.
- [Low] The edit sheet's `hasChanges` logic compares draft to original. For create mode, the original is the blank draft, so any field edit triggers `hasChanges = true`. → This is correct behaviour — a blank unsaved item should prompt discard confirmation if the user typed anything.
