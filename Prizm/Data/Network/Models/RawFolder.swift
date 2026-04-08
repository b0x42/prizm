import Foundation

// MARK: - RawFolder

/// Wire-format model for a folder returned by the Bitwarden `/sync` API endpoint.
///
/// The `name` field is an EncString (type-2: AES-256-CBC + HMAC-SHA256) that must be
/// decrypted using the user's vault symmetric key before display.
///
/// Reference: Bitwarden Server API `/api/sync` response body, `Folders[]` array;
/// Bitwarden Server API `/api/folders` CRUD endpoints.
nonisolated struct RawFolder: Codable {
    let id:           String
    let name:         String   // EncString
    let revisionDate: String?  // ISO-8601 UTC
}
