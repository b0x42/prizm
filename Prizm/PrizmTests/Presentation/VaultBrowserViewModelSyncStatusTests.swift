import XCTest
@testable import Prizm

@MainActor
final class VaultBrowserViewModelSyncStatusTests: XCTestCase {

    private var vault:    MockVaultRepository!
    private var syncRepo: MockSyncTimestampRepository!
    private var sut:      VaultBrowserViewModel!

    override func setUp() async throws {
        try await super.setUp()
        vault    = MockVaultRepository()
        syncRepo = MockSyncTimestampRepository(storedDate: nil)
        sut = makeViewModel()
    }

    private func makeViewModel(storedDate: Date? = nil) -> VaultBrowserViewModel {
        let repo    = MockSyncTimestampRepository(storedDate: storedDate)
        syncRepo    = repo
        let useCase = GetLastSyncDateUseCaseImpl(repository: repo)
        return VaultBrowserViewModel(
            vault:           vault,
            search:          SearchVaultUseCaseImpl(vault: vault),
            delete:          StubVaultDeleteUseCase(),
            permanentDelete: StubVaultPermanentDeleteUseCase(),
            restore:         StubVaultRestoreUseCase(),
            createFolder:     StubCreateFolder(),
            renameFolder:     StubRenameFolder(),
            deleteFolder:     StubDeleteFolder(),
            moveItem:         StubMoveItem(),
            createCollection: StubCreateCollection(),
            renameCollection: StubRenameCollection(),
            deleteCollection: StubDeleteCollection(),
            syncTimestamp:    repo,
            getLastSyncDate:  useCase
        )
    }

    // MARK: - 1. lastSyncedAt is nil when repository has no stored date

    func testInit_lastSyncedAt_isNil_whenNoStoredDate() async {
        XCTAssertNil(sut.lastSyncedAt)
    }

    // MARK: - 2. lastSyncedAt is loaded from use case on init

    func testInit_lastSyncedAt_loadedFromUseCase() async {
        let stored = Date(timeIntervalSince1970: 1_000_000)
        let vm = makeViewModel(storedDate: stored)
        XCTAssertEqual(vm.lastSyncedAt, stored)
    }

    // MARK: - 3. syncStatusLabel is "Never synced" when no date

    func testInit_syncStatusLabel_isNeverSynced_whenNoDate() async {
        XCTAssertEqual(sut.syncStatusLabel, "Never synced")
    }

    // MARK: - 4. handleSyncCompleted updates lastSyncedAt and calls recordSuccessfulSync

    func testHandleSyncCompleted_updatesLastSyncedAt_andRecordsTimestamp() async {
        let date = Date()
        sut.handleSyncCompleted(syncedAt: date)

        XCTAssertEqual(sut.lastSyncedAt, date)
        XCTAssertTrue(syncRepo.recordCalled, "recordSuccessfulSync() should be called on sync success")
    }

    // MARK: - 5. syncStatusLabel updates after handleSyncCompleted

    func testHandleSyncCompleted_updatesSyncStatusLabel() async {
        let date = Date()
        sut.handleSyncCompleted(syncedAt: date)

        XCTAssertNotEqual(sut.syncStatusLabel, "Never synced")
        XCTAssertTrue(sut.syncStatusLabel.hasPrefix("Synced"))
    }

    // MARK: - 6. handleSyncError does NOT call recordSuccessfulSync

    func testHandleSyncError_doesNotRecordTimestamp() async {
        sut.handleSyncError("Network unavailable")

        XCTAssertFalse(syncRepo.recordCalled, "recordSuccessfulSync() must not be called on sync failure")
    }
}

// MARK: - Stubs

private final class StubVaultDeleteUseCase: DeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}
private final class StubVaultPermanentDeleteUseCase: PermanentDeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}
private final class StubVaultRestoreUseCase: RestoreVaultItemUseCase {
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
