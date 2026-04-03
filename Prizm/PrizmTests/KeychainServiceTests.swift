import XCTest
@testable import Prizm

/// Tests for KeychainServiceImpl exercising the real macOS Keychain (integration-level).
///
/// These tests hit the actual Keychain, which makes them the authoritative verification
/// that `kSecUseDataProtectionKeychain` is wired correctly — unit tests using
/// MockKeychainService cannot exercise real Security.framework attributes.
@MainActor
final class KeychainServiceTests: XCTestCase {

    private var sut: KeychainService!
    private let testKey = "bw.macos.test:key"

    override func setUp() async throws {
        try await super.setUp()
        sut = KeychainServiceImpl()
        // Clean up any leftover test data
        try? sut.delete(key: testKey)
    }

    override func tearDown() async throws {
        try? sut.delete(key: testKey)
        try await super.tearDown()
    }

    // MARK: - Write + Read

    func testWriteAndReadRoundTrip() throws {
        let data = Data("hello keychain".utf8)
        try sut.write(data: data, key: testKey)
        let result = try sut.read(key: testKey)
        XCTAssertEqual(result, data)
    }

    func testOverwriteReplacesValue() throws {
        try sut.write(data: Data("first".utf8), key: testKey)
        try sut.write(data: Data("second".utf8), key: testKey)
        let result = try sut.read(key: testKey)
        XCTAssertEqual(result, Data("second".utf8))
    }

    // MARK: - Delete

    func testDeleteRemovesItem() throws {
        try sut.write(data: Data("value".utf8), key: testKey)
        try sut.delete(key: testKey)
        XCTAssertThrowsError(try sut.read(key: testKey)) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }

    func testDeleteNonExistentItemDoesNotThrow() {
        XCTAssertNoThrow(try sut.delete(key: "bw.macos.test:nonexistent"))
    }

    // MARK: - Not found

    func testReadMissingKeyThrowsNotFound() {
        XCTAssertThrowsError(try sut.read(key: "bw.macos.test:missing")) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }
}
