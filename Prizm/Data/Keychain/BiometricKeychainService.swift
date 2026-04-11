import Foundation

/// Provides biometric-gated read, write, and delete access to the macOS Keychain.
///
/// Separate from `KeychainService` because `kSecAccessControl` (used here for
/// `.biometryCurrentSet`) and `kSecAttrAccessible` (used by `KeychainServiceImpl`)
/// are mutually exclusive on the same SecItem — see design Decision 3.
///
/// This is a Data-layer implementation detail consumed only by `AuthRepositoryImpl`.
/// It MUST NOT be placed in the Domain layer (Constitution §II).
protocol BiometricKeychainService {
    /// Write `data` for `key` behind a biometric access control gate.
    func writeBiometric(data: Data, key: String) throws
    /// Read and return the data stored for `key`, triggering biometric authentication.
    /// - Throws: `KeychainError.itemNotFound` if no item exists.
    func readBiometric(key: String) async throws -> Data
    /// Delete the item for `key`. No-ops silently when the item does not exist.
    func deleteBiometric(key: String) throws
}
