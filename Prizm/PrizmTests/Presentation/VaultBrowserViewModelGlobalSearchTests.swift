import XCTest
@testable import Prizm

@MainActor
final class VaultBrowserViewModelGlobalSearchTests: XCTestCase {

    private var vault: MockVaultRepository!
    private var sut: VaultBrowserViewModel!

    private let sampleLogin = VaultItem(
        id: "1", name: "GitHub", isFavorite: false, isDeleted: false,
        creationDate: .now, revisionDate: .now,
        content: .login(LoginContent(username: "alice", password: nil, uris: [], totp: nil, notes: nil, customFields: []))
    )
    private let sampleCard = VaultItem(
        id: "2", name: "Visa", isFavorite: false, isDeleted: false,
        creationDate: .now, revisionDate: .now,
        content: .card(CardContent(cardholderName: "Alice", brand: nil, number: "4111111111111111", expMonth: nil, expYear: nil, code: nil, notes: nil, customFields: []))
    )

    override func setUp() async throws {
        try await super.setUp()
        vault = MockVaultRepository()
        vault.populate(items: [sampleLogin, sampleCard], folders: [], organizations: [], collections: [], syncedAt: .now)
        let syncRepo = MockSyncTimestampRepository(storedDate: nil)
        sut = VaultBrowserViewModel(
            vault:           vault,
            search:          SearchVaultUseCaseImpl(vault: vault),
            delete:          StubDeleteUseCase(),
            permanentDelete: StubPermanentDeleteUseCase(),
            restore:         StubRestoreUseCase(),
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

    // MARK: - 1.1 activateGlobalSearch stores previous selection and sets flag

    func testActivateGlobalSearch_storesPreviousSelectionAndSetsFlag() {
        sut.sidebarSelection = .type(.login)
        sut.activateGlobalSearch()

        XCTAssertTrue(sut.isGlobalSearch)
        XCTAssertEqual(sut.previousSelection, .type(.login))
    }

    // MARK: - 1.2 deactivateGlobalSearch restores selection, clears query, resets flag

    func testDeactivateGlobalSearch_restoresSelectionAndClearsState() {
        sut.sidebarSelection = .favorites
        sut.activateGlobalSearch()
        sut.searchQuery = "test"

        sut.deactivateGlobalSearch()

        XCTAssertFalse(sut.isGlobalSearch)
        XCTAssertEqual(sut.searchQuery, "")
        XCTAssertEqual(sut.sidebarSelection, .favorites)
    }

    // MARK: - 1.3 search passes .allItems when isGlobalSearch is true

    func testGlobalSearch_searchesAllItems() {
        sut.sidebarSelection = .type(.login)
        sut.activateGlobalSearch()
        sut.searchQuery = "Visa"

        // Visa is a Card, not a Login — should still appear in global search
        XCTAssertTrue(sut.displayedItems.contains(where: { $0.name == "Visa" }))
    }

    // MARK: - 1.4 sidebar selection change deactivates global search

    func testSidebarSelectionChange_deactivatesGlobalSearch() {
        sut.activateGlobalSearch()
        XCTAssertTrue(sut.isGlobalSearch)

        sut.sidebarSelection = .type(.card)

        XCTAssertFalse(sut.isGlobalSearch)
    }

    // MARK: - 1.5 escape/clear deactivates global search and restores selection

    func testDeactivateGlobalSearch_afterEscape_restoresSelection() {
        sut.sidebarSelection = .type(.identity)
        sut.activateGlobalSearch()
        sut.searchQuery = "something"

        // Simulate escape/clear
        sut.deactivateGlobalSearch()

        XCTAssertFalse(sut.isGlobalSearch)
        XCTAssertEqual(sut.sidebarSelection, .type(.identity))
        XCTAssertEqual(sut.searchQuery, "")
    }
}

// MARK: - Stub use cases (minimal, no-op)

private final class StubDeleteUseCase: DeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}

private final class StubPermanentDeleteUseCase: PermanentDeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}

private final class StubRestoreUseCase: RestoreVaultItemUseCase {
    func execute(id: String) async throws {}
}

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
