import XCTest
@testable import Prizm

@MainActor
final class OptionKeyMonitorTests: XCTestCase {

    func testInitialState_isOptionHeldIsFalse() {
        let monitor = OptionKeyMonitor()
        XCTAssertFalse(monitor.isOptionHeld)
    }
}
