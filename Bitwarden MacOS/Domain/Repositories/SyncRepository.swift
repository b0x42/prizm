import Foundation

/// Fetches the encrypted vault from the server and populates the in-memory store.
/// Called once per unlock event (after login and after every relaunch + unlock).
/// No background sync, periodic polling, or user-triggered re-sync in v1.
/// Implemented by `SyncRepositoryImpl` in the Data layer.
protocol SyncRepository: AnyObject {

    /// Syncs the vault from the server.
    ///
    /// Sequence:
    /// 1. GET `/sync?excludeDomains=true` → encrypted JSON.
    /// 2. Decrypt each cipher via `BitwardenCryptoServiceImpl`.
    /// 3. Populate `VaultRepositoryImpl` in-memory store.
    ///
    /// - Parameter progress: Callback fired with human-readable status messages
    ///   (minimum: "Syncing vault…" then "Decrypting…"). Called on the calling actor.
    /// - Returns: `SyncResult` with counts of synced and failed ciphers.
    /// - Throws: `SyncError` on catastrophic failure. Individual cipher failures
    ///   are skipped and counted in `SyncResult.failedDecryptionCount`.
    func sync(progress: @escaping (String) -> Void) async throws -> SyncResult
}

// MARK: - Supporting types

struct SyncResult {
    let syncedAt: Date
    let totalCiphers: Int
    let failedDecryptionCount: Int
}

enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case serverUnreachable(URL)
    /// Access token is invalid or expired; user must sign in again.
    case unauthorized
    /// Symmetric key decryption failed catastrophically (not per-cipher).
    case decryptionFailed
    /// A second `sync()` call arrived while one is already in flight.
    case syncInProgress

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection."
        case .serverUnreachable(let url):
            return "Cannot reach \(url.host ?? url.absoluteString)."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .decryptionFailed:
            return "Failed to decrypt your vault. Please sign in again."
        case .syncInProgress:
            return "Sync is already in progress."
        }
    }
}
