import Foundation
import os.log

// MARK: - VaultRepositoryImpl

/// In-memory vault store, populated by `SyncRepositoryImpl` after each sync.
///
/// All items are held in a flat `[VaultItem]` array; deleted items are excluded at query time.
/// The store is cleared on lock and sign-out via `clearVault()`.
///
/// Thread safety: this class is accessed from `@MainActor` contexts only.
/// If a background sync path is added in a future phase, the store should become an `actor`.
@MainActor
final class VaultRepositoryImpl: VaultRepository {

    private let logger = Logger(subsystem: "com.prizm", category: "VaultRepository")

    // MARK: - Dependencies (write path)

    private let apiClient: any PrizmAPIClientProtocol
    private let crypto:    any PrizmCryptoService
    private let mapper:    CipherMapper

    // MARK: - State

    private var items: [VaultItem] = []
    private var folderStore: [Folder] = []
    private(set) var lastSyncedAt: Date? = nil

    // MARK: - Init

    init(
        apiClient: any PrizmAPIClientProtocol,
        crypto:    any PrizmCryptoService,
        mapper:    CipherMapper = CipherMapper()
    ) {
        self.apiClient = apiClient
        self.crypto    = crypto
        self.mapper    = mapper
    }

    // MARK: - Write side (called by SyncRepositoryImpl)

    func populate(items: [VaultItem], folders: [Folder], syncedAt: Date) {
        self.items       = items
        self.folderStore = folders
        self.lastSyncedAt = syncedAt
        logger.info("Vault populated: \(items.count) item(s), \(folders.count) folder(s)")
    }

    func clearVault() {
        items        = []
        folderStore  = []
        lastSyncedAt = nil
        logger.info("Vault cleared")
    }

    // MARK: - Read side (called by use cases / ViewModels)

    func allItems() throws -> [VaultItem] {
        sorted(items.filter { !$0.isDeleted })
    }

    func folders() throws -> [Folder] {
        folderStore.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func items(for selection: SidebarSelection) throws -> [VaultItem] {
        switch selection {
        case .trash:
            return sorted(items.filter(\.isDeleted))
        case .allItems:
            return sorted(items.filter { !$0.isDeleted })
        case .favorites:
            return sorted(items.filter { !$0.isDeleted && $0.isFavorite })
        case .type(let itemType):
            return sorted(items.filter { !$0.isDeleted && $0.content.matchesItemType(itemType) })
        case .folder(let folderId):
            return sorted(items.filter { !$0.isDeleted && $0.folderId == folderId })
        case .newFolder:
            return []
        }
    }

    func searchItems(query: String, in selection: SidebarSelection) throws -> [VaultItem] {
        let base = try items(for: selection)
        guard !query.isEmpty else { return base }
        return base.filter { item in
            item.matchesSearch(query: query)
        }
    }

    func itemCounts() throws -> [SidebarSelection: Int] {
        let base = items.filter { !$0.isDeleted }
        var counts: [SidebarSelection: Int] = [:]
        counts[.allItems]          = base.count
        counts[.favorites]         = base.filter(\.isFavorite).count
        counts[.trash]             = items.filter(\.isDeleted).count
        for type in ItemType.allCases {
            counts[.type(type)]    = base.filter { $0.content.matchesItemType(type) }.count
        }
        for folder in folderStore {
            counts[.folder(folder.id)] = base.filter { $0.folderId == folder.id }.count
        }
        return counts
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
        // TODO: Require biometric re-auth (Touch ID / Face ID) before encrypting and
        // sending the updated cipher — deferred pending SecureEnclave entitlement approval.
        // Until this is added, any process that obtains the unlocked vault keys can write
        // changes without a second user confirmation.

        // Step 1: Obtain current symmetric keys — throws if vault is locked.
        // Translate PrizmCryptoServiceError.vaultLocked → VaultError.vaultLocked so
        // callers receive the Domain-layer error type promised by the VaultRepository protocol.
        // Other crypto errors (kdfFailed, invalidEncUserKey, etc.) propagate unchanged.
        let keys: CryptoKeys
        do {
            keys = try await crypto.currentKeys()
        } catch PrizmCryptoServiceError.vaultLocked {
            throw VaultError.vaultLocked
        }

        // Step 2: Re-encrypt all sensitive fields via the reverse cipher mapper.
        let rawCipher = try mapper.toRawCipher(draft, encryptedWith: keys)

        // Step 3: Send to the Bitwarden API (PUT /api/ciphers/{id}).
        // TODO: Queue the encrypted `rawCipher` for offline persistence so edits made
        // without connectivity are synced when the network becomes available.
        // Deferred to a later phase — requires a durable encrypted write-ahead log.
        let updatedRaw = try await apiClient.updateCipher(id: draft.id, cipher: rawCipher)

        // Step 4: Decode the server response into a domain item.
        // The cipherKey return value is discarded here — VaultKeyCache is populated at sync
        // time; a single-item edit does not need to update the key cache.
        let (updatedItem, _) = try mapper.map(raw: updatedRaw, keys: keys)

        // Step 5: Splice into the in-memory cache (no full re-sync needed).
        if let idx = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[idx] = updatedItem
        } else {
            // Item wasn't in cache (shouldn't happen in normal flow) — append it.
            items.append(updatedItem)
        }
        logger.info("Vault item updated: \(draft.id, privacy: .public)")

        return updatedItem
    }

    // MARK: - Create (write path)

    func create(_ draft: DraftVaultItem) async throws -> VaultItem {
        let keys: CryptoKeys
        do {
            keys = try await crypto.currentKeys()
        } catch PrizmCryptoServiceError.vaultLocked {
            throw VaultError.vaultLocked
        }

        let rawCipher = try mapper.toRawCipher(draft, encryptedWith: keys)
        let createdRaw = try await apiClient.createCipher(cipher: rawCipher)
        // Discard cipherKey — newly created items are picked up by the next sync which
        // populates VaultKeyCache. A just-created cipher may have no per-item key yet.
        let (createdItem, _) = try mapper.map(raw: createdRaw, keys: keys)
        items.append(createdItem)
        // Note: sidebar counts are refreshed by the caller (VaultBrowserViewModel.handleItemSaved)
        // via the onSaveSuccess callback — same pattern as update().
        logger.info("Vault item created: \(createdItem.id, privacy: .public)")
        return createdItem
    }

    // MARK: - Delete / Restore / Empty Trash

    /// Soft-deletes the active item with `id` by calling `PUT /ciphers/{id}/delete`.
    ///
    /// - Security goal: no vault key material is needed — only the cipher ID is sent.
    ///   The access token (held by `PrizmAPIClientImpl`) authorises the operation.
    /// - Bitwarden endpoint: `PUT /api/ciphers/{id}/delete` — moves the cipher to Trash.
    /// - On success the local cache entry is updated (`isDeleted = true`) immediately so
    ///   the UI reflects the change without waiting for a full re-sync.
    func deleteItem(id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        try await apiClient.softDeleteCipher(id: id)
        let old = items[idx]
        items[idx] = VaultItem(
            id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: true,
            creationDate: old.creationDate, revisionDate: old.revisionDate,
            content: old.content, reprompt: old.reprompt, attachments: old.attachments, folderId: old.folderId
        )
        logger.info("Vault item soft-deleted: \(id, privacy: .public)")
    }

    /// Permanently deletes the trashed item with `id` by calling `DELETE /ciphers/{id}`.
    ///
    /// - Security goal: same as `deleteItem` — only the cipher ID is sent; no key material.
    /// - Bitwarden endpoint: `DELETE /api/ciphers/{id}` — permanently removes the cipher.
    ///   This is distinct from the soft-delete endpoint (`PUT .../delete`).
    /// - On success the item is removed from the local cache entirely.
    func permanentDeleteItem(id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        try await apiClient.permanentDeleteCipher(id: id)
        items.remove(at: idx)
        logger.info("Vault item permanently deleted: \(id, privacy: .public)")
    }

    /// Restores the trashed item with `id` by calling `PUT /api/ciphers/{id}/restore`.
    ///
    /// - Security goal: same as `deleteItem` — only the cipher ID is sent; no key material.
    /// - Guards on the local cache index first so that an API call is never made for an item
    ///   that is not in the local store (fail-fast; avoids a successful server call with no
    ///   corresponding cache update).
    /// - On success the item is marked active in the local cache.
    func restoreItem(id: String) async throws {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        try await apiClient.restoreCipher(id: id)
        let old = items[idx]
        items[idx] = VaultItem(
            id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: false,
            creationDate: old.creationDate, revisionDate: old.revisionDate,
            content: old.content, reprompt: old.reprompt, attachments: old.attachments, folderId: old.folderId
        )
        logger.info("Vault item restored: \(id, privacy: .public)")
    }

    // MARK: - Attachment cache patch

    /// Replaces the `attachments` array for the item identified by `cipherId` in the
    /// in-memory store without triggering a full re-sync.
    ///
    /// `VaultItem` is a value type (struct), so updating the `attachments` field requires
    /// constructing a new `VaultItem` with all original fields preserved and the updated
    /// array, then splicing the new value back into the items array at the same index.
    ///
    /// This method is called by `AttachmentRepositoryImpl` from a background task context;
    /// `@MainActor` is inherited from the class declaration, so the caller's `await` hop
    /// ensures the store mutation happens on the main actor.
    func updateAttachments(_ attachments: [Attachment], for cipherId: String) async {
        guard let idx = items.firstIndex(where: { $0.id == cipherId }) else {
            logger.error("updateAttachments: cipher not found in cache — id=\(cipherId, privacy: .public)")
            return
        }
        let old = items[idx]
        items[idx] = VaultItem(
            id: old.id, name: old.name, isFavorite: old.isFavorite, isDeleted: old.isDeleted,
            creationDate: old.creationDate, revisionDate: old.revisionDate,
            content: old.content, reprompt: old.reprompt, attachments: attachments, folderId: old.folderId
        )
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
        logger.info("Folder deleted: \(id, privacy: .public)")
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
        logger.info("Bulk move to folder: \(itemIds.count, privacy: .public) item(s)")
    }

    // MARK: - Private helpers

    private func sorted(_ input: [VaultItem]) -> [VaultItem] {
        input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Encrypts a plaintext folder name as a type-2 EncString using the current vault keys.
    /// Called before folder create/rename API calls.
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
