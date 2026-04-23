import XCTest
@testable import Prizm

@MainActor
final class ToggleFavoriteTests: XCTestCase {

    private var vault: MockVaultRepository!
    private var sut: VaultBrowserViewModel!

    private let unfavoritedItem = VaultItem(
        id: "1", name: "GitHub", isFavorite: false, isDeleted: false,
        creationDate: .now, revisionDate: .now,
        content: .login(LoginContent(username: "alice", password: nil, uris: [], totp: nil, notes: nil, customFields: []))
    )

    override func setUp() async throws {
        try await super.setUp()
        vault = MockVaultRepository()
        await vault.populate(items: [unfavoritedItem], folders: [], organizations: [], collections: [], syncedAt: .now)
        let syncRepo = MockSyncTimestampRepository(storedDate: nil)
        sut = VaultBrowserViewModel(
            vault:           vault,
            search:          SearchVaultUseCaseImpl(vault: vault),
            delete:          StubDelete(),
            permanentDelete: StubPermanentDelete(),
            restore:         StubRestore(),
            createFolder:     StubCreateFolder(),
            renameFolder:     StubRenameFolder(),
            deleteFolder:     StubDeleteFolder(),
            moveItem:         StubMoveItem(),
            createCollection: StubCreateCollection(),
            renameCollection: StubRenameCollection(),
            deleteCollection: StubDeleteCollection(),
            syncTimestamp:    syncRepo,
            getLastSyncDate:  GetLastSyncDateUseCaseImpl(repository: syncRepo)
        )
    }

    func testToggleFavorite_callsUpdateWithFlippedFlag() async throws {
        let favorited = VaultItem(
            id: "1", name: "GitHub", isFavorite: true, isDeleted: false,
            creationDate: unfavoritedItem.creationDate, revisionDate: unfavoritedItem.revisionDate,
            content: unfavoritedItem.content
        )
        vault.stubbedUpdateResult = favorited

        sut.toggleFavorite(item: unfavoritedItem)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(vault.updateCallCount, 1)
        XCTAssertTrue(vault.lastUpdatedDraft!.isFavorite, "Draft should have isFavorite = true")
    }

    func testToggleFavorite_unfavorites() async throws {
        let favoritedItem = VaultItem(
            id: "1", name: "GitHub", isFavorite: true, isDeleted: false,
            creationDate: .now, revisionDate: .now,
            content: unfavoritedItem.content
        )
        await vault.populate(items: [favoritedItem], folders: [], organizations: [], collections: [], syncedAt: .now)
        vault.stubbedUpdateResult = unfavoritedItem

        sut.toggleFavorite(item: favoritedItem)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(vault.updateCallCount, 1)
        XCTAssertFalse(vault.lastUpdatedDraft!.isFavorite, "Draft should have isFavorite = false")
    }
}

private final class StubDelete: DeleteVaultItemUseCase { func execute(id: String) async throws {} }
private final class StubPermanentDelete: PermanentDeleteVaultItemUseCase { func execute(id: String) async throws {} }
private final class StubRestore: RestoreVaultItemUseCase { func execute(id: String) async throws {} }
private struct StubCreateFolder: CreateFolderUseCase {
    func execute(name: String) async throws -> Folder { Folder(id: "stub", name: name) }
}
private struct StubRenameFolder: RenameFolderUseCase {
    func execute(id: String, name: String) async throws -> Folder { Folder(id: id, name: name) }
}
private struct StubDeleteFolder: DeleteFolderUseCase {
    func execute(id: String) async throws {}
}
private struct StubMoveItem: MoveItemToFolderUseCase {
    func execute(itemId: String, folderId: String?) async throws {}
    func execute(itemIds: [String], folderId: String?) async throws {}
}
private struct StubCreateCollection: CreateCollectionUseCase {
    func execute(name: String, organizationId: String) async throws -> OrgCollection {
        OrgCollection(id: "stub", organizationId: organizationId, name: name)
    }
}
private struct StubRenameCollection: RenameCollectionUseCase {
    func execute(collectionId: String, name: String, organizationId: String) async throws -> OrgCollection {
        OrgCollection(id: collectionId, organizationId: organizationId, name: name)
    }
}
private struct StubDeleteCollection: DeleteCollectionUseCase {
    func execute(collectionId: String, organizationId: String) async throws {}
}
