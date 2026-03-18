import AppKit
import os.log

// MARK: - FaviconLoader

/// Loads favicon images from the Bitwarden icon service.
///
/// URL format: `{ICONS_BASE}/{domain}/icon.png`
/// Default icons base: `https://icons.bitwarden.net`
/// Override via `ServerEnvironment.overrides.icons`.
///
/// Caching: `URLCache` provides HTTP-level caching (`returnCacheDataElseLoad`).
/// In-memory `NSCache<NSString, NSImage>` provides session-level deduplication.
/// Failures are silent — callers fall back to the appropriate SF Symbol (FR-009).
///
/// Thread safety: `actor` isolation guarantees the in-memory cache is mutation-safe.
actor FaviconLoader {

    // MARK: - Dependencies

    private let session:  URLSession
    private let iconsBase: URL
    private let logger = Logger(subsystem: "com.bitwarden-macos", category: "FaviconLoader")

    // MARK: - In-memory cache

    private let cache = NSCache<NSString, NSImage>()

    // MARK: - Init

    /// - Parameters:
    ///   - iconsBase: Override for the icons service base URL.
    ///                Defaults to `https://icons.bitwarden.net`.
    ///   - session:   `URLSession` to use; defaults to a shared cache-enabled session.
    init(
        iconsBase: URL = URL(string: "https://icons.bitwarden.net")!,
        session: URLSession = .shared
    ) {
        self.iconsBase = iconsBase
        self.session   = session
    }

    // MARK: - Public API

    /// Returns the favicon for `domain`, or `nil` on any failure (FR-009).
    ///
    /// - Parameter domain: Bare domain (e.g. `"github.com"`), no scheme or path.
    func favicon(for domain: String) async -> NSImage? {
        let key = domain as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let url = iconsBase
            .appendingPathComponent(domain)
            .appendingPathComponent("icon.png")

        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            guard let image = NSImage(data: data) else {
                return nil
            }
            cache.setObject(image, forKey: key)
            return image
        } catch {
            logger.debug("Favicon fetch failed for \(domain, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Clears the in-memory cache (e.g. on sign-out or low-memory warning).
    func clearCache() {
        cache.removeAllObjects()
    }
}
