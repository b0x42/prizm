import XCTest
@testable import Macwarden

/// Failing tests for EncString parser + decryption (T015).
/// These tests will fail until EncString + CryptoKeys are implemented (T019).
///
/// Test vectors are derived from the Bitwarden Security Whitepaper
/// (https://bitwarden.com/images/resources/security-white-paper-download.pdf).
@MainActor
final class EncStringTests: XCTestCase {

    // MARK: - Type-0: AES-256-CBC (no MAC)

    /// Type 0 format: "0.<iv_b64>|<ct_b64>"
    func testParseType0() throws {
        let iv = Data(repeating: 0x01, count: 16)
        let ct = Data(repeating: 0x02, count: 32)
        let str = "0.\(iv.base64EncodedString())|\(ct.base64EncodedString())"
        let enc = try EncString(string: str)
        XCTAssertEqual(enc.encType, .aes256Cbc_B64)
        XCTAssertEqual(enc.iv, iv)
        XCTAssertEqual(enc.ciphertext, ct)
        XCTAssertNil(enc.mac)
    }

    /// Type 0 with wrong number of segments must throw.
    func testParseType0MissingSegmentThrows() {
        let str = "0.onlyone"
        XCTAssertThrowsError(try EncString(string: str)) { error in
            XCTAssertEqual(error as? EncStringError, .malformedEncString)
        }
    }

    // MARK: - Type-2: AES-256-CBC + HMAC-SHA256

    /// Type 2 format: "2.<iv_b64>|<ct_b64>|<mac_b64>"
    func testParseType2() throws {
        let iv  = Data(repeating: 0xAA, count: 16)
        let ct  = Data(repeating: 0xBB, count: 32)
        let mac = Data(repeating: 0xCC, count: 32)
        let str = "2.\(iv.base64EncodedString())|\(ct.base64EncodedString())|\(mac.base64EncodedString())"
        let enc = try EncString(string: str)
        XCTAssertEqual(enc.encType, .aes256Cbc_HmacSha256_B64)
        XCTAssertEqual(enc.iv,  iv)
        XCTAssertEqual(enc.ciphertext, ct)
        XCTAssertEqual(enc.mac, mac)
    }

    /// Type 2 missing MAC segment must throw.
    func testParseType2MissingMacThrows() {
        let str = "2.aaaaaa|bbbbbb"
        XCTAssertThrowsError(try EncString(string: str)) { error in
            XCTAssertEqual(error as? EncStringError, .malformedEncString)
        }
    }

    // MARK: - Type-4: RSA-OAEP-SHA1 + AES-256-CBC

    /// Type 4 format: "4.<iv_b64>|<ct_b64>|<mac_b64>"
    func testParseType4() throws {
        let iv  = Data(repeating: 0x11, count: 16)
        let ct  = Data(repeating: 0x22, count: 256)
        let mac = Data(repeating: 0x33, count: 32)
        let str = "4.\(iv.base64EncodedString())|\(ct.base64EncodedString())|\(mac.base64EncodedString())"
        let enc = try EncString(string: str)
        XCTAssertEqual(enc.encType, .rsaOaepSha1_B64)
    }

    /// Unknown type prefix must throw.
    func testParseUnknownTypeThrows() {
        let str = "99.aaaaaa|bbbbbb"
        XCTAssertThrowsError(try EncString(string: str)) { error in
            XCTAssertEqual(error as? EncStringError, .unsupportedEncType)
        }
    }

    // MARK: - MAC Verification

    /// HMAC-SHA256 verification must pass with correct key + data.
    /// Vector: mac key = 0xFF×32, iv = 0x01×16, ct = 0x02×32
    /// Expected MAC = HMAC-SHA256(macKey, iv || ct)
    func testMacVerificationPassesWithCorrectKey() throws {
        let macKey = Data(repeating: 0xFF, count: 32)
        let encKey = Data(repeating: 0xAB, count: 32)
        let iv     = Data(repeating: 0x01, count: 16)
        let ct     = Data(repeating: 0x02, count: 32)

        // Compute expected MAC
        let expectedMac = try CryptoKeys.hmacSHA256(key: macKey, data: iv + ct)
        let str = "2.\(iv.base64EncodedString())|\(ct.base64EncodedString())|\(expectedMac.base64EncodedString())"
        let enc = try EncString(string: str)

        let keys = CryptoKeys(encryptionKey: encKey, macKey: macKey)
        XCTAssertTrue(try enc.verifyMac(keys: keys))
    }

    /// Tampered MAC must fail verification (not throw — returns false).
    func testMacVerificationFailsWithWrongMac() throws {
        let macKey = Data(repeating: 0xFF, count: 32)
        let encKey = Data(repeating: 0xAB, count: 32)
        let iv     = Data(repeating: 0x01, count: 16)
        let ct     = Data(repeating: 0x02, count: 32)
        let badMac = Data(repeating: 0x00, count: 32)   // incorrect
        let str = "2.\(iv.base64EncodedString())|\(ct.base64EncodedString())|\(badMac.base64EncodedString())"
        let enc = try EncString(string: str)

        let keys = CryptoKeys(encryptionKey: encKey, macKey: macKey)
        XCTAssertFalse(try enc.verifyMac(keys: keys))
    }

    // MARK: - Decrypt round-trip (Type-2)

    /// Encrypt then decrypt must return original plaintext.
    /// Uses AES-256-CBC with a known 32-byte key and 16-byte IV.
    func testDecryptRoundTrip() throws {
        let encKey = Data(repeating: 0xDE, count: 32)
        let macKey = Data(repeating: 0xAD, count: 32)
        let keys   = CryptoKeys(encryptionKey: encKey, macKey: macKey)

        let plaintext = "Hello, Bitwarden!".data(using: .utf8)!
        let encrypted = try EncString.encrypt(data: plaintext, keys: keys)
        let decrypted = try encrypted.decrypt(keys: keys)
        XCTAssertEqual(decrypted, plaintext)
    }

    /// Decrypting with a wrong encryption key must throw `.macMismatch`.
    func testDecryptWrongKeyThrowsMacMismatch() throws {
        let encKey = Data(repeating: 0xDE, count: 32)
        let macKey = Data(repeating: 0xAD, count: 32)
        let keys   = CryptoKeys(encryptionKey: encKey, macKey: macKey)

        let plaintext = "Secret".data(using: .utf8)!
        let encrypted = try EncString.encrypt(data: plaintext, keys: keys)

        let wrongMacKey = Data(repeating: 0x00, count: 32)
        let wrongKeys   = CryptoKeys(encryptionKey: encKey, macKey: wrongMacKey)
        XCTAssertThrowsError(try encrypted.decrypt(keys: wrongKeys)) { error in
            XCTAssertEqual(error as? EncStringError, .macMismatch)
        }
    }
}
