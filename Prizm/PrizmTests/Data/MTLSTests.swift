import XCTest
@testable import Prizm

final class MTLSTests: XCTestCase {
    func testOriginUsesEffectivePortAndExactHost() throws {
        let origin = try ServerOrigin(url: URL(string: "https://VAULT.example/path")!)
        XCTAssertEqual(origin, try ServerOrigin(url: URL(string: "https://vault.example:443/identity")!))
        XCTAssertFalse(origin.contains(URL(string: "https://vault.example:8443")!))
        XCTAssertFalse(origin.contains(URL(string: "https://other.vault.example")!))
        XCTAssertFalse(origin.contains(URL(string: "http://vault.example")!))
        XCTAssertThrowsError(try ServerOrigin(url: URL(string: "https://user:secret@vault.example")!))
    }

    func testIPv6AndInternationalizedOriginsNormalizeWithoutBroadening() throws {
        let ipv6 = try ServerOrigin(url: URL(string: "https://[::1]")!)
        XCTAssertEqual(ipv6.host, "::1")
        XCTAssertEqual(ipv6.displayName, "https://[::1]:443")
        XCTAssertFalse(ipv6.contains(URL(string: "https://[::1]:8443")!))
        XCTAssertEqual(try ServerOrigin(url: URL(string: "https://bücher.example")!),
                       try ServerOrigin(url: URL(string: "https://xn--bcher-kva.example:443")!))
    }

    func testExternalDelegateNeverSelectsClientIdentity() {
        let delegate = MTLSSessionDelegate(origin: nil, credential: nil)
        let space = URLProtectionSpace(host: "vault.example", port: 443, protocol: "https", realm: nil,
                                       authenticationMethod: NSURLAuthenticationMethodClientCertificate)
        XCTAssertFalse(delegate.permitsClientCertificate(space: space, previousFailures: 0))
    }

    func testCrossOriginRedirectIsRejected() throws {
        let origin = try ServerOrigin(url: URL(string: "https://vault.example")!)
        let delegate = MTLSSessionDelegate(origin: origin, credential: nil)
        XCTAssertTrue(delegate.permitsRedirect(from: URL(string: "https://vault.example/api")!, to: URL(string: "https://vault.example:443/identity")!))
        XCTAssertFalse(delegate.permitsRedirect(from: URL(string: "https://vault.example/api")!, to: URL(string: "https://vault.example:8443/api")!))
        XCTAssertFalse(delegate.permitsRedirect(from: URL(string: "https://vault.example/api")!, to: URL(string: "https://other.example/api")!))
    }

    func testMalformedImportDoesNotCreateManagedRecord() throws {
        let store = ClientCertificateStore()
        XCTAssertThrowsError(try store.preview(data: Data("not PKCS12".utf8), password: "test-only"))
    }

    func testRemoveMissingManagedRecordDoesNotBlockUnassigning() throws {
        XCTAssertNoThrow(try ClientCertificateStore().remove(id: UUID()))
    }

    func testReferenceCountingPreservesOtherOriginAssignments() throws {
        let name = "Prizm.mTLS.references.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let configuration = ClientCertificateConfiguration(defaults: defaults)
        let first = try ServerOrigin(url: URL(string: "https://first.example")!)
        let second = try ServerOrigin(url: URL(string: "https://second.example")!)
        let details = ClientCertificateDetails(id: UUID(), name: "Test", issuer: "Test", notBefore: .distantPast,
                                               notAfter: .distantFuture, fingerprint: "test-only")
        try configuration.set(details, for: first)
        XCTAssertTrue(try configuration.isReferenced(details.id))
        XCTAssertFalse(try configuration.isReferenced(details.id, excluding: first))
        try configuration.set(details, for: second)
        XCTAssertTrue(try configuration.isReferenced(details.id, excluding: first))
        try configuration.set(nil, for: first)
        XCTAssertEqual(try configuration.certificate(for: second), details)
    }

    @MainActor
    func testConfigurationPersistsAndCorruptionFailsClosed() throws {
        let name = "Prizm.mTLS.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let config = ClientCertificateConfiguration(defaults: defaults)
        let origin = try ServerOrigin(url: URL(string: "https://vault.example")!)
        let details = ClientCertificateDetails(id: UUID(), name: "Test", issuer: "Test CA", notBefore: .distantPast,
                                               notAfter: .distantFuture, fingerprint: "test-only")
        try config.set(details, for: origin)
        XCTAssertEqual(try ClientCertificateConfiguration(defaults: defaults).certificate(for: origin), details)
        defaults.set(Data("corrupt".utf8), forKey: ClientCertificateConfiguration.storageKey)
        XCTAssertThrowsError(try config.certificate(for: origin))
    }
}
