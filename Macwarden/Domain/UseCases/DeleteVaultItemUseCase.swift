import Foundation

/// Soft-deletes a vault item by moving it to the Bitwarden Trash.
///
/// The item remains on the server (recoverable via `RestoreVaultItemUseCase`) until
/// it is permanently deleted. This operation never erases data irrecoverably — use
/// `PermanentDeleteVaultItemUseCase` to permanently remove a trashed item.
///
/// Implemented by `DeleteVaultItemUseCaseImpl` in the Data layer.
protocol DeleteVaultItemUseCase: AnyObject {
    /// Moves the item identified by `id` to Trash.
    ///
    /// - Parameter id: The cipher UUID of the item to soft-delete.
    /// - Throws: `Error` on network or HTTP failure.
    func execute(id: String) async throws
}
