import XCTest
@testable import Macwarden

/// Unit tests for Domain entity validation rules (T013).
/// Requires a unit-test target — add one in Xcode:
///   File → New → Target → macOS Unit Testing Bundle → "MacwardenTests"
///   then add this file to that target's Compile Sources.
@MainActor
final class EntityValidationTests: XCTestCase {

    // MARK: - ServerEnvironment

    func testServerEnvironmentDerivesAPIURL() {
        let base = URL(string: "https://vault.example.com")!
        let env = ServerEnvironment(base: base, overrides: nil)
        XCTAssertEqual(env.apiURL, URL(string: "https://vault.example.com/api"))
    }

    func testServerEnvironmentDerivesIdentityURL() {
        let base = URL(string: "https://vault.example.com")!
        let env = ServerEnvironment(base: base, overrides: nil)
        XCTAssertEqual(env.identityURL, URL(string: "https://vault.example.com/identity"))
    }

    func testServerEnvironmentDerivesIconsURL() {
        let base = URL(string: "https://vault.example.com")!
        let env = ServerEnvironment(base: base, overrides: nil)
        XCTAssertEqual(env.iconsURL, URL(string: "https://vault.example.com/icons"))
    }

    func testServerEnvironmentOverridesRespected() {
        let base = URL(string: "https://vault.example.com")!
        let customAPI = URL(string: "https://api.example.com")!
        let overrides = ServerURLOverrides(api: customAPI, identity: nil, icons: nil)
        let env = ServerEnvironment(base: base, overrides: overrides)
        XCTAssertEqual(env.apiURL, customAPI)
        // Non-overridden paths still derive from base
        XCTAssertEqual(env.identityURL, URL(string: "https://vault.example.com/identity"))
    }

    // MARK: - Account

    func testAccountStoresEmail() {
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        let account = Account(userId: "user-1", email: "alice@example.com", name: "Alice", serverEnvironment: env)
        XCTAssertEqual(account.email, "alice@example.com")
        XCTAssertEqual(account.name, "Alice")
    }

    func testAccountOptionalNameCanBeNil() {
        let env = ServerEnvironment(base: URL(string: "https://vault.example.com")!, overrides: nil)
        let account = Account(userId: "user-2", email: "bob@example.com", name: nil, serverEnvironment: env)
        XCTAssertNil(account.name)
    }

    // MARK: - CustomField

    func testCustomFieldNameIsNonEmpty() {
        let field = CustomField(name: "API Key", value: "abc123", type: .text, linkedId: nil)
        XCTAssertFalse(field.name.isEmpty)
    }

    func testCustomFieldHiddenType() {
        let field = CustomField(name: "Secret", value: "hunter2", type: .hidden, linkedId: nil)
        XCTAssertEqual(field.type, .hidden)
    }

    func testCustomFieldLinkedType() {
        let field = CustomField(name: "User", value: nil, type: .linked, linkedId: .loginUsername)
        XCTAssertEqual(field.linkedId, .loginUsername)
        XCTAssertEqual(field.linkedId?.displayName, "Username")
    }

    // MARK: - KdfParams

    func testKdfParamsPBKDF2HasNilMemoryAndParallelism() {
        let params = KdfParams(type: .pbkdf2, iterations: 600_000, memory: nil, parallelism: nil)
        XCTAssertEqual(params.type, .pbkdf2)
        XCTAssertNil(params.memory)
        XCTAssertNil(params.parallelism)
    }

    func testKdfParamsArgon2idHasMemoryAndParallelism() {
        let params = KdfParams(type: .argon2id, iterations: 3, memory: 65536, parallelism: 4)
        XCTAssertEqual(params.type, .argon2id)
        XCTAssertEqual(params.memory, 65536)
        XCTAssertEqual(params.parallelism, 4)
    }

    // MARK: - SidebarSelection

    func testSidebarSelectionHashableForDictKey() {
        var counts: [SidebarSelection: Int] = [:]
        counts[.allItems] = 10
        counts[.favorites] = 2
        counts[.type(.login)] = 5
        XCTAssertEqual(counts[.allItems], 10)
        XCTAssertEqual(counts[.type(.login)], 5)
    }

    func testItemTypeCaseIterable() {
        XCTAssertEqual(ItemType.allCases.count, 5)
    }

    // MARK: - VaultItem

    func testVaultItemDeletedFlagRespected() {
        let item = VaultItem(
            id: "1",
            name: "Test",
            isFavorite: false,
            isDeleted: true,
            creationDate: Date(),
            revisionDate: Date(),
            content: .secureNote(SecureNoteContent(notes: nil, customFields: []))
        )
        XCTAssertTrue(item.isDeleted)
    }
}
