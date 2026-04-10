import Foundation

// MARK: - AttachmentRepository

/// Domain repository for file attachment operations — upload, download, and delete.
///
/// All methods accept a raw 64-byte `cipherKey: Data` (encryptionKey ‖ macKey).
/// The Data layer implementation splits this into `CryptoKeys` at the boundary
/// and passes the components to `PrizmCryptoService` methods.
///
/// The caller (use case) is responsible for obtaining the cipher key via
/// `VaultKeyService.cipherKey(for:)` — it is NEVER a parameter on the
/// use-case `execute(...)` signatures (Constitution §II/§III).
///
/// Implemented by `AttachmentRepositoryImpl` in the Data layer.
protocol AttachmentRepository {

    /// Uploads a file as a new attachment to the given cipher.
    ///
    /// - Parameters:
    ///   - cipherId:  The ID of the vault item to attach the file to.
    ///   - fileName:  Plaintext file name (will be encrypted before upload).
    ///   - data:      Raw file bytes (will be encrypted before upload).
    ///   - cipherKey: 64-byte effective cipher key (encKey ‖ macKey) used to
    ///                wrap the per-attachment key and encrypt the file name.
    /// - Returns: The newly created `Attachment` with `isUploadIncomplete = false`.
    /// - Throws: `AttachmentError.premiumRequired` on HTTP 402.
    /// - Throws: `VaultError.vaultLocked` if the vault is locked before the call.
    func upload(cipherId: String, fileName: String, data: Data, cipherKey: Data) async throws -> Attachment

    /// Downloads and decrypts the file blob for the given attachment.
    ///
    /// - Parameters:
    ///   - cipherId:   The ID of the vault item the attachment belongs to.
    ///   - attachment: The attachment record containing the encrypted key and download URL.
    ///   - cipherKey:  64-byte effective cipher key used to unwrap the attachment key.
    /// - Returns: Decrypted plaintext file bytes.
    /// - Throws: `AttachmentError.downloadFailed` after one retry on 403.
    func download(cipherId: String, attachment: Attachment, cipherKey: Data) async throws -> Data

    /// Deletes an attachment from the given cipher.
    ///
    /// On success the in-memory vault cache is updated via `VaultRepository.updateAttachments`
    /// so the row disappears from the UI without a full re-sync.
    ///
    /// - Parameters:
    ///   - cipherId:     The ID of the vault item the attachment belongs to.
    ///   - attachmentId: The ID of the attachment to delete.
    func delete(cipherId: String, attachmentId: String) async throws
}

// MARK: - AttachmentError

/// Errors thrown by `AttachmentRepositoryImpl`.
nonisolated enum AttachmentError: Error, LocalizedError {
    /// The user's account does not have premium features enabled (HTTP 402).
    case premiumRequired
    /// The encrypted blob could not be downloaded after one retry.
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .premiumRequired:
            return "File attachments require a Bitwarden premium account."
        case .downloadFailed:
            return "Download failed. If this keeps happening, try locking and unlocking your vault."
        }
    }
}
