import SwiftUI

// MARK: - TOTPCodeRowView

/// The code, its countdown, and a copy button for one item.
///
/// Used by the "Verification Code" card in the detail pane and by each row of the
/// Verification Codes list (which adds the favicon in front).
///
/// Accessibility (Constitution §VIII, FR-014): the code and countdown form ONE element that
/// speaks the digits individually plus the seconds remaining. It never posts an announcement
/// when the code rotates, so VoiceOver is not flooded every 30 seconds; the value is simply
/// current the next time the user focuses it. The copy button is a separate, labeled control.
struct TOTPCodeRowView: View {

    let itemId: String
    /// The item name, used for accessibility labels and, when `showsName` is true, shown.
    let name: String
    let state: TOTPCodeState
    var showsName: Bool = false
    /// Field label shown at the leading edge in the detail card (like "Username"); nil in the list.
    var label: String? = nil
    /// When true the whole row copies on tap, like `FieldRowView`. Off in the list, where a tap
    /// selects the row.
    var copiesOnTap: Bool = false
    let onCopy: (String) -> Void

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: 10) {
            if let label {
                Text(label)
                    .font(Typography.fieldValue)
                Spacer(minLength: 8)
            }
            if showsName {
                Text(name)
                    .font(Typography.listTitle)
                    .lineLimit(1)
                    // The row identifier lives on the name, not on the container: SwiftUI
                    // propagates a container's identifier to its children and would overwrite
                    // the code and copy-button identifiers.
                    .accessibilityIdentifier(AccessibilityID.VerificationCodes.row(itemId))
                Spacer(minLength: 8)
            }
            switch state {
            case .code(let code):
                if label == nil && !showsName { Spacer(minLength: 8) }
                copyButton(for: code)
                codeView(code)
            case .unavailable:
                if label == nil && !showsName { Spacer(minLength: 0) }
                Text("Code unavailable")
                    .font(Typography.fieldValue)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Verification code for \(name): unavailable")
                    .accessibilityIdentifier(AccessibilityID.VerificationCodes.code(itemId))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            optionalAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture {
            if copiesOnTap, case .code(let code) = state { copy(code) }
        }
    }

    // MARK: - Pieces

    private func codeView(_ code: TOTPCode) -> some View {
        HStack(spacing: 10) {
            Text(code.grouped)
                .font(Typography.fieldValue.monospaced())
                .textSelection(.enabled)
            countdown(code)
        }
        // One element, no per-rotation announcement. `.updatesFrequently` tells VoiceOver the
        // value changes on its own so it does not treat each change as news.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verification code for \(name)")
        .accessibilityValue("\(spokenDigits(code)), \(code.secondsRemaining) seconds remaining")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier(AccessibilityID.VerificationCodes.code(itemId))
    }

    /// Ring plus seconds. In the last seconds (FR-001a) the ring thickens, the number turns
    /// bold, and a warning symbol appears, so the cue is not carried by color alone.
    private func countdown(_ code: TOTPCode) -> some View {
        let expiring = code.isExpiringSoon
        let progress = Double(code.secondsRemaining) / Double(max(code.period, 1))
        return HStack(spacing: 4) {
            if expiring {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: expiring ? 4 : 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(expiring ? Color.orange : Color.accentColor,
                            style: StrokeStyle(lineWidth: expiring ? 4 : 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(code.secondsRemaining)")
                    .font(Typography.utility.monospacedDigit().weight(expiring ? .bold : .regular))
            }
            .frame(width: 26, height: 26)
        }
        .accessibilityHidden(true) // spoken through the code element's value
    }

    /// Matches the "COPY" / "COPIED" hover label used by every other field (`FieldRowView`).
    /// It stays in the accessibility tree and stays clickable while invisible (clear text), so VoiceOver and
    /// keyboard users can always reach it.
    private func copyButton(for code: TOTPCode) -> some View {
        Button {
            copy(code)
        } label: {
            Text(showCopied ? "copied" : "copy")
                .font(.headline)
                .textCase(.uppercase)
                // Clear (not opacity 0) so the button stays in the accessibility tree.
                .foregroundStyle(isHovered || showCopied ? Color.accentColor : Color.clear)
                .padding(.trailing, 4)
        }
        .buttonStyle(.plain)
        .help("Copy verification code")
        .accessibilityLabel("Copy verification code for \(name)")
        .accessibilityIdentifier(AccessibilityID.VerificationCodes.copyButton(itemId))
    }

    private func copy(_ code: TOTPCode) {
        onCopy(code.copyValue)
        optionalAnimation(.easeInOut(duration: 0.1)) { showCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            optionalAnimation(.easeInOut(duration: 0.1)) { showCopied = false }
        }
    }

    private func spokenDigits(_ code: TOTPCode) -> String {
        code.digits.map(String.init).joined(separator: " ")
    }
}
