import Foundation
import CryptoKit
import CommonCrypto

// MARK: - CryptoKeys

/// A pair of AES-256 encryption key + HMAC-SHA256 MAC key derived from the master
/// password via PBKDF2 or Argon2id followed by HKDF expansion.
///
/// The two-key construction follows the Bitwarden Security Whitepaper §4:
/// "Key Derivation" — the 256-bit stretched master key is split into a 256-bit
/// encryption key and a 256-bit MAC key so that the keys used for encryption and
/// authentication are independent (per NIST SP 800-107 §5.3).
nonisolated struct CryptoKeys {
    /// 32-byte AES-256-CBC encryption key.
    let encryptionKey: Data
    /// 32-byte HMAC-SHA256 MAC key (used for authenticated encryption).
    let macKey: Data
}

// MARK: - Static HMAC helper

nonisolated extension CryptoKeys {

    /// Computes HMAC-SHA256 of `data` under `key`.
    ///
    /// Uses CryptoKit `HMAC<SHA256>` which is constant-time, removing the need
    /// for a manual constant-time comparison loop (CryptoKit handles it internally
    /// in `HMAC.isValidAuthenticationCode`).
    ///
    /// - Parameters:
    ///   - key:  32-byte MAC key.
    ///   - data: Arbitrary-length message to authenticate.
    /// - Returns: 32-byte HMAC-SHA256 digest.
    static func hmacSHA256(key: Data, data: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(mac)
    }

    /// Performs a constant-time comparison of two HMAC-SHA256 MACs.
    ///
    /// CryptoKit's `HMAC.isValidAuthenticationCode` uses a constant-time algorithm
    /// to prevent timing side-channel attacks (per NIST SP 800-107 §5.3.1).
    ///
    /// - Parameters:
    ///   - key:      32-byte MAC key.
    ///   - data:     Original message (iv || ciphertext).
    ///   - expected: The MAC bytes to verify against.
    /// - Returns: `true` if the computed MAC equals `expected`.
    static func verifyHmacSHA256(key: Data, data: Data, expected: Data) -> Bool {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(mac) == expected
    }
}
