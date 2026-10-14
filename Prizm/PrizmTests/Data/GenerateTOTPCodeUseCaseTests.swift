import XCTest
@testable import Prizm

final class GenerateTOTPCodeUseCaseTests: XCTestCase {

    private var crypto: MockPrizmCryptoService!
    private var sut: GenerateTOTPCodeUseCaseImpl!

    // base32 for the ASCII secret "12345678901234567890" (RFC 6238 SHA-1 test secret).
    private let seed = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

    override func setUp() {
        super.setUp()
        crypto = MockPrizmCryptoService()
        sut = GenerateTOTPCodeUseCaseImpl(crypto: crypto)
    }

    /// RFC 4226 §5.2 / RFC 6238 §4: the counter is floor(unixSeconds / period) as 8 bytes, big-endian.
    func test_counter_isFloorOfTimeOverPeriod_bigEndian8Bytes() async throws {
        crypto.stubbedHMAC = Data(repeating: 0, count: 20)
        _ = try await sut.execute(seed: seed, at: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(crypto.lastHMACMessage, Data([0, 0, 0, 0, 0, 0, 0, 1]))

        _ = try await sut.execute(seed: seed, at: Date(timeIntervalSince1970: 1_111_111_109))
        var expected = UInt64(1_111_111_109 / 30).bigEndian
        XCTAssertEqual(crypto.lastHMACMessage, Data(bytes: &expected, count: 8))
    }

    func test_customPeriod_changesCounter() async throws {
        crypto.stubbedHMAC = Data(repeating: 0, count: 20)
        _ = try await sut.execute(
            seed: "otpauth://totp/x?secret=\(seed)&period=60", at: Date(timeIntervalSince1970: 120))
        XCTAssertEqual(crypto.lastHMACMessage, Data([0, 0, 0, 0, 0, 0, 0, 2]))
    }

    func test_secondsRemaining_withinPeriod() async throws {
        crypto.stubbedHMAC = Data(repeating: 0, count: 20)
        let mid = try await sut.execute(seed: seed, at: Date(timeIntervalSince1970: 100)) // 100 mod 30 = 10
        XCTAssertEqual(mid.secondsRemaining, 20)
        XCTAssertEqual(mid.period, 30)
    }

    func test_secondsRemaining_atBoundary_equalsFullPeriod() async throws {
        crypto.stubbedHMAC = Data(repeating: 0, count: 20)
        let boundary = try await sut.execute(seed: seed, at: Date(timeIntervalSince1970: 90))
        XCTAssertEqual(boundary.secondsRemaining, 30)
        let lastSecond = try await sut.execute(seed: seed, at: Date(timeIntervalSince1970: 119))
        XCTAssertEqual(lastSecond.secondsRemaining, 1)
    }

    func test_sameSeedAndDate_giveSameResult() async throws {
        crypto.stubbedHMAC = Data((0..<20).map { UInt8($0) })
        let date = Date(timeIntervalSince1970: 1_234_567_890)
        let a = try await sut.execute(seed: seed, at: date)
        let b = try await sut.execute(seed: seed, at: date)
        XCTAssertEqual(a, b)
    }

    func test_digits_areZeroPaddedToConfiguredLength() async throws {
        // All-zero MAC -> truncated value 0 -> "000000" / "00000000".
        crypto.stubbedHMAC = Data(repeating: 0, count: 20)
        let six = try await sut.execute(seed: seed, at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(six.digits, "000000")
        let eight = try await sut.execute(
            seed: "otpauth://totp/x?secret=\(seed)&digits=8", at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(eight.digits, "00000000")
    }

    func test_algorithm_isPassedToCrypto() async throws {
        crypto.stubbedHMAC = Data(repeating: 0, count: 32)
        _ = try await sut.execute(
            seed: "otpauth://totp/x?secret=\(seed)&algorithm=SHA256", at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(crypto.lastHMACAlgorithm, .sha256)
    }

    func test_parserErrors_propagate() async {
        do {
            _ = try await sut.execute(seed: "", at: Date())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? TOTPError, .emptySeed)
        }
        do {
            _ = try await sut.execute(seed: "steam://\(seed)", at: Date())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? TOTPError, .unsupportedScheme)
        }
    }

    func test_errorDescription_neverContainsSeed() async {
        do {
            _ = try await sut.execute(seed: "otpauth://totp/x?secret=\(seed)&digits=3", at: Date())
            XCTFail("expected throw")
        } catch {
            XCTAssertFalse("\(error)".contains(seed))
        }
    }

    /// Constitution "Memory hardening": best-effort wipe of the use case's secret copy.
    func test_wipe_overwritesBufferWithZeros() {
        var buffer = Data([1, 2, 3, 4, 5])
        GenerateTOTPCodeUseCaseImpl.wipe(&buffer)
        XCTAssertEqual(buffer, Data(repeating: 0, count: 5))
    }
}
