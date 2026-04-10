import XCTest
@testable import Prizm

final class CryptoKeysSerializationTests: XCTestCase {

    func testRoundTrip() {
        let encKey = Data((0..<32).map { UInt8($0) })
        let macKey = Data((32..<64).map { UInt8($0) })
        let keys = CryptoKeys(encryptionKey: encKey, macKey: macKey)

        let data = keys.toData()
        XCTAssertEqual(data.count, 64)

        let decoded = CryptoKeys(data: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.encryptionKey, encKey)
        XCTAssertEqual(decoded?.macKey, macKey)
    }

    func testToDataConcatenatesKeysInOrder() {
        let encKey = Data(repeating: 0xAA, count: 32)
        let macKey = Data(repeating: 0xBB, count: 32)
        let data = CryptoKeys(encryptionKey: encKey, macKey: macKey).toData()
        XCTAssertEqual(data.prefix(32), encKey)
        XCTAssertEqual(data.suffix(32), macKey)
    }

    func testInitFromDataFailsOnWrongLength() {
        XCTAssertNil(CryptoKeys(data: Data(count: 32)))
        XCTAssertNil(CryptoKeys(data: Data(count: 63)))
        XCTAssertNil(CryptoKeys(data: Data()))
    }
}
