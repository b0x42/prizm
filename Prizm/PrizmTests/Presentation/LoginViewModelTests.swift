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
        UserDefaults.standard.removeObject(forKey: "com.prizm.login.lastServerType")
        UserDefaults.standard.removeObject(forKey: "com.prizm.login.lastServerURL")
        mockUseCase = MockLoginUseCase()
        sut         = LoginViewModel(loginUseCase: mockUseCase)
    }

    override func tearDown() async throws {
        cancellables.removeAll()
        UserDefaults.standard.removeObject(forKey: "com.prizm.login.lastServerType")
        UserDefaults.standard.removeObject(forKey: "com.prizm.login.lastServerURL")
        try await super.tearDown()
    }

    // MARK: - 10.1: persisted cloudEU restores on init

    func testInit_persistedCloudEU_restoresServerType() {
        UserDefaults.standard.set("cloudEU", forKey: "com.prizm.login.lastServerType")
        let vm = LoginViewModel(loginUseCase: mockUseCase)
        XCTAssertEqual(vm.serverType, .cloudEU)
    }

    // MARK: - 10.2: fresh install defaults to cloudUS

    func testInit_noPersistedType_defaultsToCloudUS() {
        XCTAssertEqual(sut.serverType, .cloudUS)
    }

    // MARK: - 10.3: serverType change persists; serverURL persisted and restored

    func testServerTypePersists_onSelection() {
        sut.serverType = .cloudEU
        XCTAssertEqual(UserDefaults.standard.string(forKey: "com.prizm.login.lastServerType"), "cloudEU")
    }

    func testServerURL_persistsOnSignIn_forSelfHosted() {
        sut.serverType = .selfHosted
        sut.serverURL  = "https://vault.example.com"
        sut.email      = "a@b.com"
        sut.password   = "pw"
        sut.signIn()
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "com.prizm.login.lastServerURL"),
            "https://vault.example.com"
        )
    }

    func testServerURL_restoredOnInit() {
        UserDefaults.standard.set("https://vault.example.com", forKey: "com.prizm.login.lastServerURL")
        let vm = LoginViewModel(loginUseCase: mockUseCase)
        XCTAssertEqual(vm.serverURL, "https://vault.example.com")
    }

    // MARK: - 10.4: isSignInDisabled when loading

    func testIsSignInDisabled_whenLoading_returnsTrue() {
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()   // transitions to .loading synchronously before Task fires
        XCTAssertTrue(sut.isSignInDisabled)
    }

    // MARK: - 10.5: cloud with email+password, empty serverURL → enabled

    func testIsSignInDisabled_cloud_emptyServerURL_emailAndPasswordFilled_returnsFalse() {
        sut.serverType = .cloudUS
        sut.serverURL  = ""
        sut.email      = "a@b.com"
        sut.password   = "pw"
        XCTAssertFalse(sut.isSignInDisabled)
    }

    // MARK: - 10.6: selfHosted with empty serverURL → disabled

    func testIsSignInDisabled_selfHosted_emptyServerURL_returnsTrue() {
        sut.serverType = .selfHosted
        sut.serverURL  = ""
        sut.email      = "a@b.com"
        sut.password   = "pw"
        XCTAssertTrue(sut.isSignInDisabled)
    }

    // MARK: - 10.7: otpPrompt + empty otpCode → disabled

    func testIsSignInDisabled_otpPrompt_emptyCode_returnsTrue() async throws {
        mockUseCase.stubbedResult = .requiresNewDeviceOTP
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.otpCode = ""
        XCTAssertTrue(sut.isSignInDisabled)
    }

    // MARK: - 10.8: otpPrompt + non-empty otpCode → enabled

    func testIsSignInDisabled_otpPrompt_nonEmptyCode_returnsFalse() async throws {
        mockUseCase.stubbedResult = .requiresNewDeviceOTP
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.otpCode = "123456"
        XCTAssertFalse(sut.isSignInDisabled)
    }

    // MARK: - 10.9: requiresNewDeviceOTP → flowState .otpPrompt

    func testSignIn_requiresNewDeviceOTP_transitionsToOtpPrompt() async throws {
        mockUseCase.stubbedResult = .requiresNewDeviceOTP
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.flowState, .otpPrompt)
    }

    // MARK: - 10.10: cancelOTP → flowState .login

    func testCancelOTP_resetsToLogin() async throws {
        mockUseCase.stubbedResult = .requiresNewDeviceOTP
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.cancelOTP()
        XCTAssertEqual(sut.flowState, .login)
        XCTAssertTrue(mockUseCase.cancelNewDeviceOTPCalled)
    }

    // MARK: - 10.11: invalid OTP error → stays .otpPrompt, error set

    func testSubmitOTP_invalidError_staysOtpPrompt() async throws {
        mockUseCase.stubbedResult             = .requiresNewDeviceOTP
        mockUseCase.completeNewDeviceOTPError = AuthError.invalidCredentials
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.otpCode = "000000"
        sut.submitOTP()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.flowState, .otpPrompt)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - 10.12: resendOTP success → otpCode cleared

    func testResendOTP_success_clearsOtpCode() async throws {
        mockUseCase.stubbedResult = .requiresNewDeviceOTP
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.otpCode = "555555"
        sut.resendOTP()
        // flowState should go to .loading immediately on resend.
        XCTAssertEqual(sut.flowState, .loading, "resendOTP must set .loading before the async call")
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(mockUseCase.resendNewDeviceOTPCalled)
        XCTAssertEqual(sut.flowState, .otpPrompt, "flowState must return to .otpPrompt on resend success")
        XCTAssertEqual(sut.otpCode, "")
    }

    // MARK: - 10.13: resendOTP failure → error set, otpCode unchanged

    func testResendOTP_failure_setsErrorLeavesOtpCode() async throws {
        mockUseCase.stubbedResult           = .requiresNewDeviceOTP
        mockUseCase.resendNewDeviceOTPError = AuthError.serverUnreachable
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.otpCode = "555555"
        sut.resendOTP()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.flowState, .otpPrompt)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.otpCode, "555555")
    }

    // MARK: - 10.14: otpCode cleared synchronously before request fires

    func testSubmitOTP_clearsOtpCodeImmediately() async throws {
        mockUseCase.stubbedResult = .requiresNewDeviceOTP
        sut.email    = "a@b.com"
        sut.password = "pw"
        sut.signIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.otpCode = "123456"
        sut.submitOTP()
        // otpCode is cleared synchronously before the async Task body runs (Constitution §III).
        XCTAssertEqual(sut.otpCode, "", "otpCode must be cleared synchronously in submitOTP()")
    }

    // MARK: - Existing: signIn password cleared on success

    func testSignIn_success_clearsPasswordField() async throws {
        mockUseCase.stubbedResult = .success(makeAccount())
        sut.email    = "alice@example.com"
        sut.password = "SuperSecret1!"

        let exp = expectation(description: "password cleared after sign-in")
        sut.$password
            .dropFirst()
            .filter { $0.isEmpty }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.signIn()

        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertEqual(sut.password, "")
    }

    func testSignIn_requiresTwoFactor_clearsPasswordField() async throws {
        mockUseCase.stubbedResult = .requiresTwoFactor(.authenticatorApp)
        sut.email    = "alice@example.com"
        sut.password = "SuperSecret1!"

        let exp = expectation(description: "flow transitions to 2FA prompt")
        sut.$flowState
            .dropFirst()
            .filter { $0 == .totpPrompt }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.signIn()

        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertEqual(sut.password, "")
    }

    func testSignIn_emptyPassword_doesNotCallUseCase() {
        sut.email    = "alice@example.com"
        sut.password = ""
        sut.signIn()
        XCTAssertEqual(mockUseCase.executeCallCount, 0)
    }

    // MARK: - Existing: cancelTOTP

    func testCancelTOTP_callsUseCaseAndResetsState() {
        sut.cancelTOTP()
        XCTAssertTrue(mockUseCase.cancelTOTPCalled)
        XCTAssertEqual(sut.flowState, .login)
    }
}
