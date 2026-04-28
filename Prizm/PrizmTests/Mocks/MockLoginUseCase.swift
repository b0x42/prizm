import Foundation
@testable import Prizm

/// Test double for `LoginUseCase`.
@MainActor
final class MockLoginUseCase: LoginUseCase {

    // MARK: - Call tracking

    private(set) var executeCallCount:              Int  = 0
    private(set) var cancelTOTPCalled:              Bool = false
    private(set) var completeTOTPCalled:            Bool = false
    private(set) var completeNewDeviceOTPCalled:    Bool = false
    private(set) var resendNewDeviceOTPCalled:      Bool = false
    private(set) var cancelNewDeviceOTPCalled:      Bool = false
    private(set) var lastExecutedServerType:         ServerType?
    private(set) var lastExecutedServerURL:          String?

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
    var completeNewDeviceOTPError: Error?
    var resendNewDeviceOTPError: Error?

    // MARK: - LoginUseCase

    func execute(serverType: ServerType, serverURL: String, email: String, masterPassword: Data) async throws -> LoginResult {
        executeCallCount += 1
        lastExecutedServerType = serverType
        lastExecutedServerURL  = serverURL
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

    func completeNewDeviceOTP(otp: String) async throws -> Account {
        completeNewDeviceOTPCalled = true
        if let err = completeNewDeviceOTPError { throw err }
        guard case .success(let account) = stubbedResult else {
            throw AuthError.invalidCredentials
        }
        return account
    }

    func resendNewDeviceOTP() async throws {
        resendNewDeviceOTPCalled = true
        if let err = resendNewDeviceOTPError { throw err }
    }

    func cancelNewDeviceOTP() {
        cancelNewDeviceOTPCalled = true
    }
}
