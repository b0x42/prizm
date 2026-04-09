import Foundation

// MARK: - UploadAttachmentUseCase

/// Encrypts and uploads a file as a new attachment to a vault cipher.
///
/// The cipher key is resolved internally via `VaultKeyService` — it is NEVER a
/// parameter on `execute(...)`. This keeps key material out of the Presentation layer
/// and enforces the encryption boundary at the Data layer (Constitution §II/§III).
///
/// Implemented by `UploadAttachmentUseCaseImpl` in the Data layer.
protocol UploadAttachmentUseCase: AnyObject {

    /// Uploads `data` as a new attachment named `fileName` to the given cipher.
    ///
    /// - Parameters:
    ///   - cipherId:  The vault item to attach the file to.
    ///   - fileName:  Plaintext file name.
    ///   - data:      Raw file bytes.
    /// - Returns: The newly created `Attachment` record (`isUploadIncomplete = false`).
    /// - Throws: `AttachmentError.premiumRequired` on HTTP 402.
    /// - Throws: `VaultError.vaultLocked` if the vault is locked.
    func execute(cipherId: String, fileName: String, data: Data) async throws -> Attachment
}
