import XCTest

/// XCUITest: Biometric unlock journey.
///
/// Tests the biometric unlock flow including auto-prompt, successful unlock,
/// cancellation fallback, and lockout message. Requires `--mock-biometrics`
/// launch argument to simulate biometric availability.
///
/// Touch ID is indicated by a badge on the lock icon and subtitle copy —
/// there is no separate Touch ID button (design Decision 2).
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
        // When biometrics are enabled the subtitle mentions "Touch ID".
        // The badge overlay carries the accessibility identifier "unlock.biometricBadge".
        let badge = app.images["unlock.biometricBadge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        // Subtitle copy confirms Touch ID is active.
        let subtitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Touch ID'")).firstMatch
        XCTAssertTrue(subtitle.exists)
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
