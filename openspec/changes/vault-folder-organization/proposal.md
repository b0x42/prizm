## Why

Prizm has no concept of folders. Users who organise their Bitwarden/Vaultwarden vault into folders (via the web vault or another client) see a flat list in Prizm with no way to browse by folder. The Bitwarden sync API already returns folder data (`folders[]` array and `folderId` on each cipher), but Prizm ignores both. Adding folder support lets users organise items the way they already do on other clients, and manage folders entirely from Prizm without switching to the web vault.

## What Changes

- Parse `folders` from the sync response and `folderId` from each cipher during sync
- Introduce a `Folder` domain entity (id, decrypted name) and store folders in the vault repository alongside items
- Add a "Folders" section to the sidebar between Menu and Types, sorted alphabetically by name, with per-folder item counts
- Add folder CRUD: create (Apple Mail-style button on section header), rename (select + Enter or right-click → Rename), delete (right-click → Delete) via the Bitwarden folder API endpoints
- Add a folder picker to the item edit/create sheet so users can assign or change an item's folder
- Support drag-and-drop of items (single and multi-select) onto sidebar folder rows to move items between folders, using `PUT /ciphers/{id}/partial` for single moves and `PUT /ciphers/move` for bulk moves
- Items without a `folderId` have no dedicated sidebar row — they remain accessible via All Items, Favorites, and Type filters
- Folders are flat (no nested Parent/Child convention)
- Folder names are encrypted client-side (EncString type-2) before being sent to the server, matching the existing cipher encryption pattern

## Capabilities

### New Capabilities
- `vault-folder-organization`: Folder browsing, CRUD, item-to-folder assignment, and drag-and-drop in the sidebar

### Modified Capabilities
- `vault-browser-ui`: Sidebar gains a new "Folders" section with dynamic rows, item counts, context menus, and drop targets; `SidebarSelection` gains a `.folder(id)` case; item list supports multi-select for bulk drag operations
- `vault-item-create`: Create sheet gains a folder picker field; new items can be assigned to a folder at creation time

## Impact

- **Wire models**: `SyncResponse` adds `folders: [RawFolder]`; `RawCipher` adds `folderId: String?`
- **Domain entities**: New `Folder` struct; `VaultItem` and `DraftVaultItem` gain `folderId: String?`; `SidebarSelection` gains `.folder(String)` case; `SidebarSection` gains `.folders` case
- **Crypto**: Folder names require encrypt/decrypt using the existing EncString type-2 (AES-256-CBC + HMAC-SHA256) path — no new crypto primitives
- **API client**: New endpoints: `POST /api/folders`, `PUT /api/folders/{id}`, `DELETE /api/folders/{id}`, `PUT /ciphers/{id}/partial`, `PUT /ciphers/move`
- **Repository layer**: `VaultRepository` stores and queries folders; `VaultRepositoryImpl` adds folder-scoped item filtering and folder counts
- **Presentation**: `SidebarView`, `VaultBrowserViewModel`, `ItemEditView`, `ItemListView` all modified; new folder management UI in sidebar
- **Tests**: Existing vault repository, cipher mapper, and view model tests need updates for `folderId`; new tests for folder CRUD, drag-and-drop, and folder-scoped filtering
