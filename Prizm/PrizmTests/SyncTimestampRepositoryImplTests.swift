import XCTest
@testable import Prizm

@MainActor
final class SyncTimestampRepositoryImplTests: XCTestCase {

    // Use an isolated UserDefaults suite so tests don't pollute the real defaults.
    private var defaults: UserDefaults!
    private let email = "alice@example.com"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: "SyncTimestampRepositoryImplTests")!
        // Clean slate before each test.
        defaults.removePersistentDomain(forName: "SyncTimestampRepositoryImplTests")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "SyncTimestampRepositoryImplTests")
        defaults = nil
        try await super.tearDown()
    }

    private func makeSUT(email: String = "alice@example.com") -> SyncTimestampRepositoryImpl {
        SyncTimestampRepositoryImpl(email: email, defaults: defaults)
    }

    // MARK: - 1. Nil before first write

    func testLastSyncDate_isNil_beforeFirstSync() {
        let sut = makeSUT()
        XCTAssertNil(sut.lastSyncDate)
    }

    // MARK: - 2. Read-back after write

    func testLastSyncDate_returnsSavedDate_afterRecord() throws {
        let sut = makeSUT()
        let before = Date()
        sut.recordSuccessfulSync()

        let result = try XCTUnwrap(sut.lastSyncDate)
        // ISO-8601 round-trip truncates to milliseconds, so sub-millisecond precision in
        // `before` can make the parsed result appear fractionally earlier. Use 1-second
        // accuracy instead of strict >= / <= to absorb that truncation.
        XCTAssertEqual(result.timeIntervalSince1970, before.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - 3. Persists across new instance (simulates app restart)

    func testLastSyncDate_persistsAcrossNewInstance() {
        let sut1 = makeSUT()
        sut1.recordSuccessfulSync()
        let saved = sut1.lastSyncDate

        let sut2 = makeSUT()
        XCTAssertEqual(
            sut2.lastSyncDate?.timeIntervalSinceReferenceDate ?? 0,
            saved?.timeIntervalSinceReferenceDate ?? -1,
            accuracy: 1.0
        )
    }

    // MARK: - 4. Isolation between different account emails

    func testLastSyncDate_isIsolatedByEmail() {
        let sut1 = makeSUT(email: "alice@example.com")
        let sut2 = makeSUT(email: "bob@example.com")

        sut1.recordSuccessfulSync()

        XCTAssertNotNil(sut1.lastSyncDate)
        XCTAssertNil(sut2.lastSyncDate, "bob's timestamp should not be affected by alice's sync")
    }
}
