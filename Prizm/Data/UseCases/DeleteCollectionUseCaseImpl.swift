import Foundation

final class DeleteCollectionUseCaseImpl: DeleteCollectionUseCase {
    private let repository: any VaultRepository
    init(repository: any VaultRepository) { self.repository = repository }

    func execute(collectionId: String, organizationId: String) async throws {
        try await repository.deleteCollection(id: collectionId, organizationId: organizationId)
    }

    // macOS 15: avoid the isolated-deinit crash (swiftlang/swift#88036).
    nonisolated deinit {}
}
