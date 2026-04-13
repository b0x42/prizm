import Foundation
@testable import Prizm

/// Test double for `VaultRepository`.
///
/// Tracks items stored by `SyncRepositoryImpl` via `populate(items:syncedAt:)` and
/// edit operations via `update(_:)`.
@MainActor
final class MockVaultRepository: VaultRepository {

    // MARK: - State

    private(set) var populatedItems: [VaultItem] = []
    private(set) var populatedFolders: [Folder] = []
    private(set) var populatedOrganizations: [Organization] = []
    private(set) var populatedCollections: [OrgCollection] = []
    private(set) var lastSyncedAt:   Date?        = nil
    private(set) var clearVaultCalled: Bool       = false

    // MARK: - update(_:) stubbing

    var stubbedUpdateResult: VaultItem?
    var stubbedUpdateError: Error?
    private(set) var updateCallCount: Int = 0
    private(set) var lastUpdatedDraft: DraftVaultItem?

    // MARK: - VaultRepository (write side)

    func populate(items: [VaultItem], folders: [Folder], organizations: [Organization],
                  collections: [OrgCollection], syncedAt: Date) {
        populatedItems         = items
        populatedFolders       = folders
        populatedOrganizations = organizations
        populatedCollections   = collections
        lastSyncedAt           = syncedAt
    }

    func clearVault() {
        populatedItems         = []
        populatedFolders       = []
        populatedOrganizations = []
        populatedCollections   = []
        lastSyncedAt           = nil
        clearVaultCalled       = true
    }

    // MARK: - VaultRepository (read side)

    func allItems() throws -> [VaultItem] { populatedItems }

    func folders() throws -> [Folder] { populatedFolders }

    func organizations() throws -> [Organization] { populatedOrganizations }

    func collections() throws -> [OrgCollection] { populatedCollections }

    func items(for collection: String) throws -> [VaultItem] {
        populatedItems.filter { $0.collectionIds.contains(collection) }
    }

    func items(for selection: SidebarSelection) throws -> [VaultItem] {
        switch selection {
        case .allItems:
            return populatedItems
        case .favorites:
            return populatedItems.filter(\.isFavorite)
        case .type(let itemType):
            return populatedItems.filter { $0.content.matchesType(itemType) }
        case .folder(let folderId):
            return populatedItems.filter { $0.folderId == folderId }
        case .trash:
            return populatedItems.filter(\.isDeleted)
        case .newFolder:
            return []
        case .organization(let orgId):
            let orgColIds = Set(populatedCollections.filter { $0.organizationId == orgId }.map(\.id))
            return populatedItems.filter { !$0.collectionIds.filter { orgColIds.contains($0) }.isEmpty }
        case .collection(let colId):
            return populatedItems.filter { $0.collectionIds.contains(colId) }
        case .newCollection:
            return []
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

    // MARK: - create(_:) stubbing

    var stubbedCreateResult: VaultItem?
    var stubbedCreateError: Error?
    private(set) var createCallCount: Int = 0
    private(set) var lastCreatedDraft: DraftVaultItem?

    func create(_ draft: DraftVaultItem) async throws -> VaultItem {
        createCallCount += 1
        lastCreatedDraft = draft
        if let error = stubbedCreateError { throw error }
        guard let result = stubbedCreateResult else {
            return VaultItem(draft)
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

    // MARK: - updateAttachments stubbing

    private(set) var updateAttachmentsCallCount: Int = 0
    private(set) var lastUpdatedAttachments: [Attachment]?
    private(set) var lastUpdateAttachmentsCipherId: String?

    func updateAttachments(_ attachments: [Attachment], for cipherId: String) async {
        updateAttachmentsCallCount += 1
        lastUpdatedAttachments = attachments
        lastUpdateAttachmentsCipherId = cipherId
        // Patch in-memory state so allItems() reflects the update
        if let idx = populatedItems.firstIndex(where: { $0.id == cipherId }) {
            let old = populatedItems[idx]
            populatedItems[idx] = VaultItem(
                id:             old.id,
                name:           old.name,
                isFavorite:     old.isFavorite,
                isDeleted:      old.isDeleted,
                creationDate:   old.creationDate,
                revisionDate:   old.revisionDate,
                content:        old.content,
                reprompt:       old.reprompt,
                attachments:    attachments,
                folderId:       old.folderId,
                organizationId: old.organizationId,
                collectionIds:  old.collectionIds
            )
        }
    }

    // MARK: - Folder CRUD stubbing

    var stubbedCreateFolderResult: Folder?
    var stubbedCreateFolderError: Error?

    func createFolder(name: String) async throws -> Folder {
        if let error = stubbedCreateFolderError { throw error }
        let folder = stubbedCreateFolderResult ?? Folder(id: UUID().uuidString, name: name)
        populatedFolders.append(folder)
        return folder
    }

    func renameFolder(id: String, name: String) async throws -> Folder {
        let folder = Folder(id: id, name: name)
        if let idx = populatedFolders.firstIndex(where: { $0.id == id }) {
            populatedFolders[idx] = folder
        }
        return folder
    }

    var stubbedDeleteFolderError: Error?

    func deleteFolder(id: String) async throws {
        if let error = stubbedDeleteFolderError { throw error }
        populatedFolders.removeAll { $0.id == id }
    }

    func moveItemToFolder(itemId: String, folderId: String?) async throws {}
    func moveItemsToFolder(itemIds: [String], folderId: String?) async throws {}

    // MARK: - Collection CRUD stubbing

    var stubbedCreateCollectionResult: OrgCollection?
    var stubbedCreateCollectionError: Error?
    private(set) var createCollectionCallCount: Int = 0
    private(set) var lastCreateCollectionName: String?
    private(set) var lastCreateCollectionOrgId: String?

    func createCollection(name: String, organizationId: String) async throws -> OrgCollection {
        createCollectionCallCount += 1
        lastCreateCollectionName  = name
        lastCreateCollectionOrgId = organizationId
        if let err = stubbedCreateCollectionError { throw err }
        if let result = stubbedCreateCollectionResult { return result }
        let col = OrgCollection(id: UUID().uuidString, organizationId: organizationId, name: name)
        populatedCollections.append(col)
        return col
    }

    var stubbedRenameCollectionResult: OrgCollection?
    var stubbedRenameCollectionError: Error?
    private(set) var renameCollectionCallCount: Int = 0

    func renameCollection(id: String, organizationId: String, name: String) async throws -> OrgCollection {
        renameCollectionCallCount += 1
        if let err = stubbedRenameCollectionError { throw err }
        let col = stubbedRenameCollectionResult
            ?? OrgCollection(id: id, organizationId: organizationId, name: name)
        if let idx = populatedCollections.firstIndex(where: { $0.id == id }) {
            populatedCollections[idx] = col
        }
        return col
    }

    var stubbedDeleteCollectionError: Error?
    private(set) var deleteCollectionCallCount: Int = 0
    private(set) var lastDeleteCollectionId: String?
    private(set) var lastDeleteCollectionOrgId: String?

    func deleteCollection(id: String, organizationId: String) async throws {
        deleteCollectionCallCount += 1
        lastDeleteCollectionId    = id
        lastDeleteCollectionOrgId = organizationId
        if let err = stubbedDeleteCollectionError { throw err }
        populatedCollections.removeAll { $0.id == id }
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
