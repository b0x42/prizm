import Foundation
@testable import Bitwarden_MacOS

/// Test double for `KeychainService`.
///
/// Uses an in-memory dictionary instead of the real macOS Keychain.
/// Records which keys were deleted so tests can assert on `signOut` cleanup.
final class MockKeychainService: KeychainService {

    // MARK: - In-memory store

    private var store: [String: Data] = [:]

    // MARK: - Observation

    private(set) var deletedKeys: Set<String> = []
    private(set) var writtenKeys: [String]    = []

    // MARK: - KeychainService

    func read(key: String) throws -> Data {
        guard let value = store[key] else {
            throw KeychainError.itemNotFound
        }
        return value
    }

    func write(data: Data, key: String) throws {
        store[key] = data
        writtenKeys.append(key)
    }

    func delete(key: String) throws {
        deletedKeys.insert(key)
        store.removeValue(forKey: key)
    }

    // MARK: - Test helpers

    /// Pre-seeds a value for tests that need to read from Keychain without going through write.
    func seed(key: String, value: String) {
        store[key] = value.data(using: .utf8)!
    }

    /// Pre-seeds raw Data for tests.
    func seed(key: String, data: Data) {
        store[key] = data
    }
}
