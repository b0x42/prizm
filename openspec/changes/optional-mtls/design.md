# Package 0: inventory and decisions

## Integration points
- `Data/Network/PrizmAPIClient.swift`: all API/identity/CRUD operations; also Azure upload and blob download. Session is currently shared and fixed. Replace production default with a factory; preserve explicit test-session injection.
- `Data/Network/FaviconLoader.swift`: independent public icon session. Use a credential-free session; no bearer tokens. Own icon hosts are deferred.
- `Data/Repositories/AuthRepositoryImpl.swift`: environment setup, password/biometric unlock restoration, refresh, sign-out. Restore certificate assignment before any request; invalidate on sign-out.
- `App/AppContainer.swift`: wire certificate store/configuration and UI Domain protocol.
- `Presentation/Login/*`: import, preview, confirm, replace/remove before login.
- No other URLSession/network call sites found in Swift sources.

## Keychain strategy
The supported target is macOS 26. SDK `SecImportExport.h` documents `kSecImportToMemoryOnly` since macOS 15: use it for preview, so failed imports cannot populate the login Keychain. Persist the private key and certificate separately, retain both exact persistent references, and roll back only objects newly added by that attempt. Persist explicitly into the data-protection Keychain, with non-synchronizable WhenUnlockedThisDeviceOnly access and app access-group isolation. Never persist PKCS#12 bytes or password. Retain exact persistent references and an app-owned UUID record; never delete by subject/fingerprint. Public chain DER lives in an app-scoped generic-password record alongside ownership references, not in the trust store. No CA trust changes.

Import validates identity count, private key, validity dates, and KU/EKU through Security.framework. Use CryptoKit SHA-256 over leaf DER. Preview holds only the in-memory identity until commit/cancel. Reject duplicate existing objects rather than claim ownership.

## Transport
HTTPS origin = lowercased host plus effective port; reject URL userinfo. A delegate holds a fixed credential and origin. Client certificate challenges elsewhere are cancelled (including on external sessions); server trust keeps system handling. Reject cross-origin redirects before following. Disable shared credential storage and cookies. API actor keeps a generation number and rejects responses after session changes. Factory resolves assignment before network operations and fails closed for corrupt configuration/missing identities. Server/certificate changes cancel old sessions, clear bearer tokens and rebuild. Lock does not remove identity. Sign-out invalidates sessions but preserves prelogin server assignment; explicit Remove deletes the assignment and owned identity.

## Prototype boundaries
Attachments are disabled for an mTLS server until package 4; non-mTLS attachments use a separate credential-free session for signed URLs and never bearer auth. Public icons use a separate session with client identity selection cancelled.

## Validation and risks
Tests: origin boundaries, certificate challenge selection, redirect rejection, configuration persistence/corruption, invalid import, real Keychain restart/removal, lifecycle stale response, login/refresh/sync using local TLS server and ephemeral CA. No production identities. A local Python TLS fixture will require client auth and exercise an independent second port plus invalid server trust.

Signed sandbox builds must verify data-protection Keychain access and re-launch; unsigned standalone scripts cannot prove production entitlements. The user chose unsigned compilation; signed Keychain acceptance is pending. Do not mark those acceptance checks passed until executed. Spec/design reviewed against CONSTITUTION.md before implementation. No foreign source copied.

## Complexity tracking
A Domain certificate-management protocol keeps Security types out of Presentation. Immutable delegate credentials prevent account-switch races. App-owned Keychain records make exact deletion possible. These are required by transport isolation and ownership, rather than reusable general credential infrastructure.

References: https://developer.apple.com/documentation/security/importing-an-identity ; https://developer.apple.com/documentation/security/ksecimporttomemoryonly ; installed Security.framework SDK headers.
