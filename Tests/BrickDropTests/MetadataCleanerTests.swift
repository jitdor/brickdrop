import XCTest
@testable import BrickDrop

final class MetadataCleanerTests: XCTestCase {
    func testCleanerRemovesOnlyKnownMetadata() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "BrickDropCleaner-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appending(path: "Roms/GB"), withIntermediateDirectories: true)
        let rom = root.appending(path: "Roms/GB/Tetris.gb")
        let appleDouble = root.appending(path: "Roms/GB/._Tetris.gb")
        let dsStore = root.appending(path: "Roms/.DS_Store")
        let ordinaryHiddenFile = root.appending(path: "Roms/GB/.keep")
        try Data([1, 2, 3]).write(to: rom)
        try Data([4]).write(to: appleDouble)
        try Data([5]).write(to: dsStore)
        try Data([6]).write(to: ordinaryHiddenFile)

        let report = MetadataCleaner().clean(root: root)

        XCTAssertEqual(report.removedCount, 2)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rom.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordinaryHiddenFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: appleDouble.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dsStore.path))
    }

    func testCleanerNeverFollowsOrRemovesSymlinks() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "BrickDropSymlink-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appending(path: "SD")
        let outside = base.appending(path: "Outside")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside.appending(path: ".Trashes"), withIntermediateDirectories: true)
        let outsideMetadata = outside.appending(path: "._precious")
        let outsideDSStore = outside.appending(path: ".DS_Store")
        try Data([1]).write(to: outsideMetadata)
        try Data([2]).write(to: outsideDSStore)

        // A symlinked directory pointing outside the card, one named like metadata, and a file symlink.
        let linkedDirectory = root.appending(path: "Linked")
        let linkedTrashes = root.appending(path: ".Trashes")
        let linkedAppleDouble = root.appending(path: "._link")
        try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: outside)
        try FileManager.default.createSymbolicLink(at: linkedTrashes, withDestinationURL: outside.appending(path: ".Trashes"))
        try FileManager.default.createSymbolicLink(at: linkedAppleDouble, withDestinationURL: outsideMetadata)

        let report = MetadataCleaner().clean(root: root)

        XCTAssertEqual(report.removedCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideMetadata.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideDSStore.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.appending(path: ".Trashes").path))
        for link in [linkedDirectory, linkedTrashes, linkedAppleDouble] {
            XCTAssertNotNil(try? FileManager.default.destinationOfSymbolicLink(atPath: link.path), link.lastPathComponent)
        }
    }

    func testCleanerRemovesMetadataDirectoriesRecursively() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "BrickDropDirs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let trashes = root.appending(path: ".Trashes/501")
        try FileManager.default.createDirectory(at: trashes, withIntermediateDirectories: true)
        try Data([1]).write(to: trashes.appending(path: "old.gb"))

        let report = MetadataCleaner().clean(root: root)

        XCTAssertEqual(report.removedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: ".Trashes").path))
    }
}
