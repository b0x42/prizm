import Foundation
import os.log

// MARK: - CipherMapperError

/// Errors that can be thrown by `CipherMapper.map(raw:keys:)`.
nonisolated enum CipherMapperError: Error, Equatable {
    /// The cipher belongs to an organisation and is intentionally skipped in
    /// the personal vault view (organizationId != nil).
    case organisationCipherSkipped
    /// The cipher has an unknown `type` integer.
    case unsupportedCipherType(Int)
    /// A required encrypted field could not be decrypted.
    case fieldDecryptionFailed(String)
}

// MARK: - CipherMapper

/// Transforms a `RawCipher` (wire-format, encrypted) into a `VaultItem` (domain,
/// decrypted) using the provided symmetric `CryptoKeys`.
///
/// **Responsibilities** (single responsibility per §III of the project constitution):
/// - Decrypt each EncString field using AES-256-CBC + HMAC-SHA256 (EncString type-2).
/// - Map the raw `type` integer to a typed `ItemContent` enum case.
/// - Filter out organisation ciphers (`organizationId != nil`) — personal vault only.
/// - Map raw `RawField` array to `[CustomField]` domain values.
///
/// **What this class does NOT do**:
/// - Network I/O.
/// - Keychain access.
/// - KDF derivation.
nonisolated final class CipherMapper {

    private static let logger = Logger(subsystem: "com.macwarden", category: "CipherMapper")

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Public API

    /// Maps a single `RawCipher` to a `VaultItem`.
    ///
    /// - Parameters:
    ///   - raw:  The encrypted wire-format cipher from the sync response.
    ///   - keys: The symmetric key pair used to decrypt EncString fields.
    /// - Returns: A decrypted `VaultItem` ready for display in the vault browser.
    /// - Throws: `CipherMapperError.organisationCipherSkipped` for org ciphers.
    /// - Throws: `CipherMapperError.unsupportedCipherType` for unknown type integers.
    /// - Throws: `EncStringError` or `CipherMapperError.fieldDecryptionFailed` on decryption failure.
    func map(raw: RawCipher, keys: CryptoKeys) throws -> VaultItem {
        // Organisation ciphers are excluded from the personal vault view
        if raw.organizationId != nil {
            throw CipherMapperError.organisationCipherSkipped
        }

        let name   = try decryptRequired(raw.name, field: "name", keys: keys)
        let notes  = try raw.notes.map { try decryptRequired($0, field: "notes", keys: keys) }
        let fields = try mapFields(raw.fields ?? [], keys: keys)

        let content: ItemContent = try mapContent(
            type:   raw.type,
            raw:    raw,
            notes:  notes,
            fields: fields,
            keys:   keys
        )

        let fallbackDate = Date(timeIntervalSince1970: 0)
        let creationDate  = raw.creationDate.flatMap  { Self.iso8601.date(from: $0) } ?? fallbackDate
        let revisionDate  = raw.revisionDate.flatMap  { Self.iso8601.date(from: $0) } ?? fallbackDate

        return VaultItem(
            id:           raw.id,
            name:         name,
            isFavorite:   raw.favorite,
            isDeleted:    raw.deletedDate != nil,
            creationDate: creationDate,
            revisionDate: revisionDate,
            content:      content
        )
    }

    // MARK: - Private: Content dispatch

    private func mapContent(
        type:   Int,
        raw:    RawCipher,
        notes:  String?,
        fields: [CustomField],
        keys:   CryptoKeys
    ) throws -> ItemContent {
        switch type {
        case 1: return try mapLogin(raw.login,       notes: notes, fields: fields, keys: keys)
        case 2: return try mapIdentity(raw.identity, notes: notes, fields: fields, keys: keys)
        case 3: return mapSecureNote(                notes: notes, fields: fields)
        case 4: return try mapCard(raw.card,         notes: notes, fields: fields, keys: keys)
        case 5: return try mapSSHKey(raw.sshKey,     notes: notes, fields: fields, keys: keys)
        default:
            throw CipherMapperError.unsupportedCipherType(type)
        }
    }

    // MARK: - Login

    private func mapLogin(
        _ data: RawLoginData?,
        notes:  String?,
        fields: [CustomField],
        keys:   CryptoKeys
    ) throws -> ItemContent {
        let login = data ?? RawLoginData(username: nil, password: nil, uris: [], totp: nil)
        let uris: [LoginURI] = try (login.uris ?? []).compactMap { rawURI in
            guard let encUri = rawURI.uri else { return nil }
            let uriStr = try decryptRequired(encUri, field: "uri", keys: keys)
            let match  = rawURI.match.flatMap { URIMatchType(rawValue: $0) }
            return LoginURI(uri: uriStr, matchType: match)
        }
        return .login(LoginContent(
            username:     try login.username.map { try decryptRequired($0, field: "username", keys: keys) },
            password:     try login.password.map { try decryptRequired($0, field: "password", keys: keys) },
            uris:         uris,
            totp:         try login.totp.map { try decryptRequired($0, field: "totp", keys: keys) },
            notes:        notes,
            customFields: fields
        ))
    }

    // MARK: - Secure Note

    private func mapSecureNote(notes: String?, fields: [CustomField]) -> ItemContent {
        .secureNote(SecureNoteContent(notes: notes, customFields: fields))
    }

    // MARK: - Card

    private func mapCard(
        _ data: RawCardData?,
        notes:  String?,
        fields: [CustomField],
        keys:   CryptoKeys
    ) throws -> ItemContent {
        let card = data ?? RawCardData(cardholderName: nil, brand: nil, number: nil,
                                      expMonth: nil, expYear: nil, code: nil)
        return .card(CardContent(
            cardholderName: try card.cardholderName.map { try decryptRequired($0, field: "cardholderName", keys: keys) },
            brand:          try card.brand.map          { try decryptRequired($0, field: "brand",          keys: keys) },
            number:         try card.number.map         { try decryptRequired($0, field: "number",         keys: keys) },
            expMonth:       try card.expMonth.map       { try decryptRequired($0, field: "expMonth",       keys: keys) },
            expYear:        try card.expYear.map        { try decryptRequired($0, field: "expYear",        keys: keys) },
            code:           try card.code.map           { try decryptRequired($0, field: "code",           keys: keys) },
            notes:          notes,
            customFields:   fields
        ))
    }

    // MARK: - Identity

    private func mapIdentity(
        _ data: RawIdentityData?,
        notes:  String?,
        fields: [CustomField],
        keys:   CryptoKeys
    ) throws -> ItemContent {
        let id = data ?? RawIdentityData(
            title: nil, firstName: nil, middleName: nil, lastName: nil,
            address1: nil, address2: nil, address3: nil, city: nil, state: nil,
            postalCode: nil, country: nil, company: nil, email: nil, phone: nil,
            ssn: nil, username: nil, passportNumber: nil, licenseNumber: nil
        )
        func dec(_ s: String?, field: String) throws -> String? {
            try s.map { try decryptRequired($0, field: field, keys: keys) }
        }
        return .identity(IdentityContent(
            title:          try dec(id.title,           field: "title"),
            firstName:      try dec(id.firstName,       field: "firstName"),
            middleName:     try dec(id.middleName,      field: "middleName"),
            lastName:       try dec(id.lastName,        field: "lastName"),
            address1:       try dec(id.address1,        field: "address1"),
            address2:       try dec(id.address2,        field: "address2"),
            address3:       try dec(id.address3,        field: "address3"),
            city:           try dec(id.city,            field: "city"),
            state:          try dec(id.state,           field: "state"),
            postalCode:     try dec(id.postalCode,      field: "postalCode"),
            country:        try dec(id.country,         field: "country"),
            company:        try dec(id.company,         field: "company"),
            email:          try dec(id.email,           field: "email"),
            phone:          try dec(id.phone,           field: "phone"),
            ssn:            try dec(id.ssn,             field: "ssn"),
            username:       try dec(id.username,        field: "username"),
            passportNumber: try dec(id.passportNumber,  field: "passportNumber"),
            licenseNumber:  try dec(id.licenseNumber,   field: "licenseNumber"),
            notes:          notes,
            customFields:   fields
        ))
    }

    // MARK: - SSH Key

    private func mapSSHKey(
        _ data: RawSSHKeyData?,
        notes:  String?,
        fields: [CustomField],
        keys:   CryptoKeys
    ) throws -> ItemContent {
        let ssh = data ?? RawSSHKeyData(privateKey: nil, publicKey: nil, fingerprint: nil)
        return .sshKey(SSHKeyContent(
            privateKey:     try ssh.privateKey.map  { try decryptRequired($0, field: "privateKey",  keys: keys) },
            publicKey:      try ssh.publicKey.map   { try decryptRequired($0, field: "publicKey",   keys: keys) },
            keyFingerprint: try ssh.fingerprint.map { try decryptRequired($0, field: "fingerprint", keys: keys) },
            notes:          notes,
            customFields:   fields
        ))
    }

    // MARK: - Custom Fields

    private func mapFields(_ rawFields: [RawField], keys: CryptoKeys) throws -> [CustomField] {
        try rawFields.compactMap { raw in
            // name is required for CustomField; skip fields with no name
            guard let rawName = raw.name else { return nil }
            let name     = try decryptRequired(rawName, field: "field.name", keys: keys)
            let value    = try raw.value.map { try decryptRequired($0, field: "field.value", keys: keys) }
            let type     = CustomFieldType(rawValue: raw.type) ?? .text
            let linkedId = raw.linkedId.flatMap { LinkedFieldId(rawValue: $0) }
            return CustomField(name: name, value: value, type: type, linkedId: linkedId)
        }
    }

    // MARK: - Decrypt helpers

    /// Decrypts an EncString field that is expected to be present.
    private func decryptRequired(_ encStr: String, field: String, keys: CryptoKeys) throws -> String {
        do {
            let enc  = try EncString(string: encStr)
            let data = try enc.decrypt(keys: keys)
            guard let str = String(data: data, encoding: .utf8) else {
                throw CipherMapperError.fieldDecryptionFailed(field)
            }
            return str
        } catch let e as EncStringError {
            throw e
        } catch {
            Self.logger.error("Field decryption failed: \(field, privacy: .public)")
            throw CipherMapperError.fieldDecryptionFailed(field)
        }
    }
}
