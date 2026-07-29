import EmperorCore
import XCTest

final class InterfaceSpriteCatalogTests: XCTestCase {
    func testEverySemanticIconHasFourDistinctStates() throws {
        var allIDs = Set<Int>()
        for icon in OriginalInterfaceIcon.allCases where icon != .messages {
            let ids = try OriginalInterfaceIconState.allCases.map {
                try XCTUnwrap(OriginalInterfaceSpriteCatalog.imageID(for: icon, state: $0))
            }
            XCTAssertEqual(Set(ids).count, 4, "\(icon) should have four states")
            XCTAssertTrue(allIDs.isDisjoint(with: ids), "\(icon) overlaps another family")
            allIDs.formUnion(ids)
        }
        XCTAssertEqual(allIDs, OriginalInterfaceSpriteCatalog.requiredImageIDs)
        XCTAssertNil(
            OriginalInterfaceSpriteCatalog.imageID(for: .messages),
            "1275 is cabbage/cargo artwork, not the original message button"
        )
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
            .union(OriginalInterfaceChromeSpriteCatalog.requiredImageIDs)
        for imageID in requiredImageIDs.sorted() {
            let record = archive.images[imageID]
            XCTAssertFalse(record.isExternal, "interface image #\(imageID) is external")
            let sprite = try SpriteDecoder.decode(image: record, pixelData: pixels)
            XCTAssertGreaterThan(sprite.width, 0)
            XCTAssertGreaterThan(sprite.height, 0)
            XCTAssertNotNil(sprite.makeCGImage())
        }
    }

    func testClassicCityChromeUsesVerifiedOriginalArtwork() {
        XCTAssertEqual(
            OriginalInterfaceChromeSpriteCatalog.cityHUDBackgroundImageID,
            1_221
        )
        XCTAssertEqual(
            OriginalInterfaceChromeSpriteCatalog.cityPanelBackgroundImageID,
            1_223
        )
        XCTAssertEqual(OriginalInterfaceChromeSpriteCatalog.treasuryImageID, 652)
        XCTAssertNil(
            OriginalInterfaceChromeSpriteCatalog.laborImageID,
            "#311 includes terrain and must not stand in for the HUD labor icon"
        )
        XCTAssertEqual(
            OriginalInterfaceChromeSpriteCatalog.zodiacImageID(for: "牛"),
            1_372
        )
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
