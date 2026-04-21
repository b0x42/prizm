## 1. Build Infrastructure

- [ ] 1.1 Add `LocalSecrets.xcconfig.template` to repo root with empty `BW_CLIENT_IDENTIFIER` and copy instructions
- [ ] 1.2 Add `BWClientIdentifier` key to `Prizm/Prizm-Info.plist` with value `$(BW_CLIENT_IDENTIFIER)`
- [ ] 1.3 Add `LocalSecrets.xcconfig` to `.gitignore`
- [ ] 1.4 Include `LocalSecrets.xcconfig` in Xcode project under Debug and Release configurations (analogous to `LocalConfig.xcconfig`)
- [ ] 1.5 Add `Config.bitwardenClientIdentifier` to `App/Config.swift` — reads `BWClientIdentifier` from `Bundle.main`, defaults to `""`
- [ ] 1.6 Verify `Config.clientName` exists in `Config.swift` (used in `baseRequest()` for `Bitwarden-Client-Name` header); add if absent

## 2. Domain Layer — Entities and Protocols

- [ ] 2.1 Add `ServerType` enum (`cloudUS`, `cloudEU`, `selfHosted`) with `String` raw values to `Domain/Entities/Account.swift`
- [ ] 2.2 Add `serverType: ServerType` property to `ServerEnvironment`; default to `.selfHosted` in `init` and in `Codable` decoding (legacy records with no key decode as `.selfHosted`)
- [ ] 2.3 Update `ServerEnvironment` computed properties (`apiURL`, `identityURL`, `iconsURL`) to switch on `serverType` and return hardcoded cloud URLs for `cloudUS`/`cloudEU`, falling back to `base`-derived values for `selfHosted` only
- [ ] 2.4 Add static factory methods `ServerEnvironment.cloudUS()` and `ServerEnvironment.cloudEU()` (sentinel `base = https://bitwarden.com`)
- [ ] 2.5 Add `LoginResult.requiresNewDeviceOTP` case to `AuthRepository.swift`
- [ ] 2.6 Add `AuthError.clientIdentifierNotConfigured` case with `errorDescription`
- [ ] 2.7 Update `LoginUseCase` protocol: change `execute` signature to accept `environment: ServerEnvironment` instead of `serverURL: String`
- [ ] 2.8 Add `completeNewDeviceOTP(otp: String) async throws -> Account` to `LoginUseCase` protocol
- [ ] 2.9 Add `resendNewDeviceOTP() async throws` to `LoginUseCase` protocol
- [ ] 2.10 Add `cancelNewDeviceOTP()` to `LoginUseCase` protocol; update protocol doc comment to describe the full login flow
- [ ] 2.11 Add `loginWithNewDeviceOTP(_ otp: String) async throws -> Account` to `AuthRepository` protocol
- [ ] 2.12 Add `requestNewDeviceOTP() async throws` to `AuthRepository` protocol
- [ ] 2.13 Add `cancelNewDeviceOTP()` to `AuthRepository` protocol

## 3. Domain Unit Tests (write before implementing)

- [ ] 3.1 `ServerEnvironment` with `serverType == .cloudUS` returns `https://api.bitwarden.com`, `https://identity.bitwarden.com`, `https://icons.bitwarden.net`
- [ ] 3.2 `ServerEnvironment` with `serverType == .cloudEU` returns `https://api.bitwarden.eu`, `https://identity.bitwarden.eu`, `https://icons.bitwarden.net`
- [ ] 3.3 `ServerEnvironment` with `serverType == .selfHosted` and `base = https://vault.example.com` returns `base`-derived URLs unchanged
- [ ] 3.4 Cloud cases ignore `overrides` — `ServerEnvironment.cloudUS()` with `overrides` set still returns canonical US URLs
- [ ] 3.5 Decode a legacy JSON record (no `serverType` key) → `serverType == .selfHosted`
- [ ] 3.6 Round-trip encode/decode for each `ServerType` case preserves exact raw string (`"cloudUS"`, `"cloudEU"`, `"selfHosted"`)

## 4. Data Layer — PrizmAPIClient

- [ ] 4.1 Add `IdentityTokenError.newDeviceNotVerified` case; handle `HTTP 400` + `"error": "device_error"` in `identityToken` to throw it (check only `error` field, not `error_description`)
- [ ] 4.2 Rename `APIError.baseURLNotSet` to `APIError.serverEnvironmentNotSet`; update all catch sites and existing tests
- [ ] 4.3 Replace `setBaseURL(_ url: URL)` with `setServerEnvironment(_ env: ServerEnvironment)` on `PrizmAPIClientProtocol` and `PrizmAPIClientImpl`; remove `setBaseURL` entirely
- [ ] 4.4 Make `clientId` instance state on `PrizmAPIClient` (set via `setServerEnvironment`): cloud environments use `Config.bitwardenClientIdentifier`, self-hosted keeps `"desktop"`
- [ ] 4.5 Update all ~32 endpoint methods to route via `env.apiURL`, `env.identityURL`, or `env.iconsURL` instead of appending to a single `base`
- [ ] 4.6 Add `Bitwarden-Client-Name` header to `baseRequest()` using `Config.clientName`

## 5. Data Unit Tests — PrizmAPIClient (write before implementing)

- [ ] 5.1 `setServerEnvironment` with `cloudUS` → subsequent `preLogin` request URL uses `https://api.bitwarden.com`
- [ ] 5.2 `setServerEnvironment` with `cloudEU` → subsequent `identityToken` request URL uses `https://identity.bitwarden.eu`
- [ ] 5.3 `setServerEnvironment` with `cloudEU` → subsequent `refreshAccessToken` URL uses `https://identity.bitwarden.eu`
- [ ] 5.4 `setServerEnvironment` with `selfHosted(base: https://vault.example.com)` → `fetchSync` URL uses `https://vault.example.com/api`
- [ ] 5.5 Request made before `setServerEnvironment` throws `APIError.serverEnvironmentNotSet`
- [ ] 5.6 Cloud `identityToken` request sends `Bitwarden-Client-Name` and `Bitwarden-Client-Version` headers
- [ ] 5.7 Cloud `identityToken` `client_id` equals `Config.bitwardenClientIdentifier` (not `"desktop"`)
- [ ] 5.8 Cloud `refreshAccessToken` `client_id` equals `Config.bitwardenClientIdentifier`
- [ ] 5.9 Self-hosted `identityToken` `client_id` equals `"desktop"`
- [ ] 5.10 `identityToken` with `HTTP 400` + `{"error": "device_error"}` throws `IdentityTokenError.newDeviceNotVerified`

## 6. Data Layer — AuthRepositoryImpl

- [ ] 6.1 Update all four `setBaseURL` call sites to `setServerEnvironment` (lines 83, 325, 540, 606)
- [ ] 6.2 Catch `IdentityTokenError.newDeviceNotVerified` in `loginWithPassword` and return `LoginResult.requiresNewDeviceOTP`; hold `environment`, `email`, and hashed password in memory
- [ ] 6.3 Guard cloud login with `Config.bitwardenClientIdentifier.isEmpty` check; throw `AuthError.clientIdentifierNotConfigured` before any network request
- [ ] 6.4 Skip `validateServerURL` for cloud environments; call only when `environment.serverType == .selfHosted`
- [ ] 6.5 Implement `loginWithNewDeviceOTP(_ otp: String)`: retry `identityToken` with `newdeviceotp` param; zero cached credentials after (success or failure)
- [ ] 6.6 Implement `requestNewDeviceOTP()`: re-post original `identityToken` without `newdeviceotp`; do NOT zero cached credentials
- [ ] 6.7 Implement `cancelNewDeviceOTP()`: zero cached credentials without network request
- [ ] 6.8 Self-hosted `device_error` response (unexpected): surface as `AuthError.invalidCredentials`

## 7. Data Unit Tests — AuthRepositoryImpl + LoginUseCaseImpl (write before implementing)

- [ ] 7.1 `AuthRepositoryImpl.setServerEnvironment` calls `apiClient.setServerEnvironment` (not `setBaseURL`)
- [ ] 7.2 `AuthRepositoryImpl.loginWithPassword` returns `LoginResult.requiresNewDeviceOTP` when `identityToken` throws `IdentityTokenError.newDeviceNotVerified`
- [ ] 7.3 `AuthRepositoryImpl` throws `AuthError.clientIdentifierNotConfigured` when `Config.bitwardenClientIdentifier` is empty and `serverType` is cloud — no network request made
- [ ] 7.4 `LoginUseCaseImpl` does NOT call `auth.validateServerURL` when `environment.serverType == .cloudUS` or `.cloudEU`
- [ ] 7.5 `LoginUseCaseImpl` DOES call `auth.validateServerURL` when `environment.serverType == .selfHosted`
- [ ] 7.6 Cached credentials zeroed after `loginWithNewDeviceOTP` succeeds
- [ ] 7.7 Cached credentials zeroed after `loginWithNewDeviceOTP` fails
- [ ] 7.8 Cached credentials zeroed after `cancelNewDeviceOTP`
- [ ] 7.9 `requestNewDeviceOTP` does NOT zero cached credentials
- [ ] 7.10 OTP retry includes `newdeviceotp` form parameter
- [ ] 7.11 `LoginUseCaseImpl.completeNewDeviceOTP` calls `auth.loginWithNewDeviceOTP` and triggers sync on success
- [ ] 7.12 `LoginUseCaseImpl.cancelNewDeviceOTP` calls `auth.cancelNewDeviceOTP` and makes no network request
- [ ] 7.13 `LoginUseCaseImpl.resendNewDeviceOTP` calls `auth.requestNewDeviceOTP` (not `loginWithNewDeviceOTP`)

## 8. LoginUseCaseImpl

- [ ] 8.1 Update `execute` to accept `environment: ServerEnvironment`; remove internal URL string construction; pass environment directly to `auth.setServerEnvironment`
- [ ] 8.2 Implement `completeNewDeviceOTP(otp:)`: call `auth.loginWithNewDeviceOTP`, trigger sync, return `Account`
- [ ] 8.3 Implement `resendNewDeviceOTP()`: call `auth.requestNewDeviceOTP`
- [ ] 8.4 Implement `cancelNewDeviceOTP()`: call `auth.cancelNewDeviceOTP`

## 9. Presentation Unit Tests (write before implementing)

- [ ] 9.1 `LoginViewModel` initialised with `UserDefaults` key `com.prizm.login.lastServerType = "cloudEU"` → `serverType == .cloudEU`
- [ ] 9.2 Selecting a cloud type persists to `UserDefaults`; selecting self-hosted restores last entered URL
- [ ] 9.3 `isSignInDisabled` returns `false` for cloud when email and password non-empty, `serverURL` empty
- [ ] 9.4 `isSignInDisabled` returns `true` for self-hosted when `serverURL` empty, email and password filled
- [ ] 9.5 `isSignInDisabled` returns `true` when `flowState == .otpPrompt` and OTP field empty
- [ ] 9.6 `isSignInDisabled` returns `false` when `flowState == .otpPrompt` and OTP field non-empty
- [ ] 9.7 `flowState` transitions to `.otpPrompt` when `execute` returns `LoginResult.requiresNewDeviceOTP`
- [ ] 9.8 `flowState` transitions to `.login` when Cancel tapped (after `cancelNewDeviceOTP`)
- [ ] 9.9 `flowState` remains `.otpPrompt` after invalid OTP error; error message set
- [ ] 9.10 `resendNewDeviceOTP` called when Resend tapped; OTP field cleared on success; confirmation announced
- [ ] 9.11 `resendNewDeviceOTP` throws → `flowState` returns to `.otpPrompt`, error message set, OTP field unchanged

## 10. Presentation — LoginViewModel

- [ ] 10.1 Add `serverType: ServerType` `@Published` property; persist/restore via `UserDefaults` key `com.prizm.login.lastServerType`
- [ ] 10.2 Add `isSignInDisabled: Bool` computed property per spec logic (cloud: email+password; self-hosted: email+password+serverURL; otpPrompt: OTP field non-empty)
- [ ] 10.3 Update `signIn()` to construct `ServerEnvironment` from `serverType` (`.cloudUS()` / `.cloudEU()` / `selfHosted` from URL string) and call `loginUseCase.execute(environment:email:masterPassword:)`
- [ ] 10.4 Handle `LoginResult.requiresNewDeviceOTP` in `signIn()`: set `flowState = .otpPrompt`
- [ ] 10.5 Add `otpCode: String` `@Published` property for the OTP text field
- [ ] 10.6 Add `submitOTP()` method: calls `loginUseCase.completeNewDeviceOTP(otp: otpCode)`; on success → sync flow; on `invalid_grant` error → stay `.otpPrompt` with error message
- [ ] 10.7 Add `resendOTP()` method: calls `loginUseCase.resendNewDeviceOTP()`; on success → clear `otpCode`, announce "A new code has been sent to your email"; on error → set error message, leave `otpCode` unchanged
- [ ] 10.8 Add `cancelOTP()` method: calls `loginUseCase.cancelNewDeviceOTP()`, sets `flowState = .login`
- [ ] 10.9 Post `AccessibilityNotification.Announcement` for all new error messages as they appear

## 11. Presentation — Views

- [ ] 11.1 Update `LoginView`: replace static subtitle with three-way `Picker` (`serverTypePicker`) bound to `viewModel.serverType`; hide server URL field for cloud options
- [ ] 11.2 Set `accessibilityIdentifier = AccessibilityID.Login.serverTypePicker`, `accessibilityLabel = "Server"`, `accessibilityValue` to current selection label on the picker
- [ ] 11.3 Add `LoginFlowState.otpPrompt` case to `LoginFlowState` enum in `LoginViewModel.swift`
- [ ] 11.4 Add `Screen.otpPrompt` case to `RootViewModel.Screen` in `PrizmApp.swift`
- [ ] 11.5 Update `RootViewModel.handleLoginFlow` to map `.otpPrompt → .otpPrompt`
- [ ] 11.6 Create `NewDeviceOTPView` (pattern: `TOTPPromptView`): OTP text field, Sign In button, Resend button, Cancel button
- [ ] 11.7 Set `accessibilityIdentifier` on `NewDeviceOTPView` controls: `AccessibilityID.Login.newDeviceOtpField`, `AccessibilityID.Login.resendOtpButton`, `AccessibilityID.Login.cancelOtpButton`
- [ ] 11.8 Update `PrizmApp` root switch to show `NewDeviceOTPView(viewModel: rootVM.loginVM)` for `.otpPrompt`
- [ ] 11.9 Wire Sign In button `disabled` modifier to `viewModel.isSignInDisabled` in both `LoginView` and `NewDeviceOTPView`

## 12. Integration Test

- [ ] 12.1 Verify full login flow against Vaultwarden stub (existing integration test) passes after `PrizmAPIClient` refactor

## 13. XCUITest

- [ ] 13.1 Three-way picker visible on `LoginView`; all three options selectable
- [ ] 13.2 Selecting cloud hides server URL field; selecting self-hosted shows it
- [ ] 13.3 Sign In button enabled for cloud with email + password, empty `serverURL`
- [ ] 13.4 Sign In button disabled for self-hosted when `serverURL` empty
- [ ] 13.5 Successful cloud login against local stub (no OTP path)
- [ ] 13.6 `device_error` response → `NewDeviceOTPView` appears with label "Check your email for a verification code"
- [ ] 13.7 Valid OTP submitted → login succeeds; OTP field disappears
- [ ] 13.8 Invalid OTP → error message shown; OTP field remains

## 14. Observability

- [ ] 14.1 Log server environment selection and restoration at `.info` (include `serverType` value; no secrets)
- [ ] 14.2 Log each `identityToken` request at `.info` with `identityURL` (not password or hash)
- [ ] 14.3 Log `requiresNewDeviceOTP` returned and OTP retry at `.info`
- [ ] 14.4 Log `invalid_grant` on OTP retry at `.error`
- [ ] 14.5 Log `clientIdentifierNotConfigured` at `.error` before surfacing to Presentation
- [ ] 14.6 Log URL validation failures at `.error`

## 15. Documentation

- [ ] 15.1 Add `Config.bitwardenApiVersion = "2026.4.0"` to `App/Config.swift`
- [ ] 15.2 Update `DEVELOPMENT.md`: add `LocalSecrets.xcconfig` section with copy command, xcconfig/Info.plist/Config.swift key names, and note that self-hosted login is unaffected without the file
- [ ] 15.3 Update `SECURITY.md`: document cloud endpoints, OTP memory handling, client identifier injection
- [ ] 15.4 Update `ACCESSIBILITY.md`: document server picker VoiceOver behaviour and `NewDeviceOTPView` OTP field/announcement behaviour
- [ ] 15.5 Update `CLAUDE.md` active changes table: add `hosted-cloud-support` row
