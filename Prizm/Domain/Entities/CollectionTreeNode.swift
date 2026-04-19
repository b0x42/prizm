import Foundation

/// A node in the collection tree for one organization, built by parsing `/`-delimited names.
///
/// Mirrors `FolderTreeNode` — Bitwarden uses the same `/` convention for collection hierarchy
/// (e.g. "Engineering/Backend" nests "Backend" under "Engineering").
nonisolated struct CollectionTreeNode: Identifiable {
    let id: String
    let name: String
    /// Nil for virtual parent nodes that have no corresponding collection.
    let collection: OrgCollection?
    var children: [CollectionTreeNode]

    var isVirtual: Bool { collection == nil }
    var hasChildren: Bool { !children.isEmpty }

    static func buildTree(from collections: [OrgCollection]) -> [CollectionTreeNode] {
        var root: [CollectionTreeNode] = []
        let sorted = collections.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for col in sorted {
            let parts = col.name.split(separator: "/").map(String.init).filter { !$0.isEmpty }
            guard !parts.isEmpty else { continue }
            insertNode(into: &root, parts: parts, collection: col)
        }
        return root
    }

    private static func insertNode(into nodes: inout [CollectionTreeNode], parts: [String], collection: OrgCollection) {
        guard let first = parts.first else { return }
        let remaining = Array(parts.dropFirst())
        if let idx = nodes.firstIndex(where: { $0.name.caseInsensitiveCompare(first) == .orderedSame }) {
            if remaining.isEmpty {
                if nodes[idx].collection == nil {
                    // Promote virtual placeholder to real collection, preserving any children.
                    nodes[idx] = CollectionTreeNode(id: collection.id, name: first, collection: collection, children: nodes[idx].children)
                } else {
                    // A real collection with this name already exists — append as a separate
                    // sibling so both are reachable. (Bitwarden allows duplicate names.)
                    nodes.append(CollectionTreeNode(id: collection.id, name: first, collection: collection, children: []))
                }
            } else {
                insertNode(into: &nodes[idx].children, parts: remaining, collection: collection)
            }
        } else if remaining.isEmpty {
            nodes.append(CollectionTreeNode(id: collection.id, name: first, collection: collection, children: []))
        } else {
            var virtual = CollectionTreeNode(id: "virtual:\(collection.organizationId):\(first)", name: first, collection: nil, children: [])
            insertNode(into: &virtual.children, parts: remaining, collection: collection)
            nodes.append(virtual)
        }
    }
}
