import SwiftUI

// MARK: - IdentityDetailView

/// Detail view for Identity items (FR-030, FR-046).
///
/// Displays all identity fields. Each field row supports copy-on-hover.
/// Subtitle fallback chain (firstName+lastName → email → blank) applies to
/// item rows; in the detail pane every non-nil field is shown.
struct IdentityDetailView: View {

    let item:     VaultItem
    let identity: IdentityContent
    let onCopy:   (String) -> Void

    private var rows: [(String, String?)] {
        [
            ("Title",           identity.title),
            ("First Name",      identity.firstName),
            ("Middle Name",     identity.middleName),
            ("Last Name",       identity.lastName),
            ("Company",         identity.company),
            ("SSN",             identity.ssn),
            ("Passport Number", identity.passportNumber),
            ("License Number",  identity.licenseNumber),
            ("Email",           identity.email),
            ("Phone",           identity.phone),
            ("Username",        identity.username),
            ("Address 1",       identity.address1),
            ("Address 2",       identity.address2),
            ("Address 3",       identity.address3),
            ("City",            identity.city),
            ("State",           identity.state),
            ("Postal Code",     identity.postalCode),
            ("Country",         identity.country),
            ("Notes",           identity.notes),
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    let (label, value) = rows[index]
                    if let value {
                        FieldRowView(label: label, value: value, itemId: item.id, onCopy: onCopy)
                        Divider()
                    }
                }
                CustomFieldsSection(fields: identity.customFields, itemId: item.id, onCopy: onCopy)
            }
            .padding(.horizontal, 8)
        }
    }
}
