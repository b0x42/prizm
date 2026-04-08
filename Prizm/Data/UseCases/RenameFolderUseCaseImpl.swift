import Foundation

final class RenameFolderUseCaseImpl: RenameFolderUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(id: String, name: String) async throws -> Folder {
        try await repository.renameFolder(id: id, name: name)
    }
}
