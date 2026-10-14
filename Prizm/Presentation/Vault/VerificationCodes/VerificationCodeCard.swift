import SwiftUI

// MARK: - VerificationCodeCard

/// The "Verification Code" card in a Login's detail pane (FR-001, FR-006).
///
/// Starts its own tracker while on screen and stops it when the view goes away or the app is
/// hidden or minimized, so no code lingers or refreshes in the background (FR-010, FR-011).
/// Shown only for a Login with a stored seed; the raw seed is never displayed (FR-017).
struct VerificationCodeCard: View {

    let item: VaultItem
    let onCopy: (String) -> Void

    @StateObject private var codes: TOTPCodesViewModel

    init(item: VaultItem, makeViewModel: @escaping () -> TOTPCodesViewModel, onCopy: @escaping (String) -> Void) {
        self.item = item
        self.onCopy = onCopy
        _codes = StateObject(wrappedValue: makeViewModel())
    }

    var body: some View {
        DetailSectionCard("Verification Code") {
            Group {
                if let state = codes.states[item.id] {
                    TOTPCodeRowView(itemId: item.id, name: item.name, state: state,
                                    label: "Code", copiesOnTap: true, onCopy: onCopy)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.vertical, 16) // same as FieldRowView
            .padding(.horizontal, Spacing.rowHorizontal)
        }
        .task(id: item) { codes.start(items: [item]) }
        .onDisappear { codes.stop() }
        .onAppVisibilityChange { visible in
            if visible { codes.start(items: [item]) } else { codes.stop() }
        }
    }
}
