## Why

The item list rows in the content pane are compact and dense. Row height is minimal (2pt vertical padding), the item name uses `.body` font, and there's little whitespace around the text. This makes the list feel cramped compared to the detail pane's polished card layout. Increasing row height, adding breathing room, and promoting the item name to `.headline` (matching the detail view section headers) will make the list more scannable and visually consistent.

## What Changes

- Increase vertical padding on `ItemRowView` for taller rows
- Add more whitespace around text content
- Item name uses `.headline` font (matching "Credentials", "Websites" etc. in the detail view)

## Capabilities

### New Capabilities

*(none)*

### Modified Capabilities

- `vault-browser-ui`: Item list row height increased, item name promoted to `.headline` style

## Impact

- `ItemRowView.swift` — padding and font changes
- Presentation layer only; no Domain or Data changes
