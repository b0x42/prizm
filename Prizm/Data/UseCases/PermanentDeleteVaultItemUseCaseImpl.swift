import Foundation

/// Delegates permanent deletion to `VaultRepository.permanentDeleteItem(id:)`.
final class PermanentDeleteVaultItemUseCaseImpl: PermanentDeleteVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.permanentDeleteItem(id: id)
    }
}
