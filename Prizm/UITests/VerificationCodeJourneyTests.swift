import AppKit
import XCTest

/// XCUITest: TOTP verification codes (specs/001-totp-verification-codes).
///
/// Launches the app with `--ui-test-vault`, a DEBUG-only seam (`UITestFixtures`) that shows a
/// seeded in-memory vault without a server:
/// - alpha  "Alpha Bank"     plain base32 seed
/// - beta   "Beta Mail"      otpauth link, SHA-256, 8 digits, 60 s
/// - gamma  "Gamma No Seed"  no seed
/// - delta  "Delta Bad Seed" unusable seed
/// - zeta   "Zeta Trashed"   seed, but in the trash
///
/// Run with: `xcodebuild test -scheme Prizm -destination 'platform=macOS' -only-testing:PrizmUITests`.
/// The target is skipped in the scheme by default so a plain "run all tests" stays fast.
final class VerificationCodeJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-test-vault"]
        app.launch()
        XCTAssertTrue(element("itemList.row.alpha").waitForExistence(timeout: 20), "Seeded vault must appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openItem(_ id: String) {
        let row = element("itemList.row.\(id)")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Row \(id) should exist")
        row.click()
    }

    private func openVerificationCodes() {
        // Sidebar rows carry no accessibility identifiers, so match the row by its label.
        let row = app.outlines["Sidebar"].staticTexts["Verification Codes"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Verification Codes sidebar row should exist")
        row.click()
    }

    /// The code element speaks "1 2 3 4 5 6, 20 seconds remaining" (digits individually).
    private let spokenValue = #"^(\d ){5,7}\d, \d+ seconds remaining$"#

    // MARK: - US1: one item

    func testDetailPane_showsVerificationCode_forItemWithSeed() {
        openItem("alpha")
        let code = element("verificationCodes.code.alpha")
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        let value = code.value as? String ?? ""
        XCTAssertNotNil(value.range(of: spokenValue, options: .regularExpression), "Unexpected value: \(value)")
        XCTAssertTrue(element("verificationCodes.copy.alpha").exists)
    }

    func testDetailPane_showsNoCode_forItemWithoutSeed() {
        openItem("gamma")
        XCTAssertFalse(element("verificationCodes.code.gamma").waitForExistence(timeout: 2))
    }

    func testCopyButton_putsSixDigitCodeOnClipboard() {
        openItem("alpha")
        let copy = element("verificationCodes.copy.alpha")
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        copy.click()
        let pasted = NSPasteboard.general.string(forType: .string) ?? ""
        XCTAssertNotNil(pasted.range(of: #"^\d{6}$"#, options: .regularExpression), "Clipboard: \(pasted)")
    }

    // MARK: - US2: the list

    func testList_showsOnlyNonTrashedItemsWithSeeds_alphabetically() {
        openVerificationCodes()
        let alpha = element("verificationCodes.row.alpha")
        let beta = element("verificationCodes.row.beta")
        let delta = element("verificationCodes.row.delta")
        XCTAssertTrue(alpha.waitForExistence(timeout: 10))
        XCTAssertTrue(beta.exists)
        XCTAssertTrue(delta.exists)
        XCTAssertFalse(element("verificationCodes.row.gamma").exists, "No seed: not listed")
        XCTAssertFalse(element("verificationCodes.row.zeta").exists, "Trashed: not listed")
        XCTAssertLessThan(alpha.frame.minY, beta.frame.minY)
        XCTAssertLessThan(beta.frame.minY, delta.frame.minY)
    }

    func testList_unusableSeed_showsUnavailable_andNoCopyButton() {
        openVerificationCodes()
        let code = element("verificationCodes.code.delta")
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        XCTAssertTrue(code.label.contains("unavailable"), "Label: \(code.label)")
        XCTAssertFalse(element("verificationCodes.copy.delta").exists)
    }

    func testList_search_filtersRows() {
        openVerificationCodes()
        XCTAssertTrue(element("verificationCodes.row.alpha").waitForExistence(timeout: 10))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("Beta")
        XCTAssertTrue(element("verificationCodes.row.beta").waitForExistence(timeout: 5))
        XCTAssertFalse(element("verificationCodes.row.alpha").waitForExistence(timeout: 2))
    }

    func testList_selectingRow_opensItemInDetailPane() {
        openVerificationCodes()
        let row = element("verificationCodes.row.alpha")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.click()
        XCTAssertTrue(app.staticTexts["Alpha Bank"].waitForExistence(timeout: 5))
    }

    func testList_copyButton_putsCodeOnClipboard() {
        openVerificationCodes()
        let copy = element("verificationCodes.copy.beta")
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        copy.click()
        let pasted = NSPasteboard.general.string(forType: .string) ?? ""
        XCTAssertNotNil(pasted.range(of: #"^\d{8}$"#, options: .regularExpression), "Clipboard: \(pasted)")
    }

    // MARK: - US3: lock

    func testLock_removesCodes() {
        openVerificationCodes()
        XCTAssertTrue(element("verificationCodes.code.alpha").waitForExistence(timeout: 10))
        app.menuBars.menuBarItems["Prizm"].click()
        app.menuBars.menuItems["Lock Vault"].click()
        XCTAssertFalse(element("verificationCodes.code.alpha").waitForExistence(timeout: 3),
                       "No code may be visible after lock")
    }
}
