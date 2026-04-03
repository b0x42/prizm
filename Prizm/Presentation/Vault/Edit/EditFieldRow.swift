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

/// An editable field that masks its content by default with a reveal toggle.
///
/// Used for the Login password and SSH Key private key fields, consistent with
/// the app-wide treatment of sensitive values (spec §4.9, Constitution §III).
struct MaskedEditFieldRow: View {

    let label: String
    @Binding var value: String?
    /// When non-nil, a generator wand button is shown that opens the password generator popover.
    /// The binding receives the generated value when the user taps "Use".
    var generatorBinding: Binding<String?>?

    @State private var isRevealed = false
    /// Background task that auto-masks after the sensitive-field timeout.
    @State private var maskTask: Task<Void, Never>?
    @State private var showGenerator = false
    @State private var generatorVM: PasswordGeneratorViewModel?

    // TODO: make the timeout app-wide configurable (UserDefaults pref) — deferred to v2.
    // Using 30 s as a sensible default, matching the clipboard auto-clear interval.
    private let revealTimeout: Duration = .seconds(30)

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.fieldLabel)
                    .foregroundStyle(.secondary)

                if isRevealed {
                    TextField(
                        label,
                        text: Binding(
                            get:  { value ?? "" },
                            set:  { value = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(Typography.fieldValue.monospaced())
                    .textFieldStyle(.plain)
                } else {
                    SecureField(
                        label,
                        text: Binding(
                            get:  { value ?? "" },
                            set:  { value = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .font(Typography.fieldValue.monospaced())
                    .textFieldStyle(.plain)
                }
            }
            Spacer()

            if generatorBinding != nil {
                Button {
                    if generatorVM == nil {
                        generatorVM = PasswordGeneratorViewModel(provider: CryptographicRandomnessProvider())
                    }
                    showGenerator.toggle()
                } label: {
                    Image(systemName: "wand.and.stars")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help("Generate password")
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
                if isRevealed {
                    maskNow()
                } else {
                    reveal()
                }
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .help(isRevealed ? "Hide" : "Reveal")
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }

    private func reveal() {
        isRevealed = true
        // Cancel any outstanding mask task before scheduling a new one.
        maskTask?.cancel()
        maskTask = Task { @MainActor in
            do {
                try await Task.sleep(for: revealTimeout)
                maskNow()
            } catch {
                // Task cancelled (e.g., user manually re-hid) — do nothing.
            }
        }
    }

    private func maskNow() {
        isRevealed = false
        maskTask?.cancel()
        maskTask = nil
    }
}
