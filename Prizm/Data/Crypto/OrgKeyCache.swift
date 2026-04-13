import Foundation
import os.log

// MARK: - OrgKeyCache

/// In-memory cache mapping organization IDs to their unwrapped symmetric keys.
///
/// - Security goal: keeps org key material in the Data layer behind a protocol boundary,
///   preventing exposure to the Presentation layer. Org keys are zeroed before removal
///   (Constitution §III) to reduce the heap-residency window after lock.
///
/// - Populated at sync time by `SyncRepositoryImpl` after unwrapping each org's RSA-encrypted
///   symmetric key. Cleared alongside `VaultKeyCache` on vault lock and sign-out.
///   Reference: Bitwarden Security Whitepaper §4 — "Organization Key Wrapping".
///
/// - Thread safety: declared as `actor` because it is written from the sync path
///   (background `actor SyncRepositoryImpl`) and read from `CipherMapper` via a
///   synchronous snapshot. An `actor` prevents data races under Swift 6 strict
///   concurrency checking (Constitution §II — "actor for shared mutable state in
///   Data layer").
actor OrgKeyCache {

    private let logger = Logger(subsystem: "com.prizm", category: "OrgKeyCache")

    /// Maps organization ID → unwrapped 64-byte symmetric key (encKey ‖ macKey).
    private var cache: [String: CryptoKeys] = [:]

    // MARK: - Public API

    /// Stores the org's symmetric key in the cache.
    ///
    /// - Parameters:
    ///   - key:   The unwrapped 64-byte `CryptoKeys` for the organization.
    ///   - orgId: The organization's ID string.
    func store(key: CryptoKeys, for orgId: String) {
        cache[orgId] = key
        logger.info("OrgKeyCache: stored key for org \(orgId.prefix(8), privacy: .public)…")
    }

    /// Returns a value-type snapshot of the cache for synchronous use in `CipherMapper`.
    ///
    /// Why a snapshot instead of passing the actor reference: `CipherMapper.map()` is
    /// synchronous. Passing a `[String: CryptoKeys]` value copy avoids actor-isolation
    /// crossings inside the tight per-cipher decryption loop, keeping it synchronous and
    /// non-throwing from an async perspective.
    func snapshot() -> [String: CryptoKeys] {
        cache
    }

    /// Zeros all org key material and clears the cache.
    ///
    /// Called on vault lock and sign-out alongside `VaultKeyCache.clear()`.
    /// Zeroing before clearing reduces the window during which key bytes remain on the
    /// heap after the cache is discarded (Constitution §III).
    func clear() {
        // Zero encryptionKey and macKey data for each cached org key.
        // Direct field mutation via `inout` is not available on actor-isolated stored properties;
        // we copy, zero, and discard — the original `CryptoKeys` value is replaced by the
        // `cache.removeAll()` call that follows. The zero copy ensures the bytes are overwritten
        // in memory before the allocator can reclaim them.
        for key in cache.keys {
            if var keys = cache[key] {
                keys.encryptionKey.resetBytes(in: 0..<keys.encryptionKey.count)
                keys.macKey.resetBytes(in: 0..<keys.macKey.count)
                // Overwrite the cache entry with the zeroed value before removal.
                cache[key] = keys
            }
        }
        cache.removeAll()
        logger.info("OrgKeyCache cleared — key material zeroed")
    }
}
