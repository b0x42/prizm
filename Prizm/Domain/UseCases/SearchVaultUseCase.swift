import Foundation

/// Filters the in-memory vault by a text query within the active sidebar selection.
protocol SearchVaultUseCase {
    func execute(query: String, in selection: SidebarSelection) async throws -> [VaultItem]
}
