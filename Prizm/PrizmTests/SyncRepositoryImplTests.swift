import Synchronization
import XCTest
@testable import Prizm

/// Failing tests for SyncRepositoryImpl (T025).
/// These will fail until SyncRepositoryImpl + PrizmAPIClient are implemented (T027–T030).
@MainActor
final class SyncRepositoryImplTests: XCTestCase {

    private var sut: SyncRepositoryImpl!
    private var mockAPI: MockPrizmAPIClient!
    private var mockCrypto: MockPrizmCryptoService!
    private var mockVault: MockVaultRepository!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI    = MockPrizmAPIClient()
        mockCrypto = MockPrizmCryptoService()
        mockVault  = MockVaultRepository()
        sut = SyncRepositoryImpl(
            apiClient:       mockAPI,
            crypto:          mockCrypto,
            vaultRepository: mockVault
        )
    }

    // MARK: - T025: sync()

    /// sync() fires at least one progress message containing "Syncing" and one containing "Decrypt".
    func testSync_firesProgressCallbacks() async throws {
        mockAPI.syncResponse          = makeSyncResponse(cipherCount: 0)
        mockCrypto.stubbedDecryptList = []

        let collected = Mutex<[String]>([])
        _ = try await sut.sync(progress: { msg in
            collected.withLock { $0.append(msg) }
        })

        let messages = collected.withLock { $0 }
        XCTAssertTrue(
            messages.contains(where: { $0.localizedCaseInsensitiveContains("Syncing") }),
            "Expected a 'Syncing vault' progress message; got: \(messages)"
        )
        XCTAssertTrue(
            messages.contains(where: { $0.localizedCaseInsensitiveContains("Decrypt") }),
            "Expected a 'Decrypting' progress message; got: \(messages)"
        )
    }

    /// sync() stores all successfully decrypted items in VaultRepository.
    func testSync_storesDecryptedItems() async throws {
        let items = [makeVaultItem(id: "a"), makeVaultItem(id: "b")]
        mockAPI.syncResponse          = makeSyncResponse(cipherCount: 2)
        mockCrypto.stubbedDecryptList = items

        _ = try await sut.sync(progress: { _ in })

        XCTAssertEqual(mockVault.populatedItems.count, 2)
        XCTAssertEqual(Set(mockVault.populatedItems.map(\.id)), ["a", "b"])
    }

    /// sync() returns a SyncResult whose totalCiphers equals the raw count from the server.
    func testSync_returnsCorrectTotalCiphers() async throws {
        mockAPI.syncResponse          = makeSyncResponse(cipherCount: 5)
        mockCrypto.stubbedDecryptList = Array(repeating: makeVaultItem(), count: 5)

        let result = try await sut.sync(progress: { _ in })

        XCTAssertEqual(result.totalCiphers, 5)
    }

    /// sync() returns a SyncResult whose failedDecryptionCount reflects decryption failures.
    func testSync_returnsCorrectFailedCount() async throws {
        // 3 ciphers in response; mock says 2 decrypted successfully → 1 failure
        mockAPI.syncResponse           = makeSyncResponse(cipherCount: 3)
        mockCrypto.stubbedDecryptList  = [makeVaultItem(), makeVaultItem()]
        mockCrypto.stubbedFailedCount  = 1

        let result = try await sut.sync(progress: { _ in })

        XCTAssertEqual(result.failedDecryptionCount, 1)
    }

    /// A concurrent sync() call thrown while one is already in flight returns .syncInProgress.
    func testSync_throwsSyncInProgressWhenReentrant() async throws {
        mockAPI.syncResponse          = makeSyncResponse(cipherCount: 0)
        mockCrypto.stubbedDecryptList = []
        // Add a small delay so the first sync stays "in flight" long enough for the second call.
        mockAPI.syncDelay = 0.3

        let sut = self.sut!
        let firstTask = Task { @MainActor in
            try await sut.sync(progress: { _ in })
        }
        // Let the first sync begin.
        try await Task.sleep(nanoseconds: 50_000_000)

        await XCTAssertThrowsErrorAsync(
            try await sut.sync(progress: { _ in })
        ) { error in
            XCTAssertEqual(error as? SyncError, .syncInProgress)
        }

        _ = try await firstTask.value
    }

    /// GET /sync returning an unauthorized error propagates as SyncError.unauthorized.
    func testSync_propagatesUnauthorizedError() async throws {
        mockAPI.syncShouldThrow = APIError.httpError(statusCode: 401, body: "")

        let sut = self.sut!
        await XCTAssertThrowsErrorAsync(
            try await sut.sync(progress: { _ in })
        ) { error in
            XCTAssertEqual(error as? SyncError, .unauthorized)
        }
    }

    /// syncedAt on the returned SyncResult is close to the current time.
    func testSync_syncedAtIsRecent() async throws {
        mockAPI.syncResponse          = makeSyncResponse(cipherCount: 0)
        mockCrypto.stubbedDecryptList = []

        let before = Date()
        let result = try await sut.sync(progress: { _ in })

        XCTAssertGreaterThanOrEqual(result.syncedAt, before)
    }

    // MARK: - Helpers

    private func makeSyncResponse(cipherCount: Int) -> SyncResponse {
        let ciphers: [RawCipher] = (0..<cipherCount).map { i in
            RawCipher(
                id:             "cipher-\(i)",
                organizationId: nil,
                type:           2,   // secureNote — simplest type
                name:           "2.name\(i)==",
                notes:          nil,
                favorite:       false,
                reprompt:       nil,
                deletedDate:    nil,
                creationDate:   nil,
                revisionDate:   nil,
                login:          nil,
                card:           nil,
                identity:       nil,
                secureNote:     nil,
                sshKey:         nil,
                fields:         []
            )
        }
        return SyncResponse(
            profile: RawProfile(
                id:         "profile-id",
                email:      "alice@example.com",
                name:       nil,
                key:        "2.encKey==",
                privateKey: "2.encPrivKey=="
            ),
            ciphers: ciphers
        )
    }

    private func makeVaultItem(id: String = UUID().uuidString) -> VaultItem {
        VaultItem(
            id:           id,
            name:         "Test Item",
            isFavorite:   false,
            isDeleted:    false,
            creationDate: Date(),
            revisionDate: Date(),
            content:      .secureNote(SecureNoteContent(notes: nil, customFields: []))
        )
    }
}
