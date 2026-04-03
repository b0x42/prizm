import XCTest
@testable import Macwarden

// @MainActor required: GetLastSyncDateUseCaseImpl is inferred @MainActor in the
// test module because other test classes store MockSyncTimestampRepository as a
// concrete @MainActor property, propagating actor isolation to types that use it.
// Async test methods let XCTest dispatch correctly via Swift's concurrency runtime.
@MainActor
final class GetLastSyncDateUseCaseTests: XCTestCase {

    // MARK: - 1. Returns nil when repository has no stored timestamp

    func testExecute_returnsNil_whenNoTimestampStored() async {
        let repo = MockSyncTimestampRepository(storedDate: nil)
        let sut  = GetLastSyncDateUseCaseImpl(repository: repo)

        XCTAssertNil(sut.execute())
    }

    // MARK: - 2. Returns stored date when one exists

    func testExecute_returnsStoredDate() async {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let repo = MockSyncTimestampRepository(storedDate: date)
        let sut  = GetLastSyncDateUseCaseImpl(repository: repo)

        XCTAssertEqual(sut.execute(), date)
    }

    // MARK: - 3. Future date is passed through (clamping is a Presentation concern)

    func testExecute_passesThroughFutureDate() async {
        let future = Date(timeIntervalSinceNow: 3600)
        let repo   = MockSyncTimestampRepository(storedDate: future)
        let sut    = GetLastSyncDateUseCaseImpl(repository: repo)

        XCTAssertEqual(sut.execute(), future)
    }
}
