import AppKit
import Foundation

enum VolumeEjectError: LocalizedError {
    case volumeNotFound
    case notRemovable(String)

    var errorDescription: String? {
        switch self {
        case .volumeNotFound:
            "Could not identify the selected SD card's mounted volume."
        case .notRemovable(let name):
            "\(name) is not reported by macOS as a removable or ejectable volume."
        }
    }
}

@MainActor
struct VolumeEjector {
    func eject(selectedRoot: URL) throws -> URL {
        let values = try selectedRoot.resourceValues(forKeys: [
            .volumeURLKey,
            .volumeIsEjectableKey,
            .volumeIsRemovableKey
        ])
        guard let volumeURL = values.volume else { throw VolumeEjectError.volumeNotFound }
        guard values.volumeIsEjectable == true || values.volumeIsRemovable == true else {
            throw VolumeEjectError.notRemovable(volumeURL.lastPathComponent)
        }
        try NSWorkspace.shared.unmountAndEjectDevice(at: volumeURL)
        return volumeURL
    }
}
