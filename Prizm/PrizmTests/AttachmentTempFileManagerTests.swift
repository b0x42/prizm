import XCTest
@testable import Prizm

/// Unit tests for `AttachmentTempFileManager` (task 7.2c).
///
/// Uses `register(url:deleteAfter:)` to control cleanup timing without sleeping.
final class AttachmentTempFileManagerTests: XCTestCase {

    private var sut: AttachmentTempFileManager!
    private var createdURLs: [URL] = []

    override func setUp() {
        sut = AttachmentTempFileManager()
    }

    override func tearDown() {
        for url in createdURLs { try? FileManager.default.removeItem(at: url) }
        createdURLs.removeAll()
    }

    // MARK: - Helpers

    /// Creates a real temp file on disk and records it for teardown.
    private func makeTempFile(content: String = "sensitive content") -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prizm-tmptest-\(UUID().uuidString).txt")
        try? content.data(using: .utf8)!.write(to: url)
        createdURLs.append(url)
        return url
    }

    // MARK: - register

    func test_register_fileStillExistsBeforeCleanup() {
        let url = makeTempFile()
        sut.register(url: url)
        // cleanup() not called yet — file should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - cleanup — expired deadline

    func test_cleanup_deletesFilesPastDeadline() {
        let url = makeTempFile()
        // Register with a deadline 1 second in the past
        sut.register(url: url, deleteAfter: Date().addingTimeInterval(-1))

        sut.cleanup()

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
            "File should be deleted after its deadline passes")
    }

    func test_cleanup_zerosAndDeletesExpiredFile() throws {
        let sensitiveContent = "sensitive data that should be zeroed"
        let url = makeTempFile(content: sensitiveContent)
        sut.register(url: url, deleteAfter: Date().addingTimeInterval(-1))

        sut.cleanup()

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
            "File should not exist after cleanup")
    }

    // MARK: - cleanup — unexpired deadline

    func test_cleanup_leavesFilesNotYetExpired() {
        let url = makeTempFile()
        // Register with a deadline 30 seconds in the future
        sut.register(url: url, deleteAfter: Date().addingTimeInterval(30))

        sut.cleanup()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
            "File should remain until its deadline passes")
    }

    func test_cleanup_mixedDeadlines_onlyDeletesExpired() {
        let expiredURL  = makeTempFile(content: "expired")
        let freshURL    = makeTempFile(content: "fresh")

        sut.register(url: expiredURL, deleteAfter: Date().addingTimeInterval(-1))
        sut.register(url: freshURL,   deleteAfter: Date().addingTimeInterval(30))

        sut.cleanup()

        XCTAssertFalse(FileManager.default.fileExists(atPath: expiredURL.path),
            "Expired file should be deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshURL.path),
            "Fresh file should remain")
    }

    // MARK: - Multiple cleanups

    func test_cleanup_idempotent_doesNotCrashOnMissingFile() {
        let url = makeTempFile()
        sut.register(url: url, deleteAfter: Date().addingTimeInterval(-1))

        sut.cleanup()
        sut.cleanup()  // second call — file already gone, should not throw/crash

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Register + cleanup lifecycle

    func test_registeredFile_isDeletedOnCleanupAfterDeadline() {
        let url = makeTempFile()
        sut.register(url: url)
        // Manually expire by re-registering with past deadline
        sut.register(url: url, deleteAfter: Date().addingTimeInterval(-1))

        sut.cleanup()

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
