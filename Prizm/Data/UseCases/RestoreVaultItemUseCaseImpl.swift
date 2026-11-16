import Foundation

/// Delegates restore to `VaultRepository.restoreItem(id:)`.
final class RestoreVaultItemUseCaseImpl: RestoreVaultItemUseCase {

    private let repository: any VaultRepository

    init(repository: any VaultRepository) {
        self.repository = repository
    }

    // macOS 15: avoid the isolated-deinit crash (swiftlang/swift#88036).
    nonisolated deinit {}

    func execute(id: String) async throws {
        try await repository.restoreItem(id: id)
    }
}
