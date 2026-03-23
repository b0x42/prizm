import Foundation

/// A fully-decrypted vault entry. Produced by `CipherMapper` from a `RawCipher`.
/// Value type — safe to pass across layers without defensive copying.
nonisolated struct VaultItem: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let isFavorite: Bool
    let isDeleted: Bool
    let creationDate: Date
    let revisionDate: Date
    let content: ItemContent
    /// Master-password re-prompt setting mirrored from the Bitwarden wire format.
    /// 0 = disabled (default), 1 = require master password before revealing fields.
    /// Stored here so `CipherMapper.toRawCipher` can round-trip it unchanged on PUT,
    /// preventing silent loss of re-prompt protection during edits.
    let reprompt: Int

    /// Custom memberwise init with `reprompt` defaulted to 0 so existing call sites
    /// that pre-date this field do not need to be updated.
    init(
        id: String, name: String, isFavorite: Bool, isDeleted: Bool,
        creationDate: Date, revisionDate: Date, content: ItemContent,
        reprompt: Int = 0
    ) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.isDeleted = isDeleted
        self.creationDate = creationDate
        self.revisionDate = revisionDate
        self.content = content
        self.reprompt = reprompt
    }
}

// MARK: - Item content discriminator

/// Discriminated union of all five Bitwarden vault item types.
nonisolated enum ItemContent: Equatable, Hashable {
    case login(LoginContent)
    case secureNote(SecureNoteContent)
    case card(CardContent)
    case identity(IdentityContent)
    case sshKey(SSHKeyContent)
}

// MARK: - Login

nonisolated struct LoginContent: Equatable, Hashable {
    let username: String?
    let password: String?
    let uris: [LoginURI]
    /// Stored TOTP seed. Present on some items but never displayed in v1 (FR-038).
    let totp: String?
    let notes: String?
    let customFields: [CustomField]
}

nonisolated struct LoginURI: Equatable, Hashable {
    let uri: String
    let matchType: URIMatchType?
}

/// URI-matching strategy used when auto-filling (stored per URI, not used in v1 display).
nonisolated enum URIMatchType: Int, Equatable, Hashable {
    case domain = 0
    case host = 1
    case startsWith = 2
    case exact = 3
    case regularExpression = 4
    case never = 5
}

// MARK: - Card

nonisolated struct CardContent: Equatable, Hashable {
    let cardholderName: String?
    let brand: String?
    let number: String?
    let expMonth: String?
    let expYear: String?
    let code: String?
    let notes: String?
    let customFields: [CustomField]
}

// MARK: - Identity

nonisolated struct IdentityContent: Equatable, Hashable {
    let title: String?
    let firstName: String?
    let middleName: String?
    let lastName: String?
    let address1: String?
    let address2: String?
    let address3: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let company: String?
    let email: String?
    let phone: String?
    let ssn: String?
    let username: String?
    let passportNumber: String?
    let licenseNumber: String?
    let notes: String?
    let customFields: [CustomField]
}

// MARK: - Secure Note

nonisolated struct SecureNoteContent: Equatable, Hashable {
    let notes: String?
    let customFields: [CustomField]
}

// MARK: - SSH Key

nonisolated struct SSHKeyContent: Equatable, Hashable {
    let privateKey: String?
    let publicKey: String?
    let keyFingerprint: String?
    let notes: String?
    let customFields: [CustomField]
}
