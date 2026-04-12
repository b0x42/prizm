import XCTest
@testable import Prizm

/// Tests for `BiometricKeychainServiceImpl`.
///
/// Biometric Keychain operations require `.biometryCurrentSet` access control,
/// which cannot be exercised in CI (no enrolled biometrics). These tests use
/// `useDataProtectionKeychain: false` to exercise the SecItem code paths without
/// the biometric gate — the access control flag is tested manually (task 10.4).
@MainActor
final class BiometricKeychainServiceTests: XCTestCase {

    private var sut: BiometricKeychainServiceImpl!
    private let testKey = "bw.macos.test:biometricKey"

    override func setUp() async throws {
        try await super.setUp()
        sut = BiometricKeychainServiceImpl(useDataProtectionKeychain: false)
        try? sut.deleteBiometric(key: testKey)
    }

    override func tearDown() async throws {
        try? sut.deleteBiometric(key: testKey)
        try await super.tearDown()
    }

    // MARK: - Write + Read

    func testWriteAndReadRoundTrip() async throws {
        let data = Data(repeating: 0xAB, count: 64)
        try sut.writeBiometric(data: data, key: testKey)
        let result = try await sut.readBiometric(key: testKey)
        XCTAssertEqual(result, data)
    }

    func testOverwriteReplacesValue() async throws {
        let first = Data(repeating: 0x01, count: 64)
        let second = Data(repeating: 0x02, count: 64)
        try sut.writeBiometric(data: first, key: testKey)
        try sut.writeBiometric(data: second, key: testKey)
        let result = try await sut.readBiometric(key: testKey)
        XCTAssertEqual(result, second)
    }

    // MARK: - Delete

    func testDeleteRemovesItem() async throws {
        try sut.writeBiometric(data: Data(count: 64), key: testKey)
        try sut.deleteBiometric(key: testKey)
        do {
            _ = try await sut.readBiometric(key: testKey)
            XCTFail("Expected itemNotFound")
        } catch {
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }

    func testDeleteNonExistentItemDoesNotThrow() {
        XCTAssertNoThrow(try sut.deleteBiometric(key: "bw.macos.test:nonexistent"))
    }

    // MARK: - Not found

    func testReadMissingKeyThrowsNotFound() async {
        do {
            _ = try await sut.readBiometric(key: "bw.macos.test:missing")
            XCTFail("Expected itemNotFound")
        } catch {
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }
}
