import Foundation

/// Permanently deletes all items in the Bitwarden Trash in a single bulk operation.
///
/// **This operation is irreversible.** All trashed items are removed from the server
/// and cannot be recovered. The caller is responsible for presenting a confirmation
/// dialog before invoking `execute()`.
///
/// Implemented by `EmptyTrashUseCaseImpl` in the Data layer.
protocol EmptyTrashUseCase: AnyObject {
    /// Permanently deletes every item currently in Trash.
    ///
    /// - Throws: `APIError` on network or HTTP failure.
    func execute() async throws
}
