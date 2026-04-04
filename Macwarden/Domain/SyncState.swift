import Foundation

/// The current state of the background sync operation.
///
/// Owned by `SyncService` (Data layer) and exposed to the Presentation layer via
/// `SyncStatusProviding`. Lives in Domain so views can observe it without importing Data.
enum SyncState {
    /// No sync is in progress and the last sync (if any) succeeded.
    case idle
    /// A vault sync is actively running in the background.
    case syncing
    /// The most recent sync attempt failed with the given error.
    case error(Error)
}
