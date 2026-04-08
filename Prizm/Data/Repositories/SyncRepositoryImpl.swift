import Foundation
import os.log

// MARK: - SyncRepositoryImpl

/// Concrete implementation of `SyncRepository`.
///
/// Fetches the encrypted vault from the Bitwarden server, decrypts personal ciphers
/// via `PrizmCryptoServiceImpl.decryptList`, and populates the in-memory `VaultRepository`.
///
/// Organisation ciphers (`organizationId != nil`) are skipped in v1. The encrypted
/// private key needed to decrypt per-org symmetric keys is present in the token response
/// (`PrivateKey` field) but RSA decryption is not yet implemented.
// TODO: support organisation ciphers — requires RSA private-key decryption of the
// per-org symmetric key wrapped in the account's RSA keypair.
// Deferred: Security.framework RSA-OAEP + the user's private key (from tokenResponse.privateKey)
// must be decrypted with the vault symmetric key before org ciphers can be read.
///
/// Individual cipher decryption failures are non-fatal — they are counted and logged
/// but the remaining ciphers are still stored.
///
/// Concurrent calls: the second caller receives `SyncError.syncInProgress`.
actor SyncRepositoryImpl: SyncRepository {

    // MARK: - Dependencies

    private let apiClient:       any PrizmAPIClientProtocol
    private let crypto:          any PrizmCryptoService
    private let vaultRepository: any VaultRepository

    private let logger = Logger(subsystem: "com.prizm", category: "SyncRepository")

    // MARK: - State

    private var isSyncing = false

    // MARK: - Init

    init(
        apiClient:       any PrizmAPIClientProtocol,
        crypto:          any PrizmCryptoService,
        vaultRepository: any VaultRepository
    ) {
        self.apiClient       = apiClient
        self.crypto          = crypto
        self.vaultRepository = vaultRepository
    }

    // MARK: - SyncRepository

    func sync(progress: @Sendable @escaping (String) -> Void) async throws -> SyncResult {
        guard !isSyncing else {
            logger.info("sync() called while already in progress")
            throw SyncError.syncInProgress
        }
        isSyncing = true
        defer { isSyncing = false }

        // Phase 1: Fetch encrypted vault from server.
        progress("Syncing vault…")
        logger.info("Starting vault sync")

        let syncResponse: SyncResponse
        do {
            syncResponse = try await apiClient.fetchSync()
        } catch let err as APIError {
            switch err {
            case .httpError(statusCode: 401, _):
                throw SyncError.unauthorized
            default:
                throw SyncError.networkUnavailable
            }
        } catch {
            throw SyncError.networkUnavailable
        }

        let totalCiphers = syncResponse.ciphers.count
        logger.info("Fetched \(totalCiphers) cipher(s)")

        if DebugConfig.isEnabled {
            // Log counts by cipher type to help diagnose sync issues (e.g. unexpected
            // type integers from a non-standard server). Values are type ints only —
            // no cipher names, URLs, or other vault content is logged.
            let typeCounts = syncResponse.ciphers.reduce(into: [Int: Int]()) { acc, c in
                acc[c.type, default: 0] += 1
            }
            let orgCount = syncResponse.ciphers.filter { $0.organizationId != nil }.count
            let typeNames = [1: "login", 2: "identity", 3: "note", 4: "card", 5: "sshKey"]
            let breakdown = typeCounts
                .sorted(by: { $0.key < $1.key })
                .map { "\(typeNames[$0.key] ?? "type\($0.key)")=\($0.value)" }
                .joined(separator: " ")
            logger.debug("[debug] cipher breakdown: \(breakdown, privacy: .public) org(skipped)=\(orgCount, privacy: .public)")
        }

        // Phase 2: Decrypt personal ciphers via the crypto service.
        progress("Decrypting \(totalCiphers) item(s)…")

        let (items, failedCount) = try await crypto.decryptList(ciphers: syncResponse.ciphers)
        logger.info("Decrypted \(items.count) cipher(s); \(failedCount) failure(s)")
        if DebugConfig.isEnabled && failedCount > 0 {
            logger.debug("[debug] \(failedCount, privacy: .public) cipher(s) failed to decrypt — check PrizmCryptoService logs for per-cipher errors")
        }

        // Phase 2b: Decrypt folder names.
        logger.info("Decrypting \(syncResponse.folders.count, privacy: .public) folder(s)")
        let (folders, folderFailedCount) = try await crypto.decryptFolders(folders: syncResponse.folders)
        logger.info("Decrypted \(folders.count, privacy: .public) folder(s); \(folderFailedCount, privacy: .public) failure(s)")
        if folderFailedCount > 0 {
            logger.error("decryptFolders: \(folderFailedCount, privacy: .public) folder(s) failed to decrypt")
        }

        // Phase 3: Populate the in-memory vault store.
        let syncedAt = Date()
        await vaultRepository.populate(items: items, folders: folders, syncedAt: syncedAt)

        return SyncResult(
            syncedAt:              syncedAt,
            totalCiphers:          totalCiphers,
            failedDecryptionCount: failedCount
        )
    }
}
