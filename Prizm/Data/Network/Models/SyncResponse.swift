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
    /// Organizations the user belongs to. Defaults to `[]` when absent (Vaultwarden
    /// instances without org support do not include this key).
    let organizations: [RawOrganization]
    /// Collections across all organizations. Defaults to `[]` when absent.
    let collections: [RawCollection]

    init(profile: RawProfile, ciphers: [RawCipher], folders: [RawFolder] = [],
         organizations: [RawOrganization] = [], collections: [RawCollection] = []) {
        self.profile = profile
        self.ciphers = ciphers
        self.folders = folders
        self.organizations = organizations
        self.collections = collections
    }

    init(from decoder: Decoder) throws {
        // Vaultwarden API uses camelCase; some versions / the official Bitwarden server
        // use PascalCase. Try camelCase first, fall back to PascalCase for each key.
        let container = try decoder.container(keyedBy: FlexKeys.self)
        profile = try (try? container.decode(RawProfile.self,  forKey: FlexKeys("profile")))
               ?? container.decode(RawProfile.self,  forKey: FlexKeys("Profile"))
        ciphers = try (try? container.decode([RawCipher].self, forKey: FlexKeys("ciphers")))
               ?? container.decode([RawCipher].self, forKey: FlexKeys("Ciphers"))
        folders = (try? container.decode([RawFolder].self, forKey: FlexKeys("folders")))
               ?? (try? container.decode([RawFolder].self, forKey: FlexKeys("Folders")))
               ?? []
        organizations = (try? container.decode([RawOrganization].self, forKey: FlexKeys("organizations")))
               ?? (try? container.decode([RawOrganization].self, forKey: FlexKeys("Organizations")))
               ?? []
        collections = (try? container.decode([RawCollection].self, forKey: FlexKeys("collections")))
               ?? (try? container.decode([RawCollection].self, forKey: FlexKeys("Collections")))
               ?? []
    }

    /// Ad-hoc `CodingKey` that accepts any string key, used to try multiple casing variants.
    private struct FlexKeys: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}

// MARK: - RawOrganization

/// Wire-format model for a Bitwarden organization returned in the sync response.
///
/// `key` is the organization's symmetric key (64 bytes), RSA-OAEP-SHA1 encrypted with
/// the user's RSA-2048 public key. Unwrapped at sync time into `OrgKeyCache`.
/// Reference: Bitwarden Security Whitepaper §4 — "Organization Key Wrapping".
nonisolated struct RawOrganization: Codable, Equatable {
    let id:   String
    let name: String
    /// RSA-encrypted organization symmetric key (EncString, Type-4).
    let key:  String
    /// Membership role integer: 0=Owner, 1=Admin, 2=Manager, 3=User, 4=Custom.
    let type: Int
}

// MARK: - RawCollection

/// Wire-format model for a Bitwarden collection returned in the sync response.
///
/// `name` is an EncString encrypted with the organization's symmetric key.
/// Decrypted at sync time using the unwrapped org key from `OrgKeyCache`.
nonisolated struct RawCollection: Codable, Equatable {
    let id:             String
    let organizationId: String
    let name:           String  // EncString, encrypted with org key
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
    /// Vaultwarden returns this as `"privateKey"` (camelCase) in the sync profile;
    /// the official Bitwarden server uses `"PrivateKey"` (PascalCase). Both are handled.
    let privateKey:          String?
    // Note: KDF params are NOT included in the Vaultwarden sync profile response.
    // They are obtained from the preLogin endpoint and stored in the Keychain at login time.

    /// Custom decoding to handle both Bitwarden server (PascalCase) and Vaultwarden (camelCase)
    /// field naming within the Profile object.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FlexProfileKeys.self)
        id         = try (try? c.decode(String.self,  forKey: .id))  ?? c.decode(String.self,  forKey: .idUpper)
        email      = try (try? c.decode(String.self,  forKey: .email)) ?? c.decode(String.self, forKey: .emailUpper)
        name       = try? (try? c.decode(String.self, forKey: .name)) ?? c.decode(String.self, forKey: .nameUpper)
        key        = try (try? c.decode(String.self,  forKey: .key))  ?? c.decode(String.self,  forKey: .keyUpper)
        privateKey = (try? c.decode(String.self, forKey: .privateKey))
                  ?? (try? c.decode(String.self, forKey: .privateKeyUpper))
    }

    init(id: String, email: String, name: String?, key: String, privateKey: String?) {
        self.id         = id
        self.email      = email
        self.name       = name
        self.key        = key
        self.privateKey = privateKey
    }

    private enum FlexProfileKeys: String, CodingKey {
        case id = "id", idUpper = "Id"
        case email = "email", emailUpper = "Email"
        case name = "name", nameUpper = "Name"
        case key = "key", keyUpper = "Key"
        case privateKey = "privateKey", privateKeyUpper = "PrivateKey"
    }
}
