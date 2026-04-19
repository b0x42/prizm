import Foundation

/// Renames an existing collection within an organization.
/// The new name is encrypted with the org's symmetric key before being sent to the server.
protocol RenameCollectionUseCase {
    func execute(collectionId: String, name: String, organizationId: String) async throws -> OrgCollection
}
