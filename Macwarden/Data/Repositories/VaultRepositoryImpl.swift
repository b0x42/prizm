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

    private let logger = Logger(subsystem: "com.macwarden", category: "VaultRepository")

    // MARK: - Dependencies (write path)

    private let apiClient: any MacwardenAPIClientProtocol
    private let crypto:    any MacwardenCryptoService
    private let mapper:    CipherMapper

    // MARK: - State

    private var items: [VaultItem] = []
    private(set) var lastSyncedAt: Date? = nil

    // MARK: - Init

    init(
        apiClient: any MacwardenAPIClientProtocol,
        crypto:    any MacwardenCryptoService,
        mapper:    CipherMapper = CipherMapper()
    ) {
        self.apiClient = apiClient
        self.crypto    = crypto
        self.mapper    = mapper
    }

    // MARK: - Write side (called by SyncRepositoryImpl)

    func populate(items: [VaultItem], syncedAt: Date) {
        self.items     = items
        self.lastSyncedAt = syncedAt
        logger.info("Vault populated: \(items.count) item(s)")
    }

    func clearVault() {
        items       = []
        lastSyncedAt = nil
        logger.info("Vault cleared")
    }

    // MARK: - Read side (called by use cases / ViewModels)

    func allItems() throws -> [VaultItem] {
        sorted(items.filter { !$0.isDeleted })
    }

    func items(for selection: SidebarSelection) throws -> [VaultItem] {
        let base = items.filter { !$0.isDeleted }
        switch selection {
        case .allItems:
            return sorted(base)
        case .favorites:
            return sorted(base.filter(\.isFavorite))
        case .type(let itemType):
            return sorted(base.filter { $0.content.matchesItemType(itemType) })
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
        for type in ItemType.allCases {
            counts[.type(type)]    = base.filter { $0.content.matchesItemType(type) }.count
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
    ///   1. Obtain current symmetric keys from `MacwardenCryptoService` — throws immediately
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
    /// - Throws: `VaultError.vaultLocked` if the vault is locked (translated from `MacwardenCryptoServiceError`).
    /// - Throws: `APIError` on network or HTTP failure.
    /// - Throws: `CipherMapperError` if the reverse mapper or response mapper fails.
    func update(_ draft: DraftVaultItem) async throws -> VaultItem {
        // TODO: Require biometric re-auth (Touch ID / Face ID) before encrypting and
        // sending the updated cipher — deferred pending SecureEnclave entitlement approval.
        // Until this is added, any process that obtains the unlocked vault keys can write
        // changes without a second user confirmation.

        // Step 1: Obtain current symmetric keys — throws if vault is locked.
        // Translate MacwardenCryptoServiceError.vaultLocked → VaultError.vaultLocked so
        // callers receive the Domain-layer error type promised by the VaultRepository protocol.
        // Other crypto errors (kdfFailed, invalidEncUserKey, etc.) propagate unchanged.
        let keys: CryptoKeys
        do {
            keys = try await crypto.currentKeys()
        } catch MacwardenCryptoServiceError.vaultLocked {
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
        let updatedItem = try mapper.map(raw: updatedRaw, keys: keys)

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

    // MARK: - Private helpers

    private func sorted(_ input: [VaultItem]) -> [VaultItem] {
        input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
