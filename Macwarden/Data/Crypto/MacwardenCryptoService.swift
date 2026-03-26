import Foundation
import CommonCrypto
import CryptoKit
import Argon2Swift
import os.log

// MARK: - MacwardenCryptoServiceError

/// Errors thrown by `MacwardenCryptoService` operations.
nonisolated enum MacwardenCryptoServiceError: Error, Equatable {
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

// MARK: - MacwardenCryptoService Protocol

/// Provides cryptographic operations for the Bitwarden vault:
/// key derivation, key stretching, server hash computation, and vault lock/unlock.
///
/// Implemented as an `actor` to protect the in-memory key material from data races.
/// All async methods must be called with `await`.
protocol MacwardenCryptoService: Actor {

    /// Whether the vault is currently unlocked (key material is in memory).
    var isUnlocked: Bool { get }

    /// Derives a 32-byte master key from the user's email + password using the
    /// specified KDF (PBKDF2-SHA256 or Argon2id).
    ///
    /// Per the Bitwarden Security Whitepaper §4: the master key is the root secret
    /// from which all other keys are derived.  It is **never** sent to the server.
    ///
    /// - Parameters:
    ///   - password: The user's master password (UTF-8 encoded).
    ///   - email:    The user's lowercase email address (used as the PBKDF2 salt).
    ///   - kdf:      KDF parameters (algorithm, iterations, optional memory/parallelism).
    /// - Returns: 32-byte master key `Data`.
    func makeMasterKey(password: String, email: String, kdf: KdfParams) async throws -> Data

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
    ///   - password:  The user's master password (used as the PBKDF2 "salt" in this step).
    /// - Returns: Base64-encoded 32-byte hash string (44 chars with padding).
    func makeServerHash(masterKey: Data, password: String) async throws -> String

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
    /// - Throws: `MacwardenCryptoServiceError.vaultLocked` if the vault is not unlocked.
    func decryptList(ciphers: [RawCipher]) async throws -> (items: [VaultItem], failedCount: Int)

    /// Loads `keys` into memory, marking the vault as unlocked.
    func unlockWith(keys: CryptoKeys) async

    /// Zeroes and discards all in-memory key material, locking the vault.
    ///
    /// After this call, `isUnlocked` returns `false` and any attempt to decrypt
    /// vault items will throw `MacwardenCryptoServiceError.vaultLocked`.
    func lockVault() async

    /// Returns the current vault symmetric key pair for callers that need to perform
    /// encryption (e.g. the reverse cipher mapper for PUT /ciphers/{id}).
    ///
    /// - Throws: `MacwardenCryptoServiceError.vaultLocked` if the vault is locked.
    func currentKeys() async throws -> CryptoKeys
}

// MARK: - MacwardenCryptoServiceImpl

/// Concrete implementation of `MacwardenCryptoService`.
///
/// Key derivation algorithms:
/// - **PBKDF2-SHA256** (RFC 8018 §5.2, NIST SP 800-132): used when
///   `KdfParams.type == .pbkdf2`.  Implemented via CommonCrypto `CCKeyDerivationPBKDF`.
/// - **Argon2id** (RFC 9106): used when `KdfParams.type == .argon2id`.
///   Delegated to the vendored `Argon2Swift` library.
/// - **HKDF** (RFC 5869): used for key stretching in `stretchKey`.  Implemented
///   using CryptoKit `HKDF<SHA256>` which is the recommended approach on Apple
///   platforms (CryptoKit is FIPS 140-3 certified since macOS 12).
actor MacwardenCryptoServiceImpl: MacwardenCryptoService {

    private let logger = Logger(subsystem: "com.macwarden", category: "MacwardenCryptoService")

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
            throw MacwardenCryptoServiceError.vaultLocked
        }
        return vaultKeys
    }

    // MARK: - decryptList

    func decryptList(ciphers: [RawCipher]) async throws -> (items: [VaultItem], failedCount: Int) {
        guard let vaultKeys = keys else {
            throw MacwardenCryptoServiceError.vaultLocked
        }
        logger.info("decryptList: starting with \(ciphers.count) ciphers")
        let mapper = CipherMapper()
        var items: [VaultItem] = []
        var failedCount = 0
        for (index, cipher) in ciphers.enumerated() {
            // Organisation ciphers are not supported in v1.
            if cipher.organizationId != nil {
                if DebugConfig.isEnabled {
                    logger.debug("[debug] cipher[\(index, privacy: .public)] skipped — organizationId present")
                }
                continue
            }
            do {
                let item = try mapper.map(raw: cipher, keys: vaultKeys)
                items.append(item)
                if DebugConfig.isEnabled {
                    logger.debug("[debug] cipher[\(index, privacy: .public)] OK — type=\(cipher.type, privacy: .public) id=\(cipher.id, privacy: .private)")
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
        return (items: items, failedCount: failedCount)
    }

    // MARK: - makeMasterKey

    func makeMasterKey(password: String, email: String, kdf: KdfParams) async throws -> Data {
        guard let passwordData = password.data(using: .utf8),
              let emailData    = email.lowercased().data(using: .utf8) else {
            throw MacwardenCryptoServiceError.kdfFailed
        }

        logger.debug("KDF: using \(String(describing: kdf.type)) with \(kdf.iterations) iterations")

        switch kdf.type {
        case .pbkdf2:
            return try pbkdf2SHA256(
                password: passwordData,
                salt:     emailData,
                rounds:   UInt32(kdf.iterations),
                keyLen:   32
            )
        case .argon2id:
            // Argon2id requires memory + parallelism params
            guard let memory      = kdf.memory,
                  let parallelism = kdf.parallelism else {
                throw MacwardenCryptoServiceError.kdfFailed
            }
            return try argon2idDerive(
                password:    passwordData,
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

    func makeServerHash(masterKey: Data, password: String) async throws -> String {
        guard let passwordData = password.data(using: .utf8) else {
            throw MacwardenCryptoServiceError.kdfFailed
        }
        // serverHash = PBKDF2-SHA256(masterKey, password, 1 iteration, 32 bytes)
        // Per Bitwarden Security Whitepaper §4: "Local Password Hash"
        let hash = try pbkdf2SHA256(password: masterKey, salt: passwordData, rounds: 1, keyLen: 32)
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
            throw MacwardenCryptoServiceError.invalidEncUserKey
        }

        let keyData: Data
        do {
            keyData = try enc.decrypt(keys: stretchedKeys)
        } catch {
            logger.error("Failed to decrypt encUserKey: \(error, privacy: .public)")
            throw MacwardenCryptoServiceError.invalidEncUserKey
        }

        guard keyData.count == 64 else {
            logger.error("Decrypted symmetric key has wrong length: \(keyData.count, privacy: .public) bytes (expected 64)")
            throw MacwardenCryptoServiceError.invalidSymmetricKeyLength
        }

        return CryptoKeys(
            encryptionKey: keyData[0..<32],
            macKey:        keyData[32..<64]
        )
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
    /// - Throws: `MacwardenCryptoServiceError.kdfFailed` if CommonCrypto returns a non-zero status.
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
            throw MacwardenCryptoServiceError.kdfFailed
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
    /// - Throws: `MacwardenCryptoServiceError.kdfFailed` if Argon2Swift returns an error.
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
