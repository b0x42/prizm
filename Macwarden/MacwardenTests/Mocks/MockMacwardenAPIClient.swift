import Foundation
@testable import Macwarden

/// Test double for `MacwardenAPIClientProtocol`.
///
/// Configure stubs before calling the SUT; inspect recorded calls after.
actor MockMacwardenAPIClient: MacwardenAPIClientProtocol {

    // MARK: - Configuration state
    // nonisolated(unsafe) allows tests to read/write without await — safe in single-threaded tests.

    nonisolated(unsafe) var baseURL: URL?
    nonisolated(unsafe) var storedAccessToken: String?

    // MARK: - Stubs: preLogin

    nonisolated(unsafe) var preLoginResponse: PreLoginResponse?
    nonisolated(unsafe) var preLoginShouldThrow: Error?

    // MARK: - Stubs: identityToken

    nonisolated(unsafe) var tokenResponse: TokenResponse?
    nonisolated(unsafe) var tokenShouldThrow: Error?
    nonisolated(unsafe) var tokenTwoFactorProviders: [Int]?

    // MARK: - Stubs: fetchSync

    nonisolated(unsafe) var syncResponse: SyncResponse?
    nonisolated(unsafe) var syncShouldThrow: Error?
    nonisolated(unsafe) var syncDelay: TimeInterval = 0

    // MARK: - Stubs: refreshAccessToken

    nonisolated(unsafe) var refreshResponse: String?
    nonisolated(unsafe) var refreshShouldThrow: Error?

    // MARK: - Stubs: updateCipher

    nonisolated(unsafe) var updateCipherResponse: RawCipher?
    nonisolated(unsafe) var updateCipherShouldThrow: Error?
    nonisolated(unsafe) var updateCipherCallCount: Int = 0
    nonisolated(unsafe) var lastUpdatedCipherId: String?

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
            throw APIError.baseURLNotSet
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
                key: "2.k==", privateKey: nil
            ),
            ciphers: []
        )
    }

    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, refreshToken: String?) {
        if let err = refreshShouldThrow { throw err }
        let token = refreshResponse ?? "refreshed-access-token"
        storedAccessToken = token
        return (token, nil)
    }

    func updateCipher(id: String, cipher: RawCipher) async throws -> RawCipher {
        updateCipherCallCount += 1
        lastUpdatedCipherId = id
        if let err = updateCipherShouldThrow { throw err }
        return updateCipherResponse ?? cipher
    }

    // MARK: - Stubs: softDeleteCipher

    nonisolated(unsafe) var softDeleteShouldThrow: Error?
    nonisolated(unsafe) var softDeleteCallCount: Int = 0
    nonisolated(unsafe) var lastSoftDeletedId: String?

    func softDeleteCipher(id: String) async throws {
        softDeleteCallCount += 1
        lastSoftDeletedId = id
        if let err = softDeleteShouldThrow { throw err }
    }

    // MARK: - Stubs: permanentDeleteCipher

    nonisolated(unsafe) var permanentDeleteShouldThrow: Error?
    nonisolated(unsafe) var permanentDeleteCallCount: Int = 0
    nonisolated(unsafe) var lastPermanentDeletedId: String?

    func permanentDeleteCipher(id: String) async throws {
        permanentDeleteCallCount += 1
        lastPermanentDeletedId = id
        if let err = permanentDeleteShouldThrow { throw err }
    }

    // MARK: - Stubs: restoreCipher

    nonisolated(unsafe) var restoreShouldThrow: Error?
    nonisolated(unsafe) var restoreCallCount: Int = 0
    nonisolated(unsafe) var lastRestoredId: String?

    func restoreCipher(id: String) async throws {
        restoreCallCount += 1
        lastRestoredId = id
        if let err = restoreShouldThrow { throw err }
    }

}
