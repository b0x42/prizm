import XCTest
@testable import Macwarden

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
        vault.populate(items: [unfavoritedItem], syncedAt: .now)
        sut = VaultBrowserViewModel(
            vault: vault,
            search: SearchVaultUseCaseImpl(vault: vault),
            delete: StubDelete(),
            permanentDelete: StubPermanentDelete(),
            restore: StubRestore()
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
        vault.populate(items: [favoritedItem], syncedAt: .now)
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
