import Foundation

struct ImportExecutor: @unchecked Sendable {
    private let fileManager: FileManager
    private let cleaner: MetadataCleaner

    init(fileManager: FileManager = .default, cleaner: MetadataCleaner = MetadataCleaner()) {
        self.fileManager = fileManager
        self.cleaner = cleaner
    }

    func execute(items: [ImportItem], sdRoot: URL, overwriteExisting: Bool) -> CopyReport {
        var copied = Set<UUID>()
        var skipped = Set<UUID>()
        var failures: [UUID: String] = [:]

        for item in items where item.status == .ready || item.status == .preview {
            guard let destination = item.destinationURL else {
                failures[item.id] = "No destination was selected"
                continue
            }
            do {
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: destination.path) {
                    if overwriteExisting {
                        try fileManager.removeItem(at: destination)
                    } else {
                        skipped.insert(item.id)
                        continue
                    }
                }
                try fileManager.copyItem(at: item.sourceURL, to: destination)
                copied.insert(item.id)
            } catch {
                failures[item.id] = error.localizedDescription
            }
        }

        let cleanup = cleaner.clean(root: sdRoot)
        return CopyReport(copied: copied, skipped: skipped, failures: failures, cleanup: cleanup)
    }
}
