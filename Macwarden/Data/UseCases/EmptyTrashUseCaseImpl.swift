import Foundation

/// Delegates empty-trash to `VaultRepository.emptyTrash()`.
final class EmptyTrashUseCaseImpl: EmptyTrashUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.emptyTrash()
    }
}
