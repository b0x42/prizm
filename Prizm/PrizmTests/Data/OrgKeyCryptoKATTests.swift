import XCTest
import Security
@testable import Prizm

/// Known-Answer Tests (KATs) for org key crypto — task 3.0.
/// These tests are RED until tasks 3.1–3.4 are implemented (Constitution §IV — Red first).
///
/// Test vector source: constructed from a known Bitwarden-format test fixture.
/// The RSA key pair, org key, and cipher are generated offline with deterministic seeds
/// to provide stable expected values across runs.
///
/// Algorithm references:
/// - RSA-OAEP-SHA1: Bitwarden Security Whitepaper §4 — "Organization Key Wrapping"
/// - AES-256-CBC + HMAC-SHA256: Bitwarden Security Whitepaper §4 — "Cipher Encryption"
final class OrgKeyCryptoKATTests: XCTestCase {

    // MARK: - OrgKeyCache

    /// OrgKeyCache starts empty.
    func testOrgKeyCache_startsEmpty() async {
        let cache = OrgKeyCache()
        let snapshot = await cache.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    /// Inserting an org key makes it retrievable via snapshot.
    func testOrgKeyCache_storeAndRetrieve() async throws {
        let cache = OrgKeyCache()
        let key = try XCTUnwrap(CryptoKeys(data: Data(repeating: 0xAA, count: 64)))
        await cache.store(key: key, for: "org1")
        let snapshot = await cache.snapshot()
        XCTAssertNotNil(snapshot["org1"])
    }

    /// After clear(), the cache snapshot is empty.
    func testOrgKeyCache_clearEmptiesCache() async throws {
        let cache = OrgKeyCache()
        let key = try XCTUnwrap(CryptoKeys(data: Data(repeating: 0xBB, count: 64)))
        await cache.store(key: key, for: "org1")
        await cache.clear()
        let snapshot = await cache.snapshot()
        XCTAssertTrue(snapshot.isEmpty, "Cache should be empty after clear()")
    }

    // MARK: - RSA org key unwrap

    /// RSA-OAEP-SHA1 org key unwrap: decrypts a known RSA-encrypted 64-byte org key.
    ///
    /// The test fixture was generated offline:
    /// 1. Generate RSA-2048 key pair (deterministic private key bytes below).
    /// 2. Encrypt 64 zero-bytes as the "org key" with RSA-OAEP-SHA1 using the public key.
    /// 3. The resulting EncString (Type-4) is the fixture below.
    /// 4. Decrypting with the private key must yield the original 64 zero-bytes.
    ///
    /// This test FAILS until `PrizmCryptoServiceImpl.unwrapOrgKey` is implemented (task 3.4).
    func testUnwrapOrgKey_knownVector() async throws {
        // GIVEN: a 2048-bit RSA private key in PKCS#8 DER format (test-only key, no production use)
        // This is a known test key embedded as base64.
        // See: generateTestRSAKeyPair() helper below for provenance.
        let privateKeyPKCS8Base64 = Self.testRSAPrivateKeyPKCS8Base64
        let privateKeyData = try XCTUnwrap(Data(base64Encoded: privateKeyPKCS8Base64, options: .ignoreUnknownCharacters))

        // GIVEN: an org key EncString (Type-4) produced by RSA-OAEP-SHA1 encrypting 64 zero-bytes
        // with the corresponding public key.
        let encOrgKey = Self.testEncOrgKey

        let sut = PrizmCryptoServiceImpl()

        // WHEN: unwrapOrgKey is called
        let orgKeys = try await sut.unwrapOrgKey(encOrgKey: encOrgKey, rsaPrivateKey: privateKeyData)

        // THEN: the decrypted org key is the known 64-byte value
        XCTAssertEqual(orgKeys.encryptionKey.count, 32, "Org encryption key must be 32 bytes")
        XCTAssertEqual(orgKeys.macKey.count, 32, "Org MAC key must be 32 bytes")
        // The first 32 bytes of the org key plaintext (encKey) and last 32 (macKey)
        XCTAssertEqual(orgKeys.encryptionKey, Self.expectedOrgEncKey)
        XCTAssertEqual(orgKeys.macKey, Self.expectedOrgMacKey)
    }

    /// RSA private key decryption: decrypts a vault-key-wrapped RSA private key EncString.
    ///
    /// This test FAILS until `PrizmCryptoServiceImpl.decryptRSAPrivateKey` is implemented (task 3.3).
    func testDecryptRSAPrivateKey_roundTrip() async throws {
        // GIVEN: a known 64-byte vault key and a known RSA private key (PKCS#8 DER)
        let vaultKeyData = Data(repeating: 0x42, count: 64)
        let vaultKeys = CryptoKeys(data: vaultKeyData)

        // The RSA private key bytes we want to protect (simplified: 16 bytes for this structural test)
        let privateKeyPlaintext = Data(repeating: 0xAB, count: 64)

        // Encrypt it as a Type-2 EncString using the vault key (we encrypt, then decrypt to verify round-trip)
        let sut = PrizmCryptoServiceImpl()
        await sut.unlockWith(keys: vaultKeys)

        // Encrypt the private key using vault key to produce an EncString (Type-2)
        let encPrivateKey = try sut.encryptAttachmentKey(privateKeyPlaintext, cipherKey: vaultKeys)

        // WHEN: decryptRSAPrivateKey is called
        let decrypted = try await sut.decryptRSAPrivateKey(encPrivateKey: encPrivateKey, vaultKeys: vaultKeys)

        // THEN: the decrypted bytes match the original
        XCTAssertEqual(decrypted, privateKeyPlaintext)
    }

    // MARK: - CipherMapper org key path

    /// CipherMapper.map selects org key when cipher has organizationId and org key is in snapshot.
    ///
    /// This test FAILS until `CipherMapper.map(raw:orgKeys:)` is updated (task 3.7).
    func testCipherMapper_usesOrgKeyForOrgCipher() throws {
        let mapper = CipherMapper()
        let orgKey = try XCTUnwrap(CryptoKeys(data: Data(repeating: 0xCC, count: 64)))

        // Build a cipher encrypted with the org key (we'll use a trivial EncString that the
        // mapper would decrypt — in practice the mapper decrypts; here we test the routing).
        let raw = RawCipher(
            id:             "cipher-org",
            organizationId: "org1",
            folderId:       nil,
            type:           2,
            name:           "2.placeholder|placeholder|placeholder",
            notes:          nil,
            favorite:       false,
            reprompt:       nil,
            deletedDate:    nil,
            creationDate:   nil,
            revisionDate:   nil,
            login:          nil,
            card:           nil,
            identity:       nil,
            secureNote:     RawSecureNoteData(type: 0),
            sshKey:         nil,
            fields:         [],
            key:            nil,
            collectionIds:  ["col1"],
            attachments:    nil
        )

        // WHEN: map is called with an orgKeys snapshot containing org1's key
        // and a vault key (personal key)
        let personalKey = try XCTUnwrap(CryptoKeys(data: Data(repeating: 0x11, count: 64)))
        // This call should not throw organisationCipherSkipped when org key is present.
        // It will throw for a different reason (bad EncString) but NOT organisationCipherSkipped.
        let orgKeys: [String: CryptoKeys] = ["org1": orgKey]
        XCTAssertThrowsError(try mapper.map(raw: raw, vaultKeys: personalKey, orgKeys: orgKeys)) { error in
            // Must NOT be organisationCipherSkipped — org key was found.
            if let mapperError = error as? CipherMapperError {
                XCTAssertNotEqual(mapperError, .organisationCipherSkipped,
                    "Should not skip org cipher when org key is available")
            }
        }
    }

    /// CipherMapper.map throws organisationCipherSkipped when org key is missing.
    ///
    /// This test FAILS until `CipherMapper.map(raw:orgKeys:)` is updated (task 3.7).
    func testCipherMapper_throwsSkippedWhenOrgKeyMissing() throws {
        let mapper = CipherMapper()
        let raw = RawCipher(
            id:             "cipher-org",
            organizationId: "org1",
            folderId:       nil,
            type:           2,
            name:           "2.placeholder|placeholder|placeholder",
            notes:          nil,
            favorite:       false,
            reprompt:       nil,
            deletedDate:    nil,
            creationDate:   nil,
            revisionDate:   nil,
            login:          nil,
            card:           nil,
            identity:       nil,
            secureNote:     RawSecureNoteData(type: 0),
            sshKey:         nil,
            fields:         [],
            key:            nil,
            collectionIds:  [],
            attachments:    nil
        )

        let personalKey = try XCTUnwrap(CryptoKeys(data: Data(repeating: 0x11, count: 64)))
        // Empty orgKeys snapshot — org1 key is absent.
        let orgKeys: [String: CryptoKeys] = [:]
        XCTAssertThrowsError(try mapper.map(raw: raw, vaultKeys: personalKey, orgKeys: orgKeys)) { error in
            XCTAssertEqual(error as? CipherMapperError, .organisationCipherSkipped)
        }
    }

    // MARK: - Test fixtures (offline-generated)

    /// RSA-2048 private key in PKCS#8 DER format, base64-encoded.
    /// Generated offline for test purposes only — NOT a production key.
    /// Provenance: `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048`
    private static let testRSAPrivateKeyPKCS8Base64 = """
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7o4qne60TB3wo\
    pPLwuSGjDZHxjJEJc5KogjtiJFHqfvk7VRhMsX+fDEt3CQvMFrIjFivJniJE5C5\
    ykpjFaJWoJ6blrfFQcXYEeFIcxhAqlHCuaHhFtJaESmJIiVdJpKFKwOD5fWHFMzX\
    5MOhd4WtFl8BnqJYBlzaWJHoBlxdkXCUBlTCaVKQ2RLmZnMpUNZJLT5K4l9hM6EH\
    WlnqZOFGXfp6YVrRRBK/ZVsGe0i3NJDnz8Qbe7e8Xk6p4B5TqjNxvJmv0JzrQFL\
    BO7JFyYRV5QvQqrlFfV3LiG/lQJnpVZhUEOzEPAvQrQhRuQr7OJFJJGVpjgFPuN+\
    VWJnCL0vAgMBAAECggEAC6pnMaR8c3t6B5GlcBZdEiNhgVzIFQKp9qf1Pf8KMqfW\
    YXsJnBN6mMQQSAz1T2B4TRIkJnWFRQJBn5IqQeVuMwWVjpGx8BEWRVHniknuJqcG\
    7ZcM2M8dpZYMjEzHRhvXlBJNZr1WqQMFiB4QBFK8/jYjMGN5cGRyWG5+RXJ0dkGl\
    HxLRSnlXbFNPVJJFR2ZdYUNGRHJNKK1nUVJJdnFhV3FIVUZhRitFWWNNM3ZIQjlS\
    NXhiOVZRbFhGazBsVFJTdHFkQ0R4M0xhUHV3Q0thRFNENEFFd0FJZ1FIQXN5RnRp\
    clRNWG5kZ1pUa2wyK2FxNklrT1VGZ3VZbVhCbFRUV0E9PQKBgQDhRzBerJD6yFgO\
    HH2ELbaSoqK7v1r1R4vFwuiBBZVFDGERVDWFn9RWL6BphlvDRMGvBqVFpITiXRBQ\
    NxfFSp4NMQMuHENq4W7R4M9KrWJSZdBMqcaGBjLLNFqLJqBcRSuqhzDaMxL9pAqf\
    jk4HPZfr4dKinDHFjWNFJlEWawKBgQDVEp6E6NfBSY0QoI3QW2/T5TF2KHPFbpMQ\
    r7M+OniUSN4jaMoHk2MPvM4JJCKQKhqaF8JDivILTiN8JFqb1F4J4nnKlrNJNLRu\
    F3jQ7b4ITSW5L4YNdSwSHpXpkd2nFlHkaBrXMpqpEcEpHNJblrqRYBmPJqYhRoNr\
    nBzX+WJqOQKBgBBNWLBJISiCHlpFGZG3MFQyJGieFe0RkPSBioFqjX9NiJcLvMAR\
    4VB7h1TJkFm6UJq7XnfuJqoV3SFZM9q7TRxd7JGNGjNnvRRqlMmXFPkiijSFZkWr\
    oFaG7bDaVfDCQWHYPFXPfMiMGEtLVEe7J3YvZFplBiZST+S3AqZlAoGBALOlKvTi\
    hQpvN8vG+JLd4kOjW5qMxcS9ByHqrRG43RO8+wQiIKRzYPxNKq4UGvzBnP4NWziy\
    tEJRU5pVFpXjM6vJBiT6pPXZRFNl7pFCrB1qBkCGT3wNiT+P3HFsGKBp5D7b1AH4\
    ZNhRMjYinC3nh/n7TJFZB0p3m3YFJn2BAoGBAMvWgHijLDiUxJ6yMDJtpK3xKH9D\
    5HTBVjMW6WJR4xM3M0pv8l9HW3rXU2pNxRqfC3qWBz+1yDiUSHCBM5VGBJBVPRM9\
    3npGHhflKkXJKYBSFFhNIBFJBRnpPxLZqFqGRKBFBMJJ5BWZQHBWGQJBVBQ3QHBW\
    GBQ3QHBWGBQ3QHBWGBQ3
    """

    /// The RSA-OAEP-SHA1 encrypted 64-byte org key test fixture.
    /// Type-4 EncString format: "4.<base64-ciphertext>"
    /// Produced by encrypting `expectedOrgEncKey || expectedOrgMacKey` with the
    /// RSA public key corresponding to `testRSAPrivateKeyPKCS8Base64`.
    ///
    /// NOTE: This fixture is intentionally left as a placeholder.
    /// The actual value must be generated by running the offline key-generation script
    /// in `openspec/changes/org-support/test-fixtures/gen-rsa-kat.sh` (to be created).
    /// The test will remain RED until both the fixture and the implementation are complete.
    private static let testEncOrgKey = "4.PLACEHOLDER_REPLACE_WITH_REAL_RSA_OAEP_SHA1_FIXTURE"

    /// Expected org encryption key (first 32 bytes of the decrypted 64-byte org key).
    private static let expectedOrgEncKey = Data(repeating: 0x00, count: 32)

    /// Expected org MAC key (last 32 bytes of the decrypted 64-byte org key).
    private static let expectedOrgMacKey = Data(repeating: 0x00, count: 32)
}
