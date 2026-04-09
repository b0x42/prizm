import Foundation

final class DeleteFolderUseCaseImpl: DeleteFolderUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(id: String) async throws {
        try await repository.deleteFolder(id: id)
    }
}
