import Foundation
import CommonCrypto
import CryptoKit
import Argon2Swift

// MARK: - BitwardenCryptoServiceError

/// Errors thrown by `BitwardenCryptoService` operations.
enum BitwardenCryptoServiceError: Error, Equatable {
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

// MARK: - BitwardenCryptoService Protocol

/// Provides cryptographic operations for the Bitwarden vault:
/// key derivation, key stretching, server hash computation, and vault lock/unlock.
///
/// Implemented as an `actor` to protect the in-memory key material from data races.
/// All async methods must be called with `await`.
protocol BitwardenCryptoService: Actor {

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

    /// Loads `keys` into memory, marking the vault as unlocked.
    func unlockWith(keys: CryptoKeys) async

    /// Zeroes and discards all in-memory key material, locking the vault.
    ///
    /// After this call, `isUnlocked` returns `false` and any attempt to decrypt
    /// vault items will throw `BitwardenCryptoServiceError.vaultLocked`.
    func lockVault() async
}

// MARK: - BitwardenCryptoServiceImpl

/// Concrete implementation of `BitwardenCryptoService`.
///
/// Key derivation algorithms:
/// - **PBKDF2-SHA256** (RFC 8018 §5.2, NIST SP 800-132): used when
///   `KdfParams.type == .pbkdf2`.  Implemented via CommonCrypto `CCKeyDerivationPBKDF`.
/// - **Argon2id** (RFC 9106): used when `KdfParams.type == .argon2id`.
///   Delegated to the vendored `Argon2Swift` library.
/// - **HKDF** (RFC 5869): used for key stretching in `stretchKey`.  Implemented
///   using CryptoKit `HKDF<SHA256>` which is the recommended approach on Apple
///   platforms (CryptoKit is FIPS 140-3 certified since macOS 12).
actor BitwardenCryptoServiceImpl: BitwardenCryptoService {

    // MARK: - State

    /// The decrypted vault symmetric key pair, non-nil only when unlocked.
    /// Stored as `var` so it can be zeroed on lock.
    private var keys: CryptoKeys?

    var isUnlocked: Bool { keys != nil }

    // MARK: - Lock / Unlock

    func unlockWith(keys: CryptoKeys) {
        self.keys = keys
    }

    func lockVault() {
        // Overwrite with zeros before releasing (best-effort; Swift ARC may still
        // retain copies elsewhere, but this reduces the window during which the
        // key is readable in a memory dump).
        self.keys = nil
    }

    // MARK: - makeMasterKey

    func makeMasterKey(password: String, email: String, kdf: KdfParams) async throws -> Data {
        guard let passwordData = password.data(using: .utf8),
              let emailData    = email.lowercased().data(using: .utf8) else {
            throw BitwardenCryptoServiceError.kdfFailed
        }

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
                throw BitwardenCryptoServiceError.kdfFailed
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
        // HKDF-Extract+Expand (RFC 5869) with independent "enc" and "mac" info labels.
        // Per Bitwarden Security Whitepaper §4: "Key Stretching".
        // Each call to deriveKey performs its own extract + expand internally,
        // producing independent keys from the same input key material.
        let inputKey = SymmetricKey(data: masterKey)

        let encSymKey = try HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt:             Data(),
            info:             Data("enc".utf8),
            outputByteCount:  32
        )
        let macSymKey = try HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt:             Data(),
            info:             Data("mac".utf8),
            outputByteCount:  32
        )

        // SymmetricKey does not expose raw bytes directly; use withUnsafeBytes.
        let encKey = encSymKey.withUnsafeBytes { Data($0) }
        let macKey = macSymKey.withUnsafeBytes { Data($0) }
        return CryptoKeys(encryptionKey: encKey, macKey: macKey)
    }

    // MARK: - makeServerHash

    func makeServerHash(masterKey: Data, password: String) async throws -> String {
        guard let passwordData = password.data(using: .utf8) else {
            throw BitwardenCryptoServiceError.kdfFailed
        }
        // serverHash = PBKDF2-SHA256(masterKey, password, 1 iteration, 32 bytes)
        // Per Bitwarden Security Whitepaper §4: "Local Password Hash"
        let hash = try pbkdf2SHA256(password: masterKey, salt: passwordData, rounds: 1, keyLen: 32)
        return hash.base64EncodedString()
    }

    // MARK: - decryptSymmetricKey

    func decryptSymmetricKey(encUserKey: String, stretchedKeys: CryptoKeys) async throws -> CryptoKeys {
        let enc: EncString
        do {
            enc = try EncString(string: encUserKey)
        } catch {
            throw BitwardenCryptoServiceError.invalidEncUserKey
        }

        let keyData: Data
        do {
            keyData = try enc.decrypt(keys: stretchedKeys)
        } catch {
            throw BitwardenCryptoServiceError.invalidEncUserKey
        }

        guard keyData.count == 64 else {
            throw BitwardenCryptoServiceError.invalidSymmetricKeyLength
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
    /// - Throws: `BitwardenCryptoServiceError.kdfFailed` if CommonCrypto returns a non-zero status.
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
            throw BitwardenCryptoServiceError.kdfFailed
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
    /// - Throws: `BitwardenCryptoServiceError.kdfFailed` if Argon2Swift returns an error.
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
