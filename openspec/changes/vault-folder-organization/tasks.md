## 1. Wire Models & Sync

- [ ] 1.1 Add `RawFolder` model (`id: String`, `name: String`, `revisionDate: String?`) to `Data/Network/Models/`
- [ ] 1.2 Add `folders: [RawFolder]` to `SyncResponse`
- [ ] 1.3 Add `folderId: String?` to `RawCipher`

## 2. Domain Entities

- [ ] 2.1 Create `Folder` entity (`id: String`, `name: String`) in `Domain/Entities/`
- [ ] 2.2 Add `folderId: String?` to `VaultItem` (with default `nil` in init)
- [ ] 2.3 Add `var folderId: String?` to `DraftVaultItem` and `DraftVaultItem.blank(type:)`
- [ ] 2.4 Add `.folder(String)` case to `SidebarSelection` (update `Equatable`, `Hashable`, `displayName`)
- [ ] 2.5 Add `.folders` case to `SidebarSection`

## 3. Mapper & Crypto

- [ ] 3.1 Pass through `folderId` in `CipherMapper.map(raw:keys:)` → `VaultItem`
- [ ] 3.2 Include `folderId` in `CipherMapper.toRawCipher(_:encryptedWith:)` output
- [ ] 3.3 Update `CipherMapperTests` to verify `folderId` pass-through (forward and reverse)
- [ ] 3.4 Add folder name decrypt in `SyncRepositoryImpl` using existing `EncString.decrypt(keys:)` path
- [ ] 3.5 Add folder name encrypt in use case impls using existing `EncString.encrypt(data:keys:)` path

## 4. API Client

- [ ] 4.1 Add `createFolder(encryptedName: String) async throws -> RawFolder` to `PrizmAPIClientProtocol` and impl (`POST /api/folders`)
- [ ] 4.2 Add `updateFolder(id: String, encryptedName: String) async throws -> RawFolder` (`PUT /api/folders/{id}`)
- [ ] 4.3 Add `deleteFolder(id: String) async throws` (`DELETE /api/folders/{id}`)
- [ ] 4.4 Add `updateCipherPartial(id: String, folderId: String?, favorite: Bool) async throws` (`PUT /ciphers/{id}/partial`)
- [ ] 4.5 Add `moveCiphersToFolder(ids: [String], folderId: String?) async throws` (`PUT /ciphers/move`)
- [ ] 4.6 Update `MockPrizmAPIClient` with folder endpoint stubs

## 5. Repository Layer

- [ ] 5.1 Add `folders: [Folder]` storage to `VaultRepositoryImpl` with populate/clear
- [ ] 5.2 Add `folders() throws -> [Folder]` to `VaultRepository` protocol and impl (sorted alphabetically)
- [ ] 5.3 Update `VaultRepository.populate` to accept folders alongside items
- [ ] 5.4 Update `SyncRepositoryImpl.sync` to decrypt folder names from `syncResponse.folders` and pass to `vaultRepository.populate`
- [ ] 5.5 Update `VaultRepositoryImpl.items(for:)` to handle `.folder(id)` selection (filter by `folderId`)
- [ ] 5.6 Update `VaultRepositoryImpl.itemCounts()` to include per-folder counts
- [ ] 5.7 Update `VaultRepositoryImpl.searchItems(query:in:)` to support folder-scoped search
- [ ] 5.8 Add folder CRUD methods to `VaultRepository`: `createFolder`, `renameFolder`, `deleteFolder` (encrypt name, call API, update local cache)
- [ ] 5.9 Add `moveItemToFolder(itemId:folderId:)` and `moveItemsToFolder(itemIds:folderId:)` to `VaultRepository` (call partial/move API, update local folderId)
- [ ] 5.10 Update `MockVaultRepository` with folder methods and `folderId` support
- [ ] 5.11 Add `VaultRepositoryImplTests` for folder-scoped filtering, counts, and folder CRUD
- [ ] 5.12 Add tests for move-to-folder (single and bulk, local cache update)

## 6. Domain Use Cases

- [ ] 6.1 Create `CreateFolderUseCase` protocol in Domain and `CreateFolderUseCaseImpl` in Data
- [ ] 6.2 Create `RenameFolderUseCase` protocol in Domain and `RenameFolderUseCaseImpl` in Data
- [ ] 6.3 Create `DeleteFolderUseCase` protocol in Domain and `DeleteFolderUseCaseImpl` in Data
- [ ] 6.4 Create `MoveItemToFolderUseCase` protocol in Domain and `MoveItemToFolderUseCaseImpl` in Data (handles single and bulk)
- [ ] 6.5 Add use case tests for folder create, rename, delete, and move-to-folder
- [ ] 6.6 Wire use cases in `AppContainer`

## 7. Sidebar UI

- [ ] 7.1 Add `.folders` section to `SidebarView` with dynamic folder rows sorted alphabetically
- [ ] 7.2 Add `folder.badge.plus` button on the Folders section header for folder creation
- [ ] 7.3 Add `.contextMenu` on folder rows with "Rename" and "Delete Folder" actions
- [ ] 7.4 Implement inline rename using SwiftUI `.renameAction` on folder rows
- [ ] 7.5 Add `.dropDestination` on folder rows to accept dragged item IDs
- [ ] 7.6 Always show the Folders section header (with create button); show folder rows only when folders exist

## 8. Item List & Drag

- [ ] 8.1 Change `ItemListView` selection from `VaultItem?` to `Set<String>` for multi-select support
- [ ] 8.2 Update `VaultBrowserViewModel` to handle `Set<String>` selection and derive detail pane item
- [ ] 8.3 Add `.draggable` on item rows with item ID as `Transferable` payload
- [ ] 8.4 Wire drop handler on folder rows to call `MoveItemToFolderUseCase` and refresh counts

## 9. Edit Sheet — Folder Picker

- [ ] 9.1 Add folder `Picker` to `ItemEditView` (all folders + "None", sorted alphabetically)
- [ ] 9.2 Bind picker selection to `DraftVaultItem.folderId`
- [ ] 9.3 Pass folders from `VaultRepository` through to the edit view model

## 10. ViewModel Integration

- [ ] 10.1 Expose `folders` from `VaultBrowserViewModel` for sidebar rendering
- [ ] 10.2 Add folder CRUD actions to `VaultBrowserViewModel` calling use cases (create, rename, delete)
- [ ] 10.3 Add move-to-folder action to `VaultBrowserViewModel` calling `MoveItemToFolderUseCase` (single and bulk)
- [ ] 10.4 Update `refreshCounts` and `refreshItems` to include folder data
- [ ] 10.5 Handle folder deletion: if the deleted folder was selected, switch to All Items
- [ ] 10.6 Add delete folder confirmation alert to `VaultBrowserView`
