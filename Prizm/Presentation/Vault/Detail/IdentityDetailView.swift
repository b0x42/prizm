import SwiftUI

// MARK: - IdentityDetailView

/// Detail view for Identity items (FR-030, FR-046).
///
/// The 17+ identity fields are grouped into six labelled card sections to reduce
/// cognitive load: Personal Info, ID Numbers, Contact, Address, Notes, Custom Fields.
/// Each section is hidden entirely when all of its fields are nil/empty.
struct IdentityDetailView: View {

    let item:     VaultItem
    let identity: IdentityContent
    let onCopy:   (String) -> Void

    // MARK: - Section presence helpers

    private var hasPersonalInfo: Bool {
        identity.title != nil || identity.firstName != nil ||
        identity.middleName != nil || identity.lastName != nil || identity.company != nil
    }

    private var hasIDNumbers: Bool {
        identity.ssn != nil || identity.passportNumber != nil || identity.licenseNumber != nil
    }

    private var hasContact: Bool {
        identity.email != nil || identity.phone != nil || identity.username != nil
    }

    private var hasAddress: Bool {
        identity.address1 != nil || identity.address2 != nil || identity.address3 != nil ||
        identity.city != nil || identity.state != nil ||
        identity.postalCode != nil || identity.country != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

                if hasPersonalInfo {
                    DetailSectionCard("Personal Info") {
                        fieldRows([
                            ("Title",       identity.title),
                            ("First Name",  identity.firstName),
                            ("Middle Name", identity.middleName),
                            ("Last Name",   identity.lastName),
                            ("Company",     identity.company),
                        ])
                    }
                }

                if hasIDNumbers {
                    DetailSectionCard("ID Numbers") {
                        fieldRows([
                            ("SSN",             identity.ssn),
                            ("Passport Number", identity.passportNumber),
                            ("License Number",  identity.licenseNumber),
                        ])
                    }
                }

                if hasContact {
                    DetailSectionCard("Contact") {
                        fieldRows([
                            ("Email",    identity.email),
                            ("Phone",    identity.phone),
                            ("Username", identity.username),
                        ])
                    }
                }

                if hasAddress {
                    DetailSectionCard("Address") {
                        fieldRows([
                            ("Address 1",    identity.address1),
                            ("Address 2",    identity.address2),
                            ("Address 3",    identity.address3),
                            ("City",         identity.city),
                            ("State",        identity.state),
                            ("Postal Code",  identity.postalCode),
                            ("Country",      identity.country),
                        ])
                    }
                }

                if let notes = identity.notes, !notes.isEmpty {
                    DetailSectionCard("Notes") {
                        FieldRowView(label: "", value: notes, itemId: item.id, isMultiLine: true, onCopy: onCopy)
                    }
                }

                if !identity.customFields.isEmpty {
                    DetailSectionCard("Custom Fields") {
                        CustomFieldsSection(fields: identity.customFields, itemId: item.id, onCopy: onCopy)
                    }
                }
            }
    }

    // MARK: - Private helpers

    /// Renders a sequence of optional field rows with dividers between present fields.
    @ViewBuilder
    private func fieldRows(_ pairs: [(String, String?)]) -> some View {
        // Filter to only present values first so dividers are placed correctly.
        let present = pairs.filter { $0.1 != nil }
        ForEach(present.indices, id: \.self) { index in
            let (label, value) = present[index]
            if index > 0 { Divider() }
            FieldRowView(label: label, value: value!, itemId: item.id, onCopy: onCopy)
        }
    }
}
