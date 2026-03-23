import Foundation

/// Restores a soft-deleted vault item from Trash back to the active vault.
///
/// Implemented by `RestoreVaultItemUseCaseImpl` in the Data layer.
protocol RestoreVaultItemUseCase: AnyObject {
    /// Restores the trashed item identified by `id` to the active vault.
    ///
    /// - Parameter id: The cipher UUID of the trashed item to restore.
    /// - Throws: `APIError` on network or HTTP failure.
    func execute(id: String) async throws
}
