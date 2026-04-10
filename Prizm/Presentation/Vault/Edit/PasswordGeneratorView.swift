import SwiftUI

/// Password/passphrase generator popover.
/// Receives a binding to write the generated value into the target field.
struct PasswordGeneratorView: View {

    @ObservedObject var viewModel: PasswordGeneratorViewModel
    @Binding var targetValue: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Mode picker
            Picker("Mode", selection: $viewModel.mode) {
                Text("Password").tag(PasswordGeneratorConfig.Mode.password)
                Text("Passphrase").tag(PasswordGeneratorConfig.Mode.passphrase)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityID.Generator.modePicker)

            Divider()

            // Mode-specific controls
            switch viewModel.mode {
            case .password:
                passwordControls
            case .passphrase:
                passphraseControls
            }

            Divider()

            // Preview area
            previewArea

            Divider()

            // Action row
            actionRow
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: - Password controls

    @ViewBuilder
    private var passwordControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Length: \(viewModel.length)")
                    .font(Typography.fieldLabel)
                Spacer()
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.length) },
                    set: { viewModel.length = Int($0) }
                ),
                in: 5...128,
                step: 1
            )
            .accessibilityIdentifier(AccessibilityID.Generator.lengthSlider)

            Toggle("Uppercase (A–Z)", isOn: $viewModel.includeUppercase)
                .disabled(isLastEnabledSet(\.includeUppercase))
                .accessibilityIdentifier(AccessibilityID.Generator.uppercaseToggle)
            Toggle("Lowercase (a–z)", isOn: $viewModel.includeLowercase)
                .disabled(isLastEnabledSet(\.includeLowercase))
                .accessibilityIdentifier(AccessibilityID.Generator.lowercaseToggle)
            Toggle("Digits (0–9)", isOn: $viewModel.includeDigits)
                .disabled(isLastEnabledSet(\.includeDigits))
                .accessibilityIdentifier(AccessibilityID.Generator.digitsToggle)
            Toggle("Symbols (!@#$…)", isOn: $viewModel.includeSymbols)
                .disabled(isLastEnabledSet(\.includeSymbols))
                .accessibilityIdentifier(AccessibilityID.Generator.symbolsToggle)
            Toggle("Avoid ambiguous characters", isOn: $viewModel.avoidAmbiguous)
                .accessibilityIdentifier(AccessibilityID.Generator.avoidAmbiguousToggle)
        }
    }

    // MARK: - Passphrase controls

    @ViewBuilder
    private var passphraseControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper("Words: \(viewModel.wordCount)", value: $viewModel.wordCount, in: 3...10)
                .accessibilityIdentifier(AccessibilityID.Generator.wordCountStepper)
            HStack {
                Text("Separator")
                    .font(Typography.fieldLabel)
                TextField("Separator", text: $viewModel.separator)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .accessibilityIdentifier(AccessibilityID.Generator.separatorField)
            }
            Toggle("Capitalize each word", isOn: $viewModel.capitalize)
                .accessibilityIdentifier(AccessibilityID.Generator.capitalizeToggle)
            Toggle("Include number", isOn: $viewModel.includeNumber)
                .accessibilityIdentifier(AccessibilityID.Generator.includeNumberToggle)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewArea: some View {
        HStack {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.fieldValue)
                    .foregroundStyle(.red)
            } else {
                Text(viewModel.generatedValue)
                    .font(Typography.fieldValue.monospaced())
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(AccessibilityID.Generator.preview)
            }
            Spacer()
            Button {
                viewModel.generate()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Generate new")
            .accessibilityLabel("Generate new password")
            .accessibilityIdentifier(AccessibilityID.Generator.refreshButton)
        }
        .frame(minHeight: 40)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionRow: some View {
        HStack {
            Button("Copy") {
                viewModel.copyToClipboard()
            }
            .disabled(viewModel.errorMessage != nil)
            .accessibilityHint("Copies to clipboard")
            .accessibilityIdentifier(AccessibilityID.Generator.copyButton)

            Spacer()

            Button(viewModel.mode == .password ? "Use Password" : "Use Passphrase") {
                targetValue = viewModel.generatedValue
                dismiss()
            }
            .disabled(viewModel.errorMessage != nil)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.Generator.useButton)
        }
    }

    // MARK: - Helpers

    /// Returns `true` if the given toggle is the last enabled character set.
    private func isLastEnabledSet(_ keyPath: KeyPath<PasswordGeneratorViewModel, Bool>) -> Bool {
        let enabled = [
            viewModel.includeUppercase,
            viewModel.includeLowercase,
            viewModel.includeDigits,
            viewModel.includeSymbols
        ].filter { $0 }.count
        return enabled == 1 && viewModel[keyPath: keyPath]
    }
}
