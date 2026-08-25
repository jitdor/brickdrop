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
}
