import XCTest
@testable import Macwarden

/// T063: Unit tests for search — per-type field matching (FR-012),
/// category scoping, empty results, term preservation.
@MainActor
final class SearchVaultTests: XCTestCase {

    private var vault: VaultRepositoryImpl!
    private var sut:   SearchVaultUseCaseImpl!

    // MARK: - Fixtures

    private static let now = Date()

    private static let loginGithub = VaultItem(
        id: "1", name: "GitHub", isFavorite: true, isDeleted: false,
        creationDate: now, revisionDate: now,
        content: .login(LoginContent(
            username: "octocat", password: "p", uris: [LoginURI(uri: "https://github.com", matchType: nil)],
            totp: nil, notes: nil, customFields: []
        ))
    )

    private static let loginGitlab = VaultItem(
        id: "2", name: "GitLab", isFavorite: false, isDeleted: false,
        creationDate: now, revisionDate: now,
        content: .login(LoginContent(
            username: "labuser", password: "p", uris: [LoginURI(uri: "https://gitlab.com", matchType: nil)],
            totp: nil, notes: nil, customFields: []
        ))
    )

    private static let cardVisa = VaultItem(
        id: "3", name: "My Visa", isFavorite: false, isDeleted: false,
        creationDate: now, revisionDate: now,
        content: .card(CardContent(
            cardholderName: "Alice Smith", brand: "Visa", number: "4111", expMonth: "12", expYear: "2030",
            code: "123", notes: nil, customFields: []
        ))
    )

    private static let identityWork = VaultItem(
        id: "4", name: "Work ID", isFavorite: false, isDeleted: false,
        creationDate: now, revisionDate: now,
        content: .identity(IdentityContent(
            title: "Ms", firstName: "Alice", middleName: nil, lastName: "Smith",
            address1: nil, address2: nil, address3: nil, city: nil, state: nil,
            postalCode: nil, country: nil, company: "Acme Corp", email: "alice@acme.com",
            phone: nil, ssn: nil, username: nil, passportNumber: nil, licenseNumber: nil,
            notes: nil, customFields: []
        ))
    )

    private static let secureNote = VaultItem(
        id: "5", name: "Secret Note", isFavorite: false, isDeleted: false,
        creationDate: now, revisionDate: now,
        content: .secureNote(SecureNoteContent(notes: "top secret", customFields: []))
    )

    private static let sshKey = VaultItem(
        id: "6", name: "Deploy Key", isFavorite: false, isDeleted: false,
        creationDate: now, revisionDate: now,
        content: .sshKey(SSHKeyContent(
            privateKey: "priv", publicKey: "pub", keyFingerprint: "SHA256:abc",
            notes: nil, customFields: []
        ))
    )

    private static let deletedItem = VaultItem(
        id: "7", name: "Deleted Login", isFavorite: false, isDeleted: true,
        creationDate: now, revisionDate: now,
        content: .login(LoginContent(
            username: "gone", password: "p", uris: [], totp: nil, notes: nil, customFields: []
        ))
    )

    private static let allFixtures = [
        loginGithub, loginGitlab, cardVisa, identityWork, secureNote, sshKey, deletedItem
    ]

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        vault = VaultRepositoryImpl(apiClient: MockMacwardenAPIClient(), crypto: MockMacwardenCryptoService())
        vault.populate(items: Self.allFixtures, syncedAt: Self.now)
        sut = SearchVaultUseCaseImpl(vault: vault)
    }

    override func tearDown() {
        vault = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Name search (all types)

    func testSearchByName_matchesPartialCaseInsensitive() throws {
        let results = try sut.execute(query: "git", in: .allItems)
        XCTAssertEqual(Set(results.map(\.id)), Set(["1", "2"]))
    }

    // MARK: - Login-specific fields

    func testSearchLogin_matchesUsername() throws {
        let results = try sut.execute(query: "octocat", in: .allItems)
        XCTAssertEqual(results.map(\.id), ["1"])
    }

    func testSearchLogin_matchesURI() throws {
        let results = try sut.execute(query: "gitlab.com", in: .allItems)
        XCTAssertEqual(results.map(\.id), ["2"])
    }

    // MARK: - Card-specific fields

    func testSearchCard_matchesCardholderName() throws {
        let results = try sut.execute(query: "alice smith", in: .allItems)
        // Should match card (cardholderName) and identity (company: Acme, email: alice@acme)
        XCTAssertTrue(results.contains(where: { $0.id == "3" }), "Card should match on cardholderName")
    }

    // MARK: - Identity-specific fields

    func testSearchIdentity_matchesEmail() throws {
        let results = try sut.execute(query: "alice@acme", in: .allItems)
        XCTAssertEqual(results.map(\.id), ["4"])
    }

    func testSearchIdentity_matchesCompany() throws {
        let results = try sut.execute(query: "acme corp", in: .allItems)
        XCTAssertEqual(results.map(\.id), ["4"])
    }

    // MARK: - SecureNote and SSHKey: name only

    func testSearchSecureNote_matchesNameOnly() throws {
        let results = try sut.execute(query: "secret", in: .allItems)
        XCTAssertEqual(results.map(\.id), ["5"])
    }

    func testSearchSSHKey_matchesNameOnly() throws {
        let results = try sut.execute(query: "deploy", in: .allItems)
        XCTAssertEqual(results.map(\.id), ["6"])
    }

    func testSearchSSHKey_doesNotMatchFingerprint() throws {
        let results = try sut.execute(query: "SHA256", in: .allItems)
        XCTAssertTrue(results.isEmpty, "SSH key search should only match name, not fingerprint")
    }

    // MARK: - Category scoping

    func testSearchScopedToLoginType() throws {
        let results = try sut.execute(query: "git", in: .type(.login))
        XCTAssertEqual(Set(results.map(\.id)), Set(["1", "2"]))
    }

    func testSearchScopedToCardType_excludesLogins() throws {
        // "Alice" would match identity too, but card scope should only return the card
        let results = try sut.execute(query: "alice", in: .type(.card))
        XCTAssertEqual(results.map(\.id), ["3"])
    }

    func testSearchScopedToFavorites() throws {
        let results = try sut.execute(query: "git", in: .favorites)
        XCTAssertEqual(results.map(\.id), ["1"], "Only favorite GitHub should match")
    }

    // MARK: - Empty results

    func testSearchNoMatch_returnsEmpty() throws {
        let results = try sut.execute(query: "nonexistent", in: .allItems)
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchEmptyQuery_returnsAllInCategory() throws {
        let results = try sut.execute(query: "", in: .allItems)
        // 6 non-deleted items
        XCTAssertEqual(results.count, 6, "Empty query should return all non-deleted items")
    }

    // MARK: - Deleted items excluded

    func testSearchExcludesDeletedItems() throws {
        let results = try sut.execute(query: "deleted", in: .allItems)
        XCTAssertTrue(results.isEmpty, "Deleted items should never appear in search results")
    }
}
