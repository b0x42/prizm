import Foundation

final class CreateCollectionUseCaseImpl: CreateCollectionUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(name: String, organizationId: String) async throws -> OrgCollection {
        try await repository.createCollection(name: name, organizationId: organizationId)
    }
}
