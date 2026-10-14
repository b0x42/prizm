import Foundation

/// Generates time-based one-time passwords (TOTP).
///
/// - Standard: RFC 6238 (TOTP) built on RFC 4226 (HOTP), verified by known-answer tests
///   against RFC 6238 Appendix B and RFC 4226 Appendix D (`TOTPKnownAnswerTests`).
/// - Security goal: derive a short-lived code from a seed that is already in the unlocked
///   vault. Nothing is stored; the HMAC itself is done by `PrizmCryptoService` (CryptoKit),
///   never hand-rolled here (Constitution §III).
/// - Intentionally NOT done: no clock correction (the device clock is the time source), no
///   caching of seeds or parsed configurations, no logging of seeds or codes.
nonisolated final class GenerateTOTPCodeUseCaseImpl: GenerateTOTPCodeUseCase, Sendable {

    private let crypto: any PrizmCryptoService

    init(crypto: any PrizmCryptoService) {
        self.crypto = crypto
    }

    func execute(seed: String, at date: Date) async throws -> TOTPCode {
        let config = try TOTPSeedParser.parse(seed)

        // Memory hardening (Constitution §III): work on a private copy of the secret and
        // overwrite it when done. Best effort only: `config.secret` and the HMAC's own key
        // copy are outside our control, and the seed `String` already lives in the vault.
        var key = Data(repeating: 0, count: config.secret.count)
        key.replaceSubrange(0..<key.count, with: config.secret)
        defer { Self.wipe(&key) }

        let unixSeconds = max(0, Int64(date.timeIntervalSince1970.rounded(.down)))
        let period = Int64(config.period)
        // RFC 4226 §5.2: the moving factor is an 8-byte big-endian counter.
        var counter = UInt64(unixSeconds / period).bigEndian
        let message = Data(bytes: &counter, count: MemoryLayout<UInt64>.size)

        let mac = crypto.hmac(config.algorithm, key: key, message: message)
        let value = try Self.truncate(mac, digits: config.digits)

        let digits = String(value)
        let padded = String(repeating: "0", count: max(0, config.digits - digits.count)) + digits
        return TOTPCode(
            digits: padded,
            period: config.period,
            secondsRemaining: Int(period - (unixSeconds % period))
        )
    }

    /// RFC 4226 §5.3 dynamic truncation: the low 4 bits of the last byte pick an offset; the
    /// 31 bits starting there (top bit masked so the result is never negative) are reduced
    /// modulo 10^digits.
    private static func truncate(_ mac: Data, digits: Int) throws -> UInt64 {
        let bytes = [UInt8](mac)
        guard let last = bytes.last else { throw TOTPError.invalidSecret }
        let offset = Int(last & 0x0F)
        guard offset + 4 <= bytes.count else { throw TOTPError.invalidSecret }
        let binary = (UInt32(bytes[offset] & 0x7F) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            |  UInt32(bytes[offset + 3])
        var modulus: UInt64 = 1
        for _ in 0..<digits { modulus *= 10 }
        return UInt64(binary) % modulus
    }

    /// Overwrites `buffer` with zeros. Exposed to tests; see the best-effort note above.
    static func wipe(_ buffer: inout Data) {
        buffer.resetBytes(in: 0..<buffer.count)
    }
}
