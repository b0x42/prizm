import Foundation

/// Filters the in-memory vault by a text query within the active sidebar selection.
/// Runs synchronously on the calling thread — no I/O or async needed.
protocol SearchVaultUseCase {
    func execute(query: String, in selection: SidebarSelection) throws -> [VaultItem]
}
