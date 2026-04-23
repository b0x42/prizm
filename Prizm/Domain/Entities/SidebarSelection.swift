import Foundation

/// The five vault item categories shown in the sidebar Type section.
/// `CaseIterable` enables the sidebar to iterate all types without a hardcoded list.
/// `Hashable` is required because `SidebarSelection.type(ItemType)` uses this as an
/// associated value, and `[SidebarSelection: Int]` is used for item counts.
nonisolated enum ItemType: String, Equatable, Hashable, CaseIterable, Identifiable {
    case login
    case card
    case identity
    case secureNote
    case sshKey

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .login:      return "Login"
        case .card:       return "Card"
        case .identity:   return "Identity"
        case .secureNote: return "Secure Note"
        case .sshKey:     return "SSH Key"
        }
    }

    var sfSymbol: String {
        switch self {
        case .login:      return "key"
        case .card:       return "creditcard"
        case .identity:   return "person.crop.rectangle"
        case .secureNote: return "note.text"
        case .sshKey:     return "terminal"
        }
    }
}

/// Represents which sidebar row the user has selected.
/// `Hashable` is required for use as a `NavigationSplitView` selection value
/// and as a dictionary key in `[SidebarSelection: Int]` item counts.
///
/// `Equatable` and `Hashable` are implemented explicitly with `nonisolated` to
/// prevent the compiler from inferring `@MainActor` on the conformances when
/// `SidebarSelection` is used as a `NavigationSplitView` selection type (a SwiftUI
/// `@MainActor` context). The `nonisolated` on the conformance extension ensures
/// the conformance itself is nonisolated, not just the individual methods.
nonisolated enum SidebarSelection {
    case allItems
    case favorites
    case type(ItemType)
    case folder(String)
    /// Soft-deleted items awaiting permanent removal (Bitwarden Trash).
    case trash
    /// Transient state while the user is typing a new folder name inline.
    case newFolder
    /// All items across all collections in the given organization.
    case organization(String)
    /// Items assigned to a specific collection within an organization.
    case collection(String)
    /// Transient state while the user is typing a new collection name inline.
    case newCollection(organizationId: String)
}

extension SidebarSelection {
    var displayName: String {
        switch self {
        case .allItems:                      return "All Items"
        case .favorites:                     return "Favorites"
        case .type(let type):                return type.displayName
        case .folder:                        return "Folder"
        case .trash:                         return "Trash"
        case .newFolder:                     return "New Folder"
        case .organization:                  return "Organization"
        case .collection:                    return "Collection"
        case .newCollection:                 return "New Collection"
        }
    }
}

nonisolated extension SidebarSelection: Hashable {
    nonisolated static func == (lhs: SidebarSelection, rhs: SidebarSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allItems, .allItems):                                     return true
        case (.favorites, .favorites):                                   return true
        case (.type(let a), .type(let b)):                               return a == b
        case (.folder(let a), .folder(let b)):                           return a == b
        case (.trash, .trash):                                           return true
        case (.newFolder, .newFolder):                                   return true
        case (.organization(let a), .organization(let b)):               return a == b
        case (.collection(let a), .collection(let b)):                   return a == b
        case (.newCollection(let a), .newCollection(let b)):             return a == b
        default:                                                         return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .allItems:                          hasher.combine(0)
        case .favorites:                         hasher.combine(1)
        case .type(let type):                    hasher.combine(2); hasher.combine(type)
        case .folder(let id):                    hasher.combine(3); hasher.combine(id)
        case .trash:                             hasher.combine(4)
        case .newFolder:                         hasher.combine(5)
        case .organization(let id):              hasher.combine(6); hasher.combine(id)
        case .collection(let id):                hasher.combine(7); hasher.combine(id)
        case .newCollection(let orgId):          hasher.combine(8); hasher.combine(orgId)
        }
    }
}
