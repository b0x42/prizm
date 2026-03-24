import SwiftUI

// MARK: - LoginEditForm

/// Edit form for Login vault items.
///
/// Mirrors the layout of `LoginDetailView`: Credentials card, Websites card,
/// Notes card, Custom Fields card. URIs can be added, removed, and reordered.
/// Password is masked by default.
struct LoginEditForm: View {

    @Binding var draft: DraftLoginContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                DetailSectionCard("Credentials") {
                    OptionalEditFieldRow(label: "Username", value: $draft.username)
                    Divider()
                    MaskedEditFieldRow(label: "Password", value: $draft.password, generatorBinding: $draft.password)
                }

                DetailSectionCard("Websites") {
                    ForEach(draft.uris) { uri in
                        if let index = draft.uris.firstIndex(where: { $0.id == uri.id }) {
                            if index > 0 { Divider() }
                            URIEditRow(
                                uri: $draft.uris[index],
                                canMoveUp: index > 0,
                                canMoveDown: index < draft.uris.count - 1,
                                showReorderButtons: draft.uris.count > 1,
                                onMoveUp: {
                                    guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }), i > 0 else { return }
                                    draft.uris.swapAt(i, i - 1)
                                },
                                onMoveDown: {
                                    guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }), i < draft.uris.count - 1 else { return }
                                    draft.uris.swapAt(i, i + 1)
                                },
                                onRemove: {
                                    guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }) else { return }
                                    draft.uris.remove(at: i)
                                }
                            )
                        }
                    }
                    if !draft.uris.isEmpty { Divider() }
                    Button {
                        draft.uris.append(DraftLoginURI())
                    } label: {
                        Label("Add Website", systemImage: "plus")
                            .font(Typography.fieldValue)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.borderless)
                    .padding(.vertical, Spacing.rowVertical)
                    .padding(.horizontal, Spacing.rowHorizontal)
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

/// An editable row for a single LoginURI, with match-type picker, reorder, and remove controls.
private struct URIEditRow: View {

    @Binding var uri: DraftLoginURI
    let canMoveUp: Bool
    let canMoveDown: Bool
    let showReorderButtons: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    @State private var showMatchType = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if showReorderButtons {
                    VStack(spacing: 2) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(Typography.utility)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!canMoveUp)

                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(Typography.utility)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!canMoveDown)
                    }
                    .padding(.leading, Spacing.rowHorizontal)
                }

                EditFieldRow(label: "Website", text: $uri.uri)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showMatchType.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(showMatchType ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)

                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, Spacing.rowHorizontal)
            }
            if showMatchType {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
