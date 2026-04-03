import Foundation

// MARK: - SyncUseCaseImpl

/// Thin wrapper around `SyncRepository.sync` — exposes the sync operation to the
/// Presentation layer via the Domain `SyncUseCase` protocol.
final class SyncUseCaseImpl: SyncUseCase {

    private let sync: any SyncRepository

    init(sync: any SyncRepository) {
        self.sync = sync
    }

    func execute(progress: @Sendable @escaping (String) -> Void) async throws -> SyncResult {
        try await sync.sync(progress: progress)
    }
}
