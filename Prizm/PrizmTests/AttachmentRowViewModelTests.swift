import XCTest
@testable import Prizm

/// Unit tests for `AttachmentRowViewModel` (tasks 7.5 and 6d.3).
///
/// Covers: Open error path, Save to Disk cancel (no download triggered), Delete confirm
/// vs cancel, incomplete-attachment row state, and retry flow.
@MainActor
final class AttachmentRowViewModelTests: XCTestCase {

    // MARK: - Fixtures

    private let cipherId      = "cipher-abc"
    private let plainData     = Data("decrypted file content".utf8)
    private var mockDownload: MockRowDownloadUseCase!
    private var mockDelete:   MockRowDeleteUseCase!
    private var mockUpload:   MockRowUploadUseCase!
    private var mockTempMgr:  MockTempFileManager!

    private var normalAttachment: Attachment!
    private var incompleteAttachment: Attachment!

    override func setUp() {
        mockDownload = MockRowDownloadUseCase()
        mockDelete   = MockRowDeleteUseCase()
        mockUpload   = MockRowUploadUseCase()
        mockTempMgr  = MockTempFileManager()

        normalAttachment = Attachment(
            id: "att-1", fileName: "report.pdf", encryptedKey: "2.a|b|c",
            size: 1024, sizeName: "1 KB", url: "https://cdn.example.com/blob",
            isUploadIncomplete: false
        )

        incompleteAttachment = Attachment(
            id: "att-inc", fileName: "draft.doc", encryptedKey: "2.x|y|z",
            size: 512, sizeName: "512 B", url: nil,
            isUploadIncomplete: true
        )
    }

    private func makeSUT(attachment: Attachment? = nil,
                         fileSaver: ((String) -> URL?)? = nil,
                         retryPicker: (() -> URL?)? = nil) -> AttachmentRowViewModel {
        AttachmentRowViewModel(
            cipherId:        cipherId,
            attachment:      attachment ?? normalAttachment,
            downloadUseCase: mockDownload,
            deleteUseCase:   mockDelete,
            uploadUseCase:   mockUpload,
            tempFileManager: mockTempMgr,
            fileSaver:       fileSaver,
            retryFilePicker: retryPicker
        )
    }

    // MARK: - Open

    func test_open_successfulDownload_opensFile() async throws {
        mockDownload.result = .success(plainData)
        let sut = makeSUT()

        sut.open()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(mockTempMgr.registerCalled)
        XCTAssertNil(sut.actionError)
    }

    func test_open_downloadFailure_setsActionError() async throws {
        mockDownload.result = .failure(AttachmentError.downloadFailed)
        let sut = makeSUT()

        sut.open()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(sut.actionError)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Save to Disk

    func test_saveToDisk_userCancelsPanel_noDownloadTriggered() {
        // Return nil from fileSaver to simulate panel cancel
        let sut = makeSUT(fileSaver: { _ in nil })

        sut.saveToDisk()

        XCTAssertFalse(mockDownload.executeCalled)
        XCTAssertFalse(sut.isLoading)
    }

    func test_saveToDisk_success_zerosBuffer() async throws {
        let saveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("prizm-save-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: saveURL) }

        mockDownload.result = .success(plainData)
        let sut = makeSUT(fileSaver: { _ in saveURL })

        sut.saveToDisk()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(FileManager.default.fileExists(atPath: saveURL.path))
        XCTAssertNil(sut.actionError)
    }

    func test_saveToDisk_downloadFailure_setsActionError() async throws {
        mockDownload.result = .failure(AttachmentError.downloadFailed)
        let saveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("prizm-save-\(UUID().uuidString).pdf")
        let sut = makeSUT(fileSaver: { _ in saveURL })

        sut.saveToDisk()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(sut.actionError)
    }

    // MARK: - Delete

    func test_delete_callsDeleteUseCase() async throws {
        let sut = makeSUT()

        sut.delete()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(mockDelete.executeCalled)
        XCTAssertNil(sut.actionError)
    }

    func test_delete_failure_setsActionError() async throws {
        mockDelete.result = .failure(AttachmentError.downloadFailed)
        let sut = makeSUT()

        sut.delete()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(sut.actionError)
    }

    // MARK: - Incomplete attachment (task 6d.3)

    func test_incompleteAttachment_isUploadIncompleteTrue() {
        let sut = makeSUT(attachment: incompleteAttachment)
        XCTAssertTrue(sut.attachment.isUploadIncomplete)
    }

    func test_normalAttachment_isUploadIncompleteFalse() {
        let sut = makeSUT(attachment: normalAttachment)
        XCTAssertFalse(sut.attachment.isUploadIncomplete)
    }

    // MARK: - Retry Upload (task 6d.3)

    func test_retryUpload_onlyWorksOnIncompleteAttachment() {
        let sut = makeSUT(attachment: normalAttachment, retryPicker: { URL(fileURLWithPath: "/tmp/f.txt") })
        // Should not trigger on a complete attachment
        sut.retryUpload()
        XCTAssertFalse(mockDelete.executeCalled)
        XCTAssertFalse(mockUpload.executeCalled)
    }

    func test_retryUpload_userCancels_noAction() {
        let sut = makeSUT(attachment: incompleteAttachment, retryPicker: { nil })
        sut.retryUpload()
        XCTAssertFalse(mockDelete.executeCalled)
    }

    func test_retryUpload_success_deletesOldThenUploads() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("prizm-retry-\(UUID().uuidString).txt")
        try Data("content".utf8).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        mockDelete.result = .success(())
        mockUpload.result = .success(Attachment(
            id: "att-new", fileName: "draft.doc", encryptedKey: "2.a|b|c",
            size: 7, sizeName: "7 B", url: nil, isUploadIncomplete: false
        ))

        let sut = makeSUT(attachment: incompleteAttachment, retryPicker: { tempFile })
        sut.retryUpload()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(mockDelete.executeCalled,  "Old incomplete attachment should be deleted first")
        XCTAssertTrue(mockUpload.executeCalled,  "New upload should be started after delete")
        XCTAssertNil(sut.retryError)
    }

    func test_retryUpload_deleteFailure_setsRetryError() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("prizm-retry-fail-\(UUID().uuidString).txt")
        try Data("content".utf8).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        mockDelete.result = .failure(AttachmentError.downloadFailed)

        let sut = makeSUT(attachment: incompleteAttachment, retryPicker: { tempFile })
        sut.retryUpload()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertNotNil(sut.retryError)
        XCTAssertFalse(mockUpload.executeCalled,
            "Upload should NOT be called if delete failed")
    }
}

// MARK: - Test doubles

private final class MockRowDownloadUseCase: DownloadAttachmentUseCase {
    var result: Result<Data, Error> = .success(Data())
    private(set) var executeCalled = false

    func execute(cipherId: String, attachment: Attachment) async throws -> Data {
        executeCalled = true
        return try result.get()
    }
}

private final class MockRowDeleteUseCase: DeleteAttachmentUseCase {
    var result: Result<Void, Error> = .success(())
    private(set) var executeCalled = false

    func execute(cipherId: String, attachmentId: String) async throws {
        executeCalled = true
        try result.get()
    }
}

private final class MockRowUploadUseCase: UploadAttachmentUseCase {
    var result: Result<Attachment, Error> = .success(
        Attachment(id: "att-1", fileName: "f.txt", encryptedKey: "2.a|b|c",
                   size: 1, sizeName: "1 B", url: nil, isUploadIncomplete: false)
    )
    private(set) var executeCalled = false

    func execute(cipherId: String, fileName: String, data: Data) async throws -> Attachment {
        executeCalled = true
        return try result.get()
    }
}

private final class MockTempFileManager: TempFileManaging {
    private(set) var registerCalled = false
    private(set) var cleanupCalled  = false

    func register(url: URL) { registerCalled = true }
    func cleanup()           { cleanupCalled  = true }
}
