import Foundation

/// The five vault item categories shown in the sidebar Type section.
/// `CaseIterable` enables the sidebar to iterate all types without a hardcoded list.
/// `Hashable` is required because `SidebarSelection.type(ItemType)` uses this as an
/// associated value, and `[SidebarSelection: Int]` is used for item counts.
enum ItemType: String, Equatable, Hashable, CaseIterable {
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
enum SidebarSelection: Hashable, Equatable {
    case allItems
    case favorites
    case type(ItemType)
}
