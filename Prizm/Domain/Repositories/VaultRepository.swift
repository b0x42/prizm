import Foundation

/// In-memory vault store: write side used by `SyncRepositoryImpl`, read side used by use cases.
/// Implemented by `VaultRepositoryImpl` (a dedicated `actor`) in the Data layer.
/// All methods are `async` — callers must `await` them regardless of their own isolation context.
protocol VaultRepository: AnyObject, Sendable {

    /// All non-deleted vault items, sorted alphabetically by name (case-insensitive).
    func allItems() async throws -> [VaultItem]

    /// Items matching the given sidebar selection, sorted alphabetically.
    func items(for selection: SidebarSelection) async throws -> [VaultItem]

    /// Case-insensitive substring search scoped to the active sidebar selection.
    /// Searches type-specific fields per FR-012:
    /// - Login:      name, username, URIs
    /// - Card:       name, cardholderName
    /// - Identity:   name, email, company
    /// - SecureNote: name
    /// - SSHKey:     name
    func searchItems(query: String, in selection: SidebarSelection) async throws -> [VaultItem]

    /// Cached item counts keyed by `SidebarSelection`. O(1) — served from a pre-built index.
    func itemCounts() async throws -> [SidebarSelection: Int]

    /// Returns the fully-decrypted detail for a single item.
    /// Not cached — re-decrypts on every call (decrypt on demand, per spec).
    func itemDetail(id: String) async throws -> VaultItem

    /// Replaces the in-memory vault store and rebuilds all read indexes.
    /// Called by `SyncRepositoryImpl` after a successful sync.
    func populate(items: [VaultItem], folders: [Folder], organizations: [Organization],
                  collections: [OrgCollection], syncedAt: Date) async

    /// All organizations the user belongs to, sorted alphabetically by name.
    func organizations() async throws -> [Organization]

    /// All collections across all organizations, sorted alphabetically by name.
    func collections() async throws -> [OrgCollection]

    /// Items assigned to the given collection, sorted alphabetically by name.
    func items(for collection: String) async throws -> [VaultItem]

    /// Clears the in-memory vault store and all indexes. Called on lock and sign-out.
    func clearVault() async

    /// All folders, sorted alphabetically by name (case-insensitive).
    func folders() async throws -> [Folder]

    /// Re-encrypts `draft`, calls `PUT /ciphers/{id}`, updates the in-memory cache, and
    /// returns the server-confirmed `VaultItem` decoded from the API response.
    func update(_ draft: DraftVaultItem) async throws -> VaultItem

    /// Soft-deletes the item with `id` by calling `PUT /ciphers/{id}/delete`.
    func deleteItem(id: String) async throws

    /// Permanently removes the trashed item with `id` by calling `DELETE /ciphers/{id}`.
    func permanentDeleteItem(id: String) async throws

    /// Restores a trashed item by calling `PUT /ciphers/{id}/restore`.
    func restoreItem(id: String) async throws

    /// Encrypts a new `draft`, calls `POST /api/ciphers`, inserts the server-confirmed item
    /// into the in-memory cache, and returns it.
    func create(_ draft: DraftVaultItem) async throws -> VaultItem

    /// Replaces the `attachments` array for the vault item identified by `cipherId`,
    /// patching the in-memory cache without a full re-sync.
    func updateAttachments(_ attachments: [Attachment], for cipherId: String) async

    // MARK: - Folder CRUD

    func createFolder(name: String) async throws -> Folder
    func renameFolder(id: String, name: String) async throws -> Folder
    func deleteFolder(id: String) async throws

    // MARK: - Move to folder

    func moveItemToFolder(itemId: String, folderId: String?) async throws
    func moveItemsToFolder(itemIds: [String], folderId: String?) async throws

    // MARK: - Collection CRUD

    func createCollection(name: String, organizationId: String) async throws -> OrgCollection
    func renameCollection(id: String, organizationId: String, name: String) async throws -> OrgCollection
    func deleteCollection(id: String, organizationId: String) async throws

}

// MARK: - Errors

nonisolated enum VaultError: Error, LocalizedError {
    case vaultLocked
    case decryptionFailed(String)
    case itemNotFound(String)

    var errorDescription: String? {
        switch self {
        case .vaultLocked:
            return "The vault is locked. Please unlock to continue."
        case .decryptionFailed(let detail):
            return "Decryption failed: \(detail)"
        case .itemNotFound(let id):
            return "Item not found: \(id)"
        }
    }
}
