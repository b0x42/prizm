import Foundation

/// A successfully authenticated Bitwarden user account.
struct Account: Equatable {
    let userId: String
    let email: String
    let name: String?
    let serverEnvironment: ServerEnvironment
}

/// The server a user account belongs to (self-hosted Bitwarden or Vaultwarden).
/// Stored as JSON in the Keychain under `bw.macos:{userId}:serverEnvironment`.
struct ServerEnvironment: Codable, Equatable {

    /// The base URL supplied by the user (e.g. `https://vault.example.com`).
    let base: URL

    /// Per-service URL overrides. When nil the default derived paths are used.
    var overrides: ServerURLOverrides?

    /// `{base}/api` unless overridden.
    var apiURL: URL { overrides?.api ?? base.appendingPathComponent("api") }

    /// `{base}/identity` unless overridden.
    var identityURL: URL { overrides?.identity ?? base.appendingPathComponent("identity") }

    /// `{base}/icons` unless overridden.
    var iconsURL: URL { overrides?.icons ?? base.appendingPathComponent("icons") }
}

/// Optional per-service URL overrides for self-hosted deployments that
/// separate their API, identity and icon services onto different hosts.
struct ServerURLOverrides: Codable, Equatable {
    var api: URL?
    var identity: URL?
    var icons: URL?
}
