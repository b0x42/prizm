import XCTest
@testable import Prizm

// MARK: - Mocks

private final class MockAttachmentRepository: AttachmentRepository {
    var uploadCalled = false
    var uploadResult: Result<Attachment, Error> = .success(
        Attachment(id: "att-1", fileName: "file.txt", encryptedKey: "2.x|y|z",
                   size: 64, sizeName: "64 B", url: nil, isUploadIncomplete: false)
    )
    var downloadCalled = false
    var downloadResult: Result<Data, Error> = .success(Data("hello".utf8))
    var deleteCalled = false
    var deleteResult: Result<Void, Error> = .success(())

    func upload(cipherId: String, fileName: String, data: Data, cipherKey: Data) async throws -> Attachment {
        uploadCalled = true
        return try uploadResult.get()
    }
    func download(cipherId: String, attachment: Attachment, cipherKey: Data) async throws -> Data {
        downloadCalled = true
        return try downloadResult.get()
    }
    func delete(cipherId: String, attachmentId: String) async throws {
        deleteCalled = true
        try deleteResult.get()
    }
}

private final class MockVaultKeyService: VaultKeyService {
    var keyResult: Result<Data, Error> = .success(Data(repeating: 0xAB, count: 64))
    var cipherKeyCalled = false

    func cipherKey(for cipherId: String) async throws -> Data {
        cipherKeyCalled = true
        return try keyResult.get()
    }
}

// MARK: - UploadAttachmentUseCaseImpl Tests

final class UploadAttachmentUseCaseTests: XCTestCase {

    private var mockRepo: MockAttachmentRepository!
    private var mockKeyService: MockVaultKeyService!
    private var sut: UploadAttachmentUseCaseImpl!

    override func setUp() {
        mockRepo       = MockAttachmentRepository()
        mockKeyService = MockVaultKeyService()
        sut            = UploadAttachmentUseCaseImpl(repository: mockRepo, vaultKeyService: mockKeyService)
    }

    func test_execute_fetchesCipherKeyInternally() async throws {
        _ = try await sut.execute(cipherId: "cipher-1", fileName: "photo.jpg", data: Data())
        XCTAssertTrue(mockKeyService.cipherKeyCalled, "VaultKeyService must be called internally")
        XCTAssertTrue(mockRepo.uploadCalled)
    }

    func test_execute_doesNotExposeKeyInSignature() async throws {
        // The execute signature has no cipherKey parameter — this is a compile-time guarantee.
        // This test verifies the successful path works end-to-end.
        let result = try await sut.execute(cipherId: "c-1", fileName: "doc.pdf", data: Data("content".utf8))
        XCTAssertEqual(result.id, "att-1")
    }

    func test_execute_propagatesVaultLockedError() async {
        mockKeyService.keyResult = .failure(VaultError.vaultLocked)
        do {
            _ = try await sut.execute(cipherId: "c-1", fileName: "f", data: Data())
            XCTFail("Expected VaultError.vaultLocked")
        } catch VaultError.vaultLocked {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_propagatesUploadError() async {
        mockRepo.uploadResult = .failure(AttachmentError.premiumRequired)
        do {
            _ = try await sut.execute(cipherId: "c-1", fileName: "f", data: Data())
            XCTFail("Expected AttachmentError.premiumRequired")
        } catch AttachmentError.premiumRequired {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - DownloadAttachmentUseCaseImpl Tests

final class DownloadAttachmentUseCaseTests: XCTestCase {

    private var mockRepo: MockAttachmentRepository!
    private var mockKeyService: MockVaultKeyService!
    private var sut: DownloadAttachmentUseCaseImpl!

    private let stubAttachment = Attachment(
        id: "att-1", fileName: "file.txt", encryptedKey: "2.x|y|z",
        size: 64, sizeName: "64 B", url: "https://cdn.example.com/file", isUploadIncomplete: false
    )

    override func setUp() {
        mockRepo       = MockAttachmentRepository()
        mockKeyService = MockVaultKeyService()
        sut            = DownloadAttachmentUseCaseImpl(repository: mockRepo, vaultKeyService: mockKeyService)
    }

    func test_execute_fetchesCipherKeyInternally() async throws {
        _ = try await sut.execute(cipherId: "c-1", attachment: stubAttachment)
        XCTAssertTrue(mockKeyService.cipherKeyCalled, "VaultKeyService must be called internally")
        XCTAssertTrue(mockRepo.downloadCalled)
    }

    func test_execute_propagatesVaultLockedError() async {
        mockKeyService.keyResult = .failure(VaultError.vaultLocked)
        do {
            _ = try await sut.execute(cipherId: "c-1", attachment: stubAttachment)
            XCTFail("Expected VaultError.vaultLocked")
        } catch VaultError.vaultLocked {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_propagatesDownloadError() async {
        mockRepo.downloadResult = .failure(AttachmentError.downloadFailed)
        do {
            _ = try await sut.execute(cipherId: "c-1", attachment: stubAttachment)
            XCTFail("Expected AttachmentError.downloadFailed")
        } catch AttachmentError.downloadFailed {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - DeleteAttachmentUseCaseImpl Tests

final class DeleteAttachmentUseCaseTests: XCTestCase {

    private var mockRepo: MockAttachmentRepository!
    private var sut: DeleteAttachmentUseCaseImpl!

    override func setUp() {
        mockRepo = MockAttachmentRepository()
        sut      = DeleteAttachmentUseCaseImpl(repository: mockRepo)
        // Note: no VaultKeyService — delete requires no key material (Constitution §VI)
    }

    func test_execute_callsRepositoryDelete() async throws {
        try await sut.execute(cipherId: "c-1", attachmentId: "att-1")
        XCTAssertTrue(mockRepo.deleteCalled)
    }

    func test_execute_propagatesDeleteError() async {
        mockRepo.deleteResult = .failure(AttachmentError.downloadFailed)
        do {
            try await sut.execute(cipherId: "c-1", attachmentId: "att-1")
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(mockRepo.deleteCalled)
        }
    }

    func test_delete_doesNotUseVaultKeyService() {
        // Structural: DeleteAttachmentUseCaseImpl has no VaultKeyService property.
        // This is a compile-time guarantee enforced by the type system — if a developer
        // adds VaultKeyService to the init, this test will fail to compile with the
        // existing init signature, making the violation visible at build time.
        let _impl = DeleteAttachmentUseCaseImpl(repository: mockRepo)
        _ = _impl
    }
}
