import XCTest

/// XCUITest: Biometric enrollment prompt journey.
///
/// Tests the enrollment prompt that appears after the first successful password unlock
/// when biometrics are available. Requires `--mock-biometrics` launch argument to
/// simulate biometric availability without real hardware.
final class BiometricEnrollmentJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--inject-session",
            "--mock-biometrics",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - First-time enrollment prompt

    func testEnrollmentPrompt_firstTime_showsCorrectCopy() throws {
        // Unlock with password to trigger enrollment prompt.
        let passwordField = app.secureTextFields["unlock.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.click()
        passwordField.typeText("TestPassword1!")
        app.buttons["unlock.unlock"].click()

        // Enrollment prompt should appear.
        let prompt = app.sheets.firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertTrue(prompt.staticTexts.matching(NSPredicate(format: "label CONTAINS 'unlock faster'")).firstMatch.exists)
    }

    func testEnrollmentPrompt_accept_enablesBiometric() throws {
        let passwordField = app.secureTextFields["unlock.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.click()
        passwordField.typeText("TestPassword1!")
        app.buttons["unlock.unlock"].click()

        let prompt = app.sheets.firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        // Tap the enable button.
        prompt.buttons.matching(NSPredicate(format: "label CONTAINS 'Enable'")).firstMatch.click()
        // Prompt should dismiss and vault should appear.
        XCTAssertTrue(app.navigationSplitViews["vault.navigationSplit"].waitForExistence(timeout: 10))
    }

    func testEnrollmentPrompt_dismiss_proceedsToVault() throws {
        let passwordField = app.secureTextFields["unlock.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.click()
        passwordField.typeText("TestPassword1!")
        app.buttons["unlock.unlock"].click()

        let prompt = app.sheets.firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.buttons["Not now"].click()
        // Vault should appear.
        XCTAssertTrue(app.navigationSplitViews["vault.navigationSplit"].waitForExistence(timeout: 10))
    }
}
