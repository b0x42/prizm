import XCTest

/// XCUITest: Biometric enrollment prompt journey.
///
/// Tests the enrollment prompt that appears after the first successful password unlock
/// when biometrics are available. Requires `--mock-biometrics` launch argument to
/// simulate biometric availability without real hardware.
///
/// The prompt is rendered inline on the unlock screen (not a sheet) via
/// `UnlockFlowState.enrollmentPrompt` — see design Decision 3.
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
        // Unlock with password to trigger inline enrollment prompt.
        let passwordField = app.secureTextFields["unlock.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.click()
        passwordField.typeText("TestPassword1!")
        app.buttons["unlock.unlock"].click()

        // Enrollment prompt renders inline — query via its container accessibility ID.
        let prompt = app.otherElements["unlock.enrollmentPrompt"].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertTrue(prompt.staticTexts.matching(NSPredicate(format: "label CONTAINS 'unlock faster'")).firstMatch.exists)
    }

    func testEnrollmentPrompt_accept_enablesBiometric() throws {
        let passwordField = app.secureTextFields["unlock.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.click()
        passwordField.typeText("TestPassword1!")
        app.buttons["unlock.unlock"].click()

        let prompt = app.otherElements["unlock.enrollmentPrompt"].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        // Tap the enable button.
        prompt.buttons.matching(NSPredicate(format: "label CONTAINS 'Enable'")).firstMatch.click()
        // Prompt dismisses inline and vault appears.
        XCTAssertTrue(app.navigationSplitViews["vault.navigationSplit"].waitForExistence(timeout: 10))
    }

    func testEnrollmentPrompt_dismiss_proceedsToVault() throws {
        let passwordField = app.secureTextFields["unlock.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.click()
        passwordField.typeText("TestPassword1!")
        app.buttons["unlock.unlock"].click()

        let prompt = app.otherElements["unlock.enrollmentPrompt"].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.buttons["Not now"].click()
        // Vault should appear.
        XCTAssertTrue(app.navigationSplitViews["vault.navigationSplit"].waitForExistence(timeout: 10))
    }
}
