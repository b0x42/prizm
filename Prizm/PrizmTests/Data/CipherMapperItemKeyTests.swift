import XCTest
@testable import Prizm

/// Tests for ciphers that carry a per-item key (`key`).
///
/// Bitwarden clients (web vault, browser extension) set a per-item key on every new item: `key` is a
/// 64-byte key wrapped with the vault key, and ALL fields (name, notes, login, ...) are encrypted under
/// it, not under the vault key (Bitwarden Security Whitepaper, "Cipher Key Wrapping"). Decrypting those
/// fields with the vault key fails the MAC check, so the mapper must resolve the item key first.
@MainActor
final class CipherMapperItemKeyTests: XCTestCase {

    private let vaultKeys = CryptoKeys(
        encryptionKey: Data(repeating: 0xDE, count: 32),
        macKey:        Data(repeating: 0xAD, count: 32)
    )
    private let itemKeys = CryptoKeys(
        encryptionKey: Data(repeating: 0x11, count: 32),
        macKey:        Data(repeating: 0x22, count: 32)
    )

    private func enc(_ plaintext: String, keys: CryptoKeys) throws -> String {
        try EncString.encrypt(data: Data(plaintext.utf8), keys: keys).toString()
    }

    /// A login whose per-item key is wrapped with the vault key and whose fields are encrypted under it.
    private func makeLoginWithItemKey() throws -> (raw: RawCipher, itemKeyBytes: Data) {
        let itemKeyBytes = itemKeys.encryptionKey + itemKeys.macKey
        let wrappedItemKey = try EncString.encrypt(data: itemKeyBytes, keys: vaultKeys).toString()
        let raw = RawCipher(
            id:             "uuid-item-key",
            organizationId: nil,
            folderId:       nil,
            type:           1,
            name:           try enc("My Login", keys: itemKeys),
            notes:          try enc("a note", keys: itemKeys),
            favorite:       false,
            reprompt:       nil,
            deletedDate:    nil,
            creationDate:   nil,
            revisionDate:   nil,
            login: RawLoginData(
                username: try enc("alice@example.com", keys: itemKeys),
                password: try enc("s3cr3t", keys: itemKeys),
                uris:     [RawURI(uri: try enc("https://example.com", keys: itemKeys), match: nil)],
                totp:     nil
            ),
            card:           nil,
            identity:       nil,
            secureNote:     nil,
            sshKey:         nil,
            fields:         [],
            key:            wrappedItemKey,
            attachments:    nil
        )
        return (raw, itemKeyBytes)
    }

    func testMapLoginCipher_withItemKey_decryptsAllFieldsWithTheItemKey() throws {
        let (raw, itemKeyBytes) = try makeLoginWithItemKey()

        let (item, cipherKey) = try CipherMapper().map(raw: raw, keys: vaultKeys)

        XCTAssertEqual(item.name, "My Login")
        guard case .login(let login) = item.content else { return XCTFail("Expected .login content") }
        XCTAssertEqual(login.username, "alice@example.com")
        XCTAssertEqual(login.password, "s3cr3t")
        XCTAssertEqual(login.notes, "a note")
        XCTAssertEqual(login.uris.first?.uri, "https://example.com")
        XCTAssertEqual(cipherKey, itemKeyBytes, "the returned effective key is the unwrapped item key")
    }

    func testMapLoginCipher_withoutItemKey_stillUsesTheVaultKey() throws {
        let raw = RawCipher(
            id: "uuid-no-item-key", organizationId: nil, folderId: nil, type: 1,
            name: try enc("Plain", keys: vaultKeys), notes: nil, favorite: false, reprompt: nil,
            deletedDate: nil, creationDate: nil, revisionDate: nil,
            login: RawLoginData(username: try enc("bob", keys: vaultKeys), password: nil, uris: [], totp: nil),
            card: nil, identity: nil, secureNote: nil, sshKey: nil, fields: [], key: nil, attachments: nil
        )

        let (item, cipherKey) = try CipherMapper().map(raw: raw, keys: vaultKeys)

        XCTAssertEqual(item.name, "Plain")
        XCTAssertEqual(cipherKey, vaultKeys.encryptionKey + vaultKeys.macKey)
    }
}
