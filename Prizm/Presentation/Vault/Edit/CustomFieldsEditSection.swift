import SwiftUI

// MARK: - CustomFieldsEditSection

/// Editable custom fields for a vault item.
///
/// Names and values can be changed, fields can be added or removed, and hidden values
/// remain masked until explicitly revealed.
struct CustomFieldsEditSection: View {

    /// Binding into the parent draft's `customFields` array.
    @Binding var fields: [DraftCustomField]
    let linkedFieldOptions: [LinkedFieldId]

    var body: some View {
        DetailSectionCard(
            "Custom Fields",
            showsBackground: !fields.isEmpty
        ) {
            ForEach(fields) { field in
                if let index = fields.firstIndex(where: { $0.id == field.id }) {
                    if index > 0 { Divider() }
                    CustomFieldEditRow(
                        field: $fields[index],
                        linkedFieldOptions: linkedFieldOptions,
                        canMoveUp: index > fields.startIndex,
                        canMoveDown: index < fields.index(before: fields.endIndex),
                        onMoveUp: {
                            moveField(from: index, to: index - 1)
                        },
                        onMoveDown: {
                            moveField(from: index, to: index + 1)
                        },
                        onDropField: { sourceID in
                            moveField(withID: sourceID, to: index)
                        },
                        onRemove: {
                            fields.removeAll { $0.id == field.id }
                        }
                    )
                }
            }

            if !fields.isEmpty { Divider() }

            Menu {
                Button("Text Field", systemImage: "textformat") {
                    addField(type: .text)
                }
                Button("Hidden Field", systemImage: "eye.slash") {
                    addField(type: .hidden)
                }
                Button("Boolean Field", systemImage: "checkmark.square") {
                    addField(type: .boolean)
                }
                if !linkedFieldOptions.isEmpty {
                    Button("Linked Field", systemImage: "link") {
                        addField(type: .linked)
                    }
                }
            } label: {
                Label("Add Custom Field", systemImage: "plus")
                    .font(Typography.fieldValue)
                    .foregroundStyle(Color.accentColor)
            }
            // `.button` + `.plain` keeps the label SwiftUI-rendered; the AppKit-backed
            // `.borderlessButton` style draws its own bezel and forces primary text color.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .padding(.vertical, fields.isEmpty ? 0 : Spacing.rowVertical)
            .padding(.horizontal, fields.isEmpty ? 0 : Spacing.rowHorizontal)
            .accessibilityLabel("Add custom field")
        }
    }

    private func addField(type: CustomFieldType) {
        fields.append(DraftCustomField(
            value: type == .boolean ? "false" : nil,
            type: type,
            linkedId: type == .linked ? linkedFieldOptions.first : nil
        ))
    }

    private func moveField(from sourceIndex: Int, to destinationIndex: Int) {
        guard fields.indices.contains(sourceIndex),
              fields.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }
        fields.swapAt(sourceIndex, destinationIndex)
    }

    private func moveField(withID sourceID: String, to destinationIndex: Int) -> Bool {
        guard let id = UUID(uuidString: sourceID),
              let sourceIndex = fields.firstIndex(where: { $0.id == id }),
              fields.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return false }

        fields.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        )
        return true
    }
}

// MARK: - CustomFieldEditRow

/// A single editable row for one custom field.
private struct CustomFieldEditRow: View {

    @Binding var field: DraftCustomField
    let linkedFieldOptions: [LinkedFieldId]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDropField: (String) -> Bool
    let onRemove: () -> Void

    @State private var isDropTargeted = false
    @FocusState private var isSecretFieldFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.headerGap) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .draggable(field.id.uuidString)
                .help("Drag to reorder")
                .accessibilityLabel("Reorder \(accessibleFieldName)")

            VStack(alignment: .leading, spacing: 2) {
                TextField("Key", text: $field.name)
                    .font(Typography.fieldLabel)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Custom field key")

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
                    .accessibilityLabel("\(accessibleFieldName) value")
                    .accessibilityValue(field.value == "true" ? "True" : "False")

                case .linked:
                    Picker("Linked Field", selection: $field.linkedId) {
                        ForEach(linkedFieldOptions, id: \.self) { option in
                            Text(option.displayName).tag(Optional(option))
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("\(accessibleFieldName) linked field")

                default: // .text
                    TextField("Value", text: valueBinding)
                    .font(Typography.fieldValue)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("\(accessibleFieldName) value")
                }
            }
            Spacer()

            if field.type == .hidden {
                Button {
                    isSecretFieldFocused.toggle()
                } label: {
                    Image(systemName: isSecretFieldFocused ? "eye.slash" : "eye")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help(isSecretFieldFocused ? "Hide" : "Edit")
                .accessibilityLabel(
                    isSecretFieldFocused
                        ? "Hide \(accessibleFieldName)"
                        : "Edit \(accessibleFieldName)"
                )
            }

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove custom field")
            .accessibilityLabel("Remove \(accessibleFieldName)")
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
        .background(
            isDropTargeted
                ? Color.accentColor.opacity(Opacity.dropTarget(contrast))
                : Color.clear
        )
        .dropDestination(for: String.self) { sourceIDs, _ in
            guard let sourceID = sourceIDs.first else { return false }
            return onDropField(sourceID)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .accessibilityAction(named: "Move up") {
            if canMoveUp { onMoveUp() }
        }
        .accessibilityAction(named: "Move down") {
            if canMoveDown { onMoveDown() }
        }
    }

    @ViewBuilder
    private var editableHiddenField: some View {
        TextField("Value", text: valueBinding)
            .font(Typography.fieldValue.monospaced())
            .textFieldStyle(.plain)
            .focused($isSecretFieldFocused)
            .foregroundStyle(isSecretFieldFocused ? Color.primary : Color.clear)
            .overlay(alignment: .leading) {
                if !isSecretFieldFocused, field.value?.isEmpty == false {
                    Text(MaskedFieldState.maskedPlaceholder)
                        .font(Typography.fieldValue.monospaced())
                        .foregroundStyle(.primary)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel("\(accessibleFieldName) value")
            .accessibilityValue(isSecretFieldFocused ? field.value ?? "" : "Hidden")
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { field.value ?? "" },
            set: { field.value = $0.isEmpty ? nil : $0 }
        )
    }

    private var accessibleFieldName: String {
        field.name.isEmpty ? "custom field" : field.name
    }
}
