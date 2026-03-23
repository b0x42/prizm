import Foundation

/// In-memory vault store: write side used by `SyncRepositoryImpl`, read side used by use cases.
/// Throws `VaultError.vaultLocked` when read methods are called before a successful unlock + sync.
/// Implemented by `VaultRepositoryImpl` in the Data layer.
protocol VaultRepository: AnyObject {

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

    /// Replaces the in-memory vault store with `items` and records the sync timestamp.
    /// Called by `SyncRepositoryImpl` after a successful sync.
    func populate(items: [VaultItem], syncedAt: Date)

    /// Clears the in-memory vault store. Called on lock and sign-out.
    func clearVault()

    /// Re-encrypts `draft`, calls `PUT /ciphers/{id}`, updates the in-memory cache, and
    /// returns the server-confirmed `VaultItem` decoded from the API response.
    ///
    /// - Parameter draft: The user's edited draft.
    /// - Returns: The authoritative `VaultItem` as returned by the server.
    /// - Throws: `VaultError.vaultLocked` if the vault is locked (translated from the Data layer).
    /// - Throws: `APIError` on network or HTTP failure.
    func update(_ draft: DraftVaultItem) async throws -> VaultItem
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
