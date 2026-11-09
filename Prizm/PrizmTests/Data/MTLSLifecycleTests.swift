import XCTest
@testable import Prizm

final class MTLSLifecycleTests: XCTestCase {
    func testServerSwitchRejectsLateResponse() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PausedMTLSProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); PausedMTLSProtocol.reset() }
        let api = PrizmAPIClientImpl(session: session)
        try await api.setBaseURL(URL(string: "https://first.example")!)
        let started = expectation(description: "old request started")
        PausedMTLSProtocol.onStart = { started.fulfill() }
        let pending = Task { try await api.preLogin(email: "test@example.org") }
        await fulfillment(of: [started], timeout: 2)
        try await api.setBaseURL(URL(string: "https://second.example")!)
        PausedMTLSProtocol.complete()
        do { _ = try await pending.value; XCTFail("Stale response accepted") }
        catch is CancellationError { }
        catch { XCTFail("Expected cancellation, received \(error)") }
        let base = await api.baseURL
        XCTAssertEqual(base?.host, "second.example")
    }

    func testSignOutCancelsAndClearsServer() async throws {
        let api = PrizmAPIClientImpl(session: URLSession(configuration: .ephemeral))
        try await api.setBaseURL(URL(string: "https://vault.example")!)
        await api.clearAccessToken()
        let base = await api.baseURL
        XCTAssertNil(base)
        do { _ = try await api.preLogin(email: "test@example.org"); XCTFail("Signed-out client still connects") }
        catch APIError.baseURLNotSet { }
    }

    func testMissingIdentityFailsBeforeNetworkAndClearsPriorEnvironment() async throws {
        let name = "Prizm.mTLS.lifecycle.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let configuration = ClientCertificateConfiguration(defaults: defaults)
        let api = PrizmAPIClientImpl(sessionFactory: ServerSessionFactory(configuration: configuration, store: ClientCertificateStore()))
        try await api.setBaseURL(URL(string: "https://plain.example")!)
        let missing = ClientCertificateDetails(id: UUID(), name: "Missing test identity", issuer: "Test", notBefore: .distantPast,
                                               notAfter: .distantFuture, fingerprint: "test-only")
        try configuration.set(missing, for: ServerOrigin(url: URL(string: "https://vault.example")!))
        do { try await api.setBaseURL(URL(string: "https://vault.example")!); XCTFail("Missing identity accepted") }
        catch ClientCertificateError.unavailable { }
        let base = await api.baseURL
        XCTAssertNil(base, "Must not fall back to previous environment")
    }
}

nonisolated private final class PausedMTLSProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var pending: PausedMTLSProtocol?
    nonisolated(unsafe) private static var start: (@Sendable () -> Void)?
    static var onStart: (@Sendable () -> Void)? {
        get { lock.withLock { start } }
        set { lock.withLock { start = newValue } }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let notify = Self.lock.withLock { Self.pending = self; return Self.start }
        notify?()
    }
    override func stopLoading() { }
    static func reset() { lock.withLock { pending = nil; start = nil } }
    static func complete() {
        guard let instance = lock.withLock({ pending }) else { return }
        let response = HTTPURLResponse(url: instance.request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        instance.client?.urlProtocol(instance, didReceive: response, cacheStoragePolicy: .notAllowed)
        instance.client?.urlProtocol(instance, didLoad: Data("{\"kdf\":0,\"kdfIterations\":600000}".utf8))
        instance.client?.urlProtocolDidFinishLoading(instance)
    }
}
