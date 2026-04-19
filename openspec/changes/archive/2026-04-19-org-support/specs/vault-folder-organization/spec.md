## ADDED Requirements

### Requirement: New button is context-aware for org and collection selections
Each org's disclosure header in the sidebar SHALL display a `+` button when `canManageCollections == true` for that org (always visible on the header, not selection-dependent — matching the Folders section header pattern). Clicking the org header `+` SHALL trigger inline collection creation for that org. When `canManageCollections == false`, the `+` button SHALL be absent from that org's header. In addition, the global `+` button action SHALL be context-aware based on `SidebarSelection`:
- `.collection(id)` — opens the item create sheet pre-filled with that collection
- `.folder(id)` or `.allItems` — existing folder and item creation behaviour unchanged

#### Scenario: Plus button on org header creates collection (admin)
- **GIVEN** the user's role is Admin or Owner in org "org1"
- **WHEN** the sidebar renders
- **THEN** a `+` button SHALL be visible on org "org1"'s disclosure header at all times (not just when selected)

#### Scenario: Plus button absent on org header (user role)
- **GIVEN** the user's role is User in org "org1"
- **WHEN** the sidebar renders
- **THEN** no `+` button SHALL appear on org "org1"'s disclosure header

#### Scenario: Plus button in collection selection creates item
- **GIVEN** the active selection is `.collection("col1")`
- **WHEN** the user clicks `+`
- **THEN** the item create sheet SHALL open with the org and collection "col1" pre-selected

#### Scenario: Plus button in folder selection is unchanged
- **GIVEN** the active selection is a personal folder
- **WHEN** the user clicks `+`
- **THEN** existing folder/item creation behaviour is preserved (no change)
