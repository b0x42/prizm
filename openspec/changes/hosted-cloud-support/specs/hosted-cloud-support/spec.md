## Purpose

Defines support for Bitwarden Cloud (US and EU regions) alongside self-hosted Vaultwarden instances. Scope: single active account; user chooses server at login. Data layer is designed for multi-account from day one; multi-account UI is deferred.

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

### Requirement: `PrizmAPIClient` routes requests via `ServerEnvironment`

`PrizmAPIClient` SHALL replace `setBaseURL(_ url: URL)` with `setServerEnvironment(_ env: ServerEnvironment)`. `setBaseURL` SHALL be removed from `PrizmAPIClientProtocol` entirely. All ~32 endpoint methods SHALL use `env.apiURL`, `env.identityURL`, or `env.iconsURL` instead of appending to a single `base`.

`AuthRepositoryImpl` currently calls `apiClient.setBaseURL(...)` in four places — all four SHALL be updated to `apiClient.setServerEnvironment(...)`:
- `setServerEnvironment(_:)` — line 83
- `storedAccount()` restoration — line 325
- `loginWithPassword` completion — line 540
- `unlockWithBiometrics` completion — line 606

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

### Requirement: Registered client identifier used for cloud password login

The Bitwarden OAuth password grant (`grant_type=password`) requires a `client_id` parameter identifying the client application. `PrizmAPIClient` already sends this as `ClientHeaders.clientId`, currently hardcoded to `"desktop"`. For cloud accounts this value SHALL be replaced with the registered identifier obtained from Bitwarden, Inc., injected at build time via a gitignored `.xcconfig` file. Self-hosted login is unaffected — Vaultwarden does not enforce this identifier.

The `client_id` is an app-level credential, not a per-user credential. No additional login UI is needed; it is transparent to the user.

#### Scenario: Registered identifier sent on cloud password login
- **GIVEN** the active account has `serverType == .cloudUS` or `serverType == .cloudEU`
- **WHEN** `PrizmAPIClient` posts the identity token request
- **THEN** the `client_id` form parameter SHALL equal the registered identifier (not `"desktop"`)

#### Scenario: Unconfigured identifier blocks cloud login
- **GIVEN** the xcconfig value for the client identifier is empty
- **WHEN** the user attempts to log in with a cloud option selected
- **THEN** login SHALL fail with a clear error indicating the client identifier is not configured

#### Scenario: Self-hosted login unaffected
- **GIVEN** the active account has `serverType == .selfHosted`
- **THEN** the `client_id` value used SHALL remain `"desktop"` (Vaultwarden-compatible default)

---

### Requirement: Cloud login supports email/password with hCaptcha handling

All three server options use email + master password login. When a cloud account (`cloudUS` or `cloudEU`) triggers an hCaptcha challenge, the system SHALL present a `WKWebView` modal for the user to complete the challenge before the token request is retried. hCaptcha is not required on every login; the server decides when to require it.

> **Implementation note**:
> The exact mechanism by which the client distinguishes hCaptcha requirement from other auth failures (e.g., invalid credentials, 2FA required) is not clearly documented in public repositories and must be discovered at implementation time via testing against cloud endpoints or referencing internal documentation.

#### Scenario: hCaptcha modal shown for cloud password login
- **GIVEN** the user attempts password login with a cloud option selected
- **AND** the server returns an hCaptcha challenge response
- **THEN** a `WKWebView` modal SHALL be presented
- **AND** when hCaptcha completes, its JS SHALL call `window.webkit.messageHandlers.hcaptcha.postMessage(token)`
- **AND** the native `WKScriptMessageHandler` SHALL receive the token, dismiss the modal, and retry `identityToken` with the token included
- **AND** the token SHALL be held in memory only for the duration of the retry and NOT persisted

#### Scenario: hCaptcha challenge dismissal treated as failed login
- **GIVEN** the hCaptcha modal is presented
- **WHEN** the user dismisses the modal without completing the challenge
- **THEN** the login attempt SHALL be treated as a failed login
- **AND** an appropriate error message SHALL be displayed to the user

#### Scenario: Self-hosted login has no hCaptcha handling
- **GIVEN** the active account has `serverType == .selfHosted`
- **THEN** no hCaptcha modal path exists in the login flow

---

### Requirement: Accessibility

All new interactive controls introduced by this change MUST be fully usable via VoiceOver (§VIII).

- The server picker SHALL have `accessibilityIdentifier` set to `AccessibilityID.Login.serverTypePicker`, `accessibilityLabel` set to "Server", and expose its current value via `accessibilityValue` (e.g. "Bitwarden Cloud (US)")
- The server URL text field SHALL retain its existing `accessibilityIdentifier` and have a meaningful `accessibilityLabel` ("Server URL")
- The hCaptcha `WKWebView` modal SHALL have an accessible dismiss path (a labelled close button); VoiceOver focus SHALL move into the modal on presentation and return to the login form on dismissal
- Error messages (unreachable server, invalid credentials, missing client identifier) SHALL be announced via `AccessibilityNotification.Announcement` as soon as they appear

#### Scenario: Picker exposes current selection to VoiceOver
- **WHEN** the server picker has "Bitwarden Cloud (EU)" selected
- **THEN** VoiceOver SHALL announce the control as "Server, Bitwarden Cloud (EU)"

#### Scenario: Error announced to assistive technology
- **WHEN** an error message appears in the login form
- **THEN** an `AccessibilityNotification.Announcement` SHALL be posted with the error text

---

### Requirement: Observability

All new code paths MUST produce structured `os.Logger` output (§V). Secrets MUST NOT appear in logs.

- Server environment selection and restoration SHALL be logged at `.info` level, including the `serverType` value
- Each identity token request SHALL log the target `identityURL` (not the password or hash) at `.info`
- hCaptcha challenge receipt and completion SHALL be logged at `.info`
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
- Cloud login attempt with empty client identifier throws before making a network request

**Unit tests (Presentation):**
- `LoginViewModel` server type selection is persisted and restored across instantiation
- `LoginViewModel` initialised with `UserDefaults` containing `com.prizm.login.lastServerType = "cloudEU"` defaults `serverType` to `.cloudEU`
- Selecting a cloud type clears `serverURL`; selecting self-hosted restores the last entered URL
- `isSignInDisabled` returns `false` for cloud when email and password are non-empty, even when `serverURL` is empty
- `isSignInDisabled` returns `true` for self-hosted when `serverURL` is empty, even when email and password are filled

**Integration tests:**
- Full login flow against a Vaultwarden stub (existing coverage) continues to pass after the `PrizmAPIClient` refactor

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
