import Foundation
import os.log

// MARK: - SyncTimestampRepositoryImpl

/// Persists the last successful vault sync timestamp to `UserDefaults`.
///
/// - Storage: `UserDefaults`, keyed per account email. Not a secret — no Keychain needed.
/// - Thread safety: implemented as an `actor` (CLAUDE.md: actor for shared mutable state in
///   the Data layer) to guard against concurrent reads/writes from the sync completion path
///   and the ViewModel load path.
/// - Key format: `com.macwarden.lastSyncDate.<email>` — scoped per account so that
///   switching accounts never shows a timestamp from a previous session.
/// - Format: ISO-8601 string via `ISO8601DateFormatter` — human-readable in developer tools.
actor SyncTimestampRepositoryImpl: SyncTimestampRepository {

    /// Stored as `nonisolated(unsafe)` because they are set exactly once in `init` and
    /// never mutated again — safe to read from any concurrency context.
    nonisolated(unsafe) private let key:      String
    nonisolated(unsafe) private let defaults: UserDefaults

    /// Shared formatter used for both reads and writes.
    ///
    /// `ISO8601DateFormatter` is thread-safe for concurrent use after construction (Apple docs).
    /// `nonisolated(unsafe)` is correct here: the formatter is a static constant, never mutated
    /// after initialisation, so there is no data race risk.
    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// - Parameters:
    ///   - email: The account email used to scope the UserDefaults key. Lowercased before use
    ///     to match the Bitwarden server's email normalisation convention, so different
    ///     casings of the same address map to a single key.
    ///   - defaults: The `UserDefaults` suite to write to. Defaults to `.standard`.
    ///     Pass a test-suite instance in unit tests to avoid polluting real defaults.
    init(email: String, defaults: UserDefaults = .standard) {
        self.key      = "com.macwarden.lastSyncDate.\(email.lowercased())"
        self.defaults = defaults
    }

    // MARK: - SyncTimestampRepository

    /// Returns the stored timestamp synchronously.
    ///
    /// `nonisolated` so callers on any actor (including `@MainActor` ViewModels) can
    /// read without `await`. `UserDefaults` reads are documented as thread-safe by Apple.
    nonisolated var lastSyncDate: Date? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return Self.formatter.date(from: raw)
    }

    /// Persists the current date as the last successful sync timestamp.
    ///
    /// `nonisolated` so callers on any actor (including `@MainActor` ViewModels) can invoke
    /// this synchronously without `await`, satisfying the non-isolated protocol requirement.
    /// `defaults` and `key` are `nonisolated(unsafe)` immutable lets, safe to access here.
    /// `UserDefaults.set` is thread-safe per Apple's documentation.
    ///
    /// Call only on the sync success path. Error paths MUST NOT call this — the stored
    /// value must always reflect the last *successful* sync.
    nonisolated func recordSuccessfulSync() {
        let iso = Self.formatter.string(from: Date())
        defaults.set(iso, forKey: key)
        // §V Observability: log that a sync timestamp was recorded. Timestamp is non-sensitive.
        // Local Logger allocation required because the actor-isolated `logger` property is not
        // accessible from a nonisolated context. os.Logger is a lightweight struct — no cost.
        Logger(subsystem: "com.macwarden", category: "SyncTimestampRepository")
            .info("Sync timestamp recorded: \(iso, privacy: .public)")
    }
}
