import SwiftUI

// MARK: - LoginEditForm

/// Edit form for Login vault items.
///
/// Mirrors the layout of `LoginDetailView`: Credentials card, Websites card,
/// Notes card, Custom Fields card. All existing URI rows are editable (adding
/// and removing URIs is out of scope for v1). Password is masked by default.
struct LoginEditForm: View {

    @Binding var draft: DraftLoginContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailSectionCard("Credentials") {
                    OptionalEditFieldRow(label: "Username", value: $draft.username)
                    Divider()
                    MaskedEditFieldRow(label: "Password", value: $draft.password)
                }

                if !draft.uris.isEmpty {
                    DetailSectionCard("Websites") {
                        ForEach(draft.uris.indices, id: \.self) { index in
                            if index > 0 { Divider() }
                            URIEditRow(uri: $draft.uris[index])
                        }
                    }
                }

                DetailSectionCard("Notes") {
                    OptionalEditFieldRow(label: "Notes", value: $draft.notes)
                }

                CustomFieldsEditSection(fields: $draft.customFields)
            }
        }
    }
}

// MARK: - URIEditRow

/// An editable row for a single LoginURI, with a match-type picker.
private struct URIEditRow: View {

    @Binding var uri: DraftLoginURI

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            EditFieldRow(label: "Website", text: $uri.uri)
            Divider()
            HStack {
                Text("Match Type")
                    .font(Typography.fieldLabel)
                    .foregroundStyle(.secondary)
                    .padding(.leading, Spacing.rowHorizontal)
                Spacer()
                Picker("Match Type", selection: $uri.matchType) {
                    Text("Default").tag(URIMatchType?.none)
                    ForEach(URIMatchType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(URIMatchType?.some(type))
                    }
                }
                .labelsHidden()
                .padding(.trailing, Spacing.rowHorizontal)
            }
            .padding(.vertical, Spacing.rowVertical)
        }
    }
}

// MARK: - URIMatchType + Helpers

private extension URIMatchType {
    static var allCases: [URIMatchType] {
        [.domain, .host, .startsWith, .exact, .regularExpression, .never]
    }

    var displayName: String {
        switch self {
        case .domain:            return "Domain"
        case .host:              return "Host"
        case .startsWith:        return "Starts With"
        case .exact:             return "Exact"
        case .regularExpression: return "Regular Expression"
        case .never:             return "Never"
        }
    }
}
