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

- **Reuse `ItemEditView` in a "create" mode** rather than building a separate creation form. The view model has two initialisers — `init(item:useCase:)` for edit mode and `init(type:useCase:)` for create mode — so the type system enforces the correct use case at compile time. This avoids duplicating form UI and validation logic. Alternative: a separate `ItemCreateView` — rejected because the fields are identical.

- **Blank draft factory on `DraftVaultItem`** (`DraftVaultItem.blank(type:)`) rather than on the view model. This keeps the domain layer responsible for default values and makes it testable without UI. The factory generates a temporary UUID as the `id` which is discarded when the server assigns the real one.

- **New `CreateVaultItemUseCase`** rather than overloading `EditVaultItemUseCase`. Create and update are semantically different operations (POST vs PUT, no pre-existing ID). Keeping them separate follows the existing single-responsibility pattern.

- **Type picker as a `+` button embedded in the content column view body** (not a `ToolbarItem`) immediately above the item list. macOS `NavigationSplitView` uses a single unified `NSToolbar`; `ToolbarItem` placements such as `.primaryAction` and `.automatic` resolve relative to whichever column currently holds keyboard focus, so clicking a sidebar row drifted the button to the search-bar area. Embedding it in the `VStack` view body keeps its position unconditionally stable. The button is a plain `Button` (not SwiftUI `Menu`) that opens a `popover` containing `NewItemTypePickerView` — a `List` with single-selection binding. Using `Menu` was rejected because SwiftUI propagates `.keyboardShortcut` to every child `Button` inside a `Menu`, which caused ⌘N to appear as a shortcut annotation on every item-type row. The `Button` + popover approach keeps ⌘N on the trigger only; `List` provides native ↑/↓ navigation and Enter-to-confirm via `.onKeyPress(.return)`.

## Risks / Trade-offs

- [Low] `DraftVaultItem` currently requires an `id` at init. The blank factory will use `UUID().uuidString` as a placeholder. The server response provides the real ID. → The `create` method on `VaultRepository` must use the server-returned item (not the draft) when inserting into the cache, same as `update` already does.
- [Low] The edit sheet's `hasChanges` logic compares draft to original. For create mode, the original is the blank draft, so any field edit triggers `hasChanges = true`. → This is correct behaviour — a blank unsaved item should prompt discard confirmation if the user typed anything.
