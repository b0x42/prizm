import Foundation

/// Contains only public metadata and app-owned IDs. Unreadable data fails closed.
nonisolated final class ClientCertificateConfiguration: @unchecked Sendable {
    static let storageKey = "com.prizm.client-certificates.v1"
    private let defaults: UserDefaults
    private let lock = NSLock()
    private struct Assignment: Codable {
        let origin: ServerOrigin
        let certificate: ClientCertificateDetails
    }

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func certificate(for origin: ServerOrigin) throws -> ClientCertificateDetails? {
        try lock.withLock { try assignments().first { $0.origin == origin }?.certificate }
    }

    func set(_ certificate: ClientCertificateDetails?, for origin: ServerOrigin) throws {
        try lock.withLock {
            var entries = try assignments().filter { $0.origin != origin }
            if let certificate { entries.append(Assignment(origin: origin, certificate: certificate)) }
            defaults.set(try JSONEncoder().encode(entries), forKey: Self.storageKey)
        }
    }

    func isReferenced(_ id: UUID, excluding origin: ServerOrigin? = nil) throws -> Bool {
        try lock.withLock { try assignments().contains { $0.origin != origin && $0.certificate.id == id } }
    }

    private func assignments() throws -> [Assignment] {
        guard let object = defaults.object(forKey: Self.storageKey) else { return [] }
        guard let data = object as? Data else { throw ClientCertificateError.corruptConfiguration }
        do {
            let entries = try JSONDecoder().decode([Assignment].self, from: data)
            guard Set(entries.map(\.origin)).count == entries.count,
                  entries.allSatisfy({ !$0.origin.host.isEmpty && (1...65535).contains($0.origin.port) }) else {
                throw ClientCertificateError.corruptConfiguration
            }
            return entries
        } catch { throw ClientCertificateError.corruptConfiguration }
    }
}
