import XCTest
@testable import Prizm

// MARK: - CollectionTreeNodeTests

/// Unit tests for `CollectionTreeNode.buildTree`.
///
/// Covers:
///   - Flat (no slash) collections produce leaf nodes
///   - Slash-delimited names produce a parent/child hierarchy
///   - Virtual parent nodes are created for intermediate path segments with no matching collection
///   - Nodes at the same level are sorted alphabetically (case-insensitive)
///   - A real collection that also acts as a parent is non-virtual
final class CollectionTreeNodeTests: XCTestCase {

    // MARK: - Helpers

    private func col(_ name: String, id: String? = nil) -> OrgCollection {
        OrgCollection(id: id ?? name, organizationId: "org1", name: name)
    }

    // MARK: - Flat collections

    func test_flat_producesLeafNodes() {
        let tree = CollectionTreeNode.buildTree(from: [col("Alpha"), col("Beta"), col("Gamma")])

        XCTAssertEqual(tree.count, 3)
        XCTAssertFalse(tree[0].hasChildren)
        XCTAssertFalse(tree[0].isVirtual)
    }

    func test_flat_sortedAlphabetically() {
        let tree = CollectionTreeNode.buildTree(from: [col("Zebra"), col("apple"), col("Mango")])

        XCTAssertEqual(tree.map(\.name), ["apple", "Mango", "Zebra"])
    }

    // MARK: - Nested collections

    func test_nested_createsChildUnderParent() {
        let tree = CollectionTreeNode.buildTree(from: [
            col("Engineering/Backend"),
            col("Engineering/Frontend"),
        ])

        XCTAssertEqual(tree.count, 1)
        let eng = tree[0]
        XCTAssertEqual(eng.name, "Engineering")
        XCTAssertTrue(eng.isVirtual)       // no real "Engineering" collection
        XCTAssertEqual(eng.children.count, 2)
        XCTAssertEqual(eng.children.map(\.name), ["Backend", "Frontend"])
    }

    func test_nested_realParentIsNotVirtual() {
        // "Engineering" exists as a real collection AND has children via slash names.
        let tree = CollectionTreeNode.buildTree(from: [
            col("Engineering", id: "eng"),
            col("Engineering/Backend"),
        ])

        XCTAssertEqual(tree.count, 1)
        let eng = tree[0]
        XCTAssertFalse(eng.isVirtual)
        XCTAssertEqual(eng.collection?.id, "eng")
        XCTAssertEqual(eng.children.count, 1)
        XCTAssertEqual(eng.children[0].name, "Backend")
    }

    func test_nested_multiLevel() {
        let tree = CollectionTreeNode.buildTree(from: [
            col("A/B/C"),
        ])

        XCTAssertEqual(tree.count, 1)
        let a = tree[0]
        XCTAssertTrue(a.isVirtual)
        XCTAssertEqual(a.children.count, 1)
        let b = a.children[0]
        XCTAssertTrue(b.isVirtual)
        XCTAssertEqual(b.children.count, 1)
        XCTAssertEqual(b.children[0].name, "C")
        XCTAssertFalse(b.children[0].isVirtual)
    }

    // MARK: - Mixed flat and nested

    func test_mixed_flatAndNestedCoexist() {
        let tree = CollectionTreeNode.buildTree(from: [
            col("HR"),
            col("Engineering/Backend"),
        ])

        XCTAssertEqual(tree.count, 2)
        let names = tree.map(\.name)
        XCTAssertTrue(names.contains("HR"))
        XCTAssertTrue(names.contains("Engineering"))
    }

    // MARK: - Edge cases

    func test_empty_producesEmptyTree() {
        XCTAssertTrue(CollectionTreeNode.buildTree(from: []).isEmpty)
    }

    func test_singleCollection_producesOneLeaf() {
        let tree = CollectionTreeNode.buildTree(from: [col("Solo")])
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree[0].name, "Solo")
        XCTAssertFalse(tree[0].hasChildren)
    }
}
