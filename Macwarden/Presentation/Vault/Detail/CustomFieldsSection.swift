import SwiftUI

// MARK: - CustomFieldsSection

/// Renders a list of custom fields for any item type (FR-029).
///
/// - `text` fields: visible, copyable.
/// - `hidden` fields: masked, revealable.
/// - `boolean` fields: checkbox icon (read-only in v1).
/// - `linked` fields: shown as read-only label with linked field name.
struct CustomFieldsSection: View {

    let fields: [CustomField]
    let itemId: String
    let onCopy: (String) -> Void

    var body: some View {
        if fields.isEmpty { EmptyView() } else {
            Section {
                ForEach(fields.indices, id: \.self) { index in
                    let field = fields[index]
                    customFieldRow(field)
                    if index < fields.indices.last! {
                        Divider()
                    }
                }
            } header: {
                Text("Custom Fields")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private func customFieldRow(_ field: CustomField) -> some View {
        switch field.type {
        case .text:
            FieldRowView(
                label:  field.name,
                value:  field.value,
                itemId: itemId,
                onCopy: onCopy
            )

        case .hidden:
            FieldRowView(
                label:    field.name,
                value:    field.value,
                itemId:   itemId,
                isMasked: true,
                onCopy:   onCopy
            )

        case .boolean:
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: field.value == "true" ? "checkmark.square" : "square")
                        .imageScale(.medium)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)

        case .linked:
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("→ \(field.linkedId?.displayName ?? "Unknown Field")")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
    }
}
