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
}
