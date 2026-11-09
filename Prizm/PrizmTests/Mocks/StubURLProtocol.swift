import Foundation
import os

/// `URLProtocol` stub for tests that need to see the exact request `PrizmAPIClientImpl` sends and answer
/// it without a network. Build the client with `StubURLProtocol.makeSession()` and set `requestHandler`
/// before the call; reset it in `tearDown`.
///
/// `URLProtocol` callbacks run on a `URLSession`-owned queue, not on the main actor, hence `nonisolated`.
/// The static state is lock-guarded because `startLoading` writes it from a `URLSession` queue while the
/// test reads it from the main actor, and parallel testing could run two stubbed tests at once.
nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    private struct State {
        var requestHandler: ((URLRequest, Data) -> (status: Int, body: Data))?
        var lastRequest: URLRequest?
        var lastBody: Data?
    }
    private static let state = OSAllocatedUnfairLock(uncheckedState: State())

    /// Returns the HTTP status and body for a request (and its body bytes).
    static var requestHandler: ((URLRequest, Data) -> (status: Int, body: Data))? {
        get { state.withLockUnchecked { $0.requestHandler } }
        set { state.withLockUnchecked { $0.requestHandler = newValue } }
    }
    static var lastRequest: URLRequest? { state.withLockUnchecked { $0.lastRequest } }
    static var lastBody: Data? { state.withLockUnchecked { $0.lastBody } }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        state.withLockUnchecked { $0 = State() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(of: request)
        let handler = Self.state.withLockUnchecked { state -> ((URLRequest, Data) -> (status: Int, body: Data))? in
            state.lastRequest = request
            state.lastBody = body
            return state.requestHandler
        }

        // Fail loudly: a test that forgot `requestHandler` should see an error naming the cause, not a mystery 500.
        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "StubURLProtocol: no requestHandler set, or request has no URL"
            ]))
            return
        }

        let (status, data) = handler(request, body)
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// `URLSession` hands request bodies to protocols as a stream, `httpBody` is usually nil there.
    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
