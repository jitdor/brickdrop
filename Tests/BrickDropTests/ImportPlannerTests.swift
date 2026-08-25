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
