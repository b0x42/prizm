#if DEBUG
import Foundation

/// Seeds an in-memory vault for XCUITest, so UI journeys can run without a server or a login.
///
/// Enabled only by the `--ui-test-vault` launch argument and compiled out of Release builds
/// (`#if DEBUG`), so a shipping password manager contains no test-vault backdoor. The fixtures
/// use made-up names and RFC 6238 test secrets, never real credentials.
enum UITestFixtures {

    static let launchArgument = "--ui-test-vault"

    static var isEnabled: Bool { CommandLine.arguments.contains(launchArgument) }

    /// With `--ui-test-open-codes`, start on the Codes list with its first item selected.
    static var opensOnCodes: Bool { CommandLine.arguments.contains("--ui-test-open-codes") }

    /// RFC 6238 Appendix B secret "12345678901234567890" in base32.
    static let rfcSeed = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

    static var items: [VaultItem] {
        [
            login(id: "alpha", name: "Alpha Bank", totp: rfcSeed),
            login(id: "beta", name: "Beta Mail",
                  totp: "otpauth://totp/Beta:me?secret=\(rfcSeed)&digits=8&period=60&algorithm=SHA256"),
            login(id: "gamma", name: "Gamma No Seed", totp: nil),
            login(id: "delta", name: "Delta Bad Seed", totp: "not-a-seed!"),
            login(id: "zeta", name: "Zeta Trashed", totp: rfcSeed, isDeleted: true),
        ]
    }

    private static func login(id: String, name: String, totp: String?, isDeleted: Bool = false) -> VaultItem {
        VaultItem(
            id: id, name: name, isFavorite: false, isDeleted: isDeleted,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            revisionDate: Date(timeIntervalSince1970: 1_700_000_000),
            content: .login(LoginContent(
                username: "user-\(id)", password: "pw-\(id)", uris: [], totp: totp, notes: nil, customFields: []
            ))
        )
    }
}
#endif
