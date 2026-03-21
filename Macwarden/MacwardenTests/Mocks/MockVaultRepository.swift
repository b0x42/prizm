import Foundation
@testable import Macwarden

/// Test double for `VaultRepository`.
///
/// Tracks items stored by `SyncRepositoryImpl` via `populate(items:syncedAt:)`.
final class MockVaultRepository: VaultRepository {

    // MARK: - State

    private(set) var populatedItems: [VaultItem] = []
    private(set) var lastSyncedAt:   Date?        = nil
    private(set) var clearVaultCalled: Bool       = false

    // MARK: - VaultRepository (write side)

    func populate(items: [VaultItem], syncedAt: Date) {
        populatedItems = items
        lastSyncedAt   = syncedAt
    }

    func clearVault() {
        populatedItems  = []
        lastSyncedAt    = nil
        clearVaultCalled = true
    }

    // MARK: - VaultRepository (read side — not exercised in sync tests)

    func allItems() throws -> [VaultItem] { populatedItems }

    func items(for selection: SidebarSelection) throws -> [VaultItem] {
        switch selection {
        case .allItems:
            return populatedItems
        case .favorites:
            return populatedItems.filter(\.isFavorite)
        case .type(let itemType):
            return populatedItems.filter { $0.content.matchesType(itemType) }
        }
    }

    func searchItems(query: String, in selection: SidebarSelection) throws -> [VaultItem] {
        let base = try items(for: selection)
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func itemCounts() throws -> [SidebarSelection: Int] { [:] }

    func itemDetail(id: String) async throws -> VaultItem {
        guard let item = populatedItems.first(where: { $0.id == id }) else {
            throw VaultError.itemNotFound(id)
        }
        return item
    }
}

// MARK: - ItemContent helper

private extension ItemContent {
    func matchesType(_ type: ItemType) -> Bool {
        switch (self, type) {
        case (.login,       .login):      return true
        case (.card,        .card):       return true
        case (.identity,    .identity):   return true
        case (.secureNote,  .secureNote): return true
        case (.sshKey,      .sshKey):     return true
        default:                          return false
        }
    }
}
