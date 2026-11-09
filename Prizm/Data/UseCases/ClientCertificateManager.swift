import Foundation

@MainActor
final class ClientCertificateManager: ClientCertificateManaging {
    private let store: ClientCertificateStore
    private let configuration: ClientCertificateConfiguration
    private let api: PrizmAPIClientImpl
    private var pending: ClientCertificateStore.Preview?

    init(store: ClientCertificateStore, configuration: ClientCertificateConfiguration, api: PrizmAPIClientImpl) {
        self.store = store
        self.configuration = configuration
        self.api = api
    }

    func configuredCertificate(server: URL) throws -> ClientCertificateDetails? {
        try configuration.certificate(for: ServerOrigin(url: server))
    }

    func preview(file: URL, password: String) throws -> ClientCertificateDetails {
        pending = nil
        let access = file.startAccessingSecurityScopedResource()
        defer { if access { file.stopAccessingSecurityScopedResource() } }
        var data = try Data(contentsOf: file)
        defer { data.resetBytes(in: 0..<data.count) }
        let preview = try store.preview(data: data, password: password)
        pending = preview
        return preview.details
    }

    func cancelPreview() { pending = nil }

    func confirm(server: URL) async throws -> ClientCertificateDetails {
        let origin = try ServerOrigin(url: server)
        guard let pending else { throw ClientCertificateError.noPreview }
        let old = try configuration.certificate(for: origin)
        try store.save(pending)
        do { try configuration.set(pending.details, for: origin) }
        catch {
            try store.remove(id: pending.details.id)
            throw error
        }
        self.pending = nil
        // Invalidate before deleting the previous private key; no old TLS connection survives.
        await api.invalidateServerSession()
        if let old, try !configuration.isReferenced(old.id) { try store.remove(id: old.id) }
        return pending.details
    }

    func remove(server: URL) async throws {
        let origin = try ServerOrigin(url: server)
        let old = try configuration.certificate(for: origin)
        await api.invalidateServerSession()
        if let old, try !configuration.isReferenced(old.id, excluding: origin) {
            try store.remove(id: old.id)
        }
        try configuration.set(nil, for: origin)
    }
}
