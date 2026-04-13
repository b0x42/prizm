import XCTest
@testable import Prizm

// MARK: - VaultRepositoryImplDeleteRestoreTests

/// Integration tests for the delete, restore, and empty-trash operations in
/// `VaultRepositoryImpl`.
///
/// Covers:
///   - deleteItem soft-deletes active items (marks isDeleted, stays in cache)
///   - deleteItem permanently removes already-trashed items from cache
///   - restoreItem marks trashed items as active
///   - items(for: .trash) returns only trashed items
///   - itemCounts includes .trash count
///   - API errors propagate correctly
@MainActor
final class VaultRepositoryImplDeleteRestoreTests: XCTestCase {

    private var sut: VaultRepositoryImpl!
    private var mockAPI: MockPrizmAPIClient!
    private var mockCrypto: MockPrizmCryptoService!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI    = MockPrizmAPIClient()
        mockCrypto = MockPrizmCryptoService()
        sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto)
    }

    // MARK: - Helpers

    private func makeLogin(
        id: String = UUID().uuidString,
        name: String,
        isDeleted: Bool = false
    ) -> VaultItem {
        VaultItem(
            id: id, name: name, isFavorite: false, isDeleted: isDeleted,
            creationDate: Date(), revisionDate: Date(),
            content: .login(LoginContent(
                username: nil, password: nil, uris: [], totp: nil,
                notes: nil, customFields: []
            ))
        )
    }

    // MARK: - deleteItem (soft-delete active item)

    func testDeleteItem_activeItem_marksDeletedInCache() async throws {
        let item = makeLogin(id: "id-1", name: "Active Item")
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.deleteItem(id: "id-1")

        // Item should still be in the cache but marked deleted.
        let allActive = try sut.allItems()
        XCTAssertTrue(allActive.isEmpty, "Active list should exclude soft-deleted item")

        let trashed = try sut.items(for: .trash)
        XCTAssertEqual(trashed.count, 1)
        XCTAssertEqual(trashed[0].id, "id-1")
        XCTAssertTrue(trashed[0].isDeleted)
    }

    func testDeleteItem_activeItem_callsAPIOnce() async throws {
        let item = makeLogin(id: "id-1", name: "Active")
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.deleteItem(id: "id-1")

        XCTAssertEqual(mockAPI.softDeleteCallCount, 1)
        XCTAssertEqual(mockAPI.lastSoftDeletedId, "id-1")
    }

    func testPermanentDeleteItem_trashedItem_removesFromCache() async throws {
        let item = makeLogin(id: "id-2", name: "Trashed Item", isDeleted: true)
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.permanentDeleteItem(id: "id-2")

        // Item should be completely removed from the cache.
        let trashed = try sut.items(for: .trash)
        XCTAssertTrue(trashed.isEmpty, "Item should be removed from cache after permanent delete")
    }

    func testPermanentDeleteItem_callsAPIOnce() async throws {
        let item = makeLogin(id: "id-2", name: "Trashed Item", isDeleted: true)
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.permanentDeleteItem(id: "id-2")

        XCTAssertEqual(mockAPI.permanentDeleteCallCount, 1)
        XCTAssertEqual(mockAPI.lastPermanentDeletedId, "id-2")
    }

    func testDeleteItem_apiError_doesNotUpdateCache() async throws {
        let item = makeLogin(id: "id-3", name: "Item")
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())
        mockAPI.softDeleteShouldThrow = APIError.httpError(statusCode: 500, body: "fail")

        do {
            try await sut.deleteItem(id: "id-3")
            XCTFail("Expected error")
        } catch { }

        // Cache should be unchanged after a failed API call.
        let active = try sut.allItems()
        XCTAssertEqual(active.count, 1, "Item should remain active when API call fails")
    }

    // MARK: - restoreItem

    func testRestoreItem_trashedItem_marksActiveInCache() async throws {
        let item = makeLogin(id: "id-4", name: "Trashed", isDeleted: true)
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.restoreItem(id: "id-4")

        let active = try sut.allItems()
        XCTAssertEqual(active.count, 1)
        XCTAssertFalse(active[0].isDeleted)

        let trashed = try sut.items(for: .trash)
        XCTAssertTrue(trashed.isEmpty, "Restored item should not appear in trash")
    }

    func testRestoreItem_callsAPIOnce() async throws {
        let item = makeLogin(id: "id-4", name: "Trashed", isDeleted: true)
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.restoreItem(id: "id-4")

        XCTAssertEqual(mockAPI.restoreCallCount, 1)
        XCTAssertEqual(mockAPI.lastRestoredId, "id-4")
    }

    func testRestoreItem_apiError_doesNotUpdateCache() async throws {
        let item = makeLogin(id: "id-5", name: "Trashed", isDeleted: true)
        sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())
        mockAPI.restoreShouldThrow = APIError.httpError(statusCode: 503, body: "unavailable")

        do {
            try await sut.restoreItem(id: "id-5")
            XCTFail("Expected error")
        } catch { }

        let trashed = try sut.items(for: .trash)
        XCTAssertEqual(trashed.count, 1, "Trashed item should remain when API call fails")
    }

    // MARK: - items(for: .trash)

    func testItemsForTrash_onlyReturnsTrashedItems() throws {
        let active  = makeLogin(name: "Active",  isDeleted: false)
        let trashed = makeLogin(name: "Trashed", isDeleted: true)
        sut.populate(items: [active, trashed], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try sut.items(for: .trash)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Trashed")
    }

    func testItemsForTrash_empty_returnsEmpty() throws {
        sut.populate(items: [makeLogin(name: "Active")], folders: [], organizations: [], collections: [], syncedAt: Date())
        let result = try sut.items(for: .trash)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - itemCounts(.trash)

    func testItemCounts_includesTrashCount() throws {
        let items: [VaultItem] = [
            makeLogin(name: "A", isDeleted: false),
            makeLogin(name: "B", isDeleted: true),
            makeLogin(name: "C", isDeleted: true),
        ]
        sut.populate(items: items, folders: [], organizations: [], collections: [], syncedAt: Date())

        let counts = try sut.itemCounts()
        XCTAssertEqual(counts[.trash], 2, "Trash count should reflect all isDeleted items")
        XCTAssertEqual(counts[.allItems], 1, "Active count should exclude deleted items")
    }
}
