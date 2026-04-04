import Foundation
import CommonCrypto
import CryptoKit
import os.log

// MARK: - AttachmentCryptoError

/// Errors thrown by attachment cryptographic operations.
nonisolated enum AttachmentCryptoError: Error, Equatable {
    /// The encrypted blob is too short to contain a valid IV + HMAC header.
    /// Minimum valid length = 16 (IV) + 1 (ciphertext) + 32 (HMAC) = 49 bytes.
    case blobTooShort
    /// HMAC-SHA256 verification failed — blob may have been tampered with.
    case macMismatch
    /// AES-256-CBC decryption failed.
    case decryptionFailed
    /// AES-256-CBC encryption or IV generation failed.
    case encryptionFailed
    /// `SecRandomCopyBytes` failed to generate a random key.
    case keyGenerationFailed
    /// The attachment key data is not 64 bytes (encKey ‖ macKey).
    case invalidKeyLength
}

// MARK: - Attachment crypto extension on PrizmCryptoService

/// Attachment-specific cryptographic operations added to `PrizmCryptoServiceImpl`.
///
/// All new methods are `nonisolated` so they can be called from any concurrency context
/// without hopping onto the actor — they access no actor-isolated state.
///
/// Binary blob format (tasks 2.2 / 2.3):
///   `IV (16 bytes) ‖ ciphertext (variable) ‖ HMAC-SHA256 (32 bytes)`
///
/// This matches the Bitwarden Attachments binary format described in the Bitwarden
/// Security Whitepaper §4. The HMAC is computed over `IV ‖ ciphertext`
/// (Encrypt-then-MAC), verifying integrity before decryption to prevent padding-oracle
/// attacks (Vaudenay, 2002).
extension PrizmCryptoServiceImpl {

    // MARK: - 2.1 generateAttachmentKey

    /// Generates a cryptographically random 64-byte per-attachment key.
    ///
    /// - Security goal: each file upload gets an independent random key so that
    ///   compromise of one attachment key does not compromise any other attachment
    ///   (key isolation per Bitwarden Security Whitepaper §4).
    /// - Algorithm: 64 bytes from `SecRandomCopyBytes` (backed by `/dev/urandom`).
    ///   First 32 bytes = AES-256-CBC encryption key; last 32 bytes = HMAC-SHA256 MAC key.
    /// - Spec: Bitwarden Security Whitepaper §4 — "Attachment Key Generation".
    ///
    /// - Returns: 64-byte random key Data.
    /// - Throws: `AttachmentCryptoError.keyGenerationFailed` if `SecRandomCopyBytes` fails.
    nonisolated func generateAttachmentKey() throws -> Data {
        var keyBytes = [UInt8](repeating: 0, count: 64)
        let status = SecRandomCopyBytes(kSecRandomDefault, 64, &keyBytes)
        guard status == errSecSuccess else {
            throw AttachmentCryptoError.keyGenerationFailed
        }
        return Data(keyBytes)
    }

    // MARK: - 2.2 encryptData

    /// Encrypts file data using AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC).
    ///
    /// - Security goal: confidentiality and integrity of attachment file bytes.
    ///   The HMAC covers the IV and ciphertext so that any bit-flip in the blob is
    ///   detected before decryption (prevents padding-oracle attacks).
    ///
    /// - Algorithm: AES-256-CBC per NIST SP 800-38A; HMAC-SHA256 per RFC 2104.
    ///   Key split: `attachmentKey[0..<32]` = AES key; `attachmentKey[32..<64]` = MAC key.
    ///
    /// - Binary layout: `IV (16 bytes) ‖ ciphertext ‖ HMAC-SHA256 (32 bytes)`.
    ///   `decryptData` must parse in exactly this order.
    ///
    /// - Parameters:
    ///   - data:          Plaintext file bytes.
    ///   - attachmentKey: 64-byte per-attachment key (encKey ‖ macKey).
    /// - Returns: Binary encrypted blob.
    /// - Throws: `AttachmentCryptoError.invalidKeyLength` if key is not 64 bytes.
    /// - Throws: `AttachmentCryptoError.encryptionFailed` on AES failure.
    nonisolated func encryptData(_ data: Data, attachmentKey: Data) throws -> Data {
        guard attachmentKey.count == 64 else {
            throw AttachmentCryptoError.invalidKeyLength
        }
        let encKey = attachmentKey[0..<32]
        let macKey = attachmentKey[32..<64]

        // Random IV — 16 bytes per AES-CBC block size (NIST SP 800-38A).
        var ivBytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, 16, &ivBytes) == errSecSuccess else {
            throw AttachmentCryptoError.encryptionFailed
        }
        let iv = Data(ivBytes)

        let ciphertext = try aesCbcEncrypt(key: encKey, iv: iv, plaintext: data)

        // HMAC over IV ‖ ciphertext (Encrypt-then-MAC per Bitwarden Security Whitepaper §4).
        let mac = try CryptoKeys.hmacSHA256(key: macKey, data: iv + ciphertext)

        // Layout: IV (16) ‖ ciphertext ‖ HMAC (32)
        return iv + ciphertext + mac
    }

    // MARK: - 2.3 decryptData

    /// Decrypts a binary blob produced by `encryptData`.
    ///
    /// - Security goal: integrity and confidentiality. HMAC verification happens
    ///   BEFORE decryption (Encrypt-then-MAC) to prevent padding-oracle attacks.
    ///
    /// - Algorithm: AES-256-CBC per NIST SP 800-38A; HMAC-SHA256 per RFC 2104.
    ///
    /// - Binary layout: first 16 bytes = IV, last 32 bytes = HMAC, middle = ciphertext.
    ///   Minimum valid blob size = 16 + 1 + 32 = 49 bytes (at least one byte of ciphertext).
    ///
    /// - Parameters:
    ///   - data:          Encrypted binary blob.
    ///   - attachmentKey: 64-byte per-attachment key (encKey ‖ macKey).
    /// - Returns: Plaintext file bytes.
    /// - Throws: `AttachmentCryptoError.blobTooShort` if blob is < 49 bytes.
    /// - Throws: `AttachmentCryptoError.macMismatch` if HMAC verification fails.
    /// - Throws: `AttachmentCryptoError.invalidKeyLength` if key is not 64 bytes.
    /// - Throws: `AttachmentCryptoError.decryptionFailed` on AES failure.
    nonisolated func decryptData(_ data: Data, attachmentKey: Data) throws -> Data {
        guard attachmentKey.count == 64 else {
            throw AttachmentCryptoError.invalidKeyLength
        }
        // Minimum: 16 (IV) + 1 (ciphertext) + 32 (HMAC) = 49
        guard data.count >= 49 else {
            throw AttachmentCryptoError.blobTooShort
        }

        let encKey = attachmentKey[0..<32]
        let macKey = attachmentKey[32..<64]

        // Parse layout: IV ‖ ciphertext ‖ HMAC
        let iv         = data[data.startIndex..<data.startIndex.advanced(by: 16)]
        let mac        = data[data.endIndex.advanced(by: -32)..<data.endIndex]
        let ciphertext = data[data.startIndex.advanced(by: 16)..<data.endIndex.advanced(by: -32)]

        // Verify HMAC over IV ‖ ciphertext before decrypting (Encrypt-then-MAC).
        guard CryptoKeys.verifyHmacSHA256(key: macKey, data: iv + ciphertext, expected: mac) else {
            throw AttachmentCryptoError.macMismatch
        }

        return try aesCbcDecrypt(key: encKey, iv: iv, ciphertext: ciphertext)
    }

    // MARK: - 2.4 encryptAttachmentKey

    /// Wraps the per-attachment key as a type-2 EncString using the cipher's `CryptoKeys`.
    ///
    /// - Security goal: the attachment key is encrypted with the cipher's effective key
    ///   so it can be stored server-side and decrypted only by someone who holds the
    ///   cipher key (which itself is encrypted with the vault key).
    ///   This implements the Bitwarden two-layer key scheme per Security Whitepaper §4.
    ///
    /// - Algorithm: EncString type-2 (AES-256-CBC + HMAC-SHA256) matching all other
    ///   Bitwarden field encryption. Uses `cipherKey.encryptionKey` for AES-CBC and
    ///   `cipherKey.macKey` for HMAC-SHA256.
    ///
    /// - Spec: Bitwarden Security Whitepaper §4, "Cipher String Types".
    ///
    /// - Parameters:
    ///   - key:       Raw 64-byte per-attachment key to wrap.
    ///   - cipherKey: The cipher's effective `CryptoKeys` (from `VaultKeyService`).
    /// - Returns: EncString wire representation (e.g. `"2.<iv>|<ct>|<mac>"`).
    /// - Throws: `EncStringError.encryptionFailed` on AES or IV generation failure.
    nonisolated func encryptAttachmentKey(_ key: Data, cipherKey: CryptoKeys) throws -> String {
        return try EncString.encrypt(data: key, keys: cipherKey).toString()
    }

    // MARK: - 2.5 decryptAttachmentKey

    /// Unwraps a per-attachment key from its EncString representation.
    ///
    /// - Security goal: recovers the 64-byte per-attachment key needed to decrypt the
    ///   file blob. The EncString is the value stored in `Attachment.encryptedKey`.
    ///
    /// - Algorithm: EncString type-2 (AES-256-CBC + HMAC-SHA256). MAC is verified before
    ///   decryption (Encrypt-then-MAC). Bitwarden Security Whitepaper §4.
    ///
    /// - Parameters:
    ///   - encString: The EncString wire representation of the attachment key.
    ///   - cipherKey: The cipher's effective `CryptoKeys`.
    /// - Returns: Raw 64-byte attachment key Data.
    /// - Throws: `EncStringError` on parse or decryption failure.
    nonisolated func decryptAttachmentKey(_ encString: String, cipherKey: CryptoKeys) throws -> Data {
        let enc = try EncString(string: encString)
        return try enc.decrypt(keys: cipherKey)
    }

    // MARK: - 2.6 encryptFileName

    /// Encrypts a plaintext file name as a type-2 EncString for upload metadata.
    ///
    /// - Security goal: file names can reveal sensitive information (e.g. "salary_2025.pdf",
    ///   "diagnosis_report.docx"). Encrypting them before upload prevents the server from
    ///   learning the file names of user attachments.
    ///
    /// - Algorithm: EncString type-2 (AES-256-CBC + HMAC-SHA256). Uses
    ///   `cipherKey.encryptionKey` for AES and `cipherKey.macKey` for HMAC.
    ///   Matches `CipherMapper.encryptString` for consistency.
    ///
    /// - Parameters:
    ///   - name:      Plaintext file name.
    ///   - cipherKey: The cipher's effective `CryptoKeys`.
    /// - Returns: EncString wire representation.
    /// - Throws: `EncStringError.encryptionFailed` on failure.
    nonisolated func encryptFileName(_ name: String, cipherKey: CryptoKeys) throws -> String {
        guard let nameData = name.data(using: .utf8) else {
            throw EncStringError.encryptionFailed
        }
        return try EncString.encrypt(data: nameData, keys: cipherKey).toString()
    }

    // MARK: - Private CommonCrypto helpers (AES-256-CBC)

    /// AES-256-CBC encrypt via CommonCrypto.
    ///
    /// CommonCrypto is FIPS 140-2 validated. Key: 256 bits (32 bytes).
    /// Block/IV size: 128 bits (16 bytes). Padding: PKCS#7 (RFC 5652 §6.3).
    nonisolated private func aesCbcEncrypt(key: Data, iv: Data, plaintext: Data) throws -> Data {
        var outLength  = 0
        let outCap     = plaintext.count + kCCBlockSizeAES128
        var outData    = Data(count: outCap)
        let status = outData.withUnsafeMutableBytes { outPtr in
            plaintext.withUnsafeBytes { ptPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count, ivPtr.baseAddress,
                            ptPtr.baseAddress, plaintext.count,
                            outPtr.baseAddress, outCap, &outLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw AttachmentCryptoError.encryptionFailed }
        outData.removeSubrange(outLength...)
        return outData
    }

    /// AES-256-CBC decrypt via CommonCrypto.
    nonisolated private func aesCbcDecrypt(key: Data, iv: Data, ciphertext: Data) throws -> Data {
        var outLength = 0
        let outCap    = ciphertext.count + kCCBlockSizeAES128
        var outData   = Data(count: outCap)
        let status = outData.withUnsafeMutableBytes { outPtr in
            ciphertext.withUnsafeBytes { ctPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count, ivPtr.baseAddress,
                            ctPtr.baseAddress, ciphertext.count,
                            outPtr.baseAddress, outCap, &outLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw AttachmentCryptoError.decryptionFailed }
        outData.removeSubrange(outLength...)
        return outData
    }
}
