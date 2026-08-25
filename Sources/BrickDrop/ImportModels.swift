import Foundation

enum ImportStatus: String, Sendable {
    case ready = "Ready"
    case needsChoice = "Choose system"
    case copied = "Copied"
    case skipped = "Skipped"
    case failed = "Failed"
    case preview = "Preview"
}

struct ImportItem: Identifiable, Sendable {
    let id: UUID
    let sourceURL: URL
    var system: ROMSystem?
    var candidateSystems: [ROMSystem]
    var destinationURL: URL?
    var status: ImportStatus
    var detail: String
    var groupRoot: URL?
    var relativePath: String?

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        system: ROMSystem?,
        candidateSystems: [ROMSystem],
        destinationURL: URL?,
        status: ImportStatus,
        detail: String,
        groupRoot: URL? = nil,
        relativePath: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.system = system
        self.candidateSystems = candidateSystems
        self.destinationURL = destinationURL
        self.status = status
        self.detail = detail
        self.groupRoot = groupRoot
        self.relativePath = relativePath
    }
}

struct CleanupReport: Sendable {
    let removedCount: Int
    let failures: [String]
}

struct CopyReport: Sendable {
    let copied: Set<UUID>
    let skipped: Set<UUID>
    let failures: [UUID: String]
    let cleanup: CleanupReport
}
