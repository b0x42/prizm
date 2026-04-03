import Foundation

// MARK: - AboutViewModel

/// Backing model for `AboutView`.
///
/// A `@MainActor`-isolated value type holding immutable display strings. The type is
/// main-actor-isolated because it is only ever consumed by SwiftUI views, and because
/// `forCurrentApp()` must read `Bundle.main` (which is `@MainActor` in macOS 26+).
@MainActor
struct AboutViewModel {

    let appName: String
    let version: String
    let tagline: String
    let gitHubURL: URL

    /// Third-party libraries and protocols that Prizm relies on.
    ///
    /// These appear in the About window's Acknowledgements section so users
    /// can audit the full dependency chain — required by CONSTITUTION §VII
    /// (Radical Transparency).
    let acknowledgements: [String]

    // MARK: - Factory

    /// Reads display values from the main application bundle.
    ///
    /// `Bundle.main` is `@MainActor` on macOS 26+, so this factory must be called
    /// from a `@MainActor` context (e.g. a SwiftUI view's `body` or an `@MainActor` method).
    @MainActor
    static func forCurrentApp() -> AboutViewModel {
        AboutViewModel(
            appName: Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Prizm",
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            tagline: "Your secrets. Your server. Our user interface.",
            gitHubURL: URL(string: "https://github.com/b0x42/prizm")!,
            acknowledgements: [
                "Vaultwarden & Bitwarden — server API and vault format",
                "Argon2Swift — Argon2id key derivation (RFC 9106)",
            ]
        )
    }
}
