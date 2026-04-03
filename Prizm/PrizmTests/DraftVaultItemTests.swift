import XCTest
@testable import Prizm

/// Round-trip tests for `DraftVaultItem` ↔ `VaultItem` conversion.
///
/// Each test verifies that initialising a `DraftVaultItem` from a `VaultItem` and then
/// reconstructing a `VaultItem` from the draft produces a value equal to the original.
/// This guards against any field being accidentally dropped in either init.
final class DraftVaultItemTests: XCTestCase {

    // MARK: - Helpers

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeVaultItem(id: String = "id-1", name: String = "Test", content: ItemContent) -> VaultItem {
        VaultItem(
            id: id,
            name: name,
            isFavorite: true,
            isDeleted: false,
            creationDate: baseDate,
            revisionDate: baseDate,
            content: content
        )
    }

    // MARK: - Login round-trip

    func test_loginRoundTrip_preservesAllFields() {
        let original = makeVaultItem(content: .login(LoginContent(
            username: "user@example.com",
            password: "hunter2",
            uris: [
                LoginURI(uri: "https://example.com", matchType: .domain),
                LoginURI(uri: "https://sub.example.com", matchType: nil)
            ],
            totp: "TOTPSEED",
            notes: "Some notes",
            customFields: [
                CustomField(name: "token", value: "abc123", type: .text, linkedId: nil),
                CustomField(name: "secret", value: "shh", type: .hidden, linkedId: nil)
            ]
        )))

        let draft = DraftVaultItem(original)
        let reconstructed = VaultItem(draft)

        XCTAssertEqual(reconstructed, original)
    }

    func test_loginRoundTrip_nilOptionals() {
        let original = makeVaultItem(content: .login(LoginContent(
            username: nil,
            password: nil,
            uris: [],
            totp: nil,
            notes: nil,
            customFields: []
        )))

        let draft = DraftVaultItem(original)
        let reconstructed = VaultItem(draft)

        XCTAssertEqual(reconstructed, original)
    }

    // MARK: - Card round-trip

    func test_cardRoundTrip_preservesAllFields() {
        let original = makeVaultItem(content: .card(CardContent(
            cardholderName: "Jane Doe",
            brand: "Visa",
            number: "4111111111111111",
            expMonth: "12",
            expYear: "2028",
            code: "123",
            notes: "Card notes",
            customFields: [CustomField(name: "bank", value: "ACME Bank", type: .text, linkedId: nil)]
        )))

        let draft = DraftVaultItem(original)
        let reconstructed = VaultItem(draft)

        XCTAssertEqual(reconstructed, original)
    }

    // MARK: - Identity round-trip

    func test_identityRoundTrip_preservesAllFields() {
        let original = makeVaultItem(content: .identity(IdentityContent(
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

        let draft = DraftVaultItem(original)
        let reconstructed = VaultItem(draft)

        XCTAssertEqual(reconstructed, original)
    }

    // MARK: - Secure Note round-trip

    func test_secureNoteRoundTrip_preservesAllFields() {
        let original = makeVaultItem(content: .secureNote(SecureNoteContent(
            notes: "Super secret note",
            customFields: [CustomField(name: "hint", value: "remember", type: .text, linkedId: nil)]
        )))

        let draft = DraftVaultItem(original)
        let reconstructed = VaultItem(draft)

        XCTAssertEqual(reconstructed, original)
    }

    // MARK: - SSH Key round-trip

    func test_sshKeyRoundTrip_preservesAllFields() {
        let original = makeVaultItem(content: .sshKey(SSHKeyContent(
            privateKey: "-----BEGIN OPENSSH PRIVATE KEY-----\nABC\n-----END OPENSSH PRIVATE KEY-----",
            publicKey: "ssh-ed25519 AAAA... user@host",
            keyFingerprint: "SHA256:abc123",
            notes: "Work laptop key",
            customFields: []
        )))

        let draft = DraftVaultItem(original)
        let reconstructed = VaultItem(draft)

        XCTAssertEqual(reconstructed, original)
    }

    // MARK: - Top-level fields

    func test_topLevelFields_preservedInDraft() {
        let item = makeVaultItem(id: "abc", name: "My Item", content: .secureNote(SecureNoteContent(notes: nil, customFields: [])))
        let draft = DraftVaultItem(item)

        XCTAssertEqual(draft.id, "abc")
        XCTAssertEqual(draft.name, "My Item")
        XCTAssertTrue(draft.isFavorite)
        XCTAssertFalse(draft.isDeleted)
        XCTAssertEqual(draft.creationDate, baseDate)
        XCTAssertEqual(draft.revisionDate, baseDate)
    }

    func test_draftMutations_notReflectedInOriginal() {
        let item = makeVaultItem(content: .secureNote(SecureNoteContent(notes: "original", customFields: [])))
        var draft = DraftVaultItem(item)

        draft.name = "changed"
        if case .secureNote(var noteContent) = draft.content {
            noteContent.notes = "changed notes"
            draft.content = .secureNote(noteContent)
        }

        // Original VaultItem is a value type — it must not change
        XCTAssertEqual(item.name, "Test")
        if case .secureNote(let c) = item.content {
            XCTAssertEqual(c.notes, "original")
        } else {
            XCTFail("Expected secure note content")
        }
    }

    // MARK: - Custom field name/type immutability in draft

    func test_draftCustomField_nameAndTypeAreImmutable() {
        let field = CustomField(name: "token", value: "val", type: .hidden, linkedId: nil)
        var draftField = DraftCustomField(field)
        draftField.value = "new-val"

        // name and type are let — verifying they round-trip unchanged
        XCTAssertEqual(draftField.name, "token")
        XCTAssertEqual(draftField.type, .hidden)
        XCTAssertEqual(draftField.value, "new-val")
    }

    // MARK: - URI match type nil (default)

    func test_loginURI_nilMatchType_roundTrips() {
        let uri = LoginURI(uri: "https://example.com", matchType: nil)
        let draftURI = DraftLoginURI(uri)

        XCTAssertEqual(draftURI.uri, "https://example.com")
        XCTAssertNil(draftURI.matchType)
    }

    // MARK: - DraftLoginURI empty initializer

    func test_draftLoginURI_emptyInit_defaultsToEmptyStringAndNilMatchType() {
        let uri = DraftLoginURI()
        XCTAssertEqual(uri.uri, "")
        XCTAssertNil(uri.matchType)
    }

    // MARK: - URI list mutations (add / remove / reorder)

    func test_appendingBlankURI_increasesCount() {
        var content = DraftLoginContent(LoginContent(
            username: nil, password: nil,
            uris: [LoginURI(uri: "https://a.com", matchType: nil)],
            totp: nil, notes: nil, customFields: []
        ))
        content.uris.append(DraftLoginURI())
        XCTAssertEqual(content.uris.count, 2)
        XCTAssertEqual(content.uris[1].uri, "")
    }

    func test_removingURI_decreasesCount() {
        var content = DraftLoginContent(LoginContent(
            username: nil, password: nil,
            uris: [
                LoginURI(uri: "https://a.com", matchType: nil),
                LoginURI(uri: "https://b.com", matchType: nil)
            ],
            totp: nil, notes: nil, customFields: []
        ))
        content.uris.remove(at: 0)
        XCTAssertEqual(content.uris.count, 1)
        XCTAssertEqual(content.uris[0].uri, "https://b.com")
    }

    func test_swappingAdjacentURIs_reorders() {
        var content = DraftLoginContent(LoginContent(
            username: nil, password: nil,
            uris: [
                LoginURI(uri: "https://first.com", matchType: nil),
                LoginURI(uri: "https://second.com", matchType: nil)
            ],
            totp: nil, notes: nil, customFields: []
        ))
        content.uris.swapAt(0, 1)
        XCTAssertEqual(content.uris[0].uri, "https://second.com")
        XCTAssertEqual(content.uris[1].uri, "https://first.com")
    }
}
