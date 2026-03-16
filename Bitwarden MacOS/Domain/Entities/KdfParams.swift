import Foundation

/// Key derivation function algorithm identifiers as defined by the Bitwarden API.
/// Returned by the `/accounts/prelogin` endpoint and persisted in the Keychain.
enum KdfType: Int, Codable, Equatable {
    /// PBKDF2-SHA256 (Bitwarden default, kdfType = 0).
    case pbkdf2 = 0
    /// Argon2id (kdfType = 1). Requires `memory` and `parallelism` parameters.
    case argon2id = 1
}

/// Parameters for the master-key derivation step.
/// Persisted as JSON in the Keychain under `bw.macos:{userId}:kdfParams`
/// so the unlock flow can derive the master key locally without a network call.
struct KdfParams: Codable, Equatable {
    let type: KdfType

    /// Iteration count.
    /// • PBKDF2: minimum 600 000 (Bitwarden default 600 000).
    /// • Argon2id: time-cost parameter (Bitwarden default 3).
    let iterations: Int

    /// Memory cost in KiB. Argon2id only; nil for PBKDF2 (Bitwarden default 64 MiB = 65536 KiB).
    let memory: Int?

    /// Degree of parallelism. Argon2id only; nil for PBKDF2 (Bitwarden default 4).
    let parallelism: Int?
}
