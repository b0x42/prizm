import XCTest
@testable import Prizm

/// Known-answer tests for time-based one-time passwords (Constitution §IV: crypto needs KATs).
///
/// Vectors:
/// - RFC 6238 Appendix B (SHA-1, SHA-256, SHA-512; 8 digits; T0 = 0, step = 30 s).
/// - RFC 4226 Appendix D (HMAC-SHA-1 truncation, 6 digits, counters 0...9).
///
/// These use the real `PrizmCryptoServiceImpl` so the HMAC is the production CryptoKit path.
final class TOTPKnownAnswerTests: XCTestCase {

    private func makeUseCase() -> GenerateTOTPCodeUseCaseImpl {
        GenerateTOTPCodeUseCaseImpl(crypto: PrizmCryptoServiceImpl())
    }

    /// Plain base32 of an ASCII secret, as an authenticator would be provisioned.
    private func base32(_ ascii: String) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0, value = 0
        var out = ""
        for byte in Data(ascii.utf8) {
            value = (value << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                out.append(alphabet[(value >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { out.append(alphabet[(value << (5 - bits)) & 31]) }
        return out
    }

    private func seedURI(_ ascii: String, algorithm: String, digits: Int) -> String {
        "otpauth://totp/KAT?secret=\(base32(ascii))&algorithm=\(algorithm)&digits=\(digits)&period=30"
    }

    // RFC 6238 Appendix B secrets (ASCII): the SHA-1 secret is 20 bytes, SHA-256 32 bytes,
    // SHA-512 64 bytes, each the digits "1234567890" repeated and truncated.
    private let sha1Secret   = "12345678901234567890"
    private let sha256Secret = "12345678901234567890123456789012"
    private let sha512Secret = "1234567890123456789012345678901234567890123456789012345678901234"

    /// (unix time, SHA-1, SHA-256, SHA-512) from RFC 6238 Appendix B.
    private let rfc6238: [(time: TimeInterval, sha1: String, sha256: String, sha512: String)] = [
        (59,           "94287082", "46119246", "90693936"),
        (1111111109,   "07081804", "68084774", "25091201"),
        (1111111111,   "14050471", "67062674", "99943326"),
        (1234567890,   "89005924", "91819424", "93441116"),
        (2000000000,   "69279037", "90698825", "38618901"),
        (20000000000,  "65353130", "77737706", "47863826"),
    ]

    func test_rfc6238_sha1() async throws {
        let useCase = makeUseCase()
        for row in rfc6238 {
            let code = try await useCase.execute(
                seed: seedURI(sha1Secret, algorithm: "SHA1", digits: 8), at: Date(timeIntervalSince1970: row.time))
            XCTAssertEqual(code.digits, row.sha1, "SHA-1 at \(row.time)")
        }
    }

    func test_rfc6238_sha256() async throws {
        let useCase = makeUseCase()
        for row in rfc6238 {
            let code = try await useCase.execute(
                seed: seedURI(sha256Secret, algorithm: "SHA256", digits: 8), at: Date(timeIntervalSince1970: row.time))
            XCTAssertEqual(code.digits, row.sha256, "SHA-256 at \(row.time)")
        }
    }

    func test_rfc6238_sha512() async throws {
        let useCase = makeUseCase()
        for row in rfc6238 {
            let code = try await useCase.execute(
                seed: seedURI(sha512Secret, algorithm: "SHA512", digits: 8), at: Date(timeIntervalSince1970: row.time))
            XCTAssertEqual(code.digits, row.sha512, "SHA-512 at \(row.time)")
        }
    }

    /// RFC 4226 Appendix D: HOTP values for counters 0...9. With period 30 and time = 30 * counter
    /// the TOTP counter equals the HOTP counter, so the same truncation is exercised.
    func test_rfc4226_truncationVectors() async throws {
        let expected = ["755224", "287082", "359152", "969429", "338314",
                        "254676", "287922", "162583", "399871", "520489"]
        let useCase = makeUseCase()
        for (counter, value) in expected.enumerated() {
            let code = try await useCase.execute(
                seed: base32(sha1Secret), at: Date(timeIntervalSince1970: TimeInterval(counter * 30)))
            XCTAssertEqual(code.digits, value, "HOTP counter \(counter)")
        }
    }
}
