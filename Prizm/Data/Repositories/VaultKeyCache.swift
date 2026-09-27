import Foundation
import os.log

// MARK: - VaultKeyCache

/// In-memory cache mapping cipher IDs to their effective 64-byte symmetric keys
/// (encryptionKey ‖ macKey).
///
/// - Security goal: keeps per-cipher key material close to where it is used
///   (attachment operations) without storing it on `VaultItem` domain entities,
///   which would expose key material to the Presentation layer.
///
/// - Populated at sync time by `SyncRepositoryImpl` via `populate(keys:)`, using the
///   effective cipher keys returned by `CipherMapper`. Cleared alongside the vault
///   store on lock/sign-out.
///
/// - Thread safety: declared as `actor` because it is written from the sync path
///   (background `actor SyncRepositoryImpl`) and read from attachment operation paths
///   (`VaultKeyServiceImpl`). An `actor` prevents data races under Swift 6 strict
///   concurrency checking (Constitution §II - "actor for shared mutable state in
///   Data layer").
actor VaultKeyCache {

    private let logger = Logger(subsystem: "com.prizm", category: "VaultKeyCache")

    /// Maps cipher ID → 64-byte effective key (encryptionKey ‖ macKey).
    private var cache: [String: Data] = [:]

    // MARK: - Public API

    /// Replaces the entire key cache with the provided mapping.
    ///
    /// Called by `SyncRepositoryImpl` after sync completes. This is a wholesale
    /// replace (not a merge) so stale entries from a previous sync are evicted.
    ///
    /// - Parameter keys: Dictionary of cipher ID → 64-byte effective key.
    func populate(keys: [String: Data]) {
        cache = keys
        logger.info("VaultKeyCache populated: \(keys.count, privacy: .public) entry/entries")
    }

    /// Returns the 64-byte effective key for the given cipher ID, or `nil` if no
    /// per-item key is stored (cipher has vault-level key, or was created after
    /// the last sync and not yet in the cache).
    ///
    /// - Parameter cipherId: The vault item's ID.
    func key(for cipherId: String) -> Data? {
        cache[cipherId]
    }

    /// Stores the effective key for an item created after the last full sync.
    ///
    /// This is required for immediate attachment uploads, especially for organization
    /// items whose effective key differs from the user's personal vault key.
    func store(key: Data, for cipherId: String) {
        if var existing = cache.removeValue(forKey: cipherId) {
            existing.resetBytes(in: existing.indices)
        }
        cache[cipherId] = key
    }

    /// Zeros all key material and clears the cache.
    ///
    /// Called on vault lock and sign-out - mirrors the lifecycle of `VaultRepositoryImpl`.
    /// Zeroing before clearing reduces the window during which key bytes remain on the
    /// heap after the cache is discarded (Constitution §III).
    func clear() {
        // Remove values before zeroing them. Mutating Data through Dictionary's
        // optional _modify accessor can corrupt its CoW backing storage on macOS 26.
        while let entry = cache.popFirst() {
            var keyData = entry.value
            keyData.resetBytes(in: keyData.indices)
        }
        logger.info("VaultKeyCache cleared - key material zeroed")
    }
}
