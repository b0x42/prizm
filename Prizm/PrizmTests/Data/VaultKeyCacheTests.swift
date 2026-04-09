import XCTest
@testable import Prizm

/// Tests for `VaultKeyCache` actor — populate/lookup/clear lifecycle.
final class VaultKeyCacheTests: XCTestCase {

    private var sut: VaultKeyCache!

    override func setUp() async throws {
        sut = VaultKeyCache()
    }

    func test_populate_thenLookup_returnsKey() async {
        let key = Data(repeating: 0xAB, count: 64)
        await sut.populate(keys: ["cipher-1": key])
        let result = await sut.key(for: "cipher-1")
        XCTAssertEqual(result, key)
    }

    func test_lookup_unknownCipherId_returnsNil() async {
        await sut.populate(keys: ["cipher-1": Data(count: 64)])
        let result = await sut.key(for: "cipher-999")
        XCTAssertNil(result)
    }

    func test_clear_makesAllLookupsReturnNil() async {
        await sut.populate(keys: [
            "cipher-1": Data(repeating: 0x01, count: 64),
            "cipher-2": Data(repeating: 0x02, count: 64)
        ])
        await sut.clear()
        let r1 = await sut.key(for: "cipher-1")
        let r2 = await sut.key(for: "cipher-2")
        XCTAssertNil(r1)
        XCTAssertNil(r2)
    }

    func test_populate_replacesExistingEntries() async {
        let oldKey = Data(repeating: 0x01, count: 64)
        let newKey = Data(repeating: 0x02, count: 64)
        await sut.populate(keys: ["cipher-1": oldKey])
        await sut.populate(keys: ["cipher-1": newKey])
        let result = await sut.key(for: "cipher-1")
        XCTAssertEqual(result, newKey)
    }

    func test_populate_emptyClearsExistingEntries() async {
        await sut.populate(keys: ["cipher-1": Data(count: 64)])
        await sut.populate(keys: [:])
        let result = await sut.key(for: "cipher-1")
        XCTAssertNil(result)
    }
}
