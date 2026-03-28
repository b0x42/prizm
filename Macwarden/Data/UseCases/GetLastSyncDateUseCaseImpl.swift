import Foundation

/// Reads the last successful sync date from `SyncTimestampRepository`.
final class GetLastSyncDateUseCaseImpl: GetLastSyncDateUseCase {

    private let repository: any SyncTimestampRepository

    init(repository: any SyncTimestampRepository) {
        self.repository = repository
    }

    func execute() -> Date? {
        repository.lastSyncDate
    }
}
