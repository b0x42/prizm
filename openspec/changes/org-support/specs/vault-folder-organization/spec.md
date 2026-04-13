## ADDED Requirements

### Requirement: New button is context-aware for org and collection selections
The sidebar `+` button SHALL change its action based on the active `SidebarSelection`:
- `.organization(id)` — triggers inline collection creation (if `canManageCollections == true` for that org; hidden otherwise)
- `.collection(id)` — opens the item create sheet pre-filled with that collection
- `.folder(id)` or `.allItems` — existing folder and item creation behaviour unchanged

#### Scenario: Plus button in org selection creates collection (admin)
- **GIVEN** the active selection is `.organization("org1")` and the user's role is Admin
- **WHEN** the user clicks `+`
- **THEN** an inline collection name field SHALL appear under the org in the sidebar

#### Scenario: Plus button hidden in org selection (user role)
- **GIVEN** the active selection is `.organization("org1")` and the user's role is User
- **WHEN** the sidebar renders
- **THEN** no `+` button SHALL be visible for that org

#### Scenario: Plus button in collection selection creates item
- **GIVEN** the active selection is `.collection("col1")`
- **WHEN** the user clicks `+`
- **THEN** the item create sheet SHALL open with the org and collection "col1" pre-selected

#### Scenario: Plus button in folder selection is unchanged
- **GIVEN** the active selection is a personal folder
- **WHEN** the user clicks `+`
- **THEN** existing folder/item creation behaviour is preserved (no change)
