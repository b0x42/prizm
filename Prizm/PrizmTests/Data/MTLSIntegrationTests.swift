import XCTest
import Security
@testable import Prizm

/// Real TLS, ephemeral CA, no system trust changes and no committed private keys.
@MainActor
final class MTLSIntegrationTests: XCTestCase {
    private var process: Process!
    private var directory: URL!
    private var manifest: [String: Int] = [:]
    private var usesExternalFixture = false

    override func setUp() async throws {
        // Optional persistence tests should not generate unused keys or start a
        // TLS server in an unsigned CI run.
        if name.contains("testSignedKeychain"),
           ProcessInfo.processInfo.environment["PRIZM_MTLS_SIGNED_KEYCHAIN_TESTS"] != "1" {
            throw XCTSkip("Requires a signed sandbox host with Keychain test opt-in")
        }
        // The signed sandbox host must not launch a compiler/Python toolchain or
        // listen as a TLS server. An external runner can provide a disposable fixture.
        if let path = ProcessInfo.processInfo.environment["PRIZM_MTLS_FIXTURE_DIR"] {
            usesExternalFixture = true
            directory = URL(fileURLWithPath: path)
            manifest = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: directory.appendingPathComponent("ready.json")))
            return
        }
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Prizm-mTLS-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", root.appendingPathComponent("tests/mtls/fixture.py").path, directory.path]
        process.standardOutput = FileHandle.nullDevice
        let logURL = directory.appendingPathComponent("fixture.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        process.standardError = try FileHandle(forWritingTo: logURL)
        try process.run()
        let manifestURL = directory.appendingPathComponent("ready.json")
        for _ in 0..<1500 {
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                manifest = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: manifestURL))
                return
            }
            guard process.isRunning else {
                let message = try String(contentsOf: directory.appendingPathComponent("fixture.log"), encoding: .utf8)
                throw NSError(domain: "TLS fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw NSError(domain: "TLS fixture timed out", code: 1)
    }

    override func tearDown() async throws {
        if process?.isRunning == true { process.terminate(); process.waitUntilExit() }
        if let directory, !usesExternalFixture { try FileManager.default.removeItem(at: directory) }
    }

    private func file(_ name: String) -> URL { directory.appendingPathComponent(name) }
    private func url(_ name: String = "server", host: String = "localhost", path: String = "/") -> URL {
        URL(string: "https://\(host):\(manifest[name]!)\(path)")!
    }
    private func preview(_ name: String = "client") throws -> ClientCertificateStore.Preview {
        try ClientCertificateStore().preview(data: Data(contentsOf: file("\(name).p12")), password: "test-only")
    }
    private func anchoredSession(origin: ServerOrigin?, credential: URLCredential?, anchorName: String = "ca.der") throws -> URLSession {
        let anchor = SecCertificateCreateWithData(nil, try Data(contentsOf: file(anchorName)) as CFData)!
        let config = URLSessionConfiguration.ephemeral
        config.urlCredentialStorage = nil
        return URLSession(configuration: config, delegate: TestAnchorDelegate(origin: origin, credential: credential, anchor: anchor), delegateQueue: nil)
    }

    func testImportValidationAndChain() throws {
        let imported = try preview()
        XCTAssertEqual(imported.details.name, "Prizm test client")
        XCTAssertFalse(imported.details.issuer.isEmpty)
        XCTAssertEqual(imported.details.fingerprint.split(separator: ":").count, 32)
        XCTAssertGreaterThanOrEqual(imported.chain.count, 2)
        XCTAssertThrowsError(try ClientCertificateStore().preview(data: Data(contentsOf: file("client.p12")), password: "wrong"))
        for name in ["expired", "future", "serverOnly", "wrongUsage", "multiple", "noKey"] {
            XCTAssertThrowsError(try preview(name), "Must reject \(name)")
        }
        XCTAssertNoThrow(try preview("unrestricted"))
    }

    func testRealTLSAndIsolation() async throws {
        let imported = try preview()
        let credential = URLCredential(identity: imported.identity, certificates: imported.chain, persistence: .forSession)
        let origin = try ServerOrigin(url: url())
        let delegate = MTLSSessionDelegate(origin: origin, credential: credential)
        let space = URLProtectionSpace(host: origin.host, port: origin.port, protocol: "https", realm: nil,
                                       authenticationMethod: NSURLAuthenticationMethodClientCertificate)
        XCTAssertTrue(delegate.permitsClientCertificate(space: space, previousFailures: 0))
        XCTAssertFalse(delegate.permitsClientCertificate(space: space, previousFailures: 1))
        let session = try anchoredSession(origin: origin, credential: credential)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(from: url())
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "client authenticated")

        for destination in [url("other"), url(host: "127.0.0.1")] {
            do {
                _ = try await session.data(from: destination)
                XCTFail("Wrong port/host must fail")
            } catch {
                XCTAssertTrue(error is URLError, "Expected TLS rejection, received \(error)")
            }
        }
        // Use the rejecting server's own origin so the client identity is offered;
        // otherwise origin isolation would reject first and never test its CA policy.
        let rejecting = try anchoredSession(origin: ServerOrigin(url: url("reject")), credential: credential)
        defer { rejecting.invalidateAndCancel() }
        do { _ = try await rejecting.data(from: url("reject")); XCTFail("Server accepted an untrusted client CA") }
        catch { XCTAssertTrue(error is URLError) }
        let rejectionDelegate = try XCTUnwrap(rejecting.delegate as? TestAnchorDelegate)
        XCTAssertGreaterThan(rejectionDelegate.clientCredentialUses, 0, "The server must reject an actually offered identity")

        let external = try anchoredSession(origin: nil, credential: nil)
        defer { external.invalidateAndCancel() }
        do { _ = try await external.data(from: url()); XCTFail("External session supplied an identity") }
        catch { XCTAssertTrue(error is URLError, "Expected rejection of missing client identity") }

        let untrusted = ServerSessionFactory.makeExternalSession()
        defer { untrusted.invalidateAndCancel() }
        do { _ = try await untrusted.data(from: url()); XCTFail("Invalid server trust accepted") }
        catch let error as URLError {
            XCTAssertEqual(error.code, .serverCertificateUntrusted, "Must fail system server-trust validation")
        }

        var request = URLRequest(url: url(path: "/redirect"))
        request.setValue("Bearer test-only", forHTTPHeaderField: "Authorization")
        let (_, redirected) = try await session.data(for: request)
        XCTAssertEqual((redirected as? HTTPURLResponse)?.statusCode, 302)
        let events = try String(contentsOf: file("events.jsonl"), encoding: .utf8)
        XCTAssertFalse(events.contains("\"server\": \"other\""), "Redirect target received a request")
    }

    func testAPIAuthenticationRefreshAndSyncOverTLS() async throws {
        let imported = try preview()
        let credential = URLCredential(identity: imported.identity, certificates: imported.chain, persistence: .forSession)
        let session = try anchoredSession(origin: ServerOrigin(url: url()), credential: credential)
        defer { session.invalidateAndCancel() }
        let api = PrizmAPIClientImpl(session: session)
        try await api.setBaseURL(url())
        let prelogin = try await api.preLogin(email: "test@example.org")
        XCTAssertEqual(prelogin.kdfIterations, 600000)
        let token = try await api.identityToken(email: "test@example.org", passwordHash: "test-only", deviceIdentifier: "test-only",
                                                twoFactorToken: nil, twoFactorProvider: nil, twoFactorRemember: false)
        await api.setAccessToken(token.accessToken)
        let refreshed = try await api.refreshAccessToken(refreshToken: "test-only")
        XCTAssertEqual(refreshed.accessToken, "test-only-access")
        let sync = try await api.fetchSync()
        XCTAssertEqual(sync.profile.id, "test-only-user")
        XCTAssertTrue(sync.ciphers.isEmpty)
        let events = try String(contentsOf: file("events.jsonl"), encoding: .utf8)
        XCTAssertTrue(events.contains("/api/accounts/prelogin"))
        XCTAssertTrue(events.contains("/identity/connect/token"))
        XCTAssertTrue(events.contains("/api/sync"))
        XCTAssertFalse(events.contains("\"client\": false"))
    }

    /// Requires the signed app's real access-group entitlement. Explicitly gated so an
    /// unsigned test run never turns an entitlement failure into a false passing result.
    func testSignedKeychainRestartAndRemoval() async throws {
        guard ProcessInfo.processInfo.environment["PRIZM_MTLS_SIGNED_KEYCHAIN_TESTS"] == "1" else {
            throw XCTSkip("Run with a signed sandbox host and PRIZM_MTLS_SIGNED_KEYCHAIN_TESTS=1 to validate app-isolated persistence")
        }
        let imported = try preview()
        let store = ClientCertificateStore()
        try store.save(imported)
        do {
            XCTAssertNoThrow(try ClientCertificateStore().credential(id: imported.details.id))
            XCTAssertThrowsError(try store.save(imported), "Duplicate import must not claim existing objects")
            let duplicate = try preview()
            XCTAssertNotEqual(duplicate.details.id, imported.details.id)
            XCTAssertThrowsError(try store.save(duplicate), "A new import UUID must still reject the existing leaf certificate")
            var result: CFTypeRef?
            let orphanQuery: [String: Any] = [kSecClass as String: kSecClassKey,
                                             kSecAttrApplicationTag as String: Data(duplicate.details.id.uuidString.utf8),
                                             kSecUseDataProtectionKeychain as String: true,
                                             kSecReturnAttributes as String: true]
            XCTAssertEqual(SecItemCopyMatching(orphanQuery as CFDictionary, &result), errSecItemNotFound,
                           "Certificate collision must roll back the newly inserted private key")
            XCTAssertNoThrow(try store.credential(id: imported.details.id), "Duplicate rollback must preserve original identity")
        }
        do {
            let savedCredential = try ClientCertificateStore().credential(id: imported.details.id)
            let session = try anchoredSession(origin: ServerOrigin(url: url()), credential: savedCredential)
            defer { session.invalidateAndCancel() }
            let (_, response) = try await session.data(from: url())
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200, "Persisted private key must complete mTLS")
        } catch {
            try store.remove(id: imported.details.id)
            throw error
        }
        try store.remove(id: imported.details.id)
        XCTAssertThrowsError(try store.credential(id: imported.details.id))
    }

    /// Invoke twice with distinct XCTest host processes: import, then restore. Only
    /// public metadata is passed between runs; the private key remains in Keychain.
    func testSignedKeychainSurvivesProcessRestart() async throws {
        guard ProcessInfo.processInfo.environment["PRIZM_MTLS_SIGNED_KEYCHAIN_TESTS"] == "1",
              let phase = ProcessInfo.processInfo.environment["PRIZM_MTLS_RESTART_PHASE"] else {
            throw XCTSkip("Requires signed import/restore runs in separate host processes")
        }
        let defaults = UserDefaults(suiteName: "com.prizm.mtls-restart-test")!
        let key = "test-certificate-details"
        let store = ClientCertificateStore()
        if phase == "import" {
            guard defaults.data(forKey: key) == nil else { throw NSError(domain: "Clean previous restart fixture before importing", code: 1) }
            let imported = try preview()
            try store.save(imported)
            do { defaults.set(try JSONEncoder().encode(imported.details), forKey: key) }
            catch { try store.remove(id: imported.details.id); throw error }
            // This test deliberately leaves its managed test identity for the next process.
        } else if phase == "restore" {
            let data = try XCTUnwrap(defaults.data(forKey: key))
            let details = try JSONDecoder().decode(ClientCertificateDetails.self, from: data)
            do {
                let credential = try store.credential(id: details.id)
                let session = try anchoredSession(origin: ServerOrigin(url: url()), credential: credential)
                defer { session.invalidateAndCancel() }
                let (_, response) = try await session.data(from: url())
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            } catch {
                try store.remove(id: details.id)
                defaults.removeObject(forKey: key)
                throw error
            }
            try store.remove(id: details.id)
            defaults.removeObject(forKey: key)
            XCTAssertThrowsError(try store.credential(id: details.id))
        } else { XCTFail("Unknown restart phase") }
    }
}

/// Only this test wrapper trusts the ephemeral CA, only for its own SecTrust object.
/// Production server-trust handling is forwarded untouched and tested separately.
nonisolated private final class TestAnchorDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    let transport: MTLSSessionDelegate
    let anchor: SecCertificate
    private let lock = NSLock()
    private var credentialUses = 0
    var clientCredentialUses: Int { lock.withLock { credentialUses } }
    init(origin: ServerOrigin?, credential: URLCredential?, anchor: SecCertificate) {
        self.transport = MTLSSessionDelegate(origin: origin, credential: credential)
        self.anchor = anchor
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            SecTrustSetAnchorCertificates(trust, [anchor] as CFArray)
            SecTrustSetAnchorCertificatesOnly(trust, true)
            var error: CFError?
            if SecTrustEvaluateWithError(trust, &error) { completionHandler(.useCredential, URLCredential(trust: trust)) }
            else { completionHandler(.cancelAuthenticationChallenge, nil) }
        } else {
            transport.urlSession(session, didReceive: challenge) { disposition, credential in
                if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate,
                   disposition == .useCredential {
                    self.lock.withLock { self.credentialUses += 1 }
                }
                completionHandler(disposition, credential)
            }
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        transport.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler)
    }
}
