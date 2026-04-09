import Foundation

final class CreateFolderUseCaseImpl: CreateFolderUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(name: String) async throws -> Folder {
        try await repository.createFolder(name: name)
    }
}
