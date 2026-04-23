import Foundation
import os.log

// MARK: - VaultRepositoryImpl

/// In-memory vault store, populated by `SyncRepositoryImpl` after each sync.
///
/// All items are held in a flat `[VaultItem]` array. `populate()` rebuilds three
/// pre-computed indexes so that read methods are O(1) lookups instead of O(n) scans.
/// Every write method that mutates the raw stores calls `buildIndexes()` to keep the
/// cache consistent without waiting for the next sync.
///
/// Thread safety: this type is a Swift `actor`. All mutations and reads execute on the
/// actor's cooperative-thread-pool executor — never on the main thread.
actor VaultRepositoryImpl: VaultRepository {

    private let logger = Logger(subsystem: "com.prizm", category: "VaultRepository")

    // MARK: - Dependencies (write path)

    private let apiClient:   any PrizmAPIClientProtocol
    private let crypto:      any PrizmCryptoService
    private let mapper:      CipherMapper
    private let orgKeyCache: OrgKeyCache

    // MARK: - Raw stores

    private var items: [VaultItem] = []
    private var folderStore: [Folder] = []
    private var organizationStore: [Organization] = []
    private var collectionStore: [OrgCollection] = []

    /// Internal sync timestamp; not exposed on the protocol (use `GetLastSyncDateUseCase`).
    private(set) var lastSyncedAt: Date? = nil

    // MARK: - Read indexes (rebuilt by buildIndexes() after every mutation)

    /// Pre-filtered, sorted item lists keyed by SidebarSelection.
    private var _bySelection: [SidebarSelection: [VaultItem]] = [:]

    /// Pre-computed counts keyed by SidebarSelection.
    private var _counts: [SidebarSelection: Int] = [:]

    /// Maps orgId → Set<collectionId> for O(1) org-membership tests.
    private var _orgCollectionIds: [String: Set<String>] = [:]

    // MARK: - Init

    init(
        apiClient:   any PrizmAPIClientProtocol,
        crypto:      any PrizmCryptoService,
        mapper:      CipherMapper = CipherMapper(),
        orgKeyCache: OrgKeyCache = OrgKeyCache()
    ) {
        self.apiClient   = apiClient
        self.crypto      = crypto
        self.mapper      = mapper
        self.orgKeyCache = orgKeyCache
    }

    // MARK: - Write side (called by SyncRepositoryImpl)

    func populate(items: [VaultItem], folders: [Folder], organizations: [Organization],
                  collections: [OrgCollection], syncedAt: Date) async {
        self.items             = items
        self.folderStore       = folders
        self.organizationStore = organizations
        self.collectionStore   = collections
        self.lastSyncedAt      = syncedAt
        buildIndexes()
        logger.info("Vault populated: \(items.count) item(s), \(folders.count) folder(s), \(organizations.count) org(s), \(collections.count) collection(s)")
    }

    func clearVault() async {
        items             = []
        folderStore       = []
        organizationStore = []
        collectionStore   = []
        lastSyncedAt      = nil
        _bySelection      = [:]
        _counts           = [:]
        _orgCollectionIds = [:]
        logger.info("Vault cleared")
    }

    // MARK: - Index builder

    private func buildIndexes() {
        // Local staging variable — not stored; _bySelection[.allItems] serves the same role.
        let active = items.filter { !$0.isDeleted }

        // Build org-collection map first: used by both _bySelection and _counts.
        var orgColIds: [String: Set<String>] = [:]
        for col in collectionStore {
            orgColIds[col.organizationId, default: []].insert(col.id)
        }
        _orgCollectionIds = orgColIds

        // Build _bySelection
        var bySelection: [SidebarSelection: [VaultItem]] = [:]
        bySelection[.allItems]  = sorted(active)
        bySelection[.favorites] = sorted(active.filter(\.isFavorite))
        bySelection[.trash]     = sorted(items.filter(\.isDeleted))

        for type in ItemType.allCases {
            bySelection[.type(type)] = sorted(active.filter { $0.content.matchesItemType(type) })
        }
        for folder in folderStore {
            bySelection[.folder(folder.id)] = sorted(active.filter {
                $0.organizationId == nil && $0.folderId == folder.id
            })
        }
        for collection in collectionStore {
            bySelection[.collection(collection.id)] = sorted(active.filter {
                $0.collectionIds.contains(collection.id)
            })
        }
        for org in organizationStore {
            let colIds = orgColIds[org.id] ?? []
            bySelection[.organization(org.id)] = sorted(active.filter {
                $0.organizationId == org.id ||
                $0.collectionIds.contains(where: { colIds.contains($0) })
            })
        }
        _bySelection = bySelection

        // Build _counts
        var counts: [SidebarSelection: Int] = [:]
        counts[.allItems]  = active.count
        counts[.favorites] = active.filter(\.isFavorite).count
        counts[.trash]     = items.filter(\.isDeleted).count

        for type in ItemType.allCases {
            counts[.type(type)] = active.filter { $0.content.matchesItemType(type) }.count
        }
        for folder in folderStore {
            counts[.folder(folder.id)] = active.filter {
                $0.organizationId == nil && $0.folderId == folder.id
            }.count
        }
        for collection in collectionStore {
            counts[.collection(collection.id)] = active.filter {
                $0.collectionIds.contains(collection.id)
            }.count
        }
        for org in organizationStore {
            let colIds = orgColIds[org.id] ?? []
            counts[.organization(org.id)] = active.filter {
                $0.organizationId == org.id ||
                $0.collectionIds.contains(where: { colIds.contains($0) })
            }.count
        }
        _counts = counts
    }

    // MARK: - Read side

    func allItems() async throws -> [VaultItem] {
        _bySelection[.allItems] ?? []
    }

    func folders() async throws -> [Folder] {
        folderStore.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func organizations() async throws -> [Organization] {
        organizationStore.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func collections() async throws -> [OrgCollection] {
        collectionStore.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func items(for collection: String) async throws -> [VaultItem] {
        _bySelection[.collection(collection)] ?? []
    }

    func items(for selection: SidebarSelection) async throws -> [VaultItem] {
        switch selection {
        case .newFolder, .newCollection:
            return []
        default:
            return _bySelection[selection] ?? []
        }
    }

    func searchItems(query: String, in selection: SidebarSelection) async throws -> [VaultItem] {
        let base = _bySelection[selection] ?? []
        guard !query.isEmpty else { return base }
        return base.filter { $0.matchesSearch(query: query) }
    }

    func itemCounts() async throws -> [SidebarSelection: Int] {
        _counts
    }

    func itemDetail(id: String) async throws -> VaultItem {
        guard let item = items.first(where: { $0.id == id }) else {
            throw VaultError.itemNotFound(id)
        }
        return item
    }

    // MARK: - Update (write path — called by EditVaultItemUseCaseImpl)

    /// Re-encrypts `draft`, calls `PUT /api/ciphers/{id}`, splices the server-confirmed
    /// item into the in-memory cache, and returns it.
    ///
    /// - Security goal: the vault's symmetric keys are used to re-encrypt every sensitive
    ///   field before the request leaves the device. The re-encryption boundary is the call
    ///   to `CipherMapper.toRawCipher` — after that point only EncString ciphertext exists
    ///   in the `RawCipher` struct. Plaintext is never serialised into the JSON body.
    ///   Algorithm: EncString type-2 (AES-256-CBC + HMAC-SHA256); see `CipherMapper.toRawCipher`
    ///   for the full algorithm reference and security notes.
    ///
    /// - Data flow (re-encryption boundary):
    ///   1. Obtain current symmetric keys from `PrizmCryptoService` — throws immediately
    ///      if the vault is locked, preventing writes from a locked state.
    ///   2. `CipherMapper.toRawCipher` encrypts every sensitive field with the vault key.
    ///      No plaintext value crosses this call boundary in the outbound direction.
    ///   3. The encrypted `RawCipher` is sent via `PUT /api/ciphers/{id}`.
    ///   4. The server response is decoded and re-mapped to a `VaultItem` — we use the
    ///      *response* (not the draft) so the server's revision date and any server-side
    ///      normalisation are captured correctly.
    ///   5. The in-memory cache is patched in-place so the UI reflects the latest state
    ///      without triggering a full re-sync.
    ///
    /// - What is NOT done:
    ///   • Biometric re-authentication is not required before writing (see TODO below).
    ///   • Offline writes are not queued; a network failure surfaces as a thrown error
    ///     and leaves the local cache unchanged (see TODO below).
    ///
    /// - Throws: `VaultError.vaultLocked` if the vault is locked (translated from `PrizmCryptoServiceError`).
    /// - Throws: `APIError` on network or HTTP failure.
    /// - Throws: `CipherMapperError` if the reverse mapper or response mapper fails.
    func update(_ draft: DraftVaultItem) async throws -> VaultItem {
        // TODO: Require biometric re-auth before encrypting and sending — deferred pending
        // SecureEnclave entitlement approval.

        let vaultKeys: CryptoKeys
        do {
            vaultKeys = try await crypto.currentKeys()
        } catch PrizmCryptoServiceError.vaultLocked {
            throw VaultError.vaultLocked
        }

        let orgKeysSnapshot = await orgKeyCache.snapshot()
        let encryptionKeys: CryptoKeys
        if let orgId = draft.organizationId, let orgKey = orgKeysSnapshot[orgId] {
            encryptionKeys = orgKey
        } else {
            encryptionKeys = vaultKeys
        }

        let rawCipher = try mapper.toRawCipher(draft, encryptedWith: encryptionKeys)

        // TODO: Queue encrypted rawCipher for offline persistence (deferred — requires WAL).
        let updatedRaw = try await apiClient.updateCipher(id: draft.id, cipher: rawCipher)

        if draft.organizationId != nil {
            try await apiClient.updateCipherCollections(id: draft.id, collectionIds: draft.collectionIds)
        }

        var (updatedItem, _) = try mapper.map(raw: updatedRaw, vaultKeys: vaultKeys, orgKeys: orgKeysSnapshot)

        // Patch collectionIds: PUT /api/ciphers/{id} returns pre-update collection state.
        if draft.organizationId != nil {
            updatedItem = VaultItem(
                id: updatedItem.id, name: updatedItem.name,
                isFavorite: updatedItem.isFavorite, isDeleted: updatedItem.isDeleted,
                creationDate: updatedItem.creationDate, revisionDate: updatedItem.revisionDate,
                content: updatedItem.content, reprompt: updatedItem.reprompt,
                attachments: updatedItem.attachments, folderId: updatedItem.folderId,
                organizationId: updatedItem.organizationId, collectionIds: draft.collectionIds
            )
        }

        if let idx = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[idx] = updatedItem
        } else {
            items.append(updatedItem)
        }
        buildIndexes()
        logger.info("Vault item updated: \(draft.id, privacy: .public)")
        return updatedItem
    }

    // MARK: - Create (write path)

    func create(_ draft: DraftVaultItem) async throws -> VaultItem {
        let vaultKeys: CryptoKeys
        do {
            vaultKeys = try await crypto.currentKeys()
        } catch PrizmCryptoServiceError.vaultLocked {
            throw VaultError.vaultLocked
        }

        let orgKeysSnapshot = await orgKeyCache.snapshot()
        let encryptionKeys: CryptoKeys
        if let orgId = draft.organizationId, let orgKey = orgKeysSnapshot[orgId] {
            encryptionKeys = orgKey
        } else {
            encryptionKeys = vaultKeys
        }

        let rawCipher = try mapper.toRawCipher(draft, encryptedWith: encryptionKeys)

        let createdRaw: RawCipher
        if draft.organizationId != nil {
            createdRaw = try await apiClient.createOrgCipher(cipher: rawCipher)
        } else {
            createdRaw = try await apiClient.createCipher(cipher: rawCipher)
        }

        // Discard cipherKey — newly created items are picked up by the next sync.
        let (createdItem, _) = try mapper.map(raw: createdRaw, vaultKeys: vaultKeys, orgKeys: orgKeysSnapshot)
        items.append(createdItem)
        buildIndexes()
        logger.info("Vault item created: \(createdItem.id, privacy: .public)")
        return createdItem
    }

    // MARK: - Delete / Restore / Empty Trash

    /// Soft-deletes the active item with `id` by calling `PUT /ciphers/{id}/delete`.
    ///
    /// - Security goal: no vault key material is needed — only the cipher ID is sent.
    ///   The access token (held by `PrizmAPIClientImpl`) authorises the operation.
    /// - Bitwarden endpoint: `PUT /api/ciphers/{id}/delete` — moves the cipher to Trash.
    func deleteItem(id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        try await apiClient.softDeleteCipher(id: id)
        let old = items[idx]
        items[idx] = VaultItem(
            id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: true,
            creationDate: old.creationDate, revisionDate: old.revisionDate,
            content: old.content, reprompt: old.reprompt, attachments: old.attachments,
            folderId: old.folderId, organizationId: old.organizationId, collectionIds: old.collectionIds
        )
        buildIndexes()
        logger.info("Vault item soft-deleted: \(id, privacy: .public)")
    }

    /// Permanently deletes the trashed item with `id` by calling `DELETE /ciphers/{id}`.
    ///
    /// - Security goal: same as `deleteItem` — only the cipher ID is sent; no key material.
    /// - Bitwarden endpoint: `DELETE /api/ciphers/{id}` — permanently removes the cipher.
    func permanentDeleteItem(id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        try await apiClient.permanentDeleteCipher(id: id)
        items.remove(at: idx)
        buildIndexes()
        logger.info("Vault item permanently deleted: \(id, privacy: .public)")
    }

    /// Restores the trashed item with `id` by calling `PUT /api/ciphers/{id}/restore`.
    ///
    /// - Security goal: same as `deleteItem` — only the cipher ID is sent; no key material.
    func restoreItem(id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        try await apiClient.restoreCipher(id: id)
        let old = items[idx]
        items[idx] = VaultItem(
            id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: false,
            creationDate: old.creationDate, revisionDate: old.revisionDate,
            content: old.content, reprompt: old.reprompt, attachments: old.attachments,
            folderId: old.folderId, organizationId: old.organizationId, collectionIds: old.collectionIds
        )
        buildIndexes()
        logger.info("Vault item restored: \(id, privacy: .public)")
    }

    // MARK: - Attachment cache patch

    /// Replaces the `attachments` array for the item identified by `cipherId` in the
    /// in-memory store without triggering a full re-sync.
    func updateAttachments(_ attachments: [Attachment], for cipherId: String) async {
        guard let idx = items.firstIndex(where: { $0.id == cipherId }) else {
            logger.error("updateAttachments: cipher not found in cache — id=\(cipherId, privacy: .public)")
            return
        }
        let old = items[idx]
        items[idx] = VaultItem(
            id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: old.isDeleted,
            creationDate: old.creationDate, revisionDate: old.revisionDate,
            content: old.content, reprompt: old.reprompt, attachments: attachments,
            folderId: old.folderId, organizationId: old.organizationId, collectionIds: old.collectionIds
        )
        buildIndexes()
        logger.info("Vault item attachments updated: cipher=\(cipherId, privacy: .public) count=\(attachments.count, privacy: .public)")
    }

    // MARK: - Folder CRUD

    func createFolder(name: String) async throws -> Folder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VaultError.decryptionFailed("empty folder name") }
        let encName = try await encryptFolderName(trimmed)
        let raw = try await apiClient.createFolder(encryptedName: encName)
        let folder = Folder(id: raw.id, name: trimmed)
        folderStore.append(folder)
        buildIndexes()
        logger.info("Folder created: \(raw.id, privacy: .public)")
        return folder
    }

    func renameFolder(id: String, name: String) async throws -> Folder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VaultError.decryptionFailed("empty folder name") }
        let encName = try await encryptFolderName(trimmed)
        _ = try await apiClient.updateFolder(id: id, encryptedName: encName)
        let folder = Folder(id: id, name: trimmed)
        if let idx = folderStore.firstIndex(where: { $0.id == id }) {
            folderStore[idx] = folder
        }
        buildIndexes()
        logger.info("Folder renamed: \(id, privacy: .public)")
        return folder
    }

    func deleteFolder(id: String) async throws {
        try await apiClient.deleteFolder(id: id)
        folderStore.removeAll { $0.id == id }
        // Unfolder items that were in this folder (server does this too).
        for i in items.indices where items[i].folderId == id {
            let old = items[i]
            items[i] = VaultItem(
                id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: old.isDeleted,
                creationDate: old.creationDate, revisionDate: old.revisionDate,
                content: old.content, reprompt: old.reprompt, attachments: old.attachments, folderId: nil
            )
        }
        buildIndexes()
        logger.info("Folder deleted: \(id, privacy: .public)")
    }

    // MARK: - Collection CRUD

    /// Creates a new collection within an organization.
    ///
    /// - Security goal: collection names are encrypted with the *org* symmetric key
    ///   (not the vault key) so that all members of the organization can decrypt them.
    ///   Reference: Bitwarden Security Whitepaper §4 — "Organization Key Wrapping".
    func createCollection(name: String, organizationId: String) async throws -> OrgCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VaultError.decryptionFailed("empty collection name") }
        let encName = try await encryptCollectionName(trimmed, organizationId: organizationId)
        let raw = try await apiClient.createCollection(organizationId: organizationId,
                                                        encryptedName: encName)
        let collection = OrgCollection(id: raw.id, organizationId: organizationId, name: trimmed)
        collectionStore.append(collection)
        buildIndexes()
        logger.info("Collection created: \(raw.id, privacy: .public)")
        return collection
    }

    /// Renames an existing collection. New name encrypted with the org key.
    func renameCollection(id: String, organizationId: String, name: String) async throws -> OrgCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VaultError.decryptionFailed("empty collection name") }
        let encName = try await encryptCollectionName(trimmed, organizationId: organizationId)
        _ = try await apiClient.renameCollection(id: id, organizationId: organizationId,
                                                  encryptedName: encName)
        let collection = OrgCollection(id: id, organizationId: organizationId, name: trimmed)
        if let idx = collectionStore.firstIndex(where: { $0.id == id }) {
            collectionStore[idx] = collection
        }
        buildIndexes()
        logger.info("Collection renamed: \(id, privacy: .public)")
        return collection
    }

    /// Deletes a collection from an organization and removes it from the local cache.
    ///
    /// Items that were in the collection are NOT deleted — they remain in the vault
    /// with stale `collectionIds` entries that no longer match a known collection.
    func deleteCollection(id: String, organizationId: String) async throws {
        try await apiClient.deleteCollection(id: id, organizationId: organizationId)
        collectionStore.removeAll { $0.id == id }
        buildIndexes()
        logger.info("Collection deleted: \(id, privacy: .public)")
    }

    // MARK: - Move to folder

    func moveItemToFolder(itemId: String, folderId: String?) async throws {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        let old = items[idx]
        try await apiClient.updateCipherPartial(id: itemId, folderId: folderId, favorite: old.isFavorite)
        items[idx] = VaultItem(
            id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: old.isDeleted,
            creationDate: old.creationDate, revisionDate: old.revisionDate,
            content: old.content, reprompt: old.reprompt, attachments: old.attachments, folderId: folderId
        )
        buildIndexes()
        logger.info("Item moved to folder: \(itemId, privacy: .public)")
    }

    func moveItemsToFolder(itemIds: [String], folderId: String?) async throws {
        try await apiClient.moveCiphersToFolder(ids: itemIds, folderId: folderId)
        for i in items.indices where itemIds.contains(items[i].id) {
            let old = items[i]
            items[i] = VaultItem(
                id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: old.isDeleted,
                creationDate: old.creationDate, revisionDate: old.revisionDate,
                content: old.content, reprompt: old.reprompt, attachments: old.attachments, folderId: folderId
            )
        }
        buildIndexes()
        logger.info("Bulk move to folder: \(itemIds.count, privacy: .public) item(s)")
    }

    // MARK: - Private helpers

    private func sorted(_ input: [VaultItem]) -> [VaultItem] {
        input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Encrypts a plaintext folder name as a type-2 EncString using the current vault keys.
    ///
    /// - Security: AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC) with a fresh random IV.
    ///   Same algorithm as cipher field encryption in `CipherMapper.encryptString`.
    private func encryptFolderName(_ name: String) async throws -> String {
        let keys: CryptoKeys
        do {
            keys = try await crypto.currentKeys()
        } catch PrizmCryptoServiceError.vaultLocked {
            throw VaultError.vaultLocked
        }
        guard let data = name.data(using: .utf8) else {
            throw VaultError.decryptionFailed("utf8-encode")
        }
        return try EncString.encrypt(data: data, keys: keys).toString()
    }

    /// Encrypts a plaintext collection name using the organization's symmetric key.
    ///
    /// - Security goal: collection names are org-key-encrypted so any org member
    ///   can read them. The vault key is NOT used — it is per-user, not per-org.
    ///   Algorithm: EncString type-2 (AES-256-CBC + HMAC-SHA256).
    private func encryptCollectionName(_ name: String, organizationId: String) async throws -> String {
        let orgSnapshot = await orgKeyCache.snapshot()
        guard let orgKey = orgSnapshot[organizationId] else {
            throw VaultError.decryptionFailed("org key not found for org: \(organizationId)")
        }
        guard let data = name.data(using: .utf8) else {
            throw VaultError.decryptionFailed("utf8-encode")
        }
        return try EncString.encrypt(data: data, keys: orgKey).toString()
    }
}

// MARK: - ItemContent search / type matching

private extension ItemContent {
    func matchesItemType(_ type: ItemType) -> Bool {
        switch (self, type) {
        case (.login,      .login):      return true
        case (.card,       .card):       return true
        case (.identity,   .identity):   return true
        case (.secureNote, .secureNote): return true
        case (.sshKey,     .sshKey):     return true
        default:                         return false
        }
    }
}

private extension VaultItem {
    /// Case-insensitive substring search across type-specific fields (FR-012).
    func matchesSearch(query: String) -> Bool {
        if name.localizedCaseInsensitiveContains(query) { return true }
        switch content {
        case .login(let l):
            return (l.username?.localizedCaseInsensitiveContains(query) == true) ||
                   l.uris.contains { $0.uri.localizedCaseInsensitiveContains(query) }
        case .card(let c):
            return c.cardholderName?.localizedCaseInsensitiveContains(query) == true
        case .identity(let i):
            return (i.email?.localizedCaseInsensitiveContains(query) == true) ||
                   (i.company?.localizedCaseInsensitiveContains(query) == true)
        case .secureNote, .sshKey:
            return false
        }
    }
}
