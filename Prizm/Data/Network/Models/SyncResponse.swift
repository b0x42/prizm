import Foundation

// MARK: - SyncResponse

/// Top-level response from the Bitwarden `/api/sync` endpoint.
///
/// Contains the encrypted user profile (including the `encUserKey` needed to unlock
/// the vault) and the list of encrypted ciphers.
///
/// Reference: Bitwarden Server API `/api/sync` response schema.
nonisolated struct SyncResponse: Codable {
    let profile: RawProfile
    let ciphers: [RawCipher]
    let folders: [RawFolder]
}

// MARK: - RawProfile

/// The authenticated user's profile data included in the sync response.
///
/// The `privateKey` and the `key` (encUserKey) are both EncStrings that
/// must be decrypted using the user's stretched master key before the vault can
/// be unlocked.
nonisolated struct RawProfile: Codable {
    let id:                  String
    let email:               String
    let name:                String?
    /// The user's symmetric vault key, encrypted under the stretched master key.
    /// EncString (Type-2: AES-256-CBC + HMAC-SHA256).
    let key:                 String
    /// The user's RSA-2048 private key, encrypted under the vault symmetric key.
    /// EncString (Type-2 or Type-4).
    /// Vaultwarden returns this as `"privateKey"` (camelCase) in the sync profile.
    let privateKey:          String?
    // Note: KDF params are NOT included in the Vaultwarden sync profile response.
    // They are obtained from the preLogin endpoint and stored in the Keychain at login time.
}
