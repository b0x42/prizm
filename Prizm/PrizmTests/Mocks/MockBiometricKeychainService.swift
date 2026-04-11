import Foundation
@testable import Prizm

final class MockBiometricKeychainService: BiometricKeychainService {
    private var store: [String: Data] = [:]
    var readError: Error?
    var writeError: Error?

    func writeBiometric(data: Data, key: String) throws {
        if let err = writeError { throw err }
        store[key] = data
    }

    func readBiometric(key: String) async throws -> Data {
        if let err = readError { throw err }
        guard let data = store[key] else { throw KeychainError.itemNotFound }
        return data
    }

    func deleteBiometric(key: String) throws {
        store.removeValue(forKey: key)
    }
}
