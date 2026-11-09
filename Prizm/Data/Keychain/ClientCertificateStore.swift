/// PKCS#12 (RFC 7292) import via Security.framework; SHA-256 via CryptoKit.
/// Memory-only import prevents macOS's implicit login-Keychain side effects. Persisted
/// identities use the app-isolated data-protection Keychain; no CA trust is installed.
import Foundation
import Security
import CryptoKit

nonisolated struct ClientCertificateStore: Sendable {
    struct Preview {
        let details: ClientCertificateDetails
        let identity: SecIdentity
        let chain: [SecCertificate]
    }

    private struct Record: Codable {
        let keyReference: Data
        let certificateReference: Data
        let chain: [Data]
    }
    private static let service = "com.prizm.client-certificate"

    func preview(data: Data, password: String) throws -> Preview {
        var result: CFArray?
        let options: [String: Any] = [kSecImportExportPassphrase as String: password,
                                      kSecImportToMemoryOnly as String: true]
        guard SecPKCS12Import(data as CFData, options as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { throw ClientCertificateError.invalidImport }
        guard items.count == 1 else { throw ClientCertificateError.identityCount }
        guard let value = items[0][kSecImportItemIdentity as String], CFGetTypeID(value as CFTypeRef) == SecIdentityGetTypeID() else {
            throw ClientCertificateError.missingKey
        }
        let identity = value as! SecIdentity
        var key: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess, key != nil else {
            throw ClientCertificateError.missingKey
        }
        var leaf: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &leaf) == errSecSuccess, let leaf else {
            throw ClientCertificateError.invalidCertificate
        }
        let dates = try validate(leaf)
        let fingerprint = SHA256.hash(data: SecCertificateCopyData(leaf) as Data).map { String(format: "%02X", $0) }.joined(separator: ":")
        let values = try certificateValues(leaf)
        let issuer = values[kSecOIDX509V1IssuerName as String] as? [String: Any]
        let issuerName = strings(in: issuer?[kSecPropertyKeyValue as String]).joined(separator: ", ")
        let details = ClientCertificateDetails(id: UUID(), name: SecCertificateCopySubjectSummary(leaf) as String? ?? "Client certificate",
                                              issuer: issuerName, notBefore: dates.0, notAfter: dates.1, fingerprint: fingerprint)
        let importedChain = items[0][kSecImportItemCertChain as String] as? [SecCertificate] ?? [leaf]
        return Preview(details: details, identity: identity, chain: importedChain)
    }

    /// Add key and certificate separately so a partial/duplicate import can roll
    /// back ONLY the exact objects added by this attempt, never a pre-existing key.
    func save(_ preview: Preview) throws {
        var key: SecKey?
        var certificate: SecCertificate?
        guard SecIdentityCopyPrivateKey(preview.identity, &key) == errSecSuccess, let key,
              SecIdentityCopyCertificate(preview.identity, &certificate) == errSecSuccess, let certificate else {
            throw ClientCertificateError.missingKey
        }
        let keyRef = try add(value: key, itemClass: kSecClassKey, id: preview.details.id)
        var certificateRef: Data?
        do {
            let certRef = try add(value: certificate, itemClass: kSecClassCertificate, id: preview.details.id)
            certificateRef = certRef
            let record = Record(keyReference: keyRef, certificateReference: certRef,
                                chain: preview.chain.map { SecCertificateCopyData($0) as Data })
            var query = recordQuery(id: preview.details.id)
            query[kSecValueData as String] = try JSONEncoder().encode(record)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else { throw ClientCertificateError.keychain(status) }
        } catch {
            // Attempt both exact deletions even if one fails; surface cleanup failures.
            let certificateStatus = certificateRef.map { delete(reference: $0, itemClass: kSecClassCertificate) } ?? errSecSuccess
            let keyStatus = delete(reference: keyRef, itemClass: kSecClassKey)
            for status in [certificateStatus, keyStatus] where status != errSecSuccess && status != errSecItemNotFound {
                throw ClientCertificateError.keychain(status)
            }
            throw error
        }
    }

    private func add(value: CFTypeRef, itemClass: CFString, id: UUID) throws -> Data {
        var result: CFTypeRef?
        var query: [String: Any] = [kSecClass as String: itemClass, kSecValueRef as String: value,
                                   kSecAttrLabel as String: label(id),
                                   kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                   kSecAttrSynchronizable as String: false,
                                   kSecUseDataProtectionKeychain as String: true,
                                   kSecReturnPersistentRef as String: true]
        if itemClass == kSecClassKey { query[kSecAttrApplicationTag as String] = Data(id.uuidString.utf8) }
        let status = SecItemAdd(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw ClientCertificateError.keychain(status) }
        guard let reference = result as? Data else { throw ClientCertificateError.unavailable }
        return reference
    }

    private func label(_ id: UUID) -> String { "Prizm mTLS \(id.uuidString)" }

    func credential(id: UUID) throws -> URLCredential {
        guard let record = try loadRecord(id: id) else { throw ClientCertificateError.unavailable }
        var result: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassIdentity,
                                   kSecAttrLabel as String: label(id),
                                   kSecAttrApplicationTag as String: Data(id.uuidString.utf8),
                                   kSecMatchLimit as String: kSecMatchLimitOne,
                                   kSecUseDataProtectionKeychain as String: true,
                                   kSecReturnRef as String: true]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let result, CFGetTypeID(result) == SecIdentityGetTypeID() else { throw ClientCertificateError.unavailable }
        let identity = result as! SecIdentity
        var leaf: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &leaf) == errSecSuccess, let leaf else { throw ClientCertificateError.unavailable }
        _ = try validate(leaf)
        let chain = try record.chain.map { data -> SecCertificate in
            guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { throw ClientCertificateError.unavailable }
            return certificate
        }
        return URLCredential(identity: identity, certificates: chain, persistence: .forSession)
    }

    /// An app-scoped record is the ownership proof; deletion is by exact persistent ref.
    func remove(id: UUID) throws {
        // If the ownership record was already removed, there is nothing we can
        // safely delete. Still allow the user to unassign this missing identity.
        guard let record = try loadRecord(id: id, allowMissing: true) else { return }
        let certificateStatus = delete(reference: record.certificateReference, itemClass: kSecClassCertificate)
        let keyStatus = delete(reference: record.keyReference, itemClass: kSecClassKey)
        for status in [certificateStatus, keyStatus] where status != errSecSuccess && status != errSecItemNotFound {
            throw ClientCertificateError.keychain(status)
        }
        let recordStatus = SecItemDelete(recordQuery(id: id) as CFDictionary)
        guard recordStatus == errSecSuccess || recordStatus == errSecItemNotFound else { throw ClientCertificateError.keychain(recordStatus) }
    }

    private func delete(reference: Data, itemClass: CFString) -> OSStatus {
        SecItemDelete([kSecClass as String: itemClass, kSecValuePersistentRef as String: reference,
                       kSecUseDataProtectionKeychain as String: true] as CFDictionary)
    }

    private func recordQuery(id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service,
         kSecAttrAccount as String: id.uuidString, kSecUseDataProtectionKeychain as String: true,
         kSecAttrSynchronizable as String: false]
    }

    private func loadRecord(id: UUID, allowMissing: Bool = false) throws -> Record? {
        var query = recordQuery(id: id)
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound, allowMissing { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw ClientCertificateError.unavailable }
        do { return try JSONDecoder().decode(Record.self, from: data) }
        catch { throw ClientCertificateError.unavailable }
    }

    private func certificateValues(_ certificate: SecCertificate) throws -> [String: Any] {
        var error: Unmanaged<CFError>?
        guard let values = SecCertificateCopyValues(certificate, nil, &error) as? [String: Any] else {
            throw ClientCertificateError.invalidCertificate
        }
        return values
    }

    /// Security.framework parses X.509 values; KU digitalSignature and EKU clientAuth
    /// are required only when the corresponding restrictions are present (RFC 5280 §4.2.1).
    private func validate(_ certificate: SecCertificate) throws -> (Date, Date) {
        let values = try certificateValues(certificate)
        func value(_ oid: CFString) -> Any? { (values[oid as String] as? [String: Any])?[kSecPropertyKeyValue as String] }
        guard let start = value(kSecOIDX509V1ValidityNotBefore) as? NSNumber,
              let end = value(kSecOIDX509V1ValidityNotAfter) as? NSNumber else { throw ClientCertificateError.invalidCertificate }
        let notBefore = Date(timeIntervalSinceReferenceDate: start.doubleValue)
        let notAfter = Date(timeIntervalSinceReferenceDate: end.doubleValue)
        guard notBefore <= Date(), notAfter > Date() else { throw ClientCertificateError.invalidCertificate }
        if let usage = value(kSecOIDKeyUsage) {
            // CopyValues synthesizes 0 for an absent KU extension. Otherwise its
            // numeric representation uses bit 0 for digitalSignature (not the
            // legacy CSSM CE_KeyUsage representation). Criticality occupies bit 31.
            guard let bits = usage as? NSNumber,
                  bits.uint32Value == 0 || bits.uint32Value & 1 != 0 else { throw ClientCertificateError.invalidUsage }
        }
        if let usage = value(kSecOIDExtendedKeyUsage) {
            // CopyValues returns the DER content bytes of each OBJECT IDENTIFIER,
            // not its dotted display string. RFC 5280 §4.2.1.12 defines clientAuth.
            let clientAuth = Data([0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x02])
            let anyUsage = Data([0x55, 0x1d, 0x25, 0x00])
            guard let oids = usage as? [Data], oids.contains(clientAuth) || oids.contains(anyUsage) else {
                throw ClientCertificateError.invalidUsage
            }
        }
        return (notBefore, notAfter)
    }

    private func strings(in value: Any?) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [Any] { return array.flatMap { strings(in: $0) } }
        if let property = value as? [String: Any] { return strings(in: property[kSecPropertyKeyValue as String]) }
        return []
    }
}
