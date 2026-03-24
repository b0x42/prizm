## 1. Domain Layer

- [x] 1.1 Add memberwise initializer `init(uri: String = "", matchType: URIMatchType? = nil)` to `DraftLoginURI` in `DraftVaultItem.swift`
- [x] 1.2 Remove the "adding/removing URIs is out of scope" comment from `DraftLoginContent`

## 2. Domain Tests

- [x] 2.1 Add unit test for `DraftLoginURI()` empty initializer — verify defaults to empty string and nil match type
- [x] 2.2 Add unit test for appending a blank `DraftLoginURI` to `DraftLoginContent.uris`
- [x] 2.3 Add unit test for removing a URI from `DraftLoginContent.uris`
- [x] 2.4 Add unit test for swapping adjacent URIs in `DraftLoginContent.uris` (reorder)

## 3. Edit Form UI

- [x] 3.1 Always show the Websites `DetailSectionCard` in `LoginEditForm` (remove `if !draft.uris.isEmpty` guard)
- [x] 3.2 Add "Add Website" button at the bottom of the Websites section that appends a blank `DraftLoginURI()`
- [x] 3.3 Add inline remove (−) button to each `URIEditRow`
- [x] 3.4 Add ▲▼ reorder buttons to each `URIEditRow` — disabled at boundaries, hidden when only one URI exists
