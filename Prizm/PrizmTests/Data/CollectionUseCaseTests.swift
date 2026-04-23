import XCTest
@testable import Prizm

// MARK: - CollectionUseCaseTests (task 4.0)

/// RED tests written before implementation (Constitution §IV — Red first).
///
/// Covers:
///   - VaultRepository `.collection(id)` filtering returns only matching items
///   - VaultRepository `.organization(id)` filtering returns items from all org collections
///   - CreateCollectionUseCaseImpl delegates to repository
///   - RenameCollectionUseCaseImpl delegates to repository
///   - DeleteCollectionUseCaseImpl delegates to repository and removes from cache
///   - VaultRepositoryImpl.createCollection inserts into local cache
///   - VaultRepositoryImpl.renameCollection updates local cache
///   - VaultRepositoryImpl.deleteCollection removes from local cache
///   - Personal item create routes to POST /api/ciphers
///   - Org item create routes to POST /api/ciphers/create
@MainActor
final class CollectionUseCaseTests: XCTestCase {

    // MARK: - Helpers

    private func makeLogin(id: String = UUID().uuidString, name: String,
                           collectionIds: [String] = [], organizationId: String? = nil) -> VaultItem {
        VaultItem(
            id: id, name: name, isFavorite: false, isDeleted: false,
            creationDate: Date(), revisionDate: Date(),
            content: .login(LoginContent(username: nil, password: nil, uris: [], totp: nil,
                                         notes: nil, customFields: [])),
            organizationId: organizationId, collectionIds: collectionIds
        )
    }

    // MARK: - VaultRepository filtering: .collection(id)

    func testCollectionFiltering_returnsOnlyItemsInThatCollection() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto)

        let colA = "col-A"
        let colB = "col-B"

        let itemInA     = makeLogin(name: "InA",    collectionIds: [colA])
        let itemInB     = makeLogin(name: "InB",    collectionIds: [colB])
        let itemInBoth  = makeLogin(name: "InBoth", collectionIds: [colA, colB])
        let itemInNone  = makeLogin(name: "InNone", collectionIds: [])

        await sut.populate(items: [itemInA, itemInB, itemInBoth, itemInNone],
                           folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.items(for: .collection(colA))
        let names  = result.map(\.name)
        XCTAssertTrue(names.contains("InA"),    "InA should appear for collection A")
        XCTAssertTrue(names.contains("InBoth"), "InBoth should appear for collection A")
        XCTAssertFalse(names.contains("InB"),   "InB must NOT appear for collection A")
        XCTAssertFalse(names.contains("InNone"),"InNone must NOT appear for collection A")
        XCTAssertEqual(result.count, 2)
    }

    func testCollectionFiltering_unknownId_returnsEmpty() async throws {
        let sut = VaultRepositoryImpl(apiClient: MockPrizmAPIClient(), crypto: MockPrizmCryptoService())
        await sut.populate(items: [makeLogin(name: "X", collectionIds: ["col-1"])],
                           folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.items(for: .collection("no-such-collection"))
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - VaultRepository filtering: .organization(id)

    func testOrganizationFiltering_returnsItemsFromAllOrgCollections() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto)

        let orgId  = "org-1"
        let colA   = OrgCollection(id: "col-A", organizationId: orgId, name: "Col A")
        let colB   = OrgCollection(id: "col-B", organizationId: orgId, name: "Col B")
        let colOther = OrgCollection(id: "col-other", organizationId: "org-2", name: "Other")

        let inColA   = makeLogin(name: "InColA",  collectionIds: ["col-A"])
        let inColB   = makeLogin(name: "InColB",  collectionIds: ["col-B"])
        let inOther  = makeLogin(name: "InOther", collectionIds: ["col-other"])
        let personal = makeLogin(name: "Personal", collectionIds: [])

        await sut.populate(items: [inColA, inColB, inOther, personal],
                           folders: [], organizations: [],
                           collections: [colA, colB, colOther], syncedAt: Date())

        let result = try await sut.items(for: .organization(orgId))
        let names  = result.map(\.name)
        XCTAssertTrue(names.contains("InColA"),   "InColA must appear for org-1")
        XCTAssertTrue(names.contains("InColB"),   "InColB must appear for org-1")
        XCTAssertFalse(names.contains("InOther"), "InOther is from a different org")
        XCTAssertFalse(names.contains("Personal"),"Personal item is not org-scoped")
        XCTAssertEqual(result.count, 2)
    }

    func testOrganizationFiltering_noCollections_returnsEmpty() async throws {
        let sut = VaultRepositoryImpl(apiClient: MockPrizmAPIClient(), crypto: MockPrizmCryptoService())
        await sut.populate(items: [makeLogin(name: "X", collectionIds: ["col-A"])],
                           folders: [], organizations: [], collections: [], syncedAt: Date())

        let result = try await sut.items(for: .organization("org-1"))
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Personal vs org item create routing

    func testCreate_personalItem_routesToCreateCipher() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto)

        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0xAA, count: 32),
            macKey:        Data(repeating: 0xBB, count: 32)
        ))

        let now = Date()
        let draft = DraftVaultItem(
            id: UUID().uuidString, name: "Personal Item",
            isFavorite: false, isDeleted: false,
            creationDate: now, revisionDate: now,
            content: .secureNote(DraftSecureNoteContent(SecureNoteContent(notes: nil, customFields: []))),
            reprompt: 0
        )
        // organizationId is nil → personal item

        _ = try await sut.create(draft)

        XCTAssertEqual(mockAPI.createCipherCallCount, 1,
                       "Personal item must route to POST /api/ciphers")
        XCTAssertEqual(mockAPI.createOrgCipherCallCount, 0,
                       "Org endpoint must NOT be called for personal items")
    }

    func testCreate_orgItem_routesToCreateOrgCipher() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let orgCache   = OrgKeyCache()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto,
                                             orgKeyCache: orgCache)

        let orgKeys = CryptoKeys(encryptionKey: Data(repeating: 0xCC, count: 32),
                                 macKey:        Data(repeating: 0xDD, count: 32))
        await orgCache.store(key: orgKeys, for: "org-1")
        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0xAA, count: 32),
            macKey:        Data(repeating: 0xBB, count: 32)
        ))

        let now = Date()
        var draft = DraftVaultItem(
            id: UUID().uuidString, name: "Org Item",
            isFavorite: false, isDeleted: false,
            creationDate: now, revisionDate: now,
            content: .secureNote(DraftSecureNoteContent(SecureNoteContent(notes: nil, customFields: []))),
            reprompt: 0
        )
        draft.organizationId = "org-1"
        draft.collectionIds  = ["col-1"]

        _ = try await sut.create(draft)

        XCTAssertEqual(mockAPI.createOrgCipherCallCount, 1,
                       "Org item must route to POST /api/ciphers/create")
        XCTAssertEqual(mockAPI.createCipherCallCount, 0,
                       "Personal endpoint must NOT be called for org items")
    }

    // MARK: - VaultRepositoryImpl.createCollection

    func testCreateCollection_insertsIntoLocalCache() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let orgCache   = OrgKeyCache()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto,
                                             orgKeyCache: orgCache)

        let orgKeys = CryptoKeys(encryptionKey: Data(repeating: 0xAA, count: 32),
                                 macKey:        Data(repeating: 0xBB, count: 32))
        await orgCache.store(key: orgKeys, for: "org-1")
        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0x11, count: 32),
            macKey:        Data(repeating: 0x22, count: 32)
        ))

        // Stub API response
        mockAPI.createCollectionResponse = RawCollection(
            id: "col-new", organizationId: "org-1", name: "2.encrypted|iv|mac"
        )

        let created = try await sut.createCollection(name: "Work Passwords", organizationId: "org-1")

        XCTAssertEqual(created.id, "col-new")
        XCTAssertEqual(created.organizationId, "org-1")
        XCTAssertEqual(created.name, "Work Passwords", "Cache must store plaintext name")

        let cached = try await sut.collections()
        XCTAssertTrue(cached.contains(where: { $0.id == "col-new" }),
                      "New collection must appear in collections()")
    }

    func testCreateCollection_usesEncryptedNameForAPICall() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let orgCache   = OrgKeyCache()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto,
                                             orgKeyCache: orgCache)

        let orgKeys = CryptoKeys(encryptionKey: Data(repeating: 0xAA, count: 32),
                                 macKey:        Data(repeating: 0xBB, count: 32))
        await orgCache.store(key: orgKeys, for: "org-1")
        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0x11, count: 32),
            macKey:        Data(repeating: 0x22, count: 32)
        ))

        let plaintext = "Secret Collection"
        _ = try await sut.createCollection(name: plaintext, organizationId: "org-1")

        // The encrypted name sent to the API must NOT equal the plaintext.
        XCTAssertNotNil(mockAPI.lastCreateCollectionEncryptedName)
        XCTAssertNotEqual(mockAPI.lastCreateCollectionEncryptedName, plaintext,
                          "Collection name must be encrypted before being sent to the API")
    }

    func testCreateCollection_missingOrgKey_throws() async throws {
        let sut = VaultRepositoryImpl(apiClient: MockPrizmAPIClient(), crypto: MockPrizmCryptoService())
        // OrgKeyCache is empty — org key not present.
        await XCTAssertThrowsErrorAsync(
            try await sut.createCollection(name: "Test", organizationId: "org-99")
        ) { error in
            XCTAssertNotNil(error, "Must throw when org key is absent")
        }
    }

    // MARK: - VaultRepositoryImpl.renameCollection

    func testRenameCollection_updatesLocalCache() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let orgCache   = OrgKeyCache()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto,
                                             orgKeyCache: orgCache)

        let orgKeys = CryptoKeys(encryptionKey: Data(repeating: 0xAA, count: 32),
                                 macKey:        Data(repeating: 0xBB, count: 32))
        await orgCache.store(key: orgKeys, for: "org-1")
        await mockCrypto.unlockWith(keys: CryptoKeys(
            encryptionKey: Data(repeating: 0x11, count: 32),
            macKey:        Data(repeating: 0x22, count: 32)
        ))

        let existing = OrgCollection(id: "col-1", organizationId: "org-1", name: "Old Name")
        await sut.populate(items: [], folders: [], organizations: [],
                           collections: [existing], syncedAt: Date())

        mockAPI.renameCollectionResponse = RawCollection(
            id: "col-1", organizationId: "org-1", name: "2.encNewName|iv|mac"
        )

        let renamed = try await sut.renameCollection(id: "col-1", organizationId: "org-1",
                                                      name: "New Name")

        XCTAssertEqual(renamed.name, "New Name")
        let cached = try await sut.collections()
        XCTAssertEqual(cached.first(where: { $0.id == "col-1" })?.name, "New Name",
                       "Cache must reflect the new plaintext name")
    }

    // MARK: - VaultRepositoryImpl.deleteCollection

    func testDeleteCollection_removesFromLocalCache() async throws {
        let mockAPI    = MockPrizmAPIClient()
        let mockCrypto = MockPrizmCryptoService()
        let sut        = VaultRepositoryImpl(apiClient: mockAPI, crypto: mockCrypto)

        let col = OrgCollection(id: "col-delete-me", organizationId: "org-1", name: "Bye")
        await sut.populate(items: [], folders: [], organizations: [],
                           collections: [col], syncedAt: Date())

        try await sut.deleteCollection(id: "col-delete-me", organizationId: "org-1")

        let cached = try await sut.collections()
        XCTAssertFalse(cached.contains(where: { $0.id == "col-delete-me" }),
                       "Deleted collection must be removed from local cache")
    }

    // MARK: - CreateCollectionUseCaseImpl

    func testCreateCollectionUseCase_execute_delegatesToRepository() async throws {
        let mockRepo = MockVaultRepository()
        let sut      = CreateCollectionUseCaseImpl(repository: mockRepo)

        let col = OrgCollection(id: "col-1", organizationId: "org-1", name: "Finances")
        mockRepo.stubbedCreateCollectionResult = col

        let result = try await sut.execute(name: "Finances", organizationId: "org-1")

        XCTAssertEqual(result.id, "col-1")
        XCTAssertEqual(mockRepo.createCollectionCallCount, 1)
        XCTAssertEqual(mockRepo.lastCreateCollectionName, "Finances")
        XCTAssertEqual(mockRepo.lastCreateCollectionOrgId, "org-1")
    }

    // MARK: - RenameCollectionUseCaseImpl

    func testRenameCollectionUseCase_execute_delegatesToRepository() async throws {
        let mockRepo = MockVaultRepository()
        let sut      = RenameCollectionUseCaseImpl(repository: mockRepo)

        let col = OrgCollection(id: "col-1", organizationId: "org-1", name: "Finances 2")
        mockRepo.stubbedRenameCollectionResult = col

        let result = try await sut.execute(collectionId: "col-1", name: "Finances 2",
                                            organizationId: "org-1")

        XCTAssertEqual(result.id, "col-1")
        XCTAssertEqual(mockRepo.renameCollectionCallCount, 1)
    }

    // MARK: - DeleteCollectionUseCaseImpl

    func testDeleteCollectionUseCase_execute_delegatesToRepository() async throws {
        let mockRepo = MockVaultRepository()
        let sut      = DeleteCollectionUseCaseImpl(repository: mockRepo)

        try await sut.execute(collectionId: "col-1", organizationId: "org-1")

        XCTAssertEqual(mockRepo.deleteCollectionCallCount, 1)
        XCTAssertEqual(mockRepo.lastDeleteCollectionId, "col-1")
        XCTAssertEqual(mockRepo.lastDeleteCollectionOrgId, "org-1")
    }
}
