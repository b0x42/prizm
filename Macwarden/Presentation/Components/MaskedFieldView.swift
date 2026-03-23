import SwiftUI

// MARK: - MaskedFieldState

/// Testable value type driving the reveal/mask toggle logic for `MaskedFieldView`.
///
/// Keeping the state logic in a pure struct means it can be unit-tested without
/// rendering a SwiftUI view (FR-026, FR-027).
struct MaskedFieldState {

    /// The eight-bullet placeholder always shown when the field is masked (FR-026).
    static let maskedPlaceholder = "••••••••"

    let value: String
    var isRevealed: Bool

    init(value: String, isRevealed: Bool = false) {
        self.value      = value
        self.isRevealed = isRevealed
    }

    /// The string that should be displayed in the UI.
    var displayValue: String {
        isRevealed ? value : Self.maskedPlaceholder
    }

    /// Display value considering an external peek override (e.g. Option-key held).
    func displayValue(peeking: Bool) -> String {
        (isRevealed || peeking) ? value : Self.maskedPlaceholder
    }

    /// Returns a copy with `isRevealed` flipped.
    func toggled() -> MaskedFieldState {
        MaskedFieldState(value: value, isRevealed: !isRevealed)
    }

    /// Returns a new state for a different item, resetting to masked (FR-027).
    func resetForNewItem(value newValue: String) -> MaskedFieldState {
        MaskedFieldState(value: newValue, isRevealed: false)
    }
}

// MARK: - MaskedFieldView

/// A text field that shows eight bullet dots when masked and the real value when revealed.
///
/// The view accepts an optional `String?` value; nil is treated as an empty string.
/// `itemId` drives the `.onChange` that resets `isRevealed` when the parent item changes (FR-027).
///
/// Usage:
/// ```swift
/// MaskedFieldView(label: "Password", value: item.password, itemId: item.id)
/// ```
struct MaskedFieldView: View {

    let label:  String
    let value:  String?
    /// A stable identifier for the current item; changing this resets the reveal state.
    let itemId: String

    @State private var state: MaskedFieldState
    @Environment(OptionKeyMonitor.self) private var optionKeyMonitor

    init(label: String, value: String?, itemId: String) {
        self.label  = label
        self.value  = value
        self.itemId = itemId
        _state = State(initialValue: MaskedFieldState(value: value ?? ""))
    }

    /// Plaintext when revealed via toggle OR Option-key peek.
    private var effectiveDisplayValue: String {
        state.displayValue(peeking: optionKeyMonitor.isOptionHeld)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.fieldLabel)
                    .foregroundStyle(.secondary)
                Text(effectiveDisplayValue)
                    .font(Typography.fieldValue.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier(AccessibilityID.Masked.value(label))
            }
            Spacer()
            Button {
                state = state.toggled()
            } label: {
                Image(systemName: state.isRevealed ? "eye.slash" : "eye")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .help(state.isRevealed ? "Hide" : "Reveal")
            .accessibilityIdentifier(AccessibilityID.Masked.toggle(label))
        }
        // Reset to masked whenever the parent item changes (FR-027).
        .onChange(of: itemId) { _, _ in
            state = state.resetForNewItem(value: value ?? "")
        }
        // Keep value in sync if the item itself changes while the same itemId is reused.
        .onChange(of: value) { _, newValue in
            state = MaskedFieldState(value: newValue ?? "", isRevealed: state.isRevealed)
        }
    }
}
