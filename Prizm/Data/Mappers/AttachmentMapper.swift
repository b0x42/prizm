import Foundation
import os.log

// MARK: - AttachmentMapperError

/// Errors thrown by `AttachmentMapper.map(_:cipherKey:)`.
nonisolated enum AttachmentMapperError: Error, Equatable {
    /// The `size` field could not be parsed to an integer.
    case invalidSize(String)
    /// The `fileName` EncString could not be decrypted.
    case fileNameDecryptionFailed
}

// MARK: - AttachmentMapper

/// Maps an `AttachmentDTO` (wire format, partially encrypted) to an `Attachment`
/// (domain, decrypted) using the cipher's effective `CryptoKeys`.
///
/// **Security goal**: only `fileName` is decrypted here — `key` (the per-attachment
/// symmetric key) is preserved as an EncString and decrypted on demand inside
/// `AttachmentRepositoryImpl` when a file operation is performed. This minimises the
/// window during which attachment key material lives in memory.
///
/// **Algorithm**: EncString type-2 (AES-256-CBC + HMAC-SHA256), per the Bitwarden
/// Security Whitepaper §4. The `cipherKey` provides both the AES encryption key and
/// the HMAC-SHA256 MAC key via the `CryptoKeys.encryptionKey` and `CryptoKeys.macKey`
/// fields respectively.
///
/// **Deviations**: none. The decryption algorithm and key usage match the Bitwarden
/// reference implementation.
nonisolated final class AttachmentMapper {

    private static let logger = Logger(subsystem: "com.prizm", category: "attachments")

    /// Maps an `AttachmentDTO` to a domain `Attachment`.
    ///
    /// - Parameters:
    ///   - dto:       Wire-format attachment record from the sync response.
    ///   - cipherKey: The cipher's effective `CryptoKeys`. Provided by `CipherMapper`
    ///                which already holds `CryptoKeys` at call time — avoids re-splitting
    ///                a 64-byte Data blob unnecessarily.
    /// - Returns: A decrypted `Attachment` ready for use in the domain layer.
    /// - Throws: `AttachmentMapperError.fileNameDecryptionFailed` if fileName cannot be decrypted.
    /// - Throws: `AttachmentMapperError.invalidSize` if the `size` string is not a valid integer.
    func map(_ dto: AttachmentDTO, cipherKey: CryptoKeys) throws -> Attachment {
        // Decrypt the file name (EncString → plaintext).
        // The attachment key (dto.key) is NOT decrypted here — it is preserved verbatim
        // as encryptedKey and decrypted on demand during download (Constitution §III).
        let plainFileName: String
        do {
            let enc  = try EncString(string: dto.fileName)
            let data = try enc.decrypt(keys: cipherKey)
            guard let str = String(data: data, encoding: .utf8) else {
                throw AttachmentMapperError.fileNameDecryptionFailed
            }
            plainFileName = str
        } catch let e as AttachmentMapperError {
            throw e
        } catch {
            Self.logger.error("Attachment fileName decryption failed: \(error, privacy: .public)")
            throw AttachmentMapperError.fileNameDecryptionFailed
        }

        // Parse size string → Int. Non-numeric values are a server-side data error.
        guard let sizeInt = Int(dto.size) else {
            Self.logger.error("Attachment size field is non-numeric: '\(dto.size, privacy: .public)'")
            throw AttachmentMapperError.invalidSize(dto.size)
        }

        return Attachment(
            id:                 dto.id,
            fileName:           plainFileName,
            encryptedKey:       dto.key,       // verbatim — not decrypted here
            size:               sizeInt,
            sizeName:           dto.sizeName,  // verbatim — not reformatted
            url:                dto.url,        // verbatim — may be nil
            isUploadIncomplete: dto.url == nil  // nil url → blob never received
        )
    }
}
