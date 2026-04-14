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
    private let vaultKeyCache:   VaultKeyCache
    private let orgKeyCache:     OrgKeyCache

    private let logger = Logger(subsystem: "com.prizm", category: "SyncRepository")

    // MARK: - State

    private var isSyncing = false

    // MARK: - Init

    init(
        apiClient:       any PrizmAPIClientProtocol,
        crypto:          any PrizmCryptoService,
        vaultRepository: any VaultRepository,
        vaultKeyCache:   VaultKeyCache,
        orgKeyCache:     OrgKeyCache = OrgKeyCache()
    ) {
        self.apiClient       = apiClient
        self.crypto          = crypto
        self.vaultRepository = vaultRepository
        self.vaultKeyCache   = vaultKeyCache
        self.orgKeyCache     = orgKeyCache
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

        var (items, failedCount, cipherKeyMap) = try await crypto.decryptList(ciphers: syncResponse.ciphers)
        logger.info("Decrypted \(items.count) cipher(s); \(failedCount) failure(s)")
        if DebugConfig.isEnabled && failedCount > 0 {
            logger.debug("[debug] \(failedCount, privacy: .public) cipher(s) failed to decrypt — check PrizmCryptoService logs for per-cipher errors")
        }

        // Phase 2b: Populate the per-cipher key cache from keys collected during decryptList.
        // Only ciphers with a per-item key are included; vault-key-only ciphers are handled
        // by VaultKeyServiceImpl's fallback path.
        await vaultKeyCache.populate(keys: cipherKeyMap)
        logger.info("VaultKeyCache populated with \(cipherKeyMap.count, privacy: .public) per-item key(s)")

        // Phase 2b: Decrypt folder names.
        let (folders, folderFailedCount) = try await crypto.decryptFolders(folders: syncResponse.folders)
        logger.info("Decrypted \(folders.count, privacy: .public) folder(s); \(folderFailedCount, privacy: .public) failure(s)")
        if folderFailedCount > 0 {
            logger.error("decryptFolders: \(folderFailedCount, privacy: .public) folder(s) failed to decrypt")
        }

        // Phase 2c: Unwrap org keys and decrypt collection names.
        //
        // Only performed when the sync response contains organizations AND the profile
        // has a privateKey field (i.e. the user has org membership). Vaultwarden instances
        // without org support will have an empty `organizations` array and skip this block.
        //
        // Security: the decrypted RSA private key bytes are zeroed immediately after use.
        // Reference: Bitwarden Security Whitepaper §4 — "Organization Key Wrapping".
        var organizations: [Organization] = []
        var collections: [OrgCollection] = []

        if !syncResponse.organizations.isEmpty,
           let encPrivateKey = syncResponse.profile.privateKey {
            do {
                let vaultKeys = try await crypto.currentKeys()

                // Decrypt the user's RSA private key (PKCS#8 DER) from the sync profile.
                var rsaPrivateKeyBytes = try await crypto.decryptRSAPrivateKey(
                    encPrivateKey: encPrivateKey,
                    vaultKeys: vaultKeys
                )
                defer {
                    // Zero the private key bytes immediately after use (Constitution §III).
                    rsaPrivateKeyBytes.resetBytes(in: 0..<rsaPrivateKeyBytes.count)
                }

                // Unwrap each org key into OrgKeyCache.
                // Failure for a single org is logged and skipped; other orgs proceed.
                await orgKeyCache.clear()  // Fresh slate for this sync.
                for rawOrg in syncResponse.organizations {
                    do {
                        let orgKeys = try await crypto.unwrapOrgKey(
                            encOrgKey: rawOrg.key,
                            rsaPrivateKey: rsaPrivateKeyBytes
                        )
                        await orgKeyCache.store(key: orgKeys, for: rawOrg.id)
                    } catch {
                        logger.fault("Failed to unwrap org key for org \(rawOrg.id.prefix(8), privacy: .public)… — org ciphers will be skipped: \(error, privacy: .public)")
                    }
                }

                // Build domain Organization entities.
                let orgKeysSnapshot = await orgKeyCache.snapshot()
                organizations = syncResponse.organizations.compactMap { (raw: RawOrganization) in
                    guard let role = OrgRole(rawValue: raw.type) else {
                        logger.error("Unknown org role type \(raw.type, privacy: .public) for org \(raw.id.prefix(8), privacy: .public)")
                        return nil
                    }
                    return Organization(id: raw.id, name: raw.name, role: role)
                }

                // Decrypt collection names using the respective org key.
                collections = syncResponse.collections.compactMap { raw in
                    guard let orgKey = orgKeysSnapshot[raw.organizationId] else {
                        logger.error("No org key for collection \(raw.id.prefix(8), privacy: .public) (org \(raw.organizationId.prefix(8), privacy: .public))")
                        return nil
                    }
                    do {
                        let encName = try EncString(string: raw.name)
                        let nameData = try encName.decrypt(keys: orgKey)
                        guard let name = String(data: nameData, encoding: .utf8) else {
                            logger.error("Collection name not valid UTF-8 for collection \(raw.id.prefix(8), privacy: .public)")
                            return nil
                        }
                        return OrgCollection(id: raw.id, organizationId: raw.organizationId, name: name)
                    } catch {
                        logger.error("Failed to decrypt collection name for \(raw.id.prefix(8), privacy: .public): \(error, privacy: .public)")
                        return nil
                    }
                }

                // Decrypt org ciphers using the unwrapped org keys.
                // Personal ciphers were already decrypted by `decryptList` above; org ciphers
                // were skipped there because org keys were not yet available at that point.
                // We do a second pass here, using the same CipherMapper with the org key snapshot.
                let orgMapper = CipherMapper()
                var orgCipherFailedCount = 0
                for (index, cipher) in syncResponse.ciphers.enumerated() {
                    guard cipher.organizationId != nil else { continue }
                    do {
                        let (item, cipherKey) = try orgMapper.map(
                            raw: cipher, vaultKeys: vaultKeys, orgKeys: orgKeysSnapshot
                        )
                        items.append(item)
                        if cipher.key != nil { cipherKeyMap[cipher.id] = cipherKey }
                    } catch CipherMapperError.organisationCipherSkipped {
                        // Org key not in snapshot — org key unwrap failed for this org.
                        orgCipherFailedCount += 1
                        if DebugConfig.isEnabled {
                            logger.debug("[debug] org cipher[\(index, privacy: .public)] skipped — org key unavailable")
                        }
                    } catch {
                        orgCipherFailedCount += 1
                        logger.error("Org cipher decryption failed at index \(index, privacy: .public): \(error, privacy: .public)")
                    }
                }
                // Refresh the VaultKeyCache to include per-item keys from org ciphers.
                await vaultKeyCache.populate(keys: cipherKeyMap)

                logger.info("Org sync: \(organizations.count) org(s), \(collections.count) collection(s), \(orgCipherFailedCount, privacy: .public) org cipher(s) skipped")
            } catch {
                logger.error("Org key sync failed — org ciphers unavailable this session: \(error, privacy: .public)")
                // Non-fatal: personal items still work without org support.
            }
        }

        // Phase 3: Populate the in-memory vault store.
        let syncedAt = Date()
        await vaultRepository.populate(
            items:         items,
            folders:       folders,
            organizations: organizations,
            collections:   collections,
            syncedAt:      syncedAt
        )

        return SyncResult(
            syncedAt:              syncedAt,
            totalCiphers:          totalCiphers,
            failedDecryptionCount: failedCount
        )
    }
}
