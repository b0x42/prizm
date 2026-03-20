import SwiftUI

// MARK: - LoginDetailView

/// Detail view for Login items (FR-025, FR-029).
///
/// Displays username, masked password, each URI as an independent copyable row
/// with an open-in-browser button, notes, and custom fields.
struct LoginDetailView: View {

    let item:  VaultItem
    let login: LoginContent
    let onCopy: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let username = login.username {
                    FieldRowView(
                        label:  "Username",
                        value:  username,
                        itemId: item.id,
                        onCopy: onCopy
                    )
                    Divider()
                }

                if let password = login.password {
                    FieldRowView(
                        label:    "Password",
                        value:    password,
                        itemId:   item.id,
                        isMasked: true,
                        onCopy:   onCopy
                    )
                    Divider()
                }

                ForEach(login.uris.indices, id: \.self) { index in
                    let uri = login.uris[index]
                    FieldRowView(
                        label:  "Website",
                        value:  uri.uri,
                        itemId: item.id,
                        url:    URL(string: uri.uri),
                        onCopy: onCopy
                    )
                    Divider()
                }

                if let notes = login.notes, !notes.isEmpty {
                    FieldRowView(
                        label:  "Notes",
                        value:  notes,
                        itemId: item.id,
                        onCopy: onCopy
                    )
                    Divider()
                }

                CustomFieldsSection(fields: login.customFields, itemId: item.id, onCopy: onCopy)
            }
            .padding(.horizontal, 8)
        }
    }
}
