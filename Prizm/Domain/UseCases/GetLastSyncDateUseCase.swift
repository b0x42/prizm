import Foundation

/// Returns the date of the last successful vault sync for the current account.
///
/// Reads from `SyncTimestampRepository`, which persists across app restarts.
/// Returns `nil` if no sync has completed for this account.
protocol GetLastSyncDateUseCase {
    func execute() -> Date?
}
