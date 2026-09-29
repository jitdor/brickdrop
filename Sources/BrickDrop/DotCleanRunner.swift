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
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ chunk: Data) {
        lock.lock()
        buffer.append(chunk)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
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

        // Drain the pipe as data arrives so a chatty child can't block on a full buffer. EOF only
        // arrives once every holder of the write end closes it, which a backgrounded grandchild
        // can delay long after the executable itself exits, so every wait on it is bounded.
        let box = OutputBox()
        let drained = DispatchSemaphore(value: 0)
        let reader = output.fileHandleForReading
        reader.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                drained.signal()
            } else {
                box.append(chunk)
            }
        }
        // Stops reading and closes our end so nothing is left blocked on an inherited pipe.
        func releasePipe(waitingUpTo grace: TimeInterval) {
            if drained.wait(timeout: .now() + grace) == .timedOut {
                reader.readabilityHandler = nil
                try? reader.close()
            }
        }

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 2)
            }
            releasePipe(waitingUpTo: 1)
            throw DotCleanError.timedOut(seconds: timeout)
        }
        releasePipe(waitingUpTo: 1)

        let message = String(data: box.data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw DotCleanError.failed(exitCode: process.terminationStatus, message: message)
        }
        return message
    }
}
