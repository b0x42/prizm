import AppKit
import XCTest
@testable import Prizm

/// Copied secrets are flagged so clipboard managers that honor the nspasteboard.org
/// convention do not record them in their history.
@MainActor
final class ConcealedPasteboardTests: XCTestCase {

    private var pasteboard: NSPasteboard!

    override func setUp() async throws {
        try await super.setUp()
        // A private, uniquely named pasteboard keeps tests off the user's real clipboard.
        pasteboard = NSPasteboard(name: NSPasteboard.Name("com.prizm.tests.\(UUID().uuidString)"))
    }

    override func tearDown() async throws {
        pasteboard.releaseGlobally()
        try await super.tearDown()
    }

    func test_write_setsTheStringValue() {
        VaultBrowserViewModel.writeConcealed("123456", to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "123456")
    }

    func test_write_marksTheItemAsConcealed() {
        VaultBrowserViewModel.writeConcealed("123456", to: pasteboard)
        XCTAssertTrue(pasteboard.types?.contains(VaultBrowserViewModel.concealedType) == true)
    }

    func test_write_replacesPreviousContents() {
        pasteboard.setString("old", forType: .string)
        VaultBrowserViewModel.writeConcealed("new", to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "new")
    }
}
