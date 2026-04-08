import Foundation
@testable import Prizm

/// Test double for `PrizmAPIClientProtocol`.
///
/// Configure stubs before calling the SUT; inspect recorded calls after.
actor MockPrizmAPIClient: PrizmAPIClientProtocol {

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

    func clearAccessToken() {
        storedAccessToken = nil
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
            ciphers: [],
            folders: []
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

    // MARK: - Stubs: createCipher

    nonisolated(unsafe) var createCipherResponse: RawCipher?
    nonisolated(unsafe) var createCipherShouldThrow: Error?
    nonisolated(unsafe) var createCipherCallCount: Int = 0

    func createCipher(cipher: RawCipher) async throws -> RawCipher {
        createCipherCallCount += 1
        if let err = createCipherShouldThrow { throw err }
        return createCipherResponse ?? cipher
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

    // MARK: - Stubs: Folder CRUD

    nonisolated(unsafe) var createFolderResponse: RawFolder?
    nonisolated(unsafe) var createFolderShouldThrow: Error?

    func createFolder(encryptedName: String) async throws -> RawFolder {
        if let err = createFolderShouldThrow { throw err }
        return createFolderResponse ?? RawFolder(id: UUID().uuidString, name: encryptedName, revisionDate: nil)
    }

    nonisolated(unsafe) var updateFolderResponse: RawFolder?
    nonisolated(unsafe) var updateFolderShouldThrow: Error?

    func updateFolder(id: String, encryptedName: String) async throws -> RawFolder {
        if let err = updateFolderShouldThrow { throw err }
        return updateFolderResponse ?? RawFolder(id: id, name: encryptedName, revisionDate: nil)
    }

    nonisolated(unsafe) var deleteFolderShouldThrow: Error?

    func deleteFolder(id: String) async throws {
        if let err = deleteFolderShouldThrow { throw err }
    }

    // MARK: - Stubs: Cipher partial / move

    nonisolated(unsafe) var updateCipherPartialShouldThrow: Error?

    func updateCipherPartial(id: String, folderId: String?, favorite: Bool) async throws {
        if let err = updateCipherPartialShouldThrow { throw err }
    }

    nonisolated(unsafe) var moveCiphersShouldThrow: Error?

    func moveCiphersToFolder(ids: [String], folderId: String?) async throws {
        if let err = moveCiphersShouldThrow { throw err }
    }

}
