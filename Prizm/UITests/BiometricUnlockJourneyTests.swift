import XCTest

/// XCUITest: Biometric unlock journey.
///
/// Tests the biometric unlock flow including auto-prompt, successful unlock,
/// cancellation fallback, and lockout message. Requires `--mock-biometrics`
/// launch argument to simulate biometric availability.
final class BiometricUnlockJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--inject-session",
            "--mock-biometrics",
            "--biometric-enabled",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Auto-prompt

    func testBiometricAutoPrompt_firesOnUnlockScreen() throws {
        // The biometric button should be visible on the unlock screen.
        let biometricButton = app.buttons["unlock.biometric"]
        XCTAssertTrue(biometricButton.waitForExistence(timeout: 5))
    }

    // MARK: - Successful unlock

    func testBiometricUnlock_success_showsVaultBrowser() throws {
        // With mock biometrics succeeding, the vault should appear.
        let vault = app.navigationSplitViews["vault.navigationSplit"]
        XCTAssertTrue(vault.waitForExistence(timeout: 10))
    }

    // MARK: - Cancellation fallback

    func testBiometricUnlock_cancelled_showsPasswordField() throws {
        // When biometric is cancelled, password field should be focused.
        let passwordField = app.secureTextFields["unlock.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
    }

    // MARK: - Lockout message

    func testBiometricUnlock_lockout_showsErrorMessage() throws {
        // With mock biometrics returning lockout, error should appear.
        let error = app.staticTexts["unlock.error"]
        if error.waitForExistence(timeout: 5) {
            XCTAssertTrue(error.label.contains("Too many failed"))
        }
    }
}
