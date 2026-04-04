import Foundation

// MARK: - VaultKeyService

/// Provides the effective cipher key for a given vault item, used by attachment
/// upload and download use cases.
///
/// The returned 64-byte `Data` is `encryptionKey ‖ macKey` — the same layout that
/// `CryptoKeys` stores as two separate 32-byte fields. Passing raw `Data` rather than
/// `CryptoKeys` keeps the Domain layer free of Data-layer types (Constitution §II).
///
/// Implemented by `VaultKeyServiceImpl` in the Data layer. Foundation-only — no crypto
/// imports belong in the Domain layer.
protocol VaultKeyService: Sendable {

    /// Returns the 64-byte effective cipher key for the vault item identified by `cipherId`.
    ///
    /// - If the cipher has a per-item key stored in `VaultKeyCache` (populated at sync time),
    ///   that key is returned.
    /// - If the cache has no entry (cipher was created after last sync, or has no per-item key),
    ///   the vault-level key is returned as a fallback.
    ///
    /// - Parameter cipherId: The ID of the vault item.
    /// - Returns: 64-byte `Data` (encryptionKey ‖ macKey).
    /// - Throws: `VaultError.vaultLocked` when the vault is locked and no fallback is available.
    func cipherKey(for cipherId: String) async throws -> Data
}
