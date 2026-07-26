import EmperorCore
import XCTest

final class InterfaceSpriteCatalogTests: XCTestCase {
    func testEverySemanticIconHasFourDistinctStates() throws {
        var allIDs = Set<Int>()
        for icon in OriginalInterfaceIcon.allCases {
            let ids = try OriginalInterfaceIconState.allCases.map {
                try XCTUnwrap(OriginalInterfaceSpriteCatalog.imageID(for: icon, state: $0))
            }
            XCTAssertEqual(Set(ids).count, 4, "\(icon) should have four states")
            XCTAssertTrue(allIDs.isDisjoint(with: ids), "\(icon) overlaps another family")
            allIDs.formUnion(ids)
        }
        XCTAssertEqual(allIDs, OriginalInterfaceSpriteCatalog.requiredImageIDs)
    }

    func testInstalledSemanticInterfaceIconsDecode() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let baseName = OriginalInterfaceSpriteCatalog.archiveBaseName
        let archive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("\(baseName).sg3")
        )
        let pixels = try Data(
            contentsOf: source.dataDirectory.appendingPathComponent("\(baseName).555"),
            options: [.mappedIfSafe]
        )

        let requiredImageIDs = OriginalInterfaceSpriteCatalog.requiredImageIDs
            .union(OriginalInterfaceUtilitySpriteCatalog.requiredImageIDs)
        for imageID in requiredImageIDs.sorted() {
            let record = archive.images[imageID]
            XCTAssertFalse(record.isExternal, "interface image #\(imageID) is external")
            let sprite = try SpriteDecoder.decode(image: record, pixelData: pixels)
            XCTAssertGreaterThan(sprite.width, 0)
            XCTAssertGreaterThan(sprite.height, 0)
            XCTAssertNotNil(sprite.makeCGImage())
        }
    }

    func testClearUsesOriginalShovelAndDemolishAvoidsUndoArtwork() throws {
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .clearLand),
            1_283
        )
        XCTAssertNil(OriginalInterfaceUtilitySpriteCatalog.imageID(for: .demolish))
        XCTAssertNil(OriginalInterfaceUtilitySpriteCatalog.imageID(for: .road))
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.roadTerrainLocalID,
            782
        )
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.defaultRoadLocalID(forConnectionMask: 0b0101),
            782
        )
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.defaultRoadLocalID(forConnectionMask: 0b1010),
            783
        )
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.defaultRoadLocalIDByConnectionMask.count,
            16
        )
        XCTAssertTrue(
            OriginalInterfaceUtilitySpriteCatalog.roadTerrainLocalIDs.contains(782)
        )
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.requiredImageIDs,
            Set([1_283])
        )
    }
}
