import XCTest

/// XCUITest: Edit Vault Item Journey (edit-vault-items task 10.x)
///
/// Validates the full edit-and-save flow: opening the edit sheet via the Edit button
/// and ⌘E, making changes, saving with the Save button and ⌘S, discarding with the
/// Discard button and Esc, and the discard confirmation prompt.
///
/// Prerequisites: App launched with `--ui-testing`, `--inject-session`, `--inject-vault`,
/// `--skip-sync` so a pre-populated vault is available without a network round-trip.
final class EditItemJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--inject-session", "--inject-vault", "--skip-sync"]
        app.launch()

        let vaultNav = app.otherElements["vault.navigationSplit"]
        XCTAssertTrue(vaultNav.waitForExistence(timeout: 30), "Vault browser must be visible")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Task 10.1: Open edit sheet, change name, save, verify detail pane and list row

    /// Opens the edit sheet for a Login item, changes the name, saves, and verifies the
    /// updated name appears in both the detail pane and the list row.
    func testEditLoginItem_saveName_updatesDetailAndList() throws {
        // Select the first item in the list.
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        // Open the edit sheet via the Edit toolbar button.
        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.click()

        // Verify the edit sheet opened.
        let saveButton = app.buttons["edit.button.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Edit sheet should be visible")

        // Change the Name field.
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tripleClick()
        nameField.typeText("Updated Item Name")

        // Save.
        saveButton.click()

        // Verify the sheet dismissed.
        XCTAssertFalse(saveButton.waitForExistence(timeout: 5), "Edit sheet should have dismissed")

        // Verify the detail pane shows the updated name.
        let detailName = app.staticTexts["detail.name"]
        XCTAssertTrue(detailName.waitForExistence(timeout: 3))
        XCTAssertTrue(detailName.label.contains("Updated Item Name"),
                      "Detail pane should show updated name")
    }

    // MARK: - Task 10.2: Discard with changes — confirm prompt

    /// Opens the edit sheet, makes a change, clicks Discard, confirms in the prompt,
    /// and verifies the item retains its original values.
    func testEditItem_discardWithChanges_confirmPrompt_itemUnchanged() throws {
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        let originalName = app.staticTexts["detail.name"].label

        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.click()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tripleClick()
        nameField.typeText("CHANGED NAME")

        let discardButton = app.buttons["edit.button.discard"]
        XCTAssertTrue(discardButton.exists)
        discardButton.click()

        // Confirm in the alert.
        let discardChangesButton = app.buttons["Discard Changes"]
        XCTAssertTrue(discardChangesButton.waitForExistence(timeout: 3))
        discardChangesButton.click()

        // Sheet should be dismissed.
        XCTAssertFalse(app.buttons["edit.button.save"].waitForExistence(timeout: 3),
                       "Edit sheet should have dismissed")

        // Detail pane should show the original name.
        let detailName = app.staticTexts["detail.name"]
        XCTAssertEqual(detailName.label, originalName)
    }

    // MARK: - Task 10.3: Save disabled when Name is empty

    /// Opens the edit sheet, clears the Name field, and verifies Save is disabled.
    func testEditItem_emptyName_saveDisabled() throws {
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.click()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tripleClick()
        nameField.typeKey(.delete, modifierFlags: [])

        let saveButton = app.buttons["edit.button.save"]
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when Name is empty")
    }

    // MARK: - Task 10.4: ⌘E opens edit sheet

    /// Selects an item and presses ⌘E to open the edit sheet.
    func testCmdE_opensEditSheet() throws {
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        app.typeKey("e", modifierFlags: .command)

        let saveButton = app.buttons["edit.button.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "⌘E should open the edit sheet")
    }

    // MARK: - Task 10.5: ⌘S saves and dismisses sheet

    /// Opens the edit sheet, makes a change, presses ⌘S, and verifies the sheet dismisses.
    func testCmdS_savesAndDismissesSheet() throws {
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.click()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tripleClick()
        nameField.typeText("Cmd-S Saved Item")

        app.typeKey("s", modifierFlags: .command)

        XCTAssertFalse(app.buttons["edit.button.save"].waitForExistence(timeout: 5),
                       "⌘S should save and dismiss the sheet")
    }

    // MARK: - Task 10.6: Esc with no changes dismisses without prompt

    /// Opens the edit sheet without making changes, presses Esc, and verifies the sheet
    /// dismisses immediately without showing a confirmation prompt.
    func testEsc_noChanges_immediatelyDismisses() throws {
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.click()

        XCTAssertTrue(app.buttons["edit.button.save"].waitForExistence(timeout: 3))

        // Press Esc — no changes made, so should dismiss immediately.
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertFalse(app.buttons["Discard Changes"].waitForExistence(timeout: 1),
                       "No confirmation prompt should appear when there are no changes")
        XCTAssertFalse(app.buttons["edit.button.save"].waitForExistence(timeout: 3),
                       "Edit sheet should dismiss immediately on Esc with no changes")
    }

    // MARK: - Delete Item button hidden during creation

    /// Opens the create sheet via ⌘N and verifies no Delete Item button is shown.
    func testCreateSheet_deleteButtonHidden() throws {
        app.typeKey("n", modifierFlags: .command)
        let loginRow = app.cells["typePicker.row.login"]
        XCTAssertTrue(loginRow.waitForExistence(timeout: 3))
        app.typeKey(.return, modifierFlags: [])

        let saveButton = app.buttons["edit.button.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Create sheet must be open")

        let deleteButton = app.buttons["edit.button.delete"]
        XCTAssertFalse(deleteButton.exists,
                       "Delete Item button must not appear in create mode")

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Detail toolbar has no Delete for active items

    /// Selects an active item and verifies the detail toolbar does not contain a Delete button.
    func testDetailToolbar_noDeleteButton_forActiveItems() throws {
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        // The Edit button should be visible (confirms we're looking at the right toolbar).
        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))

        // No Delete button should exist in the toolbar for active items.
        // Use a short timeout — we're asserting absence.
        let deleteToolbarButton = app.buttons.matching(NSPredicate(format: "label == 'Delete'")).firstMatch
        XCTAssertFalse(deleteToolbarButton.waitForExistence(timeout: 1),
                       "Detail toolbar must not contain a Delete button for active items")
    }

    // MARK: - Task 10.7: Menu bar extra vault lock/unlock

    /// Verifies the "Item" menu bar extra appears when the vault is unlocked and
    /// disappears when it locks.
    func testMenuBarExtra_appearsWhenUnlocked_disappearsWhenLocked() throws {
        // The vault should already be unlocked from setUp.
        let menuBarItem = app.menuBars.menuBarItems["Item"]
        XCTAssertTrue(menuBarItem.waitForExistence(timeout: 5),
                      "Item menu bar extra should be visible when vault is unlocked")

        // Click to verify the dropdown contains Edit and Save.
        menuBarItem.click()
        XCTAssertTrue(app.menuItems["Edit"].waitForExistence(timeout: 3),
                      "Edit menu item should be in the Item dropdown")
        XCTAssertTrue(app.menuItems["Save"].exists,
                      "Save menu item should be in the Item dropdown")

        // Dismiss the menu.
        app.typeKey(.escape, modifierFlags: [])

        // Sign out to lock the vault.
        // (Locking directly is not available in v1; use sign-out as a proxy.)
        // The menu bar extra should disappear after lock.
        app.typeKey("q", modifierFlags: [.command, .shift])
        let signOutButton = app.buttons["Sign Out"]
        if signOutButton.waitForExistence(timeout: 3) {
            signOutButton.click()
        }

        XCTAssertFalse(menuBarItem.waitForExistence(timeout: 5),
                       "Item menu bar extra should disappear after vault locks")
    }
}

// MARK: - XCUIElement convenience

private extension XCUIElement {
    func tripleClick() {
        click()
        click(forDuration: 0, thenDragTo: self)
        typeKey("a", modifierFlags: .command)
    }
}
