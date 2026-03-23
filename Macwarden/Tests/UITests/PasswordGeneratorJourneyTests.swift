import XCTest

/// XCUITest: Password Generator Journey (password-generator tasks 5.1–5.2)
///
/// Validates the generator popover flow: opening from the Login edit sheet,
/// interacting with controls, and applying the generated value.
///
/// Prerequisites: App launched with `--ui-testing`, `--inject-session`, `--inject-vault`,
/// `--skip-sync` so a pre-populated vault is available without a network round-trip.
final class PasswordGeneratorJourneyTests: XCTestCase {

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

    // MARK: - Task 5.1: Generator popover opens, slider changes preview, Use applies value

    func testGeneratorPopover_opensAndAppliesPassword() throws {
        // Select a Login item from the sidebar.
        let sidebarLogins = app.staticTexts["sidebar.type.login"]
        XCTAssertTrue(sidebarLogins.waitForExistence(timeout: 5))
        sidebarLogins.click()

        // Select the first item.
        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        // Open the edit sheet.
        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.click()

        // Tap the generator trigger button.
        let generatorButton = app.buttons["generator.button.trigger"]
        XCTAssertTrue(generatorButton.waitForExistence(timeout: 3), "Generator button should be visible")
        generatorButton.click()

        // Verify the popover opened — preview should exist.
        let preview = app.staticTexts["generator.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3), "Generator popover should be open")
        let initialPreview = preview.label

        // Change the length slider.
        let slider = app.sliders["generator.lengthSlider"]
        XCTAssertTrue(slider.exists, "Length slider should be visible")
        slider.adjust(toNormalizedSliderPosition: 0.8)

        // Verify preview updated.
        let updatedPreview = app.staticTexts["generator.preview"].label
        XCTAssertNotEqual(initialPreview, updatedPreview, "Preview should update after slider change")

        // Tap "Use Password".
        let useButton = app.buttons["generator.button.use"]
        XCTAssertTrue(useButton.exists)
        useButton.click()

        // Verify popover dismissed.
        XCTAssertFalse(preview.waitForExistence(timeout: 2), "Popover should have dismissed")

        // Discard the edit sheet.
        let discardButton = app.buttons["edit.button.discard"]
        if discardButton.exists { discardButton.click() }
    }

    // MARK: - Task 5.2: Switch to Passphrase mode, change word count, verify preview

    func testGeneratorPopover_passphraseMode_wordCountUpdatesPreview() throws {
        // Select a Login item.
        let sidebarLogins = app.staticTexts["sidebar.type.login"]
        XCTAssertTrue(sidebarLogins.waitForExistence(timeout: 5))
        sidebarLogins.click()

        let firstRow = app.tables["itemList.list"].cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.click()

        // Open edit sheet.
        let editButton = app.buttons["edit.button.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.click()

        // Open generator popover.
        let generatorButton = app.buttons["generator.button.trigger"]
        XCTAssertTrue(generatorButton.waitForExistence(timeout: 3))
        generatorButton.click()

        let preview = app.staticTexts["generator.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3))

        // Switch to Passphrase mode.
        let passphraseTab = app.buttons["Passphrase"]
        XCTAssertTrue(passphraseTab.waitForExistence(timeout: 2))
        passphraseTab.click()

        // Verify preview now contains hyphens (passphrase separator).
        let passphrasePreview = app.staticTexts["generator.preview"].label
        XCTAssertTrue(passphrasePreview.contains("-"), "Passphrase should contain separator")

        // Change word count via stepper increment.
        let stepper = app.steppers["generator.wordCount"]
        XCTAssertTrue(stepper.exists, "Word count stepper should be visible")
        stepper.buttons["Increment"].click()

        // Verify preview updated.
        let updatedPreview = app.staticTexts["generator.preview"].label
        XCTAssertNotEqual(passphrasePreview, updatedPreview, "Preview should update after word count change")

        // Discard.
        app.typeKey(.escape, modifierFlags: [])
        let discardButton = app.buttons["edit.button.discard"]
        if discardButton.exists { discardButton.click() }
    }
}
