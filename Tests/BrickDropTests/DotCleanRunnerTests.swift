import XCTest
@testable import BrickDrop

final class DotCleanRunnerTests: XCTestCase {
    func testPassesVolumePathAsOneArgument() throws {
        let runner = DotCleanRunner(executableURL: URL(fileURLWithPath: "/bin/echo"))
        let output = try runner.clean(volumeURL: URL(fileURLWithPath: "/Volumes/My SD Card"))

        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "-m /Volumes/My SD Card")
    }

    func testReportsNonzeroExit() {
        let runner = DotCleanRunner(executableURL: URL(fileURLWithPath: "/usr/bin/false"))

        XCTAssertThrowsError(try runner.clean(volumeURL: URL(fileURLWithPath: "/Volumes/Card"))) { error in
            guard case DotCleanError.failed(let exitCode, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertNotEqual(exitCode, 0)
        }
    }

    func testTimesOutHungProcess() {
        let started = Date()

        // A script that ignores its arguments and never finishes on its own.
        let script = FileManager.default.temporaryDirectory.appending(path: "hang-\(UUID().uuidString).sh")
        defer { try? FileManager.default.removeItem(at: script) }
        XCTAssertNoThrow(try "#!/bin/sh\nexec sleep 30\n".write(to: script, atomically: true, encoding: .utf8))
        XCTAssertNoThrow(try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path))

        let hanging = DotCleanRunner(executableURL: script, timeout: 0.5)
        XCTAssertThrowsError(try hanging.clean(volumeURL: URL(fileURLWithPath: "/Volumes/Card"))) { error in
            guard case DotCleanError.timedOut = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testReturnsWhenExitedProcessLeavesBackgroundChildHoldingOutput() throws {
        let script = FileManager.default.temporaryDirectory.appending(path: "orphan-\(UUID().uuidString).sh")
        defer { try? FileManager.default.removeItem(at: script) }
        try "#!/bin/sh\necho done\nsleep 30 &\nexit 0\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let runner = DotCleanRunner(executableURL: script, timeout: 0.5)
        let started = Date()

        let output = try runner.clean(volumeURL: URL(fileURLWithPath: "/Volumes/Card"))

        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "done")
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }
}
