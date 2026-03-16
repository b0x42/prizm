import Foundation
@testable import Bitwarden_MacOS

/// Test double for `BitwardenCryptoService`.
///
/// Conforms to the `Actor` requirement via `@globalActor`-style isolation on `@MainActor`.
/// Since tests run on `@MainActor` this provides the necessary actor isolation.
@MainActor
final class MockBitwardenCryptoService: BitwardenCryptoService {

    // MARK: - State

    private(set) var _isUnlocked: Bool = false
    nonisolated var isUnlocked: Bool { _isUnlocked }

    // MARK: - Stubs

    var stubbedMasterKey:    Data   = Data(count: 32)
    var stubbedStretchedKeys = CryptoKeys(
        encryptionKey: Data(count: 32),
        macKey:        Data(count: 32)
    )
    var stubbedServerHash:   String = "stubServerHash=="
    var stubbedVaultKeys    = CryptoKeys(
        encryptionKey: Data(count: 32),
        macKey:        Data(count: 32)
    )
    /// Returned by `decryptList` as successfully decrypted items.
    var stubbedDecryptList:  [VaultItem] = []
    /// Returned by `decryptList` as the failure count.
    var stubbedFailedCount:  Int = 0

    // MARK: - BitwardenCryptoService

    func makeMasterKey(password: String, email: String, kdf: KdfParams) async throws -> Data {
        stubbedMasterKey
    }

    func stretchKey(masterKey: Data) async throws -> CryptoKeys {
        stubbedStretchedKeys
    }

    func makeServerHash(masterKey: Data, password: String) async throws -> String {
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
}
