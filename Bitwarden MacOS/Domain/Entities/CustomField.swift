import Foundation

/// A user-defined or linked extra field attached to a vault item.
nonisolated struct CustomField: Equatable, Hashable {
    let name: String
    let value: String?
    let type: CustomFieldType
    /// Non-nil only when `type == .linked`.
    let linkedId: LinkedFieldId?
}

/// Discriminates how a custom field's value is stored and displayed.
nonisolated enum CustomFieldType: Int, Equatable, Hashable {
    case text = 0
    case hidden = 1
    case boolean = 2
    case linked = 3
}

/// Identifies a native vault-item field that a linked custom field mirrors.
/// Raw values match the Bitwarden API schema.
nonisolated enum LinkedFieldId: Int, Equatable, Hashable {
    // MARK: - Login fields
    case loginUsername = 100
    case loginPassword = 101

    // MARK: - Card fields
    case cardCardholderName = 300
    case cardExpMonth = 301
    case cardExpYear = 302
    case cardCode = 303
    case cardBrand = 304
    case cardNumber = 305

    // MARK: - Identity fields
    case identityTitle = 400
    case identityMiddleName = 401
    case identityAddress1 = 402
    case identityAddress2 = 403
    case identityAddress3 = 404
    case identityCity = 405
    case identityState = 406
    case identityPostalCode = 407
    case identityCountry = 408
    case identityCompany = 409
    case identityEmail = 410
    case identityPhone = 411
    case identitySsn = 412
    case identityUsername = 413
    case identityPassportNumber = 414
    case identityLicenseNumber = 415
    case identityFirstName = 416
    case identityLastName = 417
    case identityFullName = 418

    /// Human-readable label shown in the linked field row (e.g. "Username").
    var displayName: String {
        switch self {
        case .loginUsername:        return "Username"
        case .loginPassword:        return "Password"
        case .cardCardholderName:   return "Cardholder Name"
        case .cardExpMonth:         return "Expiration Month"
        case .cardExpYear:          return "Expiration Year"
        case .cardCode:             return "Security Code"
        case .cardBrand:            return "Brand"
        case .cardNumber:           return "Number"
        case .identityTitle:        return "Title"
        case .identityMiddleName:   return "Middle Name"
        case .identityAddress1:     return "Address 1"
        case .identityAddress2:     return "Address 2"
        case .identityAddress3:     return "Address 3"
        case .identityCity:         return "City"
        case .identityState:        return "State"
        case .identityPostalCode:   return "Postal Code"
        case .identityCountry:      return "Country"
        case .identityCompany:      return "Company"
        case .identityEmail:        return "Email"
        case .identityPhone:        return "Phone"
        case .identitySsn:          return "SSN"
        case .identityUsername:     return "Username"
        case .identityPassportNumber: return "Passport Number"
        case .identityLicenseNumber:  return "License Number"
        case .identityFirstName:    return "First Name"
        case .identityLastName:     return "Last Name"
        case .identityFullName:     return "Full Name"
        }
    }
}
