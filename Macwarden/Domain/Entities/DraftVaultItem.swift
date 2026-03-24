import Foundation

// MARK: - DraftLoginURI

/// Mutable mirror of `LoginURI` used exclusively within the edit flow.
///
/// Why mutable mirror instead of mutating `LoginURI` directly: `LoginURI` is a value type with
/// `let` fields, which prevents accidental mutation in read-only views. By introducing a separate
/// `DraftLoginURI` we confine mutability to the edit sheet and keep the read path immutable.
nonisolated struct DraftLoginURI: Equatable {
    var uri: String
    var matchType: URIMatchType?

    init(uri: String = "", matchType: URIMatchType? = nil) {
        self.uri = uri
        self.matchType = matchType
    }

    init(_ source: LoginURI) {
        self.uri = source.uri
        self.matchType = source.matchType
    }
}

// MARK: - DraftCustomField

/// Mutable mirror of `CustomField` used exclusively within the edit flow.
///
/// Field `name` and `type` are intentionally kept as `let` because renaming a custom field or
/// changing its type is out of scope for v1 editing (structural changes are deferred). Only
/// `value` can be mutated by the user.
nonisolated struct DraftCustomField: Equatable {
    /// Read-only: field names are structural and not editable in v1.
    let name: String
    var value: String?
    /// Read-only: field type changes are out of scope for v1 editing.
    let type: CustomFieldType
    /// Non-nil only when `type == .linked`.
    let linkedId: LinkedFieldId?

    init(_ source: CustomField) {
        self.name = source.name
        self.value = source.value
        self.type = source.type
        self.linkedId = source.linkedId
    }
}

// MARK: - Draft content types

/// Mutable mirror of `LoginContent` used exclusively within the edit flow.
///
/// See `DraftVaultItem` for the rationale behind the mutable mirror pattern.
nonisolated struct DraftLoginContent: Equatable {
    var username: String?
    var password: String?
    var uris: [DraftLoginURI]
    /// TOTP seed is not editable in v1.
    let totp: String?
    var notes: String?
    /// Custom field values are editable; adding/removing/reordering is out of scope.
    var customFields: [DraftCustomField]

    init(_ source: LoginContent) {
        self.username = source.username
        self.password = source.password
        self.uris = source.uris.map(DraftLoginURI.init)
        self.totp = source.totp
        self.notes = source.notes
        self.customFields = source.customFields.map(DraftCustomField.init)
    }
}

/// Mutable mirror of `CardContent` used exclusively within the edit flow.
///
/// See `DraftVaultItem` for the rationale behind the mutable mirror pattern.
nonisolated struct DraftCardContent: Equatable {
    var cardholderName: String?
    var brand: String?
    var number: String?
    var expMonth: String?
    var expYear: String?
    var code: String?
    var notes: String?
    var customFields: [DraftCustomField]

    init(_ source: CardContent) {
        self.cardholderName = source.cardholderName
        self.brand = source.brand
        self.number = source.number
        self.expMonth = source.expMonth
        self.expYear = source.expYear
        self.code = source.code
        self.notes = source.notes
        self.customFields = source.customFields.map(DraftCustomField.init)
    }
}

/// Mutable mirror of `IdentityContent` used exclusively within the edit flow.
///
/// See `DraftVaultItem` for the rationale behind the mutable mirror pattern.
nonisolated struct DraftIdentityContent: Equatable {
    var title: String?
    var firstName: String?
    var middleName: String?
    var lastName: String?
    var address1: String?
    var address2: String?
    var address3: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var country: String?
    var company: String?
    var email: String?
    var phone: String?
    var ssn: String?
    var username: String?
    var passportNumber: String?
    var licenseNumber: String?
    var notes: String?
    var customFields: [DraftCustomField]

    init(_ source: IdentityContent) {
        self.title = source.title
        self.firstName = source.firstName
        self.middleName = source.middleName
        self.lastName = source.lastName
        self.address1 = source.address1
        self.address2 = source.address2
        self.address3 = source.address3
        self.city = source.city
        self.state = source.state
        self.postalCode = source.postalCode
        self.country = source.country
        self.company = source.company
        self.email = source.email
        self.phone = source.phone
        self.ssn = source.ssn
        self.username = source.username
        self.passportNumber = source.passportNumber
        self.licenseNumber = source.licenseNumber
        self.notes = source.notes
        self.customFields = source.customFields.map(DraftCustomField.init)
    }
}

/// Mutable mirror of `SecureNoteContent` used exclusively within the edit flow.
///
/// See `DraftVaultItem` for the rationale behind the mutable mirror pattern.
nonisolated struct DraftSecureNoteContent: Equatable {
    var notes: String?
    var customFields: [DraftCustomField]

    init(_ source: SecureNoteContent) {
        self.notes = source.notes
        self.customFields = source.customFields.map(DraftCustomField.init)
    }
}

/// Mutable mirror of `SSHKeyContent` used exclusively within the edit flow.
///
/// `keyFingerprint` is excluded because it is auto-derived from the private key and is
/// not sent to the API — showing it as editable would be misleading.
nonisolated struct DraftSSHKeyContent: Equatable {
    var privateKey: String?
    var publicKey: String?
    /// Read-only display value. Auto-derived from `privateKey`; never sent to the API.
    let keyFingerprint: String?
    var notes: String?
    var customFields: [DraftCustomField]

    init(_ source: SSHKeyContent) {
        self.privateKey = source.privateKey
        self.publicKey = source.publicKey
        self.keyFingerprint = source.keyFingerprint
        self.notes = source.notes
        self.customFields = source.customFields.map(DraftCustomField.init)
    }
}

// MARK: - DraftItemContent

/// Mutable discriminated union mirroring `ItemContent`, used exclusively within the edit flow.
///
/// Mirrors `ItemContent` case-for-case so `ItemEditView` can switch on content type and
/// project a `Binding<DraftLoginContent>` (etc.) for the per-type edit form without casting.
/// The enum is mutable by carrying mutable associated values (`var` structs), which allows
/// SwiftUI to propagate changes back through `@Binding` chains to the ViewModel's `draft`.
///
/// See `DraftVaultItem` for the rationale behind the mutable mirror pattern.
nonisolated enum DraftItemContent: Equatable {
    case login(DraftLoginContent)
    case secureNote(DraftSecureNoteContent)
    case card(DraftCardContent)
    case identity(DraftIdentityContent)
    case sshKey(DraftSSHKeyContent)
}

// MARK: - DraftVaultItem

/// Mutable mirror of `VaultItem` used exclusively within the edit flow.
///
/// Why a mutable mirror instead of mutating `VaultItem`:
/// `VaultItem` has `let` fields to prevent accidental mutation anywhere in the app. Widening
/// mutation to `var` would require `@State` copies in every read-only detail view and remove
/// the safety guarantee that domain entities are never modified outside the write path.
/// `DraftVaultItem` confines that mutability to the edit sheet where it is intentional.
///
/// Lifecycle:
/// 1. Created via `DraftVaultItem.init(_ item: VaultItem)` when the edit sheet opens.
/// 2. Mutated as the user edits fields in the `ItemEditViewModel`.
/// 3. Passed to `EditVaultItemUseCase.execute(draft:)` on save.
/// 4. Cleared from memory when the sheet is dismissed (Constitution §III plaintext minimisation).
nonisolated struct DraftVaultItem: Equatable {
    /// Immutable — item identity cannot change during an edit.
    let id: String
    var name: String
    var isFavorite: Bool
    /// Deletion state is not editable in v1.
    let isDeleted: Bool
    /// Dates are server-managed; not editable.
    let creationDate: Date
    let revisionDate: Date
    var content: DraftItemContent
    /// Re-prompt setting from `VaultItem.reprompt` — carried through unchanged so PUT
    /// round-trips it correctly. Not user-editable in v1.
    let reprompt: Int

    /// Converts an immutable `VaultItem` into a mutable draft ready for editing.
    init(_ item: VaultItem) {
        self.id = item.id
        self.name = item.name
        self.isFavorite = item.isFavorite
        self.isDeleted = item.isDeleted
        self.creationDate = item.creationDate
        self.revisionDate = item.revisionDate
        self.reprompt = item.reprompt
        self.content = {
            switch item.content {
            case .login(let c):      return .login(DraftLoginContent(c))
            case .secureNote(let c): return .secureNote(DraftSecureNoteContent(c))
            case .card(let c):       return .card(DraftCardContent(c))
            case .identity(let c):   return .identity(DraftIdentityContent(c))
            case .sshKey(let c):     return .sshKey(DraftSSHKeyContent(c))
            }
        }()
    }
}

// MARK: - VaultItem ← DraftVaultItem

extension VaultItem {
    /// Reconstructs an immutable `VaultItem` from a saved draft.
    ///
    /// Only called after a successful `PUT /ciphers/{id}` response has been decoded into a
    /// server-confirmed `VaultItem` via `CipherMapper`. This path is provided for any
    /// post-save local patching if needed; normally the API response is used directly.
    init(_ draft: DraftVaultItem) {
        self.id = draft.id
        self.name = draft.name
        self.isFavorite = draft.isFavorite
        self.isDeleted = draft.isDeleted
        self.creationDate = draft.creationDate
        self.revisionDate = draft.revisionDate
        self.reprompt = draft.reprompt
        self.content = {
            switch draft.content {
            case .login(let c):
                return .login(LoginContent(
                    username: c.username,
                    password: c.password,
                    uris: c.uris.map { LoginURI(uri: $0.uri, matchType: $0.matchType) },
                    totp: c.totp,
                    notes: c.notes,
                    customFields: c.customFields.map {
                        CustomField(name: $0.name, value: $0.value, type: $0.type, linkedId: $0.linkedId)
                    }
                ))
            case .secureNote(let c):
                return .secureNote(SecureNoteContent(
                    notes: c.notes,
                    customFields: c.customFields.map {
                        CustomField(name: $0.name, value: $0.value, type: $0.type, linkedId: $0.linkedId)
                    }
                ))
            case .card(let c):
                return .card(CardContent(
                    cardholderName: c.cardholderName,
                    brand: c.brand,
                    number: c.number,
                    expMonth: c.expMonth,
                    expYear: c.expYear,
                    code: c.code,
                    notes: c.notes,
                    customFields: c.customFields.map {
                        CustomField(name: $0.name, value: $0.value, type: $0.type, linkedId: $0.linkedId)
                    }
                ))
            case .identity(let c):
                return .identity(IdentityContent(
                    title: c.title,
                    firstName: c.firstName,
                    middleName: c.middleName,
                    lastName: c.lastName,
                    address1: c.address1,
                    address2: c.address2,
                    address3: c.address3,
                    city: c.city,
                    state: c.state,
                    postalCode: c.postalCode,
                    country: c.country,
                    company: c.company,
                    email: c.email,
                    phone: c.phone,
                    ssn: c.ssn,
                    username: c.username,
                    passportNumber: c.passportNumber,
                    licenseNumber: c.licenseNumber,
                    notes: c.notes,
                    customFields: c.customFields.map {
                        CustomField(name: $0.name, value: $0.value, type: $0.type, linkedId: $0.linkedId)
                    }
                ))
            case .sshKey(let c):
                return .sshKey(SSHKeyContent(
                    privateKey: c.privateKey,
                    publicKey: c.publicKey,
                    keyFingerprint: c.keyFingerprint,
                    notes: c.notes,
                    customFields: c.customFields.map {
                        CustomField(name: $0.name, value: $0.value, type: $0.type, linkedId: $0.linkedId)
                    }
                ))
            }
        }()
    }
}
