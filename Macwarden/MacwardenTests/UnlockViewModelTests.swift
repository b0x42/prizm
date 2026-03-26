import XCTest
import Combine
@testable import Macwarden

@MainActor
final class UnlockViewModelTests: XCTestCase {

    private var sut:          UnlockViewModel!
    private var mockAuth:     MockAuthRepository!
    private var mockSync:     MockSyncUseCase!
    private var cancellables: Set<AnyCancellable> = []

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

    override func tearDown() async throws {
        cancellables.removeAll()
        try await super.tearDown()
    }

    // MARK: - unlock: password cleared on success

    /// unlock() clears the password field after a successful unlock (Constitution §III).
    func testUnlock_success_clearsPasswordField() async throws {
        mockAuth.stubbedLoginResult = .success(stubAccount)
        sut.password = "SuperSecret1!"

        let exp = expectation(description: "password cleared after unlock")
        sut.$password
            .dropFirst()
            .filter { $0.isEmpty }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.unlock()

        await fulfillment(of: [exp], timeout: 2.0)
        XCTAssertEqual(sut.password, "", "Password field must be cleared after successful unlock")
    }

    // MARK: - unlock: wrong password

    /// Configures a wrong-password unlock and waits for the async Task to complete.
    /// Both wrong-password assertions share this setup to avoid duplication.
    private func runUnlockWithWrongPassword() async {
        mockAuth.unlockWithPasswordError = AuthError.invalidCredentials
        sut.password = "WrongPassword!"

        let exp = expectation(description: "unlock fails with error message")
        sut.$errorMessage
            .compactMap { $0 }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        sut.unlock()
        await fulfillment(of: [exp], timeout: 2.0)
    }

    /// unlock() does NOT clear the password field on wrong password so the user can correct it.
    func testUnlock_wrongPassword_retainsPasswordField() async throws {
        await runUnlockWithWrongPassword()
        XCTAssertEqual(sut.password, "WrongPassword!",
                       "Password field must be retained on failed unlock so the user can correct it")
    }

    /// unlock() surfaces an error message on wrong password.
    func testUnlock_wrongPassword_setsErrorMessage() async throws {
        await runUnlockWithWrongPassword()
        XCTAssertNotNil(sut.errorMessage, "An error message must be shown on failed unlock")
    }

    // MARK: - email property

    /// email property returns the stored account's email address.
    func testEmail_returnsStoredAccountEmail() {
        XCTAssertEqual(sut.email, "alice@example.com")
    }
}
