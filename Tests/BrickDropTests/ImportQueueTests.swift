import XCTest
@testable import BrickDrop

final class ImportQueueTests: XCTestCase {
    func testSeparateDropsAccumulate() {
        let first = item("Mario.nes", system: .fc)
        let second = item("Tetris.gb", system: .gb)

        let afterFirst = ImportQueue.merge(existing: [], incoming: [first])
        let afterSecond = ImportQueue.merge(existing: afterFirst.items, incoming: [second])

        XCTAssertEqual(afterSecond.items.count, 2)
        XCTAssertEqual(afterSecond.addedCount, 1)
        XCTAssertEqual(Set(afterSecond.items.map { $0.sourceURL.lastPathComponent }), ["Mario.nes", "Tetris.gb"])
    }

    func testDuplicateDropDoesNotCreateAnotherJob() {
        let original = item("Mario.nes", system: .fc)
        let duplicate = item("Mario.nes", system: .fc)

        let result = ImportQueue.merge(existing: [original], incoming: [duplicate])

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.addedCount, 0)
        XCTAssertEqual(result.upgradedCount, 0)
        XCTAssertEqual(result.items[0].id, original.id)
    }

    func testLaterCueDropUpgradesLooseTrackIntoDiscSet() {
        let loose = item("Game.bin", system: nil, status: .needsChoice)
        let cue = URL(fileURLWithPath: "/Incoming/Game.cue")
        let grouped = ImportItem(
            sourceURL: loose.sourceURL,
            system: .ps,
            candidateSystems: [.ps],
            destinationURL: URL(fileURLWithPath: "/SD/Roms/PS/Game/Game.bin"),
            status: .ready,
            detail: "Included by CUE",
            groupRoot: cue,
            relativePath: "Game/Game.bin"
        )

        let result = ImportQueue.merge(existing: [loose], incoming: [grouped])

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.upgradedCount, 1)
        XCTAssertEqual(result.items[0].id, loose.id)
        XCTAssertEqual(result.items[0].system, .ps)
        XCTAssertEqual(result.items[0].destinationURL?.path, "/SD/Roms/PS/Game/Game.bin")
    }

    func testCompletedResultIsNotQueuedAgain() {
        let completed = item("Mario.nes", system: .fc, status: .copied)
        let repeated = item("Mario.nes", system: .fc)

        let result = ImportQueue.merge(existing: [completed], incoming: [repeated])

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].status, .copied)
        XCTAssertEqual(result.addedCount, 0)
    }

    private func item(_ name: String, system: ROMSystem?, status: ImportStatus = .ready) -> ImportItem {
        let source = URL(fileURLWithPath: "/Incoming/\(name)")
        return ImportItem(
            sourceURL: source,
            system: system,
            candidateSystems: system.map { [$0] } ?? [.ps, .md],
            destinationURL: system.map { URL(fileURLWithPath: "/SD/Roms/\($0.folderName)/\(name)") },
            status: status,
            detail: "Test"
        )
    }
}
