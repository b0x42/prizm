## Purpose

Defines support for Bitwarden Cloud (US and EU regions) alongside self-hosted Vaultwarden instances. Scope: single active account; user chooses server at login. Data layer is designed for multi-account from day one; multi-account UI is deferred.

## Complexity Tracking

Per §I and §VI, non-trivial architectural decisions and AppKit exceptions must be justified here.

No AppKit exceptions are required for this change. New device OTP verification uses a native SwiftUI text field — no web rendering is needed.

> **Spike finding (2026-04-20)**: hCaptcha was removed from Bitwarden Cloud server and all clients in [PR #1861](https://github.com/bitwarden/ios/pull/1861) (merged 2025-08-20, PM-24667). The `WKWebView` modal originally planned for this change is no longer required. New device OTP verification (email OTP on first login from an unrecognized device) is the current mechanism.

## Baseline (what already exists)

- `ServerEnvironment` (`Domain/Entities/Account.swift`) — `base: URL`, `overrides: ServerURLOverrides?`, computed `apiURL`/`identityURL`/`iconsURL`. No cloud/region discriminant.
- `AuthRepository.setServerEnvironment(_ env:)` — declared and implemented; only calls `apiClient.setBaseURL(environment.base)`.
- `PrizmAPIClient` actor — single `baseURL`; ~32 endpoint methods all use `base.appendingPathComponent(...)`.
- `LoginView` / `LoginViewModel` — single `serverURL: String` field, static subtitle "Self-hosted vault".
- `bw.macos:{userId}:serverEnvironment` — Keychain key in use for self-hosted accounts.

---

### Requirement: Login UI presents a three-way server picker

The `LoginView` SHALL replace the static subtitle "Self-hosted vault" and single server URL field with a three-option picker:

1. **Bitwarden Cloud (US)** — hides the server URL field
2. **Bitwarden Cloud (EU)** — hides the server URL field
3. **Self-hosted** — shows the server URL field as it exists today

When a cloud option is selected, no URL entry is required or shown. When "Self-hosted" is selected, the server URL field is shown and behaves as today. The last-used selection SHALL be persisted to `UserDefaults` under the key `com.prizm.login.lastServerType` (raw `String` value of `ServerType`) and restored when `LoginViewModel` is initialised.

#### Scenario: Picker is visible on the login screen
- **WHEN** `LoginView` is displayed
- **THEN** a picker offering "Bitwarden Cloud (US)", "Bitwarden Cloud (EU)", and "Self-hosted" SHALL be visible above the email field

#### Scenario: Cloud selection hides the server URL field
- **WHEN** the user selects "Bitwarden Cloud (US)" or "Bitwarden Cloud (EU)"
- **THEN** the server URL field SHALL be hidden
- **AND** the email and master password fields SHALL remain visible

#### Scenario: Self-hosted selection shows the server URL field
- **WHEN** the user selects "Self-hosted"
- **THEN** the server URL field SHALL be visible and editable
- **AND** any previously entered URL SHALL be restored

#### Scenario: Sign In button enabled for cloud without server URL
- **GIVEN** the user has selected "Bitwarden Cloud (US)" or "Bitwarden Cloud (EU)"
- **WHEN** email and master password are both non-empty
- **THEN** the Sign In button SHALL be enabled regardless of `serverURL`

#### Scenario: Sign In button still requires server URL for self-hosted
- **GIVEN** the user has selected "Self-hosted"
- **THEN** the Sign In button SHALL remain disabled until `serverURL`, email, and password are all non-empty

#### Scenario: Last-used selection restored on relaunch
- **GIVEN** the user last chose "Bitwarden Cloud (EU)" before quitting
- **WHEN** `LoginView` appears on the next launch
- **THEN** the picker SHALL default to "Bitwarden Cloud (EU)"

---

### Requirement: `ServerEnvironment` extended with three-case `ServerType`

`ServerEnvironment` SHALL gain a `ServerType` enum with cases `cloudUS`, `cloudEU`, and `selfHosted`. The computed properties SHALL return the following canonical URLs per case:

| `serverType` | `apiURL` | `identityURL` | `iconsURL` |
|---|---|---|---|
| `cloudUS` | `https://api.bitwarden.com` | `https://identity.bitwarden.com` | `https://icons.bitwarden.net` |
| `cloudEU` | `https://api.bitwarden.eu` | `https://identity.bitwarden.eu` | `https://icons.bitwarden.net` |
| `selfHosted` | `{base}/api` (or override) | `{base}/identity` (or override) | `{base}/icons` (or override) |

> **Reference**: Endpoint URLs confirmed via [Bitwarden's official documentation](https://bitwarden.com/help/bitwarden-addresses/).
>
> **Out of scope**: `events`, `scim`, `sso`, and `push` endpoints listed in Bitwarden's documentation are enterprise/admin services. `PrizmAPIClient` does not call any of them; they are not modelled in `ServerEnvironment` and are explicitly excluded from this change.

Cloud cases SHALL ignore `overrides` and SHALL ignore `base` for URL routing. `selfHosted` behaviour is unchanged. Existing Keychain records without a `serverType` key SHALL decode as `selfHosted`.

`ServerType` SHALL be a `String`-backed `RawRepresentable` enum with fixed raw values: `"cloudUS"`, `"cloudEU"`, `"selfHosted"`. These raw values are part of the Keychain storage contract and MUST NOT be renamed after any release that has written Keychain data.

`ServerEnvironment` SHALL expose static factory methods for cloud cases that set `base` to a sentinel value (`https://bitwarden.com`) so the struct invariant is satisfied without exposing a meaningless URL to callers:

```swift
static func cloudUS() -> ServerEnvironment
static func cloudEU() -> ServerEnvironment
```

The computed properties (`apiURL`, `identityURL`, `iconsURL`) SHALL switch on `serverType` and return hardcoded cloud URLs for cloud cases, falling back to `base`-derived values only for `selfHosted`. `base` MUST NOT be used for URL routing when `serverType != .selfHosted`.

#### Scenario: cloudUS returns US canonical URLs
- **GIVEN** a `ServerEnvironment` with `serverType == .cloudUS`
- **THEN** `apiURL` SHALL equal `https://api.bitwarden.com`
- **AND** `identityURL` SHALL equal `https://identity.bitwarden.com`
- **AND** `iconsURL` SHALL equal `https://icons.bitwarden.net`

#### Scenario: cloudEU returns EU canonical URLs
- **GIVEN** a `ServerEnvironment` with `serverType == .cloudEU`
- **THEN** `apiURL` SHALL equal `https://api.bitwarden.eu`
- **AND** `identityURL` SHALL equal `https://identity.bitwarden.eu`
- **AND** `iconsURL` SHALL equal `https://icons.bitwarden.net` (global CDN; no EU-specific icons endpoint exists)

#### Scenario: selfHosted returns URL-derived values
- **GIVEN** a `ServerEnvironment` with `serverType == .selfHosted` and `base = https://vault.example.com`
- **THEN** `apiURL` SHALL equal `https://vault.example.com/api`
- **AND** `identityURL` SHALL equal `https://vault.example.com/identity`
- **AND** `iconsURL` SHALL equal `https://vault.example.com/icons`

#### Scenario: Legacy record decoded as selfHosted
- **GIVEN** a stored JSON record with no `serverType` key
- **WHEN** decoded from Keychain
- **THEN** `serverType` SHALL be `selfHosted`

---

### Requirement: `LoginUseCase.execute` accepts `ServerEnvironment`

`LoginUseCase.execute` SHALL change its signature from `execute(serverURL: String, email: String, masterPassword: Data)` to `execute(environment: ServerEnvironment, email: String, masterPassword: Data)`. `LoginViewModel` is responsible for constructing the correct `ServerEnvironment` before calling the use case:

```swift
// Cloud
let environment = ServerEnvironment.cloudUS()   // or .cloudEU()

// Self-hosted
let environment = ServerEnvironment(base: url, overrides: nil)
```

`LoginUseCaseImpl` SHALL call `auth.validateServerURL` **only** when `environment.serverType == .selfHosted`. Cloud environments SHALL skip URL validation entirely — they use hardcoded canonical URLs with no user-supplied string to validate.

The internal URL construction (`URL(string: trimmed)`) in `LoginUseCaseImpl` is removed; the environment is passed directly to `auth.setServerEnvironment(environment)`.

`LoginViewModel` retains responsibility for URL string validation feedback (empty field, non-HTTPS warning) before constructing the `ServerEnvironment` — this is UI-layer input validation, distinct from the use-case-layer server reachability check.

#### Scenario: Cloud login skips URL validation
- **GIVEN** `LoginViewModel` constructs `ServerEnvironment.cloudUS()`
- **WHEN** `LoginUseCase.execute(environment:email:masterPassword:)` is called
- **THEN** `auth.validateServerURL` SHALL NOT be called
- **AND** `auth.setServerEnvironment` SHALL be called with the cloud environment directly

#### Scenario: Self-hosted login still validates URL
- **GIVEN** `LoginViewModel` constructs a `selfHosted` `ServerEnvironment`
- **WHEN** `LoginUseCase.execute(environment:email:masterPassword:)` is called
- **THEN** `auth.validateServerURL` SHALL be called before `auth.setServerEnvironment`

---

### Requirement: `PrizmAPIClient` routes requests via `ServerEnvironment`

`PrizmAPIClient` SHALL replace `setBaseURL(_ url: URL)` with `setServerEnvironment(_ env: ServerEnvironment)`. `setBaseURL` SHALL be removed from `PrizmAPIClientProtocol` entirely. All ~32 endpoint methods SHALL use `env.apiURL`, `env.identityURL`, or `env.iconsURL` instead of appending to a single `base`.

`AuthRepositoryImpl` currently calls `apiClient.setBaseURL(...)` in four places — all four SHALL be updated to `apiClient.setServerEnvironment(...)`:
- `setServerEnvironment(_:)` — line 83
- `storedAccount()` restoration — line 325
- `loginWithPassword` completion — line 540
- `unlockWithBiometrics` completion — line 606

All requests to cloud endpoints SHALL include the required Bitwarden client headers — `Bitwarden-Client-Name`, `Bitwarden-Client-Version`, and `Device-Type` — as already implemented in `ClientHeaders`. No change to header values is required by this change; the existing values are valid for cloud requests. A unit test SHALL assert these headers are present on a representative cloud `identityToken` request.

#### Scenario: cloudUS routes api requests correctly
- **GIVEN** the active account has `serverType == .cloudUS`
- **WHEN** `PrizmAPIClient` makes a request to an `api/...` endpoint
- **THEN** the request SHALL be sent to `https://api.bitwarden.com/api/...`

#### Scenario: cloudEU routes api requests correctly
- **GIVEN** the active account has `serverType == .cloudEU`
- **WHEN** `PrizmAPIClient` makes a request to an `api/...` endpoint
- **THEN** the request SHALL be sent to `https://api.bitwarden.eu/api/...`

#### Scenario: cloudEU routes identity requests correctly
- **GIVEN** the active account has `serverType == .cloudEU`
- **WHEN** `PrizmAPIClient` makes a request to an `identity/...` endpoint
- **THEN** the request SHALL be sent to `https://identity.bitwarden.eu/identity/...`

#### Scenario: selfHosted routes to user-supplied URL
- **GIVEN** the active account has `serverType == .selfHosted` and `base = https://vault.example.com`
- **WHEN** `PrizmAPIClient` makes a request to an `api/...` endpoint
- **THEN** the request SHALL be sent to `https://vault.example.com/api/...`

#### Scenario: refreshAccessToken routes via identityURL
- **GIVEN** the active account has `serverType == .cloudEU`
- **WHEN** `PrizmAPIClient.refreshAccessToken()` is called
- **THEN** the request SHALL be sent to `https://identity.bitwarden.eu/identity/connect/token`

`PrizmAPIClient` MUST NOT fall back to a different `ServerEnvironment` on request failure. A failed request SHALL surface the error directly to the caller; no automatic retry against another region or self-hosted is permitted. Switching server environments requires a new login.

#### Scenario: No silent region fallback on cloud auth failure
- **GIVEN** the active account has `serverType == .cloudUS`
- **WHEN** `identityToken` returns an error
- **THEN** the error SHALL be surfaced to the caller as-is
- **AND** no request SHALL be made to `identity.bitwarden.eu` or any other environment

---

### Requirement: Error taxonomy

The existing `AuthError` enum (`Domain/Repositories/AuthRepository.swift`) SHALL be extended with two new cases for this change. `LoginViewModel` pattern-matches all `AuthError` cases; no new error type is introduced.

| Case | Thrown by | `errorDescription` |
|---|---|---|
| `clientIdentifierNotConfigured` | `AuthRepositoryImpl` (before network request) | `"Prizm is not configured for Bitwarden Cloud. Contact support or use a self-hosted server."` |
| `newDeviceVerificationRequired` | `AuthRepositoryImpl` (on `device_error` 400 response) | `nil` — handled structurally by `LoginViewModel`; triggers the OTP entry UI, not a plain error string |

`newDeviceVerificationRequired` is thrown when the server returns `HTTP 400` with `{"error": "device_error"}`. `LoginViewModel` catches it and transitions to `awaitingOTP` state rather than displaying an error string.

**Layer boundary**: `PrizmAPIClient.identityToken` throws a Data-layer error (e.g. `IdentityTokenError.newDeviceNotVerified`) when it receives a `device_error` response. `AuthRepositoryImpl` catches that Data-layer error and translates it to `AuthError.newDeviceVerificationRequired` before rethrowing — preserving the clean architecture boundary. The Domain layer and above never import or reference `IdentityTokenError` directly.

`serverUnreachable`, `invalidCredentials`, `networkUnavailable`, and `invalidURL` already exist in `AuthError` and cover the remaining error scenarios defined in this spec without modification.

---

### Requirement: Server environment persists per account in Keychain

After successful login, the `ServerEnvironment` (including `serverType`) SHALL be written to Keychain under `bw.macos:{userId}:serverEnvironment`. On app launch the active account's environment SHALL be read from Keychain and used to configure `PrizmAPIClient`. The data layer is keyed by `userId` and is multi-account-ready.

#### Scenario: Environment persisted after login
- **GIVEN** the user logs in with "Bitwarden Cloud (EU)" selected
- **WHEN** login succeeds
- **THEN** a `ServerEnvironment` with `serverType == .cloudEU` SHALL be written to Keychain for that `userId`

#### Scenario: Environment restored on app launch
- **GIVEN** the active account was logged in as "Bitwarden Cloud (EU)"
- **WHEN** the app launches and the vault is unlocked
- **THEN** `PrizmAPIClient` SHALL use EU URLs for all requests

---

### Requirement: Registered client identifier used for all cloud requests

Both the OAuth password grant (`grant_type=password`) and the token refresh grant (`grant_type=refresh_token`) require a `client_id` parameter identifying the client application. Confirmed against the Bitwarden iOS reference client: both request types send the same registered identifier (`"mobile"` for the iOS client). `PrizmAPIClient` currently sends `ClientHeaders.clientId = "desktop"` in both `identityToken` (line 463) and `refreshAccessToken` (line 1004). For cloud accounts both call sites SHALL use the registered identifier injected at build time via a gitignored `.xcconfig` file. Self-hosted login is unaffected — Vaultwarden does not enforce this identifier.

`ClientHeaders.clientId` is currently a static constant. It SHALL become instance state on `PrizmAPIClient` (set via `setServerEnvironment`) so both call sites pick up the correct value for the active environment without any per-call parameter.

The `client_id` is an app-level credential, not a per-user credential. No additional login UI is needed; it is transparent to the user.

#### Scenario: Registered identifier sent on cloud password login
- **GIVEN** the active account has `serverType == .cloudUS` or `serverType == .cloudEU`
- **WHEN** `PrizmAPIClient` posts the identity token request (`grant_type=password`)
- **THEN** the `client_id` form parameter SHALL equal the registered identifier (not `"desktop"`)

#### Scenario: Registered identifier sent on cloud token refresh
- **GIVEN** the active account has `serverType == .cloudUS` or `serverType == .cloudEU`
- **WHEN** `PrizmAPIClient` posts a token refresh request (`grant_type=refresh_token`)
- **THEN** the `client_id` form parameter SHALL equal the registered identifier (not `"desktop"`)

#### Scenario: Unconfigured identifier blocks cloud login
- **GIVEN** the xcconfig value for the client identifier is empty
- **WHEN** the user attempts to log in with a cloud option selected
- **THEN** login SHALL fail with a clear error indicating the client identifier is not configured

#### Scenario: Self-hosted login unaffected
- **GIVEN** the active account has `serverType == .selfHosted`
- **THEN** the `client_id` value used in both `identityToken` and `refreshAccessToken` SHALL remain `"desktop"` (Vaultwarden-compatible default)

---

### Requirement: `LoginUseCase` OTP retry flow

`LoginUseCase` SHALL gain two new methods mirroring the existing 2FA pattern (`completeTOTP` / `cancelTOTP`):

```swift
/// Retries the identity token request with the new-device OTP the user received by email.
/// Only valid to call after `execute` throws `AuthError.newDeviceVerificationRequired`.
/// On success, triggers vault sync and returns the logged-in `Account`.
func completeNewDeviceOTP(otp: String) async throws -> Account

/// Re-triggers the original identity token request without an OTP, causing the server to
/// dispatch a new verification code to the user's email. The OTP field should be cleared
/// after calling this. Only valid when in the `awaitingOTP` state.
func resendNewDeviceOTP() async throws

/// Cancels a pending new-device OTP challenge and clears any cached credentials.
func cancelNewDeviceOTP()
```

`AuthRepository` SHALL gain three matching methods:
```swift
/// Retries the identity token request with the supplied OTP. Zeros cached credentials after attempt.
func loginWithNewDeviceOTP(_ otp: String) async throws -> Account

/// Retries the original identity token request without an OTP, triggering the server to
/// dispatch a new verification code. Does NOT return an Account — the user remains in
/// the awaitingOTP state after this call.
func requestNewDeviceOTP() async throws

/// Zeros any cached credentials held from the pending new-device OTP challenge.
func cancelNewDeviceOTP()
```

`AuthRepositoryImpl` holds the pending environment, email, and hashed password in memory after throwing `newDeviceVerificationRequired`. `loginWithNewDeviceOTP` retries `PrizmAPIClient.identityToken` with the `newdeviceotp` form parameter added, then zeros cached credentials immediately after (success or failure). `requestNewDeviceOTP` re-posts the original identity token request without `newdeviceotp` — the server recognises the unverified device and sends a fresh code; no credentials are zeroed since the challenge is still pending. `cancelNewDeviceOTP` zeros cached credentials without making a network request.

`LoginUseCase.resendNewDeviceOTP()` calls `auth.requestNewDeviceOTP()` — not `loginWithNewDeviceOTP`.

`LoginViewModel` catches `AuthError.newDeviceVerificationRequired`, sets `flowState = .otpPrompt`, and on Sign In (from `NewDeviceOTPView`) calls `loginUseCase.completeNewDeviceOTP(otp:)`.

The `execute` method signature changes are covered by the `LoginUseCase.execute` requirement above. `LoginUseCase.protocol` doc comment SHALL be updated to reflect the new flow: `execute → (optional) completeNewDeviceOTP → sync` or `execute → (optional) completeTOTP → sync`.

#### Scenario: `completeNewDeviceOTP` retries with OTP
- **GIVEN** `execute` has thrown `AuthError.newDeviceVerificationRequired`
- **WHEN** `completeNewDeviceOTP(otp:)` is called with a valid code
- **THEN** `PrizmAPIClient.identityToken` SHALL be called with `newdeviceotp` set to the code
- **AND** on success, cached credentials SHALL be zeroed and vault sync SHALL run
- **AND** the `Account` SHALL be returned

#### Scenario: `cancelNewDeviceOTP` clears cached credentials
- **GIVEN** `execute` has thrown `AuthError.newDeviceVerificationRequired`
- **WHEN** `cancelNewDeviceOTP()` is called
- **THEN** cached credentials (environment, email, hashed password) SHALL be zeroed
- **AND** no network request SHALL be made

---

### Requirement: `LoginViewModel` state machine

`LoginFlowState` (already defined in `LoginViewModel.swift`) SHALL gain a new case `.otpPrompt`. No new enum is introduced — the existing state machine is extended.

```swift
// Existing cases — unchanged:
//   .login, .loading, .totpPrompt, .syncing(message:), .vault
// New case added:
case otpPrompt   // device_error received; app shows NewDeviceOTPView
```

`RootViewModel.Screen` (in `PrizmApp.swift`) SHALL gain a matching `.otpPrompt` case. `RootViewModel.handleLoginFlow(_:)` SHALL map `.otpPrompt → .otpPrompt` alongside the existing cases. `PrizmApp`'s root switch SHALL show `NewDeviceOTPView(viewModel: rootVM.loginVM)` for `.otpPrompt`, analogous to how `TOTPPromptView` is shown for `.totpPrompt`.

`NewDeviceOTPView` is a new screen (separate SwiftUI view, same pattern as `TOTPPromptView`) that shows the OTP entry field, Resend button, and Cancel button. `LoginViewModel` transitions `flowState` to `.otpPrompt` when `execute` throws `AuthError.newDeviceVerificationRequired`.

**Valid transitions (additions to existing `LoginFlowState` machine):**

| From | Event | To |
|---|---|---|
| `.login` | Sign In tapped | `.loading` |
| `.loading` | Auth success | `.syncing` → `.vault` |
| `.loading` | Auth failure (not device_error) | `.login` (error shown) |
| `.loading` | `newDeviceVerificationRequired` | `.otpPrompt` |
| `.otpPrompt` | Sign In tapped (OTP submit) | `.loading` |
| `.otpPrompt` | Invalid OTP (`invalid_grant`) | `.otpPrompt` (error shown, field remains) |
| `.otpPrompt` | Resend tapped | `.loading` → `.otpPrompt` (OTP field cleared, confirmation announced) |
| `.otpPrompt` | Cancel tapped | `.login` (credentials zeroed) |

#### Scenario: OTP screen shown on device_error
- **GIVEN** `flowState == .loading` and the server returns `device_error`
- **THEN** `flowState` SHALL transition to `.otpPrompt`
- **AND** `NewDeviceOTPView` SHALL be displayed

#### Scenario: Cancel returns to login screen
- **GIVEN** `flowState == .otpPrompt`
- **WHEN** the user taps Cancel
- **THEN** `LoginViewModel` SHALL call `loginUseCase.cancelNewDeviceOTP()` before setting `flowState` to `.login`

#### Scenario: Fields disabled during loading
- **GIVEN** `flowState == .loading`
- **THEN** all interactive controls in the current view SHALL be non-interactive

---

### Requirement: Cloud login supports email/password with new device OTP verification

All three server options use email + master password login.

When Bitwarden Cloud does not recognise the device, it returns `HTTP 400` with `{"error": "device_error", "error_description": "New device verification required"}` and sends a one-time code to the user's registered email address. The system SHALL handle this by transitioning to `NewDeviceOTPView` (a dedicated screen, matching the existing `TOTPPromptView` pattern) and retrying the identity token request with the `newdeviceotp` parameter.

> **Spike findings (2026-04-20)**: hCaptcha was removed from Bitwarden Cloud in [bitwarden/ios#1861](https://github.com/bitwarden/ios/pull/1861) (merged 2025-08-20). The `WKWebView` modal originally planned is not needed. The current mechanism is:
> - **Trigger**: `HTTP 400`, `{"error": "device_error"}`
> - **Bitwarden sends**: OTP to the user's registered email
> - **Retry field**: `newdeviceotp=<code>` added to the `POST /connect/token` form body
> - **No web view required** — standard SwiftUI text field

New device verification is not required on every login; Bitwarden decides when to require it based on device recognition. It does not apply to self-hosted Vaultwarden instances.

#### Scenario: New device OTP screen shown on device_error
- **GIVEN** the user attempts password login with a cloud option selected
- **AND** the server returns `HTTP 400` with `{"error": "device_error"}`
- **THEN** `flowState` SHALL transition to `.otpPrompt` and `NewDeviceOTPView` SHALL appear with the label "Check your email for a verification code"
- **AND** the Sign In button SHALL remain disabled until the OTP field is non-empty

#### Scenario: OTP submitted and login retried
- **GIVEN** the new device OTP field is visible and the user has entered a code
- **WHEN** the user taps Sign In
- **THEN** `PrizmAPIClient` SHALL retry `POST /connect/token` with the `newdeviceotp` form parameter set to the entered code
- **AND** on success the OTP SHALL be zeroed from memory immediately

#### Scenario: Invalid OTP shows error
- **GIVEN** the user submits an incorrect OTP
- **WHEN** the server returns `HTTP 400` with `{"error": "invalid_grant"}`
- **THEN** an error message SHALL indicate the code is invalid or expired
- **AND** the OTP field SHALL remain visible for re-entry

#### Scenario: Resend code clears OTP field and sends fresh code
- **GIVEN** `loginState == .awaitingOTP`
- **WHEN** the user taps "Resend code"
- **THEN** `loginUseCase.resendNewDeviceOTP()` SHALL be called
- **AND** the OTP field SHALL be cleared
- **AND** `loginState` SHALL transition to `loading` during the request and back to `awaitingOTP` on completion
- **AND** an `AccessibilityNotification.Announcement` SHALL be posted with "A new code has been sent to your email"

`LoginUseCase` SHALL gain a `resendNewDeviceOTP() async throws` method. `AuthRepositoryImpl` implements it by retrying the original identity token request without `newdeviceotp`, causing the server to recognise the unverified device and dispatch a new code.

#### Scenario: Self-hosted login has no new device OTP handling
- **GIVEN** the active account has `serverType == .selfHosted`
- **THEN** no OTP entry field is shown; `device_error` responses SHALL surface as a generic auth error

---

### Requirement: Accessibility

All new interactive controls introduced by this change MUST be fully usable via VoiceOver (§VIII).

- The server picker SHALL have `accessibilityIdentifier` set to `AccessibilityID.Login.serverTypePicker`, `accessibilityLabel` set to "Server", and expose its current value via `accessibilityValue` (e.g. "Bitwarden Cloud (US)")
- The server URL text field SHALL retain its existing `accessibilityIdentifier` and have a meaningful `accessibilityLabel` ("Server URL")
- The new device OTP text field SHALL have `accessibilityIdentifier` set to `AccessibilityID.Login.newDeviceOtpField` and `accessibilityLabel` set to "Verification code"
- Error messages (unreachable server, invalid credentials, missing client identifier, invalid OTP) SHALL be announced via `AccessibilityNotification.Announcement` as soon as they appear

#### Scenario: Picker exposes current selection to VoiceOver
- **WHEN** the server picker has "Bitwarden Cloud (EU)" selected
- **THEN** VoiceOver SHALL announce the control as "Server, Bitwarden Cloud (EU)"

#### Scenario: OTP screen announced when it appears
- **WHEN** `NewDeviceOTPView` appears after a `device_error` response
- **THEN** an `AccessibilityNotification.Announcement` SHALL be posted with "Check your email for a verification code"

#### Scenario: Error announced to assistive technology
- **WHEN** an error message appears in the login form
- **THEN** an `AccessibilityNotification.Announcement` SHALL be posted with the error text

---

### Requirement: Observability

All new code paths MUST produce structured `os.Logger` output (§V). Secrets MUST NOT appear in logs.

- Server environment selection and restoration SHALL be logged at `.info` level, including the `serverType` value
- Each identity token request SHALL log the target `identityURL` (not the password or hash) at `.info`
- New device verification required and OTP retry SHALL be logged at `.info`
- Invalid or expired OTP (`invalid_grant` on retry) SHALL be logged at `.error`
- Client identifier misconfiguration SHALL be logged at `.error` before surfacing to the Presentation layer
- URL validation failures (non-HTTPS, parse error) SHALL be logged at `.error`

---

### Requirement: Tests

Per §IV, tests MUST be written before implementation. The following are required:

**Unit tests (Domain):**
- `ServerEnvironment` with `serverType == .cloudUS` returns correct US canonical URLs
- `ServerEnvironment` with `serverType == .cloudEU` returns correct EU canonical URLs, and `iconsURL == https://icons.bitwarden.net`
- `ServerEnvironment` with `serverType == .selfHosted` returns `base`-derived URLs unchanged
- Decoding a legacy JSON record (no `serverType` key) yields `serverType == .selfHosted`
- Round-trip encode/decode for each `ServerType` case preserves the exact raw string value (`"cloudUS"`, `"cloudEU"`, `"selfHosted"`)

**Unit tests (Data):**
- `PrizmAPIClient.setServerEnvironment()` stores the environment and subsequent requests use `env.apiURL` / `env.identityURL` as appropriate (representative call sites: `preLogin`, `identityToken`, `refreshAccessToken`, `fetchSync`)
- `AuthRepositoryImpl.setServerEnvironment(_:)` calls `apiClient.setServerEnvironment(_:)` (not `setBaseURL`)
- `LoginUseCaseImpl` does NOT call `auth.validateServerURL` when `environment.serverType == .cloudUS` or `.cloudEU`
- `LoginUseCaseImpl` DOES call `auth.validateServerURL` when `environment.serverType == .selfHosted`
- Cloud login attempt with empty client identifier throws before making a network request
- `PrizmAPIClient` includes `Bitwarden-Client-Name`, `Bitwarden-Client-Version`, and `Device-Type` headers on a cloud `identityToken` request
- `PrizmAPIClient.refreshAccessToken` sends the registered cloud `client_id` (not `"desktop"`) when `serverType` is cloud
- `AuthRepositoryImpl` throws `AuthError.newDeviceVerificationRequired` when the identity token response is `HTTP 400` with `{"error": "device_error"}`
- `LoginUseCaseImpl.completeNewDeviceOTP` calls `auth.loginWithNewDeviceOTP(_:)` and triggers sync on success
- `LoginUseCaseImpl.cancelNewDeviceOTP` calls `auth.cancelNewDeviceOTP()` and makes no network request
- OTP retry includes `newdeviceotp` form parameter and succeeds on a valid code
- Cached credentials (environment, email, hashed password) are zeroed after retry completes or fails, and after cancel

**Unit tests (Presentation):**
- `LoginViewModel` server type selection is persisted and restored across instantiation
- `LoginViewModel` initialised with `UserDefaults` containing `com.prizm.login.lastServerType = "cloudEU"` defaults `serverType` to `.cloudEU`
- Selecting a cloud type clears `serverURL`; selecting self-hosted restores the last entered URL
- `isSignInDisabled` returns `false` for cloud when email and password are non-empty, even when `serverURL` is empty
- `isSignInDisabled` returns `true` for self-hosted when `serverURL` is empty, even when email and password are filled
- `isSignInDisabled` returns `true` in `NewDeviceOTPView` when the OTP field is empty
- `isSignInDisabled` returns `false` in `NewDeviceOTPView` when the OTP field is non-empty
- `flowState` transitions to `.otpPrompt` when `execute` throws `AuthError.newDeviceVerificationRequired`
- `flowState` transitions to `.login` when Cancel is tapped from `NewDeviceOTPView` (after `cancelNewDeviceOTP()`)
- `flowState` remains `.otpPrompt` after an invalid OTP error; error message is set
- `loginUseCase.resendNewDeviceOTP()` is called when "Resend code" is tapped; OTP field is cleared and confirmation is announced
- `LoginUseCaseImpl.resendNewDeviceOTP()` calls `auth.requestNewDeviceOTP()` to re-trigger server dispatch

**Integration tests:**
- Full login flow against a Vaultwarden stub (existing coverage) continues to pass after the `PrizmAPIClient` refactor

**UI tests (XCUITest):**

- Three-way picker is visible on `LoginView`; all three options ("Bitwarden Cloud (US)", "Bitwarden Cloud (EU)", "Self-hosted") are selectable
- Selecting "Bitwarden Cloud (US)" or "Bitwarden Cloud (EU)" hides the server URL field
- Selecting "Self-hosted" shows the server URL field
- Sign In button is enabled for a cloud option when email and password are non-empty and `serverURL` is empty
- Sign In button is disabled for "Self-hosted" when `serverURL` is empty even if email and password are filled
- Successful cloud login end-to-end against a local stub (no OTP required path)
- `device_error` response causes `NewDeviceOTPView` to appear with label "Check your email for a verification code"
- Valid OTP entered → login succeeds; OTP field disappears
- Invalid OTP → error message shown; OTP field remains for re-entry

---

### Requirement: Server environment errors surfaced clearly

#### Scenario: Non-HTTPS self-hosted URL rejected
- **WHEN** the user enters a self-hosted URL without `https://`
- **THEN** the system SHALL reject it with an error indicating HTTPS is required

#### Scenario: Unreachable self-hosted endpoint
- **WHEN** the user enters a self-hosted URL that cannot be reached
- **THEN** login SHALL fail with an error indicating the server is unreachable

#### Scenario: Authentication failure distinct from network error
- **WHEN** login fails due to invalid credentials
- **THEN** the error SHALL clearly indicate authentication failure, not a connectivity problem

#### Scenario: Cloud endpoints unreachable
- **WHEN** a cloud option is selected and the corresponding endpoints cannot be reached
- **THEN** the error SHALL indicate that Bitwarden Cloud services are temporarily unavailable

---

### Requirement: Document tested Bitwarden API version in `Config.swift`

Per Constitution Bitwarden API Integration Requirements, `Config.swift` SHALL gain a `bitwardenApiVersion` constant recording the Bitwarden server API version this client has been tested against:

```swift
/// Bitwarden server API version Prizm was last tested against.
/// Update when testing against a newer server release.
static let bitwardenApiVersion = "2026.4.0"
```

Starting value: `2026.4.0` — the current Bitwarden server release as of the implementation spike (2026-04-20, confirmed from [bitwarden/ios v2026.4.0-bwpm](https://github.com/bitwarden/ios/releases/tag/v2026.4.0-bwpm)). Update if testing against a newer release before shipping.

---

### Requirement: Update `DEVELOPMENT.md` for `LocalSecrets.xcconfig`

`DEVELOPMENT.md` SHALL be updated to document the new `LocalSecrets.xcconfig` setup step required for cloud login:
- Add a `LocalSecrets.xcconfig` section explaining its purpose (injects the registered Bitwarden client identifier at build time)
- Provide a template copy command analogous to the existing `LocalConfig.xcconfig` instructions
- Clarify that without this file, the app will build successfully but cloud login will fail at runtime with a clear error — self-hosted login is unaffected

---

### Requirement: Update `SECURITY.md` (§VII)

`SECURITY.md` SHALL be updated to reflect the expanded network attack surface introduced by this change:
- Document the two cloud regions and their canonical endpoints
- Note that new device OTP verification is handled via a plain text field; the OTP is held in memory only for the duration of the retry and zeroed immediately after
- Note that the registered client identifier is injected at build time and never stored at runtime beyond the request

---

### Requirement: Update `ACCESSIBILITY.md` (§VIII)

`ACCESSIBILITY.md` SHALL be updated to document:
- The new server picker control and its VoiceOver behaviour
- `NewDeviceOTPView` and its OTP field `accessibilityLabel` / announcement behaviour

---

## Security Considerations

### Certificate Pinning (§III evaluation)

Certificate pinning was evaluated for `api.bitwarden.com`, `identity.bitwarden.com`, `api.bitwarden.eu`, and `identity.bitwarden.eu`.

**Decision: not implemented in this release.**

Rationale:
- Bitwarden's official clients do not pin certificates.
- macOS ATS + the system trust store provides a strong baseline; no `NSAllowsArbitraryLoads` exemptions are needed for these endpoints.
- Operational risk: if Bitwarden rotates their TLS certificate without advance notice, pinned clients would lock all users out until an app update ships — an unacceptable availability risk for a credential vault.

Revisit if Bitwarden publishes a pinning recommendation, if a CA compromise incident occurs, or if Prizm moves to a managed distribution channel with rapid OTA update capability.
