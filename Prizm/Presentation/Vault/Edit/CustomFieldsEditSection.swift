import SwiftUI

// MARK: - CustomFieldsEditSection

/// Editable rows for the existing custom fields of a vault item.
///
/// Each field shows its name as a read-only label (field names are structural and not
/// editable in v1) and its value as an editable `TextField`. Hidden-type fields are
/// masked by default with a reveal toggle.
///
/// Adding, removing, and reordering custom fields is out of scope for v1 editing.
struct CustomFieldsEditSection: View {

    /// Binding into the parent draft's `customFields` array.
    @Binding var fields: [DraftCustomField]

    var body: some View {
        if !fields.isEmpty {
            DetailSectionCard("Custom Fields") {
                ForEach(fields.indices, id: \.self) { index in
                    if index > 0 { Divider() }
                    CustomFieldEditRow(field: $fields[index])
                }
            }
        }
    }
}

// MARK: - CustomFieldEditRow

/// A single editable row for one custom field.
private struct CustomFieldEditRow: View {

    @Binding var field: DraftCustomField

    /// Controls reveal state for Hidden fields (masked by default — spec §4.9).
    @State private var isRevealed = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                // Field name is read-only (structural, not editable in v1).
                Text(field.name)
                    .font(Typography.fieldLabel)
                    .foregroundStyle(.secondary)

                switch field.type {
                case .hidden:
                    editableHiddenField

                case .boolean:
                    // Boolean fields use a Toggle; value is "true" or "false" string.
                    Toggle(
                        isOn: Binding(
                            get:  { field.value == "true" },
                            set:  { field.value = $0 ? "true" : "false" }
                        )
                    ) {
                        EmptyView()
                    }
                    .labelsHidden()

                case .linked:
                    // Linked fields are read-only by design — their value is derived
                    // from another field and cannot be independently edited.
                    Text(field.value ?? "—")
                        .font(Typography.fieldValue)
                        .foregroundStyle(.secondary)

                default: // .text
                    TextField(
                        field.name,
                        text: Binding(
                            get:  { field.value ?? "" },
                            set:  { field.value = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(Typography.fieldValue)
                    .textFieldStyle(.plain)
                }
            }
            Spacer()

            if field.type == .hidden {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide" : "Reveal")
                .accessibilityLabel(isRevealed ? "Hide \(field.name)" : "Reveal \(field.name)")
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }

    @ViewBuilder
    private var editableHiddenField: some View {
        if isRevealed {
            TextField(
                field.name,
                text: Binding(
                    get:  { field.value ?? "" },
                    set:  { field.value = $0.isEmpty ? nil : $0 }
                )
            )
            .font(Typography.fieldValue.monospaced())
            .textFieldStyle(.plain)
        } else {
            Text(MaskedFieldState.maskedPlaceholder)
                .font(Typography.fieldValue.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
