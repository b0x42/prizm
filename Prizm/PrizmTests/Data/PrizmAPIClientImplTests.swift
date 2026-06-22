import XCTest
@testable import Prizm

// MARK: - CapturingURLProtocol

/// URLProtocol subclass that captures every outbound request and returns a configured response.
/// All shared state is guarded by a lock because `startLoading()` runs on URLSession's
/// delegate queue while tests read from `@MainActor`.
final class CapturingURLProtocol: URLProtocol {

    private static let lock = NSLock()
    private nonisolated(unsafe) static var _capturedRequests: [URLRequest] = []
    private nonisolated(unsafe) static var _nextStatusCode: Int = 200
    private nonisolated(unsafe) static var _nextResponseData: Data = Data("{}".utf8)

    static var capturedRequests: [URLRequest] {
        get { lock.withLock { _capturedRequests } }
        set { lock.withLock { _capturedRequests = newValue } }
    }
    static var nextStatusCode: Int {
        get { lock.withLock { _nextStatusCode } }
        set { lock.withLock { _nextStatusCode = newValue } }
    }
    static var nextResponseData: Data {
        get { lock.withLock { _nextResponseData } }
        set { lock.withLock { _nextResponseData = newValue } }
    }

    static var lastRequest: URLRequest? { capturedRequests.last }

    static func reset() {
        lock.withLock {
            _capturedRequests = []
            _nextStatusCode   = 200
            _nextResponseData = Data("{}".utf8)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // URLSession moves httpBody into httpBodyStream; read it back so tests can inspect it.
        var captured = request
        if let stream = request.httpBodyStream {
            var body = Data()
            stream.open()
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            defer { buf.deallocate() }
            while stream.hasBytesAvailable {
                let n = stream.read(buf, maxLength: 1024)
                if n > 0 { body.append(buf, count: n) }
            }
            stream.close()
            captured.httpBody = body
        }

        let (statusCode, responseData) = CapturingURLProtocol.lock.withLock {
            CapturingURLProtocol._capturedRequests.append(captured)
            return (CapturingURLProtocol._nextStatusCode, CapturingURLProtocol._nextResponseData)
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - PrizmAPIClientImplTests

@MainActor
final class PrizmAPIClientImplTests: XCTestCase {

    private var sut: PrizmAPIClientImpl!

    override func setUp() async throws {
        try await super.setUp()
        CapturingURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        let session = URLSession(configuration: config)
        sut = PrizmAPIClientImpl(session: session)
    }

    // MARK: - 6.1: cloudUS preLogin URL

    func testCloudUS_preLogin_usesCorrectURL() async throws {
        await sut.setServerEnvironment(.cloudUS())
        CapturingURLProtocol.nextResponseData = preLoginJSON()

        _ = try await sut.preLogin(email: "t@t.com")

        XCTAssertEqual(
            CapturingURLProtocol.lastRequest?.url?.absoluteString,
            "https://identity.bitwarden.com/accounts/prelogin"
        )
    }

    // MARK: - 6.2: cloudEU identityToken URL

    func testCloudEU_identityToken_usesCorrectURL() async throws {
        await sut.setServerEnvironment(.cloudEU())
        // Return 400 device_error — we just need the URL to be captured before the throw.
        CapturingURLProtocol.nextStatusCode    = 400
        CapturingURLProtocol.nextResponseData  = Data(#"{"error":"device_error"}"#.utf8)

        do {
            _ = try await sut.identityToken(
                email: "t@t.com", passwordHash: "hash",
                deviceIdentifier: "dev-id",
                twoFactorToken: nil, twoFactorProvider: nil, twoFactorRemember: false,
                newDeviceOTP: nil
            )
        } catch { /* expected throw */ }

        XCTAssertEqual(
            CapturingURLProtocol.lastRequest?.url?.absoluteString,
            "https://identity.bitwarden.eu/connect/token"
        )
    }

    // MARK: - 6.3: cloudEU refreshAccessToken URL

    func testCloudEU_refreshAccessToken_usesCorrectURL() async throws {
        await sut.setServerEnvironment(.cloudEU())
        CapturingURLProtocol.nextResponseData = refreshTokenJSON()

        _ = try await sut.refreshAccessToken(refreshToken: "rt")

        XCTAssertEqual(
            CapturingURLProtocol.lastRequest?.url?.absoluteString,
            "https://identity.bitwarden.eu/connect/token"
        )
    }

    // MARK: - 6.4: selfHosted fetchSync URL includes /api/ prefix

    func testSelfHosted_fetchSync_retainsApiPrefix() async throws {
        let base = URL(string: "https://vault.example.com")!
        await sut.setServerEnvironment(ServerEnvironment(base: base, overrides: nil))
        CapturingURLProtocol.nextResponseData = syncJSON()

        _ = try await sut.fetchSync()

        let urlString = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(
            urlString.hasPrefix("https://vault.example.com/api/sync"),
            "Expected self-hosted URL to include /api/ prefix, got: \(urlString)"
        )
    }

    // MARK: - 6.5: no environment → serverEnvironmentNotSet

    func testNoEnvironment_throwsServerEnvironmentNotSet() async throws {
        do {
            _ = try await sut.preLogin(email: "t@t.com")
            XCTFail("Expected APIError.serverEnvironmentNotSet")
        } catch APIError.serverEnvironmentNotSet {
            // pass
        }
    }

    // MARK: - 6.6: cloud identityToken sends required headers

    func testCloudIdentityToken_sendsClientHeaders() async throws {
        await sut.setServerEnvironment(.cloudUS())
        CapturingURLProtocol.nextResponseData = Data(#"{"error":"device_error"}"#.utf8)
        CapturingURLProtocol.nextStatusCode   = 400

        do {
            _ = try await sut.identityToken(
                email: "t@t.com", passwordHash: "hash",
                deviceIdentifier: "dev-id",
                twoFactorToken: nil, twoFactorProvider: nil, twoFactorRemember: false,
                newDeviceOTP: nil
            )
        } catch { }

        let headers = CapturingURLProtocol.lastRequest?.allHTTPHeaderFields ?? [:]
        XCTAssertNotNil(headers["Bitwarden-Client-Name"],    "Bitwarden-Client-Name header required")
        XCTAssertNotNil(headers["Bitwarden-Client-Version"], "Bitwarden-Client-Version header required")
    }

    // MARK: - 6.7: cloud identityToken client_id = "desktop"

    func testCloudIdentityToken_clientId_isRegisteredIdentifier() async throws {
        await sut.setServerEnvironment(.cloudUS())
        CapturingURLProtocol.nextResponseData = Data(#"{"error":"device_error"}"#.utf8)
        CapturingURLProtocol.nextStatusCode   = 400

        do {
            _ = try await sut.identityToken(
                email: "t@t.com", passwordHash: "hash",
                deviceIdentifier: "dev-id",
                twoFactorToken: nil, twoFactorProvider: nil, twoFactorRemember: false,
                newDeviceOTP: nil
            )
        } catch { }

        let body   = formBody(from: CapturingURLProtocol.lastRequest)
        let actual = body["client_id"] ?? ""
        XCTAssertEqual(actual, "desktop",
                       "Cloud client_id must be 'desktop' for password grant")
    }

    // MARK: - 6.8: cloud refreshAccessToken client_id = "desktop"

    func testCloudRefreshToken_clientId_isRegisteredIdentifier() async throws {
        await sut.setServerEnvironment(.cloudUS())
        CapturingURLProtocol.nextResponseData = refreshTokenJSON()

        _ = try await sut.refreshAccessToken(refreshToken: "rt")

        let body   = formBody(from: CapturingURLProtocol.lastRequest)
        let actual = body["client_id"] ?? ""
        XCTAssertEqual(actual, "desktop")
    }

    // MARK: - 6.9: selfHosted identityToken client_id = "desktop"

    func testSelfHosted_identityToken_clientId_isDesktop() async throws {
        let base = URL(string: "https://vault.example.com")!
        await sut.setServerEnvironment(ServerEnvironment(base: base, overrides: nil))
        CapturingURLProtocol.nextResponseData = Data(#"{"error":"invalid_grant"}"#.utf8)
        CapturingURLProtocol.nextStatusCode   = 400

        do {
            _ = try await sut.identityToken(
                email: "t@t.com", passwordHash: "hash",
                deviceIdentifier: "dev-id",
                twoFactorToken: nil, twoFactorProvider: nil, twoFactorRemember: false,
                newDeviceOTP: nil
            )
        } catch { }

        let body   = formBody(from: CapturingURLProtocol.lastRequest)
        XCTAssertEqual(body["client_id"], "desktop")
    }

    // MARK: - 6.10: device_error → IdentityTokenError.newDeviceNotVerified

    func testIdentityToken_deviceError_throwsNewDeviceNotVerified() async throws {
        await sut.setServerEnvironment(.cloudUS())
        CapturingURLProtocol.nextStatusCode   = 400
        CapturingURLProtocol.nextResponseData = Data(#"{"error":"device_error","error_description":"No device"}"#.utf8)

        do {
            _ = try await sut.identityToken(
                email: "t@t.com", passwordHash: "hash",
                deviceIdentifier: "dev-id",
                twoFactorToken: nil, twoFactorProvider: nil, twoFactorRemember: false,
                newDeviceOTP: nil
            )
            XCTFail("Expected IdentityTokenError.newDeviceNotVerified")
        } catch IdentityTokenError.newDeviceNotVerified {
            // pass
        }
    }

    // MARK: - Helpers

    private func preLoginJSON() -> Data {
        Data(#"{"kdf":0,"kdfIterations":600000}"#.utf8)
    }

    private func refreshTokenJSON() -> Data {
        Data(#"{"access_token":"new-at","token_type":"Bearer","expires_in":3600}"#.utf8)
    }

    private func syncJSON() -> Data {
        let json = """
        {
          "Profile": {
            "Id": "pid",
            "Email": "t@t.com",
            "Key": "2.k==",
            "PrivateKey": null,
            "Organizations": []
          },
          "Ciphers": [],
          "Folders": []
        }
        """
        return Data(json.utf8)
    }

    /// Parses a `application/x-www-form-urlencoded` body into a key→value dict.
    private func formBody(from request: URLRequest?) -> [String: String] {
        guard let data = request?.httpBody,
              let str  = String(data: data, encoding: .utf8) else { return [:] }
        var result = [String: String]()
        for pair in str.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key   = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            result[key] = value
        }
        return result
    }
}
