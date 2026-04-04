import SwiftUI

// MARK: - SidebarFooterView

/// Persistent footer at the bottom of the sidebar column.
///
/// Shows the vault name on the left and a live sync status indicator on the right.
/// Anchored via `.safeAreaInset(edge: .bottom)` on `SidebarView` so it stays visible
/// regardless of the list scroll position (design §6).
///
/// **Sync indicator states:**
/// - `.idle`    → no icon (indicator area is empty)
/// - `.syncing` → rotating `arrow.clockwise` SF Symbol
/// - `.error`   → red `exclamationmark.triangle.fill`; tapping opens an error sheet
struct SidebarFooterView: View {

    let vaultName:   String
    let syncService: any SyncStatusProviding

    /// Controls the error-detail sheet (design §7).
    @State private var showErrorSheet: Bool = false

    /// Rotation angle used by the continuous sync spinner animation.
    @State private var spinnerAngle: Double = 0

    var body: some View {
        HStack {
            Text(vaultName)
                .font(Typography.listSubtitle)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            syncIndicator
        }
        .padding(.horizontal, Spacing.sidebarHorizontal)
        .padding(.top, Spacing.rowVertical)
        .padding(.bottom, Spacing.sidebarStatusBottom)
        .sheet(isPresented: $showErrorSheet) {
            errorSheetContent
        }
    }

    // MARK: - Sync indicator

    @ViewBuilder
    private var syncIndicator: some View {
        switch syncService.state {
        case .idle:
            // No icon in idle state — indicator area is empty.
            EmptyView()

        case .syncing:
            // Continuous rotation animation signals an active background sync.
            Image(systemName: "arrow.clockwise")
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(spinnerAngle))
                .animation(
                    .linear(duration: 1).repeatForever(autoreverses: false),
                    value: spinnerAngle
                )
                .onAppear { spinnerAngle = 360 }
                .onDisappear { spinnerAngle = 0 }

        case .error:
            // Tappable red icon — opens the error detail sheet.
            Button {
                showErrorSheet = true
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.small)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Sync error — tap for details")
            .accessibilityIdentifier(AccessibilityID.Vault.sidebarSyncError)
        }
    }

    // MARK: - Error sheet

    @ViewBuilder
    private var errorSheetContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("Sync Failed")
                .font(Typography.sectionHeader)

            Text(syncService.lastError?.localizedDescription ?? "An unknown error occurred.")
                .font(Typography.fieldValue)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Dismiss") {
                showErrorSheet = false
                syncService.clearError()
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(AccessibilityID.Vault.sidebarSyncErrorDismiss)
        }
        .padding(Spacing.pageMargin)
        .frame(minWidth: 280)
    }
}

#Preview("Idle") {
    SidebarFooterView(vaultName: "My Vault", syncService: PreviewSyncService(.idle))
        .frame(width: 220)
}

#Preview("Syncing") {
    SidebarFooterView(vaultName: "My Vault", syncService: PreviewSyncService(.syncing))
        .frame(width: 220)
}

#Preview("Error") {
    SidebarFooterView(vaultName: "My Vault", syncService: PreviewSyncService(.error(URLError(.notConnectedToInternet))))
        .frame(width: 220)
}

// MARK: - Preview helper

@MainActor
private final class PreviewSyncService: SyncStatusProviding {
    var state: SyncState
    var lastError: Error?
    init(_ state: SyncState) {
        self.state = state
        if case .error(let err) = state { lastError = err }
    }
    func trigger()    {}
    func clearError() { state = .idle; lastError = nil }
    func reset()      { state = .idle; lastError = nil }
}
