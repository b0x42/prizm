import Foundation
@testable import Prizm

/// Test double for `PrizmCryptoService`.
actor MockPrizmCryptoService: PrizmCryptoService {

    // MARK: - State
    // nonisolated(unsafe) allows tests to read/write without await — safe in single-threaded tests.

    nonisolated(unsafe) var _isUnlocked: Bool = false
    nonisolated var isUnlocked: Bool { _isUnlocked }

    // MARK: - Stubs

    nonisolated(unsafe) var stubbedMasterKey:    Data   = Data(count: 32)
    nonisolated(unsafe) var stubbedStretchedKeys = CryptoKeys(
        encryptionKey: Data(count: 32),
        macKey:        Data(count: 32)
    )
    nonisolated(unsafe) var stubbedServerHash:   String = "stubServerHash=="
    nonisolated(unsafe) var stubbedVaultKeys    = CryptoKeys(
        encryptionKey: Data(count: 32),
        macKey:        Data(count: 32)
    )
    nonisolated(unsafe) var stubbedDecryptList:  [VaultItem] = []
    nonisolated(unsafe) var stubbedFailedCount:  Int = 0
    nonisolated(unsafe) var stubbedFolders:      [Folder] = []

    // MARK: - PrizmCryptoService

    func makeMasterKey(password: Data, email: String, kdf: KdfParams) async throws -> Data {
        stubbedMasterKey
    }

    func stretchKey(masterKey: Data) async throws -> CryptoKeys {
        stubbedStretchedKeys
    }

    func makeServerHash(masterKey: Data, password: Data) async throws -> String {
        stubbedServerHash
    }

    func decryptSymmetricKey(encUserKey: String, stretchedKeys: CryptoKeys) async throws -> CryptoKeys {
        stubbedVaultKeys
    }

    func decryptList(ciphers: [RawCipher]) async throws -> (items: [VaultItem], failedCount: Int, cipherKeys: [String: Data]) {
        (items: stubbedDecryptList, failedCount: stubbedFailedCount, cipherKeys: [:])
    }

    func decryptFolders(folders: [RawFolder]) async throws -> (folders: [Folder], failedCount: Int) {
        (folders: stubbedFolders, failedCount: 0)
    }

    func unlockWith(keys: CryptoKeys) async {
        _isUnlocked = true
    }

    func lockVault() async {
        _isUnlocked = false
    }

    func currentKeys() throws -> CryptoKeys {
        guard _isUnlocked else { throw PrizmCryptoServiceError.vaultLocked }
        return stubbedVaultKeys
    }

    // MARK: - Org key crypto stubs

    nonisolated(unsafe) var stubbedRSAPrivateKey: Data = Data(count: 32)
    nonisolated(unsafe) var stubbedOrgKeys: [String: CryptoKeys] = [:]

    func decryptRSAPrivateKey(encPrivateKey: String, vaultKeys: CryptoKeys) throws -> Data {
        stubbedRSAPrivateKey
    }

    func unwrapOrgKey(encOrgKey: String, rsaPrivateKey: Data) throws -> CryptoKeys {
        // Return a deterministic stub org key for tests.
        CryptoKeys(encryptionKey: Data(count: 32), macKey: Data(count: 32))
    }

    // MARK: - Attachment crypto stubs

    nonisolated(unsafe) var stubbedAttachmentKey: Data = Data(count: 32)
    nonisolated(unsafe) var stubbedEncryptedData: Data = Data()
    nonisolated(unsafe) var stubbedDecryptedData: Data = Data()
    nonisolated(unsafe) var stubbedEncAttachmentKey: String = "2.stubEncKey|stub|stub"
    nonisolated(unsafe) var stubbedDecAttachmentKey: Data = Data(count: 32)
    nonisolated(unsafe) var stubbedEncFileName: String = "2.stubName|stub|stub"

    nonisolated func generateAttachmentKey() throws -> Data { stubbedAttachmentKey }
    nonisolated func encryptData(_ data: Data, attachmentKey: Data) throws -> Data { stubbedEncryptedData }
    nonisolated func decryptData(_ data: Data, attachmentKey: Data) throws -> Data { stubbedDecryptedData }
    nonisolated func encryptAttachmentKey(_ key: Data, cipherKey: CryptoKeys) throws -> String { stubbedEncAttachmentKey }
    nonisolated func decryptAttachmentKey(_ encString: String, cipherKey: CryptoKeys) throws -> Data { stubbedDecAttachmentKey }
    nonisolated func encryptFileName(_ name: String, cipherKey: CryptoKeys) throws -> String { stubbedEncFileName }

}
