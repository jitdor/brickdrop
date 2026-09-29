import XCTest
@testable import BrickDrop

final class ImportPlannerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "BrickDropTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
    }

    func testCueAutomaticallyIncludesReferencedBin() throws {
        let source = temporaryDirectory.appending(path: "Source")
        let sd = temporaryDirectory.appending(path: "SD")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sd, withIntermediateDirectories: true)
        let cue = source.appending(path: "Ridge Racer.cue")
        let bin = source.appending(path: "Ridge Racer (Track 01).bin")
        try "FILE \"Ridge Racer (Track 01).bin\" BINARY\n  TRACK 01 MODE2/2352".write(to: cue, atomically: true, encoding: .utf8)
        try Data([0, 1, 2]).write(to: bin)

        let items = ImportPlanner().plan(urls: [cue], sdRoot: sd)

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { $0.system == .ps })
        XCTAssertTrue(items.contains { $0.destinationURL?.path.hasSuffix("Roms/PS/Ridge Racer/Ridge Racer.cue") == true })
        XCTAssertTrue(items.contains { $0.destinationURL?.path.hasSuffix("Roms/PS/Ridge Racer/Ridge Racer (Track 01).bin") == true })
    }

    func testDroppedFolderKeepsRelativeStructure() throws {
        let source = temporaryDirectory.appending(path: "PS1 Collection")
        let disc = source.appending(path: "Final Fantasy/Disc 1")
        let sd = temporaryDirectory.appending(path: "SD")
        try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sd, withIntermediateDirectories: true)
        let chd = disc.appending(path: "Final Fantasy.chd")
        try Data([1]).write(to: chd)

        let items = ImportPlanner().plan(urls: [source], sdRoot: sd)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].system, .ps)
        XCTAssertTrue(items[0].destinationURL?.path.hasSuffix("Roms/PS/PS1 Collection/Final Fantasy/Disc 1/Final Fantasy.chd") == true)
    }

    func testCueWinsWhenCueAndBinAreDroppedTogether() throws {
        let source = temporaryDirectory.appending(path: "Loose")
        let sd = temporaryDirectory.appending(path: "SD")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sd, withIntermediateDirectories: true)
        let cue = source.appending(path: "Game.cue")
        let bin = source.appending(path: "Game.bin")
        try "FILE \"Game.bin\" BINARY".write(to: cue, atomically: true, encoding: .utf8)
        try Data([1]).write(to: bin)

        let items = ImportPlanner().plan(urls: [bin, cue], sdRoot: sd)

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { $0.destinationURL?.path.contains("Roms/PS/Game/") == true })
    }
}

extension ImportPlannerTests {
    func testM3UIncludesExistingReferencedDiscsAndSkipsMissingOnes() throws {
        let source = temporaryDirectory.appending(path: "Source")
        let sd = temporaryDirectory.appending(path: "SD")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sd, withIntermediateDirectories: true)
        let playlist = source.appending(path: "Final Fantasy VII PS1.m3u")
        try "# comment\nDisc 1.chd\n\nDisc 2.chd\nMissing.chd\n".write(to: playlist, atomically: true, encoding: .utf8)
        try Data([1]).write(to: source.appending(path: "Disc 1.chd"))
        try Data([2]).write(to: source.appending(path: "Disc 2.chd"))

        let items = ImportPlanner().plan(urls: [playlist], sdRoot: sd)

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.allSatisfy { $0.system == .ps })
        XCTAssertTrue(items.contains { $0.destinationURL?.path.hasSuffix("Roms/PS/Final Fantasy VII PS1/Disc 2.chd") == true })
    }

    func testCueIgnoresMissingAndUnquotedReferences() throws {
        let source = temporaryDirectory.appending(path: "Source")
        let sd = temporaryDirectory.appending(path: "SD")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sd, withIntermediateDirectories: true)
        let cue = source.appending(path: "Game.cue")
        try "FILE Track01.bin BINARY\nFILE \"Missing.bin\" BINARY\n".write(to: cue, atomically: true, encoding: .utf8)
        try Data([1]).write(to: source.appending(path: "Track01.bin"))

        let items = ImportPlanner().plan(urls: [cue], sdRoot: sd)

        XCTAssertEqual(items.map { $0.sourceURL.lastPathComponent }.sorted(), ["Game.cue", "Track01.bin"])
    }
}
