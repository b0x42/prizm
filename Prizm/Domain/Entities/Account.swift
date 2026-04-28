import Foundation

/// A successfully authenticated Bitwarden user account.
nonisolated struct Account: Equatable {
    let userId: String
    let email: String
    let name: String?
    let serverEnvironment: ServerEnvironment
}

/// Identifies the type of Bitwarden server for an account.
/// Raw `String` values are stored in Keychain — do NOT rename after any release
/// that has written Keychain data (Keychain storage contract).
nonisolated enum ServerType: String, Codable, Equatable {
    case cloudUS    = "cloudUS"
    case cloudEU    = "cloudEU"
    case selfHosted = "selfHosted"

    /// User-visible display name used in the login picker and VoiceOver announcements.
    var displayName: String {
        switch self {
        case .cloudUS:    return "Bitwarden Cloud (US)"
        case .cloudEU:    return "Bitwarden Cloud (EU)"
        case .selfHosted: return "Self-hosted"
        }
    }
}

/// The server a user account belongs to (cloud Bitwarden or self-hosted Vaultwarden).
/// Stored as JSON in the Keychain under `bw.macos:{userId}:serverEnvironment`.
nonisolated struct ServerEnvironment: Codable, Equatable {

    /// The base URL supplied by the user, or a sentinel value for cloud environments.
    let base: URL

    /// Per-service URL overrides. Ignored for cloud server types; used for self-hosted only.
    var overrides: ServerURLOverrides?

    /// Identifies the server type. Defaults to `.selfHosted` for backwards compatibility
    /// with Keychain records written before this property existed.
    var serverType: ServerType

    init(base: URL, overrides: ServerURLOverrides? = nil, serverType: ServerType = .selfHosted) {
        self.base = base
        self.overrides = overrides
        self.serverType = serverType
    }

    // Custom Codable so legacy records lacking `serverType` decode as `.selfHosted`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        base      = try container.decode(URL.self, forKey: .base)
        overrides = try container.decodeIfPresent(ServerURLOverrides.self, forKey: .overrides)
        serverType = try container.decodeIfPresent(ServerType.self, forKey: .serverType) ?? .selfHosted
    }

    enum CodingKeys: String, CodingKey {
        case base, overrides, serverType
    }

    // MARK: - Static factory methods

    /// Returns a `ServerEnvironment` configured for Bitwarden Cloud US.
    /// `base` is set to a sentinel URL — cloud URL routing ignores `base`.
    static func cloudUS() -> ServerEnvironment {
        ServerEnvironment(
            base:       URL(string: "https://bitwarden.com")!,
            overrides:  nil,
            serverType: .cloudUS
        )
    }

    /// Returns a `ServerEnvironment` configured for Bitwarden Cloud EU.
    /// `base` is set to a sentinel URL — cloud URL routing ignores `base`.
    static func cloudEU() -> ServerEnvironment {
        ServerEnvironment(
            base:       URL(string: "https://bitwarden.com")!,
            overrides:  nil,
            serverType: .cloudEU
        )
    }

    // MARK: - Computed URL properties

    /// API service URL. Cloud cases return canonical hostnames; self-hosted appends `/api` to `base`.
    var apiURL: URL {
        switch serverType {
        case .cloudUS:    return URL(string: "https://api.bitwarden.com")!
        case .cloudEU:    return URL(string: "https://api.bitwarden.eu")!
        case .selfHosted: return overrides?.api ?? base.appendingPathComponent("api")
        }
    }

    /// Identity service URL. Cloud cases return canonical hostnames; self-hosted appends `/identity` to `base`.
    var identityURL: URL {
        switch serverType {
        case .cloudUS:    return URL(string: "https://identity.bitwarden.com")!
        case .cloudEU:    return URL(string: "https://identity.bitwarden.eu")!
        case .selfHosted: return overrides?.identity ?? base.appendingPathComponent("identity")
        }
    }

    /// Icons CDN URL. Cloud cases share a single global CDN; self-hosted appends `/icons` to `base`.
    var iconsURL: URL {
        switch serverType {
        case .cloudUS, .cloudEU: return URL(string: "https://icons.bitwarden.net")!
        case .selfHosted:        return overrides?.icons ?? base.appendingPathComponent("icons")
        }
    }
}

/// Optional per-service URL overrides for self-hosted deployments that
/// separate their API, identity and icon services onto different hosts.
nonisolated struct ServerURLOverrides: Codable, Equatable {
    var api: URL?      = nil
    var identity: URL? = nil
    var icons: URL?    = nil
}
