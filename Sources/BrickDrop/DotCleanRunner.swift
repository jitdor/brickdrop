import Foundation

enum DotCleanError: LocalizedError {
    case failed(exitCode: Int32, message: String)
    case timedOut(seconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .failed(let exitCode, let message):
            let detail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "dot_clean failed with exit code \(exitCode)."
                : "dot_clean failed: \(detail)"
        case .timedOut(let seconds):
            return "dot_clean did not finish within \(Int(seconds)) seconds and was stopped."
        }
    }
}

private final class OutputBox: @unchecked Sendable {
    var data = Data()
}

struct DotCleanRunner: Sendable {
    let executableURL: URL
    let timeout: TimeInterval

    init(executableURL: URL = URL(fileURLWithPath: "/usr/sbin/dot_clean"), timeout: TimeInterval = 120) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    @discardableResult
    func clean(volumeURL: URL) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["-m", volumeURL.path]
        process.standardOutput = output
        process.standardError = output

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()

        // Drain the pipe concurrently so a chatty child can't block on a full buffer.
        let box = OutputBox()
        let drained = DispatchGroup()
        drained.enter()
        DispatchQueue.global().async {
            box.data = output.fileHandleForReading.readDataToEndOfFile()
            drained.leave()
        }

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                finished.wait()
            }
            _ = drained.wait(timeout: .now() + 2)
            throw DotCleanError.timedOut(seconds: timeout)
        }
        drained.wait()

        let message = String(data: box.data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw DotCleanError.failed(exitCode: process.terminationStatus, message: message)
        }
        return message
    }
}
