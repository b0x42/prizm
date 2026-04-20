## Purpose

Defines support for Bitwarden Cloud (US and EU regions) alongside self-hosted Vaultwarden instances. Scope: single active account; user chooses server at login. Data layer is designed for multi-account from day one; multi-account UI is deferred.

## Complexity Tracking

Per §I and §VI, non-trivial architectural decisions and AppKit exceptions must be justified here.

| Component | Type | Justification | Simpler alternative rejected |
|---|---|---|---|
| `WKWebView` hCaptcha modal | AppKit/WebKit exception (§I) | SwiftUI has no web rendering API on macOS; `WKWebView` is the only platform-provided mechanism for an interactive web challenge | Skipping hCaptcha entirely — rejected because Bitwarden Cloud conditionally requires it; affected users would get a silent auth failure |
| `HCaptchaPresenter` protocol + DI | Added abstraction (§VI) | Required for XCUITest determinism; without injection the hCaptcha path cannot be exercised in CI without a live network | Single concrete `WKWebView` usage — rejected because it makes the modal untestable |

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

The existing `AuthError` enum (`Domain/Repositories/AuthRepository.swift`) SHALL be extended with three new cases for this change. `LoginViewModel` pattern-matches all `AuthError` cases; no new error type is introduced.

| Case | Thrown by | `errorDescription` |
|---|---|---|
| `clientIdentifierNotConfigured` | `AuthRepositoryImpl` (before network request) | `"Prizm is not configured for Bitwarden Cloud. Contact support or use a self-hosted server."` |
| `hCaptchaRequired(siteKey: String)` | `AuthRepositoryImpl` (on challenge response) | `nil` — handled structurally by `LoginViewModel`; not shown as a plain error string |
| `hCaptchaCancelled` | `LoginViewModel` (on modal dismiss without token) | `"Unable to complete the security challenge. To log in without this requirement, use a self-hosted Vaultwarden server."` |

`hCaptchaRequired` carries the site key extracted from the server's challenge response so `LoginViewModel` can pass it to `WKWebViewHCaptchaPresenter` when constructing the challenge URL.

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

> **Research spike required — resolve before writing tasks:**
>
> The following must be determined by consulting the [Bitwarden iOS client](https://github.com/bitwarden/ios) (study-only reference per Constitution External Dependencies) before implementation begins. Findings SHALL replace this block with concrete values.
>
> 1. **Trigger signal**: What HTTP status and response body field indicate an hCaptcha challenge is required? (Expected: `400` with a JSON error body containing a `HCaptcha_SiteKey` or similar field — verify against iOS source.)
> 2. **Challenge URL**: What URL does the `WKWebView` load? (Expected: a Bitwarden-hosted page such as `https://vault.bitwarden.com/captcha-mobile-connector.html` that embeds the hCaptcha widget — verify; EU region may differ.)
> 3. **Site key**: Is the hCaptcha site key static per region (hardcode in `ServerType`) or returned dynamically in the challenge response? (If dynamic, it must be extracted from the error body and passed to the challenge URL as a query parameter.)
> 4. **JS message name**: Confirm the `WKScriptMessageHandler` message name is `"hcaptcha"` — verify against iOS source.
> 5. **Token field name**: What form parameter name carries the hCaptcha token in the retried `identityToken` request? (Expected: `captchaResponse` or similar — verify.)
>
> **Do not begin implementation of the hCaptcha path until all five points are confirmed and this block is replaced with findings.**

#### Scenario: hCaptcha modal shown for cloud password login
- **GIVEN** the user attempts password login with a cloud option selected
- **AND** the server returns an hCaptcha challenge response
- **THEN** a `WKWebView` modal SHALL be presented
- **AND** when hCaptcha completes, its JS SHALL call `window.webkit.messageHandlers.hcaptcha.postMessage(token)`
- **AND** the native `WKScriptMessageHandler` SHALL receive the token, dismiss the modal, and retry `identityToken` with the token included
- **AND** the token SHALL be held in memory only for the duration of the retry, NOT persisted, and zeroed from memory immediately after the retry completes or fails

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
- The hCaptcha `WKWebView` modal SHALL have `accessibilityLabel` set to "Complete security challenge"; VoiceOver focus SHALL move into the modal on presentation and return to the login form on dismissal
- The modal SHALL always expose a keyboard-accessible "Cancel" button reachable without completing the web challenge
- Error messages (unreachable server, invalid credentials, missing client identifier) SHALL be announced via `AccessibilityNotification.Announcement` as soon as they appear

> **Known limitation**: `WKWebView` renders a third-party hCaptcha widget; Prizm cannot guarantee the widget itself meets WCAG 2.1 AA. If a user cannot complete the challenge via assistive technology, the Cancel path (see scenario below) provides an exit. This limitation MUST be documented in `ACCESSIBILITY.md` with a note that self-hosted Vaultwarden is available as an alternative that does not require hCaptcha.

#### Scenario: Picker exposes current selection to VoiceOver
- **WHEN** the server picker has "Bitwarden Cloud (EU)" selected
- **THEN** VoiceOver SHALL announce the control as "Server, Bitwarden Cloud (EU)"

#### Scenario: Error announced to assistive technology
- **WHEN** an error message appears in the login form
- **THEN** an `AccessibilityNotification.Announcement` SHALL be posted with the error text

#### Scenario: hCaptcha inaccessible path
- **GIVEN** the hCaptcha modal is presented
- **WHEN** the user cannot complete the challenge via assistive technology and activates the "Cancel" button
- **THEN** the modal SHALL be dismissed
- **AND** an error message SHALL read "Unable to complete the security challenge. To log in without this requirement, use a self-hosted Vaultwarden server."
- **AND** the `AccessibilityNotification.Announcement` SHALL be posted with that error text

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
- `PrizmAPIClient` includes `Bitwarden-Client-Name`, `Bitwarden-Client-Version`, and `Device-Type` headers on a cloud `identityToken` request

**Unit tests (Presentation):**
- `LoginViewModel` server type selection is persisted and restored across instantiation
- `LoginViewModel` initialised with `UserDefaults` containing `com.prizm.login.lastServerType = "cloudEU"` defaults `serverType` to `.cloudEU`
- Selecting a cloud type clears `serverURL`; selecting self-hosted restores the last entered URL
- `isSignInDisabled` returns `false` for cloud when email and password are non-empty, even when `serverURL` is empty
- `isSignInDisabled` returns `true` for self-hosted when `serverURL` is empty, even when email and password are filled

**Integration tests:**
- Full login flow against a Vaultwarden stub (existing coverage) continues to pass after the `PrizmAPIClient` refactor

**UI tests (XCUITest):**

`LoginViewModel` SHALL accept a `HCaptchaPresenter` protocol (injected via `AppContainer`) so XCUITest can substitute a stub that immediately fires the JS token message without loading a real `WKWebView`. Production uses `WKWebViewHCaptchaPresenter`; tests use `StubHCaptchaPresenter`.

- Three-way picker is visible on `LoginView`; all three options ("Bitwarden Cloud (US)", "Bitwarden Cloud (EU)", "Self-hosted") are selectable
- Selecting "Bitwarden Cloud (US)" or "Bitwarden Cloud (EU)" hides the server URL field
- Selecting "Self-hosted" shows the server URL field
- Sign In button is enabled for a cloud option when email and password are non-empty and `serverURL` is empty
- Sign In button is disabled for "Self-hosted" when `serverURL` is empty even if email and password are filled
- Successful cloud login end-to-end against a local Bitwarden-compatible stub (using `StubHCaptchaPresenter` to bypass real web challenge)
- hCaptcha modal presented for cloud login: `StubHCaptchaPresenter` fires the token → login proceeds
- hCaptcha modal dismissed without token: login error message is shown

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

Per Constitution Bitwarden API Integration Requirements, `Config.swift` SHALL gain a `bitwardenApiVersion` constant recording the Bitwarden server API version this client has been tested against (e.g. `static let bitwardenApiVersion = "2025-01"`). The value SHALL be determined during the implementation spike and updated whenever the tested version changes.

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
- Note that hCaptcha is handled via an embedded `WKWebView` loading a Bitwarden-hosted page; the token is held in memory only for the duration of the login retry and never persisted
- Note that the registered client identifier is injected at build time and never stored at runtime beyond the request

---

### Requirement: Update `ACCESSIBILITY.md` (§VIII)

`ACCESSIBILITY.md` SHALL be updated to document:
- The new server picker control and its VoiceOver behaviour
- The hCaptcha `WKWebView` modal and its known limitation (third-party widget; WCAG 2.1 AA compliance of the widget itself cannot be guaranteed by Prizm)
- The self-hosted alternative available to users who cannot complete the hCaptcha challenge

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
