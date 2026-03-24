import Foundation
@testable import Macwarden

/// Test double for `VaultRepository`.
///
/// Tracks items stored by `SyncRepositoryImpl` via `populate(items:syncedAt:)` and
/// edit operations via `update(_:)`.
@MainActor
final class MockVaultRepository: VaultRepository {

    // MARK: - State

    private(set) var populatedItems: [VaultItem] = []
    private(set) var lastSyncedAt:   Date?        = nil
    private(set) var clearVaultCalled: Bool       = false

    // MARK: - update(_:) stubbing

    var stubbedUpdateResult: VaultItem?
    var stubbedUpdateError: Error?
    private(set) var updateCallCount: Int = 0
    private(set) var lastUpdatedDraft: DraftVaultItem?

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
        case .trash:
            return populatedItems.filter(\.isDeleted)
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

    func update(_ draft: DraftVaultItem) async throws -> VaultItem {
        updateCallCount += 1
        lastUpdatedDraft = draft
        if let error = stubbedUpdateError { throw error }
        guard let result = stubbedUpdateResult else {
            throw VaultError.itemNotFound(draft.id)
        }
        return result
    }

    // MARK: - deleteItem stubbing

    var stubbedDeleteError: Error?
    private(set) var deleteCallCount: Int = 0
    private(set) var lastDeletedId: String?

    func deleteItem(id: String) async throws {
        deleteCallCount += 1
        lastDeletedId = id
        if let error = stubbedDeleteError { throw error }
        populatedItems.removeAll { $0.id == id }
    }

    // MARK: - permanentDeleteItem stubbing

    var stubbedPermanentDeleteError: Error?
    private(set) var permanentDeleteCallCount: Int = 0
    private(set) var lastPermanentDeletedId: String?

    func permanentDeleteItem(id: String) async throws {
        permanentDeleteCallCount += 1
        lastPermanentDeletedId = id
        if let error = stubbedPermanentDeleteError { throw error }
        populatedItems.removeAll { $0.id == id }
    }

    // MARK: - restoreItem stubbing

    var stubbedRestoreError: Error?
    private(set) var restoreCallCount: Int = 0
    private(set) var lastRestoredId: String?

    func restoreItem(id: String) async throws {
        restoreCallCount += 1
        lastRestoredId = id
        if let error = stubbedRestoreError { throw error }
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
