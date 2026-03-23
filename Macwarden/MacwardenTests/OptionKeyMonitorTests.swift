import XCTest
@testable import Macwarden

final class OptionKeyMonitorTests: XCTestCase {

    func testInitialState_isOptionHeldIsFalse() {
        let monitor = OptionKeyMonitor()
        XCTAssertFalse(monitor.isOptionHeld)
    }
}
