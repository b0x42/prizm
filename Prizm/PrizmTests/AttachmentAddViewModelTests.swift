import XCTest
@testable import Prizm

/// Unit tests for `AttachmentAddViewModel` (task 6.5).
///
/// All tests bypass `NSOpenPanel` by injecting a `filePicker` closure that returns
/// pre-canned (url, bytes) pairs. This keeps the suite runnable in CI (no interactive session).
@MainActor
final class AttachmentAddViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// A temporary file written to disk so `Data(contentsOf:)` inside `confirm()` succeeds.
    private var tempFileURL: URL!
    private let fileContent = Data("test attachment content".utf8)

    override func setUp() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prizm-test-\(UUID().uuidString).txt")
        try fileContent.write(to: url)
        tempFileURL = url
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempFileURL)
    }

    private func makeViewModel(
        uploadResult: Result<Attachment, Error> = .success(
            Attachment(id: "att-1", fileName: "doc.txt", encryptedKey: "2.a|b|c",
                       size: 22, sizeName: "22 B", url: nil, isUploadIncomplete: false)
        ),
        pickerResult: (url: URL, bytes: Int)?
    ) -> AttachmentAddViewModel {
        AttachmentAddViewModel(
            cipherId:     "cipher-1",
            uploadUseCase: MockUploadUseCase(result: uploadResult),
            filePicker:    { pickerResult }
        )
    }

    // MARK: - 500 MB rejection

    func test_selectFile_over500MB_setSizeError() async {
        let overLimit = 501 * 1024 * 1024
        let sut = makeViewModel(pickerResult: (url: tempFileURL, bytes: overLimit))

        await sut.selectFile()

        XCTAssertNotNil(sut.sizeError)
        XCTAssertFalse(sut.isConfirming)
        XCTAssertNil(sut.selectedFileURL)
    }

    func test_selectFile_exactly500MB_isAllowed() async {
        let exactly500MB = 500 * 1024 * 1024
        let sut = makeViewModel(pickerResult: (url: tempFileURL, bytes: exactly500MB))

        await sut.selectFile()

        XCTAssertNil(sut.sizeError)
        XCTAssertTrue(sut.isConfirming)
    }

    // MARK: - Advisory message (50 MB – 500 MB)

    func test_selectFile_between50MBAnd500MB_showsAdvisory() async {
        let advisorySize = 75 * 1024 * 1024
        let sut = makeViewModel(pickerResult: (url: tempFileURL, bytes: advisorySize))

        await sut.selectFile()

        XCTAssertNotNil(sut.sizeAdvisory,
            "Advisory message should appear for files between 50 MB and 500 MB")
        XCTAssertTrue(sut.isConfirming)
        XCTAssertNil(sut.sizeError)
    }

    func test_selectFile_under50MB_noAdvisory() async {
        let smallSize = 10 * 1024
        let sut = makeViewModel(pickerResult: (url: tempFileURL, bytes: smallSize))

        await sut.selectFile()

        XCTAssertNil(sut.sizeAdvisory)
        XCTAssertTrue(sut.isConfirming)
    }

    // MARK: - Successful upload

    func test_confirm_successfulUpload_setsDismissed() async throws {
        let sut = makeViewModel(pickerResult: (url: tempFileURL, bytes: 22))
        await sut.selectFile()
        XCTAssertTrue(sut.isConfirming)

        sut.confirm()

        // Wait for the upload Task to complete
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(sut.isDismissed)
        XCTAssertFalse(sut.isUploading)
        XCTAssertNil(sut.uploadError)
    }

    func test_confirm_uploading_setsIsUploading() async throws {
        let sut = makeViewModel(
            uploadResult: .success(
                Attachment(id: "att-1", fileName: "doc.txt", encryptedKey: "2.a|b|c",
                           size: 22, sizeName: "22 B", url: nil, isUploadIncomplete: false)
            ),
            pickerResult: (url: tempFileURL, bytes: 22)
        )
        await sut.selectFile()
        sut.confirm()
        XCTAssertTrue(sut.isUploading)
    }

    // MARK: - Premium error (HTTP 402)

    func test_confirm_premiumRequired_setsUploadError() async throws {
        let sut = makeViewModel(
            uploadResult: .failure(AttachmentError.premiumRequired),
            pickerResult: (url: tempFileURL, bytes: 22)
        )
        await sut.selectFile()
        sut.confirm()

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertNotNil(sut.uploadError)
        XCTAssertFalse(sut.isDismissed)
        XCTAssertTrue(sut.uploadError?.contains("premium") ?? false,
            "Error message should mention premium subscription")
    }

    // MARK: - Cancel during upload

    func test_cancel_setsIsDismissed() async {
        let sut = makeViewModel(pickerResult: (url: tempFileURL, bytes: 22))
        await sut.selectFile()

        sut.cancel()

        XCTAssertTrue(sut.isDismissed)
        XCTAssertFalse(sut.isUploading)
    }

    func test_cancel_duringUpload_cancelsTask() async throws {
        // Use a slow upload to ensure cancel fires while the task is in-flight
        let slowUpload = SlowMockUploadUseCase()
        let sut = AttachmentAddViewModel(
            cipherId:      "cipher-1",
            uploadUseCase: slowUpload,
            filePicker:    { (url: self.tempFileURL, bytes: 22) }
        )
        await sut.selectFile()
        sut.confirm()
        XCTAssertTrue(sut.isUploading)

        sut.cancel()

        XCTAssertTrue(sut.isDismissed)
    }

    // MARK: - Picker cancelled

    func test_selectFile_pickerCancelled_noStateChange() async {
        let sut = makeViewModel(pickerResult: nil)

        await sut.selectFile()

        XCTAssertFalse(sut.isConfirming)
        XCTAssertNil(sut.selectedFileURL)
        XCTAssertNil(sut.sizeError)
    }

    // MARK: - isPickingFile (task 8b.6)

    func test_isPickingFile_trueWhilePickerIsRunning() async {
        var capturedDuringPick = false
        // The filePicker closure runs synchronously inside selectFile() while
        // isPickingFile is true — capture the value mid-call.
        let sut = AttachmentAddViewModel(
            cipherId:      "cipher-1",
            uploadUseCase: MockUploadUseCase(result: .success(
                Attachment(id: "att-1", fileName: "doc.txt", encryptedKey: "2.a|b|c",
                           size: 22, sizeName: "22 B", url: nil, isUploadIncomplete: false)
            )),
            filePicker: { [weak sut] in
                capturedDuringPick = sut?.isPickingFile ?? false
                return (url: self.tempFileURL, bytes: 22)
            }
        )

        await sut.selectFile()

        XCTAssertTrue(capturedDuringPick, "isPickingFile must be true while the picker is running")
        XCTAssertFalse(sut.isPickingFile, "isPickingFile must be false after picker returns")
    }

    func test_isPickingFile_falseAfterCancel() async {
        var capturedDuringPick = false
        let sut = AttachmentAddViewModel(
            cipherId:      "cipher-1",
            uploadUseCase: MockUploadUseCase(result: .success(
                Attachment(id: "att-1", fileName: "doc.txt", encryptedKey: "2.a|b|c",
                           size: 22, sizeName: "22 B", url: nil, isUploadIncomplete: false)
            )),
            filePicker: { [weak sut] in
                capturedDuringPick = sut?.isPickingFile ?? false
                return nil  // simulate user cancelling NSOpenPanel
            }
        )

        await sut.selectFile()

        XCTAssertTrue(capturedDuringPick, "isPickingFile must be true while the picker is running")
        XCTAssertFalse(sut.isPickingFile, "isPickingFile must be false after cancel")
        XCTAssertFalse(sut.isConfirming)
    }
}

// MARK: - Test doubles

private final class MockUploadUseCase: UploadAttachmentUseCase {
    let result: Result<Attachment, Error>

    init(result: Result<Attachment, Error>) {
        self.result = result
    }

    func execute(cipherId: String, fileName: String, data: Data) async throws -> Attachment {
        try result.get()
    }
}

/// A mock that never resolves — used to test cancellation.
private final class SlowMockUploadUseCase: UploadAttachmentUseCase {
    func execute(cipherId: String, fileName: String, data: Data) async throws -> Attachment {
        // Sleep for 60 seconds — effectively infinite from a test's perspective.
        // The test cancels the Task before this ever completes.
        try await Task.sleep(for: .seconds(60))
        throw CancellationError()
    }
}
