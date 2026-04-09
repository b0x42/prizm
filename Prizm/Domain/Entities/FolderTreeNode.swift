import Foundation

/// A node in the folder tree, built by parsing `/`-delimited folder names.
struct FolderTreeNode: Identifiable {
    let id: String
    let name: String
    let folder: Folder?
    var children: [FolderTreeNode]

    var isVirtual: Bool { folder == nil }
    var hasChildren: Bool { !children.isEmpty }

    static func buildTree(from folders: [Folder]) -> [FolderTreeNode] {
        var root: [FolderTreeNode] = []
        let sorted = folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for folder in sorted {
            let parts = folder.name.split(separator: "/").map(String.init)
            guard !parts.isEmpty else { continue }
            insertNode(into: &root, parts: parts, folder: folder)
        }
        return root
    }

    private static func insertNode(into nodes: inout [FolderTreeNode], parts: [String], folder: Folder) {
        guard let first = parts.first else { return }
        let remaining = Array(parts.dropFirst())
        if let idx = nodes.firstIndex(where: { $0.name.caseInsensitiveCompare(first) == .orderedSame }) {
            if remaining.isEmpty {
                nodes[idx] = FolderTreeNode(id: folder.id, name: first, folder: folder, children: nodes[idx].children)
            } else {
                insertNode(into: &nodes[idx].children, parts: remaining, folder: folder)
            }
        } else if remaining.isEmpty {
            nodes.append(FolderTreeNode(id: folder.id, name: first, folder: folder, children: []))
        } else {
            var virtual = FolderTreeNode(id: "virtual:\(first)", name: first, folder: nil, children: [])
            insertNode(into: &virtual.children, parts: remaining, folder: folder)
            nodes.append(virtual)
        }
    }
}
