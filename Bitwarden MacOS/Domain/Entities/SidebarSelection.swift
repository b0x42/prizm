import Foundation

/// The five vault item categories shown in the sidebar Type section.
/// `CaseIterable` enables the sidebar to iterate all types without a hardcoded list.
/// `Hashable` is required because `SidebarSelection.type(ItemType)` uses this as an
/// associated value, and `[SidebarSelection: Int]` is used for item counts.
nonisolated enum ItemType: String, Equatable, Hashable, CaseIterable {
    case login
    case card
    case identity
    case secureNote
    case sshKey

    var displayName: String {
        switch self {
        case .login:      return "Login"
        case .card:       return "Card"
        case .identity:   return "Identity"
        case .secureNote: return "Secure Note"
        case .sshKey:     return "SSH Key"
        }
    }
}

/// Represents which sidebar row the user has selected.
/// `Hashable` is required for use as a `NavigationSplitView` selection value
/// and as a dictionary key in `[SidebarSelection: Int]` item counts.
///
/// `Equatable` and `Hashable` are implemented explicitly with `nonisolated` to
/// prevent Swift 5.10 from inferring `@MainActor` on the synthesized conformances,
/// which would cause a Swift 6 error when used in nonisolated contexts.
nonisolated enum SidebarSelection: Equatable {
    case allItems
    case favorites
    case type(ItemType)
}

extension SidebarSelection: Hashable {
    nonisolated static func == (lhs: SidebarSelection, rhs: SidebarSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allItems, .allItems):         return true
        case (.favorites, .favorites):       return true
        case (.type(let a), .type(let b)):   return a == b
        default:                             return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .allItems:        hasher.combine(0)
        case .favorites:       hasher.combine(1)
        case .type(let type):  hasher.combine(2); hasher.combine(type)
        }
    }
}
