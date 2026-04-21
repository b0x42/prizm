## Why

Prizm currently supports self-hosted Vaultwarden instances but does not provide a built-in option for users who prefer Bitwarden's hosted cloud service.

This change adds first-class support for Bitwarden Cloud alongside self-hosted servers, including proper endpoint configuration and a cloud/self-hosted toggle in the login flow.

## Scope

**This release:** Single active account. The user picks cloud or self-hosted at login. Only one account is active at a time.

**Deferred to a later release:** Running a cloud account and a self-hosted account simultaneously (multi-account UI). The data layer is designed for multi-account from the start (per-userId Keychain keys), so that release will require no data layer changes.

## What Changes

- Extend `ServerEnvironment` domain entity with a three-case `ServerType` enum: `cloudUS`, `cloudEU`, `selfHosted` — each case returns the correct canonical URLs from the computed properties
- Refactor `PrizmAPIClient` to accept a `ServerEnvironment` instead of a single base URL, wiring `apiURL`/`identityURL`/`iconsURL` through to all ~32 call sites
- Update `LoginView` with a three-way picker (Bitwarden Cloud (US) / Bitwarden Cloud (EU) / Self-hosted); hide the server URL field for cloud options
- Replace `ClientHeaders.clientId` (`"desktop"`) with the registered identifier from Bitwarden, Inc., injected at build time via gitignored xcconfig — this is what authorises email/password login on Bitwarden Cloud
- Handle hCaptcha challenges via an in-app `WKWebView` modal when the cloud server requires it

## Capabilities

### New Capabilities
- `hosted-cloud-support`: Enable users to choose Bitwarden Cloud or self-hosted Vaultwarden as their server environment

### Modified Capabilities
- `vault-browser-ui`: Login flow includes server environment selection UI

## Impact

- **Domain layer**: `ServerEnvironment` extended with `ServerType` enum; no breaking changes to existing self-hosted accounts
- **Data layer**: `PrizmAPIClient` refactored to use per-service URLs; `AuthRepositoryImpl.setServerEnvironment` wired to new API client method; backwards-compatible Keychain migration for existing records
- **Presentation layer**: `LoginView` updated with server type picker for cloud/self-hosted selection; no changes to vault browser or sync UI
- **No changes to vault storage or sync mechanisms**
