import Foundation

final class MoveItemToFolderUseCaseImpl: MoveItemToFolderUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(itemId: String, folderId: String?) async throws {
        try await repository.moveItemToFolder(itemId: itemId, folderId: folderId)
    }

    func execute(itemIds: [String], folderId: String?) async throws {
        try await repository.moveItemsToFolder(itemIds: itemIds, folderId: folderId)
    }
}
