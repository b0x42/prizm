import Foundation
import Security
import os.log

// MARK: - Errors

/// Errors that can be thrown by KeychainService operations.
nonisolated enum KeychainError: Error, Equatable {
    /// No item exists for the requested key.
    case itemNotFound
    /// The Keychain returned an unexpected status code.
    case unexpectedStatus(OSStatus)
    /// Keychain returned data in an unexpected format.
    case invalidData
}

// MARK: - Protocol

/// Provides read, write, and delete access to the macOS Keychain.
///
/// Keys are stored as generic passwords (`kSecClassGenericPassword`) scoped to the
/// `com.bitwarden-macos` service, accessible only when the device is unlocked and
/// not backed up to iCloud (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
///
/// All operations are synchronous and throw `KeychainError` on failure.
protocol KeychainService {
    /// Write `data` for `key`, replacing any existing value.
    func write(data: Data, key: String) throws
    /// Read and return the data stored for `key`.
    /// - Throws: `KeychainError.itemNotFound` if no item exists.
    func read(key: String) throws -> Data
    /// Delete the item for `key`.  No-ops silently when the item does not exist.
    func delete(key: String) throws
}

// MARK: - Implementation

/// Concrete Keychain implementation using Security.framework SecItem APIs.
///
/// Each item is stored as a generic password (`kSecClassGenericPassword`) with:
/// - `kSecAttrService`: `"com.bitwarden-macos"` — scopes items to this app.
/// - `kSecAttrAccount`: the caller-provided `key` — allows multiple distinct items.
/// - `kSecAttrAccessible`: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — secrets
///   are available only while the device is unlocked and are not migrated to new
///   devices or iCloud backups (per Bitwarden Security Whitepaper §5: Keychain Storage).
final class KeychainServiceImpl: KeychainService {

    private let service = "com.bitwarden-macos"
    private let logger = Logger(subsystem: "com.bitwarden-macos", category: "KeychainService")

    /// Returns the base Keychain query dictionary for `key`.
    ///
    /// `kSecUseDataProtectionKeychain: true` opts into the modern data-protection
    /// keychain used by sandboxed apps.  Without this flag, each item in the legacy
    /// login keychain can trigger a separate "allow access" prompt per item per launch.
    /// With it, macOS ties access to the app's sandbox entitlement and no prompts appear.
    private func baseQuery(for key: String) -> [CFString: Any] {
        [
            kSecClass:                    kSecClassGenericPassword,
            kSecAttrService:              service,
            kSecAttrAccount:              key,
            kSecUseDataProtectionKeychain: true,
        ]
    }

    // MARK: Write

    /// Writes `data` for `key` using SecItemAdd, or updates an existing item with SecItemUpdate.
    ///
    /// Uses an upsert pattern: attempt to add first; if `errSecDuplicateItem` is returned,
    /// update the existing item.  This avoids a read-before-write and is the recommended
    /// pattern per Apple's "Storing Keys in the Keychain" technical note.
    func write(data: Data, key: String) throws {
        var query = baseQuery(for: key)
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecValueData]      = data

        let addStatus = SecItemAdd(query as CFDictionary, nil)

        if addStatus == errSecSuccess {
            logger.debug("Keychain write: \(key, privacy: .public)")
            return
        }

        if addStatus == errSecDuplicateItem {
            let updateAttributes: [CFString: Any] = [
                kSecValueData:      data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]
            let updateStatus = SecItemUpdate(
                baseQuery(for: key) as CFDictionary,
                updateAttributes as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                logger.error("Keychain error: status \(updateStatus)")
                throw KeychainError.unexpectedStatus(updateStatus)
            }
            logger.debug("Keychain write: \(key, privacy: .public)")
            return
        }

        logger.error("Keychain error: status \(addStatus)")
        throw KeychainError.unexpectedStatus(addStatus)
    }

    // MARK: Read

    /// Reads and returns the stored data for `key`.
    ///
    /// `kSecMatchLimit: kSecMatchLimitOne` ensures only the first matching item is
    /// returned.  `kSecReturnData: true` requests the raw data blob.
    func read(key: String) throws -> Data {
        var query = baseQuery(for: key)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            logger.error("Keychain error: status \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: Delete

    /// Deletes the item for `key`.  If the item does not exist (`errSecItemNotFound`),
    /// this method returns silently — callers do not need to check existence first.
    func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            logger.debug("Keychain delete: \(key, privacy: .public)")
            return
        default:
            logger.error("Keychain error: status \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
