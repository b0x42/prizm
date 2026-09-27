import Foundation

/// A time-based one-time password generated from a Bitwarden Login item's TOTP value.
nonisolated struct TOTPCode: Equatable, Sendable {
    let value: String
    let period: Int
    let secondsRemaining: Int
}

/// Produces RFC 6238 codes without exposing cryptographic frameworks outside Data.
protocol TOTPCodeGenerating: Sendable {
    func generateCode(from configuration: String, at date: Date) throws -> TOTPCode
}
