import Foundation

/// Delegates restore to `VaultRepository.restoreItem(id:)`.
final class RestoreVaultItemUseCaseImpl: RestoreVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.restoreItem(id: id)
    }
}
