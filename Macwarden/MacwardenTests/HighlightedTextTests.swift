import XCTest
@testable import Macwarden

@MainActor
final class HighlightedTextTests: XCTestCase {

    // MARK: - Match applies bold

    func testHighlightedText_matchAppliesBold() {
        let result = ItemRowView.highlightedText("Hello World", query: "World")
        let runs = Array(result.runs)
        XCTAssertEqual(runs.count, 2)
        XCTAssertNil(runs[0].attributes.inlinePresentationIntent)
        XCTAssertEqual(runs[1].attributes.inlinePresentationIntent, .stronglyEmphasized)
    }

    // MARK: - No match returns plain

    func testHighlightedText_noMatch_returnsPlain() {
        let result = ItemRowView.highlightedText("Hello World", query: "xyz")
        let runs = Array(result.runs)
        XCTAssertEqual(runs.count, 1)
        XCTAssertNil(runs[0].attributes.inlinePresentationIntent)
    }

    // MARK: - Case-insensitive matching

    func testHighlightedText_caseInsensitive() {
        let result = ItemRowView.highlightedText("Alice's Bank", query: "alice")
        let runs = Array(result.runs)
        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].attributes.inlinePresentationIntent, .stronglyEmphasized)
        XCTAssertEqual(String(result.characters[runs[0].range]), "Alice")
    }

    // MARK: - Empty query returns plain

    func testHighlightedText_emptyQuery_returnsPlain() {
        let result = ItemRowView.highlightedText("Hello World", query: "")
        let runs = Array(result.runs)
        XCTAssertEqual(runs.count, 1)
        XCTAssertNil(runs[0].attributes.inlinePresentationIntent)
    }
}
