import Foundation

/// Delegates permanent deletion to `VaultRepository.permanentDeleteItem(id:)`.
final class PermanentDeleteVaultItemUseCaseImpl: PermanentDeleteVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    // macOS 15: avoid the isolated-deinit crash (swiftlang/swift#88036).
    nonisolated deinit {}

    func execute(id: String) async throws {
        try await repository.permanentDeleteItem(id: id)
    }
}
