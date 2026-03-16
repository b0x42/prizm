import XCTest
@testable import Bitwarden_MacOS

// MARK: - VaultRepositoryImplTests (T044)

/// Unit tests for `VaultRepositoryImpl`.
///
/// Covers:
///   - allItems excludes soft-deleted items, sorts case-insensitively
///   - items(for: .allItems) same as allItems
///   - items(for: .favorites) only isFavorite == true
///   - items(for: .type(.login)) only login items
///   - itemCounts returns correct counts across all selections
///   - searchItems filters within the given selection
///   - populate/clearVault state transitions
@MainActor
final class VaultRepositoryImplTests: XCTestCase {

    private var sut: VaultRepositoryImpl!

    override func setUp() async throws {
        try await super.setUp()
        sut = VaultRepositoryImpl()
    }

    // MARK: - Helpers

    private func makeLogin(
        id: String = UUID().uuidString,
        name: String,
        isFavorite: Bool = false,
        isDeleted: Bool = false
    ) -> VaultItem {
        VaultItem(
            id: id,
            name: name,
            isFavorite: isFavorite,
            isDeleted: isDeleted,
            creationDate: Date(),
            revisionDate: Date(),
            content: .login(LoginContent(
                username: nil, password: nil, uris: [], totp: nil,
                notes: nil, customFields: []
            ))
        )
    }

    private func makeCard(
        id: String = UUID().uuidString,
        name: String,
        isFavorite: Bool = false
    ) -> VaultItem {
        VaultItem(
            id: id,
            name: name,
            isFavorite: isFavorite,
            isDeleted: false,
            creationDate: Date(),
            revisionDate: Date(),
            content: .card(CardContent(
                cardholderName: nil, brand: nil, number: nil,
                expMonth: nil, expYear: nil, code: nil,
                notes: nil, customFields: []
            ))
        )
    }

    private func makeSecureNote(id: String = UUID().uuidString, name: String) -> VaultItem {
        VaultItem(
            id: id,
            name: name,
            isFavorite: false,
            isDeleted: false,
            creationDate: Date(),
            revisionDate: Date(),
            content: .secureNote(SecureNoteContent(notes: nil, customFields: []))
        )
    }

    // MARK: - allItems

    func testAllItems_empty_returnsEmpty() throws {
        XCTAssertTrue(try sut.allItems().isEmpty)
    }

    func testAllItems_excludesDeletedItems() throws {
        let active  = makeLogin(name: "Active")
        let deleted = makeLogin(name: "Deleted", isDeleted: true)
        sut.populate(items: [active, deleted], syncedAt: Date())

        let result = try sut.allItems()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, active.id)
    }

    func testAllItems_sortsCaseInsensitive() throws {
        let items = [
            makeLogin(name: "zebra"),
            makeLogin(name: "Apple"),
            makeLogin(name: "mango"),
        ]
        sut.populate(items: items, syncedAt: Date())

        let names = try sut.allItems().map(\.name)
        XCTAssertEqual(names, ["Apple", "mango", "zebra"])
    }

    // MARK: - items(for:)

    func testItemsForAllItems_matchesAllItems() throws {
        let items = [makeLogin(name: "A"), makeCard(name: "B")]
        sut.populate(items: items, syncedAt: Date())

        let all        = try sut.allItems()
        let forAllItems = try sut.items(for: .allItems)
        XCTAssertEqual(all, forAllItems)
    }

    func testItemsForFavorites_onlyFavorites() throws {
        let fav    = makeLogin(name: "Fav", isFavorite: true)
        let notFav = makeLogin(name: "NotFav", isFavorite: false)
        sut.populate(items: [fav, notFav], syncedAt: Date())

        let result = try sut.items(for: .favorites)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, fav.id)
    }

    func testItemsForTypeLogin_onlyLoginItems() throws {
        let login = makeLogin(name: "Login Item")
        let card  = makeCard(name: "Card Item")
        sut.populate(items: [login, card], syncedAt: Date())

        let result = try sut.items(for: .type(.login))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, login.id)
    }

    func testItemsForTypeCard_onlyCardItems() throws {
        let login = makeLogin(name: "Login")
        let card  = makeCard(name: "Visa")
        sut.populate(items: [login, card], syncedAt: Date())

        let result = try sut.items(for: .type(.card))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, card.id)
    }

    func testItemsForType_excludesDeletedItems() throws {
        let active  = makeLogin(name: "Active", isDeleted: false)
        let deleted = makeLogin(name: "Deleted", isDeleted: true)
        sut.populate(items: [active, deleted], syncedAt: Date())

        let result = try sut.items(for: .type(.login))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, active.id)
    }

    // MARK: - itemCounts

    func testItemCounts_empty_allZero() throws {
        let counts = try sut.itemCounts()
        XCTAssertEqual(counts[.allItems], 0)
        XCTAssertEqual(counts[.favorites], 0)
        XCTAssertEqual(counts[.type(.login)], 0)
    }

    func testItemCounts_correctPerCategory() throws {
        let items: [VaultItem] = [
            makeLogin(name: "L1", isFavorite: true),
            makeLogin(name: "L2"),
            makeCard(name: "C1", isFavorite: true),
            makeSecureNote(name: "N1"),
            makeLogin(name: "Deleted Login", isDeleted: true),
        ]
        sut.populate(items: items, syncedAt: Date())

        let counts = try sut.itemCounts()
        XCTAssertEqual(counts[.allItems],          4, "allItems excludes deleted")
        XCTAssertEqual(counts[.favorites],         2, "two favorites (login + card)")
        XCTAssertEqual(counts[.type(.login)],      2, "two non-deleted logins")
        XCTAssertEqual(counts[.type(.card)],       1)
        XCTAssertEqual(counts[.type(.secureNote)], 1)
        XCTAssertEqual(counts[.type(.identity)],   0)
        XCTAssertEqual(counts[.type(.sshKey)],     0)
    }

    // MARK: - searchItems

    func testSearchItems_emptyQuery_returnsAll() throws {
        let items = [makeLogin(name: "Alpha"), makeLogin(name: "Beta")]
        sut.populate(items: items, syncedAt: Date())

        let result = try sut.searchItems(query: "", in: .allItems)
        XCTAssertEqual(result.count, 2)
    }

    func testSearchItems_matchesName_caseInsensitive() throws {
        let items = [makeLogin(name: "MyBank"), makeLogin(name: "GitHub")]
        sut.populate(items: items, syncedAt: Date())

        let result = try sut.searchItems(query: "bank", in: .allItems)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "MyBank")
    }

    func testSearchItems_scopedToSelection() throws {
        let login = makeLogin(name: "MyBank")
        let card  = makeCard(name: "MyCard")
        sut.populate(items: [login, card], syncedAt: Date())

        let result = try sut.searchItems(query: "My", in: .type(.login))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, login.id)
    }

    func testSearchItems_noMatch_returnsEmpty() throws {
        sut.populate(items: [makeLogin(name: "Alpha")], syncedAt: Date())

        let result = try sut.searchItems(query: "zzz", in: .allItems)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - populate / clearVault

    func testPopulate_updatesLastSyncedAt() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        sut.populate(items: [], syncedAt: date)
        XCTAssertEqual(sut.lastSyncedAt, date)
    }

    func testClearVault_removesItemsAndTimestamp() throws {
        sut.populate(items: [makeLogin(name: "X")], syncedAt: Date())
        sut.clearVault()

        XCTAssertTrue(try sut.allItems().isEmpty)
        XCTAssertNil(sut.lastSyncedAt)
    }

    // MARK: - itemDetail

    func testItemDetail_existingId_returnsItem() async throws {
        let item = makeLogin(id: "item-1", name: "Test")
        sut.populate(items: [item], syncedAt: Date())

        let found = try await sut.itemDetail(id: "item-1")
        XCTAssertEqual(found.id, "item-1")
    }

    func testItemDetail_missingId_throwsItemNotFound() async throws {
        await XCTAssertThrowsErrorAsync(
            try await sut.itemDetail(id: "missing")
        ) { error in
            guard case VaultError.itemNotFound(let id) = error else {
                return XCTFail("Expected .itemNotFound, got \(error)")
            }
            XCTAssertEqual(id, "missing")
        }
    }
}
