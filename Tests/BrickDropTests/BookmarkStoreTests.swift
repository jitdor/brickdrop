import Foundation
import XCTest
@testable import BrickDrop

@MainActor
final class BookmarkStoreTests: XCTestCase {
    func testSavesAndRestoresVolumeURLWithoutOpenPanelScope() throws {
        let suiteName = "BookmarkStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = BookmarkStore(defaults: defaults)
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        try store.save(url)

        XCTAssertEqual(store.restore()?.standardizedFileURL, url.standardizedFileURL)
    }
}
