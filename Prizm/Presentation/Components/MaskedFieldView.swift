import Observation
import SwiftUI

// MARK: - SecretVisibilityState

/// Shared reveal state for the currently selected vault item.
///
/// A revision counter lets every masked field adopt the same value after a global
/// toggle, including fields that had previously been revealed individually.
@Observable
@MainActor
final class SecretVisibilityState {
    private(set) var revealsAll = false
    private(set) var revision = 0

    func toggleAll() {
        revealsAll.toggle()
        revision += 1
    }

    func concealAll() {
        revealsAll = false
        revision += 1
    }
}

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
        displayValue(peeking: false)
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
/// MaskedFieldView(
///     label: "Password",
///     value: item.password,
///     itemId: item.id,
///     isRevealed: $isRevealed
/// )
/// ```
struct MaskedFieldView: View {

    let label:  String
    let value:  String?
    /// A stable identifier for the current item; changing this resets the reveal state.
    let itemId: String

    @Binding var isRevealed: Bool
    @Environment(OptionKeyMonitor.self) private var optionKeyMonitor
    @Environment(SecretVisibilityState.self) private var secretVisibility

    /// Plaintext when revealed via toggle OR Option-key peek.
    private var effectiveDisplayValue: String {
        MaskedFieldState(value: value ?? "", isRevealed: isRevealed)
            .displayValue(peeking: optionKeyMonitor.isOptionHeld || secretVisibility.revealsAll)
    }

    private var isEffectivelyRevealed: Bool {
        isRevealed || secretVisibility.revealsAll
    }

    var body: some View {
        HStack {
            Button {
                if secretVisibility.revealsAll {
                    secretVisibility.concealAll()
                } else {
                    isRevealed.toggle()
                }
            } label: {
                Image(systemName: isEffectivelyRevealed ? "eye.slash" : "eye")
                    .imageScale(.medium)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(isEffectivelyRevealed ? "Hide" : "Reveal")
            .accessibilityLabel(isEffectivelyRevealed ? "Hide \(label)" : "Reveal \(label)")
            .accessibilityValue(isEffectivelyRevealed ? "Revealed" : "Hidden")
            .accessibilityIdentifier(AccessibilityID.Masked.toggle(label))

            Text(effectiveDisplayValue)
                .font(Typography.fieldValue.monospaced())
                .textSelection(.enabled)
                .accessibilityIdentifier(AccessibilityID.Masked.value(label))
        }
        .onChange(of: secretVisibility.revision) {
            isRevealed = secretVisibility.revealsAll
        }
        // Reset to masked whenever the parent item changes (FR-027).
        .onChange(of: itemId) { _, _ in
            isRevealed = false
        }
    }
}
