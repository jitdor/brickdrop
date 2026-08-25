import Foundation

enum DotCleanError: LocalizedError {
    case failed(exitCode: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .failed(let exitCode, let message):
            let detail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "dot_clean failed with exit code \(exitCode)."
                : "dot_clean failed: \(detail)"
        }
    }
}

struct DotCleanRunner: Sendable {
    let executableURL: URL

    init(executableURL: URL = URL(fileURLWithPath: "/usr/sbin/dot_clean")) {
        self.executableURL = executableURL
    }

    @discardableResult
    func clean(volumeURL: URL) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["-m", volumeURL.path]
        process.standardOutput = output
        process.standardError = output

        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw DotCleanError.failed(exitCode: process.terminationStatus, message: message)
        }
        return message
    }
}
