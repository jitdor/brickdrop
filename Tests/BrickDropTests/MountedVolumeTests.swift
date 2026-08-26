import XCTest
@testable import BrickDrop

final class MountedVolumeTests: XCTestCase {
    func testInternalVolumesAreExcluded() {
        XCTAssertFalse(MountedVolumeProvider.shouldInclude(
            isInternal: true,
            isRemovable: true,
            isEjectable: true
        ))
    }

    func testRemovableAndEjectableExternalVolumesAreIncluded() {
        XCTAssertTrue(MountedVolumeProvider.shouldInclude(
            isInternal: false,
            isRemovable: true,
            isEjectable: false
        ))
        XCTAssertTrue(MountedVolumeProvider.shouldInclude(
            isInternal: false,
            isRemovable: false,
            isEjectable: true
        ))
    }

    func testExternalButNeitherRemovableNorEjectableVolumeIsExcluded() {
        XCTAssertFalse(MountedVolumeProvider.shouldInclude(
            isInternal: false,
            isRemovable: false,
            isEjectable: false
        ))
    }

    func testCapacityUsesDecimalGigabytesRoundedToNominalSize() {
        XCTAssertEqual(StorageCapacityFormatter.string(127_865_454_592), "128 GB")
    }

    func testCapacityHandlesSmallMegabyteAndTwoTerabyteVolumes() {
        XCTAssertEqual(StorageCapacityFormatter.string(63_963_136), "64 MB")
        XCTAssertEqual(StorageCapacityFormatter.string(1_999_000_000_000), "2 TB")
    }

    func testCapacityUsesFriendlyTerabytes() {
        XCTAssertEqual(StorageCapacityFormatter.string(1_000_204_886_016), "1 TB")
        XCTAssertEqual(StorageCapacityFormatter.string(1_500_000_000_000), "1.5 TB")
    }
}
