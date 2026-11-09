import Foundation

/// RFC 6454 origin. Paths never grant additional hosts, schemes or ports.
nonisolated struct ServerOrigin: Codable, Hashable, Sendable {
    let host: String
    let port: Int

    init(url: URL) throws {
        guard url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, (1...65535).contains(url.port ?? 443) else {
            throw ClientCertificateError.invalidOrigin
        }
        self.host = host.lowercased()
        self.port = url.port ?? 443
    }

    var displayName: String { "https://\(host.contains(":") ? "[\(host)]" : host):\(port)" }
    func contains(_ url: URL) -> Bool { (try? ServerOrigin(url: url)) == self }
}

nonisolated struct ClientCertificateDetails: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let issuer: String
    let notBefore: Date
    let notAfter: Date
    let fingerprint: String
}

nonisolated enum ClientCertificateError: LocalizedError {
    case invalidOrigin, invalidImport, identityCount, missingKey, invalidCertificate, invalidUsage
    case unavailable, corruptConfiguration, noPreview, keychain(Int32), attachmentsDeferred

    var errorDescription: String? {
        switch self {
        case .invalidOrigin: "Client certificates require an HTTPS server without embedded credentials."
        case .invalidImport: "Cannot open this PKCS#12 file. Check the import password and file format."
        case .identityCount: "The PKCS#12 file must contain exactly one identity."
        case .missingKey: "The client certificate has no usable private key."
        case .invalidCertificate: "The client certificate is expired, not yet valid, or invalid."
        case .invalidUsage: "The certificate does not permit TLS client authentication."
        case .unavailable: "The configured client identity is unavailable in the Keychain. Import it again before connecting."
        case .corruptConfiguration: "The client certificate configuration is unreadable. Restore it before connecting."
        case .noPreview: "Select and inspect a client certificate before confirming."
        case .keychain(-34018): "This build lacks the Keychain entitlement required for client identities. Use a signed Prizm build with its Keychain access group enabled."
        case .keychain(let status): "Client certificate Keychain operation failed (\(status))."
        case .attachmentsDeferred: "Attachments are unavailable for mTLS servers in this prototype."
        }
    }
}
