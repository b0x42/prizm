import Foundation

final class DeleteCollectionUseCaseImpl: DeleteCollectionUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(collectionId: String, organizationId: String) async throws {
        try await repository.deleteCollection(id: collectionId, organizationId: organizationId)
    }
}
