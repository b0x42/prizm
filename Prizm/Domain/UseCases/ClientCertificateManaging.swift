import Foundation

/// Preview never persists the file/password. Confirmation assigns one origin explicitly.
@MainActor
protocol ClientCertificateManaging: AnyObject {
    func configuredCertificate(server: URL) throws -> ClientCertificateDetails?
    func preview(file: URL, password: String) throws -> ClientCertificateDetails
    func confirm(server: URL) async throws -> ClientCertificateDetails
    func cancelPreview()
    func remove(server: URL) async throws
}
