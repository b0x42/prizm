# Multi-account manager

Prizm currently retains one active account and keys session data by the remote user ID.
That prevents safe switching between accounts, especially when two self-hosted instances
issue the same user ID.

This change adds local account profiles identified independently from remote identities.
Users can add, switch, lock, and remove profiles from a native macOS Account menu. Exactly
one vault may be unlocked at a time, and switching always clears the previous vault session
before the target profile can be unlocked.
