import SwiftUI

// MARK: - LoginDetailView

/// Detail view for Login items (FR-025, FR-029).
///
/// Fields are grouped into labelled card sections to reduce cognitive load
/// when scanning items with multiple URIs, notes, and custom fields.
/// Sections are hidden entirely when their content is nil/empty.
struct LoginDetailView: View {

    let item:  VaultItem
    let login: LoginContent
    let onCopy: (String) -> Void

    // A Credentials card is only meaningful when at least one credential field is present.
    private var hasCredentials: Bool {
        login.username != nil || login.password != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

                if hasCredentials {
                    DetailSectionCard("Credentials") {
                        if let username = login.username {
                            FieldRowView(
                                label:  "Username",
                                value:  username,
                                itemId: item.id,
                                onCopy: onCopy
                            )
                        }
                        if login.username != nil && login.password != nil {
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
                        }
                    }
                }

                if !login.uris.isEmpty {
                    DetailSectionCard("Websites") {
                        ForEach(login.uris.indices, id: \.self) { index in
                            let uri = login.uris[index]
                            if index > 0 { Divider() }
                            FieldRowView(
                                label:  "Website",
                                value:  uri.uri,
                                itemId: item.id,
                                url:    URL(string: uri.uri),
                                onCopy: onCopy
                            )
                        }
                    }
                }

                if let notes = login.notes, !notes.isEmpty {
                    DetailSectionCard("Notes") {
                        FieldRowView(label: "", value: notes, itemId: item.id, isMultiLine: true, onCopy: onCopy)
                    }
                }

                if !login.customFields.isEmpty {
                    DetailSectionCard("Custom Fields") {
                        CustomFieldsSection(
                            fields: login.customFields,
                            itemId: item.id,
                            onCopy: onCopy
                        )
                    }
                }
            }
    }
}
