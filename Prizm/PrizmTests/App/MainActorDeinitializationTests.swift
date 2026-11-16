import XCTest
@testable import Prizm

@MainActor
final class MainActorDeinitializationTests: XCTestCase {

    private enum Context {
        @TaskLocal static var active = false
    }

    /// A synchronous task-local scope reproduces Swift's isolated-deinit runtime crash
    /// on macOS 15. Keep this synchronous: making the test async hides the failure.
    func testReleaseAppGraphAndAttachmentModels_insideSynchronousTaskLocal() {
        weak var releasedContainer: AppContainer?
        weak var releasedAdd: AttachmentAddViewModel?
        weak var releasedBatch: AttachmentBatchViewModel?
        weak var releasedRow: AttachmentRowViewModel?

        Context.$active.withValue(true) {
            autoreleasepool {
                let container = AppContainer()
                releasedContainer = container

                let attachment = Attachment(
                    id: "deinit-test", fileName: "test.txt", encryptedKey: "",
                    size: 0, sizeName: "0 B", url: nil, isUploadIncomplete: false
                )
                let add = container.makeAddAttachmentViewModel(for: "deinit-test")
                let batch = container.makeBatchAttachmentViewModel(for: "deinit-test")
                let row = container.makeAttachmentRowViewModel(
                    cipherId: "deinit-test", attachment: attachment
                )
                releasedAdd = add
                releasedBatch = batch
                releasedRow = row
                XCTAssertFalse(add.isUploading)
                XCTAssertFalse(batch.isUploading)
                XCTAssertFalse(row.isLoading)
            }
        }

        XCTAssertNil(releasedContainer)
        XCTAssertNil(releasedAdd)
        XCTAssertNil(releasedBatch)
        XCTAssertNil(releasedRow)
    }
}
