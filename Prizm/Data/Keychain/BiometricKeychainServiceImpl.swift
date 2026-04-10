import Foundation
import Security
import LocalAuthentication
import os.log

/// Concrete Keychain implementation for biometric-gated secrets.
///
/// Items are stored as generic passwords (`kSecClassGenericPassword`) protected by
/// `SecAccessControl` with `.biometryCurrentSet`. This means:
/// - Reading requires a successful biometric evaluation (Touch ID / Face ID).
/// - The item is invalidated if the user adds or removes a fingerprint.
///
/// Uses `kSecUseDataProtectionKeychain: true` so the access group is inferred from
/// the `keychain-access-groups` entitlement (`$(AppIdentifierPrefix)com.prizm`),
/// ensuring the item is not accessible to other apps or processes
/// (Constitution Security Requirement property 3).
///
/// `kSecAttrSynchronizable` is never set — the item is device-only, never backed up
/// or synced to iCloud (Constitution Security Requirement property 1).
///
/// Standards: design Decision 2 (`.biometryCurrentSet`), Decision 3 (separate service).
final class BiometricKeychainServiceImpl: BiometricKeychainService {

    private let service = "com.prizm.biometric"
    private let logger = Logger(subsystem: "com.prizm", category: "BiometricKeychain")
    private let useDataProtectionKeychain: Bool

    init(useDataProtectionKeychain: Bool = true) {
        self.useDataProtectionKeychain = useDataProtectionKeychain
    }

    // MARK: - Base query

    private func baseQuery(for key: String) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain] = true
        }
        return query
    }

    /// Creates the `SecAccessControl` for `.biometryCurrentSet`.
    ///
    /// `.biometryCurrentSet` invalidates the item when biometric enrollment changes,
    /// preventing a newly added fingerprint from silently accessing the vault key
    /// (design Decision 2).
    private func makeBiometricAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            let cfError = error?.takeRetainedValue()
            logger.error("SecAccessControl creation failed: \(String(describing: cfError), privacy: .public)")
            throw KeychainError.unexpectedStatus(errSecParam)
        }
        return access
    }

    // MARK: - Write

    func writeBiometric(data: Data, key: String) throws {
        var query = baseQuery(for: key)
        if useDataProtectionKeychain {
            query[kSecAttrAccessControl] = try makeBiometricAccessControl()
        }
        query[kSecValueData] = data

        let addStatus = SecItemAdd(query as CFDictionary, nil)

        if addStatus == errSecSuccess {
            logger.debug("Biometric keychain write: \(key, privacy: .public)")
            return
        }

        if addStatus == errSecDuplicateItem {
            // Delete + re-add because SecItemUpdate cannot change access control flags.
            try deleteBiometric(key: key)
            let retryStatus = SecItemAdd(query as CFDictionary, nil)
            guard retryStatus == errSecSuccess else {
                logger.error("Biometric keychain retry write failed: status \(retryStatus)")
                throw KeychainError.unexpectedStatus(retryStatus)
            }
            logger.debug("Biometric keychain write (replaced): \(key, privacy: .public)")
            return
        }

        logger.error("Biometric keychain write failed: status \(addStatus)")
        throw KeychainError.unexpectedStatus(addStatus)
    }

    // MARK: - Read

    func readBiometric(key: String) throws -> Data {
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
            logger.error("Biometric keychain read failed: status \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Delete

    func deleteBiometric(key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            logger.debug("Biometric keychain delete: \(key, privacy: .public)")
            return
        default:
            logger.error("Biometric keychain delete failed: status \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
