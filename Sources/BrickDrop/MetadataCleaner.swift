import Darwin
import Foundation

struct MetadataCleaner: @unchecked Sendable {
    private let fileManager: FileManager
    private let metadataDirectoryNames: Set<String> = [
        ".Spotlight-V100", ".Trashes", ".fseventsd", ".TemporaryItems", ".DocumentRevisions-V100"
    ]
    private let metadataFileNames: Set<String> = [".DS_Store", ".VolumeIcon.icns"]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func clean(root: URL) -> CleanupReport {
        var removed = 0
        var failures: [String] = []
        var targets: [URL] = []
        collectTargets(in: root, targets: &targets, failures: &failures)

        // Children are removed before parents if the enumerator ever returns overlapping targets.
        for target in targets.sorted(by: { $0.path.count > $1.path.count }) {
            do {
                try fileManager.removeItem(at: target)
                removed += 1
            } catch {
                failures.append("\(target.path): \(error.localizedDescription)")
            }
        }
        return CleanupReport(removedCount: removed, failures: failures)
    }

    private func collectTargets(in directory: URL, targets: inout [URL], failures: inout [String]) {
        guard let stream = opendir(directory.path) else {
            let description = String(cString: strerror(errno))
            failures.append("\(directory.path): \(description)")
            return
        }
        defer { closedir(stream) }

        while let entry = readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                    String(cString: $0)
                }
            }
            guard name != "." && name != ".." else { continue }
            let child = directory.appendingPathComponent(name, isDirectory: false)
            var info = stat()
            guard lstat(child.path, &info) == 0 else { continue }
            let fileType = info.st_mode & S_IFMT
            guard fileType != S_IFLNK else { continue }

            if fileType == S_IFDIR {
                if metadataDirectoryNames.contains(name) {
                    targets.append(child)
                } else {
                    collectTargets(in: child, targets: &targets, failures: &failures)
                }
            } else if name.hasPrefix("._") || metadataFileNames.contains(name) {
                targets.append(child)
            }
        }
    }
}
