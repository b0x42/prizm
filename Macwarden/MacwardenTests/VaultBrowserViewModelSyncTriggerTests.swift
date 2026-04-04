import XCTest
@testable import Macwarden

// MARK: - VaultBrowserViewModelSyncTriggerTests

/// Asserts that `SyncService.trigger()` fires after each successful mutation
/// and does NOT fire on failure.
@MainActor
final class VaultBrowserViewModelSyncTriggerTests: XCTestCase {

    private var vault:    MockVaultRepository!
    private var mockSync: MockSyncService!
    private var sut:      VaultBrowserViewModel!

    private let item = VaultItem(
        id: "item-1", name: "GitHub", isFavorite: false, isDeleted: false,
        creationDate: .now, revisionDate: .now,
        content: .login(LoginContent(username: "alice", password: nil, uris: [], totp: nil, notes: nil, customFields: []))
    )

    private let trashedItem = VaultItem(
        id: "trashed-1", name: "Old Email", isFavorite: false, isDeleted: true,
        creationDate: .now, revisionDate: .now,
        content: .login(LoginContent(username: "bob", password: nil, uris: [], totp: nil, notes: nil, customFields: []))
    )

    override func setUp() async throws {
        try await super.setUp()
        vault    = MockVaultRepository()
        mockSync = MockSyncService()
        vault.populate(items: [item, trashedItem], syncedAt: .now)
        let syncRepo = MockSyncTimestampRepository(storedDate: nil)
        sut = VaultBrowserViewModel(
            vault:           vault,
            search:          SearchVaultUseCaseImpl(vault: vault),
            delete:          StubSyncDelete(),
            permanentDelete: StubSyncPermanentDelete(),
            restore:         StubSyncRestore(),
            syncTimestamp:   syncRepo,
            getLastSyncDate: GetLastSyncDateUseCaseImpl(repository: syncRepo),
            syncService:     mockSync
        )
    }

    // MARK: - toggleFavorite

    func testToggleFavorite_success_triggersSyncOnce() async throws {
        let favorited = VaultItem(id: "item-1", name: "GitHub", isFavorite: true, isDeleted: false,
                                  creationDate: item.creationDate, revisionDate: item.revisionDate,
                                  content: item.content)
        vault.stubbedUpdateResult = favorited

        sut.toggleFavorite(item: item)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockSync.triggerCallCount, 1, "trigger() must be called once after toggleFavorite success")
    }

    func testToggleFavorite_failure_doesNotTriggerSync() async throws {
        vault.stubbedUpdateError = SyncError.networkUnavailable

        sut.toggleFavorite(item: item)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockSync.triggerCallCount, 0, "trigger() must NOT be called after toggleFavorite failure")
    }

    // MARK: - performSoftDelete

    func testSoftDelete_success_triggersSyncOnce() async throws {
        await sut.performSoftDelete(id: item.id)
        XCTAssertEqual(mockSync.triggerCallCount, 1, "trigger() must be called once after soft-delete success")
    }

    func testSoftDelete_failure_doesNotTriggerSync() async throws {
        // StubSyncDelete always succeeds — to test failure we inject a failing delete use case.
        let failingSut = makeViewModelWithFailingDelete()
        await failingSut.performSoftDelete(id: item.id)
        XCTAssertEqual(mockSync.triggerCallCount, 0, "trigger() must NOT be called after soft-delete failure")
    }

    // MARK: - performPermanentDelete

    func testPermanentDelete_success_triggersSyncOnce() async throws {
        await sut.performPermanentDelete(id: trashedItem.id)
        XCTAssertEqual(mockSync.triggerCallCount, 1, "trigger() must be called once after permanent delete success")
    }

    func testPermanentDelete_failure_doesNotTriggerSync() async throws {
        let failingSut = makeViewModelWithFailingPermanentDelete()
        await failingSut.performPermanentDelete(id: trashedItem.id)
        XCTAssertEqual(mockSync.triggerCallCount, 0, "trigger() must NOT be called after permanent delete failure")
    }

    // MARK: - performRestore

    func testRestore_success_triggersSyncOnce() async throws {
        await sut.performRestore(id: trashedItem.id)
        XCTAssertEqual(mockSync.triggerCallCount, 1, "trigger() must be called once after restore success")
    }

    func testRestore_failure_doesNotTriggerSync() async throws {
        let failingSut = makeViewModelWithFailingRestore()
        await failingSut.performRestore(id: trashedItem.id)
        XCTAssertEqual(mockSync.triggerCallCount, 0, "trigger() must NOT be called after restore failure")
    }

    // MARK: - handleItemSaved

    func testHandleItemSaved_triggersSyncOnce() {
        sut.handleItemSaved(item)
        XCTAssertEqual(mockSync.triggerCallCount, 1, "trigger() must be called once after handleItemSaved")
    }

    // MARK: - Helpers

    private func makeViewModelWithFailingDelete() -> VaultBrowserViewModel {
        let syncRepo = MockSyncTimestampRepository(storedDate: nil)
        return VaultBrowserViewModel(
            vault: vault, search: SearchVaultUseCaseImpl(vault: vault),
            delete: FailingSyncDelete(), permanentDelete: StubSyncPermanentDelete(),
            restore: StubSyncRestore(), syncTimestamp: syncRepo,
            getLastSyncDate: GetLastSyncDateUseCaseImpl(repository: syncRepo),
            syncService: mockSync
        )
    }

    private func makeViewModelWithFailingPermanentDelete() -> VaultBrowserViewModel {
        let syncRepo = MockSyncTimestampRepository(storedDate: nil)
        return VaultBrowserViewModel(
            vault: vault, search: SearchVaultUseCaseImpl(vault: vault),
            delete: StubSyncDelete(), permanentDelete: FailingSyncPermanentDelete(),
            restore: StubSyncRestore(), syncTimestamp: syncRepo,
            getLastSyncDate: GetLastSyncDateUseCaseImpl(repository: syncRepo),
            syncService: mockSync
        )
    }

    private func makeViewModelWithFailingRestore() -> VaultBrowserViewModel {
        let syncRepo = MockSyncTimestampRepository(storedDate: nil)
        return VaultBrowserViewModel(
            vault: vault, search: SearchVaultUseCaseImpl(vault: vault),
            delete: StubSyncDelete(), permanentDelete: StubSyncPermanentDelete(),
            restore: FailingSyncRestore(), syncTimestamp: syncRepo,
            getLastSyncDate: GetLastSyncDateUseCaseImpl(repository: syncRepo),
            syncService: mockSync
        )
    }
}

// MARK: - Stubs / fakes

private final class StubSyncDelete: DeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}
private final class StubSyncPermanentDelete: PermanentDeleteVaultItemUseCase {
    func execute(id: String) async throws {}
}
private final class StubSyncRestore: RestoreVaultItemUseCase {
    func execute(id: String) async throws {}
}
private final class FailingSyncDelete: DeleteVaultItemUseCase {
    func execute(id: String) async throws { throw SyncError.networkUnavailable }
}
private final class FailingSyncPermanentDelete: PermanentDeleteVaultItemUseCase {
    func execute(id: String) async throws { throw SyncError.networkUnavailable }
}
private final class FailingSyncRestore: RestoreVaultItemUseCase {
    func execute(id: String) async throws { throw SyncError.networkUnavailable }
}
