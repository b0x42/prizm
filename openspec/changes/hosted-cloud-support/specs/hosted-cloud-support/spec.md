## Purpose

Defines support for Bitwarden-hosted cloud services alongside self-hosted Vaultwarden instances, including endpoint environment configuration, cloud/self-hosted server selection in the login flow, and integration with the existing Bitwarden API client.

## Requirements

### Requirement: Login UI provides cloud/self-hosted toggle
The system SHALL display a picker or toggle in the `LoginView` that allows users to choose between "Bitwarden Cloud" and "Self-hosted" server environments. When "Bitwarden Cloud" is selected, the system SHALL auto-fill the standard URLs (api.bitwarden.com, identity.bitwarden.com, icons.bitwarden.net) and disable manual URL fields. When "Self-hosted" is selected, the system SHALL enable manual URL entry fields and use those user-provided URLs for all API communication. The selection SHALL be persisted across app launches.

#### Scenario: Toggle visible on login screen
- **WHEN** the `LoginView` is displayed
- **THEN** a picker or toggle SHALL be visible offering "Bitwarden Cloud" and "Self-hosted" options

#### Scenario: Cloud selection auto-fills standard URLs
- **WHEN** the user selects "Bitwarden Cloud"
- **THEN** the API URL field SHALL be pre-filled with "https://api.bitwarden.com"
- **AND** the Identity URL field SHALL be pre-filled with "https://identity.bitwarden.com"
- **AND** the Icons URL field SHALL be pre-filled with "https://icons.bitwarden.net"
- **AND** the manual URL fields SHALL be disabled (non-editable)

#### Scenario: Self-hosted selection enables manual URL entry
- **WHEN** the user selects "Self-hosted"
- **THEN** the manual URL fields SHALL become editable
- **AND** the fields SHALL be empty or retain previously entered values
- **AND** the user can enter custom URLs for API, Identity, and Icons endpoints

#### Scenario: Selection is persisted across app launches
- **GIVEN** the user selected "Bitwarden Cloud" on a previous launch
- **WHEN** the app is relaunched and the `LoginView` appears
- **THEN** the picker SHALL retain the "Bitwarden Cloud" selection
- **AND** the standard cloud URLs SHALL be pre-filled and disabled

#### Scenario: Self-hosted URLs are persisted
- **GIVEN** the user selected "Self-hosted" and entered custom URLs
- **WHEN** the app is relaunched and the `LoginView` appears
- **THEN** the picker SHALL retain the "Self-hosted" selection
- **AND** the previously entered custom URLs SHALL be pre-filled

---

### Requirement: API client uses `ServerEnvironment` URLs based on selection
The system SHALL configure `PrizmAPIClient` with the appropriate URLs based on the user's server environment selection. All network requests to `api/...` paths SHALL use the configured API base URL, all requests to `identity/...` paths SHALL use the configured Identity base URL, and all icon requests SHALL use the configured Icons base URL. The system SHALL NOT append these paths dynamically to a single base URL; each endpoint type SHALL resolve to its configured environment URL.

#### Scenario: API requests use cloud URLs when cloud is selected
- **GIVEN** the user has selected "Bitwarden Cloud"
- **WHEN** `PrizmAPIClient` makes a request to an `api/...` endpoint
- **THEN** the request SHALL be sent to `https://api.bitwarden.com/api/...`

#### Scenario: Identity requests use cloud URLs when cloud is selected
- **GIVEN** the user has selected "Bitwarden Cloud"
- **WHEN** `PrizmAPIClient` makes a request to an `identity/...` endpoint
- **THEN** the request SHALL be sent to `https://identity.bitwarden.com/identity/...`

#### Scenario: Icon requests use cloud URLs when cloud is selected
- **GIVEN** the user has selected "Bitwarden Cloud"
- **WHEN** `PrizmAPIClient` fetches a favicon or icon
- **THEN** the request SHALL be sent to `https://icons.bitwarden.net`

#### Scenario: API requests use self-hosted URLs when self-hosted is selected
- **GIVEN** the user has selected "Self-hosted" and entered "https://vault.example.com" as the API URL
- **WHEN** `PrizmAPIClient` makes a request to an `api/...` endpoint
- **THEN** the request SHALL be sent to `https://vault.example.com/api/...`

#### Scenario: Identity requests use self-hosted URLs when self-hosted is selected
- **GIVEN** the user has selected "Self-hosted" and entered "https://vault.example.com" as the Identity URL
- **WHEN** `PrizmAPIClient` makes a request to an `identity/...` endpoint
- **THEN** the request SHALL be sent to `https://vault.example.com/identity/...`

#### Scenario: Icons requests use self-hosted URLs when self-hosted is selected
- **GIVEN** the user has selected "Self-hosted" and entered "https://vault.example.com" as the Icons URL
- **WHEN** `PrizmAPIClient` fetches a favicon or icon
- **THEN** the request SHALL be sent to `https://vault.example.com`

---

### Requirement: `ServerEnvironment` configuration persists per account
The system SHALL store the server environment selection (cloud or self-hosted) and associated URLs per account in a secure persistence layer. When the user switches accounts or after app restart, the system SHALL restore the correct server environment for each account. The active account's environment SHALL be used for all network requests.

#### Scenario: Environment stored after successful login
- **GIVEN** the user successfully logs in with a specific server environment
- **WHEN** the login completes
- **THEN** the server environment selection and URLs SHALL be persisted for that account

#### Scenario: Environment restored on app launch for active account
- **GIVEN** the user was logged into an account configured for "Bitwarden Cloud"
- **WHEN** the app is relaunched and the vault is unlocked
- **THEN** `PrizmAPIClient` SHALL be configured to use cloud URLs for that account

#### Scenario: Multiple accounts can have different environments
- **GIVEN** Account A is configured for "Bitwarden Cloud"
- **AND** Account B is configured for "Self-hosted" with custom URLs
- **WHEN** the user switches from Account A to Account B
- **THEN** `PrizmAPIClient` SHALL update to use Account B's self-hosted URLs

---

### Requirement: Registered client identifier is used for cloud requests
The system SHALL include a registered client identifier in API requests when communicating with Bitwarden Cloud (`api.bitwarden.com`). The client identifier SHALL be obtained from Bitwarden, Inc. per their Device Registration requirements and shall be included in the appropriate headers per their API specification. Self-hosted Vaultwarden instances SHALL NOT require this header.

#### Scenario: Client identifier present in cloud API requests
- **GIVEN** the user has selected "Bitwarden Cloud"
- **WHEN** `PrizmAPIClient` makes a request to a cloud API endpoint
- **THEN** the request SHALL include the registered client identifier as part of the appropriate OAuth token exchange

#### Scenario: Client identifier not required for self-hosted requests
- **GIVEN** the user has selected "Self-hosted"
- **WHEN** `PrizmAPIClient` makes a request to a self-hosted Vaultwarden instance
- **THEN** the request SHALL NOT include the client identifier header

#### Scenario: Missing client identifier prevents cloud login
- **GIVEN** the user has selected "Bitwarden Cloud" and no client identifier is configured
- **WHEN** the user attempts to log in
- **THEN** the login SHALL fail with an error indicating that the client identifier is required

---

### Requirement: System supports CAPTCHA verification for cloud login
The system SHALL support authentication via Bitwarden Cloud's standard pattern. As of 2026-04-18, this includes CAPTCHA verification via [hCaptcha](https://www.hcaptcha.com/). The system SHALL launch a web view modal (`WKWebView` using standard macOS configuration) in order to pass such challenges.

API keys SHALL be stored securely in the Keychain after a successful login.

#### Scenario: API key login option is visible for cloud
- **GIVEN** the user has selected "Bitwarden Cloud"
- **WHEN** the `LoginView` is displayed
- **THEN** an option to log in with API keys SHALL be visible

#### Scenario: API key fields accept client_id and client_secret
- **GIVEN** the user has chosen the API key login option
- **WHEN** the user enters their client_id and client_secret
- **THEN** the fields SHALL validate the format (non-empty strings)

#### Scenario: API key login bypasses hCaptcha
- **GIVEN** the user has entered valid API keys
- **WHEN** the system submits the OAuth token request
- **THEN** no hCaptcha challenge SHALL be presented
- **AND** the login SHALL proceed directly on successful token exchange

#### Scenario: API keys are stored in Keychain on successful login
- **GIVEN** the user has successfully logged in via API keys
- **WHEN** the login completes
- **THEN** the client_id and client_secret SHALL be stored securely in the Keychain
- **AND** future logins for this account SHALL be able to use the stored keys

#### Scenario: Invalid API keys show clear error message
- **WHEN** the user enters invalid API keys and attempts to log in
- **THEN** an error message SHALL be displayed indicating that the API keys are invalid
- **AND** the login SHALL not proceed

#### Scenario: API key login option not shown for self-hosted by default
- **GIVEN** the user has selected "Self-hosted"
- **WHEN** the `LoginView` is displayed
- **THEN** the API key login option SHALL NOT be shown (unless the self-hosted instance explicitly supports OAuth)

---

### Requirement: Errors from server environment configuration are surfaced clearly
The system SHALL validate server environment URLs before attempting login. If the user enters an invalid URL scheme or unreachable endpoint for self-hosted configuration, the system SHALL surface a clear error message indicating the specific validation failure. Network errors during login SHALL distinguish between connectivity issues, authentication failures, and server configuration errors.

#### Scenario: Invalid URL scheme is rejected
- **WHEN** the user enters a URL without https:// in a self-hosted field
- **THEN** the system SHALL reject the URL and show an error message indicating that HTTPS is required

#### Scenario: Unreachable endpoint shows clear error
- **WHEN** the user enters a self-hosted URL that cannot be reached
- **THEN** the login attempt SHALL fail with an error message indicating the server is unreachable
- **AND** the specific endpoint that failed SHALL be mentioned (API or Identity)

#### Scenario: Authentication failure is distinguished from network error
- **WHEN** login fails due to invalid credentials
- **THEN** the error message SHALL clearly indicate an authentication failure
- **AND** SHALL be distinct from network connectivity error messages

#### Scenario: Cloud endpoint unreachable shows specific message
- **WHEN** the user selects "Bitwarden Cloud" and cloud endpoints are unreachable
- **THEN** the error message SHALL indicate that Bitwarden Cloud services are temporarily unavailable
-
