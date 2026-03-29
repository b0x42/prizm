import Foundation

/// Reads the last successful sync date from `SyncTimestampRepository`.
///
/// This use case is intentionally thin — it delegates directly to the repository with no
/// additional logic. It exists to honour the architecture rule that the Presentation layer
/// accesses data exclusively through use-case protocols, keeping `SyncTimestampRepository`
/// out of ViewModels entirely. The indirection also makes the ViewModel's dependency on this
/// operation explicit and independently mockable in tests.
final class GetLastSyncDateUseCaseImpl: GetLastSyncDateUseCase {

    // nonisolated(unsafe) lets the nonisolated init assign this property even though the
    // class is otherwise @MainActor-inferred. The let guarantee makes this safe: the value
    // is written exactly once (in init) and never mutated thereafter.
    nonisolated(unsafe) private let repository: any SyncTimestampRepository

    // `nonisolated` so the init can be called from any concurrency context.
    // The class is otherwise inferred as @MainActor because AppContainer (which
    // is @MainActor) stores it as a let property. The nonisolated init breaks
    // that inference at the call site without affecting runtime safety, since
    // execute() only reads a nonisolated var on SyncTimestampRepository.
    nonisolated init(repository: any SyncTimestampRepository) {
        self.repository = repository
    }

    // `nonisolated` so callers in any concurrency context can invoke execute() without
    // a main-actor hop. Safe because `repository` is nonisolated(unsafe) and the
    // SyncTimestampRepository.lastSyncDate property itself carries no actor isolation.
    nonisolated func execute() -> Date? {
        repository.lastSyncDate
    }
}
