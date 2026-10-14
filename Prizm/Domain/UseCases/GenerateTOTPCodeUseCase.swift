import Foundation

/// Produces the one-time code valid at a given moment for a stored TOTP seed.
///
/// Behavior (RFC 6238 §4, RFC 4226 §5):
/// - counter = floor(unixSeconds / period), encoded as 8 bytes big-endian;
/// - HMAC of the counter keyed with the seed, then dynamic truncation and modulo 10^digits,
///   zero-padded to the configured length;
/// - `secondsRemaining = period - (unixSeconds mod period)`.
///
/// Pure with respect to its arguments, and it needs no vault key, so it works whenever the
/// caller already holds the decrypted seed. Throws `TOTPError` for unusable seeds.
nonisolated protocol GenerateTOTPCodeUseCase: Sendable {
    func execute(seed: String, at date: Date) async throws -> TOTPCode
}
