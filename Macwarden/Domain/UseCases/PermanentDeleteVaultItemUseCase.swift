import Foundation

/// Permanently deletes a vault item that is already in Trash.
///
/// **This operation is irreversible.** The item is removed from the server and
/// cannot be recovered. The caller is responsible for presenting a confirmation
/// dialog before invoking `execute(id:)`.
///
/// Unlike `DeleteVaultItemUseCase` (which soft-deletes active items), this use
/// case targets trashed items only. Calling it on an active item is unsupported
/// and may return an error from the server.
///
/// Implemented by `PermanentDeleteVaultItemUseCaseImpl` in the Data layer.
protocol PermanentDeleteVaultItemUseCase: AnyObject {
    /// Permanently deletes the trashed item identified by `id`.
    ///
    /// - Parameter id: The cipher UUID of the trashed item to permanently remove.
    /// - Throws: `Error` on network or HTTP failure.
    func execute(id: String) async throws
}
