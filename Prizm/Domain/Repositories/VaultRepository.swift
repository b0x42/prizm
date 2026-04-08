import Foundation

/// In-memory vault store: write side used by `SyncRepositoryImpl`, read side used by use cases.
/// Throws `VaultError.vaultLocked` when read methods are called before a successful unlock + sync.
/// Implemented by `VaultRepositoryImpl` in the Data layer.
protocol VaultRepository: AnyObject, Sendable {

    /// Timestamp of the last successful sync, or nil if no sync has occurred this session.
    var lastSyncedAt: Date? { get }

    /// All non-deleted vault items, sorted alphabetically by name (case-insensitive).
    func allItems() throws -> [VaultItem]

    /// Items matching the given sidebar selection, sorted alphabetically.
    /// - `.allItems`: same as `allItems()`.
    /// - `.favorites`: items where `isFavorite == true`.
    /// - `.type(t)`: items whose `content` matches `t`.
    func items(for selection: SidebarSelection) throws -> [VaultItem]

    /// Case-insensitive substring search scoped to the active sidebar selection.
    /// Searches type-specific fields per FR-012:
    /// - Login:      name, username, URIs
    /// - Card:       name, cardholderName
    /// - Identity:   name, email, company
    /// - SecureNote: name
    /// - SSHKey:     name
    func searchItems(query: String, in selection: SidebarSelection) throws -> [VaultItem]

    /// Cached item counts keyed by `SidebarSelection`.
    /// Computed once after sync and held for the session.
    func itemCounts() throws -> [SidebarSelection: Int]

    /// Returns the fully-decrypted detail for a single item.
    /// Not cached — re-decrypts on every call (decrypt on demand, per spec).
    func itemDetail(id: String) async throws -> VaultItem

    /// Replaces the in-memory vault store with `items` and `folders`, and records the sync timestamp.
    /// Called by `SyncRepositoryImpl` after a successful sync.
    func populate(items: [VaultItem], folders: [Folder], syncedAt: Date)

    /// Clears the in-memory vault store (items and folders). Called on lock and sign-out.
    func clearVault()

    /// All folders, sorted alphabetically by name (case-insensitive).
    func folders() throws -> [Folder]

    /// Re-encrypts `draft`, calls `PUT /ciphers/{id}`, updates the in-memory cache, and
    /// returns the server-confirmed `VaultItem` decoded from the API response.
    ///
    /// - Parameter draft: The user's edited draft.
    /// - Returns: The authoritative `VaultItem` as returned by the server.
    /// - Throws: `VaultError.vaultLocked` if the vault is locked (translated from the Data layer).
    /// - Throws: `APIError` on network or HTTP failure.
    func update(_ draft: DraftVaultItem) async throws -> VaultItem

    /// Soft-deletes the item with `id` by calling `PUT /ciphers/{id}/delete`.
    ///
    /// The item moves to Trash (`isDeleted == true`) on the server and remains in the
    /// local cache (visible under `.trash`). It can be recovered via `restoreItem(id:)`.
    ///
    /// - Throws: `Error` on network or HTTP failure.
    func deleteItem(id: String) async throws

    /// Permanently removes the trashed item with `id` by calling `DELETE /ciphers/{id}`.
    ///
    /// **This operation is irreversible.** The item is removed from the server and from
    /// the local cache. The item must already be in Trash (`isDeleted == true`).
    ///
    /// - Throws: `Error` on network or HTTP failure.
    func permanentDeleteItem(id: String) async throws

    /// Restores a trashed item by calling `PUT /ciphers/{id}/restore`.
    ///
    /// Clears `isDeleted` on the server and moves the item back to the active vault
    /// in the local cache.
    ///
    /// - Throws: `Error` on network or HTTP failure.
    func restoreItem(id: String) async throws

    /// Encrypts a new `draft`, calls `POST /api/ciphers`, inserts the server-confirmed item
    /// into the in-memory cache, and returns it.
    func create(_ draft: DraftVaultItem) async throws -> VaultItem

    // MARK: - Folder CRUD

    /// Creates a folder with the given plaintext name. Encryption handled internally.
    func createFolder(name: String) async throws -> Folder

    /// Renames a folder. Encryption handled internally.
    func renameFolder(id: String, name: String) async throws -> Folder

    /// Deletes a folder. Items in the folder become unfoldered.
    func deleteFolder(id: String) async throws

    // MARK: - Move to folder

    /// Moves a single item to a folder (or removes from folder if nil).
    func moveItemToFolder(itemId: String, folderId: String?) async throws

    /// Moves multiple items to a folder in a single API call.
    func moveItemsToFolder(itemIds: [String], folderId: String?) async throws

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
