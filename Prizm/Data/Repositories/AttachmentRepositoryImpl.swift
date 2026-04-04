import Foundation
import os.log

// MARK: - AttachmentRepositoryImpl

/// Concrete implementation of `AttachmentRepository`.
///
/// Handles the full upload/download/delete lifecycle for vault item attachments,
/// including two-layer encryption (attachment key + cipher key), the Bitwarden
/// two-step v2 upload flow, and in-memory vault cache patching.
///
/// - Security goal: all file bytes and key material are encrypted before leaving the
///   device. The attachment key (64 random bytes) encrypts the file blob. The cipher
///   key encrypts the attachment key. Both use AES-256-CBC + HMAC-SHA256
///   (EncString type-2 for key/metadata; binary IV‖ciphertext‖HMAC for the blob).
///
/// - Algorithm: Bitwarden two-layer attachment encryption per Security Whitepaper §4.
///   - Layer 1: `encryptData` — AES-256-CBC + HMAC-SHA256 over raw file bytes.
///   - Layer 2: `encryptAttachmentKey` — EncString type-2 wrapping the 64-byte attachment key.
///   - File name: `encryptFileName` — EncString type-2 wrapping the plaintext name.
///
/// - Key handling:
///   - The 64-byte `cipherKey: Data` parameter (encKey ‖ macKey) is split into
///     `CryptoKeys` at the Data layer boundary (encryptionKey = first 32 bytes,
///     macKey = last 32 bytes) before being passed to `PrizmCryptoService` methods.
///   - All key material is zeroed as soon as it is no longer needed.
///   - No key material appears in log output (Constitution §V).
///
/// - Deviations: none. The upload flow matches the Bitwarden reference client.
///
/// - What is NOT done: no key persistence beyond the current operation; the attachment
///   key exists only in memory for the duration of the upload/download call.
final class AttachmentRepositoryImpl: AttachmentRepository {

    private let apiClient:       any PrizmAPIClientProtocol
    private let crypto:          PrizmCryptoServiceImpl
    private let vaultRepository: any VaultRepository

    private let logger = Logger(subsystem: "com.prizm", category: "attachments")

    init(
        apiClient:       any PrizmAPIClientProtocol,
        crypto:          PrizmCryptoServiceImpl,
        vaultRepository: any VaultRepository
    ) {
        self.apiClient       = apiClient
        self.crypto          = crypto
        self.vaultRepository = vaultRepository
    }

    // MARK: - Upload

    /// Encrypts and uploads a file to the Bitwarden v2 attachment endpoint.
    ///
    /// Upload flow (Bitwarden Security Whitepaper §4, "Attachments"):
    /// 1. Generate a 64-byte random per-attachment key.
    /// 2. Encrypt the file name as an EncString using the cipher key.
    /// 3. Encrypt the file blob using the attachment key (binary layout: IV‖ciphertext‖HMAC).
    /// 4. Wrap the attachment key as an EncString using the cipher key.
    /// 5. POST metadata to `/api/ciphers/{id}/attachment/v2` to register the attachment.
    /// 6. Upload the encrypted blob:
    ///    - fileUploadType 0: POST multipart to `/api/ciphers/{id}/attachment/{attachmentId}`.
    ///    - fileUploadType 1: PUT to the Azure signed URL with `x-ms-blob-type: BlockBlob`.
    /// 7. Zero the attachment key and encrypted blob.
    /// 8. Update the in-memory vault cache via `VaultRepository.updateAttachments`.
    func upload(cipherId: String, fileName: String, data: Data, cipherKey: Data) async throws -> Attachment {
        logger.debug("upload: starting for cipher=\(cipherId, privacy: .public) size=\(data.count, privacy: .public)B")

        let keys = splitKey(cipherKey)

        // Step 1: Generate per-attachment key (64 random bytes, Constitution §III).
        var attachmentKey = try crypto.generateAttachmentKey()
        defer { attachmentKey.resetBytes(in: 0..<attachmentKey.count) }

        // Step 2: Encrypt file name.
        let encFileName = try crypto.encryptFileName(fileName, cipherKey: keys)

        // Step 3: Encrypt file blob.
        var encBlob = try crypto.encryptData(data, attachmentKey: attachmentKey)
        defer { encBlob.resetBytes(in: 0..<encBlob.count) }

        // Step 4: Wrap attachment key as EncString.
        let encKey = try crypto.encryptAttachmentKey(attachmentKey, cipherKey: keys)

        // Step 5: POST metadata to /v2 endpoint.
        let metaRequest = AttachmentMetadataRequest(
            fileName:     encFileName,
            key:          encKey,
            fileSize:     encBlob.count,
            adminRequest: false
        )
        let metaResponse: AttachmentMetadataResponse
        do {
            metaResponse = try await apiClient.createAttachmentMetadata(cipherId: cipherId, body: metaRequest)
        } catch APIError.httpError(statusCode: 402, _) {
            throw AttachmentError.premiumRequired
        }
        logger.info("upload: metadata registered attachmentId=\(metaResponse.attachmentId, privacy: .public) type=\(metaResponse.fileUploadType, privacy: .public)")

        // Step 6: Upload the encrypted blob.
        switch metaResponse.fileUploadType {
        case 0:
            // Bitwarden-hosted: POST multipart to API.
            try await apiClient.uploadAttachmentBitwardenHosted(
                cipherId:      cipherId,
                attachmentId:  metaResponse.attachmentId,
                encryptedBlob: encBlob
            )
        case 1:
            // Azure Blob Storage: PUT to signed URL with Azure-required header.
            guard let azureURL = URL(string: metaResponse.url) else {
                throw AttachmentError.downloadFailed
            }
            try await apiClient.uploadAttachmentAzure(signedURL: azureURL, encryptedBlob: encBlob)
        default:
            logger.fault("upload: unknown fileUploadType=\(metaResponse.fileUploadType, privacy: .public)")
            throw AttachmentError.downloadFailed
        }
        logger.info("upload: blob uploaded for attachmentId=\(metaResponse.attachmentId, privacy: .public)")

        // Construct the returned Attachment.
        // url = nil — the v2 response URL is the signed upload URL, not a download URL.
        // The permanent download URL is provided by the server on the next sync.
        // The download flow handles url = nil by fetching on demand.
        let sizeName = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        let newAttachment = Attachment(
            id:                 metaResponse.attachmentId,
            fileName:           fileName,
            encryptedKey:       encKey,
            size:               data.count,
            sizeName:           sizeName,
            url:                nil,
            isUploadIncomplete: false
        )

        // Step 8: Patch the in-memory vault cache.
        let currentList = (try? vaultRepository.allItems().first { $0.id == cipherId })?.attachments ?? []
        await vaultRepository.updateAttachments(currentList + [newAttachment], for: cipherId)

        return newAttachment
    }

    // MARK: - Download

    /// Downloads and decrypts the file blob for the given attachment.
    ///
    /// Download flow:
    /// 1. Obtain a download URL: use `Attachment.url` if non-nil; otherwise fetch a fresh URL
    ///    via `GET /api/ciphers/{id}/attachment/{attachmentId}`.
    /// 2. Fetch the encrypted blob from the URL.
    /// 3. On HTTP 403 (stale signed URL): discard URL, re-fetch, retry blob download once.
    ///    If the retry also fails, throw `AttachmentError.downloadFailed`.
    /// 4. Decrypt the blob: unwrap the attachment key (EncString → 64 bytes) using the
    ///    cipher key, then decrypt the blob (binary IV‖ciphertext‖HMAC) using the attachment key.
    /// 5. Zero key and blob buffers.
    func download(cipherId: String, attachment: Attachment, cipherKey: Data) async throws -> Data {
        logger.debug("download: starting for cipher=\(cipherId, privacy: .public) attachment=\(attachment.id, privacy: .public)")

        let keys = splitKey(cipherKey)

        // Resolve initial download URL.
        var downloadURL: URL
        if let urlStr = attachment.url, let url = URL(string: urlStr) {
            downloadURL = url
        } else {
            downloadURL = try await fetchFreshDownloadURL(cipherId: cipherId, attachmentId: attachment.id)
        }

        // Fetch the encrypted blob (with one retry on 403).
        var encBlob: Data
        do {
            encBlob = try await fetchBlob(from: downloadURL)
        } catch let err as APIError where statusCode(of: err) == 403 {
            logger.info("download: 403 on first attempt — fetching fresh URL for \(attachment.id, privacy: .public)")
            downloadURL = try await fetchFreshDownloadURL(cipherId: cipherId, attachmentId: attachment.id)
            do {
                encBlob = try await fetchBlob(from: downloadURL)
            } catch {
                logger.error("download: retry failed for \(attachment.id, privacy: .public)")
                throw AttachmentError.downloadFailed
            }
        }
        defer { encBlob.resetBytes(in: 0..<encBlob.count) }

        // Decrypt the attachment key (EncString → raw 64 bytes).
        var attachmentKey = try crypto.decryptAttachmentKey(attachment.encryptedKey, cipherKey: keys)
        defer { attachmentKey.resetBytes(in: 0..<attachmentKey.count) }

        // Decrypt the blob.
        let plaintext = try crypto.decryptData(encBlob, attachmentKey: attachmentKey)
        logger.info("download: decrypted \(plaintext.count, privacy: .public) bytes for \(attachment.id, privacy: .public)")
        return plaintext
    }

    // MARK: - Delete

    /// Deletes the attachment from the server and patches the in-memory vault cache.
    func delete(cipherId: String, attachmentId: String) async throws {
        logger.debug("delete: cipher=\(cipherId, privacy: .public) attachment=\(attachmentId, privacy: .public)")
        try await apiClient.deleteAttachment(cipherId: cipherId, attachmentId: attachmentId)
        let currentList = (try? vaultRepository.allItems().first { $0.id == cipherId })?.attachments ?? []
        let updatedList = currentList.filter { $0.id != attachmentId }
        await vaultRepository.updateAttachments(updatedList, for: cipherId)
        logger.info("delete: removed \(attachmentId, privacy: .public) from cache")
    }

    // MARK: - Private helpers

    /// Splits a 64-byte raw cipher key into `CryptoKeys`.
    ///
    /// - Security goal: `CryptoKeys` is required by `PrizmCryptoService` methods;
    ///   the raw Data passed through the domain boundary is split here at the Data layer.
    private func splitKey(_ raw: Data) -> CryptoKeys {
        CryptoKeys(
            encryptionKey: raw[raw.startIndex..<raw.startIndex.advanced(by: 32)],
            macKey:        raw[raw.startIndex.advanced(by: 32)..<raw.startIndex.advanced(by: 64)]
        )
    }

    /// Fetches a fresh signed download URL for the given attachment.
    private func fetchFreshDownloadURL(cipherId: String, attachmentId: String) async throws -> URL {
        let response = try await apiClient.fetchAttachmentDownloadURL(
            cipherId:     cipherId,
            attachmentId: attachmentId
        )
        guard let url = URL(string: response.url) else {
            throw AttachmentError.downloadFailed
        }
        return url
    }

    /// Downloads the raw bytes from a signed URL.
    private func fetchBlob(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw AttachmentError.downloadFailed
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, body: "")
        }
        return data
    }

    /// Extracts the status code from an `APIError.httpError`, or nil for other error types.
    private func statusCode(of error: APIError) -> Int? {
        if case .httpError(let code, _) = error { return code }
        return nil
    }
}
