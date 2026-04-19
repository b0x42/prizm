import Foundation

/// Deletes a collection from an organization.
/// Items that were in the collection remain in the vault — their `collectionIds` simply
/// no longer matches a known collection.
protocol DeleteCollectionUseCase {
    func execute(collectionId: String, organizationId: String) async throws
}
