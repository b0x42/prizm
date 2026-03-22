## Why

The current detail pane renders all fields as a single flat list of `FieldRowView` + `Divider` rows, making it hard to visually parse an item at a glance — especially for Identity items with 17+ fields and Login items that mix credentials, URIs, and notes. Grouping related fields into labelled card sections reduces cognitive load and brings the UI closer to Bitwarden Web's detail layout.

## What Changes

- Introduce a `CardBackground` `ViewModifier` (+ `.cardBackground()` extension) and a `DetailSectionCard` wrapper view that combines an optional section header with field rows inside a card.
- Refactor `LoginDetailView` to use cards: **Credentials** (username, password), **Websites** (URIs), **Notes**, **Custom Fields**.
- Refactor `CardDetailView` to use cards: **Card Details** (cardholder name, brand, number, expiry, code), **Notes**, **Custom Fields**.
- Refactor `IdentityDetailView` to use cards: **Personal Info** (title, first name, middle name, last name, company), **ID Numbers** (SSN, passport, license), **Contact** (email, phone, username), **Address** (address lines, city, state, postal, country), **Notes**, **Custom Fields**.
- Refactor `SecureNoteDetailView` to use cards: **Note**, **Custom Fields**.
- Refactor `SSHKeyDetailView` to use cards: **Key** (public key, fingerprint, private key), **Notes**, **Custom Fields**.

## Capabilities

### New Capabilities

- `detail-card-view`: Grouped card-based layout for vault item detail views — `CardBackground` modifier, `DetailSectionCard` wrapper, and refactored type-specific detail views.

### Modified Capabilities

<!-- No existing spec-level requirements are changing — this is a pure presentation refactor. -->

## Impact

- **Presentation layer only** — no Domain or Data layer changes.
- Files changed: `LoginDetailView`, `CardDetailView`, `IdentityDetailView`, `SecureNoteDetailView`, `SSHKeyDetailView`; new `CardBackground.swift` component (modifier + `DetailSectionCard`).
- Existing `FieldRowView` and `MaskedFieldView` components are reused unchanged.
- UI journey tests (`VaultBrowserJourneyTests`) may need accessibility-identifier updates if card headers are added to the hierarchy.
- No new dependencies, no crypto changes, no API changes.
