import XCTest
import SwiftUI
@testable import Prizm

// MARK: - CardBackgroundTests

/// Unit tests for `CardBackground` `ViewModifier` and `DetailSectionCard`.
///
/// SwiftUI views cannot be instantiated directly in XCTest without ViewInspector.
/// These tests therefore target the testable logic extracted from each component:
///
/// - `CardBackground`: the color asset must exist and return non-nil at runtime.
/// - `DetailSectionCard`: `hasHeader(_:)` drives whether the section label is rendered.
///
/// TDD note: these tests are written before the implementation exists and must fail (Red)
/// until `CardBackground.swift` is added to the target (task 2.1–2.3).
@MainActor
final class CardBackgroundTests: XCTestCase {

    // MARK: - CardBackground color asset (task 1.2)

    /// The CardBackground named color must resolve in both light and dark appearances.
    /// This test fails until Assets.xcassets/CardBackground.colorset is present and the
    /// asset catalog is included in the app target.
    func testCardBackgroundColor_exists() {
        // NSColor(named:) returns nil when the asset is absent from the catalog.
        let color = NSColor(named: "CardBackground")
        XCTAssertNotNil(color, "CardBackground color asset must exist in Assets.xcassets")
    }

    // MARK: - DetailSectionCard header logic (task 1.3)

    /// A non-empty title means the card should render a visible section header.
    func testHasHeader_nonEmptyTitle_returnsTrue() {
        XCTAssertTrue(DetailSectionCard<EmptyView>.hasHeader("Credentials"))
    }

    /// An empty string title means no header label should be rendered.
    func testHasHeader_emptyTitle_returnsFalse() {
        XCTAssertFalse(DetailSectionCard<EmptyView>.hasHeader(""))
    }

    /// A whitespace-only title is treated as absent — no header rendered.
    func testHasHeader_whitespaceTitle_returnsFalse() {
        XCTAssertFalse(DetailSectionCard<EmptyView>.hasHeader("   "))
    }

    /// nil title means no header label should be rendered.
    func testHasHeader_nilTitle_returnsFalse() {
        XCTAssertFalse(DetailSectionCard<EmptyView>.hasHeader(nil as String?))
    }
}
