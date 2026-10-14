# Contract: Domain and Crypto Protocols

Signatures are the contract the tests are written against. Names may change during implementation as long as the behavior below holds.

## TOTPSeedParser (Domain, Foundation only)

```swift
enum TOTPSeedParser {
    static func parse(_ seed: String) throws -> TOTPConfiguration
}
```

| Input | Result |
|---|---|
| `"JBSW Y3DP EHPK 3PXP"` (spaces, any case) | SHA-1, 6 digits, 30 s, secret decoded from base32 |
| `"otpauth://totp/Acme:me?secret=JBSWY3DPEHPK3PXP&digits=8&period=60&algorithm=SHA256"` | SHA-256, 8 digits, 60 s |
| `otpauth://totp/...` with missing optional parameters | Defaults (SHA-1, 6, 30) |
| `""`, whitespace | throws `emptySeed` |
| Invalid base32 characters, or no secret | throws `invalidSecret` |
| `steam://...`, `otpauth://hotp/...` | throws `unsupportedScheme` |
| `algorithm=MD5`, `digits=5`, `digits=9`, `period=0` | throws `unsupportedParameter` |

The parser never logs or includes the seed in an error.

## GenerateTOTPCodeUseCase (Domain protocol, impl in Data)

```swift
protocol GenerateTOTPCodeUseCase: Sendable {
    /// Returns the code valid at `date` for the stored `seed`.
    func execute(seed: String, at date: Date) async throws -> TOTPCode
}
```

Behavior:

- Counter is `floor(unixSeconds / period)`, encoded as an 8-byte big-endian value (RFC 6238 §4, RFC 4226 §5.2).
- Dynamic truncation per RFC 4226 §5.3, then modulo `10^digits`, zero-padded.
- `secondsRemaining = period - (unixSeconds mod period)`.
- Throws `TOTPError` from the parser. Never throws for a locked vault: the operation needs no vault key.
- Pure with respect to its arguments: same seed and date give the same result.

## PrizmCryptoService addition (Data)

```swift
func hmac(_ algorithm: TOTPHashAlgorithm, key: Data, message: Data) -> Data
```

- Returns the full MAC (20, 32, or 64 bytes).
- Stateless: does not read or require vault keys.
- Implemented with CryptoKit `HMAC<Insecure.SHA1>`, `HMAC<SHA256>`, `HMAC<SHA512>`. Doc comment cites RFC 2104, RFC 6238 §1.2 (SHA-1 default), and explains why SHA-1 is acceptable inside HMAC.
- `MockPrizmCryptoService` gains a matching method for tests.

## Known-answer vectors the tests must include

RFC 6238 Appendix B, 8 digits:

| Time (s) | SHA-1 | SHA-256 | SHA-512 |
|---|---|---|---|
| 59 | 94287082 | 46119246 | 90693936 |
| 1111111109 | 07081804 | 68084774 | 25091201 |
| 1111111111 | 14050471 | 67062674 | 99943326 |
| 1234567890 | 89005924 | 91819424 | 93441116 |
| 2000000000 | 69279037 | 90698825 | 38618901 |
| 20000000000 | 65353130 | 77737706 | 47863826 |

Seeds (ASCII): SHA-1 `12345678901234567890`; SHA-256 `12345678901234567890123456789012`; SHA-512 `1234567890123456789012345678901234567890123456789012345678901234`.

Verify these values against the RFC text when writing the tests (Red phase), not from this table alone.
