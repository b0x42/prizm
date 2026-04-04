import Foundation

// MARK: - DeleteAttachmentUseCase

/// Deletes a file attachment from the Bitwarden server.
///
/// Delete requires no key material — only the cipher ID and attachment ID are needed.
/// `VaultKeyService` is intentionally NOT injected here (Constitution §VI — YAGNI).
///
/// Implemented by `DeleteAttachmentUseCaseImpl` in the Data layer.
protocol DeleteAttachmentUseCase: AnyObject {

    /// Deletes the attachment identified by `attachmentId` from the given cipher.
    ///
    /// On success the in-memory vault cache is updated by the Data layer so the
    /// attachment row disappears from the UI without a full re-sync.
    ///
    /// - Parameters:
    ///   - cipherId:     The vault item the attachment belongs to.
    ///   - attachmentId: The ID of the attachment to delete.
    func execute(cipherId: String, attachmentId: String) async throws
}
