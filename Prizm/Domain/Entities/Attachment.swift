import Foundation

// MARK: - Attachment

/// A decrypted file attachment record belonging to a vault cipher.
///
/// Produced by `AttachmentMapper` from an `AttachmentDTO`. The `fileName` field
/// is plaintext (decrypted from the EncString in the sync payload). The
/// `encryptedKey` is the per-attachment key wrapped as a type-2 EncString;
/// it is preserved verbatim and decrypted on demand when a file operation
/// (upload, download) is required.
///
/// Value type — safe to pass across layers without defensive copying.
nonisolated struct Attachment: Identifiable, Equatable, Hashable {
    /// Server-assigned attachment ID.
    let id: String
    /// Plaintext file name (decrypted from EncString at sync time).
    let fileName: String
    /// Per-attachment key wrapped as a type-2 EncString — NOT decrypted at
    /// rest in the domain entity. Decrypted on demand inside `AttachmentRepositoryImpl`
    /// when a download or upload operation is performed.
    let encryptedKey: String
    /// File size in bytes, parsed from the server's `size` string field.
    let size: Int
    /// Human-readable file size string supplied by the server (e.g. "1.2 MB").
    /// Stored verbatim; not reformatted by the client to match what the server computed.
    let sizeName: String
    /// Signed download URL. Non-nil when the server has provided a URL in the sync
    /// payload. May be nil immediately after a successful upload (before the next sync),
    /// or when the server omits the URL. The download flow fetches a fresh URL on demand
    /// when this is nil or when the existing URL returns HTTP 403.
    let url: String?
    /// True when the attachment metadata was created on the server but the file blob
    /// was not successfully uploaded. An incomplete attachment shows a "Retry Upload"
    /// UI instead of the normal Open / Save to Disk actions.
    ///
    /// Derived at sync time from whether the server returned a `url`:
    /// a missing URL indicates the blob was never received.
    let isUploadIncomplete: Bool
}
