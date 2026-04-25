import XCTest

/// XCUITest: US1 Login Journey — Server Picker & New-Device OTP (T037)
///
/// Verifies the three-way server picker UI, conditional server URL field visibility,
/// Sign In button enable/disable logic, and the new-device OTP flow introduced for
/// Bitwarden Cloud logins.
///
/// **Prerequisites**: The app must launch with no stored session (clean state).
///
/// - Note: Tests 14.5–14.8 require a Bitwarden Cloud stub server that speaks the
///   Bitwarden identity API. Configure via `BW_CLOUD_STUB_URL`, `BW_CLOUD_TEST_EMAIL`,
///   and `BW_CLOUD_TEST_PASSWORD` environment variables in the test scheme.
///   Tests 14.6–14.8 additionally require the stub to return `device_error` on first
///   auth and accept/reject the OTP on subsequent requests.
final class LoginPickerJourneyTests: XCTestCase {

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

    // MARK: - 14.1 Three-way picker visible; all options selectable

    func testServerPickerShowsThreeOptions() {
        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Server type picker should be visible")

        let bitwardenUS = picker.buttons["Bitwarden Cloud (US)"]
        let bitwardenEU = picker.buttons["Bitwarden Cloud (EU)"]
        let selfHosted  = picker.buttons["Self-hosted"]

        XCTAssertTrue(bitwardenUS.exists, "Bitwarden Cloud (US) option should exist")
        XCTAssertTrue(bitwardenEU.exists, "Bitwarden Cloud (EU) option should exist")
        XCTAssertTrue(selfHosted.exists,  "Self-hosted option should exist")

        // Each option is selectable without error.
        bitwardenEU.click()
        XCTAssertTrue(bitwardenEU.isSelected, "Bitwarden Cloud (EU) should be selected after click")

        selfHosted.click()
        XCTAssertTrue(selfHosted.isSelected, "Self-hosted should be selected after click")

        bitwardenUS.click()
        XCTAssertTrue(bitwardenUS.isSelected, "Bitwarden Cloud (US) should be selected after click")
    }

    // MARK: - 14.2 Cloud hides server URL field; self-hosted shows it

    func testServerURLFieldVisibilityByPickerSelection() {
        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        picker.buttons["Bitwarden Cloud (US)"].click()
        XCTAssertFalse(
            app.textFields["login.serverURL"].exists,
            "Server URL field should be hidden for Bitwarden Cloud (US)"
        )

        picker.buttons["Bitwarden Cloud (EU)"].click()
        XCTAssertFalse(
            app.textFields["login.serverURL"].exists,
            "Server URL field should be hidden for Bitwarden Cloud (EU)"
        )

        picker.buttons["Self-hosted"].click()
        XCTAssertTrue(
            app.textFields["login.serverURL"].waitForExistence(timeout: 3),
            "Server URL field should appear for Self-hosted"
        )
    }

    // MARK: - 14.3 Sign In enabled for cloud with email + password only

    func testSignInButtonEnabledForCloudWithEmailAndPassword() {
        let picker   = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Bitwarden Cloud (US)"].click()

        let signIn   = app.buttons["login.signIn"]
        XCTAssertFalse(signIn.isEnabled, "Sign In should be disabled before any input")

        app.textFields["login.email"].click()
        app.textFields["login.email"].typeText("user@example.com")
        XCTAssertFalse(signIn.isEnabled, "Sign In should be disabled with only email")

        app.secureTextFields["login.password"].click()
        app.secureTextFields["login.password"].typeText("mypassword")
        XCTAssertTrue(signIn.isEnabled, "Sign In should be enabled with email + password for cloud")
    }

    // MARK: - 14.4 Sign In disabled for self-hosted when serverURL empty

    func testSignInButtonDisabledForSelfHostedWithEmptyServerURL() {
        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Self-hosted"].click()

        app.textFields["login.email"].click()
        app.textFields["login.email"].typeText("user@example.com")
        app.secureTextFields["login.password"].click()
        app.secureTextFields["login.password"].typeText("mypassword")

        let signIn = app.buttons["login.signIn"]
        XCTAssertFalse(
            signIn.isEnabled,
            "Sign In should be disabled for self-hosted when server URL is empty"
        )
    }

    // MARK: - 14.5 Successful cloud login reaches vault browser (no OTP)

    func testCloudLoginSuccessReachesVaultBrowser() throws {
        let stubURL  = try XCTUnwrap(envVar("BW_CLOUD_STUB_URL"), "BW_CLOUD_STUB_URL required")
        let email    = try XCTUnwrap(envVar("BW_CLOUD_TEST_EMAIL"), "BW_CLOUD_TEST_EMAIL required")
        let password = try XCTUnwrap(envVar("BW_CLOUD_TEST_PASSWORD"), "BW_CLOUD_TEST_PASSWORD required")

        // Override the cloud endpoint via launch argument so the stub URL is used.
        app.terminate()
        app.launchArguments = ["--ui-testing", "--reset-session", "--cloud-stub-url=\(stubURL)"]
        app.launch()

        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Bitwarden Cloud (US)"].click()

        app.textFields["login.email"].click()
        app.textFields["login.email"].typeText(email)
        app.secureTextFields["login.password"].click()
        app.secureTextFields["login.password"].typeText(password)
        app.buttons["login.signIn"].click()

        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(
            vaultNav.waitForExistence(timeout: 60),
            "Vault browser should appear after successful cloud login"
        )
    }

    // MARK: - 14.6 device_error response → NewDeviceOTPView appears

    func testDeviceErrorShowsNewDeviceOTPView() throws {
        let stubURL  = try XCTUnwrap(envVar("BW_CLOUD_STUB_URL"), "BW_CLOUD_STUB_URL required")
        let email    = try XCTUnwrap(envVar("BW_CLOUD_OTP_EMAIL"), "BW_CLOUD_OTP_EMAIL required")
        let password = try XCTUnwrap(envVar("BW_CLOUD_OTP_PASSWORD"), "BW_CLOUD_OTP_PASSWORD required")

        app.terminate()
        app.launchArguments = [
            "--ui-testing", "--reset-session",
            "--cloud-stub-url=\(stubURL)",
            "--cloud-stub-device-error"   // tells the stub to respond with device_error
        ]
        app.launch()

        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Bitwarden Cloud (US)"].click()

        app.textFields["login.email"].click()
        app.textFields["login.email"].typeText(email)
        app.secureTextFields["login.password"].click()
        app.secureTextFields["login.password"].typeText(password)
        app.buttons["login.signIn"].click()

        let otpHeader = app.staticTexts["totp.headerTitle"]
        XCTAssertTrue(
            otpHeader.waitForExistence(timeout: 15),
            "NewDeviceOTPView header should appear after device_error"
        )
        XCTAssertTrue(
            app.textFields["login.newDeviceOtpField"].exists,
            "OTP text field should be visible"
        )
        XCTAssertTrue(
            app.buttons["login.resendOtpButton"].exists,
            "Resend button should be visible"
        )
        XCTAssertTrue(
            app.buttons["login.cancelOtpButton"].exists,
            "Cancel button should be visible"
        )
    }

    // MARK: - 14.7 Valid OTP submitted → login succeeds; OTP field disappears

    func testValidOTPSubmissionSucceeds() throws {
        let stubURL  = try XCTUnwrap(envVar("BW_CLOUD_STUB_URL"), "BW_CLOUD_STUB_URL required")
        let email    = try XCTUnwrap(envVar("BW_CLOUD_OTP_EMAIL"), "BW_CLOUD_OTP_EMAIL required")
        let password = try XCTUnwrap(envVar("BW_CLOUD_OTP_PASSWORD"), "BW_CLOUD_OTP_PASSWORD required")
        let validOTP = try XCTUnwrap(envVar("BW_CLOUD_VALID_OTP"), "BW_CLOUD_VALID_OTP required")

        app.terminate()
        app.launchArguments = [
            "--ui-testing", "--reset-session",
            "--cloud-stub-url=\(stubURL)",
            "--cloud-stub-device-error"
        ]
        app.launch()

        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Bitwarden Cloud (US)"].click()

        app.textFields["login.email"].click()
        app.textFields["login.email"].typeText(email)
        app.secureTextFields["login.password"].click()
        app.secureTextFields["login.password"].typeText(password)
        app.buttons["login.signIn"].click()

        let otpField = app.textFields["login.newDeviceOtpField"]
        XCTAssertTrue(otpField.waitForExistence(timeout: 15), "OTP screen should appear")
        otpField.click()
        otpField.typeText(validOTP)
        app.buttons["login.signIn"].click()

        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(
            vaultNav.waitForExistence(timeout: 60),
            "Vault browser should appear after valid OTP"
        )
        XCTAssertFalse(
            app.textFields["login.newDeviceOtpField"].exists,
            "OTP field should disappear after successful OTP"
        )
    }

    // MARK: - 14.8 Invalid OTP → error shown; OTP field remains

    func testInvalidOTPShowsError() throws {
        let stubURL  = try XCTUnwrap(envVar("BW_CLOUD_STUB_URL"), "BW_CLOUD_STUB_URL required")
        let email    = try XCTUnwrap(envVar("BW_CLOUD_OTP_EMAIL"), "BW_CLOUD_OTP_EMAIL required")
        let password = try XCTUnwrap(envVar("BW_CLOUD_OTP_PASSWORD"), "BW_CLOUD_OTP_PASSWORD required")

        app.terminate()
        app.launchArguments = [
            "--ui-testing", "--reset-session",
            "--cloud-stub-url=\(stubURL)",
            "--cloud-stub-device-error"
        ]
        app.launch()

        let picker = app.segmentedControls["login.serverTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Bitwarden Cloud (US)"].click()

        app.textFields["login.email"].click()
        app.textFields["login.email"].typeText(email)
        app.secureTextFields["login.password"].click()
        app.secureTextFields["login.password"].typeText(password)
        app.buttons["login.signIn"].click()

        let otpField = app.textFields["login.newDeviceOtpField"]
        XCTAssertTrue(otpField.waitForExistence(timeout: 15), "OTP screen should appear")
        otpField.click()
        otpField.typeText("000000")   // wrong OTP — stub always rejects this
        app.buttons["login.signIn"].click()

        let errorLabel = app.staticTexts["login.otpErrorMessage"]
        XCTAssertTrue(
            errorLabel.waitForExistence(timeout: 15),
            "Error message should appear for invalid OTP"
        )
        XCTAssertFalse(errorLabel.label.isEmpty, "Error message should not be empty")
        XCTAssertTrue(
            app.textFields["login.newDeviceOtpField"].exists,
            "OTP field should remain visible after invalid OTP"
        )
    }

    // MARK: - Helpers

    private func envVar(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return (value?.isEmpty == false) ? value : nil
    }
}
