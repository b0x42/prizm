## Why

Prizm currently supports self-hosted Vaultwarden instances but does not provide a built-in option for users who prefer Bitwarden's hosted cloud service.

This change adds first-class support for Bitwarden Cloud alongside self-hosted servers, including proper endpoint configuration, a straightforward cloud/self-hosted toggle in the login flow, and multiple authentication / validation pathways.

## What Changes

- Add `ServerEnvironment` domain entity to represent cloud vs self-hosted with separate URLs for API, Identity, and Icons
- Add `LoginView` UI toggle between "Bitwarden Cloud" (auto-filled URLs) and "Self-hosted" (manual URL entry)
- Configure `PrizmAPIClient` to use `ServerEnvironment` URLs (not a single base URL)
- Provide an in-app `WKWebView` modal for CAPTCHA verification
- Persist server environment configuration per account
- Include registered client identifier for Bitwarden Cloud requests

## Capabilities

### New Capabilities
- `hosted-cloud-support`: Enable users to choose Bitwarden Cloud or self-hosted Vaultwarden as their server environment

### Modified Capabilities
- `vault-browser-ui`: Login flow includes server environment selection UI

## Impact

- **Domain layer**: New `ServerEnvironment` entity, modified auth use cases to support API key flow
- **Data layer**: `PrizmAPIClient` updated to accept separate URLs per endpoint type; repository changes for server environment persistence
- **Presentation layer**: `LoginView` updated with server environment picker and API key option
  - If Bitwarden Cloud is selected, OAuth flow will include launching a `WKWebView` to pass Bitwarden's hosted hCaptcha
- **No changes to vault storage or sync mechanisms** — this change only affects how endpoints are configured, not how vault data is handled
