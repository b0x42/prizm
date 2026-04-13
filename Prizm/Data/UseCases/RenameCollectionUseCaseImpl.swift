import Foundation

final class RenameCollectionUseCaseImpl: RenameCollectionUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(collectionId: String, name: String, organizationId: String) async throws -> OrgCollection {
        try await repository.renameCollection(id: collectionId, organizationId: organizationId, name: name)
    }
}
