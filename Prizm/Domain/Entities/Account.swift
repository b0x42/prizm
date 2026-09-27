import Foundation

/// A successfully authenticated Bitwarden user account.
nonisolated struct Account: Codable, Equatable, Identifiable {
    /// Stable local identity. Remote user IDs are only unique within one server.
    let profileId: UUID
    let userId: String
    let email: String
    let name: String?
    let serverEnvironment: ServerEnvironment

    var id: UUID { profileId }

    init(
        profileId: UUID = UUID(),
        userId: String,
        email: String,
        name: String?,
        serverEnvironment: ServerEnvironment
    ) {
        self.profileId = profileId
        self.userId = userId
        self.email = email
        self.name = name
        self.serverEnvironment = serverEnvironment
    }
}

/// The server a user account belongs to (self-hosted Bitwarden or Vaultwarden).
/// Stored with the account profile in the macOS Keychain.
nonisolated struct ServerEnvironment: Codable, Equatable {

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
nonisolated struct ServerURLOverrides: Codable, Equatable {
    var api: URL?      = nil
    var identity: URL? = nil
    var icons: URL?    = nil
}
