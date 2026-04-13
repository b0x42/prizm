import Foundation

// MARK: - RawCipher

/// Wire-format model for a single cipher (vault item) returned by the Bitwarden
/// `/sync` API endpoint.
///
/// All string fields that contain sensitive data are stored as Bitwarden EncStrings
/// (e.g. `"2.<iv_b64>|<ct_b64>|<mac_b64>"`).  Plain-text fields (ids, dates, type
/// integers) are never encrypted.
///
/// Reference: Bitwarden Server API `/api/sync` response body, `Ciphers[]` array.
nonisolated struct RawCipher: Codable {
    let id:             String
    let organizationId: String?
    let folderId:       String?
    /// 1 = Login, 2 = SecureNote, 3 = Card, 4 = Identity, 5 = SSH Key
    /// Reference: Bitwarden server `CipherType` enum (C#), Vaultwarden `CipherType` (Rust),
    /// and Bitwarden web client `CipherType` enum (TypeScript). All three sources agree.
    let type:           Int
    let name:           String          // EncString
    let notes:          String?         // EncString
    let favorite:       Bool
    /// Master-password re-prompt setting. 0 = disabled, 1 = require master password.
    /// Must be round-tripped unchanged on PUT — omitting it silently resets re-prompt
    /// protection for items that have it enabled.
    /// Reference: Bitwarden server `CipherRepromptType` enum (0 = None, 1 = Password).
    let reprompt:       Int?
    let deletedDate:    String?         // ISO-8601 UTC, nil if not deleted
    let creationDate:   String?         // ISO-8601 UTC
    let revisionDate:   String?         // ISO-8601 UTC
    let login:          RawLoginData?
    let card:           RawCardData?
    let identity:       RawIdentityData?
    let secureNote:     RawSecureNoteData?
    let sshKey:         RawSSHKeyData?
    let fields:         [RawField]?
    /// Per-cipher symmetric key wrapped as an EncString. When present, this key encrypts
    /// the cipher's fields instead of the vault-level key. When nil, the vault-level key
    /// is used directly (Bitwarden Security Whitepaper §4 — "Cipher Key Wrapping").
    let key:            String?         // EncString, optional
    /// Collections this cipher is assigned to within its organization.
    /// Defaults to `[]` when absent (personal items, or servers that omit the key).
    let collectionIds:  [String]
    /// File attachments belonging to this cipher. Nil when the server returns no
    /// attachments or omits the field entirely; treated as `[]` by `CipherMapper`.
    let attachments:    [AttachmentDTO]?

    /// Memberwise init with `collectionIds` defaulted to `[]` so existing call sites
    /// that pre-date this field continue to compile without changes.
    init(id: String, organizationId: String?, folderId: String?, type: Int, name: String,
         notes: String?, favorite: Bool, reprompt: Int?, deletedDate: String?,
         creationDate: String?, revisionDate: String?, login: RawLoginData?,
         card: RawCardData?, identity: RawIdentityData?, secureNote: RawSecureNoteData?,
         sshKey: RawSSHKeyData?, fields: [RawField]?, key: String?,
         collectionIds: [String] = [], attachments: [AttachmentDTO]?) {
        self.id             = id
        self.organizationId = organizationId
        self.folderId       = folderId
        self.type           = type
        self.name           = name
        self.notes          = notes
        self.favorite       = favorite
        self.reprompt       = reprompt
        self.deletedDate    = deletedDate
        self.creationDate   = creationDate
        self.revisionDate   = revisionDate
        self.login          = login
        self.card           = card
        self.identity       = identity
        self.secureNote     = secureNote
        self.sshKey         = sshKey
        self.fields         = fields
        self.key            = key
        self.collectionIds  = collectionIds
        self.attachments    = attachments
    }
}

// MARK: - Login

nonisolated struct RawLoginData: Codable {
    let username: String?       // EncString
    let password: String?       // EncString
    let uris:     [RawURI]?
    let totp:     String?       // EncString
}

nonisolated struct RawURI: Codable {
    let uri:   String?          // EncString
    /// 0=default, 1=baseDomain, 2=host, 3=startsWith, 4=exact, 5=regex, null=default
    let match: Int?
}

// MARK: - Card

nonisolated struct RawCardData: Codable {
    let cardholderName: String? // EncString
    let brand:          String? // EncString
    let number:         String? // EncString
    let expMonth:       String? // EncString
    let expYear:        String? // EncString
    let code:           String? // EncString
}

// MARK: - Identity

nonisolated struct RawIdentityData: Codable {
    let title:          String? // EncString
    let firstName:      String? // EncString
    let middleName:     String? // EncString
    let lastName:       String? // EncString
    let address1:       String? // EncString
    let address2:       String? // EncString
    let address3:       String? // EncString
    let city:           String? // EncString
    let state:          String? // EncString
    let postalCode:     String? // EncString
    let country:        String? // EncString
    let company:        String? // EncString
    let email:          String? // EncString
    let phone:          String? // EncString
    let ssn:            String? // EncString
    let username:       String? // EncString
    let passportNumber: String? // EncString
    let licenseNumber:  String? // EncString
}

// MARK: - Secure Note

nonisolated struct RawSecureNoteData: Codable {
    let type: Int   // 0 = Generic
}

// MARK: - SSH Key

nonisolated struct RawSSHKeyData: Codable {
    let privateKey:     String?    // EncString
    let publicKey:      String?    // EncString
    let keyFingerprint: String?    // EncString

    private enum CodingKeys: String, CodingKey {
        case privateKey, publicKey, keyFingerprint
    }
}

// MARK: - Custom Field

nonisolated struct RawField: Codable {
    /// 0 = text, 1 = hidden, 2 = boolean, 3 = linked
    let type:     Int
    let name:     String?   // EncString
    let value:    String?   // EncString
    let linkedId: Int?
}
