import XCTest
@testable import Prizm

/// Integration tests for `AttachmentRepositoryImpl`.
///
/// Uses real `PrizmCryptoServiceImpl` (actual AES-CBC + HMAC-SHA256), a mock API client,
/// and a mock vault repository to verify the full upload/download/delete lifecycles.
///
/// "Integration" here means: real crypto + mock network + mock storage — the same level as
/// `AttachmentCryptoTests`, but exercised through the repository boundary with the full two-layer
/// key scheme (attachment key encrypted with cipher key, blob encrypted with attachment key).
@MainActor
final class AttachmentRepositoryImplTests: XCTestCase {

    private var sut: AttachmentRepositoryImpl!
    private var apiClient: MockPrizmAPIClient!
    private var vaultRepo: MockVaultRepository!
    private var crypto: PrizmCryptoServiceImpl!

    // 64-byte cipher key: encryptionKey (first 32) ‖ macKey (last 32)
    private let cipherKey = Data(repeating: 0xAB, count: 32) + Data(repeating: 0xCD, count: 32)

    private let cipherId      = "cipher-abc"
    private let attachmentId  = "att-xyz"
    private let plainFileName = "document.pdf"
    private let plainData     = Data("Hello from Prizm integration test".utf8)

    override func setUp() async throws {
        apiClient  = MockPrizmAPIClient()
        vaultRepo  = MockVaultRepository()
        crypto     = PrizmCryptoServiceImpl()

        sut = AttachmentRepositoryImpl(
            apiClient:       apiClient,
            crypto:          crypto,
            vaultRepository: vaultRepo
        )

        // Seed vault with a cipher so updateAttachments can find it
        let item = VaultItem(
            id:           cipherId,
            name:         "Test Item",
            isFavorite:   false,
            isDeleted:    false,
            creationDate: Date(),
            revisionDate: Date(),
            content:      .secureNote(SecureNoteContent(notes: nil, customFields: [])),
            attachments:  []
        )
        vaultRepo.populate(items: [item], folders: [], organizations: [], collections: [], syncedAt: Date())
    }

    // MARK: - Upload: fileUploadType 0 (Bitwarden-hosted)

    func test_upload_fileUploadType0_callsBitwardenHostedUpload() async throws {
        apiClient.createAttachmentMetadataResponse = AttachmentMetadataResponse(
            attachmentId: attachmentId,
            url:          "https://api.bitwarden.com/ciphers/\(cipherId)/attachment/\(attachmentId)",
            fileUploadType: 0
        )

        _ = try await sut.upload(
            cipherId:  cipherId,
            fileName:  plainFileName,
            data:      plainData,
            cipherKey: cipherKey
        )

        // Verify correct upload path was taken
        XCTAssertEqual(apiClient.uploadBitwardenHostedCallCount, 1)
        XCTAssertEqual(apiClient.uploadAzureCallCount, 0)
        XCTAssertEqual(apiClient.uploadBitwardenHostedCallCount, 1)
    }

    func test_upload_fileUploadType0_returnsCorrectAttachment() async throws {
        apiClient.createAttachmentMetadataResponse = AttachmentMetadataResponse(
            attachmentId: attachmentId,
            url:          "https://api.example.com/upload",
            fileUploadType: 0
        )

        let attachment = try await sut.upload(
            cipherId:  cipherId,
            fileName:  plainFileName,
            data:      plainData,
            cipherKey: cipherKey
        )

        XCTAssertEqual(attachment.id, attachmentId)
        XCTAssertEqual(attachment.fileName, plainFileName)
        // url must be nil — the v2 response URL is the signed upload URL, not a download URL
        XCTAssertNil(attachment.url,
            "url must be nil: v2 response URL is the signed upload URL, not a permanent download URL")
        XCTAssertFalse(attachment.isUploadIncomplete)
        XCTAssertEqual(attachment.size, plainData.count)
        // encryptedKey is an EncString type-2
        XCTAssertTrue(attachment.encryptedKey.hasPrefix("2."),
            "encryptedKey must be an EncString type-2 starting with '2.'")
    }

    func test_upload_fileUploadType0_patchesVaultCache() async throws {
        apiClient.createAttachmentMetadataResponse = AttachmentMetadataResponse(
            attachmentId: attachmentId,
            url:          "https://api.example.com/upload",
            fileUploadType: 0
        )

        _ = try await sut.upload(
            cipherId:  cipherId,
            fileName:  plainFileName,
            data:      plainData,
            cipherKey: cipherKey
        )

        XCTAssertEqual(vaultRepo.updateAttachmentsCallCount, 1)
        XCTAssertEqual(vaultRepo.lastUpdateAttachmentsCipherId, cipherId)
        XCTAssertEqual(vaultRepo.lastUpdatedAttachments?.count, 1)
        XCTAssertEqual(vaultRepo.lastUpdatedAttachments?.first?.id, attachmentId)
    }

    func test_upload_postsCorrectMetadataRequest() async throws {
        apiClient.createAttachmentMetadataResponse = AttachmentMetadataResponse(
            attachmentId: attachmentId,
            url:          "https://api.example.com/upload",
            fileUploadType: 0
        )

        _ = try await sut.upload(
            cipherId:  cipherId,
            fileName:  plainFileName,
            data:      plainData,
            cipherKey: cipherKey
        )

        XCTAssertEqual(apiClient.createAttachmentMetadataCallCount, 1)
        let req = try XCTUnwrap(apiClient.lastAttachmentMetadataRequest)
        // fileName in request must be an EncString (encrypted)
        XCTAssertTrue(req.fileName.hasPrefix("2."),
            "Request fileName must be an EncString type-2")
        // key must be an EncString (encrypted attachment key)
        XCTAssertTrue(req.key.hasPrefix("2."),
            "Request key must be an EncString type-2")
        XCTAssertEqual(req.adminRequest, false)
        // fileSize is the encrypted blob size, which is >= plainData.count + IV(16) + HMAC(32)
        XCTAssertGreaterThan(req.fileSize, plainData.count)
    }

    // MARK: - Upload: fileUploadType 1 (Azure)

    func test_upload_fileUploadType1_callsAzureUpload() async throws {
        let azureURL = "https://myaccount.blob.core.windows.net/container/file?sv=2021-06-08&sig=abc"
        apiClient.createAttachmentMetadataResponse = AttachmentMetadataResponse(
            attachmentId: attachmentId,
            url:          azureURL,
            fileUploadType: 1
        )

        _ = try await sut.upload(
            cipherId:  cipherId,
            fileName:  plainFileName,
            data:      plainData,
            cipherKey: cipherKey
        )

        XCTAssertEqual(apiClient.uploadAzureCallCount, 1)
        XCTAssertEqual(apiClient.uploadBitwardenHostedCallCount, 0)
        XCTAssertEqual(apiClient.lastAzureSignedURL?.absoluteString, azureURL)
    }

    func test_upload_fileUploadType1_returnsCorrectAttachment() async throws {
        apiClient.createAttachmentMetadataResponse = AttachmentMetadataResponse(
            attachmentId: attachmentId,
            url:          "https://blob.azure.com/upload-signed",
            fileUploadType: 1
        )

        let attachment = try await sut.upload(
            cipherId:  cipherId,
            fileName:  plainFileName,
            data:      plainData,
            cipherKey: cipherKey
        )

        XCTAssertEqual(attachment.id, attachmentId)
        XCTAssertNil(attachment.url,
            "url must be nil even for Azure path — upload URL ≠ download URL")
        XCTAssertFalse(attachment.isUploadIncomplete)
    }

    // MARK: - Upload: HTTP 402 → premiumRequired

    func test_upload_http402_throwsPremiumRequired() async throws {
        apiClient.createAttachmentMetadataShouldThrow = APIError.httpError(statusCode: 402, body: "")

        do {
            _ = try await sut.upload(
                cipherId:  cipherId,
                fileName:  plainFileName,
                data:      plainData,
                cipherKey: cipherKey
            )
            XCTFail("Expected AttachmentError.premiumRequired to be thrown")
        } catch AttachmentError.premiumRequired {
            // Expected
        } catch {
            XCTFail("Expected AttachmentError.premiumRequired, got \(error)")
        }
    }

    // MARK: - Download: using existing Attachment.url

    func test_download_withExistingURL_decryptsBlob() async throws {
        let attachmentKey = try crypto.generateAttachmentKey()
        let encBlob       = try crypto.encryptData(plainData, attachmentKey: attachmentKey)

        let cipherKeys    = CryptoKeys(
            encryptionKey: cipherKey[cipherKey.startIndex..<cipherKey.startIndex.advanced(by: 32)],
            macKey:        cipherKey[cipherKey.startIndex.advanced(by: 32)..<cipherKey.startIndex.advanced(by: 64)]
        )
        let encKeyString  = try crypto.encryptAttachmentKey(attachmentKey, cipherKey: cipherKeys)

        // Mock API client returns the encrypted blob
        apiClient.downloadBlobResult = encBlob

        let attachment = Attachment(
            id:                 attachmentId,
            fileName:           plainFileName,
            encryptedKey:       encKeyString,
            size:               plainData.count,
            sizeName:           "32 B",
            url:                "https://cdn.prizm-test.invalid/blob",
            isUploadIncomplete: false
        )

        let decrypted = try await sut.download(
            cipherId:   cipherId,
            attachment: attachment,
            cipherKey:  cipherKey
        )

        XCTAssertEqual(decrypted, plainData)
        XCTAssertEqual(apiClient.downloadBlobCallCount, 1)
    }

    func test_download_withNilURL_fetchesFreshURLThenDecrypts() async throws {
        let attachmentKey = try crypto.generateAttachmentKey()
        let encBlob       = try crypto.encryptData(plainData, attachmentKey: attachmentKey)

        let cipherKeys = CryptoKeys(
            encryptionKey: cipherKey[cipherKey.startIndex..<cipherKey.startIndex.advanced(by: 32)],
            macKey:        cipherKey[cipherKey.startIndex.advanced(by: 32)..<cipherKey.startIndex.advanced(by: 64)]
        )
        let encKeyString = try crypto.encryptAttachmentKey(attachmentKey, cipherKey: cipherKeys)

        apiClient.downloadBlobResult = encBlob
        apiClient.fetchAttachmentDownloadURLResponse = AttachmentDownloadResponse(
            url: "https://cdn.prizm-test.invalid/fresh-blob"
        )

        let attachment = Attachment(
            id:                 attachmentId,
            fileName:           plainFileName,
            encryptedKey:       encKeyString,
            size:               plainData.count,
            sizeName:           "32 B",
            url:                nil,    // forces fresh-URL fetch
            isUploadIncomplete: false
        )

        let decrypted = try await sut.download(
            cipherId:   cipherId,
            attachment: attachment,
            cipherKey:  cipherKey
        )

        XCTAssertEqual(decrypted, plainData)
        XCTAssertEqual(apiClient.fetchAttachmentDownloadURLCallCount, 1)
    }

    func test_download_403_refetchesURLAndRetries() async throws {
        let attachmentKey = try crypto.generateAttachmentKey()
        let encBlob       = try crypto.encryptData(plainData, attachmentKey: attachmentKey)

        let cipherKeys = CryptoKeys(
            encryptionKey: cipherKey[cipherKey.startIndex..<cipherKey.startIndex.advanced(by: 32)],
            macKey:        cipherKey[cipherKey.startIndex.advanced(by: 32)..<cipherKey.startIndex.advanced(by: 64)]
        )
        let encKeyString = try crypto.encryptAttachmentKey(attachmentKey, cipherKey: cipherKeys)

        // First call returns 403 (stale URL); second call returns the blob (fresh URL).
        apiClient.downloadBlobSequence = [
            1: .failure(APIError.httpError(statusCode: 403, body: "")),
            2: .success(encBlob)
        ]
        apiClient.fetchAttachmentDownloadURLResponse = AttachmentDownloadResponse(
            url: "https://cdn.prizm-test.invalid/fresh-after-retry"
        )

        let attachment = Attachment(
            id:                 attachmentId,
            fileName:           plainFileName,
            encryptedKey:       encKeyString,
            size:               plainData.count,
            sizeName:           "32 B",
            url:                "https://cdn.prizm-test.invalid/stale",
            isUploadIncomplete: false
        )

        let decrypted = try await sut.download(
            cipherId:   cipherId,
            attachment: attachment,
            cipherKey:  cipherKey
        )

        XCTAssertEqual(decrypted, plainData)
        XCTAssertEqual(apiClient.fetchAttachmentDownloadURLCallCount, 1)
        XCTAssertEqual(apiClient.downloadBlobCallCount, 2)
    }

    // MARK: - Delete

    func test_delete_callsAPIAndPatchesCache() async throws {
        // Seed an existing attachment so the filter operation has something to remove
        let existing = Attachment(
            id:                 attachmentId,
            fileName:           "old.pdf",
            encryptedKey:       "2.abc|def|ghi",
            size:               1024,
            sizeName:           "1 KB",
            url:                "https://cdn.example.com/file",
            isUploadIncomplete: false
        )
        vaultRepo.populate(items: [VaultItem(
            id:           cipherId,
            name:         "Test Item",
            isFavorite:   false,
            isDeleted:    false,
            creationDate: Date(),
            revisionDate: Date(),
            content:      .secureNote(SecureNoteContent(notes: nil, customFields: [])),
            attachments:  [existing]
        )], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.delete(cipherId: cipherId, attachmentId: attachmentId)

        XCTAssertEqual(apiClient.deleteAttachmentCallCount, 1)
        XCTAssertEqual(apiClient.lastDeletedAttachmentId, attachmentId)

        XCTAssertEqual(vaultRepo.updateAttachmentsCallCount, 1)
        XCTAssertEqual(vaultRepo.lastUpdateAttachmentsCipherId, cipherId)
        // Attachment must be removed from the patched list
        XCTAssertEqual(vaultRepo.lastUpdatedAttachments?.count, 0)
    }

    func test_delete_preservesOtherAttachmentsInCache() async throws {
        let keep = Attachment(
            id:                 "att-keep",
            fileName:           "keep.pdf",
            encryptedKey:       "2.k|k|k",
            size:               512,
            sizeName:           "512 B",
            url:                "https://cdn.example.com/keep",
            isUploadIncomplete: false
        )
        let toDelete = Attachment(
            id:                 attachmentId,
            fileName:           "delete.pdf",
            encryptedKey:       "2.d|d|d",
            size:               256,
            sizeName:           "256 B",
            url:                "https://cdn.example.com/delete",
            isUploadIncomplete: false
        )
        vaultRepo.populate(items: [VaultItem(
            id:           cipherId,
            name:         "Test Item",
            isFavorite:   false,
            isDeleted:    false,
            creationDate: Date(),
            revisionDate: Date(),
            content:      .secureNote(SecureNoteContent(notes: nil, customFields: [])),
            attachments:  [keep, toDelete]
        )], folders: [], organizations: [], collections: [], syncedAt: Date())

        try await sut.delete(cipherId: cipherId, attachmentId: attachmentId)

        let remaining = try XCTUnwrap(vaultRepo.lastUpdatedAttachments)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, "att-keep")
    }
}
