import Foundation
@testable import Macwarden

/// Test double for `MacwardenCryptoService`.
actor MockMacwardenCryptoService: MacwardenCryptoService {

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

    // MARK: - MacwardenCryptoService

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

    func decryptList(ciphers: [RawCipher]) async throws -> (items: [VaultItem], failedCount: Int) {
        (items: stubbedDecryptList, failedCount: stubbedFailedCount)
    }

    func unlockWith(keys: CryptoKeys) async {
        _isUnlocked = true
    }

    func lockVault() async {
        _isUnlocked = false
    }

    func currentKeys() throws -> CryptoKeys {
        guard _isUnlocked else { throw MacwardenCryptoServiceError.vaultLocked }
        return stubbedVaultKeys
    }

}
