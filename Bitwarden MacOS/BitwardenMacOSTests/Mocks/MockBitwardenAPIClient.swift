import Foundation
@testable import Bitwarden_MacOS

/// Test double for `BitwardenAPIClientProtocol`.
///
/// Configure stubs before calling the SUT; inspect recorded calls after.
final class MockBitwardenAPIClient: BitwardenAPIClientProtocol {

    // MARK: - Configuration state

    private(set) var baseURL: URL?
    private(set) var storedAccessToken: String?

    // MARK: - Stubs: preLogin

    var preLoginResponse: PreLoginResponse?
    var preLoginShouldThrow: Error?

    // MARK: - Stubs: identityToken

    /// When set, `identityToken` returns this response (success path).
    var tokenResponse: TokenResponse?

    /// When set, `identityToken` throws this error (e.g. `AuthError.invalidTwoFactorCode`).
    var tokenShouldThrow: Error?

    /// When set (and `tokenResponse` is nil), simulates a 2FA challenge with these providers.
    var tokenTwoFactorProviders: [Int]?

    // MARK: - Stubs: fetchSync

    var syncResponse: SyncResponse?
    var syncShouldThrow: Error?

    /// Artificial delay (seconds) before `fetchSync` returns; used for concurrency tests.
    var syncDelay: TimeInterval = 0

    // MARK: - Protocol conformance

    func setBaseURL(_ url: URL) {
        baseURL = url
    }

    func setAccessToken(_ token: String) {
        storedAccessToken = token
    }

    func preLogin(email: String) async throws -> PreLoginResponse {
        if let err = preLoginShouldThrow { throw err }
        return preLoginResponse ?? PreLoginResponse(
            kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
        )
    }

    func identityToken(
        email:             String,
        passwordHash:      String,
        deviceIdentifier:  String,
        twoFactorToken:    String?,
        twoFactorProvider: Int?,
        twoFactorRemember: Bool
    ) async throws -> TokenResponse {
        if let err = tokenShouldThrow { throw err }

        // 2FA challenge: return a response with twoFactorProviders set.
        if let providers = tokenTwoFactorProviders, tokenResponse == nil {
            return TokenResponse(
                accessToken:        "",
                refreshToken:       nil,
                tokenType:          "Bearer",
                expiresIn:          0,
                key:                nil,
                privateKey:         nil,
                kdf:                nil,
                kdfIterations:      nil,
                kdfMemory:          nil,
                kdfParallelism:     nil,
                twoFactorToken:     nil,
                twoFactorProviders: providers,
                userId:             nil,
                email:              nil,
                name:               nil
            )
        }

        guard let resp = tokenResponse else {
            throw APIError.baseURLNotSet    // fallback — caller should configure a stub
        }
        return resp
    }

    func fetchSync() async throws -> SyncResponse {
        if syncDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(syncDelay * 1_000_000_000))
        }
        if let err = syncShouldThrow { throw err }
        return syncResponse ?? SyncResponse(
            profile: RawProfile(
                id: "pid", email: "test@example.com", name: nil,
                key: "2.k==", encryptedPrivateKey: nil,
                kdf: 0, kdfIterations: 600_000, kdfMemory: nil, kdfParallelism: nil
            ),
            ciphers: []
        )
    }
}
