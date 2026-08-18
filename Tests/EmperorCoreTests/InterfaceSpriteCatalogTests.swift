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
        // 修路 / 路障 / 清除 / 撤销 / 查看最后事件 (EmperorText 3694–3698);
        // #1279 is the roadblock sign family, not an inspection hand.
        XCTAssertEqual(
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .roadblock),
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
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .help),
            1_291
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

    func testConstructionButtonsUseExecutableRecoveredThreeStateFamilies() throws {
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
        let recoveredBases: [Int: Int] = [
            33: 1_512,
            53: 1_533,
            54: 1_542,
            66: 1_539,
            59: 1_536,
            60: 1_536,
            203: 1_503,
            211: 1_584,
            212: 1_587,
            213: 1_590,
            119: 1_632,
            122: 1_632,
            233: 1_644,
            52: 1_647,
            235: 1_647,
            236: 1_647,
            93: 1_653,
        ]
        for (buildingID, base) in recoveredBases {
            XCTAssertEqual(
                OriginalConstructionButtonSpriteCatalog.imageID(
                    forBuildingID: buildingID,
                    state: .normal
                ),
                base
            )
        }
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.imageID(forBuildingID: 47),
            1_527
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.imageID(forBuildingID: 65),
            1_539
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.cropImageID(
                isRice: true,
                isOrchard: false,
                state: .hover
            ),
            1_501
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.cropImageID(
                for: .hemp,
                state: .selected
            ),
            1_502
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.cropImageID(
                for: .tea,
                state: .normal
            ),
            1_509
        )
        XCTAssertNil(
            OriginalConstructionButtonSpriteCatalog.imageID(forBuildingID: 999)
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.evidence(forBuildingID: 54),
            .confirmedDirectFromExecutable
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.evidence(forBuildingID: 59),
            .confirmedSubmenuFamilyFromExecutable
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.evidence(forBuildingID: 999),
            .unknown
        )
        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.mappedBuildingIDs.count,
            130
        )
        XCTAssertTrue(
            OriginalConstructionButtonSpriteCatalog.mappedBuildingIDs.allSatisfy {
                OriginalConstructionButtonSpriteCatalog.evidence(forBuildingID: $0)
                    != .unknown
            }
        )
        XCTAssertFalse(OriginalConstructionButtonSpriteCatalog.requiredImageIDs.isEmpty)
    }

    func testConstructionPanelUsesExecutableRecoveredFixedSlots() throws {
        for category in OriginalConstructionPanelCategory.allCases {
            XCTAssertEqual(
                OriginalConstructionPanelCatalog.slots(for: category).count,
                6
            )
        }

        let residential = OriginalConstructionPanelCatalog.slots(for: .residential)
        XCTAssertEqual(residential.compactMap(\.self).map(\.selectorID), [2, 11])
        XCTAssertEqual(residential.compactMap(\.self).map(\.baseImageID), [1_491, 1_494])

        let agriculture = OriginalConstructionPanelCatalog.slots(for: .agriculture)
        XCTAssertEqual(
            agriculture.compactMap(\.self).map(\.selectorID),
            [24, 200, 201, 29, 25, 30]
        )
        XCTAssertEqual(
            try XCTUnwrap(agriculture[1]).memberBuildingIDs,
            [199, 198, 196, 197, 195, 194]
        )
        XCTAssertEqual(try XCTUnwrap(agriculture[5]).baseImageID, 1_512)

        let commerce = OriginalConstructionPanelCatalog.slots(for: .commerce)
        XCTAssertEqual(try XCTUnwrap(commerce[4]).selectorID, 88)
        XCTAssertEqual(try XCTUnwrap(commerce[4]).kind, .resourceSubmenu)
        XCTAssertEqual(try XCTUnwrap(commerce[5]).selectorID, 87)
        XCTAssertEqual(try XCTUnwrap(commerce[5]).baseImageID, 1_548)

        let monuments = OriginalConstructionPanelCatalog.slots(for: .monuments)
        XCTAssertEqual(monuments.compactMap(\.self).count, 6)
        XCTAssertEqual(try XCTUnwrap(monuments[0]).selectorID, 233)
        XCTAssertEqual(try XCTUnwrap(monuments[1]).selectorID, 234)
        for index in 2..<6 {
            let slot = try XCTUnwrap(monuments[index])
            XCTAssertEqual(slot.kind, .dynamicMonument)
            XCTAssertEqual(slot.familyIndex, 55)
            XCTAssertEqual(slot.baseImageID, 1_653)
            XCTAssertTrue(slot.memberBuildingIDs.isEmpty)
        }

        XCTAssertEqual(
            OriginalConstructionButtonSpriteCatalog.imageID(
                forFamilyIndex: 20,
                state: .selected
            ),
            1_550
        )
        XCTAssertEqual(
            OriginalConstructionPanelCatalog.dynamicMonumentBuildingIDs,
            Array(76...84) + [92, 93] + Array(253...268)
        )
    }

    func testOnlyExecutableFlaggedSubmenusCollapseASingleAvailableMember() {
        XCTAssertEqual(
            OriginalConstructionPanelCatalog.singletonCollapsingSelectorIDs,
            Set([63, 204, 205, 222])
        )
        for selectorID in [24, 34, 50, 87, 88, 134, 140, 200, 201, 206, 229, 230, 234, 240, 241, 242] {
            XCTAssertFalse(
                OriginalConstructionPanelCatalog.collapsesSingleAvailableMember(
                    selectorID: selectorID
                )
            )
        }
    }

    func testDynamicMonumentSlotsPreserveExecutableOrderEquivalenceAndHoles() throws {
        XCTAssertEqual(
            OriginalConstructionPanelCatalog.runtimeDynamicMonumentBuildingIDs(
                monumentTaskBuildingIDs: [77],
                existingBuildingIDs: []
            ),
            [77, nil, nil, nil]
        )
        XCTAssertEqual(
            OriginalConstructionPanelCatalog.runtimeDynamicMonumentBuildingIDs(
                monumentTaskBuildingIDs: [85],
                existingBuildingIDs: [254]
            ),
            [253, nil, 255, 256]
        )

        let greatWall = OriginalConstructionPanelCatalog.runtimeSlots(
            for: .monuments,
            monumentTaskBuildingIDs: [85],
            existingMonumentBuildingIDs: [254]
        )
        XCTAssertEqual(greatWall.compactMap(\.self).count, 5)
        XCTAssertEqual(try XCTUnwrap(greatWall[0]).selectorID, 233)
        XCTAssertEqual(try XCTUnwrap(greatWall[1]).selectorID, 234)
        XCTAssertEqual(try XCTUnwrap(greatWall[2]).selectorID, 253)
        XCTAssertNil(greatWall[3])
        XCTAssertEqual(try XCTUnwrap(greatWall[4]).selectorID, 255)
        XCTAssertEqual(try XCTUnwrap(greatWall[5]).selectorID, 256)

        let clockTower = OriginalConstructionPanelCatalog.runtimeSlots(
            for: .monuments,
            monumentTaskBuildingIDs: [92],
            existingMonumentBuildingIDs: []
        )
        XCTAssertNil(clockTower[0])
        XCTAssertEqual(try XCTUnwrap(clockTower[1]).selectorID, 234)
        XCTAssertEqual(try XCTUnwrap(clockTower[2]).selectorID, 92)

        XCTAssertEqual(
            OriginalConstructionPanelCatalog.runtimeSlots(
                for: .monuments,
                monumentTaskBuildingIDs: [],
                existingMonumentBuildingIDs: []
            ),
            Array(repeating: nil, count: 6)
        )
    }
}
