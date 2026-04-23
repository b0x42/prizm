import XCTest
@testable import Prizm

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

    func testAllItems_empty_returnsEmpty() async throws {
        let result = try await sut.allItems()
        XCTAssertTrue(result.isEmpty)
    }

    func testAllItems_excludesDeletedItems() async throws {
        let active  = makeLogin(name: "Active")
        let deleted = makeLogin(name: "Deleted", isDeleted: true)
        await sut.populate(items: [active, deleted], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.allItems()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, active.id)
    }

    func testAllItems_sortsCaseInsensitive() async throws {
        let items = [
            makeLogin(name: "zebra"),
            makeLogin(name: "Apple"),
            makeLogin(name: "mango"),
        ]
        await sut.populate(items: items, folders: [], organizations: [], collections: [], syncedAt: Date())

        let names = try await sut.allItems().map(\.name)
        XCTAssertEqual(names, ["Apple", "mango", "zebra"])
    }

    // MARK: - items(for:)

    func testItemsForAllItems_matchesAllItems() async throws {
        let items = [makeLogin(name: "A"), makeCard(name: "B")]
        await sut.populate(items: items, folders: [], organizations: [], collections: [], syncedAt: Date())

        let all        = try await sut.allItems()
        let forAllItems = try await sut.items(for: .allItems)
        XCTAssertEqual(all, forAllItems)
    }

    func testItemsForFavorites_onlyFavorites() async throws {
        let fav    = makeLogin(name: "Fav", isFavorite: true)
        let notFav = makeLogin(name: "NotFav", isFavorite: false)
        await sut.populate(items: [fav, notFav], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.items(for: .favorites)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, fav.id)
    }

    func testItemsForTypeLogin_onlyLoginItems() async throws {
        let login = makeLogin(name: "Login Item")
        let card  = makeCard(name: "Card Item")
        await sut.populate(items: [login, card], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.items(for: .type(.login))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, login.id)
    }

    func testItemsForTypeCard_onlyCardItems() async throws {
        let login = makeLogin(name: "Login")
        let card  = makeCard(name: "Visa")
        await sut.populate(items: [login, card], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.items(for: .type(.card))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, card.id)
    }

    func testItemsForType_excludesDeletedItems() async throws {
        let active  = makeLogin(name: "Active", isDeleted: false)
        let deleted = makeLogin(name: "Deleted", isDeleted: true)
        await sut.populate(items: [active, deleted], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.items(for: .type(.login))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, active.id)
    }

    // MARK: - itemCounts

    func testItemCounts_empty_allZero() async throws {
        let counts = try await sut.itemCounts()
        XCTAssertEqual(counts[.allItems], 0)
        XCTAssertEqual(counts[.favorites], 0)
        XCTAssertEqual(counts[.type(.login)], 0)
    }

    func testItemCounts_correctPerCategory() async throws {
        let items: [VaultItem] = [
            makeLogin(name: "L1", isFavorite: true),
            makeLogin(name: "L2"),
            makeCard(name: "C1", isFavorite: true),
            makeSecureNote(name: "N1"),
            makeLogin(name: "Deleted Login", isDeleted: true),
        ]
        await sut.populate(items: items, folders: [], organizations: [], collections: [], syncedAt: Date())

        let counts = try await sut.itemCounts()
        XCTAssertEqual(counts[.allItems],          4, "allItems excludes deleted")
        XCTAssertEqual(counts[.favorites],         2, "two favorites (login + card)")
        XCTAssertEqual(counts[.type(.login)],      2, "two non-deleted logins")
        XCTAssertEqual(counts[.type(.card)],       1)
        XCTAssertEqual(counts[.type(.secureNote)], 1)
        XCTAssertEqual(counts[.type(.identity)],   0)
        XCTAssertEqual(counts[.type(.sshKey)],     0)
    }

    // MARK: - searchItems

    func testSearchItems_emptyQuery_returnsAll() async throws {
        let items = [makeLogin(name: "Alpha"), makeLogin(name: "Beta")]
        await sut.populate(items: items, folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.searchItems(query: "", in: .allItems)
        XCTAssertEqual(result.count, 2)
    }

    func testSearchItems_matchesName_caseInsensitive() async throws {
        let items = [makeLogin(name: "MyBank"), makeLogin(name: "GitHub")]
        await sut.populate(items: items, folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.searchItems(query: "bank", in: .allItems)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "MyBank")
    }

    func testSearchItems_scopedToSelection() async throws {
        let login = makeLogin(name: "MyBank")
        let card  = makeCard(name: "MyCard")
        await sut.populate(items: [login, card], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.searchItems(query: "My", in: .type(.login))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, login.id)
    }

    func testSearchItems_noMatch_returnsEmpty() async throws {
        await sut.populate(items: [makeLogin(name: "Alpha")], folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.searchItems(query: "zzz", in: .allItems)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - populate / clearVault

    func testPopulate_updatesLastSyncedAt() async {
        let date = Date(timeIntervalSince1970: 1_000_000)
        await sut.populate(items: [], folders: [], organizations: [], collections: [], syncedAt: date)
        let stored = await sut.lastSyncedAt
        XCTAssertEqual(stored, date)
    }

    func testClearVault_removesItemsAndTimestamp() async throws {
        await sut.populate(items: [makeLogin(name: "X")], folders: [], organizations: [], collections: [], syncedAt: Date())
        await sut.clearVault()

        let items = try await sut.allItems()
        XCTAssertTrue(items.isEmpty)
        let ts = await sut.lastSyncedAt
        XCTAssertNil(ts)
    }

    // MARK: - Index correctness

    func testItemCounts_O1_returnsFromCache() async throws {
        let items: [VaultItem] = [
            makeLogin(name: "L1", isFavorite: true),
            makeLogin(name: "L2"),
            makeCard(name: "C1"),
        ]
        await sut.populate(items: items, folders: [], organizations: [], collections: [], syncedAt: Date())
        let counts = try await sut.itemCounts()
        XCTAssertEqual(counts[.allItems], 3)
        XCTAssertEqual(counts[.favorites], 1)
        XCTAssertEqual(counts[.type(.login)], 2)
        XCTAssertEqual(counts[.type(.card)], 1)
    }

    func testPopulateTwice_countsReflectSecondCall() async throws {
        await sut.populate(items: [makeLogin(name: "A")], folders: [], organizations: [], collections: [], syncedAt: Date())
        await sut.populate(items: [makeLogin(name: "B"), makeCard(name: "C")], folders: [], organizations: [], collections: [], syncedAt: Date())
        let counts = try await sut.itemCounts()
        XCTAssertEqual(counts[.allItems], 2)
        XCTAssertEqual(counts[.type(.login)], 1)
        XCTAssertEqual(counts[.type(.card)], 1)
    }

    func testClearVault_resetsIndexes() async throws {
        await sut.populate(items: [makeLogin(name: "X")], folders: [], organizations: [], collections: [], syncedAt: Date())
        await sut.clearVault()
        let all    = try await sut.allItems()
        let counts = try await sut.itemCounts()
        XCTAssertTrue(all.isEmpty)
        XCTAssertEqual(counts[.allItems] ?? 0, 0)
    }

    func testItemsForOrganization_usesPrebuiltIndex() async throws {
        let orgId  = "org-1"
        let colId  = "col-1"
        let org    = Organization(id: orgId, name: "Acme", role: .user)
        let col    = OrgCollection(id: colId, organizationId: orgId, name: "Dev")
        let item   = VaultItem(
            id: "i1", name: "Org Item", isFavorite: false, isDeleted: false,
            creationDate: Date(), revisionDate: Date(),
            content: .login(LoginContent(username: nil, password: nil, uris: [], totp: nil, notes: nil, customFields: [])),
            organizationId: orgId, collectionIds: [colId]
        )
        await sut.populate(items: [item], folders: [], organizations: [org], collections: [col], syncedAt: Date())
        let result = try await sut.items(for: .organization(orgId))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "i1")
    }

    func testCreate_updatesIndex() async throws {
        await sut.populate(items: [], folders: [], organizations: [], collections: [], syncedAt: Date())
        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0xDE, count: 32),
            macKey:        Data(repeating: 0xAD, count: 32)
        ))
        let draft = DraftVaultItem(makeLogin(name: "NewItem"))
        _ = try await sut.create(draft)
        let counts = try await sut.itemCounts()
        XCTAssertEqual(counts[.allItems], 1)
    }

    // MARK: - itemDetail

    func testItemDetail_existingId_returnsItem() async throws {
        let item = makeLogin(id: "item-1", name: "Test")
        await sut.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())

        let found = try await sut.itemDetail(id: "item-1")
        XCTAssertEqual(found.id, "item-1")
    }

    func testItemDetail_missingId_throwsItemNotFound() async throws {
        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.itemDetail(id: "missing")
        ) { error in
            guard case VaultError.itemNotFound(let id) = error else {
                return XCTFail("Expected .itemNotFound, got \(error)")
            }
            XCTAssertEqual(id, "missing")
        }
    }

    // MARK: - update (task 4.4)

    func testUpdate_success_replacesItemInCacheAndReturnsUpdatedItem() async throws {
        let original = makeLogin(id: "item-1", name: "Original Name")
        await sut.populate(items: [original], folders: [], organizations: [], collections: [], syncedAt: Date())

        // Vault must be unlocked to provide keys to the mapper.
        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0xDE, count: 32),
            macKey:        Data(repeating: 0xAD, count: 32)
        ))

        var draft = DraftVaultItem(original)
        draft.name = "Updated Name"

        let result = try await sut.update(draft)

        XCTAssertEqual(result.name, "Updated Name")
        // Verify the in-memory cache was updated.
        let cached = try await sut.allItems().first { $0.id == "item-1" }
        XCTAssertEqual(cached?.name, "Updated Name")
    }

    func testUpdate_vaultLocked_throwsVaultLocked() async throws {
        let original = makeLogin(id: "item-2", name: "Name")
        await sut.populate(items: [original], folders: [], organizations: [], collections: [], syncedAt: Date())
        // mockCrypto is locked by default (not unlocked)

        let draft = DraftVaultItem(original)

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(try await sut.update(draft)) { error in
            guard case VaultError.vaultLocked = error else {
                return XCTFail("Expected VaultError.vaultLocked, got \(error)")
            }
        }
    }

    func testUpdate_apiError_throws() async throws {
        let original = makeLogin(id: "item-3", name: "Name")
        await sut.populate(items: [original], folders: [], organizations: [], collections: [], syncedAt: Date())

        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0xDE, count: 32),
            macKey:        Data(repeating: 0xAD, count: 32)
        ))
        mockAPI.updateCipherShouldThrow = APIError.httpError(statusCode: 500, body: "Internal Server Error")

        let draft = DraftVaultItem(original)

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(try await sut.update(draft)) { error in
            guard let apiError = error as? APIError,
                  case APIError.httpError(let code, _) = apiError else {
                return XCTFail("Expected APIError.httpError, got \(error)")
            }
            XCTAssertEqual(code, 500)
        }
    }
}
