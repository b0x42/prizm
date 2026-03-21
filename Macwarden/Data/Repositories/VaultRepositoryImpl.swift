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

    // MARK: - State

    private var items: [VaultItem] = []
    private(set) var lastSyncedAt: Date? = nil

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
