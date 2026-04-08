import Foundation

// MARK: - SyncResponse

/// Top-level response from the Bitwarden `/api/sync` endpoint.
///
/// Contains the encrypted user profile (including the `encUserKey` needed to unlock
/// the vault) and the list of encrypted ciphers.
///
/// Reference: Bitwarden Server API `/api/sync` response schema.
nonisolated struct SyncResponse: Decodable {
    let profile: RawProfile
    let ciphers: [RawCipher]
    /// Decoded with a default of `[]` so that Vaultwarden instances that omit the key
    /// (or future API variants) don't cause the entire sync decode to throw.
    let folders: [RawFolder]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(RawProfile.self, forKey: .profile)
        ciphers = try container.decode([RawCipher].self, forKey: .ciphers)
        folders = (try? container.decode([RawFolder].self, forKey: .folders)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case profile, ciphers, folders
    }
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
