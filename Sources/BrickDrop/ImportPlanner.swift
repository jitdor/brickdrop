import Foundation

struct ImportPlanner: @unchecked Sendable {
    let router: RoutingEngine
    let fileManager: FileManager

    init(router: RoutingEngine = RoutingEngine(), fileManager: FileManager = .default) {
        self.router = router
        self.fileManager = fileManager
    }

    func plan(urls: [URL], sdRoot: URL) -> [ImportItem] {
        var items: [ImportItem] = []
        var included = Set<URL>()

        let orderedURLs = urls.map(\.standardizedFileURL).sorted {
            descriptorPriority($0) < descriptorPriority($1)
        }
        for url in orderedURLs {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                items.append(contentsOf: planFolder(url, sdRoot: sdRoot, included: &included))
            } else {
                items.append(contentsOf: planFile(url, sdRoot: sdRoot, included: &included))
            }
        }
        return items.sorted { $0.sourceURL.path.localizedStandardCompare($1.sourceURL.path) == .orderedAscending }
    }

    private func planFolder(_ folder: URL, sdRoot: URL, included: inout Set<URL>) -> [ImportItem] {
        let files = recursiveFiles(in: folder).filter { router.isLikelyROM($0) }
        guard !files.isEmpty else { return [] }
        let decision = router.routeFolder(folder, files: files)

        return files.compactMap { file in
            guard included.insert(file.standardizedFileURL).inserted else { return nil }
            let relative = relativePath(of: file, beneath: folder)
            let destination = decision.system.map {
                sdRoot.appending(path: "Roms/\($0.folderName)/\(folder.lastPathComponent)/\(relative)")
            }
            return ImportItem(
                sourceURL: file,
                system: decision.system,
                candidateSystems: decision.candidates,
                destinationURL: destination,
                status: decision.system == nil ? .needsChoice : .ready,
                detail: decision.reason,
                groupRoot: folder,
                relativePath: "\(folder.lastPathComponent)/\(relative)"
            )
        }
    }

    private func planFile(_ file: URL, sdRoot: URL, included: inout Set<URL>) -> [ImportItem] {
        let siblings = (try? fileManager.contentsOfDirectory(atPath: file.deletingLastPathComponent().path)) ?? []
        let decision = router.route(fileURL: file, siblingNames: siblings)
        var sources = [file]
        if file.pathExtension.lowercased() == "cue" {
            sources.append(contentsOf: referencedFiles(fromCue: file))
        } else if file.pathExtension.lowercased() == "m3u" {
            sources.append(contentsOf: referencedFiles(fromPlaylist: file))
        }

        let isDiscSet = sources.count > 1
        let setFolder = sanitizedDiscFolderName(file.deletingPathExtension().lastPathComponent)
        return sources.compactMap { source in
            guard included.insert(source.standardizedFileURL).inserted else { return nil }
            let relative = isDiscSet ? "\(setFolder)/\(source.lastPathComponent)" : source.lastPathComponent
            let destination = decision.system.map { sdRoot.appending(path: "Roms/\($0.folderName)/\(relative)") }
            return ImportItem(
                sourceURL: source,
                system: decision.system,
                candidateSystems: decision.candidates,
                destinationURL: destination,
                status: decision.system == nil ? .needsChoice : .ready,
                detail: source == file ? decision.reason : "Included because it is referenced by \(file.lastPathComponent)",
                groupRoot: isDiscSet ? file : nil,
                relativePath: relative
            )
        }
    }

    func applying(system: ROMSystem, to item: ImportItem, sdRoot: URL, allItems: [ImportItem]) -> [ImportItem] {
        let groupKey = item.groupRoot
        return allItems.map { existing in
            guard existing.id == item.id || (groupKey != nil && existing.groupRoot == groupKey) else { return existing }
            var updated = existing
            updated.system = system
            updated.candidateSystems = [system]
            let relative = updated.relativePath ?? updated.sourceURL.lastPathComponent
            updated.destinationURL = sdRoot.appending(path: "Roms/\(system.folderName)/\(relative)")
            updated.status = .ready
            updated.detail = "Selected \(system.displayName)"
            return updated
        }
    }

    private func recursiveFiles(in folder: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values?.isRegularFile == true && values?.isSymbolicLink != true { result.append(url) }
        }
        return result
    }

    private func referencedFiles(fromCue cue: URL) -> [URL] {
        guard let text = try? String(contentsOf: cue, encoding: .utf8) else { return [] }
        let pattern = #"(?im)^\s*FILE\s+(?:\"([^\"]+)\"|([^\s]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsrange).compactMap { match in
            let range = match.range(at: match.range(at: 1).location != NSNotFound ? 1 : 2)
            guard let swiftRange = Range(range, in: text) else { return nil }
            let candidate = cue.deletingLastPathComponent().appending(path: String(text[swiftRange]))
            return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
        }
    }

    private func referencedFiles(fromPlaylist playlist: URL) -> [URL] {
        guard let text = try? String(contentsOf: playlist, encoding: .utf8) else { return [] }
        return text.components(separatedBy: .newlines).compactMap { line in
            let path = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, !path.hasPrefix("#") else { return nil }
            let candidate = playlist.deletingLastPathComponent().appending(path: path)
            return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
        }
    }

    private func descriptorPriority(_ url: URL) -> Int {
        switch url.pathExtension.lowercased() {
        case "m3u": 0
        case "cue", "gdi": 1
        default: 2
        }
    }

    private func relativePath(of file: URL, beneath folder: URL) -> String {
        let folderPath = folder.standardizedFileURL.path.hasSuffix("/") ? folder.standardizedFileURL.path : folder.standardizedFileURL.path + "/"
        return String(file.standardizedFileURL.path.dropFirst(folderPath.count))
    }

    private func sanitizedDiscFolderName(_ name: String) -> String {
        name.replacingOccurrences(of: ":", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
