import Foundation

/// Reads the last successful sync date from `SyncTimestampRepository`.
///
/// This use case is intentionally thin — it delegates directly to the repository with no
/// additional logic. It exists to honour the architecture rule that the Presentation layer
/// accesses data exclusively through use-case protocols, keeping `SyncTimestampRepository`
/// out of ViewModels entirely. The indirection also makes the ViewModel's dependency on this
/// operation explicit and independently mockable in tests.
// @unchecked Sendable: the impl is read-only — execute() only reads
// repository.lastSyncDate, which is nonisolated. In production the repo is
// SyncTimestampRepositoryImpl (an actor, so Sendable); in tests it is a
// simple mock used single-threaded. Marking Sendable prevents Swift 6 from
// inferring @MainActor on the class when it is created inside an @MainActor
// context (AppContainer.init), which would otherwise bleed into test call sites.
final class GetLastSyncDateUseCaseImpl: GetLastSyncDateUseCase, @unchecked Sendable {

    private let repository: any SyncTimestampRepository

    init(repository: any SyncTimestampRepository) {
        self.repository = repository
    }

    func execute() -> Date? {
        repository.lastSyncDate
    }
}
