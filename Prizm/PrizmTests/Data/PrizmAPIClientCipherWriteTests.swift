import XCTest
@testable import Prizm

/// Request-level tests for the cipher write calls of `PrizmAPIClientImpl`.
///
/// Vaultwarden 1.37 (web-v2025.6.0 and later clients) declares `encryptedFor`, the id of the authenticated
/// user, as mandatory in `CipherData` and rejects bodies without it ("missing field `encryptedFor`").
/// The id is the `sub` claim of the access token (a JWT).
@MainActor
final class PrizmAPIClientCipherWriteTests: XCTestCase {

    private let userId = "11111111-2222-3333-4444-555555555555"
    private let cipherJSON = #"{"id":"c1","type":1,"name":"2.AAAA|BBBB|CCCC","favorite":false}"#

    override func tearDown() async throws {
        StubURLProtocol.reset()
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// A JWT with `{"sub": <subject>}` as payload. The client never checks the signature.
    private func makeToken(subject: String) -> String {
        func base64url(_ text: String) -> String {
            Data(text.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return [base64url(#"{"alg":"none"}"#), base64url(#"{"sub":"\#(subject)"}"#), "signature"].joined(separator: ".")
    }

    private func makeClient(token: String?) async -> PrizmAPIClientImpl {
        let json = cipherJSON
        StubURLProtocol.requestHandler = { _, _ in (200, Data(json.utf8)) }
        let client = PrizmAPIClientImpl(session: StubURLProtocol.makeSession())
        await client.setBaseURL(URL(string: "https://vault.example.com")!)
        if let token { await client.setAccessToken(token) }
        return client
    }

    private func makeCipher() throws -> RawCipher {
        try JSONDecoder().decode(RawCipher.self, from: Data(cipherJSON.utf8))
    }

    private func sentBody() throws -> [String: Any] {
        let body = try XCTUnwrap(StubURLProtocol.lastBody)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    // MARK: - Tests

    func testCreateCipher_sendsEncryptedForFromTheTokenSubject() async throws {
        let client = await makeClient(token: makeToken(subject: userId))

        _ = try await client.createCipher(cipher: try makeCipher())

        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/ciphers")
        let body = try sentBody()
        XCTAssertEqual(body["encryptedFor"] as? String, userId)
        XCTAssertEqual(body["name"] as? String, "2.AAAA|BBBB|CCCC", "the cipher itself must be sent unchanged")
    }

    func testUpdateCipher_sendsEncryptedForFromTheTokenSubject() async throws {
        let client = await makeClient(token: makeToken(subject: userId))

        _ = try await client.updateCipher(id: "c1", cipher: try makeCipher())

        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/ciphers/c1")
        XCTAssertEqual(try sentBody()["encryptedFor"] as? String, userId)
    }

    func testCreateOrgCipher_sendsEncryptedForInsideTheCipherObject() async throws {
        let client = await makeClient(token: makeToken(subject: userId))

        _ = try await client.createOrgCipher(cipher: try makeCipher())

        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/ciphers/create")
        let body = try sentBody()
        let cipher = try XCTUnwrap(body["cipher"] as? [String: Any])
        XCTAssertEqual(cipher["encryptedFor"] as? String, userId)
        XCTAssertNil(body["encryptedFor"], "the wrapper object does not carry the field, only the cipher does")
        XCTAssertNotNil(body["collectionIds"])
    }

    func testCreateCipher_withoutAccessToken_doesNotInventEncryptedFor() async throws {
        let client = await makeClient(token: nil)

        _ = try await client.createCipher(cipher: try makeCipher())

        XCTAssertNil(try sentBody()["encryptedFor"])
    }
}
