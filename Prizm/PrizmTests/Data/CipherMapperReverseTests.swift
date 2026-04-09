import XCTest
@testable import Prizm

/// Round-trip tests for `CipherMapper.toRawCipher(_:encryptedWith:)`.
///
/// Each test converts a `VaultItem` → `DraftVaultItem` → `RawCipher` (via reverse mapper)
/// → `VaultItem` (via forward mapper) and verifies the final item equals the original.
/// This validates that no field is dropped or corrupted by the encrypt/decrypt cycle.
@MainActor
final class CipherMapperReverseTests: XCTestCase {

    private var sut: CipherMapper!
    private var keys: CryptoKeys!
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() async throws {
        try await super.setUp()
        sut = CipherMapper()
        keys = CryptoKeys(
            encryptionKey: Data(repeating: 0xDE, count: 32),
            macKey:        Data(repeating: 0xAD, count: 32)
        )
    }

    // MARK: - Helpers

    private func roundTrip(_ item: VaultItem) throws -> VaultItem {
        let draft      = DraftVaultItem(item)
        let rawCipher  = try sut.toRawCipher(draft, encryptedWith: keys)
        return try sut.map(raw: rawCipher, keys: keys).item
    }

    private func makeItem(content: ItemContent) -> VaultItem {
        VaultItem(
            id: "id-rt",
            name: "Round Trip Item",
            isFavorite: true,
            isDeleted: false,
            creationDate: baseDate,
            revisionDate: baseDate,
            content: content
        )
    }

    // MARK: - Login round-trip

    func test_reverseMapper_loginRoundTrip() throws {
        let original = makeItem(content: .login(LoginContent(
            username: "user@example.com",
            password: "s3cret!",
            uris: [
                LoginURI(uri: "https://example.com", matchType: .domain),
                LoginURI(uri: "https://other.example.com", matchType: nil)
            ],
            totp: "TOTP_SEED",
            notes: "Login notes",
            customFields: [
                CustomField(name: "api_key", value: "key123", type: .text, linkedId: nil),
                CustomField(name: "hidden_token", value: "tok", type: .hidden, linkedId: nil)
            ]
        )))

        let result = try roundTrip(original)
        XCTAssertEqual(result.name, original.name)
        guard case .login(let orig) = original.content,
              case .login(let res)  = result.content else {
            return XCTFail("Expected .login")
        }
        XCTAssertEqual(res.username, orig.username)
        XCTAssertEqual(res.password, orig.password)
        XCTAssertEqual(res.notes, orig.notes)
        XCTAssertEqual(res.uris.count, orig.uris.count)
        XCTAssertEqual(res.uris[0].uri, orig.uris[0].uri)
        XCTAssertEqual(res.uris[0].matchType, orig.uris[0].matchType)
        XCTAssertNil(res.uris[1].matchType)
        XCTAssertEqual(res.customFields.count, orig.customFields.count)
        XCTAssertEqual(res.customFields[0].value, orig.customFields[0].value)
    }

    func test_reverseMapper_loginNilFields_roundTrip() throws {
        let original = makeItem(content: .login(LoginContent(
            username: nil,
            password: nil,
            uris: [],
            totp: nil,
            notes: nil,
            customFields: []
        )))

        let result = try roundTrip(original)
        guard case .login(let res) = result.content else { return XCTFail("Expected .login") }
        XCTAssertNil(res.username)
        XCTAssertNil(res.password)
        XCTAssertTrue(res.uris.isEmpty)
    }

    // MARK: - Card round-trip

    func test_reverseMapper_cardRoundTrip() throws {
        let original = makeItem(content: .card(CardContent(
            cardholderName: "Jane Doe",
            brand: "Visa",
            number: "4111111111111111",
            expMonth: "12",
            expYear: "2028",
            code: "123",
            notes: "Card notes",
            customFields: [CustomField(name: "bank", value: "ACME", type: .text, linkedId: nil)]
        )))

        let result = try roundTrip(original)
        guard case .card(let orig) = original.content,
              case .card(let res)  = result.content else {
            return XCTFail("Expected .card")
        }
        XCTAssertEqual(res.cardholderName, orig.cardholderName)
        XCTAssertEqual(res.brand, orig.brand)
        XCTAssertEqual(res.number, orig.number)
        XCTAssertEqual(res.expMonth, orig.expMonth)
        XCTAssertEqual(res.expYear, orig.expYear)
        XCTAssertEqual(res.code, orig.code)
        XCTAssertEqual(res.notes, orig.notes)
        XCTAssertEqual(res.customFields[0].value, orig.customFields[0].value)
    }

    // MARK: - Identity round-trip

    func test_reverseMapper_identityRoundTrip() throws {
        let original = makeItem(content: .identity(IdentityContent(
            title: "Dr",
            firstName: "Alice",
            middleName: "B",
            lastName: "Smith",
            address1: "1 Main St",
            address2: "Apt 2",
            address3: nil,
            city: "Springfield",
            state: "IL",
            postalCode: "62701",
            country: "US",
            company: "ACME",
            email: "alice@acme.com",
            phone: "555-0100",
            ssn: "123-45-6789",
            username: "alice",
            passportNumber: "X1234567",
            licenseNumber: "D1234567",
            notes: "ID notes",
            customFields: []
        )))

        let result = try roundTrip(original)
        guard case .identity(let orig) = original.content,
              case .identity(let res)  = result.content else {
            return XCTFail("Expected .identity")
        }
        XCTAssertEqual(res.firstName, orig.firstName)
        XCTAssertEqual(res.lastName, orig.lastName)
        XCTAssertEqual(res.email, orig.email)
        XCTAssertEqual(res.ssn, orig.ssn)
        XCTAssertNil(res.address3)
        XCTAssertEqual(res.licenseNumber, orig.licenseNumber)
    }

    // MARK: - Secure Note round-trip

    func test_reverseMapper_secureNoteRoundTrip() throws {
        let original = makeItem(content: .secureNote(SecureNoteContent(
            notes: "Top secret note",
            customFields: [CustomField(name: "hint", value: "remember", type: .text, linkedId: nil)]
        )))

        let result = try roundTrip(original)
        guard case .secureNote(let orig) = original.content,
              case .secureNote(let res)  = result.content else {
            return XCTFail("Expected .secureNote")
        }
        XCTAssertEqual(res.notes, orig.notes)
        XCTAssertEqual(res.customFields[0].value, orig.customFields[0].value)
    }

    // MARK: - SSH Key round-trip

    func test_reverseMapper_sshKeyRoundTrip() throws {
        let original = makeItem(content: .sshKey(SSHKeyContent(
            privateKey: "-----BEGIN OPENSSH PRIVATE KEY-----\nABC\n-----END OPENSSH PRIVATE KEY-----",
            publicKey: "ssh-ed25519 AAAA... user@host",
            keyFingerprint: "SHA256:abc123",
            notes: "Work laptop",
            customFields: []
        )))

        let result = try roundTrip(original)
        guard case .sshKey(let orig) = original.content,
              case .sshKey(let res)  = result.content else {
            return XCTFail("Expected .sshKey")
        }
        XCTAssertEqual(res.privateKey, orig.privateKey)
        XCTAssertEqual(res.publicKey, orig.publicKey)
        XCTAssertEqual(res.notes, orig.notes)
        // keyFingerprint is not sent to the API; the forward-mapped result will have nil.
        // This is expected — the server returns the authoritative fingerprint post-save.
        XCTAssertNil(res.keyFingerprint)
    }

    // MARK: - Name and favorite preserved

    func test_reverseMapper_preservesNameAndFavorite() throws {
        let original = VaultItem(
            id: "fav-1",
            name: "My Favourite Login",
            isFavorite: true,
            isDeleted: false,
            creationDate: baseDate,
            revisionDate: baseDate,
            content: .secureNote(SecureNoteContent(notes: nil, customFields: []))
        )

        let result = try roundTrip(original)
        XCTAssertEqual(result.name, "My Favourite Login")
        XCTAssertTrue(result.isFavorite)
    }
}
