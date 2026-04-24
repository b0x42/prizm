## 1. Build Infrastructure

- [x] 1.1 Add `LocalSecrets.xcconfig.template` to `Prizm/` (same directory as `LocalConfig.xcconfig`) with empty `BW_CLIENT_IDENTIFIER` and copy instructions; xcconfig `#include` paths are relative to the including file so the template must live alongside `LocalConfig.xcconfig`
- [x] 1.2 Add `BWClientIdentifier` key to `Prizm/Prizm/Info.plist` with value `$(BW_CLIENT_IDENTIFIER)` (actual path — the file is currently an empty `<dict/>`)
- [x] 1.3 Add `LocalSecrets.xcconfig` to `.gitignore`
- [x] 1.4 Include `LocalSecrets.xcconfig` by adding `#include "LocalSecrets.xcconfig"` at the top of `LocalConfig.xcconfig`; also add the same line to `LocalConfig.xcconfig.template` (committed) so future devs who copy the template get the include automatically — `LocalConfig.xcconfig` is gitignored so the change cannot be committed directly; both Debug and Release build configurations reference `LocalConfig.xcconfig` as their `baseConfigurationReference` in the Xcode project
- [x] 1.5 Add `Config.bitwardenClientIdentifier` to `App/Config.swift` — reads `BWClientIdentifier` from `Bundle.main`, defaults to `""`
- [x] 1.6 Verify `Config.clientName` exists in `Config.swift` (used in `baseRequest()` for `Bitwarden-Client-Name` header); add if absent

## 2. Domain Layer — Protocols Only

_(Protocol declarations require no unit tests — skip straight to implementation.)_

- [x] 2.1 Add `LoginResult.requiresNewDeviceOTP` case to `AuthRepository.swift`
- [x] 2.2 Add `AuthError.clientIdentifierNotConfigured` case with `errorDescription`
- [x] 2.3 Update `LoginUseCase` protocol: change `execute` signature to accept `environment: ServerEnvironment` instead of `serverURL: String`
- [x] 2.4 Add `completeNewDeviceOTP(otp: String) async throws -> Account` to `LoginUseCase` protocol
- [x] 2.5 Add `resendNewDeviceOTP() async throws` to `LoginUseCase` protocol
- [x] 2.6 Add `cancelNewDeviceOTP()` to `LoginUseCase` protocol; update protocol doc comment to describe the full login flow
- [x] 2.7 Add `loginWithNewDeviceOTP(_ otp: String) async throws -> Account` to `AuthRepository` protocol
- [x] 2.8 Add `requestNewDeviceOTP() async throws` to `AuthRepository` protocol
- [x] 2.9 Add `cancelNewDeviceOTP()` to `AuthRepository` protocol
- [x] 2.10 Update `MockLoginUseCase` (`PrizmTests/Mocks/MockLoginUseCase.swift`) to add stub implementations for `completeNewDeviceOTP`, `resendNewDeviceOTP`, `cancelNewDeviceOTP` — protocol conformance requires this before any test target compiles

## 3. Domain Unit Tests — Entities (write before Group 4, must fail first)

- [x] 3.1 `ServerEnvironment` with `serverType == .cloudUS` returns `https://api.bitwarden.com`, `https://identity.bitwarden.com`, `https://icons.bitwarden.net`
- [x] 3.2 `ServerEnvironment` with `serverType == .cloudEU` returns `https://api.bitwarden.eu`, `https://identity.bitwarden.eu`, `https://icons.bitwarden.net`
- [x] 3.3 `ServerEnvironment` with `serverType == .selfHosted` and `base = https://vault.example.com` returns `base`-derived URLs unchanged
- [x] 3.4 Cloud cases ignore `overrides` — `ServerEnvironment.cloudUS()` with `overrides` set still returns canonical US URLs
- [x] 3.5 Decode a legacy JSON record (no `serverType` key) → `serverType == .selfHosted`
- [x] 3.6 Round-trip encode/decode for each `ServerType` case preserves exact raw string (`"cloudUS"`, `"cloudEU"`, `"selfHosted"`)

## 4. Domain Layer — Entities (implement after Group 3 tests are failing)

- [x] 4.1 Add `ServerType` enum (`cloudUS`, `cloudEU`, `selfHosted`) with `String` raw values to `Domain/Entities/Account.swift`
- [x] 4.2 Add `serverType: ServerType` property to `ServerEnvironment`; default to `.selfHosted` in `init` and in `Codable` decoding (legacy records with no key decode as `.selfHosted`)
- [x] 4.3 Update `ServerEnvironment` computed properties (`apiURL`, `identityURL`, `iconsURL`) to switch on `serverType` and return hardcoded cloud URLs for `cloudUS`/`cloudEU`, falling back to `base`-derived values for `selfHosted` only
- [x] 4.4 Add static factory methods `ServerEnvironment.cloudUS()` and `ServerEnvironment.cloudEU()` (sentinel `base = https://bitwarden.com`)

## 5. Data Layer — PrizmAPIClient

- [x] 5.0 Add `newDeviceOTP: String? = nil` parameter to `identityToken` in `PrizmAPIClientProtocol`, `PrizmAPIClientImpl`, and `MockPrizmAPIClient`; when non-nil, append `newdeviceotp=<value>` to the `application/x-www-form-urlencoded` body — same endpoint, one extra optional field; default `nil` keeps all existing call sites unchanged
- [x] 5.1 Add `IdentityTokenError.newDeviceNotVerified` case; handle `HTTP 400` + `"error": "device_error"` in `identityToken` to throw it (check only `error` field, not `error_description`)
- [x] 5.2 Rename `APIError.baseURLNotSet` to `APIError.serverEnvironmentNotSet`; update all catch sites and existing tests
- [x] 5.3 Replace `setBaseURL(_ url: URL)` with `setServerEnvironment(_ env: ServerEnvironment)` on `PrizmAPIClientProtocol`, `PrizmAPIClientImpl`, and `MockPrizmAPIClient`; remove `setBaseURL` entirely — the mock must be updated in this same task or Group 6 tests will not compile
- [x] 5.4 Make `clientId` instance state on `PrizmAPIClient` (set via `setServerEnvironment`): cloud environments use `Config.bitwardenClientIdentifier`, self-hosted keeps `"desktop"`
- [x] 5.5 Update all ~32 endpoint methods to route via `env.apiURL`, `env.identityURL`, or `env.iconsURL` using service-relative paths (e.g. `accounts/prelogin`, `connect/token`, `sync`) — strip the `api/` and `identity/` prefixes from the current path strings; the `ServerEnvironment` computed properties absorb the difference (cloud URLs have no prefix, self-hosted URLs include it)
- [x] 5.6 Add `Bitwarden-Client-Name` header to `baseRequest()` using `Config.clientName`

## 6. Data Unit Tests — PrizmAPIClient (write before Group 5 implementation, must fail first; requires mock protocol stubs from 2.10 and the `setServerEnvironment` signature from 5.3 to compile — add the mock stub in 5.3 before writing these tests)

- [x] 6.1 `setServerEnvironment` with `cloudUS` → subsequent `preLogin` request URL is `https://api.bitwarden.com/accounts/prelogin` (no `api/` prefix in path)
- [x] 6.2 `setServerEnvironment` with `cloudEU` → subsequent `identityToken` request URL is `https://identity.bitwarden.eu/connect/token` (no `identity/` prefix in path)
- [x] 6.3 `setServerEnvironment` with `cloudEU` → subsequent `refreshAccessToken` URL is `https://identity.bitwarden.eu/connect/token`
- [x] 6.4 `setServerEnvironment` with `selfHosted(base: https://vault.example.com)` → `fetchSync` URL is `https://vault.example.com/api/sync` (self-hosted retains `api/` prefix)
- [x] 6.5 Request made before `setServerEnvironment` throws `APIError.serverEnvironmentNotSet`
- [x] 6.6 Cloud `identityToken` request sends `Bitwarden-Client-Name` and `Bitwarden-Client-Version` HTTP headers
- [x] 6.7 Cloud `identityToken` `client_id` form parameter equals `Config.bitwardenClientIdentifier` (not `"desktop"`)
- [x] 6.8 Cloud `refreshAccessToken` `client_id` form parameter equals `Config.bitwardenClientIdentifier`
- [x] 6.9 Self-hosted `identityToken` `client_id` equals `"desktop"`
- [x] 6.10 `identityToken` with `HTTP 400` + `{"error": "device_error"}` throws `IdentityTokenError.newDeviceNotVerified`

## 7. Data Layer — AuthRepositoryImpl

- [x] 7.1 Update all four `setBaseURL` call sites to `setServerEnvironment` (lines 83, 325, 540, 606)
- [x] 7.2 Catch `IdentityTokenError.newDeviceNotVerified` in `loginWithPassword` and return `LoginResult.requiresNewDeviceOTP`; store a new `PendingNewDeviceOTP` struct (separate from `PendingTwoFactor`) holding `email: String`, `passwordHash: String`, `var stretchedKeys: CryptoKeys` (`var` so zeroing is possible), `deviceId: String`, `environment: ServerEnvironment`; `stretchedKeys` MUST be zeroed before the struct is released on cancel or failure (Constitution §III) — follow the same in-place mutation pattern as `cancelTwoFactor()`
- [x] 7.3 Add `clientIdentifier: String = Config.bitwardenClientIdentifier` parameter to `AuthRepositoryImpl.init` (production callers pass no arg; tests inject `""` to verify the guard fires, or `"test-id"` to bypass it); guard cloud login: if `environment.serverType != .selfHosted && clientIdentifier.isEmpty`, throw `AuthError.clientIdentifierNotConfigured` before any network request
- [x] 7.4 Skip `validateServerURL` for cloud environments; call only when `environment.serverType == .selfHosted`
- [x] 7.5 Implement `loginWithNewDeviceOTP(_ otp: String)`: read `pendingNewDeviceOTP` (throws `AuthError.invalidCredentials` if nil); call `identityToken(email:passwordHash:deviceIdentifier:newDeviceOTP:)` using the pending struct's fields; on success call `finalizeSession(tokenResp:stretched:environment:)` using the pending struct's `stretchedKeys` and `environment`; zero `stretchedKeys` and nil `pendingNewDeviceOTP` in a `defer` block so cleanup happens on both success and failure (Constitution §III)
- [x] 7.6 Implement `requestNewDeviceOTP()`: re-post original `identityToken` without `newdeviceotp` using the pending struct's credentials; the server WILL respond with `HTTP 400 + device_error` again — this is expected (it triggers a new OTP email); catch `IdentityTokenError.newDeviceNotVerified` and treat it as **success**; propagate any other error; do NOT zero cached credentials. **Implementation note**: add a code comment explaining that catching `newDeviceNotVerified` as success is intentional — the "error" response is the server's way of confirming it dispatched a new OTP email; do not "fix" this by removing the catch.
- [x] 7.7 Implement `cancelNewDeviceOTP()`: zero `pendingNewDeviceOTP!.stretchedKeys` buffers in-place (Constitution §III — same pattern as `cancelTwoFactor()`), then set `pendingNewDeviceOTP = nil`; no network request
- [x] 7.8 Self-hosted `device_error` response (unexpected): surface as `AuthError.invalidCredentials`

## 8. Data Unit Tests — AuthRepositoryImpl + LoginUseCaseImpl (write before Groups 7 + 9, must fail first)

- [x] 8.1 `AuthRepositoryImpl.setServerEnvironment` calls `apiClient.setServerEnvironment` (not `setBaseURL`)
- [x] 8.2 `AuthRepositoryImpl.loginWithPassword` returns `LoginResult.requiresNewDeviceOTP` when `identityToken` throws `IdentityTokenError.newDeviceNotVerified`
- [x] 8.3 `AuthRepositoryImpl` throws `AuthError.clientIdentifierNotConfigured` when injected `clientIdentifier` is `""` and `serverType` is cloud — no network request made; use `init(..., clientIdentifier: "")` in the test to trigger the guard
- [x] 8.4 `LoginUseCaseImpl` does NOT call `auth.validateServerURL` when `environment.serverType == .cloudUS` or `.cloudEU`
- [x] 8.5 `LoginUseCaseImpl` DOES call `auth.validateServerURL` when `environment.serverType == .selfHosted`
- [x] 8.6 Cached credentials zeroed after `loginWithNewDeviceOTP` succeeds
- [x] 8.7 Cached credentials zeroed after `loginWithNewDeviceOTP` fails
- [x] 8.8 Cached credentials zeroed after `cancelNewDeviceOTP`
- [x] 8.9 `requestNewDeviceOTP` does NOT zero cached credentials
- [x] 8.10 OTP retry includes `newdeviceotp` form parameter
- [x] 8.11 `LoginUseCaseImpl.completeNewDeviceOTP` calls `auth.loginWithNewDeviceOTP` and triggers sync on success
- [x] 8.12 `LoginUseCaseImpl.cancelNewDeviceOTP` calls `auth.cancelNewDeviceOTP` and makes no network request
- [x] 8.13 `LoginUseCaseImpl.resendNewDeviceOTP` calls `auth.requestNewDeviceOTP` (not `loginWithNewDeviceOTP`)

## 9. LoginUseCaseImpl

- [x] 9.1 Update `execute` to accept `environment: ServerEnvironment`; remove internal URL string construction; pass environment directly to `auth.setServerEnvironment`
- [x] 9.2 Implement `completeNewDeviceOTP(otp:)`: call `auth.loginWithNewDeviceOTP`, trigger sync, return `Account`
- [x] 9.3 Implement `resendNewDeviceOTP()`: call `auth.requestNewDeviceOTP`
- [x] 9.4 Implement `cancelNewDeviceOTP()`: call `auth.cancelNewDeviceOTP`

## 10. Presentation Unit Tests (write before Group 11, must fail first)

- [x] 10.1 `LoginViewModel` initialised with `UserDefaults` key `com.prizm.login.lastServerType = "cloudEU"` → `serverType == .cloudEU`
- [x] 10.2 `LoginViewModel` initialised with no `UserDefaults` key → `serverType` defaults to `.cloudUS`
- [x] 10.3 Selecting a cloud type persists to `UserDefaults`; selecting self-hosted restores last entered URL; `serverURL` persisted to `UserDefaults` and restored on init
- [x] 10.4 `isSignInDisabled` returns `true` when `flowState == .loading` (prevents double-submit regardless of field content)
- [x] 10.5 `isSignInDisabled` returns `false` for cloud when email and password non-empty, `serverURL` empty
- [x] 10.6 `isSignInDisabled` returns `true` for self-hosted when `serverURL` empty, email and password filled
- [x] 10.7 `isSignInDisabled` returns `true` when `flowState == .otpPrompt` and `otpCode` is empty
- [x] 10.8 `isSignInDisabled` returns `false` when `flowState == .otpPrompt` and `otpCode` is non-empty
- [x] 10.9 `flowState` transitions to `.otpPrompt` when `execute` returns `LoginResult.requiresNewDeviceOTP`
- [x] 10.10 `flowState` transitions to `.login` when Cancel tapped (after `cancelNewDeviceOTP`)
- [x] 10.11 `flowState` remains `.otpPrompt` after invalid OTP error; error message set
- [x] 10.12 `resendNewDeviceOTP` called when Resend tapped; `otpCode` cleared on success; confirmation announced
- [x] 10.13 `resendNewDeviceOTP` throws → `flowState` returns to `.otpPrompt`, error message set, `otpCode` unchanged
- [x] 10.14 `otpCode` cleared from memory after successful OTP submission in `submitOTP()`

## 11. Presentation — LoginViewModel

- [x] 11.1 Add `serverType: ServerType` `@Published` property; persist/restore via `UserDefaults` key `com.prizm.login.lastServerType`; default to `.cloudUS` when key absent (fresh install)
- [x] 11.1a Persist `serverURL` to `UserDefaults` key `com.prizm.login.lastServerURL` when the user modifies it; restore on init so the self-hosted URL survives app restarts and server-type switching within a session
- [x] 11.2 Add `isSignInDisabled: Bool` computed property: `true` when `flowState == .loading` (prevents double-submit) OR (cloud + email or password empty) OR (selfHosted + email, password, or serverURL empty) OR (otpPrompt + `otpCode` empty)
- [x] 11.3 Update `signIn()` to construct `ServerEnvironment` from `serverType` (`.cloudUS()` / `.cloudEU()` / `selfHosted` from URL string) and call `loginUseCase.execute(environment:email:masterPassword:)`
- [x] 11.4 Handle `LoginResult.requiresNewDeviceOTP` in `signIn()`: set `flowState = .otpPrompt`
- [x] 11.5 Add `otpCode: String` `@Published` property for the OTP text field
- [x] 11.6 Add `submitOTP()` method: calls `loginUseCase.completeNewDeviceOTP(otp: otpCode)`; clear `otpCode` immediately on call (§III); on success → sync flow; on `invalid_grant` error → stay `.otpPrompt` with error message
- [x] 11.7 Add `resendOTP()` method: calls `loginUseCase.resendNewDeviceOTP()`; on success → clear `otpCode`, announce "A new code has been sent to your email"; on error → set error message, leave `otpCode` unchanged
- [x] 11.8 Add `cancelOTP()` method: calls `loginUseCase.cancelNewDeviceOTP()`, sets `flowState = .login`
- [x] 11.9 Post `AccessibilityNotification.Announcement` for all new error messages as they appear

## 12. Presentation — Views

- [x] 12.1 Add new identifiers to `AccessibilityID.Login` in `Presentation/AccessibilityIdentifiers.swift`: `serverTypePicker`, `newDeviceOtpField`, `resendOtpButton`, `cancelOtpButton`, `otpErrorMessage`
- [x] 12.2 Add `LoginFlowState.otpPrompt` case to `LoginFlowState` enum in `LoginViewModel.swift`
- [x] 12.3 Add `Screen.otpPrompt` case to `RootViewModel.Screen` in `PrizmApp.swift`
- [x] 12.4 Update `RootViewModel.handleLoginFlow` to map `.otpPrompt → .otpPrompt`
- [x] 12.5 Update `LoginView`: replace static subtitle with three-way `Picker` bound to `viewModel.serverType`; hide server URL field for cloud options; wire Sign In button `disabled` to `viewModel.isSignInDisabled`
- [x] 12.6 Apply `accessibilityIdentifier(AccessibilityID.Login.serverTypePicker)`, `accessibilityLabel("Server")`, and `accessibilityValue` (current selection label) to the picker
- [x] 12.7 Create `NewDeviceOTPView` (pattern: `TOTPPromptView`): header title with `.isHeader` trait, OTP text field, Sign In button, Resend button, Cancel button; wire Sign In `disabled` to `viewModel.isSignInDisabled`
- [x] 12.8 Apply accessibility identifiers on `NewDeviceOTPView` controls: `AccessibilityID.Login.newDeviceOtpField` (label: "Verification code"), `AccessibilityID.Login.resendOtpButton` (label: "Resend code"), `AccessibilityID.Login.cancelOtpButton` (label: "Cancel"), `AccessibilityID.Login.otpErrorMessage` on error label
- [x] 12.9 Update `PrizmApp` root switch to show `NewDeviceOTPView(viewModel: rootVM.loginVM)` for `.otpPrompt`

## 13. Integration Test

- [x] 13.1 Verify full login flow against Vaultwarden stub (existing integration test) passes after `PrizmAPIClient` refactor

## 14. XCUITest

- [x] 14.1 Three-way picker visible on `LoginView`; all three options selectable
- [x] 14.2 Selecting cloud hides server URL field; selecting self-hosted shows it
- [x] 14.3 Sign In button enabled for cloud with email + password, empty `serverURL`
- [x] 14.4 Sign In button disabled for self-hosted when `serverURL` empty
- [x] 14.5 Successful cloud login against local stub (no OTP path)
- [x] 14.6 `device_error` response → `NewDeviceOTPView` appears with label "Check your email for a verification code"
- [x] 14.7 Valid OTP submitted → login succeeds; OTP field disappears
- [x] 14.8 Invalid OTP → error message shown (query via `AccessibilityID.Login.otpErrorMessage`); OTP field remains

## 15. Observability

- [x] 15.1 Log server environment selection and restoration at `.info` (include `serverType` value; no secrets)
- [x] 15.2 Log each `identityToken` request at `.info` with `identityURL` (not password or hash)
- [x] 15.3 Log `requiresNewDeviceOTP` returned and OTP retry at `.info`
- [x] 15.4 Log `invalid_grant` on OTP retry at `.error`
- [x] 15.5 Log `clientIdentifierNotConfigured` at `.error` before surfacing to Presentation
- [x] 15.6 Log URL validation failures at `.error`

## 16. Documentation

- [x] 16.1 Add `Config.bitwardenApiVersion = "2026.4.0"` to `App/Config.swift`
- [x] 16.2 Update `DEVELOPMENT.md`: add `LocalSecrets.xcconfig` section with copy command, xcconfig/Info.plist/Config.swift key names, and note that self-hosted login is unaffected without the file
- [x] 16.3 Update `SECURITY.md`: document cloud endpoints, OTP memory handling, client identifier injection
- [x] 16.4 Update `ACCESSIBILITY.md`: document server picker VoiceOver behaviour and `NewDeviceOTPView` OTP field/announcement behaviour
- [x] 16.5 Update `CLAUDE.md` active changes table: add `hosted-cloud-support` row
