import Foundation

/// Delegates soft-delete to `VaultRepository.deleteItem(id:)`.
final class DeleteVaultItemUseCaseImpl: DeleteVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.deleteItem(id: id)
    }
}
