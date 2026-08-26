import Foundation

struct MountedVolume: Identifiable, Hashable {
    let url: URL
    let name: String
    let formatDescription: String
    let totalCapacity: Int64?

    var id: URL { url.standardizedFileURL }

    var capacityDescription: String {
        totalCapacity.map(StorageCapacityFormatter.string) ?? "Capacity unavailable"
    }
}

struct MountedVolumeProvider {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func removableVolumes() -> [MountedVolume] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeTotalCapacityKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey
        ]
        let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  Self.shouldInclude(
                    isInternal: values.volumeIsInternal,
                    isRemovable: values.volumeIsRemovable,
                    isEjectable: values.volumeIsEjectable
                  ) else {
                return nil
            }

            return MountedVolume(
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                formatDescription: values.volumeLocalizedFormatDescription ?? "Unknown format",
                totalCapacity: values.volumeTotalCapacity.map(Int64.init)
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func shouldInclude(isInternal: Bool?, isRemovable: Bool?, isEjectable: Bool?) -> Bool {
        isInternal != true && (isRemovable == true || isEjectable == true)
    }
}

enum StorageCapacityFormatter {
    static func string(_ byteCount: Int64) -> String {
        guard byteCount > 0 else { return "Capacity unavailable" }

        let bytes = Double(byteCount)
        if bytes >= 1_000_000_000_000 {
            return formatted(bytes / 1_000_000_000_000, unit: "TB", decimalPlaces: 1)
        }
        if bytes >= 1_000_000_000 {
            return formatted(bytes / 1_000_000_000, unit: "GB", decimalPlaces: 0)
        }
        if bytes >= 1_000_000 {
            return formatted(bytes / 1_000_000, unit: "MB", decimalPlaces: 0)
        }
        return "\(byteCount) bytes"
    }

    private static func formatted(_ value: Double, unit: String, decimalPlaces: Int) -> String {
        let scale = pow(10.0, Double(decimalPlaces))
        let rounded = (value * scale).rounded() / scale
        let number = rounded.formatted(
            .number
                .locale(Locale.current)
                .grouping(.automatic)
                .precision(.fractionLength(0...decimalPlaces))
        )
        return "\(number) \(unit)"
    }
}
