import Foundation

/// Creates a new collection within an organization.
/// The name is encrypted with the org's symmetric key before being sent to the server.
protocol CreateCollectionUseCase {
    func execute(name: String, organizationId: String) async throws -> OrgCollection
}
