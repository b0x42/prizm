import CryptoKit
import Foundation

/// Generates Bitwarden-compatible time-based one-time passwords.
///
/// Security goal: derive short-lived authentication codes locally so the TOTP secret never
/// leaves the device. HOTP truncation follows RFC 4226 §5.3 and the time counter follows
/// RFC 6238 §4.2. Base32 decoding follows RFC 4648 §6.
///
/// SHA-1 is accepted only because it is the interoperable RFC 6238 default. Its collision
/// weaknesses do not break HMAC-SHA1's PRF use here. SHA-256 and SHA-512 are also supported.
/// Secret bytes are cleared after each calculation; unavoidable copies owned by CryptoKit
/// cannot be explicitly zeroed by this API.
nonisolated struct TOTPCodeGeneratorImpl: TOTPCodeGenerating {
    func generateCode(from configuration: String, at date: Date) throws -> TOTPCode {
        var parameters = try parse(configuration)
        defer {
            parameters.secret.resetBytes(in: 0..<parameters.secret.count)
        }

        guard date.timeIntervalSince1970 >= 0 else {
            throw TOTPCodeError.invalidConfiguration
        }

        let unixTime = UInt64(date.timeIntervalSince1970.rounded(.down))
        var counter = (unixTime / UInt64(parameters.period)).bigEndian
        let counterData = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: parameters.secret)

        let digest: Data
        switch parameters.algorithm {
        case .sha1:
            digest = Data(HMAC<Insecure.SHA1>.authenticationCode(
                for: counterData,
                using: key
            ))
        case .sha256:
            digest = Data(HMAC<SHA256>.authenticationCode(
                for: counterData,
                using: key
            ))
        case .sha512:
            digest = Data(HMAC<SHA512>.authenticationCode(
                for: counterData,
                using: key
            ))
        }

        // Dynamic truncation is defined by RFC 4226 §5.3.
        let offset = Int(digest[digest.index(before: digest.endIndex)] & 0x0f)
        guard offset + 3 < digest.count else {
            throw TOTPCodeError.invalidConfiguration
        }
        let binaryCode =
            (UInt32(digest[offset]) & 0x7f) << 24 |
            UInt32(digest[offset + 1]) << 16 |
            UInt32(digest[offset + 2]) << 8 |
            UInt32(digest[offset + 3])
        let modulus = (0..<parameters.digits).reduce(1) { result, _ in result * 10 }
        let value = String(format: "%0*u", parameters.digits, binaryCode % UInt32(modulus))
        let elapsedInPeriod = Int(unixTime % UInt64(parameters.period))

        return TOTPCode(
            value: value,
            period: parameters.period,
            secondsRemaining: parameters.period - elapsedInPeriod
        )
    }

    private func parse(_ configuration: String) throws -> Parameters {
        let trimmed = configuration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TOTPCodeError.missingSecret }

        if trimmed.lowercased().hasPrefix("otpauth://") {
            guard let components = URLComponents(string: trimmed),
                  components.scheme?.lowercased() == "otpauth",
                  components.host?.lowercased() == "totp" else {
                throw TOTPCodeError.unsupportedConfiguration
            }

            let queryItems = components.queryItems ?? []
            guard let secretValue = queryItems.first(where: {
                $0.name.caseInsensitiveCompare("secret") == .orderedSame
            })?.value else {
                throw TOTPCodeError.missingSecret
            }

            let algorithm = try Algorithm(
                queryItems.first(where: {
                    $0.name.caseInsensitiveCompare("algorithm") == .orderedSame
                })?.value
            )
            let digits = try positiveInteger(
                queryItems.first(where: {
                    $0.name.caseInsensitiveCompare("digits") == .orderedSame
                })?.value,
                defaultValue: 6,
                allowed: 6...8
            )
            let period = try positiveInteger(
                queryItems.first(where: {
                    $0.name.caseInsensitiveCompare("period") == .orderedSame
                })?.value,
                defaultValue: 30,
                allowed: 1...300
            )

            return Parameters(
                secret: try decodeBase32(secretValue),
                algorithm: algorithm,
                digits: digits,
                period: period
            )
        }

        return Parameters(
            secret: try decodeBase32(trimmed),
            algorithm: .sha1,
            digits: 6,
            period: 30
        )
    }

    private func positiveInteger(
        _ value: String?,
        defaultValue: Int,
        allowed: ClosedRange<Int>
    ) throws -> Int {
        guard let value else { return defaultValue }
        guard let parsed = Int(value), allowed.contains(parsed) else {
            throw TOTPCodeError.invalidConfiguration
        }
        return parsed
    }

    private func decodeBase32(_ encoded: String) throws -> Data {
        let normalized = encoded
            .uppercased()
            .filter { !$0.isWhitespace && $0 != "-" && $0 != "=" }
        guard !normalized.isEmpty else { throw TOTPCodeError.missingSecret }

        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        let lookup = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) })
        var output = Data()
        var accumulator: UInt64 = 0
        var bitCount = 0

        for character in normalized {
            guard let value = lookup[character] else {
                output.resetBytes(in: 0..<output.count)
                throw TOTPCodeError.invalidBase32
            }
            accumulator = (accumulator << 5) | UInt64(value)
            bitCount += 5

            if bitCount >= 8 {
                bitCount -= 8
                output.append(UInt8((accumulator >> UInt64(bitCount)) & 0xff))
                accumulator &= bitCount == 0 ? 0 : (1 << UInt64(bitCount)) - 1
            }
        }

        guard !output.isEmpty, accumulator == 0 else {
            output.resetBytes(in: 0..<output.count)
            throw TOTPCodeError.invalidBase32
        }
        return output
    }
}

private extension TOTPCodeGeneratorImpl {
    nonisolated struct Parameters {
        var secret: Data
        let algorithm: Algorithm
        let digits: Int
        let period: Int
    }

    nonisolated enum Algorithm {
        case sha1
        case sha256
        case sha512

        init(_ rawValue: String?) throws {
            switch rawValue?.uppercased() ?? "SHA1" {
            case "SHA1":   self = .sha1
            case "SHA256": self = .sha256
            case "SHA512": self = .sha512
            default: throw TOTPCodeError.unsupportedAlgorithm
            }
        }
    }
}

nonisolated enum TOTPCodeError: LocalizedError {
    case missingSecret
    case invalidBase32
    case invalidConfiguration
    case unsupportedConfiguration
    case unsupportedAlgorithm

    var errorDescription: String? {
        switch self {
        case .missingSecret:             "Enter an authenticator key."
        case .invalidBase32:             "The authenticator key is not valid Base32."
        case .invalidConfiguration:      "The authenticator configuration is invalid."
        case .unsupportedConfiguration:  "Only time-based otpauth configurations are supported."
        case .unsupportedAlgorithm:      "The authenticator algorithm is not supported."
        }
    }
}
