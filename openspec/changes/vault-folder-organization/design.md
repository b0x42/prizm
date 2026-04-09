## Context

Prizm is a native macOS Bitwarden/Vaultwarden client. The vault browser uses a three-pane `NavigationSplitView` with sidebar categories (All Items, Favorites, Types, Trash), an item list, and a detail pane. Items are stored in a flat `[VaultItem]` array in `VaultRepositoryImpl`. The Bitwarden sync API already returns `folders[]` and `folderId` on each cipher, but Prizm ignores both. Folder names are encrypted as EncString type-2 (AES-256-CBC + HMAC-SHA256), the same format used for cipher field encryption.

The existing architecture follows a clean layered pattern: wire models (`RawCipher`, `SyncResponse`) → mapper (`CipherMapper`) → domain entities (`VaultItem`) → repository (`VaultRepository`) → use cases → view models → views. Folder support threads through every layer.

## Goals / Non-Goals

**Goals:**
- Parse and display folders from the Bitwarden sync response
- Full folder CRUD (create, rename, delete) via the Bitwarden folder API
- Assign items to folders via edit sheet picker and drag-and-drop
- Sidebar "Folders" section with Apple Mail-style interactions (header create button, right-click context menu, Enter-to-rename)
- Single-item drag-and-drop of items onto folder rows
- Folder-scoped search when a folder is selected

**Non-Goals:**
- "No Folder" sidebar row — unfoldered items accessible via All Items / Types
- Manual folder reordering — alphabetical sort only
- Organisation folder support — personal vault only (consistent with existing org cipher exclusion)
- Offline folder CRUD — requires active server connection (consistent with existing item CRUD)

## Decisions

### Decision 1: Folders stored in VaultRepository alongside items

Store `[Folder]` in `VaultRepositoryImpl` next to the existing `[VaultItem]` array. Both are populated during sync and cleared on lock/sign-out.

**Rationale**: Folders and items are always synced together and queried together (sidebar needs both for counts). A separate `FolderRepository` would add wiring complexity in `AppContainer` with no architectural benefit. The vault repository is already the in-memory vault store — folders are part of the vault.

**Alternative considered**: Separate `FolderRepository` actor — rejected because it would require coordinating two stores during sync and querying across two repositories for sidebar counts.

### Decision 2: Use PUT /ciphers/{id}/partial for single-item folder moves

For drag-and-drop of a single item, use `PUT /ciphers/{id}/partial` with `{ folderId, favorite }`. For multi-item moves, use `PUT /ciphers/move` with `{ ids, folderId }`.

**Rationale**: The `/partial` endpoint only sends the folder ID and favorite flag — no re-encryption of the entire cipher is needed. This is the same endpoint the official Bitwarden client uses for folder moves. The `/move` endpoint handles bulk operations in a single request. Both are supported on Vaultwarden 1.35.4+.

**Alternative considered**: Re-encrypting the full cipher via `PUT /ciphers/{id}` — rejected because it's heavyweight (decrypt → create draft → modify folderId → re-encrypt → PUT) for a metadata-only change, and risks overwriting concurrent edits.

### Decision 3: Apple Mail-style folder management in sidebar

- Create: small `folder.badge.plus` SF Symbol button on the "Folders" section header
- Rename: right-click context menu → "Rename" triggers inline editable text field via SwiftUI `.renameAction`
- Delete: right-click context menu → "Delete Folder" with confirmation alert

**Rationale**: Matches macOS platform conventions. SwiftUI provides `.renameAction` (macOS 14+), `.contextMenu`, and `.dropDestination` as built-in primitives. Prizm targets macOS 26, so all APIs are available.

### Decision 4: Multi-select deferred to follow-up change

Multi-select (`Set<String>` selection on `ItemListView`) was originally planned for this change but deferred due to the cross-cutting refactor required (touches ItemListView, TrashView, VaultBrowserView, VaultBrowserViewModel, and all selection callbacks). Single-item drag-and-drop covers the primary use case. Bulk drag-and-drop via `PUT /ciphers/move` is implemented in the Data layer and ready for when multi-select is added.

### Decision 5: folderId as a plain String? pass-through on VaultItem

`folderId` is not encrypted — it's a UUID string on the wire. It passes through `CipherMapper` without decryption, stored directly on `VaultItem` and `DraftVaultItem`. The `RawCipher` model gains `folderId: String?` and the reverse mapper (`toRawCipher`) includes it in the output.

**Rationale**: Unlike cipher field values, `folderId` is a server-assigned UUID, not user content. No crypto operations needed.

### Decision 6: Folder name encryption/decryption reuses existing EncString path

Folder names are EncString type-2, identical to cipher field encryption. Decryption during sync uses the same `EncString.decrypt(keys:)` path. Encryption for create/rename uses the same `EncString.encrypt(data:keys:)` path. No new crypto code is needed.

### Decision 7: Drag-and-drop uses SwiftUI .draggable / .dropDestination

Item rows use `.draggable` with the item ID as the transferable payload. Folder sidebar rows use `.dropDestination` to accept item IDs. SwiftUI provides default `isTargeted` highlight feedback on the drop target.

**Rationale**: Platform-standard drag-and-drop with minimal custom code. The `Transferable` protocol with a simple string ID payload avoids serialising full item data.

### Decision 8: Folder operations go through Domain use cases

Folder CRUD and move-to-folder operations follow the same use case pattern as existing item operations (`CreateVaultItemUseCase`, `EditVaultItemUseCase`, etc.). Each operation gets a protocol in Domain and an implementation in Data:
- `CreateFolderUseCase` — calls `VaultRepository.createFolder(name:)`
- `RenameFolderUseCase` — calls `VaultRepository.renameFolder(id:name:)`
- `DeleteFolderUseCase` — calls `VaultRepository.deleteFolder(id:)`
- `MoveItemToFolderUseCase` — calls `VaultRepository.moveItemToFolder` / `moveItemsToFolder`

`VaultRepositoryImpl` handles encryption of folder names internally (same as how it calls `CipherMapper.toRawCipher` before `apiClient.createCipher`). Use case impls are thin coordinators — they do not call the API client or crypto directly. ViewModels call use cases, never repository methods directly. This preserves the Clean Architecture layer boundary (Constitution §II).

### Decision 9: Folder name encryption happens in VaultRepositoryImpl

`VaultRepository` protocol methods accept plaintext folder names (e.g. `createFolder(name: String)`). `VaultRepositoryImpl` encrypts the name via `EncString.encrypt(data:keys:)` before passing the encrypted string to the API client. This matches the existing pattern: `VaultRepositoryImpl.create(_:)` calls `CipherMapper.toRawCipher` (which encrypts) before calling `apiClient.createCipher`. Plaintext folder names never reach the API client layer. The Domain protocol stays crypto-free (Constitution §II).

### Decision 10: Partial update response is not used to update cached cipher data

The `PUT /ciphers/{id}/partial` response returns cipher details, but we only use it to confirm success. The local cache is updated by setting `folderId` on the existing `VaultItem` directly, not by re-mapping the response. This avoids re-decrypting the response and is consistent with how `deleteItem`/`restoreItem` update the cache by mutating the existing item.

### Decision 11: Folder decryption goes through PrizmCryptoService

`SyncRepositoryImpl` calls `crypto.decryptFolders(folders:)` — a new method on `PrizmCryptoService` that mirrors the existing `decryptList(ciphers:)` pattern. This keeps all crypto behind the service protocol boundary (Constitution §III). The method retrieves the current keys internally and decrypts each `RawFolder.name` EncString, returning `[Folder]`.

### Decision 12: Nested folders via slash-delimited naming convention

Bitwarden represents folder hierarchy through a naming convention: a folder named `"Work/Projects"` is treated as a child of `"Work"`. The server stores all folders as a flat list — there is no parent-child relationship in the API. Prizm parses the `/` delimiter at render time to build a tree for sidebar display.

Parent nodes that have no corresponding flat folder entry (e.g. "Work" when only "Work/Projects" exists) are rendered as virtual parents — they have no `folderId` and cannot be selected or receive drops; they exist only as collapsible containers. Real parent folders (where "Work" also exists as its own folder) are selectable and receive drops.

Collapse state is persisted per-session in a `@State` `Set<String>` keyed by folder ID (or virtual path). UserDefaults persistence is deferred.

Selecting a folder in the sidebar shows only items directly assigned to that exact folder (matching `folderId` == folder.id). Items in child folders are NOT included — consistent with Bitwarden Web behavior.

### Decision 13: Folder picker in edit sheet follows field-row visual style

The default SwiftUI `Picker` renders as a bordered menu button that is visually inconsistent with the label-above-value field rows used throughout the edit sheet. The folder picker SHALL be replaced with a `Menu`-based or `Picker(.menu)` styled component wrapped in the same field row container used for other fields (label on top, value below, same horizontal padding and separator). This preserves the existing `Picker` binding semantics while matching the design system.

### Decision 14: Cmd+F search preserves active sidebar selection

The existing Cmd+F handler focuses the search field but implicitly searches All Items when a folder is selected. The correct behaviour is to scope the search to the currently selected sidebar item. Since `VaultBrowserViewModel` already scopes `searchItems` to the current selection, the fix is ensuring the `selection` binding is not reset when the search field is activated.

### Decision 15: Folder shown in item detail view

The detail pane displays field sections for the item's content (credentials, notes, etc.) but currently omits folder assignment. A "Folder" row SHALL be appended after the last content section when `item.folderId != nil`. The row shows the resolved folder name (looked up from the in-memory folder list). When `folderId` is nil the row is omitted entirely.

## Risks / Trade-offs

**[Risk] Inline rename in NavigationSplitView sidebar has had SwiftUI bugs** → Mitigation: Use `.renameAction` (the official API) rather than hand-rolling TextField-in-List. If the API has issues on macOS 26, fall back to a rename alert/popover.

**[Risk] PUT /ciphers/{id}/partial was subject to a Vaultwarden security vulnerability (CVE-2026-27898)** → Mitigation: The vulnerability was an authorization bypass (accessing other users' ciphers), patched in Vaultwarden 1.35.4. Prizm already targets 1.35.4+ as the minimum version. The endpoint itself is stable and correct for the authenticated user's own ciphers.

**[Trade-off] No "No Folder" row means users can't quickly see which items are unorganised** → Accepted: keeps the sidebar clean. Users who want to find unfoldered items can browse All Items and notice which items lack a folder indicator.
