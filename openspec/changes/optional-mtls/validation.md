# Validation and pre-PR review — 2026-10-13

## Scope

Packages 0–3 implement PKCS#12 inspection/confirmation, app-isolated Keychain persistence, one exact HTTPS origin per server assignment, immutable TLS credentials, login/token-refresh/sync integration and restart restoration. Vault crypto and API wire behavior are unchanged. This remains a prototype: mTLS attachments are explicitly disabled; private icon hosts, separate endpoint origins, expiry warnings and renewal are deferred.

The user confirmed that the interface and application connection work. A complete account-level refresh/restart acceptance sequence is still a manual check; the automated API fixture tests contracts rather than a real Vaultwarden account.

## Executed checks

- macOS 26.6.2: unsigned and Apple Development signed Debug builds passed.
- Final unsigned suite: 491 tests, 489 passed, 2 explicitly skipped, 0 failures.
- Final signed sandbox suite: 491 tests, 490 passed, 1 explicitly skipped, 0 failures.
- The two-phase restart test was separately verified with import and restore in distinct signed host processes; the restored private key completed a real TLS handshake, then the identity and public test metadata were removed.
- Signed tests verify exact-reference removal and both duplicate failure paths: an existing key UUID and a fresh UUID colliding with the existing certificate. The latter verifies the newly inserted private key is rolled back and the original remains usable for TLS.
- Real TLS: mandatory client authentication, intermediate chain, missing identity, wrong host/port, an actually offered but server-rejected client identity, default server-trust rejection and cross-origin redirect refusal.
- Import: wrong password, malformed PKCS#12, missing private key, multiple identities, expired/future certificates, restricted and absent KU/EKU, issuer/dates/SHA-256.
- Configuration/lifecycle: persistence, corrupt-config failure, reference counting, missing identity without fallback, sign-out and stale response rejection. URL typing regression tested red then green.
- IPv6, IDNA and effective-port boundaries passed. Presentation tests cover preview/confirmation/cancel/removal and incomplete URL entry.
- `git diff --check` passed. Personal signing settings remain git-ignored; no production mTLS identity or private-key fixture is committed, and no CA was installed into system trust.

## Review cleanup

- Removed redundant specification copies, unused imports and a weak nil-credential unit test already covered with a real credential in TLS integration tests.
- Removed the import force unwrap and merged duplicate reference-count queries.
- Extracted the import sheet from LoginView; preview displays the actual allowed origin. Kept the user-verified multiline error and scrollable layout fix.
- Organized new source references in their proper Xcode groups.
- Removed a hardcoded foreign signing team, restored the bundle ID already declared in ExportOptions, and let both app/test targets use LocalConfig.xcconfig. These fixes are necessary for signed sandbox validation.
- Kept two existing test-only MainActor annotations required for compilation; they do not change production behavior.
- Made the OpenSSL 3 fixture dependency explicit in CI, skipped unused signed-fixture setup in unsigned runs, and removed HTTPServer's unnecessary reverse DNS lookup. A resolver-related startup timeout was reproduced and the unsigned suite passed after removing that lookup.
- Corrected a false-positive rejected-client test: its old request was denied by origin isolation before a credential could be offered. The new test grants exactly the rejecting server's own origin and asserts credential use before rejection.

## Remaining acceptance items

- Manual account-level token refresh and app restart against a disposable Vaultwarden/Bitwarden account.
- VoiceOver/keyboard verification of the new import sheet; the user confirmed the visible layout.
- Locked-Keychain cleanup fault injection and sustained concurrent account-switch testing remain product-hardening work beyond this prototype. Signed suite diagnostics include warnings about synchronous APIs on the main thread; inspect import responsiveness during manual acceptance.

Test-first sequencing: tests were authored before implementation, but the initial import/core red run was delayed by signing clarification and compiler-cache restrictions. Later import, TLS and URL-entry regression red failures were observed and corrected. Do not claim fully verified red sequencing for that initially blocked phase.

The change is prepared on `codex/mtls-client-certificates` as a draft upstream PR. No release or merge is performed.
