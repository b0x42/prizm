## Context

The vault browser currently has no visible indicator of when vault data was last refreshed from the server. After unlocking, a re-sync is triggered automatically, but the user has no feedback that it occurred or when. For self-hosted deployments this is particularly important — users need confidence that their Vaultwarden data is current, especially after periods of inactivity or network issues.

The app already performs a sync after login and after unlock (per `vault-browser-ui` spec). This design hooks into the completion path of that existing sync operation to record and display a timestamp.

## Goals / Non-Goals

**Goals:**
- Persist the last successful sync timestamp across app restarts (UserDefaults)
- Display the timestamp in the vault browser UI as a human-friendly relative label
- Update the timestamp each time any successful sync completes
- Surface the full ISO-8601 datetime on hover (tooltip)

**Non-Goals:**
- Triggering sync from this UI element (manual sync is a separate feature)
- Showing sync progress or in-flight status
- Tracking per-item sync granularity
- Distinguishing between login sync and unlock sync for display purposes

## Decisions

### Decision: UserDefaults for persistence (not Keychain)

The last-sync timestamp is not a secret — it is a UI preference. Storing it in UserDefaults is consistent with how the project already handles UI state. Using the Keychain would be unnecessary complexity and wrong threat model.

**Alternative considered**: In-memory only (no persistence). Rejected because the value would disappear on every app relaunch, undermining the user's ability to judge data freshness after waking from sleep or restarting.

### Decision: Store as ISO-8601 string in UserDefaults

`Date` encodes cleanly as an ISO-8601 `String` with `ISO8601DateFormatter`. This is human-readable in developer tools and avoids `Double`-based epoch representations that lose clarity during debugging.

**Alternative considered**: `TimeInterval` (Double). Rejected because ISO-8601 is self-documenting.

### Decision: Display in sidebar footer, not toolbar

The sidebar footer is the natural home for persistent contextual metadata about the vault session. The toolbar is action-focused. Placing the timestamp in the footer matches the visual hierarchy of the three-pane layout and avoids crowding the toolbar.

**Alternative considered**: Toolbar trailing area. Rejected as it competes with future action controls.

### Decision: Relative time label with full timestamp tooltip

"Synced 3 minutes ago" is immediately useful without requiring the user to parse a date. The full timestamp in a tooltip provides precision when needed (e.g. debugging after a network outage). SwiftUI's `Text` with `.help(_:)` modifier covers this with no custom components.

**Alternative considered**: Always show full datetime. Rejected as visually heavy for a secondary status indicator.

### Decision: Domain `SyncTimestampRepository` protocol, UserDefaults impl in Data layer

Consistent with the project's architecture rules: domain protocol, data implementation. The use case reads/writes through the protocol, keeping the domain layer free of UserDefaults imports.

## Risks / Trade-offs

- **Clock skew**: If the user's system clock is adjusted backward, the relative label could show a future timestamp. Mitigation: clamp displayed values to "just now" if the timestamp appears to be in the future.
- **Sync error path not updated**: If a sync fails silently (network error swallowed), the old timestamp stays, which is actually the correct behavior — it reflects the last *successful* sync. Requires that the success path calls the update; error paths must not.
- **UI coupling to sync completion**: The ViewModel needs to observe sync completion. This can be done via a callback/notification from the existing sync use case, or by polling UserDefaults. A proper async notification is preferred to avoid stale display.
