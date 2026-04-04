import Foundation
import Observation
import os.log

// MARK: - SyncService

/// The single authoritative owner of vault sync state.
///
/// All callers — login flow, unlock flow, and mutation operations — go through
/// `trigger()` instead of calling `SyncRepository` directly.
///
/// **Design: `@MainActor @Observable final class` (not `actor`)**
/// SwiftUI `@Observable` requires property access on the main actor. A plain `actor`
/// would require `await syncService.state` in every view body, which is incompatible
/// with `@Observable`. All state is owned on the main actor; the actual `URLSession`
/// work happens off-main inside `SyncRepositoryImpl`; `SyncService` only `await`s the result.
///
/// **Deduplication: in-flight guard + single pending slot**
/// At most one sync runs at a time; any number of triggers while a sync is in-flight
/// collapse to a single "run one more after this one" flag (`pendingTrigger`). This
/// avoids unbounded queuing while guaranteeing eventual consistency after rapid mutations.
@MainActor @Observable
final class SyncService: SyncStatusProviding {

    // MARK: - Observable state

    /// The current sync lifecycle state. Observed by `SidebarFooterView`.
    private(set) var state: SyncState = .idle

    /// The error from the most recent failed sync, or nil.
    private(set) var lastError: Error? = nil

    // MARK: - Private state

    /// Tracks whether a second trigger arrived while a sync was in-flight.
    /// When the current sync finishes, one additional sync is run if this is true.
    private var pendingTrigger: Bool = false

    /// The active background sync task.
    ///
    /// Stored so `reset()` can cancel it.
    ///
    /// `nonisolated(unsafe)` is required because Swift 6 `deinit` is nonisolated
    /// and accessing a `@MainActor`-isolated stored property from `deinit` produces
    /// a compiler error. The value is only mutated on `@MainActor`, so this is safe.
    /// See swift/swift#79551 for the upstream compiler issue.
    nonisolated(unsafe) private var syncTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let sync: any SyncUseCase
    private let logger = Logger(subsystem: "com.macwarden", category: "SyncService")

    // MARK: - Init

    init(sync: any SyncUseCase) {
        self.sync = sync
    }

    // MARK: - SyncStatusProviding

    /// Requests a vault sync.
    ///
    /// - `.idle`    → transitions to `.syncing` and dispatches a background `Task`
    /// - `.syncing` → sets `pendingTrigger = true`; no second concurrent sync is started
    /// - `.error`   → clears the error and starts a fresh sync
    func trigger() {
        switch state {
        case .idle:
            startSync()

        case .syncing:
            // Deduplication: record that a retry is needed; don't start a second sync.
            pendingTrigger = true
            logger.info("SyncService: trigger() while syncing — pending trigger set")

        case .error:
            // Treat trigger-from-error as a manual retry: clear the error and start fresh.
            lastError = nil
            startSync()
        }
    }

    /// Transitions from `.error` to `.idle` without starting a sync.
    ///
    /// No-op unless state is `.error`. Called by the error-sheet Dismiss button.
    func clearError() {
        guard case .error = state else { return }
        state     = .idle
        lastError = nil
        logger.info("SyncService: error cleared by user")
    }

    /// Cancels any in-flight sync task and resets to `.idle`.
    ///
    /// Called from `RootViewModel.lockVault()` so error state never persists across
    /// lock/unlock cycles. `CancellationError` thrown by the cancelled task is caught
    /// inside the task body and does NOT transition to `.error`.
    func reset() {
        syncTask?.cancel()
        syncTask       = nil
        pendingTrigger = false
        state          = .idle
        lastError      = nil
        logger.info("SyncService: reset (vault locked)")
    }

    // MARK: - Private

    private func startSync() {
        state = .syncing
        logger.info("SyncService: sync started")

        syncTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await sync.execute(progress: { _ in })
                // Only update state if the task was not cancelled (reset() sets state to .idle
                // before cancelling, so the Task.isCancelled check guards the success path).
                guard !Task.isCancelled else { return }
                await handleSyncSuccess()
            } catch is CancellationError {
                // Cancelled by reset() — not a failure; state already set to .idle by reset().
                return
            } catch {
                guard !Task.isCancelled else { return }
                await handleSyncError(error)
            }
        }
    }

    @MainActor
    private func handleSyncSuccess() {
        state          = .idle
        lastError      = nil
        logger.info("SyncService: sync succeeded")

        if pendingTrigger {
            pendingTrigger = false
            logger.info("SyncService: running pending trigger")
            startSync()
        }
    }

    @MainActor
    private func handleSyncError(_ error: Error) {
        state          = .error(error)
        lastError      = error
        pendingTrigger = false  // discard any queued trigger on error per spec
        logger.error("SyncService: sync failed — \(error.localizedDescription, privacy: .public)")
    }
}
