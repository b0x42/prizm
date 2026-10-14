import Foundation

// MARK: - TOTPHashAlgorithm

/// HMAC hash used to derive a time-based one-time password.
///
/// RFC 6238 §1.2 allows HMAC-SHA-1, HMAC-SHA-256 and HMAC-SHA-512. SHA-1 is the default
/// because nearly every service issues SHA-1 seeds. The Domain layer only *names* the
/// algorithm; the Data layer maps it to CryptoKit (Constitution §II, §III).
nonisolated enum TOTPHashAlgorithm: Equatable, Hashable {
    case sha1
    case sha256
    case sha512
}

// MARK: - TOTPError

/// Reasons a stored seed cannot produce a code.
///
/// Security: no case carries an associated value, so a seed can never leak into a log
/// line or error description through this type (Constitution §III, §V).
nonisolated enum TOTPError: Error, Equatable {
    /// The seed is empty or only whitespace.
    case emptySeed
    /// The secret is not valid base32, is missing, or decodes to zero bytes.
    case invalidSecret
    /// A seed form we do not support, e.g. `steam://` or `otpauth://hotp`.
    case unsupportedScheme
    /// An unknown algorithm, digits outside 6...8, or a non-positive period.
    case unsupportedParameter
}

// MARK: - TOTPConfiguration

/// The parsed form of a stored TOTP seed.
///
/// Built only by `TOTPSeedParser.parse(_:)`. It is parsed per refresh pass and dropped, so no
/// extra copy of the secret outlives the pass (see data-model.md).
nonisolated struct TOTPConfiguration: Equatable {
    /// Decoded base32 bytes. Must be non-empty.
    let secret: Data
    let algorithm: TOTPHashAlgorithm
    /// 6 to 8 (RFC 4226 §5.3 requires at least 6). Default 6.
    let digits: Int
    /// Validity period in seconds, greater than 0. Default 30 (RFC 6238 §4.1).
    let period: Int
}
