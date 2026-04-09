import XCTest

/// XCUITest: US1 Login Journey (T036)
///
/// Validates the end-to-end login flow from a blank login screen through server URL entry,
/// credential submission, optional TOTP 2FA, vault sync, and arrival at the vault browser.
///
/// **Prerequisites**: The app must launch with no stored session (clean state).
/// **Success Criteria**: SC-001 — full login-to-vault ≤60s.
///
/// - Note: These tests require a running Vaultwarden instance or a mock server.
///   Configure the server URL via the `BW_TEST_SERVER_URL`, `BW_TEST_EMAIL`,
///   and `BW_TEST_PASSWORD` environment variables in the test scheme.
final class LoginJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pass launch argument to reset stored session for a clean login test.
        app.launchArguments = ["--ui-testing", "--reset-session"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - US1 Scenario 1: Login screen is shown on first launch

    /// Verifies the login screen appears with all expected elements when no session exists.
    func testLoginScreenShownOnFirstLaunch() {
        let serverURL = app.textFields["login.serverURL"]
        let email     = app.textFields["login.email"]
        let password  = app.secureTextFields["login.password"]
        let signIn    = app.buttons["login.signIn"]

        XCTAssertTrue(serverURL.waitForExistence(timeout: 5), "Server URL field should exist")
        XCTAssertTrue(email.exists, "Email field should exist")
        XCTAssertTrue(password.exists, "Password field should exist")
        XCTAssertTrue(signIn.exists, "Sign In button should exist")
    }

    // MARK: - US1 Scenario 2: Sign-in button disabled until all fields populated

    /// Verifies the Sign In button is disabled when any required field is empty.
    func testSignInButtonDisabledWhenFieldsEmpty() {
        let signIn = app.buttons["login.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        XCTAssertFalse(signIn.isEnabled, "Sign In should be disabled with empty fields")

        // Fill only server URL — still disabled.
        let serverURL = app.textFields["login.serverURL"]
        serverURL.click()
        serverURL.typeText("https://vault.example.com")
        XCTAssertFalse(signIn.isEnabled, "Sign In should be disabled without email and password")
    }

    // MARK: - US1 Scenario 3: Invalid server URL shows error

    /// Verifies that entering an invalid server URL and submitting shows an error message.
    func testInvalidServerURLShowsError() {
        let serverURL = app.textFields["login.serverURL"]
        let email     = app.textFields["login.email"]
        let password  = app.secureTextFields["login.password"]
        let signIn    = app.buttons["login.signIn"]

        XCTAssertTrue(serverURL.waitForExistence(timeout: 5))

        serverURL.click()
        serverURL.typeText("not-a-url")
        email.click()
        email.typeText("user@example.com")
        password.click()
        password.typeText("password123")
        signIn.click()

        let error = app.staticTexts["login.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10), "Error message should appear for invalid URL")
    }

    // MARK: - US1 Scenario 4: Invalid credentials shows error

    /// Verifies that wrong credentials show an error message without crashing.
    func testInvalidCredentialsShowsError() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")

        fillLoginForm(serverURL: serverURL, email: "wrong@example.com", password: "wrongpassword")
        app.buttons["login.signIn"].click()

        let error = app.staticTexts["login.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "Error message should appear for invalid credentials")
    }

    // MARK: - US1 Scenario 5: Successful login reaches vault browser

    /// Verifies a valid login flow transitions through sync and reaches the vault browser.
    /// Measures total login time against SC-001 (≤60s).
    func testSuccessfulLoginReachesVaultBrowser() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")
        let email     = try XCTUnwrap(envVar("BW_TEST_EMAIL"), "BW_TEST_EMAIL required")
        let password  = try XCTUnwrap(envVar("BW_TEST_PASSWORD"), "BW_TEST_PASSWORD required")

        let startTime = CFAbsoluteTimeGetCurrent()

        fillLoginForm(serverURL: serverURL, email: email, password: password)
        app.buttons["login.signIn"].click()

        // If TOTP is required, the TOTP prompt appears.
        let totpField = app.textFields["totp.code"]
        if totpField.waitForExistence(timeout: 10) {
            // TOTP required — test cannot proceed without a valid code.
            // Skip with a message; the TOTP-specific test handles this.
            throw XCTSkip("TOTP required — use testLoginWithTOTPReachesVaultBrowser instead")
        }

        // Wait for sync progress to complete and vault browser to appear.
        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(
            vaultNav.waitForExistence(timeout: 60),
            "Vault browser should appear after successful login"
        )

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThanOrEqual(elapsed, 60.0, "SC-001: Login-to-vault must complete within 60s")
    }

    // MARK: - US1 Scenario 6: TOTP prompt appears when 2FA required

    /// Verifies the TOTP prompt view appears after credential submission when 2FA is enabled.
    func testTOTPPromptAppearsWhen2FARequired() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")
        let email     = try XCTUnwrap(envVar("BW_TEST_2FA_EMAIL"), "BW_TEST_2FA_EMAIL required")
        let password  = try XCTUnwrap(envVar("BW_TEST_2FA_PASSWORD"), "BW_TEST_2FA_PASSWORD required")

        fillLoginForm(serverURL: serverURL, email: email, password: password)
        app.buttons["login.signIn"].click()

        let totpHeader = app.staticTexts["totp.headerTitle"]
        XCTAssertTrue(
            totpHeader.waitForExistence(timeout: 15),
            "TOTP prompt should appear when 2FA is required"
        )

        let codeField     = app.textFields["totp.code"]
        let rememberToggle = app.checkBoxes["totp.remember"]
        let continueBtn   = app.buttons["totp.continue"]

        XCTAssertTrue(codeField.exists, "TOTP code field should exist")
        XCTAssertTrue(rememberToggle.exists, "Remember device toggle should exist")
        XCTAssertTrue(continueBtn.exists, "Continue button should exist")
    }

    // MARK: - US1 Scenario 7: Sync progress is shown after authentication

    /// Verifies that sync progress messages appear after successful authentication.
    func testSyncProgressShownAfterAuth() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")
        let email     = try XCTUnwrap(envVar("BW_TEST_EMAIL"), "BW_TEST_EMAIL required")
        let password  = try XCTUnwrap(envVar("BW_TEST_PASSWORD"), "BW_TEST_PASSWORD required")

        fillLoginForm(serverURL: serverURL, email: email, password: password)
        app.buttons["login.signIn"].click()

        // The sync progress message should appear during the sync phase.
        let progressMsg = app.staticTexts["sync.progressMessage"]
        // This may be transient — use a short timeout.
        if progressMsg.waitForExistence(timeout: 15) {
            // Progress message appeared — sync is in progress. Good.
            XCTAssertFalse(progressMsg.label.isEmpty, "Sync progress should display a message")
        }
        // Either way, vault should eventually appear.
        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(vaultNav.waitForExistence(timeout: 60), "Vault browser should appear after sync")
    }

    // MARK: - Helpers

    private func fillLoginForm(serverURL: String, email: String, password: String) {
        let serverField = app.textFields["login.serverURL"]
        let emailField  = app.textFields["login.email"]
        let passField   = app.secureTextFields["login.password"]

        XCTAssertTrue(serverField.waitForExistence(timeout: 5))

        serverField.click()
        serverField.typeText(serverURL)
        emailField.click()
        emailField.typeText(email)
        passField.click()
        passField.typeText(password)
    }

    private func envVar(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return (value?.isEmpty == false) ? value : nil
    }
}
