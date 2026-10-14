import Foundation

/// Turns a stored TOTP seed into a `TOTPConfiguration`.
///
/// Accepted forms (FR-008):
/// - a plain base32 secret (RFC 4648 §6), case-insensitive, spaces and `=` padding ignored;
/// - an `otpauth://totp/...` link with optional `secret`, `algorithm`, `digits`, `period`
///   query parameters (Google Authenticator "Key URI Format").
///
/// Anything else is rejected rather than coerced to defaults: silently showing a wrong code
/// would be worse than showing "unavailable" in a password manager.
///
/// Base32 decoding is an encoding, not cryptography, so it lives in the Domain layer
/// (Constitution §II). The seed is never logged or placed in an error (Constitution §III, §V).
nonisolated enum TOTPSeedParser {

    static func parse(_ seed: String) throws -> TOTPConfiguration {
        let trimmed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TOTPError.emptySeed }

        if trimmed.lowercased().hasPrefix("otpauth://") {
            return try parseKeyURI(trimmed)
        }
        // Any other scheme (e.g. Bitwarden's `steam://`) is not RFC 6238.
        if trimmed.contains("://") { throw TOTPError.unsupportedScheme }

        return TOTPConfiguration(
            secret: try decodeBase32(trimmed),
            algorithm: .sha1,
            digits: defaultDigits,
            period: defaultPeriod
        )
    }

    // MARK: - Defaults (RFC 6238 §4.1, RFC 4226 §5.3)

    private static let defaultDigits = 6
    private static let defaultPeriod = 30
    private static let allowedDigits = 6...8

    // MARK: - otpauth:// links

    private static func parseKeyURI(_ uri: String) throws -> TOTPConfiguration {
        guard let components = URLComponents(string: uri) else { throw TOTPError.invalidSecret }
        // The "host" slot carries the OTP type: `totp` or `hotp`.
        guard components.host?.lowercased() == "totp" else { throw TOTPError.unsupportedScheme }

        func value(_ name: String) -> String? {
            components.queryItems?.first { $0.name.lowercased() == name }?.value
        }

        guard let rawSecret = value("secret") else { throw TOTPError.invalidSecret }
        let secret = try decodeBase32(rawSecret)

        let algorithm: TOTPHashAlgorithm
        switch value("algorithm")?.uppercased() {
        case nil, "SHA1":  algorithm = .sha1
        case "SHA256":     algorithm = .sha256
        case "SHA512":     algorithm = .sha512
        default:           throw TOTPError.unsupportedParameter
        }

        let digits = try intParameter(value("digits"), default: defaultDigits)
        guard allowedDigits.contains(digits) else { throw TOTPError.unsupportedParameter }

        let period = try intParameter(value("period"), default: defaultPeriod)
        guard period > 0 else { throw TOTPError.unsupportedParameter }

        return TOTPConfiguration(secret: secret, algorithm: algorithm, digits: digits, period: period)
    }

    private static func intParameter(_ raw: String?, default fallback: Int) throws -> Int {
        guard let raw else { return fallback }
        guard let number = Int(raw) else { throw TOTPError.unsupportedParameter }
        return number
    }

    // MARK: - Base32 (RFC 4648 §6)

    private static let base32Alphabet: [Character: UInt8] = {
        var table: [Character: UInt8] = [:]
        for (index, character) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".enumerated() {
            table[character] = UInt8(index)
        }
        return table
    }()

    private static func decodeBase32(_ text: String) throws -> Data {
        var output = Data()
        var buffer: UInt32 = 0
        var bitCount = 0

        for character in text.uppercased() where !character.isWhitespace && character != "=" {
            guard let value = base32Alphabet[character] else { throw TOTPError.invalidSecret }
            buffer = (buffer << 5) | UInt32(value)
            bitCount += 5
            if bitCount >= 8 {
                output.append(UInt8((buffer >> UInt32(bitCount - 8)) & 0xFF))
                bitCount -= 8
            }
        }
        // Trailing bits (fewer than 8) are padding and are dropped, as RFC 4648 §6 specifies.
        guard !output.isEmpty else { throw TOTPError.invalidSecret }
        return output
    }
}
