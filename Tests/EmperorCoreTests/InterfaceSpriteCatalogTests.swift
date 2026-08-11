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
            .union(OriginalConstructionButtonSpriteCatalog.requiredImageIDs)
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

    func testClassicCategoryRailUsesOriginalOrderAndFourStateFamilies() throws {
        let expectedBases: [(OriginalInterfaceIcon, Int)] = [
            (.residential, 1_323),
            (.agriculture, 1_327),
            (.industry, 1_331),
            (.commerce, 1_335),
            // Historical catalog names: this is the well/safety artwork.
            (.entertainment, 1_339),
            (.government, 1_343),
            // Historical catalog names: this is the fan/entertainment artwork.
            (.culture, 1_347),
            (.religion, 1_351),
            (.military, 1_355),
            (.aesthetics, 1_359),
            (.infrastructure, 1_319),
        ]
        for (icon, base) in expectedBases {
            let ids = try OriginalInterfaceIconState.allCases.map {
                try XCTUnwrap(OriginalInterfaceSpriteCatalog.imageID(for: icon, state: $0))
            }
            XCTAssertEqual(ids, [base, base + 1, base + 2, base + 3])
        }
        XCTAssertEqual(
            OriginalInterfaceSpriteCatalog.imageID(for: .residential, state: .selected),
            1_325
        )
    }

    func testClassicUtilityStripUsesVerifiedOriginalFamilies() throws {
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .road),
            1_275
        )
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .inspect),
            1_279
        )
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .clearLand),
            1_283
        )
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .demolish),
            1_287
        )
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
            Set([1_275, 1_279, 1_283, 1_287, 1_291])
        )
    }

    func testConstructionButtonsUseInferredThreeStateFamilies() throws {
        XCTAssertEqual(
            try OriginalConstructionButtonState.allCases.map {
                try XCTUnwrap(
                    OriginalConstructionButtonSpriteCatalog.imageID(
                        forBuildingID: 2,
                        state: $0
                    )
                )
            },
            [1_491, 1_492, 1_493]
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.imageID(
                forBuildingID: 72,
                state: .selected
            ),
            1_553
        )
        let additionalInferredBases: [Int: Int] = [
            33: 1_506,
            54: 1_528,
            66: 1_531,
            53: 1_534,
            47: 1_537,
            65: 1_540,
            67: 1_543,
            59: 1_546,
            60: 1_546,
            203: 1_575,
            211: 1_584,
            212: 1_587,
            213: 1_590,
            119: 1_638,
            122: 1_644,
            233: 1_647,
            52: 1_650,
            235: 1_650,
            236: 1_650,
            93: 1_653,
        ]
        for (buildingID, base) in additionalInferredBases {
            XCTAssertEqual(
                OriginalConstructionButtonSpriteCatalog.imageID(
                    forBuildingID: buildingID,
                    state: .normal
                ),
                base
            )
        }
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.cropImageID(
                isRice: true,
                isOrchard: false,
                state: .hover
            ),
            1_501
        )
        XCTAssertNil(
            OriginalConstructionButtonSpriteCatalog.imageID(forBuildingID: 999)
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.evidence(forBuildingID: 54),
            .inferredFromSheet
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.evidence(forBuildingID: 999),
            .unknown
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.mappedBuildingIDs.count,
            53
        )
        XCTAssertTrue(
            OriginalConstructionButtonSpriteCatalog.mappedBuildingIDs.allSatisfy {
                OriginalConstructionButtonSpriteCatalog.evidence(forBuildingID: $0)
                    == .inferredFromSheet
            }
        )
        XCTAssertFalse(OriginalConstructionButtonSpriteCatalog.requiredImageIDs.isEmpty)
    }
}
