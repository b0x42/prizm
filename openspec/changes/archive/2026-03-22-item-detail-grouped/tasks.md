## 1. CardBackground Component — Tests First (§IV TDD)

- [x] 1.1 Add `CardBackground` color asset to `Assets.xcassets`: white (`#FFFFFF`) light, dark gray (`#212121`) dark
- [x] 1.2 Write failing unit tests for `CardBackground` modifier (light/dark background, corner radius, shadow applied)
- [x] 1.3 Write failing unit tests for `DetailSectionCard` (header visible when title non-empty, header absent when title empty)

## 2. CardBackground Component — Implementation

- [x] 2.1 Create `Prizm/Presentation/Components/CardBackground.swift` with `CardBackground` `ViewModifier` (`.background(Color("CardBackground"))`, `.cornerRadius(20)`, `.shadow(color: .black.opacity(0.2), radius: 4)`) and `.cardBackground()` `View` extension
- [x] 2.2 Create `DetailSectionCard` view in the same file: optional title header + `@ViewBuilder` content wrapped in `.cardBackground()`
- [x] 2.3 Add `CardBackground.swift` to the Xcode project target build phase
- [x] 2.4 Add accessibility identifier `Detail.cardHeader.<sectionName>` to card header labels in `DetailSectionCard`
- [ ] 2.5 Confirm all tests from group 1 pass (Green)

## 3. Refactor LoginDetailView

- [x] 3.1 Wrap username + password rows in a `DetailSectionCard("Credentials")`, hidden when both are nil
- [x] 3.2 Wrap URI rows in a `DetailSectionCard("Websites")`, hidden when no URIs
- [x] 3.3 Wrap notes field in a `DetailSectionCard("Notes")`, hidden when notes nil/empty
- [x] 3.4 Wrap `CustomFieldsSection` in a `DetailSectionCard("Custom Fields")`, hidden when no custom fields

## 4. Refactor CardDetailView

- [x] 4.1 Wrap cardholder name, brand, number, expiry, and security code in a `DetailSectionCard("Card Details")`
- [x] 4.2 Wrap notes in a `DetailSectionCard("Notes")`, hidden when nil/empty
- [x] 4.3 Wrap `CustomFieldsSection` in a `DetailSectionCard("Custom Fields")`, hidden when empty

## 5. Refactor IdentityDetailView

- [x] 5.1 Wrap title, first/middle/last name, company in a `DetailSectionCard("Personal Info")`
- [x] 5.2 Wrap SSN, passport number, license number in a `DetailSectionCard("ID Numbers")`, hidden when all nil
- [x] 5.3 Wrap email, phone, username in a `DetailSectionCard("Contact")`, hidden when all nil
- [x] 5.4 Wrap address lines, city, state, postal code, country in a `DetailSectionCard("Address")`, hidden when all nil
- [x] 5.5 Wrap notes in a `DetailSectionCard("Notes")`, hidden when nil/empty
- [x] 5.6 Wrap `CustomFieldsSection` in a `DetailSectionCard("Custom Fields")`, hidden when empty

## 6. Refactor SecureNoteDetailView and SSHKeyDetailView

- [x] 6.1 Wrap the note body in `SecureNoteDetailView` in a `DetailSectionCard("Note")`
- [x] 6.2 Wrap `CustomFieldsSection` in `SecureNoteDetailView` in a `DetailSectionCard("Custom Fields")`, hidden when empty
- [x] 6.3 Wrap public key, fingerprint, and private key in `SSHKeyDetailView` in a `DetailSectionCard("Key")`
- [x] 6.4 Wrap notes in `SSHKeyDetailView` in a `DetailSectionCard("Notes")`, hidden when nil/empty
- [x] 6.5 Wrap `CustomFieldsSection` in `SSHKeyDetailView` in a `DetailSectionCard("Custom Fields")`, hidden when empty

## 7. Verify, Constitution Check, and Changelog

- [ ] 7.1 Verify existing `VaultBrowserJourneyTests` UI tests still pass (no accessibility-ID regressions)
- [ ] 7.2 Manually verify copy-on-hover and mask-toggle still work inside cards for all item types
- [x] 7.3 Constitution Check: confirm Presentation-only imports, no Domain/Data layer changes, no swallowed errors, TDD followed (§II, §IV, §V)
- [x] 7.4 Add changelog entry for grouped detail card view
