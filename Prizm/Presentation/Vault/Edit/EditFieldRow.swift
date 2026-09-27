import SwiftUI

// MARK: - EditFieldRow

/// A single labeled editable text field row, styled consistently with the read-only
/// `FieldRowView` to keep the edit and detail UIs visually aligned.
///
/// Usage:
/// ```swift
/// EditFieldRow(label: "Username", text: $draft.username)
/// EditFieldRow(label: "Notes", text: $draft.notes, isMultiline: true)
/// ```
struct EditFieldRow: View {

    let label:       String
    @Binding var text: String
    /// When `true` the value field expands to a multiline `TextEditor`.
    var isMultiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.fieldLabel)
                .foregroundStyle(.secondary)

            if isMultiline {
                TextEditor(text: $text)
                    .font(Typography.fieldValue)
                    .frame(minHeight: 64, maxHeight: 200)
                    .scrollContentBackground(.hidden)
            } else {
                TextField(label, text: $text)
                    .font(Typography.fieldValue)
                    .textFieldStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }
}

// MARK: - OptionalEditFieldRow

/// Like `EditFieldRow` but binds to an `Optional<String>`, treating nil as empty.
struct OptionalEditFieldRow: View {

    let label: String
    @Binding var value: String?

    var body: some View {
        EditFieldRow(
            label: label,
            text: Binding(
                get:  { value ?? "" },
                set:  { value = $0.isEmpty ? nil : $0 }
            )
        )
    }
}

// MARK: - MaskedEditFieldRow

/// An editable field that reveals its content only while it has keyboard focus.
///
/// Used for the Login password and SSH Key private key fields, consistent with
/// the app-wide treatment of sensitive values (spec §4.9, Constitution §III).
struct MaskedEditFieldRow: View {

    let label: String
    @Binding var value: String?
    /// When non-nil, a generation button is shown that opens the password generator popover.
    /// The binding receives the generated value when the user taps "Use".
    var generatorBinding: Binding<String?>?

    @State private var showGenerator = false
    @State private var generatorVM: PasswordGeneratorViewModel?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.fieldLabel)
                    .foregroundStyle(.secondary)

                TextField(label, text: valueBinding)
                    .font(Typography.fieldValue.monospaced())
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .foregroundStyle(isFieldFocused ? Color.primary : Color.clear)
                    .overlay(alignment: .leading) {
                        if !isFieldFocused, value?.isEmpty == false {
                            Text(MaskedFieldState.maskedPlaceholder)
                                .font(Typography.fieldValue.monospaced())
                                .foregroundStyle(.primary)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityValue(isFieldFocused ? value ?? "" : "Hidden")
            }
            Spacer()

            if generatorBinding != nil {
                Button {
                    if generatorVM == nil {
                        generatorVM = PasswordGeneratorViewModel(provider: CryptographicRandomnessProvider())
                    }
                    showGenerator.toggle()
                } label: {
                    Image(systemName: "dice.fill")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help("Generate password")
                .accessibilityLabel("Generate password")
                .accessibilityIdentifier(AccessibilityID.Generator.triggerButton)
                .popover(isPresented: $showGenerator) {
                    if let vm = generatorVM {
                        PasswordGeneratorView(
                            viewModel: vm,
                            targetValue: generatorBinding ?? $value
                        )
                    }
                }
            }

            Button {
                isFieldFocused.toggle()
            } label: {
                Image(systemName: isFieldFocused ? "eye.slash" : "eye")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .help(isFieldFocused ? "Hide" : "Edit")
            .accessibilityLabel(isFieldFocused ? "Hide \(label)" : "Edit \(label)")
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { value ?? "" },
            set: { value = $0.isEmpty ? nil : $0 }
        )
    }
}
