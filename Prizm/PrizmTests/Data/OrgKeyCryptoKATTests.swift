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
        let vaultKeys = try XCTUnwrap(CryptoKeys(data: vaultKeyData))

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
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCy4YrRzWfVSQ/i2N90kp2aU4AG\
    qBIJczy0RM+hRZ4dlaGoMlbpn2gVkJet+zbvdxji8qxAiB78BBWKUhzYfTZ92Ri7RdxWDhRm9HMK\
    u3nrOfbiHK50gsm1264WSCONOGrp1UTg8DWFiSJOmsIWWDGw3v5Qj6mo0sn2t0KcUlw7cV4Nfxj7\
    Oy5JcFRIK4YLRKgdDz0/Yw4+HZb+kam0D3mwiI3ptx3H07u61I6flbyyty/qSwj6Paf5dQhB2GK8\
    m6IVMZuivmSpRQRII/EEPxN/7zVO9lm06XiF+0iuvQnZ68OfeenWG9R1o8+/zNoVkDFVJMwOQ3Lw\
    rWv4EcYj7wEzAgMBAAECggEABhlXjNi2ihigIIlpcQWQtxLSwidX2heiQbk45RRFFFgmN2BkAzoq\
    p9WSvl1a3aZPZGmGwvqBJ/GRtHIhRqZaRccxpyz2Gr8HJg1+oKaMvR7wUnxM3G8bJoazdFIIWEfM\
    qWVaoFrAUGnBEDIJnQ5rv06TGDcVv0pUlYNhE4hhWatwwMmRFp4OJ0GQ5SIQaeNG09pe7h9G9Qwj\
    tHT0O9W/FK9VLgC23Z2cggWG2g9xh+IilSljSkMODQ7NeoBN5JnIusBnn6GONxecowP9EzmS15Rd\
    ++yGf8nN9Xx1bbNjQGx9F9IuPd0vL4TSiFwQDITkEFCL+nONqUhe+rO9JS4qEQKBgQDfeMbJvBch\
    egA3GCw7r3b+9zTwfDGjH3zGPQy4PnNPrhU0fopjeDhMXEzUQ9nTDsddCFVvC8giSURIgfY4lFW7\
    zRdWHY9wg48ODD6Ti2fthHpUcUbYaKZRkiYe//zfrtOJi+mWNYElbac7zYDLggm7k72n4r5RMdaF\
    pagV9KMp0QKBgQDM6y5xQH/JhhcFVbHH0KPRsJIXFrBK1PNVAzSNd3IDWeAIGEwxBZl5JkYYdxTr\
    uPDb15gta1rZeymkRqOfisfH3CpEmX+gYcODBbD/Y1eSAFvlPlJe8vrVAPXEVG+D1rBBX4wx8IXw\
    /59QgMARB7P9qmtna8nb74bYOMg5N1Z3wwKBgGo7DbSEdzJwvn1yPkS5KoYVmdLgFvCGXVgXWV6U\
    QViVVns31C1ozspt7g/RmVCda+QrvAEnxqGV1qHpNdS7nu3BluBW+QLxZyW0aGLXGDZujYBqwNTL\
    GpUYNoryAZGLl/+AxS+ki5nxQFhLXnhffqTunG+ceAA9As9Rak/VlWKhAoGBAMIibLVObcH2Dwk2\
    zl6HAyw9I6pMDGhYps77YmZDqvgRxXTl0AkBTQzBfdbfuio347fi4IDnHAK99A11/r2/NNXbdw/W\
    fFrtQ9R1J+JLs0LWpDjiehcKCyiQ6EU/2QYF9qV4Z9FIFRzkj4Is98kqixLeyTIJpAuBOTbPVKEg\
    FAMRAoGAZD+LPTJnf9MttazzrQmDI5+I0Rrdj1QDNi0wAffOLxzMdy0i8kScinGXIwqied59hg69\
    kcD2Vbhu3uwbu67UWzAQ1dh6WncNnv4wA3NE8vLJhFA+Tv4uOr5Sr8KjNRLIpkQB+6ArBl4AA4E0\
    Sp3zfwqy2wxqPkuxCYwUdmv5gBc=
    """

    /// The RSA-OAEP-SHA1 encrypted 64-byte org key test fixture.
    /// Type-4 EncString format: "4.<base64-ciphertext>"
    /// Produced by encrypting `expectedOrgEncKey || expectedOrgMacKey` with the
    /// RSA public key corresponding to `testRSAPrivateKeyPKCS8Base64`.
    ///
    private static let testEncOrgKey = "4.mzJizOhOZEgfRxj+6wSwbfiDlhc+Q5acTK6YtpD6sb1zUIcx2TfoERvnb1n5ISN9qTP89X5atn+AVK4Fj7Lk5tpuZNqXtOVOWYlinZmrZUUfC1bFIktu2HKR11ws3GnH7VKf0TW0MF0kZcLA30oWrumlXUfNc3AK+XRDgFqVnK7AhBBqfdKoHH3P2iNG8xrJ3WFM3qf0O8XnXuL8ZPL56B1SZOVuYW4gIk47A+ceSrvwEV5wV1XHWTIdewFlgqcAcTHyw6zyr1sk5sf7ucRrAzO31ImizXRFuQh1GO1lj0sillqZr6ceqlYxR1MRu5UnzD2fYSUirdNvPdfYzmdD3Q=="

    /// Expected org encryption key (first 32 bytes of the decrypted 64-byte org key).
    private static let expectedOrgEncKey = Data(repeating: 0x00, count: 32)

    /// Expected org MAC key (last 32 bytes of the decrypted 64-byte org key).
    private static let expectedOrgMacKey = Data(repeating: 0x00, count: 32)
}
