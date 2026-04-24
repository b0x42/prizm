import XCTest
@testable import Prizm

final class ServerEnvironmentTests: XCTestCase {

    // MARK: - 3.1: cloudUS returns US canonical URLs

    func testCloudUS_returnsUSCanonicalURLs() {
        let env = ServerEnvironment.cloudUS()
        XCTAssertEqual(env.apiURL.absoluteString,      "https://api.bitwarden.com")
        XCTAssertEqual(env.identityURL.absoluteString, "https://identity.bitwarden.com")
        XCTAssertEqual(env.iconsURL.absoluteString,    "https://icons.bitwarden.net")
    }

    // MARK: - 3.2: cloudEU returns EU canonical URLs

    func testCloudEU_returnsEUCanonicalURLs() {
        let env = ServerEnvironment.cloudEU()
        XCTAssertEqual(env.apiURL.absoluteString,      "https://api.bitwarden.eu")
        XCTAssertEqual(env.identityURL.absoluteString, "https://identity.bitwarden.eu")
        XCTAssertEqual(env.iconsURL.absoluteString,    "https://icons.bitwarden.net")
    }

    // MARK: - 3.3: selfHosted returns base-derived URLs

    func testSelfHosted_returnsBaseDerivedURLs() {
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        XCTAssertEqual(env.apiURL.absoluteString,      "https://vault.example.com/api")
        XCTAssertEqual(env.identityURL.absoluteString, "https://vault.example.com/identity")
        XCTAssertEqual(env.iconsURL.absoluteString,    "https://vault.example.com/icons")
    }

    // MARK: - 3.4: Cloud ignores overrides

    func testCloudUS_ignoresOverrides() {
        let overrides = ServerURLOverrides(
            api:      URL(string: "https://custom-api.example.com")!,
            identity: URL(string: "https://custom-id.example.com")!,
            icons:    URL(string: "https://custom-icons.example.com")!
        )
        var env = ServerEnvironment.cloudUS()
        env.overrides = overrides
        XCTAssertEqual(env.apiURL.absoluteString,      "https://api.bitwarden.com")
        XCTAssertEqual(env.identityURL.absoluteString, "https://identity.bitwarden.com")
        XCTAssertEqual(env.iconsURL.absoluteString,    "https://icons.bitwarden.net")
    }

    // MARK: - 3.5: Legacy JSON (no serverType key) decodes as selfHosted

    func testDecode_legacyRecord_decodesAsSelfHosted() throws {
        let json = """
        {"base": "https://vault.example.com"}
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(ServerEnvironment.self, from: json)
        XCTAssertEqual(env.serverType, .selfHosted)
        XCTAssertEqual(env.base.absoluteString, "https://vault.example.com")
    }

    // MARK: - 3.6: Round-trip encode/decode preserves exact raw strings

    func testEncodeDecode_cloudUS_preservesRawString() throws {
        let env = ServerEnvironment.cloudUS()
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ServerEnvironment.self, from: data)
        XCTAssertEqual(decoded.serverType, .cloudUS)
        XCTAssertEqual(decoded.serverType.rawValue, "cloudUS")
    }

    func testEncodeDecode_cloudEU_preservesRawString() throws {
        let env = ServerEnvironment.cloudEU()
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ServerEnvironment.self, from: data)
        XCTAssertEqual(decoded.serverType, .cloudEU)
        XCTAssertEqual(decoded.serverType.rawValue, "cloudEU")
    }

    func testEncodeDecode_selfHosted_preservesRawString() throws {
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        let data = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(ServerEnvironment.self, from: data)
        XCTAssertEqual(decoded.serverType, .selfHosted)
        XCTAssertEqual(decoded.serverType.rawValue, "selfHosted")
    }
}
