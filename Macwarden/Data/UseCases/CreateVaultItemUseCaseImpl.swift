import Foundation

/// Concrete implementation of `CreateVaultItemUseCase`.
/// Delegates encryption and network I/O to `VaultRepository.create`.
final class CreateVaultItemUseCaseImpl: CreateVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    func execute(draft: DraftVaultItem) async throws -> VaultItem {
        try await repository.create(draft)
    }
}
