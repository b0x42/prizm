# mTLS prototype validation

The fixture generates fresh RSA test keys, a root and intermediate CA, TLS server certificates, and PKCS#12 variants in an XCTest-owned temporary directory. Nothing is imported into system trust. Fixture processes and temporary identities are removed by test teardown.

Requires macOS 26+, Xcode, Python 3, and Homebrew OpenSSL 3. `PRIZM_TEST_OPENSSL` can select its executable; the fixture locates `lib/libcrypto.dylib` relative to it. No runtime dependency is added to Prizm.

Unsigned tests:

```sh
xcodebuild test -project Prizm/Prizm.xcodeproj -scheme Prizm \
  -destination 'platform=macOS' -derivedDataPath /tmp/prizm-mtls-build \
  CODE_SIGNING_ALLOWED=NO
```

`MTLSIntegrationTests` exercises a genuine mandatory-client-certificate handshake, required intermediate chain, wrong CA, other host/port, normal server-trust rejection, redirect isolation, and API prelogin/token/refresh/sync paths. `TestAnchorDelegate` sets an anchor only on the test's individual SecTrust object and evaluates it normally. This wrapper is confined to test sources; production never overrides server trust. The HTTP fixture implements wire contracts and is not a real Vaultwarden account.

`MTLSLifecycleTests` verifies cancellation/stale response rejection and missing-identity fail-closed behavior. Presentation tests cover inspect/confirm/remove and server changes. The full suite also covers the existing login and vault behavior.

## Signed test execution

Signed Sandbox hosts cannot spawn the Python/xcrun fixture or listen as a server. Start `fixture.py` externally in a fresh temporary directory, wait until its `ready.json` exists, then provide that path using `TEST_RUNNER_PRIZM_MTLS_FIXTURE_DIR`. XCTest can read the fixture through its testing entitlements; production entitlements are not broadened.

Set your actual Team ID in git-ignored `Prizm/LocalConfig.xcconfig`; both app and test targets use it. The ID in the certificate's display name is not necessarily the team: the valid certificate's OU field is authoritative.

```sh
TEST_RUNNER_PRIZM_MTLS_SIGNED_KEYCHAIN_TESTS=1 \
TEST_RUNNER_PRIZM_MTLS_FIXTURE_DIR=/path/to/temporary/fixture \
xcodebuild test -project Prizm/Prizm.xcodeproj -scheme Prizm \
  -destination 'platform=macOS' -derivedDataPath /tmp/prizm-mtls-signed \
  -allowProvisioningUpdates
```

`testSignedKeychainRestartAndRemoval` verifies persistence, duplicate rollback, actual TLS using the stored private key, and removal. It is deliberately skipped in unsigned runs.

For a real process-restart test, invoke `testSignedKeychainSurvivesProcessRestart` alone twice, with the same external fixture and an additional `TEST_RUNNER_PRIZM_MTLS_RESTART_PHASE=import` on the first invocation, then `=restore` on the second. Import leaves one managed test identity and public UUID metadata for the next host; restore verifies TLS and removes both. Complete both phases before stopping the fixture. Afterwards terminate the external fixture and delete its temporary directory.

Verified on 2026-10-13: full signed suite 488 passed, one two-phase test skipped there, then both restart phases passed in separate app-host processes. No CA was installed into system trust.

## Joint acceptance still required

Then use a disposable Vaultwarden test account behind an mTLS reverse proxy whose server certificate macOS already trusts:

1. Enter server URL before login; choose .p12/.pfx, enter test import password, inspect metadata/fingerprint, confirm assignment.
2. Sign in (including TOTP if configured), load vault, verify refresh and sync.
3. Quit/relaunch the signed app; unlock and sync again.
4. Replace/remove the test assignment and verify old requests/connections end; missing Keychain identity must produce a visible error.
5. Verify an ordinary server without an assignment still works.

The prototype intentionally requires app-isolated data-protection Keychain access for identity persistence. An unsigned build can inspect a certificate but fails confirmation with an explanation of the required signing. It never falls back to the legacy login Keychain for client identities. Attachments are disabled for mTLS servers; public icons use a credential-free session. Separate endpoint origins and private icon-host authentication are deferred to package 4.
