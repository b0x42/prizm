import Foundation

final class DeleteFolderUseCaseImpl: DeleteFolderUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(id: String) async throws {
        try await repository.deleteFolder(id: id)
    }

    // macOS 15: avoid the isolated-deinit crash (swiftlang/swift#88036).
    nonisolated deinit {}
}
