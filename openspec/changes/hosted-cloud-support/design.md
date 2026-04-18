## Context

Prizm currently supports only self-hosted Vaultwarden instances. Users must manually configure URLs for API, Identity, and Icons endpoints (e.g., `https://vault.example.com/api/...`, `https://vault.example.com/identity/...`). While this works for self-hosted users, it is not a good experience for users of Bitwarden's hosted cloud service, who expect a simple "Log in to Bitwarden Cloud" flow similar to the official Bitwarden clients.

More importantly, Bitwarden Cloud requires [hCaptcha](https://www.hcaptcha.com/) verification for login from unrecognized devices. Implementing hCaptcha support adds an additional web-based challenge to the login flow.

The Prizm API client (`PrizmAPIClient`) currently constructs URLs by appending paths to a single base URL. Bitwarden Cloud uses separate domains for different services: `api.bitwarden.com`, `identity.bitwarden.com`, and `icons.bitwarden.net`. Supporting cloud requires refactoring URL construction to use separate base URLs per endpoint type.

Finally, Bitwarden Cloud requires a registered client identifier per their Device Registration ADR. This identifier must be included in API requests and must be obtained from Bitwarden, Inc. before any public release targeting bitwarden.com.

## Goals / Non-Goals

**Goals:**
- Provide a polished "Bitwarden Cloud" option alongside "Self-hosted" in the login flow
- Auto-fill standard cloud URLs (api.bitwarden.com, identity.bitwarden.com, icons.bitwarden.net) when cloud is selected
- Refactor `PrizmAPIClient` to use separate URLs per endpoint type (API, Identity, Icons)
- Support hCaptcha verification through an embedded `WKWebView`
- Persist server environment configuration per account
- Include registered client identifier in cloud API requests

**Non-Goals:**
- Automatic detection of server type from URL (user must explicitly choose cloud vs self-hosted)
- Multi-device cloud sync coordination (existing sync mechanisms are unchanged)

## Decisions

### Decision: Explicit cloud/self-hosted toggle in `LoginView`

Users must explicitly choose between "Bitwarden Cloud" and "Self-hosted" via a picker or toggle. The selection determines whether URLs are auto-filled (cloud) or manually entered (self-hosted). This preserves the UX principle that the user should always be in control of where their data is stored.

**Alternative considered**: Automatically detect cloud vs self-hosted from the input URL. Rejected because this would create ambiguity if a self-hosted instance uses a similar domain pattern or if cloud URLs change.

### Decision: Separate URLs per endpoint type in `PrizmAPIClient`

`PrizmAPIClient` shall be refactored to accept separate base URLs for API, Identity, and Icons endpoints. This matches the Bitwarden Cloud architecture (separate domains) and preserves flexibility for future self-hosted installations that might also use separate domains.

### Decision: `ServerEnvironment` entity to encapsulate configuration

A new Domain entity `ServerEnvironment` shall encapsulate the server type (cloud vs self-hosted) and the three URLs. This keeps the configuration type-safe and makes it easy to persist and restore the environment per account.

**Alternative considered**: Store three separate URL values without a container. Rejected because this decouples the three URLs that logically belong to a single environment configuration.

### Decision: Use `WKWebView` to support hCaptcha challenges

While this is more complex for initial implementation, it provides a maximally user-friendly experience. Using the system's built-in `WKWebView` does not deviate from the principles of native-first UI for this use case.

API key authentication via OAuth client credentials flow

Support personal API key authentication (client_id/client_secret) using the OAuth client credentials grant type. This bypasses the hCaptcha requirement entirely and is simpler than implementing a web view or system browser redirect.

**Alternative considered**: Support only API key auth initially, removing the need for hCaptcha entirely. Rejected as poor user experience.

**Alternative considered**: System browser OAuth redirect. Rejected as sub-optimal user experience, having to leave the app and return to it.

### Decision: Server environment persists per account

Server environment configuration shall be stored per account in secure `UserDefaults` (typically not a secret). When switching accounts, the correct environment for that account is restored. This ensures that multi-account users can have some accounts on cloud and others on self-hosted instances.

**Alternative considered**: Global server environment setting. Rejected because this would not support mixed multi-account scenarios.

### Decision: Client identifier for cloud only

The registered client identifier shall be included only in requests to Bitwarden Cloud endpoints. Self-hosted Vaultwarden instances do not require this header. The client identifier shall be configurable (not hardcoded) to facilitate updates and avoid including unreleased identifiers in source code.

## Risks / Trade-offs

- **Registered client identifier required for bitwarden.com release**: Per the Constitution line 220, a registered client identifier from Bitwarden, Inc. is required before any release targeting bitwarden.com. This must be obtained externally and configured at build or runtime. Mitigation: The design makes the client identifier configurable; placeholder value can be used for development.
- **URL validation must be careful for self-hosted**: Users may enter invalid URLs. Mitigation: Validate URL schemes (require HTTPS) and basic reachability before attempting login; surface clear error messages.
