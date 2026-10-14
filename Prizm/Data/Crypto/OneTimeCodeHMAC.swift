import Foundation
import CryptoKit

// MARK: - OneTimeCodeHMAC
//
// Purpose: the HMAC primitive behind time-based one-time codes (TOTP).
//
// Standards:
//   - HMAC: RFC 2104 (implemented by CryptoKit, not by this file).
//   - TOTP: RFC 6238 §1.2 allows HMAC-SHA-1, HMAC-SHA-256 and HMAC-SHA-512.
//
// Security goal: derive a short-lived code from a seed without hand-rolling any algorithm
// (Constitution §III). This file only maps the Domain algorithm name to a CryptoKit type.
//
// SHA-1 note: `Insecure.SHA1` is named "Insecure" by CryptoKit because SHA-1 collisions are
// practical. HMAC-SHA-1 does not depend on collision resistance (see RFC 6151, "Updated Security Considerations for the MD5 Message-Digest and the HMAC-MD5 Algorithms", and RFC 6194 for SHA-1),
// and RFC 6238's default is SHA-1, so it stays supported to avoid showing "unavailable" for
// most real seeds.
//
// Known limitation: the key arrives as `Data`; CryptoKit copies it into a `SymmetricKey` whose
// storage we cannot zero. The caller wipes its own copy (see `GenerateTOTPCodeUseCaseImpl`).

extension PrizmCryptoServiceImpl {

    nonisolated func hmac(_ algorithm: TOTPHashAlgorithm, key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        switch algorithm {
        case .sha1:
            return Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetricKey))
        case .sha256:
            return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey))
        case .sha512:
            return Data(HMAC<SHA512>.authenticationCode(for: message, using: symmetricKey))
        }
    }
}
