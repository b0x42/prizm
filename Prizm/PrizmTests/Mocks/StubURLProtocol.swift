import Foundation

/// `URLProtocol` stub for tests that need to see the exact request `PrizmAPIClientImpl` sends and answer
/// it without a network. Build the client with `StubURLProtocol.makeSession()` and set `requestHandler`
/// before the call; reset it in `tearDown`.
///
/// `URLProtocol` callbacks run on a `URLSession`-owned queue, not on the main actor, hence `nonisolated`.
/// The static state is only touched by one test at a time (XCTest runs a class's tests serially).
nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    /// Returns the HTTP status and body for a request (and its body bytes).
    nonisolated(unsafe) static var requestHandler: ((URLRequest, Data) -> (status: Int, body: Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        requestHandler = nil
        lastRequest = nil
        lastBody = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(of: request)
        Self.lastRequest = request
        Self.lastBody = body

        let (status, data) = Self.requestHandler?(request, body) ?? (500, Data())
        let response = HTTPURLResponse(
            url: request.url!,
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
