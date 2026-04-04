import Foundation

/// Creates a new vault item by encrypting and posting it to the Bitwarden API.
protocol CreateVaultItemUseCase {
    func execute(draft: DraftVaultItem) async throws -> VaultItem
}
