import XCTest
@testable import Prizm

@MainActor
final class ClientCertificateViewModelTests: XCTestCase {
    func testPreviewConfirmAndServerChange() async throws {
        let manager = MockClientCertificateManager()
        let vm = LoginViewModel(loginUseCase: MockLoginUseCase(), clientCertificates: manager)
        vm.serverURL = "https://vault.example"
        vm.previewCertificate(file: URL(fileURLWithPath: "/tmp/test-only.p12"), password: "test-only")
        XCTAssertEqual(vm.certificatePreview, manager.details)
        XCTAssertNil(vm.configuredCertificate)
        let confirmed = await vm.confirmCertificate()
        XCTAssertTrue(confirmed)
        XCTAssertEqual(manager.confirmedServer?.host, "vault.example")
        XCTAssertEqual(vm.configuredCertificate, manager.details)
        XCTAssertNil(vm.certificatePreview)
        vm.serverURL = "https://other.example"
        XCTAssertNil(vm.configuredCertificate)
        XCTAssertTrue(manager.cancelled)
    }

    func testImportFailureSurfacesAndDoesNotReplaceAssignment() {
        let manager = MockClientCertificateManager()
        manager.confirmedServer = URL(string: "https://vault.example")!
        let vm = LoginViewModel(loginUseCase: MockLoginUseCase(), clientCertificates: manager)
        vm.serverURL = "https://vault.example"
        manager.rejectPreview = true
        vm.previewCertificate(file: URL(fileURLWithPath: "/tmp/test-only.p12"), password: "wrong")
        XCTAssertNil(vm.certificatePreview)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.configuredCertificate, manager.details)
    }

    func testEditingServerClearsStaleErrorsAndDoesNotValidatePartialOrigin() {
        let manager = MockClientCertificateManager()
        let vm = LoginViewModel(loginUseCase: MockLoginUseCase(), clientCertificates: manager)
        vm.serverURL = "https://"
        XCTAssertNil(vm.errorMessage, "Incomplete typing must not produce a certificate error")
        vm.errorMessage = ClientCertificateError.invalidOrigin.localizedDescription
        vm.serverURL = "https://vault.example"
        XCTAssertNil(vm.errorMessage, "Editing the server must clear an error from the previous value")
    }

    func testRemoveClearsOnlyCurrentAssignment() async {
        let manager = MockClientCertificateManager()
        manager.confirmedServer = URL(string: "https://vault.example")!
        let vm = LoginViewModel(loginUseCase: MockLoginUseCase(), clientCertificates: manager)
        vm.serverURL = "https://vault.example"
        await vm.removeCertificate()
        XCTAssertNil(vm.configuredCertificate)
        XCTAssertNil(manager.confirmedServer)
    }
}

@MainActor
private final class MockClientCertificateManager: ClientCertificateManaging {
    let details = ClientCertificateDetails(id: UUID(), name: "Test", issuer: "Test CA", notBefore: .distantPast,
                                           notAfter: .distantFuture, fingerprint: "test-only")
    var confirmedServer: URL?
    var cancelled = false
    var rejectPreview = false
    func configuredCertificate(server: URL) throws -> ClientCertificateDetails? {
        _ = try ServerOrigin(url: server)
        return server == confirmedServer ? details : nil
    }
    func preview(file: URL, password: String) throws -> ClientCertificateDetails {
        if rejectPreview { throw ClientCertificateError.invalidImport }
        return details
    }
    func confirm(server: URL) async throws -> ClientCertificateDetails {
        confirmedServer = server
        return details
    }
    func cancelPreview() { cancelled = true }
    func remove(server: URL) async throws { if server == confirmedServer { confirmedServer = nil } }
}
