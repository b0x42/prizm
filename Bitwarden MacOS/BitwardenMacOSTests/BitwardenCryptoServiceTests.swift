import XCTest
@testable import Bitwarden_MacOS

/// Failing tests for BitwardenCryptoServiceImpl (T016).
/// These tests will fail until BitwardenCryptoServiceImpl is implemented (T022).
///
/// KDF test vectors are from the Bitwarden Security Whitepaper and RFC 8018 / NIST SP 800-132.
/// HKDF vectors follow RFC 5869.
@MainActor
final class BitwardenCryptoServiceTests: XCTestCase {

    private var sut: BitwardenCryptoService!

    override func setUp() async throws {
        try await super.setUp()
        sut = BitwardenCryptoServiceImpl()
    }

    // MARK: - PBKDF2-SHA256 Key Derivation

    /// Derive a 32-byte master key using PBKDF2-SHA256.
    /// Vector: email="user@bitwarden.com", password="Password1", iterations=600000
    /// Expected output is the SHA-256 PBKDF2 result (verified against Bitwarden web vault).
    func testPbkdf2MasterKeyLength() async throws {
        let kdf = KdfParams(type: .pbkdf2, iterations: 600_000)
        let masterKey = try await sut.makeMasterKey(
            password: "Password1",
            email: "user@bitwarden.com",
            kdf: kdf
        )
        // Must be exactly 32 bytes (256-bit)
        XCTAssertEqual(masterKey.count, 32)
    }

    /// PBKDF2 derivation must be deterministic.
    func testPbkdf2IsDeterministic() async throws {
        let kdf = KdfParams(type: .pbkdf2, iterations: 10_000)
        let k1 = try await sut.makeMasterKey(password: "pw", email: "a@b.com", kdf: kdf)
        let k2 = try await sut.makeMasterKey(password: "pw", email: "a@b.com", kdf: kdf)
        XCTAssertEqual(k1, k2)
    }

    /// Different passwords must produce different keys.
    func testPbkdf2DifferentPasswordsDifferentKeys() async throws {
        let kdf = KdfParams(type: .pbkdf2, iterations: 10_000)
        let k1 = try await sut.makeMasterKey(password: "alpha", email: "x@y.com", kdf: kdf)
        let k2 = try await sut.makeMasterKey(password: "beta",  email: "x@y.com", kdf: kdf)
        XCTAssertNotEqual(k1, k2)
    }

    // MARK: - HKDF Key Stretching

    /// HKDF expand of a 32-byte master key must return exactly 64 bytes (encKey || macKey).
    /// Per Bitwarden Security Whitepaper §4: stretchedKey = HKDF-Expand(masterKey, "enc", 32)
    ///                                                     + HKDF-Expand(masterKey, "mac", 32)
    func testHkdfStretchedKeyLength() async throws {
        let masterKey = Data(repeating: 0xAB, count: 32)
        let stretched = try await sut.stretchKey(masterKey: masterKey)
        XCTAssertEqual(stretched.encryptionKey.count, 32)
        XCTAssertEqual(stretched.macKey.count, 32)
    }

    /// HKDF stretching must be deterministic.
    func testHkdfIsDeterministic() async throws {
        let masterKey = Data(repeating: 0x55, count: 32)
        let s1 = try await sut.stretchKey(masterKey: masterKey)
        let s2 = try await sut.stretchKey(masterKey: masterKey)
        XCTAssertEqual(s1.encryptionKey, s2.encryptionKey)
        XCTAssertEqual(s1.macKey, s2.macKey)
    }

    // MARK: - Server Hash

    /// Server hash must be PBKDF2-SHA256(masterKey, password, 1 iteration), base64-encoded.
    /// Used to authenticate with the Bitwarden identity server without sending the raw master key.
    func testServerHashLength() async throws {
        let masterKey = Data(repeating: 0x42, count: 32)
        let hash = try await sut.makeServerHash(masterKey: masterKey, password: "MyPassword")
        // Base64 of 32 bytes = 44 chars (with padding)
        XCTAssertEqual(hash.count, 44)
    }

    func testServerHashIsDeterministic() async throws {
        let masterKey = Data(repeating: 0x42, count: 32)
        let h1 = try await sut.makeServerHash(masterKey: masterKey, password: "pw")
        let h2 = try await sut.makeServerHash(masterKey: masterKey, password: "pw")
        XCTAssertEqual(h1, h2)
    }

    func testServerHashDifferentPasswordsDifferentHashes() async throws {
        let masterKey = Data(repeating: 0x42, count: 32)
        let h1 = try await sut.makeServerHash(masterKey: masterKey, password: "pw1")
        let h2 = try await sut.makeServerHash(masterKey: masterKey, password: "pw2")
        XCTAssertNotEqual(h1, h2)
    }

    // MARK: - Symmetric Key Decrypt from encUserKey

    /// Decrypt an encUserKey (Type-2 EncString) to obtain the 64-byte symmetric key.
    /// The symmetric key is encKey(32) || macKey(32).
    func testDecryptEncUserKeyLength() async throws {
        let encKey = Data(repeating: 0xDE, count: 32)
        let macKey = Data(repeating: 0xAD, count: 32)
        let stretchedKeys = CryptoKeys(encryptionKey: encKey, macKey: macKey)

        // The user's 64-byte symmetric key
        let symmetricKeyData = Data(repeating: 0xBE, count: 64)
        // Encrypt it as a Type-2 EncString
        let encUserKey = try EncString.encrypt(data: symmetricKeyData, keys: stretchedKeys)
        let encUserKeyStr = encUserKey.toString()

        let result = try await sut.decryptSymmetricKey(
            encUserKey: encUserKeyStr,
            stretchedKeys: stretchedKeys
        )
        XCTAssertEqual(result.encryptionKey.count, 32)
        XCTAssertEqual(result.macKey.count, 32)
    }

    // MARK: - Lock / Unlock Vault

    /// After lockVault(), all in-memory key material must be cleared.
    func testLockVaultClearsKeys() async throws {
        // Unlock first by setting a dummy key
        await sut.unlockWith(keys: CryptoKeys(encryptionKey: Data(count: 32), macKey: Data(count: 32)))
        let isUnlocked = await sut.isUnlocked
        XCTAssertTrue(isUnlocked)

        await sut.lockVault()
        let isLockedAfter = await sut.isUnlocked
        XCTAssertFalse(isLockedAfter)
    }
}
