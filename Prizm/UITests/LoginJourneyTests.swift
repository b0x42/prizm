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
        app.launchArguments = ["--ui-testing", "--reset-session"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - US1 Scenario 1: Login screen shown on first launch

    /// Verifies the login screen appears with the server picker and core fields.
    func testLoginScreenShownOnFirstLaunch() {
        let picker   = app.segmentedControls["login.serverTypePicker"]
        let email    = app.textFields["login.email"]
        let password = app.secureTextFields["login.password"]
        let signIn   = app.buttons["login.signIn"]

        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Server type picker should exist")
        XCTAssertTrue(email.exists,    "Email field should exist")
        XCTAssertTrue(password.exists, "Password field should exist")
        XCTAssertTrue(signIn.exists,   "Sign In button should exist")
    }

    // MARK: - US1 Scenario 2: Sign-in button disabled until fields populated (self-hosted)

    func testSignInButtonDisabledWhenFieldsEmpty_selfHosted() {
        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Self-hosted"].click()

        let signIn = app.buttons["login.signIn"]
        XCTAssertFalse(signIn.isEnabled, "Sign In should be disabled with empty fields")

        let serverURL = app.textFields["login.serverURL"]
        serverURL.click()
        serverURL.typeText("https://vault.example.com")
        XCTAssertFalse(signIn.isEnabled, "Sign In should be disabled without email and password")
    }

    // MARK: - US1 Scenario 3: Invalid server URL shows error

    func testInvalidServerURLShowsError() {
        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Self-hosted"].click()

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

    func testInvalidCredentialsShowsError() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")

        fillSelfHostedLoginForm(serverURL: serverURL, email: "wrong@example.com", password: "wrongpassword")
        app.buttons["login.signIn"].click()

        let error = app.staticTexts["login.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "Error message should appear for invalid credentials")
    }

    // MARK: - US1 Scenario 5: Successful self-hosted login reaches vault browser

    func testSuccessfulLoginReachesVaultBrowser() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")
        let email     = try XCTUnwrap(envVar("BW_TEST_EMAIL"), "BW_TEST_EMAIL required")
        let password  = try XCTUnwrap(envVar("BW_TEST_PASSWORD"), "BW_TEST_PASSWORD required")

        let startTime = CFAbsoluteTimeGetCurrent()

        fillSelfHostedLoginForm(serverURL: serverURL, email: email, password: password)
        app.buttons["login.signIn"].click()

        let totpField = app.textFields["totp.code"]
        if totpField.waitForExistence(timeout: 10) {
            throw XCTSkip("TOTP required — use testLoginWithTOTPReachesVaultBrowser instead")
        }

        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(
            vaultNav.waitForExistence(timeout: 60),
            "Vault browser should appear after successful login"
        )

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThanOrEqual(elapsed, 60.0, "SC-001: Login-to-vault must complete within 60s")
    }

    // MARK: - US1 Scenario 6: TOTP prompt appears when 2FA required

    func testTOTPPromptAppearsWhen2FARequired() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")
        let email     = try XCTUnwrap(envVar("BW_TEST_2FA_EMAIL"), "BW_TEST_2FA_EMAIL required")
        let password  = try XCTUnwrap(envVar("BW_TEST_2FA_PASSWORD"), "BW_TEST_2FA_PASSWORD required")

        fillSelfHostedLoginForm(serverURL: serverURL, email: email, password: password)
        app.buttons["login.signIn"].click()

        let totpHeader = app.staticTexts["totp.headerTitle"]
        XCTAssertTrue(totpHeader.waitForExistence(timeout: 15), "TOTP prompt should appear")

        XCTAssertTrue(app.textFields["totp.code"].exists)
        XCTAssertTrue(app.checkBoxes["totp.remember"].exists)
        XCTAssertTrue(app.buttons["totp.continue"].exists)
    }

    // MARK: - US1 Scenario 7: Sync progress shown after auth

    func testSyncProgressShownAfterAuth() throws {
        let serverURL = try XCTUnwrap(envVar("BW_TEST_SERVER_URL"), "BW_TEST_SERVER_URL required")
        let email     = try XCTUnwrap(envVar("BW_TEST_EMAIL"), "BW_TEST_EMAIL required")
        let password  = try XCTUnwrap(envVar("BW_TEST_PASSWORD"), "BW_TEST_PASSWORD required")

        fillSelfHostedLoginForm(serverURL: serverURL, email: email, password: password)
        app.buttons["login.signIn"].click()

        let progressMsg = app.staticTexts["sync.progressMessage"]
        if progressMsg.waitForExistence(timeout: 15) {
            XCTAssertFalse(progressMsg.label.isEmpty)
        }
        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(vaultNav.waitForExistence(timeout: 60))
    }

    // MARK: - Helpers

    private func fillSelfHostedLoginForm(serverURL: String, email: String, password: String) {
        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Self-hosted"].click()

        let serverField = app.textFields["login.serverURL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 5))
        serverField.click()
        serverField.typeText(serverURL)
        app.textFields["login.email"].click()
        app.textFields["login.email"].typeText(email)
        app.secureTextFields["login.password"].click()
        app.secureTextFields["login.password"].typeText(password)
    }

    private func envVar(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return (value?.isEmpty == false) ? value : nil
    }
}
