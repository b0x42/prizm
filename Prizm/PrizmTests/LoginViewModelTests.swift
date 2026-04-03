import XCTest
import Combine
@testable import Prizm

@MainActor
final class LoginViewModelTests: XCTestCase {

    private var sut:          LoginViewModel!
    private var mockUseCase:  MockLoginUseCase!
    private var cancellables: Set<AnyCancellable> = []

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

    override func tearDown() async throws {
        cancellables.removeAll()
        try await super.tearDown()
    }

    // MARK: - signIn: password cleared on success

    /// signIn() clears the password field after a successful login (Constitution §III).
    func testSignIn_success_clearsPasswordField() async throws {
        mockUseCase.stubbedResult = .success(makeAccount())
        sut.serverURL = "https://vault.example.com"
        sut.email     = "alice@example.com"
        sut.password  = "SuperSecret1!"

        let exp = expectation(description: "password cleared after sign-in")
        sut.$password
            .dropFirst()
            .filter { $0.isEmpty }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.signIn()

        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertEqual(sut.password, "", "Password field must be cleared after successful login")
    }

    /// signIn() clears the password field when the server returns .requiresTwoFactor (Constitution §III).
    func testSignIn_requiresTwoFactor_clearsPasswordField() async throws {
        mockUseCase.stubbedResult = .requiresTwoFactor(.authenticatorApp)
        sut.serverURL = "https://vault.example.com"
        sut.email     = "alice@example.com"
        sut.password  = "SuperSecret1!"

        let exp = expectation(description: "flow transitions to 2FA prompt")
        sut.$flowState
            .dropFirst()
            .filter { $0 == .totpPrompt }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.signIn()

        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertEqual(sut.password, "", "Password field must be cleared on 2FA prompt transition")
    }

    /// signIn() does not call the use case when password is empty (matches UI disabled-button guard).
    func testSignIn_emptyPassword_doesNotCallUseCase() {
        sut.serverURL = "https://vault.example.com"
        sut.email     = "alice@example.com"
        sut.password  = ""   // empty — guarded before Task is spawned

        sut.signIn()

        XCTAssertEqual(mockUseCase.executeCallCount, 0,
                       "execute must not be called when password is empty")
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
