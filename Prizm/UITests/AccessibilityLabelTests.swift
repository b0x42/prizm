import XCTest

/// XCUITest: Accessibility label verification.
///
/// Validates that key icon-only buttons have non-empty accessibility labels
/// and that stateful controls expose correct accessibility values.
///
/// **Prerequisites**: App launched with `--inject-session`, `--inject-vault`, `--skip-sync`.
final class AccessibilityLabelTests: XCTestCase {

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

    // MARK: - 9.1 Icon-only buttons have non-empty accessibilityLabel

    func testSettingsGearHasLabel() {
        let gear = app.buttons["vault.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5), "Settings button must exist")
        XCTAssertFalse(gear.label.isEmpty, "Settings button must have a non-empty label")
    }

    func testNewItemButtonHasLabel() {
        let plus = app.popUpButtons["create.button.newItem"]
            .exists ? app.popUpButtons["create.button.newItem"]
            : app.menuButtons["create.button.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "New Item button must exist")
        XCTAssertFalse(plus.label.isEmpty, "New Item button must have a non-empty label")
    }

    func testFavoriteStarHasLabel() throws {
        // Select the first item to make the detail toolbar appear.
        let firstRow = app.outlines.buttons.element(boundBy: 0)
        guard firstRow.waitForExistence(timeout: 5) else {
            throw XCTSkip("No vault items available to select")
        }
        firstRow.click()

        // The favorite star is a toolbar button without a fixed identifier —
        // look for a button whose label contains "Favorite" or "Unfavorite".
        let star = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'favorite'")).firstMatch
        XCTAssertTrue(star.waitForExistence(timeout: 5), "Favorite star must exist")
        XCTAssertFalse(star.label.isEmpty, "Favorite star must have a non-empty label")
    }

    // MARK: - 9.2 Favorite star accessibilityValue changes on toggle

    func testFavoriteStarValueChangesOnToggle() throws {
        // Select the first item.
        let firstRow = app.outlines.buttons.element(boundBy: 0)
        guard firstRow.waitForExistence(timeout: 5) else {
            throw XCTSkip("No vault items available to select")
        }
        firstRow.click()

        let star = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'favorite'")).firstMatch
        guard star.waitForExistence(timeout: 5) else {
            throw XCTSkip("Favorite star not found")
        }

        let valueBefore = star.value as? String ?? ""
        star.click()

        // Wait briefly for the UI to update.
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", valueBefore),
            object: star
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "Favorite star value must change after toggle")

        let valueAfter = star.value as? String ?? ""
        XCTAssertNotEqual(valueBefore, valueAfter, "Value must differ after toggle")
        XCTAssertTrue(
            ["Favorited", "Not favorited"].contains(valueAfter),
            "Value must be 'Favorited' or 'Not favorited', got '\(valueAfter)'"
        )
    }
}
