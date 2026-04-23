import Foundation

/// Delegates search to the `VaultRepository` which owns the in-memory store
/// and per-type field matching logic (FR-012).
final class SearchVaultUseCaseImpl: SearchVaultUseCase {

    private let vault: any VaultRepository

    init(vault: any VaultRepository) {
        self.vault = vault
    }

    func execute(query: String, in selection: SidebarSelection) async throws -> [VaultItem] {
        if query.isEmpty {
            return try await vault.items(for: selection)
        }
        return try await vault.searchItems(query: query, in: selection)
    }
}
