import Foundation

// MARK: - DownloadAttachmentUseCase

/// Downloads and decrypts a file attachment from the Bitwarden server.
///
/// The cipher key is resolved internally via `VaultKeyService` — it is NEVER a
/// parameter on `execute(...)`. This keeps key material out of the Presentation layer
/// and enforces the decryption boundary at the Data layer (Constitution §II/§III).
///
/// Implemented by `DownloadAttachmentUseCaseImpl` in the Data layer.
protocol DownloadAttachmentUseCase: AnyObject {

    /// Downloads and decrypts the file for the given attachment.
    ///
    /// - Parameters:
    ///   - cipherId:   The ID of the vault item the attachment belongs to.
    ///   - attachment: The attachment record containing the encrypted key and download URL.
    /// - Returns: Decrypted plaintext file bytes.
    /// - Throws: `AttachmentError.downloadFailed` after one retry on HTTP 403.
    /// - Throws: `VaultError.vaultLocked` if the vault is locked.
    func execute(cipherId: String, attachment: Attachment) async throws -> Data
}
