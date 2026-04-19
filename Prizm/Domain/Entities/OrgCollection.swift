import Foundation

/// A Bitwarden collection belonging to an organization.
/// Produced by `SyncRepositoryImpl` from `RawCollection` (name decrypted with the org key).
/// Value type — safe to pass across layers without defensive copying.
///
/// Named `OrgCollection` to avoid shadowing the `Swift.Collection` protocol in files
/// that import this module.
nonisolated struct OrgCollection: Identifiable, Equatable, Hashable {
    let id: String
    let organizationId: String
    let name: String
}
