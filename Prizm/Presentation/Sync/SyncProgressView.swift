import SwiftUI

// MARK: - SyncProgressView

/// Shown while the vault is being fetched and decrypted after login.
/// Displays the current progress message from `SyncUseCase.execute(progress:)`.
///
/// This view is purely informational — there are no user actions.
/// It transitions automatically to the vault browser once syncing completes
/// (state transition driven by `LoginViewModel`).
struct SyncProgressView: View {

    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.5)
                .padding(.bottom, 8)

            Text(message)
                .font(Typography.progressLabel)
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: message)
                .accessibilityIdentifier(AccessibilityID.Sync.progressMessage)
        }
        .frame(minWidth: 480, minHeight: 320)
        .padding(Spacing.screenHorizontal)
    }
}
