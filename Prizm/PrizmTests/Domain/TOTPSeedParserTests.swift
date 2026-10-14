import XCTest
@testable import Prizm

/// Parser table from specs/001-totp-verification-codes/contracts/domain-protocols.md.
final class TOTPSeedParserTests: XCTestCase {

    // "JBSWY3DPEHPK3PXP" is base32 for the ASCII bytes "Hello!\u{DE}\u{AD}\u{BE}\u{EF}".
    private let secretBase32 = "JBSWY3DPEHPK3PXP"
    private var secretBytes: Data { Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x21, 0xDE, 0xAD, 0xBE, 0xEF]) }

    func test_plainBase32_withSpacesAndLowercase_usesDefaults() throws {
        let config = try TOTPSeedParser.parse("jbsw y3dp ehpk 3pxp")
        XCTAssertEqual(config.secret, secretBytes)
        XCTAssertEqual(config.algorithm, .sha1)
        XCTAssertEqual(config.digits, 6)
        XCTAssertEqual(config.period, 30)
    }

    func test_plainBase32_withPadding_isAccepted() throws {
        // 8 base32 chars = 5 bytes; "MFRGG===" is "abc" padded.
        let config = try TOTPSeedParser.parse("MFRGG===")
        XCTAssertEqual(config.secret, Data("abc".utf8))
    }

    func test_otpauth_withAllParameters() throws {
        let uri = "otpauth://totp/Acme:me?secret=\(secretBase32)&digits=8&period=60&algorithm=SHA256"
        let config = try TOTPSeedParser.parse(uri)
        XCTAssertEqual(config.secret, secretBytes)
        XCTAssertEqual(config.algorithm, .sha256)
        XCTAssertEqual(config.digits, 8)
        XCTAssertEqual(config.period, 60)
    }

    func test_otpauth_sha512_andLowercaseAlgorithm() throws {
        let config = try TOTPSeedParser.parse("otpauth://totp/x?secret=\(secretBase32)&algorithm=sha512")
        XCTAssertEqual(config.algorithm, .sha512)
    }

    func test_otpauth_withDefaults() throws {
        let config = try TOTPSeedParser.parse("otpauth://totp/Acme:me?secret=\(secretBase32)&issuer=Acme")
        XCTAssertEqual(config.algorithm, .sha1)
        XCTAssertEqual(config.digits, 6)
        XCTAssertEqual(config.period, 30)
    }

    func test_emptyAndWhitespace_throwEmptySeed() {
        XCTAssertThrowsError(try TOTPSeedParser.parse("")) { XCTAssertEqual($0 as? TOTPError, .emptySeed) }
        XCTAssertThrowsError(try TOTPSeedParser.parse("  \n\t ")) { XCTAssertEqual($0 as? TOTPError, .emptySeed) }
    }

    func test_invalidBase32_throwsInvalidSecret() {
        XCTAssertThrowsError(try TOTPSeedParser.parse("not-a-seed!")) { XCTAssertEqual($0 as? TOTPError, .invalidSecret) }
        XCTAssertThrowsError(try TOTPSeedParser.parse("1890")) { XCTAssertEqual($0 as? TOTPError, .invalidSecret) }
    }

    func test_otpauth_missingSecret_throwsInvalidSecret() {
        XCTAssertThrowsError(try TOTPSeedParser.parse("otpauth://totp/Acme:me?issuer=Acme")) {
            XCTAssertEqual($0 as? TOTPError, .invalidSecret)
        }
        XCTAssertThrowsError(try TOTPSeedParser.parse("otpauth://totp/Acme:me?secret=")) {
            XCTAssertEqual($0 as? TOTPError, .invalidSecret)
        }
    }

    func test_steamAndHotp_throwUnsupportedScheme() {
        XCTAssertThrowsError(try TOTPSeedParser.parse("steam://\(secretBase32)")) {
            XCTAssertEqual($0 as? TOTPError, .unsupportedScheme)
        }
        XCTAssertThrowsError(try TOTPSeedParser.parse("otpauth://hotp/Acme:me?secret=\(secretBase32)&counter=1")) {
            XCTAssertEqual($0 as? TOTPError, .unsupportedScheme)
        }
    }

    func test_unsupportedParameters_throwUnsupportedParameter() {
        for query in ["algorithm=MD5", "digits=5", "digits=9", "period=0", "period=-30", "digits=abc", "period=abc"] {
            XCTAssertThrowsError(try TOTPSeedParser.parse("otpauth://totp/x?secret=\(secretBase32)&\(query)"), query) {
                XCTAssertEqual($0 as? TOTPError, .unsupportedParameter, query)
            }
        }
    }

    /// The seed must never appear in an error description (Constitution §III, §V).
    func test_errorDescription_doesNotContainSeed() {
        let seed = "otpauth://totp/x?secret=\(secretBase32)&algorithm=MD5"
        XCTAssertThrowsError(try TOTPSeedParser.parse(seed)) { error in
            XCTAssertFalse("\(error)".contains(secretBase32))
            XCTAssertFalse(String(reflecting: error).contains(secretBase32))
        }
    }
}
