import XCTest
@testable import BrickDrop

final class RoutingEngineTests: XCTestCase {
    private let router = RoutingEngine()

    func testDirectExtensionMappings() {
        let cases: [(String, ROMSystem)] = [
            ("mario.nes", .fc),
            ("zelda.gb", .gb),
            ("zelda.gbc", .gbc),
            ("metroid.gba", .gba),
            ("crazy-taxi.gdi", .dc),
            ("ridge-racer.cue", .ps),
            ("game.cso", .psp)
        ]

        for (filename, expected) in cases {
            XCTAssertEqual(router.route(fileURL: URL(fileURLWithPath: "/tmp/\(filename)")).system, expected, filename)
        }
    }

    func testCHDUsesSourceFolderHeuristic() {
        let dreamcast = router.route(fileURL: URL(fileURLWithPath: "/Incoming/Dreamcast/Sonic.chd"))
        let playstation = router.route(fileURL: URL(fileURLWithPath: "/Incoming/PS1/Metal Gear.chd"))
        XCTAssertEqual(dreamcast.system, .dc)
        XCTAssertEqual(playstation.system, .ps)
    }

    func testAmbiguousCHDRequiresChoice() {
        let decision = router.route(fileURL: URL(fileURLWithPath: "/Incoming/Game.chd"))
        XCTAssertNil(decision.system)
        XCTAssertEqual(decision.candidates, [.ps, .dc, .pce])
    }

    func testAmbiguousISORequiresChoice() {
        let decision = router.route(fileURL: URL(fileURLWithPath: "/Incoming/Game.iso"))
        XCTAssertNil(decision.system)
        XCTAssertEqual(decision.candidates, [.psp, .ps, .dc])
    }

    func testBinWithCueSiblingRoutesToPlayStation() {
        let decision = router.route(
            fileURL: URL(fileURLWithPath: "/Incoming/Ridge Racer.bin"),
            siblingNames: ["Ridge Racer.cue", "Ridge Racer.bin"]
        )
        XCTAssertEqual(decision.system, .ps)
    }

    func testArchiveUsesFolderHeuristic() {
        let decision = router.route(fileURL: URL(fileURLWithPath: "/ROMs/Arcade/galaga.zip"))
        XCTAssertEqual(decision.system, .arcade)
    }
}
