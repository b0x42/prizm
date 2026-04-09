import Foundation
import os.log

// MARK: - VaultKeyServiceImpl

/// Concrete implementation of `VaultKeyService`.
///
/// Returns the effective 64-byte cipher key (encryptionKey ‖ macKey) for a given
/// vault item. Key resolution order:
///
/// 1. **Cache hit** — If `VaultKeyCache` has a per-item key for the cipher ID
///    (populated at sync time by `SyncRepositoryImpl`), return it directly.
/// 2. **Cache miss** — If the cache has no entry for the cipher ID, fall back to the
///    vault-level key: call `crypto.currentKeys()` and concatenate
///    `keys.encryptionKey + keys.macKey` → 64-byte `Data`. This handles:
///    - Ciphers with no per-item key (use vault-level key directly, per Bitwarden spec).
///    - Newly created ciphers that have not yet appeared in a sync response.
///
/// **Important**: a missing cache entry does NOT indicate a locked vault. The vault-locked
/// condition is detected only by `crypto.currentKeys()` throwing
/// `PrizmCryptoServiceError.vaultLocked`, which is translated to `VaultError.vaultLocked`.
///
/// - Security goal: prevents key material from reaching the Presentation layer by
///   resolving keys only at the Data/Domain boundary (Constitution §II/§III).
/// - Algorithm: AES-256-CBC key (32 bytes) ‖ HMAC-SHA256 key (32 bytes) per
///   Bitwarden Security Whitepaper §4.
/// - Deviations: none. The 64-byte concatenation format matches the Bitwarden client
///   reference implementation.
/// - What is NOT done: no key material is persisted beyond the vault lock lifecycle;
///   `VaultKeyCache` is cleared on lock alongside `VaultRepositoryImpl`.
final class VaultKeyServiceImpl: VaultKeyService {

    private let cache:  VaultKeyCache
    private let crypto: any PrizmCryptoService

    private let logger = Logger(subsystem: "com.prizm", category: "attachments")

    init(cache: VaultKeyCache, crypto: any PrizmCryptoService) {
        self.cache  = cache
        self.crypto = crypto
    }

    func cipherKey(for cipherId: String) async throws -> Data {
        // 1. Try the per-item key cache (populated at sync time).
        if let cachedKey = await cache.key(for: cipherId) {
            return cachedKey
        }

        // 2. Cache miss — fall back to the vault-level key.
        // A missing cache entry is NOT a sign of a locked vault; it means the cipher
        // either has no per-item key, or was created after the last sync.
        logger.debug("VaultKeyServiceImpl: no per-item key for cipher \(cipherId, privacy: .public) — using vault key")

        let keys: CryptoKeys
        do {
            keys = try await crypto.currentKeys()
        } catch PrizmCryptoServiceError.vaultLocked {
            logger.error("VaultKeyServiceImpl: vault is locked — cannot resolve cipher key")
            throw VaultError.vaultLocked
        }

        // Concatenate encryptionKey ‖ macKey to form the 64-byte effective cipher key.
        // Both fields are 32 bytes each (Constitution §II — CryptoKeys struct).
        return keys.encryptionKey + keys.macKey
    }
}
