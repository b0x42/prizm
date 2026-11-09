import XCTest
@testable import Prizm

/// Request-level tests for `PrizmAPIClientImpl.preLogin`.
///
/// Vaultwarden 1.37 serves prelogin only under `/identity/accounts/prelogin`; the old
/// `/api/accounts/prelogin` route was removed and answers 404, which made every login fail (#80).
/// The official Bitwarden clients also call the identity service.
@MainActor
final class PrizmAPIClientPreLoginTests: XCTestCase {

    override func tearDown() async throws {
        StubURLProtocol.reset()
        try await super.tearDown()
    }

    func testPreLogin_postsToTheIdentityEndpoint() async throws {
        let json = #"{"kdf":1,"kdfIterations":6,"kdfMemory":32,"kdfParallelism":4}"#
        StubURLProtocol.requestHandler = { _, _ in (200, Data(json.utf8)) }

        let client = PrizmAPIClientImpl(session: StubURLProtocol.makeSession())
        await client.setBaseURL(URL(string: "https://vault.example.com")!)

        let response = try await client.preLogin(email: "user@example.com")

        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/identity/accounts/prelogin")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let sentBody = try JSONDecoder().decode([String: String].self, from: try XCTUnwrap(StubURLProtocol.lastBody))
        XCTAssertEqual(sentBody, ["email": "user@example.com"])
        XCTAssertEqual(response.kdf, 1)
        XCTAssertEqual(response.kdfIterations, 6)
        XCTAssertEqual(response.kdfMemory, 32)
        XCTAssertEqual(response.kdfParallelism, 4)
    }
}
