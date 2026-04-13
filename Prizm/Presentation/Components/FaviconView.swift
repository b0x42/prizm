import SwiftUI

// MARK: - FaviconView

/// Displays a favicon for a given domain, falling back to a per-type SF Symbol (FR-009, FR-032).
///
/// The image is loaded asynchronously via `FaviconLoader`. If the load fails or
/// the domain is nil, the SF Symbol for `itemType` is shown instead.
///
/// Usage:
/// ```swift
/// FaviconView(domain: "github.com", itemType: .login, loader: container.faviconLoader)
///     .frame(width: 16, height: 16)
/// ```
struct FaviconView: View {

    let domain:   String?
    let itemType: ItemType
    let loader:   FaviconLoader
    var size:     CGFloat = 16

    @State private var image: NSImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
            } else {
                Image(systemName: itemType.sfSymbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: domain) {
            guard let domain else {
                image = nil
                return
            }
            image = await loader.favicon(for: domain)
        }
    }
}
