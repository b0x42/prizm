import Foundation

/// Delegates soft-delete to `VaultRepository.deleteItem(id:)`.
final class DeleteVaultItemUseCaseImpl: DeleteVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    // macOS 15: avoid the isolated-deinit crash (swiftlang/swift#88036).
    nonisolated deinit {}

    func execute(id: String) async throws {
        try await repository.deleteItem(id: id)
    }
}
