import XCTest
@testable import BrickDrop

final class ImportExecutorTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "BrickDropExecutor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory.appending(path: "SD"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func makeItem(contents: UInt8, status: ImportStatus = .ready, withDestination: Bool = true) throws -> ImportItem {
        let source = directory.appending(path: "Tetris-\(UUID().uuidString).gb")
        try Data([contents]).write(to: source)
        return ImportItem(
            sourceURL: source,
            system: .gb,
            candidateSystems: [.gb],
            destinationURL: withDestination ? directory.appending(path: "SD/Roms/GB/Tetris.gb") : nil,
            status: status,
            detail: ""
        )
    }

    func testCopiesIntoNewDestinationDirectories() throws {
        let item = try makeItem(contents: 1)
        let report = ImportExecutor().execute(items: [item], sdRoot: directory.appending(path: "SD"), overwriteExisting: false)

        XCTAssertEqual(report.copied, [item.id])
        XCTAssertEqual(try Data(contentsOf: item.destinationURL!), Data([1]))
    }

    func testSkipsExistingFileWhenNotOverwriting() throws {
        let existing = try makeItem(contents: 1)
        _ = ImportExecutor().execute(items: [existing], sdRoot: directory.appending(path: "SD"), overwriteExisting: false)
        let replacement = try makeItem(contents: 2)

        let report = ImportExecutor().execute(items: [replacement], sdRoot: directory.appending(path: "SD"), overwriteExisting: false)

        XCTAssertEqual(report.skipped, [replacement.id])
        XCTAssertTrue(report.copied.isEmpty)
        XCTAssertEqual(try Data(contentsOf: replacement.destinationURL!), Data([1]))
    }

    func testReplacesExistingFileWhenOverwriting() throws {
        let existing = try makeItem(contents: 1)
        _ = ImportExecutor().execute(items: [existing], sdRoot: directory.appending(path: "SD"), overwriteExisting: false)
        let replacement = try makeItem(contents: 2)

        let report = ImportExecutor().execute(items: [replacement], sdRoot: directory.appending(path: "SD"), overwriteExisting: true)

        XCTAssertEqual(report.copied, [replacement.id])
        XCTAssertEqual(try Data(contentsOf: replacement.destinationURL!), Data([2]))
    }

    func testIgnoresItemsThatAreNotReady() throws {
        let item = try makeItem(contents: 1, status: .needsChoice)
        let report = ImportExecutor().execute(items: [item], sdRoot: directory.appending(path: "SD"), overwriteExisting: true)

        XCTAssertTrue(report.copied.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.destinationURL!.path))
    }

    func testReportsFailureForMissingDestinationOrSource() throws {
        let noDestination = try makeItem(contents: 1, withDestination: false)
        var missingSource = try makeItem(contents: 1)
        try FileManager.default.removeItem(at: missingSource.sourceURL)
        missingSource.destinationURL = directory.appending(path: "SD/Roms/GB/Other.gb")

        let report = ImportExecutor().execute(
            items: [noDestination, missingSource], sdRoot: directory.appending(path: "SD"), overwriteExisting: false
        )

        XCTAssertNotNil(report.failures[noDestination.id])
        XCTAssertNotNil(report.failures[missingSource.id])
        XCTAssertTrue(report.copied.isEmpty)
    }

    func testCleansMetadataAfterCopy() throws {
        let sd = directory.appending(path: "SD")
        try Data([9]).write(to: sd.appending(path: ".DS_Store"))
        let item = try makeItem(contents: 1)

        let report = ImportExecutor().execute(items: [item], sdRoot: sd, overwriteExisting: false)

        XCTAssertEqual(report.cleanup.removedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sd.appending(path: ".DS_Store").path))
    }
}
