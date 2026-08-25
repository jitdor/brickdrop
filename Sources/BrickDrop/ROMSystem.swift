import Foundation

enum ROMSystem: String, CaseIterable, Codable, Identifiable, Sendable {
    case fc = "FC"
    case sfc = "SFC"
    case gb = "GB"
    case gbc = "GBC"
    case gba = "GBA"
    case n64 = "N64"
    case nds = "NDS"
    case gg = "GG"
    case md = "MD"
    case ms = "MS"
    case pce = "PCE"
    case ps = "PS"
    case dc = "DC"
    case psp = "PSP"
    case arcade = "ARCADE"
    case neogeo = "NEOGEO"

    var id: String { rawValue }
    var folderName: String { rawValue }

    var displayName: String {
        switch self {
        case .fc: "Nintendo Entertainment System (FC)"
        case .sfc: "Super Nintendo (SFC)"
        case .gb: "Game Boy"
        case .gbc: "Game Boy Color"
        case .gba: "Game Boy Advance"
        case .n64: "Nintendo 64"
        case .nds: "Nintendo DS"
        case .gg: "Game Gear"
        case .md: "Mega Drive / Genesis"
        case .ms: "Master System"
        case .pce: "PC Engine"
        case .ps: "PlayStation"
        case .dc: "Dreamcast"
        case .psp: "PSP"
        case .arcade: "Arcade"
        case .neogeo: "Neo Geo"
        }
    }

    var accent: String {
        switch self {
        case .fc, .ps: "red"
        case .sfc, .gba, .n64: "purple"
        case .gb, .gbc: "green"
        case .dc, .psp: "blue"
        default: "orange"
        }
    }
}

struct RouteDecision: Equatable, Sendable {
    let system: ROMSystem?
    let candidates: [ROMSystem]
    let reason: String

    static func resolved(_ system: ROMSystem, reason: String) -> RouteDecision {
        RouteDecision(system: system, candidates: [system], reason: reason)
    }

    static func ambiguous(_ candidates: [ROMSystem], reason: String) -> RouteDecision {
        RouteDecision(system: nil, candidates: candidates, reason: reason)
    }
}
