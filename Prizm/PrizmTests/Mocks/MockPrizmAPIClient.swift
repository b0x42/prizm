import Foundation
@testable import Prizm

/// Test double for `PrizmAPIClientProtocol`.
///
/// Configure stubs before calling the SUT; inspect recorded calls after.
actor MockPrizmAPIClient: PrizmAPIClientProtocol {

    // MARK: - Configuration state
    // nonisolated(unsafe) allows tests to read/write without await — safe in single-threaded tests.

    nonisolated(unsafe) var serverEnvironment: ServerEnvironment?
    nonisolated(unsafe) var storedAccessToken: String?

    // MARK: - Stubs: preLogin

    nonisolated(unsafe) var preLoginResponse: PreLoginResponse?
    nonisolated(unsafe) var preLoginShouldThrow: Error?

    // MARK: - Stubs: identityToken

    nonisolated(unsafe) var tokenResponse: TokenResponse?
    nonisolated(unsafe) var tokenShouldThrow: Error?
    nonisolated(unsafe) var tokenTwoFactorProviders: [Int]?
    nonisolated(unsafe) var lastIdentityTokenNewDeviceOTP: String?

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

    func setServerEnvironment(_ env: ServerEnvironment) {
        serverEnvironment = env
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
        twoFactorRemember: Bool,
        newDeviceOTP:      String?
    ) async throws -> TokenResponse {
        lastIdentityTokenNewDeviceOTP = newDeviceOTP
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
            throw APIError.serverEnvironmentNotSet
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

    // MARK: - Stubs: updateCipherCollections

    nonisolated(unsafe) var updateCipherCollectionsCallCount = 0
    nonisolated(unsafe) var lastUpdatedCipherCollections: (id: String, collectionIds: [String])?

    func updateCipherCollections(id: String, collectionIds: [String]) async throws {
        updateCipherCollectionsCallCount += 1
        lastUpdatedCipherCollections = (id, collectionIds)
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

    // MARK: - Stubs: createOrgCipher

    nonisolated(unsafe) var createOrgCipherResponse: RawCipher?
    nonisolated(unsafe) var createOrgCipherCallCount: Int = 0

    func createOrgCipher(cipher: RawCipher) async throws -> RawCipher {
        createOrgCipherCallCount += 1
        if let err = createCipherShouldThrow { throw err }
        return createOrgCipherResponse ?? cipher
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

    // MARK: - Stubs: attachment endpoints

    nonisolated(unsafe) var createAttachmentMetadataResponse: AttachmentMetadataResponse?
    nonisolated(unsafe) var createAttachmentMetadataShouldThrow: Error?
    nonisolated(unsafe) var createAttachmentMetadataCallCount: Int = 0
    nonisolated(unsafe) var lastAttachmentMetadataRequest: AttachmentMetadataRequest?

    func createAttachmentMetadata(cipherId: String, body: AttachmentMetadataRequest) async throws -> AttachmentMetadataResponse {
        createAttachmentMetadataCallCount += 1
        lastAttachmentMetadataRequest = body
        if let err = createAttachmentMetadataShouldThrow { throw err }
        return createAttachmentMetadataResponse ?? AttachmentMetadataResponse(
            attachmentId: "att-123",
            url: "https://cdn.example.com/upload-signed",
            fileUploadType: 0
        )
    }

    nonisolated(unsafe) var uploadBitwardenHostedShouldThrow: Error?
    nonisolated(unsafe) var uploadBitwardenHostedCallCount: Int = 0
    nonisolated(unsafe) var lastUploadedCipherId: String?
    nonisolated(unsafe) var lastUploadedAttachmentId: String?

    func uploadAttachmentBitwardenHosted(cipherId: String, attachmentId: String, encryptedBlob: Data) async throws {
        uploadBitwardenHostedCallCount += 1
        lastUploadedCipherId = cipherId
        lastUploadedAttachmentId = attachmentId
        if let err = uploadBitwardenHostedShouldThrow { throw err }
    }

    nonisolated(unsafe) var uploadAzureShouldThrow: Error?
    nonisolated(unsafe) var uploadAzureCallCount: Int = 0
    nonisolated(unsafe) var lastAzureSignedURL: URL?

    func uploadAttachmentAzure(signedURL: URL, encryptedBlob: Data) async throws {
        uploadAzureCallCount += 1
        lastAzureSignedURL = signedURL
        if let err = uploadAzureShouldThrow { throw err }
    }

    nonisolated(unsafe) var fetchAttachmentDownloadURLResponse: AttachmentDownloadResponse?
    nonisolated(unsafe) var fetchAttachmentDownloadURLShouldThrow: Error?
    nonisolated(unsafe) var fetchAttachmentDownloadURLCallCount: Int = 0

    func fetchAttachmentDownloadURL(cipherId: String, attachmentId: String) async throws -> AttachmentDownloadResponse {
        fetchAttachmentDownloadURLCallCount += 1
        if let err = fetchAttachmentDownloadURLShouldThrow { throw err }
        return fetchAttachmentDownloadURLResponse ?? AttachmentDownloadResponse(url: "https://cdn.example.com/download-signed")
    }

    nonisolated(unsafe) var deleteAttachmentShouldThrow: Error?
    nonisolated(unsafe) var deleteAttachmentCallCount: Int = 0
    nonisolated(unsafe) var lastDeletedAttachmentId: String?

    func deleteAttachment(cipherId: String, attachmentId: String) async throws {
        deleteAttachmentCallCount += 1
        lastDeletedAttachmentId = attachmentId
        if let err = deleteAttachmentShouldThrow { throw err }
    }

    nonisolated(unsafe) var downloadBlobResult: Data = Data()
    nonisolated(unsafe) var downloadBlobShouldThrow: Error?
    nonisolated(unsafe) var downloadBlobCallCount: Int = 0
    /// Sequential results keyed by call count (1-based). Falls back to `downloadBlobResult`.
    nonisolated(unsafe) var downloadBlobSequence: [Int: Result<Data, Error>] = [:]

    func downloadBlob(from url: URL) async throws -> Data {
        downloadBlobCallCount += 1
        if let seq = downloadBlobSequence[downloadBlobCallCount] {
            return try seq.get()
        }
        if let err = downloadBlobShouldThrow { throw err }
        return downloadBlobResult
    }



    // MARK: - Stubs: Collection CRUD

    nonisolated(unsafe) var createCollectionResponse: RawCollection?
    nonisolated(unsafe) var createCollectionShouldThrow: Error?
    nonisolated(unsafe) var createCollectionCallCount: Int = 0
    nonisolated(unsafe) var lastCreateCollectionOrgId: String?
    nonisolated(unsafe) var lastCreateCollectionEncryptedName: String?

    func createCollection(organizationId: String, encryptedName: String) async throws -> RawCollection {
        createCollectionCallCount += 1
        lastCreateCollectionOrgId = organizationId
        lastCreateCollectionEncryptedName = encryptedName
        if let err = createCollectionShouldThrow { throw err }
        return createCollectionResponse ?? RawCollection(
            id: UUID().uuidString, organizationId: organizationId, name: encryptedName
        )
    }

    nonisolated(unsafe) var renameCollectionResponse: RawCollection?
    nonisolated(unsafe) var renameCollectionShouldThrow: Error?
    nonisolated(unsafe) var renameCollectionCallCount: Int = 0

    func renameCollection(id: String, organizationId: String, encryptedName: String) async throws -> RawCollection {
        renameCollectionCallCount += 1
        if let err = renameCollectionShouldThrow { throw err }
        return renameCollectionResponse ?? RawCollection(
            id: id, organizationId: organizationId, name: encryptedName
        )
    }

    nonisolated(unsafe) var deleteCollectionShouldThrow: Error?
    nonisolated(unsafe) var deleteCollectionCallCount: Int = 0
    nonisolated(unsafe) var lastDeleteCollectionId: String?

    func deleteCollection(id: String, organizationId: String) async throws {
        deleteCollectionCallCount += 1
        lastDeleteCollectionId = id
        if let err = deleteCollectionShouldThrow { throw err }
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
