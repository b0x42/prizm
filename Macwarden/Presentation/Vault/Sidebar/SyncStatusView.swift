import SwiftUI

// MARK: - SyncStatusView

/// Displays the last successful vault sync timestamp at the very bottom of the sidebar.
///
/// Pinned outside the scrollable list so it remains visible regardless of scroll position.
/// Uses `Typography.listSubtitle` to stay visually unobtrusive.
/// The view is only rendered when the vault browser is active — the parent screen state
/// machine (RootViewModel) hides the entire vault browser when locked, satisfying the
/// "hidden when vault is locked" requirement without additional logic here.
struct SyncStatusView: View {

    /// Relative label produced by the ViewModel's 60-second timer (e.g. "Synced 2 minutes ago").
    let label: String

    var body: some View {
        Text(label)
            .font(Typography.listSubtitle)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.rowHorizontal)
            .padding(.top, Spacing.rowVertical)
            .padding(.bottom, 14)
            .accessibilityIdentifier(AccessibilityID.Vault.syncStatusLabel)
    }
}

#Preview("Synced recently") {
    SyncStatusView(label: "Synced 2 minutes ago")
        .frame(width: 220)
}

#Preview("Never synced") {
    SyncStatusView(label: "Never synced")
        .frame(width: 220)
}
