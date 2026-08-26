import Foundation

@MainActor
final class BookmarkStore {
    private let defaults: UserDefaults
    private let key = "brickDropSDCardBookmark"
    private var accessedURL: URL?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    deinit {
        accessedURL?.stopAccessingSecurityScopedResource()
    }

    func save(_ url: URL) throws {
        stopAccessingCurrentURL()
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: key)
        _ = url.startAccessingSecurityScopedResource()
        accessedURL = url
    }

    func restore() -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }

        let resolutionOptions: [URL.BookmarkResolutionOptions] = [
            [.withSecurityScope, .withoutUI],
            [.withoutUI]
        ]
        for options in resolutionOptions {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else {
                continue
            }
            stopAccessingCurrentURL()
            _ = url.startAccessingSecurityScopedResource()
            accessedURL = url
            if stale { try? save(url) }
            return url
        }

        defaults.removeObject(forKey: key)
        return nil
    }

    func clear() {
        stopAccessingCurrentURL()
        defaults.removeObject(forKey: key)
    }

    func suspendAccess() {
        stopAccessingCurrentURL()
    }

    func resumeAccess(to url: URL) {
        stopAccessingCurrentURL()
        _ = url.startAccessingSecurityScopedResource()
        accessedURL = url
    }

    private func stopAccessingCurrentURL() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
    }
}
