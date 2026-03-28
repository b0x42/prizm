## Why

Users have no way to know whether their vault data is current — after unlocking, they cannot tell if the last sync succeeded or how stale their data might be. Showing the last sync timestamp gives users confidence that their vault is up to date and makes sync failures visible before they matter.

## What Changes

- Display the date and time of the last successful vault sync in the UI (sidebar footer or toolbar area)
- Persist the last-sync timestamp to UserDefaults so it survives app restarts
- Update the timestamp each time a sync completes successfully
- Show a human-friendly relative label (e.g. "Synced 2 minutes ago") with a full timestamp on hover/tooltip

## Capabilities

### New Capabilities
- `vault-sync-status`: Surface the last successful sync timestamp in the vault browser UI, persisted across sessions and updated on each successful sync

### Modified Capabilities
<!-- No existing spec-level requirements are changing -->

## Impact

- **Presentation layer**: New UI element in the vault browser (sidebar footer or toolbar); depends on `VaultBrowserViewModel` or equivalent
- **Domain layer**: New use case or service to read/write last-sync timestamp
- **Data layer**: UserDefaults persistence for last-sync timestamp
- **No API or crypto changes required**
