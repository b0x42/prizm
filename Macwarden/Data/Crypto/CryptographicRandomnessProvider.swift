import Foundation
import Security

/// Cryptographically secure random byte generator backed by `SecRandomCopyBytes`.
///
/// **Security goal:** Provide CSPRNG-quality randomness for password and passphrase generation.
/// **Algorithm:** `SecRandomCopyBytes` (Security.framework) — Apple's standard CSPRNG API,
/// documented as suitable for generating cryptographic keys and nonces.
/// **Reference:** Apple Security framework documentation; NIST SP 800-90A Rev 1.
///
/// This type lives in the Data layer because it depends on Security.framework,
/// which is restricted from the Domain layer per project architecture rules.
struct CryptographicRandomnessProvider: RandomnessProvider {

    enum Error: Swift.Error {
        case generationFailed(status: OSStatus)
    }

    func randomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw Error.generationFailed(status: status)
        }
        return bytes
    }
}
