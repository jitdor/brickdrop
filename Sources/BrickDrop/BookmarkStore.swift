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
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: key)
        _ = url.startAccessingSecurityScopedResource()
        accessedURL = url
    }

    func restore() -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        stopAccessingCurrentURL()
        _ = url.startAccessingSecurityScopedResource()
        accessedURL = url
        if stale { try? save(url) }
        return url
    }

    func clear() {
        stopAccessingCurrentURL()
        defaults.removeObject(forKey: key)
    }

    private func stopAccessingCurrentURL() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
    }
}
