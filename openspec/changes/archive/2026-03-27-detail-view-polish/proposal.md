## Why

The detail pane card style uses drop shadows and a stacked (label-on-top, value-below) field layout. macOS native apps — System Settings, Apple's Passwords app — use shadowless cards differentiated by background contrast and a horizontal label-left/value-right field layout. Aligning with the native pattern makes Prizm feel more at home on macOS.

## What Changes

- Remove the drop shadow from `CardBackground` — cards are differentiated by background fill against the pane background only
- Switch `FieldRowView` to a horizontal layout (label left, value right) for single-line fields; keep stacked layout for multi-line content (notes, long text)
- Reduce card corner radius from 12pt to 10pt to match System Settings

## Capabilities

### New Capabilities

*(none)*

### Modified Capabilities

- `detail-card-view`: CardBackground drops shadow, corner radius reduced; FieldRowView switches to horizontal label/value layout for single-line fields

## Impact

- `CardBackground.swift` — remove shadow, adjust corner radius
- `FieldRowView.swift` — horizontal layout for single-line, stacked for multi-line
- `DesignSystem.swift` — no changes expected (spacing/typography tokens stay the same)
- Presentation layer only; no Domain or Data changes
