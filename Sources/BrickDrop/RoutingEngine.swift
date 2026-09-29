import Foundation

struct RoutingEngine: Sendable {
    private let directExtensions: [String: ROMSystem] = [
        "nes": .fc, "fds": .fc,
        "sfc": .sfc, "smc": .sfc,
        "gb": .gb,
        "gbc": .gbc,
        "gba": .gba,
        "n64": .n64, "z64": .n64, "v64": .n64,
        "nds": .nds,
        "gg": .gg,
        "md": .md, "gen": .md, "smd": .md,
        "sms": .ms,
        "pce": .pce,
        "pbp": .ps,
        "gdi": .dc, "cdi": .dc,
        "cso": .psp,
        "neo": .neogeo
    ]

    private let aliases: [ROMSystem: [String]] = [
        .fc: ["fc", "nes", "famicom"],
        .sfc: ["sfc", "snes", "superfamicom", "super nintendo"],
        .gb: ["gameboy", "game boy", "dmg"],
        .gbc: ["gbc", "gameboycolor", "game boy color"],
        .gba: ["gba", "gameboyadvance", "game boy advance"],
        .n64: ["n64", "nintendo64", "nintendo 64"],
        .nds: ["nds", "nintendo ds"],
        .gg: ["gamegear", "game gear"],
        .md: ["megadrive", "mega drive", "genesis"],
        .ms: ["mastersystem", "master system"],
        .pce: ["pcengine", "pc engine", "turbografx", "tg16"],
        .ps: ["ps1", "psx", "playstation", "psone"],
        .dc: ["dreamcast", "dc"],
        .psp: ["psp"],
        .arcade: ["arcade", "mame", "fbneo", "fba"],
        .neogeo: ["neogeo", "neo geo"]
    ]

    func route(fileURL: URL, sourceContext: String? = nil, siblingNames: [String] = []) -> RouteDecision {
        let ext = fileURL.pathExtension.lowercased()
        let context = normalizedContext(fileURL: fileURL, sourceContext: sourceContext)

        if let direct = directExtensions[ext] {
            return .resolved(direct, reason: ".\(ext) files map to \(direct.folderName)")
        }

        if ext == "cue" {
            return .resolved(.ps, reason: "CUE disc sets map to PlayStation by default")
        }

        if ext == "bin" {
            let stem = fileURL.deletingPathExtension().lastPathComponent.lowercased()
            let hasCue = siblingNames.contains { name in
                let sibling = URL(fileURLWithPath: name)
                guard sibling.pathExtension.lowercased() == "cue" else { return false }
                let cueStem = sibling.deletingPathExtension().lastPathComponent.lowercased()
                // Multi-track/disc dumps name their files "Game (Track 1).bin" or "Game (Disc 1).bin"
                // next to a single "Game.cue".
                return stem == cueStem || stem.hasPrefix(cueStem + " (track") || stem.hasPrefix(cueStem + " (disc")
            }
            if hasCue { return .resolved(.ps, reason: "BIN is part of a CUE disc set") }
            if let heuristic = systemFromContext(context) {
                return .resolved(heuristic, reason: "Detected \(heuristic.displayName) from its name or source folder")
            }
            return .ambiguous([.ps, .md, .pce], reason: "BIN is used by several systems")
        }

        if ext == "chd" {
            if let heuristic = systemFromContext(context, allowed: [.dc, .ps, .pce]) {
                return .resolved(heuristic, reason: "Detected \(heuristic.displayName) from its name or source folder")
            }
            return .ambiguous([.ps, .dc, .pce], reason: "CHD is used by several disc-based systems")
        }

        if ext == "iso" || ext == "img" || ext == "m3u" {
            if let heuristic = systemFromContext(context, allowed: [.ps, .dc, .psp, .pce]) {
                return .resolved(heuristic, reason: "Detected \(heuristic.displayName) from its name or source folder")
            }
            let candidates: [ROMSystem] = ext == "iso" ? [.psp, .ps, .dc] : [.ps, .dc, .pce]
            return .ambiguous(candidates, reason: ".\(ext.uppercased()) is used by several disc-based systems")
        }

        if ext == "zip" || ext == "7z" {
            if let heuristic = systemFromContext(context) {
                return .resolved(heuristic, reason: "Detected \(heuristic.displayName) from its name or source folder")
            }
            return .ambiguous([.arcade, .neogeo, .fc, .sfc, .md], reason: "Archives can contain ROMs for many systems")
        }

        if let heuristic = systemFromContext(context) {
            return .resolved(heuristic, reason: "Detected \(heuristic.displayName) from its name or source folder")
        }

        return RouteDecision(system: nil, candidates: ROMSystem.allCases, reason: "Unknown or ambiguous file type")
    }

    func routeFolder(_ folderURL: URL, files: [URL]) -> RouteDecision {
        let names = files.map(\.lastPathComponent)
        let context = normalized(folderURL.path)
        if let heuristic = systemFromContext(context) {
            return .resolved(heuristic, reason: "Detected \(heuristic.displayName) from the folder name")
        }

        let decisions = files
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .map { route(fileURL: $0, sourceContext: folderURL.path, siblingNames: names) }
        let systems = Set(decisions.compactMap(\.system))
        if systems.count == 1, let system = systems.first {
            return .resolved(system, reason: "Files in this folder consistently map to \(system.displayName)")
        }
        if files.contains(where: { $0.pathExtension.lowercased() == "gdi" || $0.pathExtension.lowercased() == "cdi" }) {
            return .resolved(.dc, reason: "The folder contains a Dreamcast disc descriptor")
        }
        if files.contains(where: { $0.pathExtension.lowercased() == "cue" }) {
            return .resolved(.ps, reason: "The folder contains a PlayStation CUE disc set")
        }
        let candidates = Array(systems).sorted { $0.rawValue < $1.rawValue }
        return .ambiguous(candidates.isEmpty ? ROMSystem.allCases : candidates, reason: "This folder contains mixed or ambiguous ROM types")
    }

    func isLikelyROM(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return directExtensions[ext] != nil || ["cue", "bin", "chd", "iso", "img", "m3u", "zip", "7z"].contains(ext)
    }

    private func normalizedContext(fileURL: URL, sourceContext: String?) -> String {
        normalized([sourceContext, fileURL.deletingLastPathComponent().path, fileURL.lastPathComponent]
            .compactMap { $0 }.joined(separator: " "))
    }

    /// Lowercases and turns every non-alphanumeric run into a single space, padded on both ends,
    /// so aliases can be matched as whole words with a plain substring search.
    private func normalized(_ value: String) -> String {
        var result = " "
        var lastWasSpace = true
        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                result.append(" ")
                lastWasSpace = true
            }
        }
        return lastWasSpace ? result : result + " "
    }

    private func systemFromContext(_ context: String, allowed: Set<ROMSystem>? = nil) -> ROMSystem? {
        // Longest alias first so "game boy color" beats "game boy"; whole-word matching keeps
        // short aliases like "nes" or "dc" from firing inside longer words.
        for entry in orderedAliases where allowed?.contains(entry.system) ?? true {
            if context.contains(" \(entry.alias) ") { return entry.system }
        }
        return nil
    }

    private var orderedAliases: [(alias: String, system: ROMSystem)] {
        ROMSystem.allCases
            .flatMap { system in aliases[system, default: []].map { (alias: $0, system: system) } }
            .sorted { $0.alias.count > $1.alias.count }
    }
}
