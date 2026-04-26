//
//  Config.swift
//  Prizm
//
//  Created by Benjamin Burzan on 16.03.26.
//

import Foundation

// MARK: - Vault lock notification

extension Notification.Name {
    /// Posted on the main thread whenever the vault is locked (sign-out or explicit lock).
    /// `ItemEditViewModel` subscribes to dismiss the edit sheet immediately, without a
    /// confirmation prompt, and clear the `DraftVaultItem` from memory (Constitution §III).
    static let vaultDidLock = Notification.Name("com.prizm.vaultDidLock")
}

// MARK: - App config

enum Config {
    static nonisolated let clientName = "desktop"
    static let deviceType = 7

    /// Registered Bitwarden client identifier, injected at build time via LocalSecrets.xcconfig.
    /// Empty string when LocalSecrets.xcconfig is absent — cloud login fails fast with
    /// AuthError.clientIdentifierNotConfigured before any network request is attempted.
    ///
    /// `nonisolated` prevents @MainActor isolation (inferred from Bundle.main) from
    /// propagating to every actor that reads this constant. String is Sendable so the
    /// value is safe to share across isolation domains without the `unsafe` qualifier.
    static nonisolated let bitwardenClientIdentifier: String =
        Bundle.main.object(forInfoDictionaryKey: "BWClientIdentifier") as? String ?? ""

    /// Bitwarden server API version Prizm was last tested against.
    /// Update when testing against a newer server release.
    static let bitwardenApiVersion = "2026.4.0"
}

/// Gates verbose debug logging throughout the Data layer.
///
/// Enable by adding `--debug-mode` to the Xcode scheme's Run → Arguments section,
/// or by passing it on the command line when launching from Terminal.
///
/// **Never enable in production builds** — debug output may contain sensitive field
/// names, cipher counts, and HTTP response structure (though never key material or tokens).
enum DebugConfig {
    // Safe to access from any isolation domain — Bool is Sendable and this is a let constant.
    static nonisolated let isEnabled: Bool = CommandLine.arguments.contains("--debug-mode")
}
