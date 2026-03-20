import Foundation
import CommonCrypto
import CryptoKit

// MARK: - EncType

/// The encoding/encryption scheme used by a Bitwarden EncString.
///
/// Values match the numeric type prefix in the wire format
/// (Bitwarden Security Whitepaper §4: "Cipher String Types").
nonisolated enum EncType: Int {
    /// Type 0 — AES-256-CBC, Base64 IV + Base64 ciphertext (no MAC).
    case aes256Cbc_B64             = 0
    /// Type 2 — AES-256-CBC + HMAC-SHA256, Base64 IV|ciphertext|mac.
    case aes256Cbc_HmacSha256_B64  = 2
    /// Type 4 — RSA-2048-OAEP-SHA1, Base64 IV|ciphertext|mac.
    case rsaOaepSha1_B64           = 4
    /// Type 6 — RSA-2048-OAEP-SHA256, Base64 ciphertext only.
    case rsaOaepSha256_B64         = 6
}

// MARK: - EncStringError

/// Errors that can be thrown by EncString operations.
nonisolated enum EncStringError: Error, Equatable {
    /// The string does not conform to the "<type>.<segments>" format.
    case malformedEncString
    /// The numeric type prefix is not one of the supported values (0, 2, 4, 6).
    case unsupportedEncType
    /// HMAC-SHA256 verification failed — ciphertext may have been tampered with.
    case macMismatch
    /// AES decryption failed (CommonCrypto returned an error status).
    case decryptionFailed
    /// Encrypted data is shorter than the required IV length (16 bytes).
    case invalidIVLength
}

// MARK: - EncString

/// A parsed Bitwarden EncString that can be decrypted into plaintext.
///
/// The wire format is:  `<type>.<iv_b64>|<ct_b64>[|<mac_b64>]`
///
/// Supported types (Bitwarden Security Whitepaper §4, "Cipher String Types"):
/// - **Type 0** — AES-256-CBC, no MAC.  Deprecated but still appears in old vaults.
/// - **Type 2** — AES-256-CBC + HMAC-SHA256 (authenticated encryption).  Default for
///   all new symmetric encryption.
/// - **Type 4** — RSA-2048-OAEP-SHA1 wrapped AES key.
/// - **Type 6** — RSA-2048-OAEP-SHA256 wrapped AES key (newer).
nonisolated struct EncString {

    let encType:    EncType
    let iv:         Data
    let ciphertext: Data
    /// Present only for types 2, 4.
    let mac:        Data?

    // MARK: - Parsing

    /// Parse a Bitwarden EncString from its wire representation.
    ///
    /// Format: `<typeInt>.<iv_b64>|<ciphertext_b64>[|<mac_b64>]`
    ///
    /// - Throws: `EncStringError.malformedEncString` if the format is wrong.
    /// - Throws: `EncStringError.unsupportedEncType` if the type integer is unknown.
    init(string: String) throws {
        // Split on the first "." to separate type from the rest
        let dotParts = string.split(separator: ".", maxSplits: 1)
        guard dotParts.count == 2,
              let typeInt = Int(dotParts[0]),
              let type = EncType(rawValue: typeInt) else {
            if let typeInt = Int(string.split(separator: ".").first ?? ""),
               EncType(rawValue: typeInt) == nil {
                throw EncStringError.unsupportedEncType
            }
            throw EncStringError.malformedEncString
        }

        self.encType = type
        let segments = dotParts[1].split(separator: "|", omittingEmptySubsequences: false)

        switch type {
        case .aes256Cbc_B64:
            // Format: <iv>|<ct>  (no MAC)
            guard segments.count == 2,
                  let iv  = Data(base64Encoded: String(segments[0])),
                  let ct  = Data(base64Encoded: String(segments[1])) else {
                throw EncStringError.malformedEncString
            }
            self.iv         = iv
            self.ciphertext = ct
            self.mac        = nil

        case .aes256Cbc_HmacSha256_B64, .rsaOaepSha1_B64:
            // Format: <iv>|<ct>|<mac>
            guard segments.count == 3,
                  let iv  = Data(base64Encoded: String(segments[0])),
                  let ct  = Data(base64Encoded: String(segments[1])),
                  let mac = Data(base64Encoded: String(segments[2])) else {
                throw EncStringError.malformedEncString
            }
            self.iv         = iv
            self.ciphertext = ct
            self.mac        = mac

        case .rsaOaepSha256_B64:
            // Format: <ct>  (IV not used for RSA; first segment is ciphertext)
            guard segments.count >= 1,
                  let ct = Data(base64Encoded: String(segments[0])) else {
                throw EncStringError.malformedEncString
            }
            self.iv         = Data()
            self.ciphertext = ct
            self.mac        = nil
        }
    }

    // MARK: - Serialise

    /// Returns the wire-format string representation.
    func toString() -> String {
        let ivB64 = iv.base64EncodedString()
        let ctB64 = ciphertext.base64EncodedString()
        if let mac = mac {
            return "\(encType.rawValue).\(ivB64)|\(ctB64)|\(mac.base64EncodedString())"
        }
        return "\(encType.rawValue).\(ivB64)|\(ctB64)"
    }

    // MARK: - MAC Verification

    /// Verifies the HMAC-SHA256 MAC over `iv || ciphertext`.
    ///
    /// Per the Bitwarden Security Whitepaper §4: "Encrypt-then-MAC" — the MAC is
    /// computed over the IV concatenated with the ciphertext using the MAC key,
    /// and **must** be verified before any decryption is attempted to prevent
    /// padding-oracle attacks (Vaudenay, 2002).
    ///
    /// - Parameter keys: The symmetric key pair containing `macKey`.
    /// - Returns: `true` if the computed MAC equals the stored MAC; `false` otherwise.
    func verifyMac(keys: CryptoKeys) throws -> Bool {
        guard let mac = mac else { return true }   // Type-0 has no MAC
        let authenticated = CryptoKeys.verifyHmacSHA256(
            key:      keys.macKey,
            data:     iv + ciphertext,
            expected: mac
        )
        return authenticated
    }

    // MARK: - Decryption

    /// Decrypts this EncString using AES-256-CBC and returns the plaintext.
    ///
    /// For Type-2 strings, MAC is verified first (Encrypt-then-MAC).  Decryption
    /// is performed using CommonCrypto `CCCrypt` with `kCCAlgorithmAES`,
    /// `kCCOptionPKCS7Padding`, and a 16-byte IV.
    ///
    /// - Parameter keys: The 256-bit encryption key + 256-bit MAC key.
    /// - Returns: Decrypted plaintext `Data`.
    /// - Throws: `EncStringError.macMismatch` if MAC verification fails.
    /// - Throws: `EncStringError.decryptionFailed` if AES decryption fails.
    func decrypt(keys: CryptoKeys) throws -> Data {
        // 1. Verify MAC first (Encrypt-then-MAC per Bitwarden Security Whitepaper §4)
        if encType == .aes256Cbc_HmacSha256_B64 {
            guard try verifyMac(keys: keys) else {
                throw EncStringError.macMismatch
            }
        }

        // 2. AES-256-CBC decrypt via CommonCrypto
        return try Self.aesCbcDecrypt(key: keys.encryptionKey, iv: iv, ciphertext: ciphertext)
    }

    // MARK: - Encryption

    /// Encrypts `data` as a Type-2 (AES-256-CBC + HMAC-SHA256) EncString.
    ///
    /// Generates a cryptographically random 16-byte IV using
    /// `SecRandomCopyBytes` (backed by `/dev/urandom`).
    ///
    /// - Parameters:
    ///   - data: Plaintext bytes to encrypt.
    ///   - keys: Symmetric key pair.
    /// - Returns: A new `EncString` of type `.aes256Cbc_HmacSha256_B64`.
    static func encrypt(data: Data, keys: CryptoKeys) throws -> EncString {
        // Random IV (16 bytes)
        var ivBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, 16, &ivBytes)
        guard status == errSecSuccess else {
            throw EncStringError.decryptionFailed
        }
        let iv = Data(ivBytes)

        // AES-256-CBC encrypt
        let ciphertext = try aesCbcEncrypt(key: keys.encryptionKey, iv: iv, plaintext: data)

        // Compute MAC over iv || ciphertext
        let mac = try CryptoKeys.hmacSHA256(key: keys.macKey, data: iv + ciphertext)

        return EncString(
            encType:    .aes256Cbc_HmacSha256_B64,
            iv:         iv,
            ciphertext: ciphertext,
            mac:        mac
        )
    }

    // MARK: - Private CommonCrypto Helpers

    /// AES-256-CBC decrypt using CommonCrypto `CCCrypt`.
    ///
    /// CommonCrypto is a FIPS 140-2 validated cryptographic library included in macOS.
    /// Key size: 256 bits (32 bytes).  Block size / IV size: 128 bits (16 bytes).
    /// Padding: PKCS#7 (RFC 5652 §6.3).
    private static func aesCbcDecrypt(key: Data, iv: Data, ciphertext: Data) throws -> Data {
        var outLength = 0
        let outCapacity = ciphertext.count + kCCBlockSizeAES128
        var outData = Data(count: outCapacity)

        let status = outData.withUnsafeMutableBytes { outPtr in
            ciphertext.withUnsafeBytes { ctPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            ctPtr.baseAddress, ciphertext.count,
                            outPtr.baseAddress, outCapacity,
                            &outLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw EncStringError.decryptionFailed
        }
        outData.removeSubrange(outLength...)
        return outData
    }

    /// AES-256-CBC encrypt using CommonCrypto `CCCrypt`.
    private static func aesCbcEncrypt(key: Data, iv: Data, plaintext: Data) throws -> Data {
        var outLength  = 0
        let outCapacity = plaintext.count + kCCBlockSizeAES128
        var outData    = Data(count: outCapacity)

        let status = outData.withUnsafeMutableBytes { outPtr in
            plaintext.withUnsafeBytes { ptPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            ptPtr.baseAddress, plaintext.count,
                            outPtr.baseAddress, outCapacity,
                            &outLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw EncStringError.decryptionFailed
        }
        outData.removeSubrange(outLength...)
        return outData
    }
}

// MARK: - Memberwise init (private, used by encrypt)

nonisolated private extension EncString {
    init(encType: EncType, iv: Data, ciphertext: Data, mac: Data?) {
        self.encType    = encType
        self.iv         = iv
        self.ciphertext = ciphertext
        self.mac        = mac
    }
}
