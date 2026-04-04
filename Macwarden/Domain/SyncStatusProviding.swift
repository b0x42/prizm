import Foundation

/// A Domain-layer protocol that exposes the live vault sync state to the Presentation layer.
///
/// Declared `@MainActor` so all consumers — SwiftUI views and `@MainActor`-isolated ViewModels
/// — can read properties and call methods without actor-boundary warnings (Swift 6 / SE-470).
/// `SyncService` in the Data layer is the only conformer in production; tests supply mocks.
@MainActor
protocol SyncStatusProviding: AnyObject {
    /// The current sync lifecycle state (.idle, .syncing, .error).
    var state: SyncState { get }

    /// The error from the most recent failed sync, or nil if the last sync succeeded.
    var lastError: Error? { get }

    /// Requests a vault sync.
    ///
    /// State transitions:
    /// - `.idle`    → `.syncing` (starts a new sync)
    /// - `.syncing` → records a pending trigger; one additional sync will run after the current one
    /// - `.error`   → `.syncing` (clears the error and starts a fresh sync)
    func trigger()

    /// Transitions from `.error` to `.idle` without starting a sync.
    ///
    /// No-op if state is not `.error`. Used by `SidebarFooterView` when the user taps
    /// the error sheet's Dismiss button.
    func clearError()

    /// Cancels any in-flight sync task and resets state to `.idle`.
    ///
    /// Called by `RootViewModel.lockVault()` to clear sync state on every lock,
    /// preventing stale error indicators after unlock.
    func reset()
}
