import Foundation

/// Persists the date and time of the last successful vault sync, scoped per account.
///
/// - Security goal: non-sensitive UI metadata — no secrets, no encryption required.
/// - Storage: UserDefaults (not Keychain), consistent with other UI preference state.
/// - Isolation: each account's timestamp is stored under a key derived from the account
///   email so that switching accounts never shows a stale timestamp from another session.
protocol SyncTimestampRepository {
    /// The date and time of the last successful vault sync, or `nil` if no sync has
    /// completed for this account since the app was first installed.
    var lastSyncDate: Date? { get }

    /// Records the current date and time as the most recent successful sync.
    ///
    /// Call this only on the success path of a sync operation. Error paths MUST NOT
    /// call this method — the persisted timestamp should always reflect the last *successful* sync.
    func recordSuccessfulSync()
}
