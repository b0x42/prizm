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
///   Decryption is eager (at sync time, inside the mapper) rather than lazy (at display
///   time, inside Views). This keeps `VaultItem` domain entities as plain decrypted
///   Swift structs, so the Presentation layer never imports or calls crypto code.
///   Decryption failures are surfaced once during sync rather than scattered across the UI.
/// - Map the raw `type` integer to a typed `ItemContent` enum case.
/// - Filter out organisation ciphers (`organizationId != nil`) — personal vault only.
/// - Map raw `RawField` array to `[CustomField]` domain values.
///
/// **What this class does NOT do**:
/// - Network I/O.
/// - Keychain access.
/// - KDF derivation.
nonisolated final class CipherMapper {

    private let attachmentMapper = AttachmentMapper()

    private static let logger = Logger(subsystem: "com.prizm", category: "CipherMapper")

    private nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Public API

    /// Maps a single `RawCipher` to a `VaultItem` and returns the effective cipher key.
    ///
    /// The returned tuple is used by:
    /// - **Callers that only need the item** (`SyncRepositoryImpl`, `VaultRepositoryImpl.update`,
    ///   `VaultRepositoryImpl.create`): destructure and discard the `cipherKey` value.
    /// - **`SyncRepositoryImpl`**: collect all `cipherKey` values and populate `VaultKeyCache`.
    ///
    /// **Effective cipher key derivation** (Bitwarden Security Whitepaper §4):
    /// - If `raw.key` is non-nil (cipher has a per-item symmetric key), decrypt it with the
    ///   vault key and return the 64-byte plaintext as the effective key.
    /// - If `raw.key` is nil, the cipher uses the vault-level key directly — return
    ///   `keys.encryptionKey + keys.macKey` (64 bytes).
    ///
    /// - Parameters:
    ///   - raw:  The encrypted wire-format cipher from the sync response.
    ///   - keys: The vault-level symmetric key pair used to decrypt EncString fields.
    /// - Returns: A tuple of the decrypted `VaultItem` and its 64-byte effective cipher key.
    /// - Throws: `CipherMapperError.organisationCipherSkipped` for org ciphers.
    /// - Throws: `CipherMapperError.unsupportedCipherType` for unknown type integers.
    /// - Throws: `EncStringError` or `CipherMapperError.fieldDecryptionFailed` on decryption failure.
    func map(raw: RawCipher, keys: CryptoKeys) throws -> (item: VaultItem, cipherKey: Data) {
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

        // Effective cipher key: per-item key if present, otherwise vault-level key.
        // Reference: Bitwarden Security Whitepaper §4 — "Cipher Key Wrapping".
        // Must be resolved BEFORE attachment mapping so that attachment filenames are
        // decrypted with the correct key — ciphers that have a per-item key use it for
        // their attachments too (vault-level key would cause MAC verification failures).
        let cipherKey: Data
        if let encItemKey = raw.key {
            // Per-item key: decrypt the EncString-wrapped key using the vault key.
            do {
                let enc = try EncString(string: encItemKey)
                cipherKey = try enc.decrypt(keys: keys)
            } catch {
                Self.logger.fault("Per-item key decryption failed for cipher \(raw.id, privacy: .public)")
                throw CipherMapperError.fieldDecryptionFailed("key")
            }
        } else {
            // No per-item key — use the vault-level key directly.
            cipherKey = keys.encryptionKey + keys.macKey
        }

        // Build CryptoKeys from the resolved 64-byte cipher key (first 32 bytes = enc, last 32 = mac).
        let effectiveKeys = CryptoKeys(
            encryptionKey: cipherKey.prefix(32),
            macKey:        cipherKey.suffix(32)
        )

        // Map attachments using the cipher's effective key, not the raw vault key.
        // Attachment filenames are encrypted under the same key as the cipher's fields.
        let attachments: [Attachment] = (raw.attachments ?? []).compactMap { dto in
            do {
                return try attachmentMapper.map(dto, cipherKey: effectiveKeys)
            } catch {
                Self.logger.error("Attachment mapping failed for cipher \(raw.id, privacy: .public): \(error, privacy: .public)")
                return nil
            }
        }

        let item = VaultItem(
            id:           raw.id,
            name:         name,
            isFavorite:   raw.favorite,
            isDeleted:    raw.deletedDate != nil,
            creationDate: creationDate,
            revisionDate: revisionDate,
            content:      content,
            reprompt:     raw.reprompt ?? 0,
            attachments:  attachments
        )
        return (item: item, cipherKey: cipherKey)
    }

    // MARK: - Private: Content dispatch

    private func mapContent(
        type:   Int,
        raw:    RawCipher,
        notes:  String?,
        fields: [CustomField],
        keys:   CryptoKeys
    ) throws -> ItemContent {
        // Type integers match the Bitwarden server CipherType enum:
        // 1=Login, 2=SecureNote, 3=Card, 4=Identity, 5=SSHKey.
        // Reference: github.com/bitwarden/server CipherType.cs; vaultwarden CipherType enum.
        switch type {
        case 1: return try mapLogin(raw.login,       notes: notes, fields: fields, keys: keys)
        case 2: return mapSecureNote(                notes: notes, fields: fields)
        case 3: return try mapCard(raw.card,         notes: notes, fields: fields, keys: keys)
        case 4: return try mapIdentity(raw.identity, notes: notes, fields: fields, keys: keys)
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
        let ssh = data ?? RawSSHKeyData(privateKey: nil, publicKey: nil, keyFingerprint: nil)
        return .sshKey(SSHKeyContent(
            privateKey:     try ssh.privateKey.map  { try decryptRequired($0, field: "privateKey",  keys: keys) },
            publicKey:      try ssh.publicKey.map   { try decryptRequired($0, field: "publicKey",   keys: keys) },
            keyFingerprint: try ssh.keyFingerprint.map { try decryptRequired($0, field: "keyFingerprint", keys: keys) },
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

    // MARK: - Reverse mapper (domain → wire)

    /// Converts a mutable `DraftVaultItem` into an encrypted `RawCipher` ready for
    /// `PUT /ciphers/{id}`.
    ///
    /// - Security goal: ensures that no vault secret (password, card number, private key, etc.)
    ///   ever leaves the device in plaintext. Every string field that is an EncString on the
    ///   Bitwarden wire format is re-encrypted here before the request body is serialised.
    ///
    /// - Algorithm: EncString type-2 — AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC).
    ///   Spec reference: Bitwarden Security Whitepaper §4 (https://bitwarden.com/images/resources/security-white-paper-download.pdf).
    ///   Standard reference: AES-CBC per NIST SP 800-38A; HMAC-SHA256 per RFC 2104.
    ///   Each field gets a cryptographically random 16-byte IV via `SecRandomCopyBytes`
    ///   (Security.framework). Reusing IVs across fields would break CBC confidentiality;
    ///   the fresh-IV-per-field approach matches the Bitwarden client reference implementation.
    ///
    /// - Deviations from the Bitwarden reference: none. The EncString type-2 format and
    ///   key material (AES key + MAC key from `CryptoKeys`) are identical to what the
    ///   official web vault uses when editing an item.
    ///
    /// - What is NOT done:
    ///   • `id`, `type`, `favorite` are plain JSON values (not EncStrings) — sent as-is.
    ///   • `organizationId` is sent as `nil` — this mapper only handles personal vault items;
    ///     editing org ciphers is out of scope for v1 and requires org key unwrapping.
    ///   • `deletedDate`, `creationDate`, `revisionDate` are sent as `nil` — the server is
    ///     authoritative for these timestamps and ignores client-provided values on PUT.
    ///   • Biometric re-authentication before re-encryption is not performed here; it is
    ///     the caller's responsibility (see `VaultRepositoryImpl.update` TODO).
    ///
    /// - Parameter draft: The edited item to re-encrypt.
    /// - Parameter keys:  The symmetric key pair (AES-256 enc key + HMAC-SHA256 MAC key).
    /// - Returns: A `RawCipher` with all sensitive string fields encrypted as EncStrings.
    /// - Throws: `EncStringError` if IV generation or AES/HMAC computation fails.
    func toRawCipher(_ draft: DraftVaultItem, encryptedWith keys: CryptoKeys) throws -> RawCipher {
        let encName  = try encryptString(draft.name, keys: keys)
        let encNotes: String? = try {
            switch draft.content {
            case .login(let c):      return try c.notes.map { try encryptString($0, keys: keys) }
            case .secureNote(let c): return try c.notes.map { try encryptString($0, keys: keys) }
            case .card(let c):       return try c.notes.map { try encryptString($0, keys: keys) }
            case .identity(let c):   return try c.notes.map { try encryptString($0, keys: keys) }
            case .sshKey(let c):     return try c.notes.map { try encryptString($0, keys: keys) }
            }
        }()
        let encFields = try toRawFields(customFieldsOf(draft.content), keys: keys)

        let (type, loginData, cardData, identityData, secureNoteData, sshKeyData) =
            try encryptContent(draft.content, keys: keys)

        return RawCipher(
            id:             draft.id,
            organizationId: nil,
            type:           type,
            name:           encName,
            notes:          encNotes,
            favorite:       draft.isFavorite,
            reprompt:       draft.reprompt,
            deletedDate:    nil,
            creationDate:   nil,
            revisionDate:   nil,
            login:          loginData,
            card:           cardData,
            identity:       identityData,
            secureNote:     secureNoteData,
            sshKey:         sshKeyData,
            fields:         encFields.isEmpty ? nil : encFields,
            key:            nil,
            attachments:    nil
        )
    }

    // MARK: - Private: Reverse content dispatch

    private func encryptContent(
        _ content: DraftItemContent,
        keys: CryptoKeys
    ) throws -> (
        type: Int,
        login: RawLoginData?,
        card: RawCardData?,
        identity: RawIdentityData?,
        secureNote: RawSecureNoteData?,
        sshKey: RawSSHKeyData?
    ) {
        // Type integers: 1=Login, 2=SecureNote, 3=Card, 4=Identity, 5=SSHKey.
        // Must match the forward mapper (mapContent) and the Bitwarden server CipherType enum.
        switch content {
        case .login(let c):
            return (1, try toRawLogin(c, keys: keys), nil, nil, nil, nil)
        case .secureNote:
            return (2, nil, nil, nil, RawSecureNoteData(type: 0), nil)
        case .card(let c):
            return (3, nil, try toRawCard(c, keys: keys), nil, nil, nil)
        case .identity(let c):
            return (4, nil, nil, try toRawIdentity(c, keys: keys), nil, nil)
        case .sshKey(let c):
            return (5, nil, nil, nil, nil, try toRawSSHKey(c, keys: keys))
        }
    }

    // MARK: - Private: Login reverse map

    private func toRawLogin(_ c: DraftLoginContent, keys: CryptoKeys) throws -> RawLoginData {
        let rawURIs: [RawURI] = try c.uris.map { uri in
            let encURI = try encryptString(uri.uri, keys: keys)
            return RawURI(uri: encURI, match: uri.matchType?.rawValue)
        }
        return RawLoginData(
            username: try c.username.map { try encryptString($0, keys: keys) },
            password: try c.password.map { try encryptString($0, keys: keys) },
            uris:     rawURIs,
            totp:     try c.totp.map { try encryptString($0, keys: keys) }
        )
    }

    // MARK: - Private: Card reverse map

    private func toRawCard(_ c: DraftCardContent, keys: CryptoKeys) throws -> RawCardData {
        RawCardData(
            cardholderName: try c.cardholderName.map { try encryptString($0, keys: keys) },
            brand:          try c.brand.map          { try encryptString($0, keys: keys) },
            number:         try c.number.map         { try encryptString($0, keys: keys) },
            expMonth:       try c.expMonth.map       { try encryptString($0, keys: keys) },
            expYear:        try c.expYear.map        { try encryptString($0, keys: keys) },
            code:           try c.code.map           { try encryptString($0, keys: keys) }
        )
    }

    // MARK: - Private: Identity reverse map

    private func toRawIdentity(_ c: DraftIdentityContent, keys: CryptoKeys) throws -> RawIdentityData {
        func enc(_ s: String?) throws -> String? { try s.map { try encryptString($0, keys: keys) } }
        return RawIdentityData(
            title:          try enc(c.title),
            firstName:      try enc(c.firstName),
            middleName:     try enc(c.middleName),
            lastName:       try enc(c.lastName),
            address1:       try enc(c.address1),
            address2:       try enc(c.address2),
            address3:       try enc(c.address3),
            city:           try enc(c.city),
            state:          try enc(c.state),
            postalCode:     try enc(c.postalCode),
            country:        try enc(c.country),
            company:        try enc(c.company),
            email:          try enc(c.email),
            phone:          try enc(c.phone),
            ssn:            try enc(c.ssn),
            username:       try enc(c.username),
            passportNumber: try enc(c.passportNumber),
            licenseNumber:  try enc(c.licenseNumber)
        )
    }

    // MARK: - Private: SSH Key reverse map

    private func toRawSSHKey(_ c: DraftSSHKeyContent, keys: CryptoKeys) throws -> RawSSHKeyData {
        // keyFingerprint is auto-derived and not sent to the API — it is server-authoritative.
        RawSSHKeyData(
            privateKey:     try c.privateKey.map  { try encryptString($0, keys: keys) },
            publicKey:      try c.publicKey.map   { try encryptString($0, keys: keys) },
            keyFingerprint: nil
        )
    }

    // MARK: - Private: Custom fields reverse map

    private func toRawFields(_ fields: [DraftCustomField], keys: CryptoKeys) throws -> [RawField] {
        try fields.map { f in
            RawField(
                type:     f.type.rawValue,
                name:     try encryptString(f.name, keys: keys),
                value:    try f.value.map { try encryptString($0, keys: keys) },
                linkedId: f.linkedId?.rawValue
            )
        }
    }

    // MARK: - Private: Custom field extractor

    private func customFieldsOf(_ content: DraftItemContent) -> [DraftCustomField] {
        switch content {
        case .login(let c):      return c.customFields
        case .secureNote(let c): return c.customFields
        case .card(let c):       return c.customFields
        case .identity(let c):   return c.customFields
        case .sshKey(let c):     return c.customFields
        }
    }

    // MARK: - Encrypt helper

    /// Encrypts a plaintext string as a Type-2 EncString and returns its wire representation.
    private func encryptString(_ plaintext: String, keys: CryptoKeys) throws -> String {
        guard let data = plaintext.data(using: .utf8) else {
            throw CipherMapperError.fieldDecryptionFailed("utf8-encode")
        }
        return try EncString.encrypt(data: data, keys: keys).toString()
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
