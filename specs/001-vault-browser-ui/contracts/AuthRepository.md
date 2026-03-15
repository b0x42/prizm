# Contract: AuthRepository

**Layer**: Domain (protocol) — implemented in Data layer
**Purpose**: Account authentication, session management, master password verification

---

## Protocol

```swift
/// Manages the full authentication lifecycle for a Bitwarden account.
protocol AuthRepository {

    // MARK: - Server configuration

    /// Returns the currently configured server environment (self-hosted only in v1).
    var serverEnvironment: ServerEnvironment? { get }

    /// Persists a new server environment (base URL + optional overrides).
    func setServerEnvironment(_ environment: ServerEnvironment) async throws

    /// Validates a base server URL syntactically (scheme present, trailing slash stripped).
    /// Throws `AuthError.invalidURL` if the URL is malformed.
    func validateServerURL(_ urlString: String) throws -> URL

    // MARK: - Login

    /// Initiates login with email + master password.
    /// Internally: HTTP preLogin → SDK hashPassword → HTTP /connect/token.
    /// preLogin is not exposed separately; all KDF and token exchange is encapsulated here.
    /// Returns `.success` with the authenticated Account, or `.requiresTwoFactor` if 2FA needed.
    /// Throws `.unsupported2FAMethod` if the account requires a non-TOTP 2FA method —
    /// in this case the session is invalid and the user must use a different client.
    func loginWithPassword(
        email: String,
        masterPassword: String
    ) async throws -> LoginResult

    /// Completes a TOTP two-factor login challenge.
    /// Must be called after `loginWithPassword` returns `.requiresTwoFactor(.authenticatorApp)`.
    /// `rememberDevice`: when true, server suppresses future 2FA prompts for this device (FR-050).
    func loginWithTOTP(
        code: String,
        rememberDevice: Bool
    ) async throws -> Account

    // MARK: - Unlock

    /// Unlocks a locally stored, locked vault using the master password.
    /// Performs KDF derivation locally — no network call required.
    func unlockWithPassword(_ masterPassword: String) async throws -> Account

    // MARK: - Session

    /// Returns the stored account if a Keychain session exists; nil otherwise.
    func storedAccount() async -> Account?

    /// Clears ALL Keychain data for the current user and returns the app to a blank
    /// login screen. Called on sign-out or "Sign in with a different account".
    ///
    /// Cleared: access token, refresh token, encUserKey, encPrivateKey, kdfParams,
    /// email, serverEnvironment (per-user), and activeUserId (global).
    /// After this call, the login screen MUST be blank — no pre-filled email or server URL.
    func signOut() async throws

    // MARK: - Locking

    /// Locks the vault — releases decrypted key material from memory.
    /// The Keychain session remains intact; unlock is possible without re-login.
    func lockVault() async
}
```

---

## Supporting Types

```swift
enum LoginResult {
    case success(Account)
    case requiresTwoFactor(method: TwoFactorMethod)
}

enum TwoFactorMethod {
    case authenticatorApp              // TOTP — supported in v1 (FR-016, FR-050)
    case unsupported(name: String)     // any other method — login fails; user must use a
                                       // different client. Session is invalid; return to
                                       // login screen and display FR-016 error message.
}

enum AuthError: LocalizedError {
    case invalidCredentials          // wrong email/password (login or unlock)
    case invalidTwoFactorCode        // wrong TOTP code
    case invalidURL                  // malformed self-hosted URL
    case serverUnreachable(URL)      // network unreachable or server returned non-200
    case unrecognizedServer(URL)     // server responded but is not a Bitwarden instance
    case networkUnavailable          // device has no internet connection
    case unsupported2FAMethod(String)// 2FA type not supported in v1
}
```

---

## Implementation Notes (Data Layer)

The Domain protocol above is implementation-agnostic. The Data layer (`AuthRepositoryImpl`) uses
this call sequence under the hood:

**Login**: HTTP POST `/accounts/prelogin` → `BitwardenCryptoServiceImpl.hashPassword(purpose: .serverAuthorization)`
→ HTTP POST `/connect/token` → `BitwardenCryptoServiceImpl.initializeUserCrypto(masterPassword:email:kdfParams:encUserKey:encPrivateKey:)`
→ HTTP GET `/sync` → `BitwardenCryptoServiceImpl.decryptList(ciphers:)` (personal ciphers only; org ciphers
skipped — org crypto is NOT called in v1)

**Unlock** (on relaunch after quit — vault in-memory is gone): `BitwardenCryptoServiceImpl.initializeUserCrypto(...)` to
re-derive key material from Keychain (`encUserKey`, `encPrivateKey`, `kdfParams`) — no network for KDF.
Then `SyncRepository.sync()` is called to re-populate the vault (network required).

`BitwardenCryptoServiceImpl` has no HTTP layer — all network calls are made by `BitwardenAPIClient` (Data layer).

## Keychain Keys

All keys are namespaced by userId to support future multi-account.
Format: `bw.macos:{userId}:{key}` for per-account items; `bw.macos:{key}` for global items.

| Key string | Content |
|------------|---------|
| `bw.macos:{userId}:accessToken` | OAuth2 access token (Bearer) |
| `bw.macos:{userId}:refreshToken` | OAuth2 refresh token |
| `bw.macos:{userId}:encUserKey` | Encrypted user symmetric key (from token response `Key`) |
| `bw.macos:{userId}:encPrivateKey` | Encrypted RSA private key (from token response `PrivateKey`) |
| `bw.macos:{userId}:kdfParams` | Serialised KDF params (for local unlock) |
| `bw.macos:{userId}:email` | User email (for display on unlock screen) |
| `bw.macos:{userId}:serverEnvironment` | Serialised `ServerEnvironment` (base URL + overrides) |
| `bw.macos:activeUserId` | GUID of the active user; cleared on `signOut()` |
| `bw.macos:deviceIdentifier` | Stable UUID generated on first launch (UUID v4); never cleared |

All items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
No item uses `kSecAttrSynchronizable = true`.

## Crypto Service Key Material Lifecycle

`BitwardenCryptoServiceImpl` (a Data layer actor) holds all in-memory derived key material
(master key, stretched key, symmetric vault key, RSA private key). Lifecycle rules:

- **Populated**: on `initializeUserCrypto()` (login or unlock)
- **Alive**: for the duration of the unlocked session
- **Cleared**: on `lockVault()` or `signOut()` — the actor zeroes all key material from memory.
  Vault data in `VaultRepositoryImpl` is also cleared.
- **Never persisted**: key material is never written to disk or Keychain.

## Server Environment Persistence

`ServerEnvironment` is stored **per user** under `bw.macos:{userId}:serverEnvironment`
(JSON-encoded). It is written on first successful login.

On app launch:
- If `activeUserId` is set → show unlock screen with stored email pre-filled.
- If `activeUserId` is nil (never logged in, or after sign-out) → show login screen, **blank**.

On `signOut()`: `serverEnvironment`, `email`, and `activeUserId` are all cleared.
The login screen that follows is completely blank — no pre-filled email or server URL.
The user must re-enter the server URL and email from scratch.
