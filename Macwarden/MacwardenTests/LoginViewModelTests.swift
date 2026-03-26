import XCTest
@testable import Macwarden

@MainActor
final class LoginViewModelTests: XCTestCase {

    private var sut:           LoginViewModel!
    private var mockUseCase:   MockLoginUseCase!

    private func makeAccount() -> Account {
        Account(
            userId:            "user-001",
            email:             "alice@example.com",
            name:              nil,
            serverEnvironment: ServerEnvironment(
                base:      URL(string: "https://vault.example.com")!,
                overrides: nil
            )
        )
    }

    override func setUp() async throws {
        try await super.setUp()
        mockUseCase = MockLoginUseCase()
        sut         = LoginViewModel(loginUseCase: mockUseCase)
    }

    // MARK: - signIn: password cleared on success

    /// signIn() clears the password field after a successful login (Constitution §III).
    func testSignIn_success_clearsPasswordField() async throws {
        mockUseCase.stubbedResult = .success(makeAccount())
        sut.serverURL = "https://vault.example.com"
        sut.email     = "alice@example.com"
        sut.password  = "SuperSecret1!"

        sut.signIn()

        // Allow the Task to complete.
        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(sut.password, "", "Password field must be cleared after successful login")
    }

    /// signIn() clears the password field when the server returns .requiresTwoFactor (Constitution §III).
    func testSignIn_requiresTwoFactor_clearsPasswordField() async throws {
        mockUseCase.stubbedResult = .requiresTwoFactor(.authenticatorApp)
        sut.serverURL = "https://vault.example.com"
        sut.email     = "alice@example.com"
        sut.password  = "SuperSecret1!"

        sut.signIn()

        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(sut.password, "", "Password field must be cleared on 2FA prompt transition")
    }

    /// signIn() with an invalid password encoding does not call the use case.
    func testSignIn_emptyPassword_disabledState_doesNotCallUseCase() {
        sut.serverURL = "https://vault.example.com"
        sut.email     = "alice@example.com"
        sut.password  = ""   // empty — button would be disabled

        // signIn() is guarded by isSignInDisabled, so call it directly to confirm
        // the use case is never reached when the button should be disabled.
        sut.signIn()
        XCTAssertEqual(mockUseCase.executeCallCount, 0,
                       "execute must not be called when inputs are incomplete")
    }

    // MARK: - cancelTOTP

    /// cancelTOTP() delegates to the use case and resets flow state to .login.
    func testCancelTOTP_callsUseCaseAndResetsState() {
        sut.cancelTOTP()

        XCTAssertTrue(mockUseCase.cancelTOTPCalled,
                      "cancelTOTP must forward to loginUseCase.cancelTOTP()")
        XCTAssertEqual(sut.flowState, .login,
                       "flowState must return to .login after cancelling TOTP")
    }
}
