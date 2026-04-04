import XCTest
@testable import Prizm

/// Tests for `VaultKeyServiceImpl` — key resolution order and vault-lock handling.
final class VaultKeyServiceImplTests: XCTestCase {

    private var cache: VaultKeyCache!
    private var mockCrypto: MockPrizmCryptoService!
    private var sut: VaultKeyServiceImpl!

    private let vaultKeys = CryptoKeys(
        encryptionKey: Data(repeating: 0x01, count: 32),
        macKey:        Data(repeating: 0x02, count: 32)
    )

    override func setUp() async throws {
        cache       = VaultKeyCache()
        mockCrypto  = MockPrizmCryptoService()
        sut         = VaultKeyServiceImpl(cache: cache, crypto: mockCrypto)
    }

    // MARK: - Cache hit

    func test_returnsPerItemKey_whenPresentInCache() async throws {
        let perItemKey = Data(repeating: 0xAB, count: 64)
        await cache.populate(keys: ["cipher-1": perItemKey])
        mockCrypto._isUnlocked = true
        mockCrypto.stubbedVaultKeys = vaultKeys

        let result = try await sut.cipherKey(for: "cipher-1")
        XCTAssertEqual(result, perItemKey)
    }

    // MARK: - Cache miss — no per-item key

    func test_fallsBack_toVaultKey_whenCacheEntryIsNil() async throws {
        // Cipher has no per-item key (none in cache).
        mockCrypto._isUnlocked = true
        mockCrypto.stubbedVaultKeys = vaultKeys

        let result = try await sut.cipherKey(for: "cipher-no-per-item-key")
        let expected = vaultKeys.encryptionKey + vaultKeys.macKey
        XCTAssertEqual(result, expected)
    }

    func test_fallsBack_toVaultKey_forNewCipher_notYetSynced() async throws {
        // Cache populated for other ciphers; the requested cipher ID is absent.
        await cache.populate(keys: ["cipher-other": Data(repeating: 0xFF, count: 64)])
        mockCrypto._isUnlocked = true
        mockCrypto.stubbedVaultKeys = vaultKeys

        let result = try await sut.cipherKey(for: "cipher-new-not-in-cache")
        let expected = vaultKeys.encryptionKey + vaultKeys.macKey
        XCTAssertEqual(result, expected)
    }

    // MARK: - Vault locked

    func test_throwsVaultLocked_whenCryptoServiceIsLocked() async {
        // Vault is locked — currentKeys() will throw vaultLocked.
        mockCrypto._isUnlocked = false

        do {
            _ = try await sut.cipherKey(for: "cipher-1")
            XCTFail("Expected VaultError.vaultLocked")
        } catch VaultError.vaultLocked {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_doesNotThrowVaultLocked_whenCacheHasEntry_andVaultIsLocked() async throws {
        // Cache has an entry for the cipher — no need to call crypto at all.
        // Even if the vault is locked, the cache can serve the key.
        let perItemKey = Data(repeating: 0xCC, count: 64)
        await cache.populate(keys: ["cipher-1": perItemKey])
        mockCrypto._isUnlocked = false   // vault locked

        // Should succeed from cache, not throw vaultLocked.
        let result = try await sut.cipherKey(for: "cipher-1")
        XCTAssertEqual(result, perItemKey)
    }

    func test_emptyCache_doesNotInferVaultLocked() async {
        // An absent cache entry is NOT a vault-locked signal — only currentKeys() throwing
        // vaultLocked indicates that condition.
        mockCrypto._isUnlocked = false

        do {
            _ = try await sut.cipherKey(for: "cipher-absent")
            XCTFail("Expected VaultError.vaultLocked from crypto, not from missing cache entry")
        } catch VaultError.vaultLocked {
            // Expected — the error comes from currentKeys() throwing, not from the empty cache.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Key length

    func test_vaultKeyFallback_produces64Bytes() async throws {
        mockCrypto._isUnlocked = true
        mockCrypto.stubbedVaultKeys = vaultKeys

        let result = try await sut.cipherKey(for: "cipher-no-per-item")
        XCTAssertEqual(result.count, 64, "Effective cipher key must be 64 bytes (encKey ‖ macKey)")
    }
}
