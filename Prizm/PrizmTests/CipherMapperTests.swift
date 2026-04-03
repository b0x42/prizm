import XCTest
@testable import Prizm

/// Failing tests for CipherMapper (T017).
/// These tests will fail until CipherMapper + RawCipher are implemented (T020, T021).
@MainActor
final class CipherMapperTests: XCTestCase {

    private var sut: CipherMapper!
    private var mockKeys: CryptoKeys!

    override func setUp() async throws {
        try await super.setUp()
        sut = CipherMapper()
        mockKeys = CryptoKeys(
            encryptionKey: Data(repeating: 0xDE, count: 32),
            macKey:        Data(repeating: 0xAD, count: 32)
        )
    }

    // MARK: - Helpers

    /// Returns a minimal RawCipher with only required fields set.
    private func makeRawCipher(
        id:             String    = "uuid-test",
        organizationId: String?   = nil,
        type:           Int,
        name:           String,
        notes:          String?   = nil,
        favorite:       Bool      = false,
        deletedDate:    String?   = nil,
        login:          RawLoginData?      = nil,
        card:           RawCardData?       = nil,
        identity:       RawIdentityData?   = nil,
        secureNote:     RawSecureNoteData? = nil,
        sshKey:         RawSSHKeyData?     = nil
    ) -> RawCipher {
        RawCipher(
            id:             id,
            organizationId: organizationId,
            type:           type,
            name:           name,
            notes:          notes,
            favorite:       favorite,
            reprompt:       nil,
            deletedDate:    deletedDate,
            creationDate:   nil,
            revisionDate:   nil,
            login:          login,
            card:           card,
            identity:       identity,
            secureNote:     secureNote,
            sshKey:         sshKey,
            fields:         []
        )
    }

    /// Builds a minimal encrypted string for a known plaintext using mockKeys.
    private func enc(_ plaintext: String) throws -> String {
        let data = plaintext.data(using: .utf8)!
        return try EncString.encrypt(data: data, keys: mockKeys).toString()
    }

    // MARK: - Login cipher

    func testMapLoginCipher() throws {
        let raw = makeRawCipher(
            id:   "uuid-login",
            type: 1,
            name: try enc("My Login"),
            login: RawLoginData(
                username: try enc("alice@example.com"),
                password: try enc("s3cr3t"),
                uris:     [RawURI(uri: try enc("https://example.com"), match: nil)],
                totp:     nil
            )
        )

        let item = try sut.map(raw: raw, keys: mockKeys)
        XCTAssertEqual(item.id, "uuid-login")
        XCTAssertEqual(item.name, "My Login")
        XCTAssertFalse(item.isFavorite)

        guard case .login(let login) = item.content else {
            return XCTFail("Expected .login content")
        }
        XCTAssertEqual(login.username, "alice@example.com")
        XCTAssertEqual(login.password, "s3cr3t")
        XCTAssertEqual(login.uris.first?.uri, "https://example.com")
    }

    // MARK: - Secure Note cipher

    func testMapSecureNoteCipher() throws {
        let raw = makeRawCipher(
            id:         "uuid-note",
            type:       2,
            name:       try enc("My Note"),
            notes:      try enc("Top secret notes"),
            favorite:   true,
            secureNote: RawSecureNoteData(type: 0)
        )

        let item = try sut.map(raw: raw, keys: mockKeys)
        XCTAssertEqual(item.name, "My Note")
        XCTAssertTrue(item.isFavorite)

        guard case .secureNote(let note) = item.content else {
            return XCTFail("Expected .secureNote content")
        }
        XCTAssertEqual(note.notes, "Top secret notes")
    }

    // MARK: - Card cipher

    func testMapCardCipher() throws {
        let raw = makeRawCipher(
            id:   "uuid-card",
            type: 3,
            name: try enc("Visa"),
            card: RawCardData(
                cardholderName: try enc("Alice Smith"),
                brand:          try enc("Visa"),
                number:         try enc("4111111111111111"),
                expMonth:       try enc("12"),
                expYear:        try enc("2028"),
                code:           try enc("123")
            )
        )

        let item = try sut.map(raw: raw, keys: mockKeys)
        XCTAssertEqual(item.name, "Visa")

        guard case .card(let card) = item.content else {
            return XCTFail("Expected .card content")
        }
        XCTAssertEqual(card.cardholderName, "Alice Smith")
        XCTAssertEqual(card.number, "4111111111111111")
    }

    // MARK: - Identity cipher

    func testMapIdentityCipher() throws {
        let raw = makeRawCipher(
            id:       "uuid-id",
            type:     4,
            name:     try enc("My Identity"),
            identity: RawIdentityData(
                title:          nil,
                firstName:      try enc("Alice"),
                middleName:     nil,
                lastName:       try enc("Smith"),
                address1:       nil, address2: nil, address3: nil,
                city:           nil, state: nil, postalCode: nil, country: nil,
                company:        nil,
                email:          try enc("alice@example.com"),
                phone:          nil, ssn: nil, username: nil,
                passportNumber: nil, licenseNumber: nil
            )
        )

        let item = try sut.map(raw: raw, keys: mockKeys)
        XCTAssertEqual(item.name, "My Identity")

        guard case .identity(let identity) = item.content else {
            return XCTFail("Expected .identity content")
        }
        XCTAssertEqual(identity.firstName, "Alice")
        XCTAssertEqual(identity.lastName, "Smith")
        XCTAssertEqual(identity.email, "alice@example.com")
    }

    // MARK: - SSH Key cipher

    func testMapSshKeyCipher() throws {
        let raw = makeRawCipher(
            id:     "uuid-ssh",
            type:   5,
            name:   try enc("My SSH Key"),
            sshKey: RawSSHKeyData(
                privateKey:     try enc("-----BEGIN OPENSSH PRIVATE KEY-----\n..."),
                publicKey:      try enc("ssh-ed25519 AAAA..."),
                keyFingerprint: try enc("SHA256:abc123")
            )
        )

        let item = try sut.map(raw: raw, keys: mockKeys)
        XCTAssertEqual(item.name, "My SSH Key")

        guard case .sshKey(let ssh) = item.content else {
            return XCTFail("Expected .sshKey content")
        }
        XCTAssertTrue((ssh.privateKey ?? "").hasPrefix("-----BEGIN"))
        XCTAssertTrue((ssh.publicKey ?? "").hasPrefix("ssh-ed25519"))
        XCTAssertEqual(ssh.keyFingerprint, "SHA256:abc123")
    }

    // MARK: - Organisation cipher filtered

    /// Ciphers belonging to an organisation must be filtered out (organizationId != nil).
    func testOrgCipherIsFiltered() throws {
        let raw = makeRawCipher(
            id:             "uuid-org",
            organizationId: "org-uuid-123",
            type:           1,
            name:           try enc("Org Login"),
            login: RawLoginData(username: try enc("user"), password: try enc("pass"),
                                uris: [], totp: nil)
        )

        XCTAssertThrowsError(try sut.map(raw: raw, keys: mockKeys)) { error in
            XCTAssertEqual(error as? CipherMapperError, .organisationCipherSkipped)
        }
    }

    // MARK: - Deleted cipher

    /// A cipher with a deletedDate must have isDeleted == true.
    func testDeletedCipherIsMarked() throws {
        let raw = makeRawCipher(
            id:          "uuid-del",
            type:        2,
            name:        try enc("Deleted Note"),
            deletedDate: "2025-01-01T00:00:00Z",
            secureNote:  RawSecureNoteData(type: 0)
        )

        let item = try sut.map(raw: raw, keys: mockKeys)
        XCTAssertTrue(item.isDeleted)
    }
}
