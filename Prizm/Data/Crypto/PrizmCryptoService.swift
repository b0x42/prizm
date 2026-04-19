import Foundation
import CommonCrypto
import CryptoKit
import Security
import Argon2Swift
import os.log

// MARK: - PrizmCryptoServiceError

/// Errors thrown by `PrizmCryptoService` operations.
nonisolated enum PrizmCryptoServiceError: Error, Equatable {
    /// PBKDF2 or Argon2id key derivation failed.
    case kdfFailed
    /// HKDF key expansion failed.
    case hkdfFailed
    /// The encUserKey EncString could not be parsed or decrypted.
    case invalidEncUserKey
    /// The decrypted user key is not 64 bytes (encKey + macKey).
    case invalidSymmetricKeyLength
    /// The vault is locked — no key material is available.
    case vaultLocked
}

// MARK: - PrizmCryptoService Protocol

/// Provides cryptographic operations for the Bitwarden vault:
/// key derivation, key stretching, server hash computation, and vault lock/unlock.
///
/// Implemented as an `actor` to protect the in-memory key material from data races.
/// All async methods must be called with `await`.
protocol PrizmCryptoService: Actor {

    /// Whether the vault is currently unlocked (key material is in memory).
    var isUnlocked: Bool { get }

    /// Derives a 32-byte master key from the user's email + password using the
    /// specified KDF (PBKDF2-SHA256 or Argon2id).
    ///
    /// Per the Bitwarden Security Whitepaper §4: the master key is the root secret
    /// from which all other keys are derived.  It is **never** sent to the server.
    ///
    /// - Security goal: accepting `Data` (not `String`) lets the caller zero the
    ///   password bytes after the KDF call returns, reducing the window during which
    ///   plaintext password bytes live in the heap (Constitution §III). `String` is
    ///   immutable and cannot be reliably zeroed.
    ///
    /// - Parameters:
    ///   - password: The user's master password as UTF-8 bytes.
    ///   - email:    The user's lowercase email address (used as the PBKDF2 salt).
    ///   - kdf:      KDF parameters (algorithm, iterations, optional memory/parallelism).
    /// - Returns: 32-byte master key `Data`.
    func makeMasterKey(password: Data, email: String, kdf: KdfParams) async throws -> Data

    /// Stretches a 32-byte master key into a 64-byte `CryptoKeys` pair using HKDF
    /// (RFC 5869) with independent "enc" and "mac" info labels.
    ///
    /// Per the Bitwarden Security Whitepaper §4: "Key Stretching" — the stretched
    /// key provides independent encryption and MAC keys so that the two operations
    /// are cryptographically separated (NIST SP 800-107 §5.3).
    ///
    /// - Parameter masterKey: 32-byte master key.
    /// - Returns: `CryptoKeys` with a 32-byte `encryptionKey` and 32-byte `macKey`.
    func stretchKey(masterKey: Data) async throws -> CryptoKeys

    /// Computes the server authentication hash sent to the identity server during login.
    ///
    /// Per the Bitwarden Security Whitepaper §4: serverHash =
    ///   PBKDF2-SHA256(masterKey, password, iterations=1, len=32), then base64-encoded.
    ///
    /// This value proves knowledge of the master password without revealing the master
    /// key itself.  The server never stores the master key or the plaintext password.
    ///
    /// - Parameters:
    ///   - masterKey: 32-byte derived master key.
    ///   - password:  The user's master password as UTF-8 bytes (used as the PBKDF2 "salt").
    /// - Returns: Base64-encoded 32-byte hash string (44 chars with padding).
    func makeServerHash(masterKey: Data, password: Data) async throws -> String

    /// Decrypts the `encUserKey` EncString (from the sync response profile) using the
    /// stretched master keys, and returns the 64-byte vault symmetric `CryptoKeys`.
    ///
    /// Per the Bitwarden Security Whitepaper §5: the encUserKey is a Type-2 EncString
    /// that contains the 64-byte user symmetric key (encKey || macKey).
    ///
    /// - Parameters:
    ///   - encUserKey:    The EncString from `SyncResponse.profile.key`.
    ///   - stretchedKeys: The stretched master key pair used to decrypt it.
    /// - Returns: The 64-byte vault `CryptoKeys`.
    func decryptSymmetricKey(encUserKey: String, stretchedKeys: CryptoKeys) async throws -> CryptoKeys

    /// Decrypts a list of raw ciphers using the current vault keys.
    ///
    /// Organisation ciphers (`organizationId != nil`) are silently skipped in v1.
    /// Per-cipher decryption failures are non-fatal: failed items are excluded and counted.
    ///
    /// - Parameter ciphers: Raw encrypted ciphers from the sync response.
    /// - Returns: Tuple of successfully decrypted `VaultItem`s and a failure count.
    /// - Throws: `PrizmCryptoServiceError.vaultLocked` if the vault is not unlocked.
    func decryptList(ciphers: [RawCipher]) async throws -> (items: [VaultItem], failedCount: Int, cipherKeys: [String: Data])

    /// Decrypts folder names from the sync response.
    ///
    /// Per-folder decryption failures are non-fatal: failed folders are excluded and counted.
    /// - Parameter folders: Raw encrypted folders from the sync response.
    /// - Returns: Tuple of successfully decrypted `Folder`s and a failure count.
    /// - Throws: `PrizmCryptoServiceError.vaultLocked` if the vault is not unlocked.
    func decryptFolders(folders: [RawFolder]) async throws -> (folders: [Folder], failedCount: Int)

    /// Loads `keys` into memory, marking the vault as unlocked.
    func unlockWith(keys: CryptoKeys) async

    /// Zeroes and discards all in-memory key material, locking the vault.
    ///
    /// After this call, `isUnlocked` returns `false` and any attempt to decrypt
    /// vault items will throw `PrizmCryptoServiceError.vaultLocked`.
    func lockVault() async

    /// Returns the current vault symmetric key pair for callers that need to perform
    /// encryption (e.g. the reverse cipher mapper for PUT /ciphers/{id}).
    ///
    /// - Throws: `PrizmCryptoServiceError.vaultLocked` if the vault is locked.
    func currentKeys() async throws -> CryptoKeys

    // MARK: - Org key crypto (org-support)

    /// Decrypts the user's RSA private key from its EncString representation.
    ///
    /// The profile's `privateKey` EncString is a Type-2 (AES-256-CBC + HMAC-SHA256) EncString
    /// encrypted with the vault symmetric key. Decrypting it yields raw PKCS#8 DER bytes for
    /// the user's RSA-2048 private key.
    ///
    /// - Security goal: the decrypted private key bytes are used only within `unwrapOrgKey`
    ///   to decrypt org symmetric keys. The caller must zero the returned `Data` after use.
    ///   The bytes are NEVER logged (Constitution §III, §VII).
    ///
    /// - Parameters:
    ///   - encPrivateKey: EncString from `SyncResponse.profile.privateKey`.
    ///   - vaultKeys:     The vault symmetric `CryptoKeys` used to decrypt it.
    /// - Returns: Raw PKCS#8 DER bytes of the RSA private key.
    /// - Throws: `PrizmCryptoServiceError` on decryption failure.
    func decryptRSAPrivateKey(encPrivateKey: String, vaultKeys: CryptoKeys) async throws -> Data

    /// Unwraps an organization's symmetric key using the user's RSA private key.
    ///
    /// The org key EncString (Type-4) contains the org's 64-byte symmetric key encrypted
    /// with RSA-OAEP-SHA1 using the user's RSA-2048 public key.
    ///
    /// - Algorithm: `SecKeyCreateDecryptedData` with `kSecKeyAlgorithmRSAEncryptionOAEPSHA1`.
    ///   SHA-1 is used here because it is the Bitwarden protocol requirement (Security Whitepaper §4),
    ///   not a free choice. RSA-OAEP with SHA-1 remains secure for key transport when used as
    ///   specified; the weakness of standalone SHA-1 collision resistance does not apply here.
    ///   Reference: Bitwarden Security Whitepaper §4 — "Organization Key Wrapping".
    ///
    /// - PKCS#8 stripping: Bitwarden stores the RSA private key as a PKCS#8-wrapped DER blob.
    ///   `SecKeyCreateWithData` requires the raw RSA key material without the PKCS#8 header.
    ///   The header is stripped by skipping the outer SEQUENCE → SEQUENCE (AlgorithmIdentifier)
    ///   → BITSTRING wrapper to reach the raw PKCS#1 RSAPrivateKey DER bytes.
    ///
    /// - What is NOT done: This function does not cache the RSA private key — callers must
    ///   pass the already-decrypted key bytes and zero them immediately after use.
    ///
    /// - Parameters:
    ///   - encOrgKey:     Type-4 EncString from `RawOrganization.key`.
    ///   - rsaPrivateKey: PKCS#8 DER bytes of the user's RSA private key (from `decryptRSAPrivateKey`).
    /// - Returns: The 64-byte `CryptoKeys` pair for the organization.
    /// - Throws: `PrizmCryptoServiceError` on RSA decryption failure.
    func unwrapOrgKey(encOrgKey: String, rsaPrivateKey: Data) async throws -> CryptoKeys

    // MARK: - Attachment crypto (vault-document-storage)
    //
    // Declared `nonisolated` so they can be called synchronously from any concurrency
    // context — they access no actor-isolated state and can therefore be tested via
    // `any PrizmCryptoService` without requiring `await`.

    /// Generates a cryptographically random 64-byte per-attachment key.
    ///
    /// See `AttachmentCrypto.swift` for the full specification.
    nonisolated func generateAttachmentKey() throws -> Data

    /// Encrypts file data using AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC).
    /// Binary layout: `IV (16) ‖ ciphertext ‖ HMAC-SHA256 (32)`.
    nonisolated func encryptData(_ data: Data, attachmentKey: Data) throws -> Data

    /// Decrypts a binary blob produced by `encryptData`.
    /// Verifies HMAC before decrypting (Encrypt-then-MAC).
    nonisolated func decryptData(_ data: Data, attachmentKey: Data) throws -> Data

    /// Wraps the per-attachment key as a type-2 EncString using the cipher's `CryptoKeys`.
    nonisolated func encryptAttachmentKey(_ key: Data, cipherKey: CryptoKeys) throws -> String

    /// Unwraps a per-attachment key from its EncString representation.
    nonisolated func decryptAttachmentKey(_ encString: String, cipherKey: CryptoKeys) throws -> Data

    /// Encrypts a plaintext file name as a type-2 EncString for upload metadata.
    nonisolated func encryptFileName(_ name: String, cipherKey: CryptoKeys) throws -> String
}

// MARK: - PrizmCryptoServiceImpl

/// Concrete implementation of `PrizmCryptoService`.
///
/// Key derivation algorithms:
/// - **PBKDF2-SHA256** (RFC 8018 §5.2, NIST SP 800-132): used when
///   `KdfParams.type == .pbkdf2`.  Implemented via CommonCrypto `CCKeyDerivationPBKDF`.
/// - **Argon2id** (RFC 9106): used when `KdfParams.type == .argon2id`.
///   Delegated to the vendored `Argon2Swift` library.
/// - **HKDF** (RFC 5869): used for key stretching in `stretchKey`.  Implemented
///   using CryptoKit `HKDF<SHA256>` which is the recommended approach on Apple
///   platforms (CryptoKit is FIPS 140-3 certified since macOS 12).
actor PrizmCryptoServiceImpl: PrizmCryptoService {

    private let logger = Logger(subsystem: "com.prizm", category: "PrizmCryptoService")

    // MARK: - State

    /// The decrypted vault symmetric key pair, non-nil only when unlocked.
    /// Stored as `var` so it can be zeroed on lock.
    private var keys: CryptoKeys?

    var isUnlocked: Bool { keys != nil }

    // MARK: - Lock / Unlock

    func unlockWith(keys: CryptoKeys) {
        self.keys = keys
        logger.info("Vault unlocked")
    }

    func lockVault() {
        // Zero both key buffers in the actor's stored property before releasing.
        // `self.keys` is the primary reference — zeroing it reduces the window during
        // which key material exists in a heap dump (Constitution §III). Any Data copies
        // passed to in-flight decryption tasks retain their own CoW buffers until those
        // tasks complete; those copies cannot be zeroed here.
        if keys != nil {
            keys!.encryptionKey.resetBytes(in: 0..<keys!.encryptionKey.count)
            keys!.macKey.resetBytes(in: 0..<keys!.macKey.count)
        }
        keys = nil
        logger.info("Vault locked — key material zeroed")
    }

    func currentKeys() throws -> CryptoKeys {
        guard let vaultKeys = keys else {
            throw PrizmCryptoServiceError.vaultLocked
        }
        return vaultKeys
    }

    // MARK: - decryptList

    func decryptList(ciphers: [RawCipher]) async throws -> (items: [VaultItem], failedCount: Int, cipherKeys: [String: Data]) {
        guard let vaultKeys = keys else {
            throw PrizmCryptoServiceError.vaultLocked
        }
        logger.info("decryptList: starting with \(ciphers.count) ciphers")
        let mapper = CipherMapper()
        var items: [VaultItem] = []
        var cipherKeyMap: [String: Data] = [:]
        var failedCount = 0
        for (index, cipher) in ciphers.enumerated() {
            if cipher.organizationId != nil {
                if DebugConfig.isEnabled {
                    logger.debug("[debug] cipher[\(index, privacy: .public)] skipped — organizationId present")
                }
                continue
            }
            do {
                let (item, cipherKey) = try mapper.map(raw: cipher, keys: vaultKeys)
                items.append(item)
                // Only cache per-item keys; vault-key-only ciphers are handled by
                // VaultKeyServiceImpl fallback and excluded to avoid duplicate storage.
                if cipher.key != nil {
                    cipherKeyMap[cipher.id] = cipherKey
                }
                if DebugConfig.isEnabled {
                    let rawAttachmentCount = cipher.attachments?.count ?? 0
                    let mappedAttachmentCount = item.attachments.count
                    logger.debug("[debug] cipher[\(index, privacy: .public)] OK — type=\(cipher.type, privacy: .public) id=\(cipher.id, privacy: .private) rawAttachments=\(rawAttachmentCount, privacy: .public) mappedAttachments=\(mappedAttachmentCount, privacy: .public)")
                }
            } catch {
                failedCount += 1
                logger.error("decryptList: Cipher decryption failed at index \(index, privacy: .public)")
                if DebugConfig.isEnabled {
                    logger.debug("[debug] cipher[\(index, privacy: .public)] FAILED — type=\(cipher.type, privacy: .public) error=\(error, privacy: .public)")
                }
            }
        }
        logger.info("decryptList: completed — \(items.count) succeeded, \(failedCount) failed")
        return (items: items, failedCount: failedCount, cipherKeys: cipherKeyMap)
    }

    // MARK: - decryptFolders

    func decryptFolders(folders rawFolders: [RawFolder]) async throws -> (folders: [Folder], failedCount: Int) {
        guard let vaultKeys = keys else {
            throw PrizmCryptoServiceError.vaultLocked
        }
        var folders: [Folder] = []
        var failedCount = 0
        for raw in rawFolders {
            do {
                let enc  = try EncString(string: raw.name)
                let data = try enc.decrypt(keys: vaultKeys)
                guard let name = String(data: data, encoding: .utf8) else {
                    failedCount += 1
                    continue
                }
                folders.append(Folder(id: raw.id, name: name))
            } catch {
                failedCount += 1
                logger.error("decryptFolders: folder decryption failed for id \(raw.id, privacy: .public)")
            }
        }
        return (folders: folders, failedCount: failedCount)
    }

    // MARK: - makeMasterKey

    func makeMasterKey(password: Data, email: String, kdf: KdfParams) async throws -> Data {
        guard let emailData = email.lowercased().data(using: .utf8) else {
            throw PrizmCryptoServiceError.kdfFailed
        }

        logger.debug("KDF: using \(String(describing: kdf.type)) with \(kdf.iterations) iterations")

        switch kdf.type {
        case .pbkdf2:
            return try pbkdf2SHA256(
                password: password,
                salt:     emailData,
                rounds:   UInt32(kdf.iterations),
                keyLen:   32
            )
        case .argon2id:
            // Argon2id requires memory + parallelism params
            guard let memory      = kdf.memory,
                  let parallelism = kdf.parallelism else {
                throw PrizmCryptoServiceError.kdfFailed
            }
            return try argon2idDerive(
                password:    password,
                salt:        emailData,
                iterations:  kdf.iterations,
                memory:      memory,
                parallelism: parallelism
            )
        }
    }

    // MARK: - stretchKey

    func stretchKey(masterKey: Data) async throws -> CryptoKeys {
        // Bitwarden Key Stretching (Security Whitepaper §4):
        //   encKey = HKDF-Expand(PRK=masterKey, info="enc", len=32)
        //   macKey = HKDF-Expand(PRK=masterKey, info="mac", len=32)
        //
        // IMPORTANT: Bitwarden uses HKDF-Expand ONLY (RFC 5869 §2.3) — it skips the
        // Extract step and uses the 32-byte masterKey directly as the PRK.
        // CryptoKit's HKDF.deriveKey() performs full HKDF (Extract + Expand), which
        // produces different output and must NOT be used here.
        //
        // Reference: bitwarden/sdk-internal CryptoService.stretchKey / jslib hkdfExpand
        let encKey = hkdfExpand(prk: masterKey, info: Data("enc".utf8), outputLength: 32)
        let macKey = hkdfExpand(prk: masterKey, info: Data("mac".utf8), outputLength: 32)
        return CryptoKeys(encryptionKey: encKey, macKey: macKey)
    }

    /// HKDF-Expand only (RFC 5869 §2.3) for a single output block (≤ 32 bytes).
    ///
    /// `T(1) = HMAC-SHA256(key=PRK, data=info || 0x01)`
    ///
    /// Bitwarden passes the masterKey directly as PRK, bypassing the Extract phase.
    /// This matches the behaviour of `CryptoFunctionService.hkdfExpand` in bitwarden/sdk.
    private func hkdfExpand(prk: Data, info: Data, outputLength: Int) -> Data {
        precondition(outputLength <= 32, "Single-block HKDF-Expand limited to 32 bytes (SHA-256 hash length)")
        let input = info + Data([0x01])   // T(0)=empty || info || counter=1
        let mac   = HMAC<SHA256>.authenticationCode(for: input, using: SymmetricKey(data: prk))
        return Data(mac).prefix(outputLength)
    }

    // MARK: - makeServerHash

    func makeServerHash(masterKey: Data, password: Data) async throws -> String {
        // serverHash = PBKDF2-SHA256(masterKey, password, 1 iteration, 32 bytes)
        // Per Bitwarden Security Whitepaper §4: "Local Password Hash"
        let hash = try pbkdf2SHA256(password: masterKey, salt: password, rounds: 1, keyLen: 32)
        return hash.base64EncodedString()
    }

    // MARK: - decryptSymmetricKey

    func decryptSymmetricKey(encUserKey: String, stretchedKeys: CryptoKeys) async throws -> CryptoKeys {
        if DebugConfig.isEnabled {
            logger.debug("[debug] decryptSymmetricKey: encUserKey type prefix=\(String(encUserKey.prefix(2)), privacy: .public) len=\(encUserKey.count, privacy: .public)")
        }
        let enc: EncString
        do {
            enc = try EncString(string: encUserKey)
        } catch {
            logger.error("Failed to parse encUserKey EncString: \(error, privacy: .public)")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }

        let keyData: Data
        do {
            keyData = try enc.decrypt(keys: stretchedKeys)
        } catch {
            logger.error("Failed to decrypt encUserKey: \(error, privacy: .public)")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }

        guard keyData.count == 64 else {
            logger.error("Decrypted symmetric key has wrong length: \(keyData.count, privacy: .public) bytes (expected 64)")
            throw PrizmCryptoServiceError.invalidSymmetricKeyLength
        }

        return CryptoKeys(
            encryptionKey: keyData[0..<32],
            macKey:        keyData[32..<64]
        )
    }

    // MARK: - Org key crypto (RSA-OAEP-SHA1)

    /// Decrypts the user's RSA private key from its EncString representation.
    ///
    /// - Security goal: the decrypted PKCS#8 DER bytes are returned to the caller who
    ///   must zero them immediately after passing to `unwrapOrgKey`. The bytes are NEVER
    ///   logged (Constitution §III — "no secrets in logs").
    ///
    /// - The `privateKey` field in the sync profile is a Type-2 EncString (AES-256-CBC +
    ///   HMAC-SHA256) encrypted with the vault symmetric key. Decrypting it yields the
    ///   PKCS#8 DER-encoded RSA-2048 private key.
    func decryptRSAPrivateKey(encPrivateKey: String, vaultKeys: CryptoKeys) throws -> Data {
        let enc: EncString
        do {
            enc = try EncString(string: encPrivateKey)
        } catch {
            logger.error("decryptRSAPrivateKey: failed to parse EncString: \(error, privacy: .public)")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }
        do {
            return try enc.decrypt(keys: vaultKeys)
        } catch {
            logger.error("decryptRSAPrivateKey: AES-CBC decryption failed: \(error, privacy: .public)")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }
    }

    /// Unwraps an organization's symmetric key using the user's RSA private key.
    ///
    /// - Algorithm: RSA-OAEP-SHA1 via `Security.framework`.
    ///   `kSecKeyAlgorithmRSAEncryptionOAEPSHA1` — SHA-1 is used here because it is the
    ///   Bitwarden protocol requirement (Security Whitepaper §4), not a free choice.
    ///   RSA-OAEP with SHA-1 is secure for key transport; the SHA-1 collision weakness
    ///   applies only to digital signatures, not OAEP key wrapping.
    ///   Reference: Bitwarden Security Whitepaper §4 — "Organization Key Wrapping".
    ///
    /// - PKCS#8 stripping: Bitwarden stores the RSA private key as a PKCS#8-wrapped blob.
    ///   `SecKeyCreateWithData` (kSecAttrKeyTypeRSA) requires the raw PKCS#1 RSAPrivateKey
    ///   DER bytes, not the PKCS#8 wrapper. The PKCS#8 outer structure is:
    ///     SEQUENCE {
    ///       INTEGER (version = 0)
    ///       SEQUENCE { OID rsaEncryption, NULL }  ← AlgorithmIdentifier
    ///       OCTET STRING { <PKCS#1 RSAPrivateKey> }
    ///     }
    ///   We skip the outer SEQUENCE + INTEGER + SEQUENCE (AlgorithmIdentifier) + OCTET STRING
    ///   header bytes to reach the raw PKCS#1 content.
    ///
    /// - Type-4 EncString: org key EncStrings use type "4." followed by base64-encoded
    ///   RSA ciphertext. There is no IV or MAC — the authentication is provided by the
    ///   RSA-OAEP padding scheme itself.
    func unwrapOrgKey(encOrgKey: String, rsaPrivateKey: Data) throws -> CryptoKeys {
        // Parse Type-4 EncString: "4.<base64-ciphertext>"
        let rsaCiphertext = try parseType4EncString(encOrgKey)

        // Strip PKCS#8 wrapper to obtain raw PKCS#1 RSAPrivateKey DER bytes.
        let pkcs1Bytes = try stripPKCS8Header(from: rsaPrivateKey)

        // Import the RSA private key via Security.framework.
        // kSecAttrKeyTypeRSA + kSecAttrKeyClassPrivate + raw PKCS#1 DER.
        var importError: Unmanaged<CFError>?
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String:  kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]
        guard let secKey = SecKeyCreateWithData(pkcs1Bytes as CFData, keyAttributes as CFDictionary, &importError) else {
            let err = importError?.takeRetainedValue()
            logger.fault("unwrapOrgKey: SecKeyCreateWithData failed: \(err.debugDescription, privacy: .public)")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }

        // Decrypt org key bytes using RSA-OAEP-SHA1.
        // SHA-1 is mandated by the Bitwarden protocol — not a free choice.
        var decryptError: Unmanaged<CFError>?
        guard let orgKeyData = SecKeyCreateDecryptedData(
            secKey,
            .rsaEncryptionOAEPSHA1,
            rsaCiphertext as CFData,
            &decryptError
        ) as Data? else {
            let err = decryptError?.takeRetainedValue()
            logger.fault("unwrapOrgKey: RSA-OAEP-SHA1 decryption failed: \(err.debugDescription, privacy: .public)")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }

        guard orgKeyData.count == 64 else {
            logger.fault("unwrapOrgKey: decrypted org key has wrong length \(orgKeyData.count, privacy: .public) (expected 64)")
            throw PrizmCryptoServiceError.invalidSymmetricKeyLength
        }

        return CryptoKeys(
            encryptionKey: orgKeyData[0..<32],
            macKey:        orgKeyData[32..<64]
        )
    }

    /// Parses a Type-4 EncString ("4.<base64>") and returns the raw ciphertext bytes.
    ///
    /// Type-4 is used for RSA-encrypted payloads (org keys). Unlike Type-2 (AES-CBC),
    /// it has no IV or MAC — the format is simply "4." followed by base64.
    private func parseType4EncString(_ encString: String) throws -> Data {
        guard encString.hasPrefix("4.") else {
            logger.error("parseType4EncString: expected type-4 prefix, got \(String(encString.prefix(4)), privacy: .public)")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }
        let b64 = String(encString.dropFirst(2))
        guard let data = Data(base64Encoded: b64) else {
            logger.error("parseType4EncString: base64 decoding failed")
            throw PrizmCryptoServiceError.invalidEncUserKey
        }
        return data
    }

    /// Strips the PKCS#8 outer wrapper from DER-encoded RSA private key bytes.
    ///
    /// PKCS#8 format: SEQUENCE { INTEGER(0), SEQUENCE{OID, NULL}, OCTET STRING { <PKCS#1> } }
    /// We need the raw PKCS#1 RSAPrivateKey DER bytes inside the OCTET STRING.
    ///
    /// DER tag-length-value parsing:
    /// - 0x30 = SEQUENCE
    /// - 0x02 = INTEGER
    /// - 0x30 = SEQUENCE (AlgorithmIdentifier)
    /// - 0x04 = OCTET STRING (contains PKCS#1 content)
    ///
    /// This parser is minimal and only handles the exact PKCS#8 structure Bitwarden produces.
    /// It does not attempt to handle all DER variants.
    private func stripPKCS8Header(from pkcs8: Data) throws -> Data {
        var idx = pkcs8.startIndex

        // Helper: advance past a TLV tag and length, returning the content start and length.
        func readTLV(expectedTag: UInt8) throws -> (contentStart: Data.Index, contentLength: Int) {
            guard idx < pkcs8.endIndex, pkcs8[idx] == expectedTag else {
                throw PrizmCryptoServiceError.invalidEncUserKey
            }
            idx = pkcs8.index(after: idx)

            // Read length (BER/DER short or long form).
            guard idx < pkcs8.endIndex else { throw PrizmCryptoServiceError.invalidEncUserKey }
            var length: Int
            let lenByte = pkcs8[idx]
            idx = pkcs8.index(after: idx)
            if lenByte & 0x80 == 0 {
                length = Int(lenByte)
            } else {
                let numBytes = Int(lenByte & 0x7F)
                length = 0
                for _ in 0..<numBytes {
                    guard idx < pkcs8.endIndex else { throw PrizmCryptoServiceError.invalidEncUserKey }
                    length = (length << 8) | Int(pkcs8[idx])
                    idx = pkcs8.index(after: idx)
                }
            }
            return (idx, length)
        }

        // Outer SEQUENCE
        let (outerContent, _) = try readTLV(expectedTag: 0x30)
        _ = outerContent  // idx is already at content start

        // INTEGER (version = 0)
        let (_, intLen) = try readTLV(expectedTag: 0x02)
        idx = pkcs8.index(idx, offsetBy: intLen)  // skip version value

        // SEQUENCE (AlgorithmIdentifier)
        let (_, algLen) = try readTLV(expectedTag: 0x30)
        idx = pkcs8.index(idx, offsetBy: algLen)  // skip AlgorithmIdentifier

        // OCTET STRING containing PKCS#1 RSAPrivateKey
        let (pkcs1Start, pkcs1Length) = try readTLV(expectedTag: 0x04)
        let pkcs1End = pkcs8.index(pkcs1Start, offsetBy: pkcs1Length)
        return pkcs8[pkcs1Start..<pkcs1End]
    }

    // MARK: - PBKDF2-SHA256 (CommonCrypto)

    /// Derives a key using PBKDF2-SHA256 via CommonCrypto `CCKeyDerivationPBKDF`.
    ///
    /// CommonCrypto implements PBKDF2 as specified in RFC 8018 §5.2 and is validated
    /// under FIPS 140-2 as part of macOS's Common Crypto library.  This function is
    /// used for both the master key derivation (where `salt = email`) and the server
    /// hash (where `salt = password`, `rounds = 1`).
    ///
    /// - Parameters:
    ///   - password: Password bytes.
    ///   - salt:     Salt bytes.
    ///   - rounds:   Iteration count (≥ 1).
    ///   - keyLen:   Desired output key length in bytes (typically 32).
    /// - Throws: `PrizmCryptoServiceError.kdfFailed` if CommonCrypto returns a non-zero status.
    private func pbkdf2SHA256(password: Data, salt: Data, rounds: UInt32, keyLen: Int) throws -> Data {
        var derivedKey = Data(count: keyLen)
        let status = derivedKey.withUnsafeMutableBytes { dkPtr in
            password.withUnsafeBytes { pwPtr in
                salt.withUnsafeBytes { saltPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds,
                        dkPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLen
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw PrizmCryptoServiceError.kdfFailed
        }
        return derivedKey
    }

    // MARK: - Argon2id (Argon2Swift)

    /// Derives a key using Argon2id via the vendored `Argon2Swift` library.
    ///
    /// Argon2id (RFC 9106) is the recommended password hashing algorithm for
    /// memory-hard key derivation.  Bitwarden uses it as an alternative to PBKDF2
    /// for accounts that have opted in.  Parameters are stored in `KdfParams`.
    ///
    /// Note: The raw hash bytes are extracted (not the Argon2 encoded string) because
    /// only the 32-byte derived key material is needed, not the self-describing hash.
    ///
    /// - Parameters:
    ///   - password:    Password bytes.
    ///   - salt:        Salt bytes (typically the lowercased email).
    ///   - iterations:  Time cost (number of passes).
    ///   - memory:      Memory cost in KiB.
    ///   - parallelism: Degree of parallelism (number of threads).
    /// - Throws: `PrizmCryptoServiceError.kdfFailed` if Argon2Swift returns an error.
    private func argon2idDerive(
        password:    Data,
        salt:        Data,
        iterations:  Int,
        memory:      Int,
        parallelism: Int
    ) throws -> Data {
        // Argon2Swift is imported from the local vendored package.
        // The `Argon2Swift.hash(password:salt:iterations:memory:parallelism:type:)`
        // API returns a `Argon2SwiftResult`; we take `.hashData` (raw bytes).
        // `hashPasswordBytes` maps directly to the reference argon2_hash C function.
        // `.id` selects Argon2id (the hybrid variant recommended by RFC 9106 §4).
        // `length: 32` produces a 256-bit derived key suitable for AES-256 key material.
        let result = try Argon2Swift.hashPasswordBytes(
            password:    password,
            salt:        Salt(bytes: salt),
            iterations:  iterations,
            memory:      memory,
            parallelism: parallelism,
            length:      32,
            type:        .id
        )
        return result.hashData()
    }
}
