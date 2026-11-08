import XCTest
@testable import Prizm

/// Known-answer tests for the master key derivation against Bitwarden's reference implementation.
///
/// Vectors: bitwarden/sdk-internal, `crates/bitwarden-crypto/src/keys/kdf.rs`
/// (`test_master_key_derive_pbkdf2`, `test_master_key_derive_argon2`). Password `67t9b5g67$%Dh89n`,
/// "salt" `test_key` (for the server that is the account email).
///
/// Why these exist: Bitwarden hashes the email with SHA-256 to get the Argon2id salt, and the server
/// reports the Argon2 memory cost in MiB while Argon2 itself takes KiB. Prizm 1.5.0 did neither, so
/// the derived key differed from every other Bitwarden client and every login to an Argon2id account
/// failed with "Username or password is incorrect". The older KDF tests only checked the key length and
/// determinism, so they could not notice.
@MainActor
final class MasterKeyVectorTests: XCTestCase {

    private var sut: PrizmCryptoService!

    private let password = Data("67t9b5g67$%Dh89n".utf8)
    /// Already lowercase: `makeMasterKey` lowercases the email like Bitwarden does.
    private let email = "test_key"

    override func setUp() async throws {
        try await super.setUp()
        sut = PrizmCryptoServiceImpl()
    }

    // MARK: - PBKDF2-SHA256

    func testPbkdf2MasterKeyMatchesBitwardenSdkVector() async throws {
        let kdf = KdfParams(type: .pbkdf2, iterations: 10_000, memory: nil, parallelism: nil)
        let key = try await sut.makeMasterKey(password: password, email: email, kdf: kdf)

        let expected: [UInt8] = [
            31, 79, 104, 226, 150, 71, 177, 90, 194, 80, 172, 209, 17, 129, 132, 81,
            138, 167, 69, 167, 254, 149, 2, 27, 39, 197, 64, 42, 22, 195, 86, 75,
        ]
        XCTAssertEqual([UInt8](key), expected)
    }

    // MARK: - Argon2id

    /// `memory` is the server's MiB value (32 here), not KiB.
    func testArgon2idMasterKeyMatchesBitwardenSdkVector() async throws {
        let kdf = KdfParams(type: .argon2id, iterations: 4, memory: 32, parallelism: 2)
        let key = try await sut.makeMasterKey(password: password, email: email, kdf: kdf)

        let expected: [UInt8] = [
            207, 240, 225, 177, 162, 19, 163, 76, 98, 106, 179, 175, 224, 9, 17, 240,
            20, 147, 237, 47, 246, 150, 141, 184, 62, 225, 131, 242, 51, 53, 225, 242,
        ]
        XCTAssertEqual([UInt8](key), expected)
    }

    /// The email is lowercased before use, so its casing must not change the derived key.
    func testMasterKeyIgnoresEmailCase() async throws {
        let kdf = KdfParams(type: .argon2id, iterations: 4, memory: 32, parallelism: 2)
        let lower = try await sut.makeMasterKey(password: password, email: "test_key", kdf: kdf)
        let mixed = try await sut.makeMasterKey(password: password, email: "Test_KEY", kdf: kdf)
        XCTAssertEqual(lower, mixed)
    }
}
