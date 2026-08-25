import Foundation

struct QueueMergeResult: Sendable {
    let items: [ImportItem]
    let addedCount: Int
    let upgradedCount: Int
}

enum ImportQueue {
    static func merge(existing: [ImportItem], incoming: [ImportItem]) -> QueueMergeResult {
        var merged = existing
        var indexBySource = Dictionary(uniqueKeysWithValues: existing.enumerated().map {
            ($0.element.sourceURL.standardizedFileURL, $0.offset)
        })
        var added = 0
        var upgraded = 0

        for candidate in incoming {
            let source = candidate.sourceURL.standardizedFileURL
            if let index = indexBySource[source] {
                let current = merged[index]
                guard shouldReplace(current: current, with: candidate) else { continue }
                merged[index] = copy(candidate, preservingID: current.id)
                upgraded += 1
            } else {
                indexBySource[source] = merged.count
                merged.append(candidate)
                added += 1
            }
        }

        return QueueMergeResult(
            items: merged.sorted { $0.sourceURL.path.localizedStandardCompare($1.sourceURL.path) == .orderedAscending },
            addedCount: added,
            upgradedCount: upgraded
        )
    }

    private static func shouldReplace(current: ImportItem, with candidate: ImportItem) -> Bool {
        switch current.status {
        case .copied, .skipped:
            return false
        case .failed:
            return true
        case .ready, .needsChoice, .preview:
            // A descriptor or folder discovered in a later drop carries a safer
            // grouped destination than a previously queued loose file.
            return current.groupRoot == nil && candidate.groupRoot != nil
        }
    }

    private static func copy(_ item: ImportItem, preservingID id: UUID) -> ImportItem {
        ImportItem(
            id: id,
            sourceURL: item.sourceURL,
            system: item.system,
            candidateSystems: item.candidateSystems,
            destinationURL: item.destinationURL,
            status: item.status,
            detail: item.detail,
            groupRoot: item.groupRoot,
            relativePath: item.relativePath
        )
    }
}
