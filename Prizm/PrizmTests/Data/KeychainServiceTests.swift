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
        sut = KeychainServiceImpl(useDataProtectionKeychain: false)
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

    // MARK: - Entitlement probe (#60)

    /// Regression test for the unsigned-build fallback (#60): an instance created with
    /// the auto-probe must be able to complete a write immediately after init — this is
    /// the operation that gates sign-in (device identifier storage).
    ///
    /// On runners without the `keychain-access-groups` entitlement (CI, Homebrew,
    /// teamless local builds) the probe must select the legacy login keychain; on
    /// entitled builds the data protection keychain is used directly. Either way the
    /// write must succeed. A read-based probe fails this test on unsigned runners:
    /// as of macOS 26.5 `SecItemCopyMatching` returns `errSecItemNotFound` without
    /// the entitlement, while `SecItemAdd` still fails with -34018.
    func testProbedInitCanWriteRegardlessOfEntitlement() throws {
        let probed = KeychainServiceImpl()
        let key = "bw.macos.test:probed-write"
        defer { try? probed.delete(key: key) }

        try probed.write(data: Data("probe".utf8), key: key)
        XCTAssertEqual(try probed.read(key: key), Data("probe".utf8))
    }
}
