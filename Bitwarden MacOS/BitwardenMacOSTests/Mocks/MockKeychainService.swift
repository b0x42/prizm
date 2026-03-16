import Foundation
@testable import Bitwarden_MacOS

/// Test double for `KeychainService`.
///
/// Uses an in-memory dictionary instead of the real macOS Keychain.
/// Records which keys were deleted so tests can assert on `signOut` cleanup.
final class MockKeychainService: KeychainService {

    // MARK: - In-memory store

    private var store: [String: String] = [:]

    // MARK: - Observation

    private(set) var deletedKeys: Set<String> = []
    private(set) var writtenKeys: [String]    = []

    // MARK: - KeychainService

    func read(key: String) throws -> String {
        guard let value = store[key] else {
            throw KeychainError.itemNotFound
        }
        return value
    }

    func write(key: String, value: String) throws {
        store[key] = value
        writtenKeys.append(key)
    }

    func delete(key: String) throws {
        deletedKeys.insert(key)
        store.removeValue(forKey: key)
    }

    // MARK: - Test helpers

    /// Pre-seeds a value for tests that need to read from Keychain without going through write.
    func seed(key: String, value: String) {
        store[key] = value
    }
}
