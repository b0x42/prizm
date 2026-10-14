import XCTest
@testable import Prizm

@MainActor
final class SidebarSelectionTests: XCTestCase {

    private let others: [SidebarSelection] = [
        .allItems, .favorites, .type(.login), .folder("f"), .trash, .newFolder,
        .organization("o"), .collection("c"), .newCollection(organizationId: "o"),
    ]

    func test_verificationCodes_equalsOnlyItself() {
        XCTAssertEqual(SidebarSelection.verificationCodes, .verificationCodes)
        for other in others {
            XCTAssertNotEqual(SidebarSelection.verificationCodes, other)
        }
    }

    func test_verificationCodes_hashesDistinctlyFromEveryOtherCase() {
        let hashes = Set((others + [.verificationCodes]).map(\.hashValue))
        XCTAssertEqual(hashes.count, others.count + 1)
    }

    func test_verificationCodes_displayName() {
        XCTAssertEqual(SidebarSelection.verificationCodes.displayName, "Codes")
    }
}
