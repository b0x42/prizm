import XCTest
@testable import Macwarden

final class GetLastSyncDateUseCaseTests: XCTestCase {

    // MARK: - 1. Returns nil when repository has no stored timestamp

    func testExecute_returnsNil_whenNoTimestampStored() {
        let repo = MockSyncTimestampRepository(storedDate: nil)
        let sut  = GetLastSyncDateUseCaseImpl(repository: repo)

        XCTAssertNil(sut.execute())
    }

    // MARK: - 2. Returns stored date when one exists

    func testExecute_returnsStoredDate() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let repo = MockSyncTimestampRepository(storedDate: date)
        let sut  = GetLastSyncDateUseCaseImpl(repository: repo)

        XCTAssertEqual(sut.execute(), date)
    }

    // MARK: - 3. Future date is passed through (clamping is a Presentation concern)

    func testExecute_passesThroughFutureDate() {
        let future = Date(timeIntervalSinceNow: 3600)
        let repo   = MockSyncTimestampRepository(storedDate: future)
        let sut    = GetLastSyncDateUseCaseImpl(repository: repo)

        XCTAssertEqual(sut.execute(), future)
    }
}
