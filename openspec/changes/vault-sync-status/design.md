## Context

The vault browser currently has no visible indicator of when vault data was last refreshed from the server. After unlocking, a re-sync is triggered automatically, but the user has no feedback that it occurred or when. For self-hosted deployments this is particularly important — users need confidence that their Vaultwarden data is current, especially after periods of inactivity or network issues.

The app already performs a sync after login and after unlock (per `vault-browser-ui` spec). This design hooks into the completion path of that existing sync operation to record and display a timestamp.

## Goals / Non-Goals

**Goals:**
- Persist the last successful sync timestamp across app restarts (UserDefaults)
- Display the timestamp in the vault browser UI as a human-friendly relative label
- Update the timestamp each time any successful sync completes
- Refresh the relative label on a 60-second timer while the app is open

**Non-Goals:**
- Triggering sync from this UI element (manual sync is a separate feature)
- Showing sync progress or in-flight status
- Tracking per-item sync granularity
- Distinguishing between login sync and unlock sync for display purposes

## Decisions

### Decision: UserDefaults for persistence (not Keychain)

The last-sync timestamp is not a secret — it is a UI preference. Storing it in UserDefaults is consistent with how the project already handles UI state. Using the Keychain would be unnecessary complexity and wrong threat model.

**Alternative considered**: In-memory only (no persistence). Rejected because the value would disappear on every app relaunch, undermining the user's ability to judge data freshness after waking from sleep or restarting.

### Decision: Store as ISO-8601 string in UserDefaults, keyed per account

`Date` encodes cleanly as an ISO-8601 `String` with `ISO8601DateFormatter`. The UserDefaults key is scoped to the account email (`com.macwarden.lastSyncDate.<email>`) so that switching accounts does not show a stale timestamp from the previous account.

**Alternative considered**: `TimeInterval` (Double) with a shared key. Rejected — ISO-8601 is self-documenting in developer tools, and per-account keying is necessary for correctness.

### Decision: Display pinned to the very bottom of the sidebar

The sync status element is pinned to the bottom of the sidebar column, below all vault list content, and remains visible regardless of scroll position. This makes it persistently accessible as a status indicator without interfering with the item list. Implemented with a `VStack` where the list takes remaining space (`Spacer` or `List` filling available height) and the status view sits below it outside the scroll area.

**Alternative considered**: Toolbar trailing area. Rejected as it competes with future action controls and is not visible when the toolbar is hidden.

### Decision: Show relative label, not full timestamp

A relative label ("Synced 2 minutes ago", "Synced yesterday") is immediately readable at a glance without requiring the user to parse a datetime string. The label tiers: "just now" → "X minutes ago" → "X hours ago" → "yesterday" → "Month Day" for older syncs. A periodic timer (60-second interval) keeps the label current while the app is open.

**Alternative considered**: Full datetime ("Last synced: Mar 28, 2026 at 14:32"). Not chosen — harder to parse at a glance for a secondary status indicator; relative time communicates freshness more intuitively.

### Decision: Domain `SyncTimestampRepository` protocol, UserDefaults impl in Data layer

Consistent with the project's architecture rules: domain protocol, data implementation. The use case reads/writes through the protocol, keeping the domain layer free of UserDefaults imports.

## Risks / Trade-offs

- **Clock skew**: If the user's system clock is adjusted backward, the relative label could show a future timestamp. Mitigation: clamp displayed values to "just now" if the timestamp appears to be in the future.
- **Sync error path not updated**: If a sync fails silently (network error swallowed), the old timestamp stays, which is actually the correct behavior — it reflects the last *successful* sync. Requires that the success path calls the update; error paths must not.
- **UI coupling to sync completion**: The ViewModel observes sync completion via `AsyncStream<Date>` exposed on the sync use case, consumed with `for await` in a `Task` on the ViewModel. This is the chosen mechanism — not polling UserDefaults (§II layer violation) and not Combine publishers (prohibited for new code per CLAUDE.md).
