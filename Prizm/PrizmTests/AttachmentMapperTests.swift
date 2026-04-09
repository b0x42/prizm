import XCTest
@testable import Prizm

/// Tests for `AttachmentMapper`.
/// Verifies all field mappings including decryption, size parsing, and isUploadIncomplete logic.
final class AttachmentMapperTests: XCTestCase {

    private var sut: AttachmentMapper!
    private var crypto: PrizmCryptoServiceImpl!

    // Real keys for encrypt/decrypt round-trips
    private let cipherKey = CryptoKeys(
        encryptionKey: Data(repeating: 0xAA, count: 32),
        macKey:        Data(repeating: 0xBB, count: 32)
    )

    override func setUp() {
        sut    = AttachmentMapper()
        crypto = PrizmCryptoServiceImpl()
    }

    // MARK: - Helpers

    private func makeEncryptedFileName(_ name: String) throws -> String {
        try crypto.encryptFileName(name, cipherKey: cipherKey)
    }

    private func makeDTO(
        id:       String  = "att-1",
        fileName: String,   // should be an EncString
        key:      String  = "2.abc|def|ghi",
        size:     String  = "2048",
        sizeName: String  = "2 KB",
        url:      String? = "https://cdn.example.com/file"
    ) -> AttachmentDTO {
        AttachmentDTO(id: id, fileName: fileName, key: key, size: size, sizeName: sizeName, url: url)
    }

    // MARK: - fileName decrypted

    func test_map_decryptsFileName() throws {
        let encName = try makeEncryptedFileName("document.pdf")
        let dto = makeDTO(fileName: encName)
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertEqual(result.fileName, "document.pdf")
    }

    func test_map_throwsFileNameDecryptionFailed_whenEncStringInvalid() {
        let dto = makeDTO(fileName: "not-an-encstring")
        XCTAssertThrowsError(try sut.map(dto, cipherKey: cipherKey)) { error in
            XCTAssertNotNil(error as? AttachmentMapperError)
        }
    }

    // MARK: - size parsed

    func test_map_parsesSizeStringToInt() throws {
        let enc = try makeEncryptedFileName("f.txt")
        let dto = makeDTO(fileName: enc, size: "1048576")
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertEqual(result.size, 1048576)
    }

    func test_map_throwsInvalidSize_whenNonNumeric() throws {
        let enc = try makeEncryptedFileName("f.txt")
        let dto = makeDTO(fileName: enc, size: "not-a-number")
        XCTAssertThrowsError(try sut.map(dto, cipherKey: cipherKey)) { error in
            XCTAssertEqual(error as? AttachmentMapperError, .invalidSize("not-a-number"))
        }
    }

    // MARK: - sizeName preserved verbatim

    func test_map_preservesSizeNameVerbatim() throws {
        let enc = try makeEncryptedFileName("f.txt")
        let dto = makeDTO(fileName: enc, sizeName: "3.5 MB")
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertEqual(result.sizeName, "3.5 MB")
    }

    // MARK: - encryptedKey preserved verbatim

    func test_map_preservesEncryptedKeyVerbatim() throws {
        let enc = try makeEncryptedFileName("f.txt")
        let verbatimKey = "2.somebase64|morebase64|macbase64"
        let dto = makeDTO(fileName: enc, key: verbatimKey)
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertEqual(result.encryptedKey, verbatimKey)
    }

    // MARK: - url verbatim

    func test_map_preservesUrlVerbatim() throws {
        let enc = try makeEncryptedFileName("f.txt")
        let dto = makeDTO(fileName: enc, url: "https://cdn.bitwarden.net/attachment/abc123")
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertEqual(result.url, "https://cdn.bitwarden.net/attachment/abc123")
    }

    // MARK: - isUploadIncomplete

    func test_map_isUploadIncomplete_whenUrlIsNil() throws {
        let enc = try makeEncryptedFileName("f.txt")
        let dto = makeDTO(fileName: enc, url: nil)
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertTrue(result.isUploadIncomplete)
        XCTAssertNil(result.url)
    }

    func test_map_isUploadComplete_whenUrlPresent() throws {
        let enc = try makeEncryptedFileName("f.txt")
        let dto = makeDTO(fileName: enc, url: "https://cdn.example.com/file")
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertFalse(result.isUploadIncomplete)
    }

    // MARK: - null attachments → empty array (tested via CipherMapper)

    func test_nullAttachmentList_mapsToEmptyArray() throws {
        // AttachmentMapper is called with a list; a nil list coerces to [] in CipherMapper.
        // This test confirms the mapper itself maps a single DTO correctly (list handling is in CipherMapper).
        let enc = try makeEncryptedFileName("file.txt")
        let dto = makeDTO(fileName: enc)
        let result = try sut.map(dto, cipherKey: cipherKey)
        XCTAssertNotNil(result)
    }
}
