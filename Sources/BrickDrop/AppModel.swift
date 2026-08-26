import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var sdRoot: URL?
    @Published var items: [ImportItem] = []
    @Published var isTargeted = false
    @Published var isWorking = false
    @Published var overwriteExisting = false
    @Published var message = "Choose your Brick Pro SD card to begin."
    @Published var cleanupSummary: String?
    @Published var isChoosingSDCard = false
    @Published private(set) var availableVolumes: [MountedVolume] = []

    private let bookmarks = BookmarkStore()
    private let planner = ImportPlanner()
    private let executor = ImportExecutor()
    private let ejector = VolumeEjector()
    private let dotCleanRunner = DotCleanRunner()
    private let volumeProvider = MountedVolumeProvider()

    init() {
        sdRoot = bookmarks.restore()
        if let sdRoot {
            message = "Ready for ROMs — using \(sdRoot.lastPathComponent)."
        }
    }

    var unresolvedCount: Int { items.filter { $0.status == .needsChoice }.count }
    var readyCount: Int { items.filter { $0.status == .ready }.count }
    var canImport: Bool { readyCount > 0 && unresolvedCount == 0 && !isWorking && sdRoot != nil }
    var canEject: Bool { sdRoot != nil && !isWorking }

    func chooseSDCard() {
        refreshVolumes()
        isChoosingSDCard = true
    }

    func refreshVolumes() {
        availableVolumes = volumeProvider.removableVolumes()
    }

    func selectSDCard(_ volume: MountedVolume) {
        do {
            try bookmarks.save(volume.url)
            sdRoot = volume.url
            items = []
            isChoosingSDCard = false
            message = "Ready for ROMs — using \(volume.name)."
        } catch {
            message = "Could not remember that volume: \(error.localizedDescription)"
        }
    }

    func acceptProviders(_ providers: [NSItemProvider]) -> Bool {
        guard sdRoot != nil else {
            message = "Choose the SD card before dropping ROMs."
            return false
        }
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }

        Task {
            var urls: [URL] = []
            for provider in matching {
                if let url = await loadURL(from: provider) { urls.append(url) }
            }
            prepare(urls: urls)
        }
        return true
    }

    func prepare(urls: [URL]) {
        guard let sdRoot else { return }
        let planned = planner.plan(urls: urls, sdRoot: sdRoot)
        let merge = ImportQueue.merge(existing: items, incoming: planned)
        items = merge.items
        cleanupSummary = nil
        if planned.isEmpty {
            message = "No supported ROM files were found in that drop."
        } else if merge.addedCount == 0 && merge.upgradedCount == 0 {
            message = "Those files are already in the import queue."
        } else if unresolvedCount > 0 {
            message = queueUpdateText(merge) + " Choose a system for \(unresolvedCount) ambiguous item\(unresolvedCount == 1 ? "" : "s")."
        } else {
            message = queueUpdateText(merge) + " Review the queue before importing."
        }
    }

    func assign(_ system: ROMSystem, to item: ImportItem) {
        guard let sdRoot else { return }
        items = planner.applying(system: system, to: item, sdRoot: sdRoot, allItems: items)
        message = unresolvedCount == 0 ? "All destinations are resolved. Ready to import." : "Choose systems for the remaining ambiguous files."
    }

    func importFiles() {
        guard let sdRoot, canImport else { return }
        isWorking = true
        message = "Copying ROMs and removing Finder metadata…"
        let snapshot = items
        let overwrite = overwriteExisting
        Task {
            let report = await Task.detached(priority: .userInitiated) { [executor] in
                executor.execute(items: snapshot, sdRoot: sdRoot, overwriteExisting: overwrite)
            }.value
            for index in self.items.indices {
                let id = self.items[index].id
                if report.copied.contains(id) {
                    self.items[index].status = .copied
                    self.items[index].detail = "Copied successfully"
                } else if report.skipped.contains(id) {
                    self.items[index].status = .skipped
                    self.items[index].detail = "Already exists — left unchanged"
                } else if let failure = report.failures[id] {
                    self.items[index].status = .failed
                    self.items[index].detail = failure
                }
            }
            self.isWorking = false
            self.cleanupSummary = self.cleanupText(report.cleanup)
            self.message = "Import finished: \(report.copied.count) copied, \(report.skipped.count) skipped, \(report.failures.count) failed."
        }
    }

    func cleanMetadataNow() {
        guard let sdRoot, !isWorking else { return }
        isWorking = true
        message = "Scanning the SD card for macOS metadata…"
        Task {
            let report = await Task.detached(priority: .userInitiated) {
                MetadataCleaner().clean(root: sdRoot)
            }.value
            self.isWorking = false
            self.cleanupSummary = self.cleanupText(report)
            self.message = report.failures.isEmpty ? "Metadata cleanup finished." : "Metadata cleanup finished with \(report.failures.count) warning(s)."
        }
    }

    func ejectSDCard() {
        guard let selectedRoot = sdRoot, canEject else { return }
        let volume: URL
        do {
            volume = try ejector.removableVolume(for: selectedRoot)
        } catch {
            message = "Could not eject the SD card: \(error.localizedDescription)"
            return
        }

        isWorking = true
        message = "Running dot_clean on \(volume.lastPathComponent) before ejecting…"

        Task { [dotCleanRunner] in
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try dotCleanRunner.clean(volumeURL: volume)
                }.value
                bookmarks.suspendAccess()
                try ejector.eject(volumeURL: volume)
                sdRoot = nil
                items = []
                cleanupSummary = nil
                isWorking = false
                message = "dot_clean finished and \(volume.lastPathComponent) was ejected. It is safe to remove."
            } catch {
                bookmarks.resumeAccess(to: selectedRoot)
                isWorking = false
                message = "Cleanup or eject failed; the card remains mounted: \(error.localizedDescription)"
            }
        }
    }

    func clearResults() {
        items = []
        cleanupSummary = nil
        message = sdRoot.map { "Ready for ROMs — using \($0.lastPathComponent)." } ?? "Choose your Brick Pro SD card to begin."
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let nsURL = item as? NSURL {
                    continuation.resume(returning: nsURL as URL)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func cleanupText(_ report: CleanupReport) -> String {
        if report.failures.isEmpty {
            return report.removedCount == 0
                ? "No macOS metadata files were found."
                : "Removed \(report.removedCount) macOS metadata item\(report.removedCount == 1 ? "" : "s")."
        }
        return "Removed \(report.removedCount) metadata items; \(report.failures.count) could not be removed."
    }

    private func queueUpdateText(_ merge: QueueMergeResult) -> String {
        var parts: [String] = []
        if merge.addedCount > 0 {
            parts.append("Added \(merge.addedCount) file\(merge.addedCount == 1 ? "" : "s")")
        }
        if merge.upgradedCount > 0 {
            parts.append("updated \(merge.upgradedCount) disc-set item\(merge.upgradedCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " and ") + "."
    }
}
