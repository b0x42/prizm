import XCTest
@testable import Macwarden

@MainActor
final class UnlockViewModelTests: XCTestCase {

    private var sut:         UnlockViewModel!
    private var mockAuth:    MockAuthRepository!
    private var mockSync:    MockSyncUseCase!

    private let stubAccount = Account(
        userId:            "user-001",
        email:             "alice@example.com",
        name:              nil,
        serverEnvironment: ServerEnvironment(
            base:      URL(string: "https://vault.example.com")!,
            overrides: nil
        )
    )

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockAuthRepository()
        mockSync = MockSyncUseCase()
        sut      = UnlockViewModel(auth: mockAuth, sync: mockSync, account: stubAccount)
    }

    // MARK: - unlock: password cleared on success

    /// unlock() clears the password field after a successful unlock (Constitution §III).
    func testUnlock_success_clearsPasswordField() async throws {
        mockAuth.stubbedLoginResult = .success(stubAccount)
        sut.password = "SuperSecret1!"

        sut.unlock()

        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(sut.password, "", "Password field must be cleared after successful unlock")
    }

    /// unlock() does NOT clear the password field on wrong password so the user can correct it.
    func testUnlock_wrongPassword_retainsPasswordField() async throws {
        mockAuth.unlockWithPasswordError = AuthError.invalidCredentials
        sut.password = "WrongPassword!"

        sut.unlock()

        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(sut.password, "WrongPassword!",
                       "Password field must be retained on failed unlock so the user can correct it")
    }

    /// unlock() surfaces an error message on wrong password.
    func testUnlock_wrongPassword_setsErrorMessage() async throws {
        mockAuth.unlockWithPasswordError = AuthError.invalidCredentials
        sut.password = "WrongPassword!"

        sut.unlock()

        await Task.yield()
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertNotNil(sut.errorMessage, "An error message must be shown on failed unlock")
    }

    /// email property returns the stored account's email address.
    func testEmail_returnsStoredAccountEmail() {
        XCTAssertEqual(sut.email, "alice@example.com")
    }
}
