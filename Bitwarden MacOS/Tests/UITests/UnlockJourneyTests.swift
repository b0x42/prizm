import XCTest

/// XCUITest: US2 Unlock Journey (T043)
///
/// Validates the vault unlock flow for returning users with a stored session.
/// The unlock screen should show the stored email, accept the master password,
/// and reach the vault browser without a network login request.
///
/// **Prerequisites**: A session must be stored (run LoginJourneyTests first or
/// use `--ui-testing --inject-session` launch args to pre-seed a test session).
/// **Success Criteria**: SC-002 — unlock-to-vault ≤5s.
final class UnlockJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Inject a stored session so the unlock screen appears on launch.
        app.launchArguments = ["--ui-testing", "--inject-session"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - US2 Scenario 1: Unlock screen shown for returning user

    /// Verifies that the unlock screen appears (not login) when a stored session exists.
    func testUnlockScreenShownOnRelaunch() {
        let header = app.staticTexts["unlock.headerTitle"]
        XCTAssertTrue(
            header.waitForExistence(timeout: 5),
            "Unlock screen should appear for returning users"
        )
        XCTAssertEqual(header.label, "Vault locked")
    }

    // MARK: - US2 Scenario 2: Stored email is displayed read-only

    /// Verifies the stored email is displayed on the unlock screen.
    func testStoredEmailDisplayed() {
        let emailLabel = app.staticTexts["unlock.email"]
        XCTAssertTrue(
            emailLabel.waitForExistence(timeout: 5),
            "Stored email should be visible on unlock screen"
        )
        XCTAssertFalse(emailLabel.label.isEmpty, "Email label should not be empty")
    }

    // MARK: - US2 Scenario 3: Correct password unlocks vault (SC-002)

    /// Verifies that entering the correct master password reaches the vault browser.
    /// Measures time against SC-002 (≤5s).
    func testCorrectPasswordUnlocksVault() throws {
        let password = try XCTUnwrap(envVar("BW_TEST_PASSWORD"), "BW_TEST_PASSWORD required")

        let passField  = app.secureTextFields["unlock.password"]
        let unlockBtn  = app.buttons["unlock.unlock"]

        XCTAssertTrue(passField.waitForExistence(timeout: 5))

        let startTime = CFAbsoluteTimeGetCurrent()

        passField.click()
        passField.typeText(password)
        unlockBtn.click()

        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(
            vaultNav.waitForExistence(timeout: 30),
            "Vault browser should appear after unlock"
        )

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThanOrEqual(elapsed, 5.0, "SC-002: Unlock-to-vault must complete within 5s")
    }

    // MARK: - US2 Scenario 4: Wrong password shows error without locking

    /// Verifies that entering the wrong password shows an error message but stays on
    /// the unlock screen (vault is not locked/destroyed).
    func testWrongPasswordShowsErrorStaysOnUnlock() {
        let passField = app.secureTextFields["unlock.password"]
        let unlockBtn = app.buttons["unlock.unlock"]

        XCTAssertTrue(passField.waitForExistence(timeout: 5))

        passField.click()
        passField.typeText("definitely-wrong-password")
        unlockBtn.click()

        let error = app.staticTexts["unlock.error"]
        XCTAssertTrue(
            error.waitForExistence(timeout: 10),
            "Error message should appear for wrong password"
        )

        // Should still be on the unlock screen — not redirected to login.
        let header = app.staticTexts["unlock.headerTitle"]
        XCTAssertTrue(header.exists, "Should remain on unlock screen after wrong password")
    }

    // MARK: - US2 Scenario 5: "Sign in with a different account" returns to login

    /// Verifies that tapping "Sign in with a different account" clears the session
    /// and returns to the login screen.
    func testSwitchAccountReturnsToLogin() {
        let switchBtn = app.buttons["unlock.switchAccount"]
        XCTAssertTrue(switchBtn.waitForExistence(timeout: 5))
        switchBtn.click()

        let serverURL = app.textFields["login.serverURL"]
        XCTAssertTrue(
            serverURL.waitForExistence(timeout: 5),
            "Login screen should appear after switching account"
        )
    }

    // MARK: - US2 Scenario 6: Unlock button disabled when password empty

    /// Verifies the unlock button is disabled when the password field is empty.
    func testUnlockButtonDisabledWhenEmpty() {
        let unlockBtn = app.buttons["unlock.unlock"]
        XCTAssertTrue(unlockBtn.waitForExistence(timeout: 5))
        XCTAssertFalse(unlockBtn.isEnabled, "Unlock should be disabled with empty password")
    }

    // MARK: - Helpers

    private func envVar(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return (value?.isEmpty == false) ? value : nil
    }
}
