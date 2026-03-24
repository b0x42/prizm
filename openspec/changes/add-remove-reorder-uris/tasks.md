## 1. Domain Layer

- [ ] 1.1 Add memberwise initializer `init(uri: String = "", matchType: URIMatchType? = nil)` to `DraftLoginURI` in `DraftVaultItem.swift`
- [ ] 1.2 Remove the "adding/removing URIs is out of scope" comment from `DraftLoginContent`

## 2. Domain Tests

- [ ] 2.1 Add unit test for `DraftLoginURI()` empty initializer — verify defaults to empty string and nil match type
- [ ] 2.2 Add unit test for appending a blank `DraftLoginURI` to `DraftLoginContent.uris`
- [ ] 2.3 Add unit test for removing a URI from `DraftLoginContent.uris`
- [ ] 2.4 Add unit test for swapping adjacent URIs in `DraftLoginContent.uris` (reorder)

## 3. Edit Form UI

- [ ] 3.1 Always show the Websites `DetailSectionCard` in `LoginEditForm` (remove `if !draft.uris.isEmpty` guard)
- [ ] 3.2 Add "Add Website" button at the bottom of the Websites section that appends a blank `DraftLoginURI()`
- [ ] 3.3 Add inline remove (−) button to each `URIEditRow`
- [ ] 3.4 Add ▲▼ reorder buttons to each `URIEditRow` — disabled at boundaries, hidden when only one URI exists
