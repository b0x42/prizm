## Context

Prizm currently supports only self-hosted Vaultwarden instances. Users must manually configure URLs for API, Identity, and Icons endpoints (e.g., `https://vault.example.com/api/...`, `https://vault.example.com/identity/...`). While this works for self-hosted users, it is not a good experience for users of Bitwarden's hosted cloud service, who expect a simple "Log in to Bitwarden Cloud" flow similar to the official Bitwarden clients.

Bitwarden Cloud operates two independent regions: the international US region (bitwarden.com) and the EU region (bitwarden.eu), each with its own set of service endpoints. Users must choose the correct region — selecting the wrong one will produce an authentication failure.

Bitwarden Cloud requires [hCaptcha](https://www.hcaptcha.com/) verification for login from unrecognized devices. This adds a web-based challenge to the login flow.

The Prizm API client (`PrizmAPIClient`) currently constructs URLs by appending paths to a single `baseURL`. Both cloud regions and self-hosted instances use distinct domains per service type (api, identity, icons). Supporting all three options requires wiring per-service URLs through to all call sites.

Bitwarden Cloud requires a registered client identifier per their Device Registration ADR. This identifier must be injected at build time and must never appear in the repository.

### Existing infrastructure (post-merge baseline)

The following is already in the codebase and must be extended rather than created:

- **`ServerEnvironment`** (`Domain/Entities/Account.swift`) — struct with `base: URL`, optional `overrides: ServerURLOverrides?`, and computed properties `apiURL`, `identityURL`, `iconsURL`. Serialised to Keychain per account under `bw.macos:{userId}:serverEnvironment`. No cloud/region variant — only models self-hosted today.
- **`AuthRepository.setServerEnvironment(_ env:)`** — declared and implemented; currently only calls `apiClient.setBaseURL(environment.base)`, ignoring `apiURL`/`identityURL`/`iconsURL`.
- **`PrizmAPIClient.setBaseURL(_ url: URL)`** — actor method; all ~32 endpoint methods use `base.appendingPathComponent(...)`. Per-service URL properties on `ServerEnvironment` are never passed through.
- **`LoginView` / `LoginViewModel`** — single `serverURL: String` field, static subtitle "Self-hosted vault".
- **`bw.macos:{userId}:serverEnvironment`** — Keychain key already in use for self-hosted accounts.

## Goals / Non-Goals

**Goals:**
- Three-way server picker in `LoginView`: Bitwarden Cloud (US), Bitwarden Cloud (EU), Self-hosted
- Wire `PrizmAPIClient` to route requests via `env.apiURL` / `env.identityURL` / `env.iconsURL`
- Support hCaptcha via `WKWebView` for cloud password login
- Handle hCaptcha challenges via `WKWebView` for cloud password login
- Persist server environment per account in Keychain (data layer multi-account-ready)
- Include registered client identifier in cloud API requests; identifier injected at build time, never in repo

**Non-Goals:**
- Automatic server type detection from a URL
- Multi-account UI — running multiple accounts simultaneously (deferred to a later release)
- Multi-device cloud sync coordination (existing sync mechanisms are unchanged)

## Decisions

### Decision: Three-way server picker in `LoginView`

The login screen SHALL present a segmented picker (or equivalent) with three options:

1. **Bitwarden Cloud (US)** — no URL entry; US service URLs auto-configured
2. **Bitwarden Cloud (EU)** — no URL entry; EU service URLs auto-configured
3. **Self-hosted** — shows the existing server URL field

Showing US and EU as distinct top-level choices makes the region decision explicit and avoids any ambiguity about which data centre stores the user's vault. The static subtitle "Self-hosted vault" is replaced by the picker.

**API Endpoints**:

| US                     | EU                    |
|:-----------------------|:----------------------|
| api.bitwarden.com      | api.bitwarden.eu      |
| events.bitwarden.com   | events.bitwarden.eu   |
| identity.bitwarden.com | identity.bitwarden.eu |
| scim.bitwarden.com     | scim.bitwarden.eu     |
| sso.bitwarden.com      | sso.bitwarden.eu      |
| push.bitwarden.com     | push.bitwarden.eu     |

Note that `func.bitwarden.com` and `icons.bitwarden.net` are the same across clouds. Values taken from [Bitwarden's official documentation](https://bitwarden.com/help/bitwarden-addresses/#application-endpoints).

**Alternative considered**: Single "Bitwarden Cloud" option with a secondary region dropdown. Rejected — hides a decision that has real data-residency implications; users should see it upfront.

### Decision: `ServerType` flat enum with three cases

`ServerEnvironment` SHALL gain a `ServerType` enum with three cases: `cloudUS`, `cloudEU`, `selfHosted`. The computed `apiURL`/`identityURL`/`iconsURL` properties SHALL return the correct canonical URLs per case:

| Case | apiURL | identityURL | iconsURL |
|---|---|---|---|
| `cloudUS` | `https://api.bitwarden.com` | `https://identity.bitwarden.com` | `https://icons.bitwarden.net` |
| `cloudEU` | `https://api.bitwarden.eu` | `https://identity.bitwarden.eu` | `https://icons.bitwarden.net` |
| `selfHosted` | `{base}/api` (or override) | `{base}/identity` (or override) | `{base}/icons` (or override) |

The existing `overrides: ServerURLOverrides?` field is retained for self-hosted instances that split services across domains. Cloud cases ignore `overrides`.

**Alternative considered**: `cloud(region: CloudRegion)` associated-value enum. Rejected — YAGNI; two named cases are clearer and simpler than an associated value with a nested type when there are only two regions.

**Alternative considered**: Separate type per case. Rejected — breaks existing Keychain serialisation format.

Existing Keychain records with no `serverType` key SHALL decode as `selfHosted` (backwards-compatible; no migration step needed).

### Decision: `PrizmAPIClient` accepts `ServerEnvironment` directly

`PrizmAPIClient` SHALL replace `setBaseURL(_ url: URL)` with `setServerEnvironment(_ env: ServerEnvironment)`. All ~32 endpoint methods SHALL route to `env.apiURL`, `env.identityURL`, or `env.iconsURL`. `AuthRepositoryImpl.setServerEnvironment(_:)` SHALL call `apiClient.setServerEnvironment(environment)` instead of `apiClient.setBaseURL(environment.base)`. The computed properties already return the right values — this is purely wiring.

### Decision: Email/password login only; registered `client_id` enables cloud auth

All three server options use email + master password login. No API key login UI is needed.

The Bitwarden OAuth password grant already requires a `client_id` parameter identifying the client application — `PrizmAPIClient` sends it today as `ClientHeaders.clientId = "desktop"`. For cloud accounts this value is replaced with the registered identifier from Bitwarden, Inc., injected via xcconfig. This is transparent to the user; no extra UI is required.

If the cloud server returns an hCaptcha challenge, a `WKWebView` modal handles it before the token request is retried.

**Alternative considered**: API key login (`client_credentials` grant) as a CAPTCHA bypass. Rejected — out of scope for this release; the hCaptcha `WKWebView` path covers the cloud login requirement without adding a second authentication mode.

### Decision: `WKWebView` for hCaptcha (§I AppKit exception)

SwiftUI has no native web view API on macOS. `WKWebView` (WebKit framework) is the only platform-provided mechanism for rendering an interactive web challenge inline. Per §I, AppKit/non-SwiftUI APIs are permitted when SwiftUI has no equivalent — this qualifies. The `WKWebView` is scoped strictly to the hCaptcha modal; no other web rendering is used in the app. This usage MUST be documented in the Complexity Tracking table when the implementation plan is written.

### Decision: hCaptcha token handoff via `WKScriptMessageHandler`

When hCaptcha completes, its JS calls `window.webkit.messageHandlers.hcaptcha.postMessage(token)`. The native `WKScriptMessageHandler` delegate receives the token string, dismisses the modal, and passes it directly into a retry of `identityToken`. The token is held only in memory for the duration of the retry and is not persisted.

This is the standard Apple-documented JS-to-native bridge. No third-party bridge library is used. The message handler name (`"hcaptcha"`) is registered on `WKWebViewConfiguration.userContentController` before the view loads.

**Security note**: the handler MUST validate that the received message is a non-empty string before passing it to `identityToken`. Any other message type SHALL be discarded and the modal closed with an error.

### Decision: Data layer multi-account-ready; UI single-account for this release

`ServerEnvironment` is keyed by `userId` in Keychain. Adding a second account in a future release requires no data layer changes. This release manages one active account at a time. Multi-account UI is deferred.

### Decision: Client identifier injected at build time via gitignored xcconfig

The registered Bitwarden client identifier SHALL be set in a gitignored `LocalSecrets.xcconfig` file and surfaced in the app via an `Info.plist` key read by `Config.swift`. When the key is absent (e.g. a fresh clone), the value defaults to an empty string and cloud login fails with a clear error at runtime. CI/CD injects the value from a secret.

## Risks / Trade-offs

- **hCaptcha trigger conditions**: The server conditionally requires hCaptcha. The exact HTTP status and response structure indicating a required hCaptcha challenge needs to be determined at implementation time.
- **Client identifier must never appear in the repo**: injected via gitignored xcconfig. CI injects from a secret. Development builds without the key will fail cloud login at runtime with a clear error.
- **Self-hosted URL validation**: `AuthRepositoryImpl.validateServerURL()` already enforces HTTPS-only and strips trailing slashes. No new logic needed.
