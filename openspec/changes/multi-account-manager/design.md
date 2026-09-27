# Design

## Profile identity

Each stored account receives a random local `profileId`. Remote identity uniqueness is the
pair of canonical server origin and remote user ID. Keychain records use `profileId`, so
identical remote IDs from different instances cannot collide.

## Session boundary

Only one profile is active and only one vault key may be resident in memory. A switch first
locks crypto, clears decrypted vault data, key caches, temporary attachment files, favicons,
and presentation state. The target profile is then selected but remains locked until password
or profile-scoped biometric authentication succeeds.

## Migration

The legacy `activeUserId` record is copied into a versioned profile registry. Migration is
idempotent: the new index and active profile are written before legacy keys are removed.
Legacy biometric enrollment is reset because moving an access-controlled item without reading
its protected value is not supported by the current Keychain abstraction.

## Complexity

A local UUID is used instead of deriving an ID from a URL. This avoids losing access to stored
secrets if URL canonicalization rules change. Session generation is carried by the network
client so work started for an old profile cannot be accepted as current after a switch.
