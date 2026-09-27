import Foundation
import XCTest
@testable import Prizm

final class PrizmAPIClientSessionTests: XCTestCase {

    func testInvalidateSession_rejectsResponseFromPreviousAccount() async throws {
        let started = expectation(description: "request started")
        SessionURLProtocol.started = started
        SessionURLProtocol.gate = DispatchSemaphore(value: 0)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionURLProtocol.self]
        let client = PrizmAPIClientImpl(session: URLSession(configuration: configuration))
        await client.activateSession(
            baseURL: URL(string: "https://first.example.com")!,
            accessToken: "first-token"
        )

        let request = Task { try await client.preLogin(email: "alice@example.com") }
        await fulfillment(of: [started], timeout: 2)
        await client.invalidateSession()
        SessionURLProtocol.gate.signal()

        do {
            _ = try await request.value
            XCTFail("A response from the previous account session must be rejected")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionInvalidated)
        }
    }
}

private final class SessionURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var started: XCTestExpectation!
    nonisolated(unsafe) static var gate: DispatchSemaphore!

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.started.fulfill()
        DispatchQueue.global().async { [weak self] in
            Self.gate.wait()
            guard let self, let url = request.url else { return }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(
                self,
                didLoad: Data(#"{"kdf":0,"kdfIterations":600000}"#.utf8)
            )
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        Self.gate.signal()
    }
}
