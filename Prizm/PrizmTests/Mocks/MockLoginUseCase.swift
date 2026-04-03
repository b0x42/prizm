import Foundation
@testable import Prizm

/// Test double for `LoginUseCase`.
@MainActor
final class MockLoginUseCase: LoginUseCase {

    // MARK: - Call tracking

    private(set) var executeCallCount:    Int  = 0
    private(set) var cancelTOTPCalled:    Bool = false
    private(set) var completeTOTPCalled:  Bool = false

    // MARK: - Stubs

    var stubbedResult: LoginResult = .success(
        Account(
            userId:            "stub-user",
            email:             "stub@example.com",
            name:              nil,
            serverEnvironment: ServerEnvironment(
                base:      URL(string: "https://stub.example.com")!,
                overrides: nil
            )
        )
    )
    var executeError: Error?
    var completeTOTPError: Error?

    // MARK: - LoginUseCase

    func execute(serverURL: String, email: String, masterPassword: Data) async throws -> LoginResult {
        executeCallCount += 1
        if let err = executeError { throw err }
        return stubbedResult
    }

    func completeTOTP(code: String, rememberDevice: Bool) async throws -> Account {
        completeTOTPCalled = true
        if let err = completeTOTPError { throw err }
        guard case .success(let account) = stubbedResult else {
            throw AuthError.invalidTwoFactorCode
        }
        return account
    }

    func cancelTOTP() {
        cancelTOTPCalled = true
    }
}
