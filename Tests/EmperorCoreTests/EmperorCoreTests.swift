@testable import EmperorCore
import XCTest

final class EmperorCoreTests: XCTestCase {
    func testBinaryReaderUsesLittleEndianWithoutAlignmentAssumptions() throws {
        var reader = BinaryReader(data: Data([0xAA, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12]))
        XCTAssertEqual(try reader.readUInt8(), 0xAA)
        XCTAssertEqual(try reader.readUInt16LE(), 0x1234)
        XCTAssertEqual(try reader.readUInt32LE(), 0x12345678)
    }

    func testRGB555TransparencyAndWhite() {
        XCTAssertEqual(RGB555.decode(0xF81F).alpha, 0)
        XCTAssertEqual(RGB555.decode(0xD830).alpha, 255)
        let white = RGB555.decode(0x7FFF)
        XCTAssertEqual(white.red, 255)
        XCTAssertEqual(white.green, 255)
        XCTAssertEqual(white.blue, 255)
        XCTAssertEqual(white.alpha, 255)
    }

    func testFigureShadowMarkerRemainsTransparentUntilShadowCompositorIsRecovered() {
        let sprite = DecodedSprite(
            width: 2,
            height: 1,
            rgba: Data([255, 0, 0, 255, 255, 0, 8, 255])
        ).correctingFigureShadow()
        XCTAssertEqual(Array(sprite.rgba.prefix(4)), [0, 0, 0, 0])
        XCTAssertEqual(Array(sprite.rgba.suffix(4)), [255, 0, 8, 255])
    }

    func testDecodedSpriteFlipsHorizontally() {
        let sprite = DecodedSprite(
            width: 2,
            height: 1,
            rgba: Data([1, 2, 3, 255, 4, 5, 6, 255])
        ).flippedHorizontally()
        XCTAssertEqual(Array(sprite.rgba), [4, 5, 6, 255, 1, 2, 3, 255])
    }

    func testVegetationCanBeClearedWithoutLosingUnderlyingTerrain() throws {
        var terrain = try DeterministicTerrainState(
            width: 2,
            height: 1,
            terrainRawValues: [
                TerrainFlags.tree.rawValue | TerrainFlags.fertile.rawValue,
                TerrainFlags.rock.rawValue,
            ]
        )
        let tree = GridPoint(x: 0, y: 0)
        let rock = GridPoint(x: 1, y: 0)
        XCTAssertTrue(terrain.canClearVegetation(at: tree))
        XCTAssertTrue(terrain.clearVegetation(at: tree))
        XCTAssertFalse(terrain.terrain(at: tree)?.contains(.tree) == true)
        XCTAssertTrue(terrain.terrain(at: tree)?.contains(.fertile) == true)
        XCTAssertFalse(terrain.canClearVegetation(at: rock))
        XCTAssertFalse(terrain.clearVegetation(at: rock))
    }

    func testOriginalFoodQualityUsesFoodTypesSaltAndSpices() {
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [:]), .none)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [5: 100]), .bland)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [5: 100, 8: 100]), .plain)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [2: 100, 4: 100]), .plain)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [2: 100, 4: 100, 8: 100]), .appetizing)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [2: 100, 4: 100, 8: 100, 9: 100]), .tasty)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [1: 100, 2: 100, 4: 100, 8: 100, 9: 100]), .delicious)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [1: 100, 2: 100, 3: 100, 4: 100]), .tasty)
        XCTAssertEqual(OriginalFoodCatalog.quality(in: [1: 100, 2: 100, 3: 100, 4: 100, 9: 100]), .delicious)
    }

    func testRecoveredMillFoodRecipeSelectorPreservesThresholdAndCartCap() {
        // `0x555330` compares each availability with the request divided by
        // three and keeps the highest type count above that threshold.
        let high = OriginalMillFoodRecipeSelector.select(
            availabilityByType: [0, 250, 301, 900],
            maxTypeCount: 3,
            requestedAmount: 1_000
        )
        XCTAssertEqual(high?.typeCount, 3)
        XCTAssertEqual(high?.selectedAvailability, 900)
        XCTAssertEqual(high?.amount, 600)

        // If no type clears the threshold, the first non-zero availability
        // remains the fallback even when later types have more stock.
        let fallback = OriginalMillFoodRecipeSelector.select(
            availabilityByType: [0, 50, 100, 200],
            maxTypeCount: 3,
            requestedAmount: 1_000
        )
        XCTAssertEqual(fallback?.typeCount, 1)
        XCTAssertEqual(fallback?.selectedAvailability, 50)
        XCTAssertEqual(fallback?.amount, 50)

        // The divisor is fixed at three; it is not derived from the market's
        // type-count cap (a max of five must still use 1,000 / 3 = 333).
        let fixedDivisor = OriginalMillFoodRecipeSelector.select(
            availabilityByType: [0, 250, 301, 320, 0, 0],
            maxTypeCount: 5,
            requestedAmount: 1_000
        )
        XCTAssertEqual(fixedDivisor?.typeCount, 1)
        XCTAssertEqual(fixedDivisor?.selectedAvailability, 250)
        XCTAssertEqual(fixedDivisor?.amount, 250)

        // The selector itself has no positive-request guard. With zero
        // request it still returns the selected type; the downstream bundle
        // writer is the component that ignores the resulting zero amount.
        let zeroRequest = OriginalMillFoodRecipeSelector.select(
            availabilityByType: [0, 10, 20],
            maxTypeCount: 2,
            requestedAmount: 0
        )
        XCTAssertEqual(zeroRequest?.typeCount, 2)
        XCTAssertEqual(zeroRequest?.selectedAvailability, 20)
        XCTAssertEqual(zeroRequest?.amount, 0)
    }

    func testRecoveredMillFoodBundleComposerRoundsCapsAndScansEligibleIDs() {
        let bundle = OriginalMillFoodBundleComposer.compose(
            inventoryByCommodityID: [1: 400, 2: 300, 3: 200, 8: 10, 9: 10],
            typeCount: 3,
            requestedAmount: 1_000
        )
        XCTAssertEqual(bundle?.typeCount, 3)
        XCTAssertEqual(bundle?.perCommodityAmount, 200)
        XCTAssertEqual(bundle?.commodityIDs, [1, 2, 3])
        XCTAssertEqual(bundle?.amountByCommodityID, [1: 200, 2: 200, 3: 200])
        XCTAssertEqual(bundle?.totalAmount, 600)

        // The source admits IDs 1...7 only (8 and 9 are rejected by
        // FUN_00555F70), and availability equal to the rounded amount passes.
        let ascending = OriginalMillFoodBundleComposer.compose(
            inventoryByCommodityID: [1: 0, 2: 100, 3: 100, 8: 100, 9: 100],
            typeCount: 2,
            requestedAmount: 200
        )
        XCTAssertEqual(ascending?.commodityIDs, [2, 3])
        XCTAssertNil(OriginalMillFoodBundleComposer.compose(
            inventoryByCommodityID: [1: 100, 8: 100, 9: 100],
            typeCount: 2,
            requestedAmount: 200
        ))
    }

    func testRecoveredMillFoodBundleComposerPreservesZeroRoundedAmount() {
        // A positive request below one 100-unit bucket rounds to zero.  The
        // original writer still accepts the first eligible ID and returns a
        // zero total; the caller's upstream positive-amount guard is separate.
        let bundle = OriginalMillFoodBundleComposer.compose(
            inventoryByCommodityID: [:],
            typeCount: 1,
            requestedAmount: 50
        )
        XCTAssertEqual(bundle?.commodityIDs, [1])
        XCTAssertEqual(bundle?.perCommodityAmount, 0)
        XCTAssertEqual(bundle?.totalAmount, 0)
    }

    func testOriginalAgriculturalCalendarMatchesManual() {
        let expectedGrowing: [AgriculturalCrop: Set<Int>] = [
            .soybeans: [5, 6, 7, 8],
            .cabbage: [8, 9, 10, 11],
            .millet: [7, 8, 9, 10],
            .rice: [6, 7, 8, 9],
            .wheat: [3, 4, 5, 6],
            .hemp: [4, 5, 6, 7, 8],
            .tea: [3, 4, 6, 7, 9, 10],
            .mulberry: [4, 5, 7, 8],
            .lacquer: [2, 3, 4, 5, 6]
        ]
        let expectedHarvests: [AgriculturalCrop: Set<Int>] = [
            .soybeans: [9], .cabbage: [12], .millet: [11], .rice: [10],
            .wheat: [7], .hemp: [9], .tea: [5, 8, 11],
            .mulberry: [6, 9], .lacquer: [7, 8]
        ]

        XCTAssertEqual(Set(expectedGrowing.keys), Set(AgriculturalCrop.allCases))
        for crop in AgriculturalCrop.allCases {
            XCTAssertEqual(crop.growingMonths, expectedGrowing[crop], "wrong growing months for \(crop)")
            XCTAssertEqual(crop.harvestMonths, expectedHarvests[crop], "wrong harvest months for \(crop)")
            XCTAssertTrue(crop.growingMonths.isDisjoint(with: crop.harvestMonths))
        }
    }

    func testDeterministicGridPathfinder() {
        let blocked = Set([GridPoint(x: 1, y: 0), GridPoint(x: 1, y: 1)])
        let path = GridPathfinder.shortestPath(
            width: 4,
            height: 3,
            from: GridPoint(x: 0, y: 0),
            to: GridPoint(x: 3, y: 0),
            isPassable: { !blocked.contains($0) }
        )
        XCTAssertEqual(path, [
            GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 0, y: 2),
            GridPoint(x: 1, y: 2), GridPoint(x: 2, y: 2), GridPoint(x: 2, y: 1),
            GridPoint(x: 2, y: 0), GridPoint(x: 3, y: 0)
        ])
    }

    func testIsometricViewportProjectionRoundTripsEveryTileCenter() {
        let projection = IsometricViewportProjection(
            startX: 17,
            startY: 23,
            tileWidth: 48,
            tileHeight: 24,
            originX: 420,
            originY: 52
        )
        for y in 23..<55 {
            for x in 17..<49 {
                let mapPoint = GridPoint(x: x, y: y)
                let screenPoint = projection.screenPoint(for: mapPoint)
                XCTAssertEqual(projection.mapPoint(for: screenPoint), mapPoint)
            }
        }
        XCTAssertEqual(
            projection.mapPoint(for: IsometricScreenPoint(x: 420 + 6, y: 52 + 3)),
            GridPoint(x: 17, y: 23)
        )
    }

    func testEdgeScrollConvertsScreenEdgesToIsometricMapAxes() {
        let right = IsometricEdgeScrollPolicy.mapDelta(
            for: IsometricScreenPoint(x: 1, y: 0),
            elapsed: 1,
            tileWidth: 80,
            tileHeight: 40
        )
        XCTAssertGreaterThan(right.x, 0)
        XCTAssertLessThan(right.y, 0)

        let down = IsometricEdgeScrollPolicy.mapDelta(
            for: IsometricScreenPoint(x: 0, y: 1),
            elapsed: 1,
            tileWidth: 80,
            tileHeight: 40
        )
        XCTAssertGreaterThan(down.x, 0)
        XCTAssertGreaterThan(down.y, 0)
    }

    func testCornerEdgeScrollKeepsTheSameScreenSpeed() {
        let straight = IsometricEdgeScrollPolicy.mapDelta(
            for: IsometricScreenPoint(x: 1, y: 0),
            elapsed: 0.5,
            tileWidth: 80,
            tileHeight: 40
        )
        let corner = IsometricEdgeScrollPolicy.mapDelta(
            for: IsometricScreenPoint(x: 1, y: 1),
            elapsed: 0.5,
            tileWidth: 80,
            tileHeight: 40
        )

        func projectedLength(_ delta: IsometricScreenPoint) -> Double {
            let x = (delta.x - delta.y) * 80 * 0.5
            let y = (delta.x + delta.y) * 40 * 0.5
            return hypot(x, y)
        }
        XCTAssertEqual(projectedLength(straight), projectedLength(corner), accuracy: 0.001)
    }

    func testConstructionDragPlannerPreservesRoadTurns() {
        let firstLeg = ConstructionDragPlanner.orthogonalSegment(
            from: GridPoint(x: 2, y: 3),
            to: GridPoint(x: 5, y: 3)
        )
        let path = ConstructionDragPlanner.appendingOrthogonalSegment(
            to: firstLeg,
            endingAt: GridPoint(x: 5, y: 6)
        )
        XCTAssertEqual(path, [
            GridPoint(x: 2, y: 3),
            GridPoint(x: 3, y: 3),
            GridPoint(x: 4, y: 3),
            GridPoint(x: 5, y: 3),
            GridPoint(x: 5, y: 4),
            GridPoint(x: 5, y: 5),
            GridPoint(x: 5, y: 6),
        ])
    }

    func testConstructionDragPlannerFillsFieldsAndTilesHousing() {
        XCTAssertEqual(
            ConstructionDragPlanner.rectangularPoints(
                from: GridPoint(x: 4, y: 5),
                to: GridPoint(x: 6, y: 6)
            ),
            [
                GridPoint(x: 4, y: 5), GridPoint(x: 5, y: 5),
                GridPoint(x: 6, y: 5), GridPoint(x: 4, y: 6),
                GridPoint(x: 5, y: 6), GridPoint(x: 6, y: 6),
            ]
        )
        XCTAssertEqual(
            ConstructionDragPlanner.tiledOrigins(
                from: GridPoint(x: 8, y: 8),
                to: GridPoint(x: 4, y: 4),
                footprint: BuildingFootprint(width: 2, height: 2)
            ),
            [
                GridPoint(x: 8, y: 8), GridPoint(x: 6, y: 8),
                GridPoint(x: 4, y: 8), GridPoint(x: 8, y: 6),
                GridPoint(x: 6, y: 6), GridPoint(x: 4, y: 6),
                GridPoint(x: 8, y: 4), GridPoint(x: 6, y: 4),
                GridPoint(x: 4, y: 4),
            ]
        )
    }

    func testLocalCatalogWhenOriginalAssetsAreInstalled() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        XCTAssertGreaterThanOrEqual(catalog.maps.count, 160)
        XCTAssertGreaterThanOrEqual(catalog.campaigns.count, 30)
        XCTAssertGreaterThanOrEqual(catalog.spriteDescriptions.count, 50)
    }

    func testLocalTutorialCampaignMetadata() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaign = try CampaignArchive(
            url: source.campaignsDirectory.appendingPathComponent("1 Xia Dynasty - Tutorials.pak")
        )
        XCTAssertEqual(campaign.title, "Xia Dynasty Tutorials")
        XCTAssertEqual(campaign.missions.count, 6)
        XCTAssertEqual(campaign.missions.map(\.sequenceNumber), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(campaign.missions.first?.title, "Shelter and Sustenance")
        XCTAssertEqual(campaign.missions.dropFirst().first?.title, "Seeds of Civilization")
        XCTAssertTrue(campaign.campaignDescription.hasPrefix("Begin your journey into ancient China"))
    }

    func testLocalOriginalCityNameCatalog() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let names = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )

        XCTAssertEqual(names.names.count, 127)
        XCTAssertEqual(names[nameID: 4], "Banpo")
        XCTAssertEqual(names[nameID: 9], "Bo")
        XCTAssertEqual(names[nameID: 107], "Yin")
        XCTAssertEqual(names[nameID: 125], "the Kingdom of Nanyue")
        XCTAssertNil(names[nameID: 127])
    }

    func testLocalChineseTextCatalogAlignsWithShippingEnglishTable() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try OriginalLocalizedTextCatalog(root: source.root)

        XCTAssertEqual(catalog.localized("Banpo", groupID: 21), "半坡")
        XCTAssertEqual(catalog.localized("Wheat", groupID: 23), "小麦")
        XCTAssertEqual(catalog.localized("Banpo"), "半坡")
    }

    func testLocalEmperorTextGroup127RowLookupIsExactChinese() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try OriginalLocalizedTextCatalog(root: source.root)

        XCTAssertEqual(
            catalog.localized(groupID: 127, rowIndex: 58),
            "干渴的居民们要喝水, 没有水这所房子就不能升级."
        )
        XCTAssertEqual(
            catalog.localized(groupID: 127, rowIndex: 57),
            "除非这个地区的吸引力有所提高, 否则这所房子就不能升级."
        )
        XCTAssertEqual(
            catalog.localized(groupID: 127, rowIndex: 59),
            "这所房子里的居民需要 [food_quality] 食物, 房子才能升级."
        )
        let expectedRows = [
            60: "这所房子里的居民要听到音乐, 房子才能升级.",
            61: "这所房子里的居民要看到杂技表演, 房子才能升级.",
            62: "这所房子里的居民要看到戏曲表演, 房子才能升级.",
            63: "这所房子里的居民 需要针灸医生来检查身体.",
            64: "这所房子里的居民 需要草药医生来服务.",
            65: "除非有先祖庙的人到这里来, 否则这所房子不能升级.",
            66: "这所房子里的人 希望能有孔庙里的人来访.",
            67: "如果没有术士或和尚来这里, 那么这所房子就不能升级.",
            68: "这所房子里的居民需要瓷器.",
            69: "要是没有小贩送来苎麻, 这所房子就不能升级.",
            70: "要是没有小贩来卖茶叶, 这所房子就不能升级.",
            71: "这所房子里的居民需要生活器皿.",
            72: "这所房子的居民没有买到丝绸, 房子就不能升级.",
        ]
        for (rowIndex, expected) in expectedRows {
            XCTAssertEqual(catalog.localized(groupID: 127, rowIndex: rowIndex), expected)
        }
    }

    func testLocalEmperorTextGroup55HousingCapacityAndMigrationRowsAreExactChinese() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try OriginalLocalizedTextCatalog(root: source.root)

        XCTAssertEqual(
            catalog.localized(groupID: 55, rowIndex: 8),
            "目前住宅还可容纳"
        )
        XCTAssertEqual(
            catalog.localized(groupID: 55, rowIndex: 9),
            "人居住"
        )
        XCTAssertEqual(
            catalog.localized(groupID: 55, rowIndex: 12),
            "移民受到限制.原因是:"
        )
        XCTAssertEqual(
            catalog.localized(groupID: 55, rowIndex: 13),
            "缺乏住房"
        )
        XCTAssertEqual(
            catalog.localized(groupID: 55, rowIndex: 20),
            "人们希望迁居你的城市"
        )
        XCTAssertEqual(
            catalog.localized(groupID: 55, rowIndex: 10),
            "个新移民本月到达"
        )
        XCTAssertEqual(
            catalog.localized("Housing for", groupID: 55),
            "目前住宅还可容纳"
        )
        XCTAssertEqual(
            catalog.localized("more people.", groupID: 55),
            "人居住"
        )
        XCTAssertEqual(
            catalog.localized("Immigration limited by", groupID: 55),
            "移民受到限制.原因是:"
        )
        XCTAssertEqual(
            catalog.localized("lack of housing vacancies.", groupID: 55),
            "缺乏住房"
        )
        XCTAssertEqual(
            catalog.localized("People wish to come to the city.", groupID: 55),
            "人们希望迁居你的城市"
        )
        XCTAssertEqual(
            catalog.localized("newcomers arrived this month.", groupID: 55),
            "个新移民本月到达"
        )
    }

    func testLocalEmperorTextGroup55RowLookupReturnsNilOutsideBounds() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try OriginalLocalizedTextCatalog(root: source.root)

        XCTAssertNil(catalog.localized(groupID: 55, rowIndex: -1))
        XCTAssertNil(catalog.localized(groupID: 55, rowIndex: 7))
        XCTAssertNil(catalog.localized(groupID: 55, rowIndex: 11))
        XCTAssertNil(catalog.localized(groupID: 55, rowIndex: 14))
        XCTAssertNil(catalog.localized(groupID: 55, rowIndex: 36))

        // Row 10 is authorized (newcomer plural suffix `个新移民本月到达`); row 11
        // stays unauthorized because its 1-4 singular control depends on the
        // unrecovered signed-pressure equivalence.
        XCTAssertEqual(catalog.localized(groupID: 55, rowIndex: 10), "个新移民本月到达")
    }

    func testLocalEmperorTextRowLookupReturnsNilOutsideBounds() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try OriginalLocalizedTextCatalog(root: source.root)

        XCTAssertNil(catalog.localized(groupID: 127, rowIndex: -1))
        XCTAssertNil(catalog.localized(groupID: 127, rowIndex: 75))
        XCTAssertNil(catalog.localized(groupID: 0, rowIndex: 0))
    }

    func testHousingEvolutionRequirementGroup127SemanticRowIDs() {
        XCTAssertEqual(
            HouseEvolutionRequirement.desirability(current: 0, required: 1)
                .emperorTextGroup127UpgradeReasonRowIndex,
            57
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.foodQuality(current: 20, required: 50)
                .emperorTextGroup127UpgradeReasonRowIndex,
            59
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.water).emperorTextGroup127UpgradeReasonRowIndex,
            58
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.music).emperorTextGroup127UpgradeReasonRowIndex,
            60
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.acrobat).emperorTextGroup127UpgradeReasonRowIndex,
            61
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.drama).emperorTextGroup127UpgradeReasonRowIndex,
            62
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.acupuncture).emperorTextGroup127UpgradeReasonRowIndex,
            63
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.herbalist).emperorTextGroup127UpgradeReasonRowIndex,
            64
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.ancestor).emperorTextGroup127UpgradeReasonRowIndex,
            65
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.confucian).emperorTextGroup127UpgradeReasonRowIndex,
            66
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.service(.daoistOrBuddhist)
                .emperorTextGroup127UpgradeReasonRowIndex,
            67
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.commodityAlternatives([25])
                .emperorTextGroup127UpgradeReasonRowIndex,
            68
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.commodityAlternatives([19])
                .emperorTextGroup127UpgradeReasonRowIndex,
            69
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.commodityAlternatives([13])
                .emperorTextGroup127UpgradeReasonRowIndex,
            70
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.commodityAlternatives([23, 22])
                .emperorTextGroup127UpgradeReasonRowIndex,
            71
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.commodityAlternatives([22, 23])
                .emperorTextGroup127UpgradeReasonRowIndex,
            71
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.commodityAlternatives([24])
                .emperorTextGroup127UpgradeReasonRowIndex,
            72
        )
        XCTAssertNil(
            HouseEvolutionRequirement.service(.inspection)
                .emperorTextGroup127UpgradeReasonRowIndex
        )
        XCTAssertNil(
            HouseEvolutionRequirement.service(.constable)
                .emperorTextGroup127UpgradeReasonRowIndex
        )
        XCTAssertNil(
            HouseEvolutionRequirement.service(.tax).emperorTextGroup127UpgradeReasonRowIndex
        )
        XCTAssertNil(
            HouseEvolutionRequirement.commodityAlternatives([13, 25])
                .emperorTextGroup127UpgradeReasonRowIndex
        )
        XCTAssertNil(
            HouseEvolutionRequirement.commodityAlternatives([22])
                .emperorTextGroup127UpgradeReasonRowIndex
        )
    }

    func testHousingEvolutionRequirementUsesRecoveredOriginalReasonOrdinals() {
        let requirements: [HouseEvolutionRequirement] = [
            .service(.water),
            .foodQuality(current: 0, required: 20),
            .service(.music),
            .service(.acrobat),
            .service(.drama),
            .service(.acupuncture),
            .service(.herbalist),
            .service(.ancestor),
            .service(.confucian),
            .service(.daoistOrBuddhist),
            .commodityAlternatives([25]),
            .commodityAlternatives([19]),
            .commodityAlternatives([13]),
            .commodityAlternatives([22, 23]),
            .commodityAlternatives([24]),
        ]
        XCTAssertEqual(
            requirements.compactMap(\.originalUpgradeReasonCode),
            Array(19...33)
        )
        XCTAssertEqual(
            requirements.compactMap(\.emperorTextGroup127UpgradeReasonRowIndex),
            Array(58...72)
        )
        XCTAssertEqual(
            HouseEvolutionRequirement.desirability(current: 0, required: 1)
                .originalUpgradeReasonCode,
            18
        )
        XCTAssertNil(
            HouseEvolutionRequirement.service(.tax).originalUpgradeReasonCode
        )
    }

    func testLocalCampaignEmpireMapTemplateLayout() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let url = source.campaignsDirectory
            .appendingPathComponent("UNTITLED", isDirectory: true)
            .appendingPathComponent("UNTITLEDP.map")
        let empire = try CampaignEmpireMap(contentsOf: url)

        XCTAssertEqual(empire.decodedOffset, 0)
        XCTAssertEqual(empire.objects.count, 200)
        XCTAssertTrue(empire.objects.allSatisfy { $0.schemaVersion == 2 && $0.rawPayload.count == 38 })
        XCTAssertEqual(empire.cities.count, 22)
        XCTAssertTrue(empire.activeCities.isEmpty)
        XCTAssertTrue(empire.cities.allSatisfy { city in
            city.schemaVersion == 15
                && city.rawPrefix.count == 1_192
                && city.relationships.count == 22
                && city.relationships.allSatisfy { $0.schemaVersion == 5 && $0.rawPayload.count == 627 }
                && city.rawPostlude.count == 334
        })
    }

    func testLocalNavalAndShangCampaignEmpireMaps() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let naval = try XCTUnwrap(CampaignEmpireMap.loadIfPresent(
            campaignURL: source.campaignsDirectory.appendingPathComponent("Naval Trade.pak")
        ))
        XCTAssertEqual(naval.decodedOffset, 0x6c9a3)
        XCTAssertEqual(naval.objects.count, 199)
        XCTAssertEqual(naval.activeCities.map(\.nameID), [66, 11, 31, 38, 106, 93, 115, 52, 103, 88])
        XCTAssertTrue(naval.activeCities.allSatisfy { $0.tradeVisitInterval == 4 })

        let shang = try XCTUnwrap(CampaignEmpireMap.loadIfPresent(
            campaignURL: source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        ))
        XCTAssertEqual(shang.decodedOffset, 0x6cb70)
        XCTAssertEqual(shang.objects.count, 196)
        XCTAssertEqual(shang.activeCities.map(\.nameID), [34, 107, 74, 6, 4, 116, 78, 113, 9])
        XCTAssertTrue(shang.activeCities.allSatisfy { $0.tradeVisitInterval == 34 })
        XCTAssertEqual(shang.cities[0].initialFavor, 60)
        XCTAssertEqual(shang.cities[2].initialFavor, 45)
        XCTAssertEqual(shang.cities[13].initialFavor, 55)

        let banpo = try XCTUnwrap(shang.cities.first { $0.nameID == 4 })
        XCTAssertEqual(banpo.demandCommodityIDs, [2, 7, 26])
        XCTAssertEqual(banpo.supplyCommodityIDs, [19, 5, 25, 18])
        XCTAssertEqual(banpo.annualLoadsByCommodityID[2], 24)
        XCTAssertEqual(banpo.annualLoadsByCommodityID[5], 36)
        XCTAssertEqual(banpo.annualLoadsByCommodityID[19], 24)
        XCTAssertEqual(banpo.priceByCommodityID[26], 230)

        let models = try OriginalEconomyModels(source: source)
        let partner = try XCTUnwrap(banpo.tradePartner(name: "Banpo", tradeRules: models.trade))
        XCTAssertEqual(partner.routeKind, .land)
        XCTAssertEqual(partner.demandByCommodityID, [2: .medium, 7: .low, 26: .low])
        XCTAssertEqual(partner.supplyByCommodityID, [5: .high, 18: .medium, 19: .medium, 25: .low])
        XCTAssertEqual(partner.priceByCommodityID[26], models.trade[commodityID: 26]?.price)
    }

    func testLocalQinCampaignEmpireCitiesPersistChineseInvasionEnemySet() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let qin = try XCTUnwrap(CampaignEmpireMap.loadIfPresent(
            campaignURL: source.campaignsDirectory.appendingPathComponent("4 Qin Dynasty.pak")
        ))

        XCTAssertEqual(qin.decodedOffset, 0x6caa2)
        XCTAssertEqual(qin.objects.count, 193)
        XCTAssertEqual(qin.cities.count, CampaignEmpireMap.cityCount)
        XCTAssertTrue(qin.cities.allSatisfy { $0.serializedEnemySetIndex == 0 })
        XCTAssertTrue(qin.activeCities.allSatisfy { (0...6).contains($0.serializedEnemySetIndex) })
    }

    func testVersion032EmpireDiplomacyStatusCodesAgentsConquestAndHomage() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let original = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: original)
        let campaignURL = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let empireMap = try XCTUnwrap(CampaignEmpireMap.loadIfPresent(campaignURL: campaignURL))
        let cityNames = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        var runtime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: 1600,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: 0, events: []),
            replaySeed: 0x3032_454D_5049_5245,
            empireMap: empireMap,
            playerCityID: 13,
            cityNames: cityNames
        )
        var city = DeterministicCityState(
            year: 1600,
            treasury: 20_000,
            mapWidth: 20,
            mapHeight: 10
        )
        _ = city.buildRoad((0..<20).map { GridPoint(x: $0, y: 6) }, rules: rules)
        _ = try XCTUnwrap(city.constructMilitaryFort(
            buildingID: 221,
            at: GridPoint(x: 0, y: 2),
            rules: rules
        ))

        XCTAssertEqual(runtime.empireState?.cities.first { $0.id == 0 }?.favor, 60)
        XCTAssertTrue(runtime.sendEmissary(to: 0, city: &city))
        XCTAssertEqual(runtime.empireState?.cities.first { $0.id == 0 }?.favor, 70)
        XCTAssertTrue(runtime.requestAlliance(with: 0))
        XCTAssertEqual(runtime.empireState?.alliedCityCount, 1)
        XCTAssertTrue(runtime.sendSpy(to: 1, city: &city))
        XCTAssertEqual(runtime.empireState?.cities.first { $0.id == 1 }?.spyStatus, .arrived)
        XCTAssertTrue(runtime.conquerCity(2, using: city))
        XCTAssertEqual(runtime.empireState?.conqueredCityCount, 1)

        var liveEmpire = try XCTUnwrap(runtime.empireState)
        XCTAssertTrue(liveEmpire.applyStatus(
            rawCode: CampaignCityStatusCode.setFavor.rawValue,
            cityID: 3,
            secondaryCityID: nil,
            amount: 82
        ))
        XCTAssertEqual(liveEmpire.cities.first { $0.id == 3 }?.favor, 82)
        XCTAssertTrue(liveEmpire.applyStatus(
            rawCode: CampaignCityStatusCode.rivalBecomesAlly.rawValue,
            cityID: 3,
            secondaryCityID: nil,
            amount: nil
        ))
        XCTAssertEqual(liveEmpire.alliedCityCount, 2)

        XCTAssertTrue(runtime.prepayHeroHomage(
            heroID: 4,
            city: &city,
            months: 2
        ))
        _ = runtime.advance(
            settlementYear: 1600,
            month: 1,
            city: &city,
            rules: rules,
            goalSet: nil
        )
        _ = runtime.advance(
            settlementYear: 1600,
            month: 2,
            city: &city,
            rules: rules,
            goalSet: nil
        )
        XCTAssertEqual(runtime.empireState?.homageProgress, 2)
        XCTAssertEqual(
            try JSONDecoder().decode(
                CampaignMissionRuntimeState.self,
                from: JSONEncoder().encode(runtime)
            ),
            runtime
        )
    }

    func testLocalAllCampaignEmpireMapsAreStructurallyValid() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaigns = try CampaignCatalog.load(source)
        let tradeRules = try OriginalEconomyModels(source: source).trade
        let maps = try campaigns.compactMap { try CampaignEmpireMap.loadIfPresent(campaignURL: $0.url) }

        XCTAssertEqual(maps.count, 20)
        XCTAssertEqual(maps.reduce(0) { $0 + $1.activeCities.count }, 227)
        XCTAssertTrue(maps.allSatisfy { map in
            map.objects.count <= CampaignEmpireMap.maximumEmpireObjectCount
                && map.objects.allSatisfy { $0.schemaVersion == 2 }
                && map.cities.count == CampaignEmpireMap.cityCount
                && map.cities.allSatisfy { city in
                    city.schemaVersion == 15
                        && (!city.isActive || (
                            map.objects.indices.contains(city.empireObjectID)
                                && map.objects[city.empireObjectID].linkedCityID == city.id
                        ))
                        && city.relationships.allSatisfy { $0.schemaVersion == 5 }
                        && Set(city.demandCommodityIDs).isDisjoint(with: city.supplyCommodityIDs)
                }
                && map.tradingCities.allSatisfy {
                    $0.tradePartner(name: "#\($0.nameID)", tradeRules: tradeRules) != nil
                }
        })
    }

    func testLocalTutorialCampaignResolvesEmbeddedOriginalMaps() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        let maps = try CampaignEmbeddedMapResolver.resolve(
            campaignURL: source.campaignsDirectory.appendingPathComponent("1 Xia Dynasty - Tutorials.pak"),
            candidateMapURLs: catalog.maps.map(\.url)
        )
        let byName = Dictionary(uniqueKeysWithValues: maps.map { ($0.mapURL.lastPathComponent, $0.campaignChunkRange) })
        XCTAssertEqual(byName["Banpo.map"], 29..<87)
        XCTAssertEqual(byName["Erlitou.map"], 87..<145)
    }

    func testLocalTutorialCampaignResolvesEveryMissionToItsOriginalMap() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaignURL = source.campaignsDirectory.appendingPathComponent("1 Xia Dynasty - Tutorials.pak")
        let campaign = try CampaignArchive(url: campaignURL)
        let catalog = try GameDataCatalog.scan(source)
        let maps = try CampaignMissionMapArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count,
            candidateMapURLs: catalog.maps.map(\.url)
        )

        XCTAssertEqual(maps.mapNameTableOffset, 0x6b1fe)
        XCTAssertEqual(maps.playerCityTableOffset, 0x6bc30)
        XCTAssertEqual(maps.sourceMissionTableOffset, 0x6bc3a)
        XCTAssertEqual(maps.missions.map(\.playerCityID), [0, 0, 0, 0, 1, 1])
        XCTAssertEqual(maps.missions.map(\.sourceMissionIndex), [0, 0, 1, 2, 4, 4])
        XCTAssertEqual(
            maps.missions.map { $0.embeddedMap.mapURL.lastPathComponent },
            ["Banpo.map", "Banpo.map", "Banpo.map", "Banpo.map", "Erlitou.map", "Erlitou.map"]
        )
    }

    func testLocalShangCampaignContinuationMapLinksAreExact() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaignURL = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: campaignURL)
        let catalog = try GameDataCatalog.scan(source)
        let maps = try CampaignMissionMapArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count,
            candidateMapURLs: catalog.maps.map(\.url)
        )

        XCTAssertEqual(maps.missions.map(\.sourceMissionIndex), [0, 1, 0, 3, 4, 5, 4])
        XCTAssertEqual(maps.missions.map(\.playerCityID), [13, 3, 13, 7, 1, 2, 1])
        XCTAssertEqual(
            maps.missions.map { $0.embeddedMap.mapURL.lastPathComponent },
            ["Bo.map", "Baoji.map", "Bo.map", "Zhengzhou.map", "Anyang.map", "Jiangxi.map", "Anyang.map"]
        )
        XCTAssertEqual(maps.missions.filter(\.isContinuation).map(\.id), [2, 6])

        let empire = try XCTUnwrap(try CampaignEmpireMap.loadIfPresent(campaignURL: campaignURL))
        let names = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        let economy = try OriginalEconomyModels(source: source)
        let settings = try CampaignMissionSettingsArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let expectedPlayerCities = ["Bo", "Baoji", "Bo", "Zhengzhou", "Yin", "Panlongcheng", "Yin"]
        let expectedMapSides = [112, 112, 112, 112, 140, 140, 140]
        let expectedOriginalRoadCounts = [57, 79, 57, 131, 143, 134, 143]
        for mission in campaign.missions {
            let world = try CampaignMissionWorldState(
                missionID: mission.id,
                missionSettings: settings,
                missionMaps: maps,
                empireMap: empire,
                cityNames: names,
                tradeRules: economy.trade
            )
            let playerCity = try XCTUnwrap(world.playerCity)
            XCTAssertEqual(world.playerCityName, expectedPlayerCities[mission.id])
            XCTAssertEqual(world.startSettings.id, mission.id)
            XCTAssertFalse(world.tradePartners.contains { $0.id == playerCity.id })
            XCTAssertEqual(world.tradePartners.count, empire.tradingCities.count - 1)
            var city = DeterministicCityState(year: 1600, treasury: 2_000)
            XCTAssertEqual(
                world.installTradePartners(in: &city, rules: EconomyRulesEngine(models: economy)),
                world.tradePartners.count
            )
            XCTAssertEqual(city.trade.activePartnerCount, world.tradePartners.count)
            XCTAssertEqual(city.campaignGoalProgressSnapshot().tradingPartnerCount, 0)

            let originalMap = try EmperorMap(url: world.mapAssignment.embeddedMap.mapURL)
            let missionCity = DeterministicCityState(
                missionSettings: world.startSettings,
                map: originalMap
            )
            XCTAssertEqual(originalMap.width, expectedMapSides[mission.id])
            XCTAssertEqual(originalMap.height, expectedMapSides[mission.id])
            XCTAssertEqual(missionCity.calendar.year, settings.missions[mission.id].startYear)
            XCTAssertEqual(missionCity.calendar.month, settings.missions[mission.id].startMonth)
            XCTAssertEqual(missionCity.economy.treasury, settings.missions[mission.id].initialFunds)
            XCTAssertEqual(missionCity.missionSettings, settings.missions[mission.id])
            XCTAssertEqual(missionCity.roadNetwork.width, expectedMapSides[mission.id])
            XCTAssertEqual(missionCity.roadNetwork.points.count, expectedOriginalRoadCounts[mission.id])
            XCTAssertNotNil(missionCity.nextHouseConstructionLocation())
            if mission.id == 0 {
                let save = NativeSaveGame(
                    campaignFileName: campaignURL.lastPathComponent,
                    missionIndex: mission.id,
                    replaySeed: 1,
                    city: missionCity
                )
                let restored = try NativeSaveGameStore.decoded(NativeSaveGameStore.encoded(save))
                XCTAssertEqual(restored.city.missionSettings, world.startSettings)
            }
        }
    }

    func testLocalShangCampaignStartSettingsAreExact() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaignURL = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: campaignURL)
        let settings = try CampaignMissionSettingsArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )

        XCTAssertEqual(settings.yearTableOffset, 0x1252)
        XCTAssertEqual(settings.missionRecordStride, 0x9FE7)
        XCTAssertEqual(settings.missions.map(\.startMonth), Array(repeating: 6, count: 7))
        XCTAssertEqual(settings.missions.map(\.startYear), [-1606, -1585, -1559, -1501, -1384, -1308, -1250])
        XCTAssertEqual(settings.missions.map(\.initialFunds), [5_000, 8_000, 9_000, 12_000, 12_000, 8_000, 6_000])
        XCTAssertEqual(
            settings.missions[0].allowedBuildingMenuIDs,
            [1, 9, 12, 13, 15, 16, 17, 20, 26, 27, 29, 30, 33, 41]
        )
        XCTAssertEqual(
            settings.missions[0].allowedResourceCommodityIDs,
            [4, 5, 18, 19, 25]
        )
        for buildingID in [35, 43, 53, 54, 59, 72, 207, 211, 214] {
            XCTAssertNil(
                settings.missions[0].constructionRestriction(forBuildingID: buildingID),
                "Shang mission 1 should expose building #\(buildingID)"
            )
        }
        for buildingID in [125, 208, 212, 213, 215, 219] {
            XCTAssertNotNil(
                settings.missions[0].constructionRestriction(forBuildingID: buildingID),
                "Shang mission 1 should hide building #\(buildingID)"
            )
        }
        XCTAssertEqual(settings.missions[0].startingTreasury(difficulty: .veryEasy), 7_500)
        XCTAssertEqual(settings.missions[0].startingTreasury(difficulty: .normal), 5_000)
        XCTAssertEqual(settings.missions[0].startingTreasury(difficulty: .veryHard), 4_000)
    }

    func testOriginalCampaignBuildingPermissionCatalogMatchesShippingTextGroupOrder() {
        XCTAssertEqual(OriginalCampaignBuildingPermissionCatalog.menuNames.count, 57)
        XCTAssertEqual(
            Array(OriginalCampaignBuildingPermissionCatalog.menuNames[1...11]),
            [
                "Roadblock", "Elite Housing", "Irrigation Pump", "Mint", "Money Printer",
                "Lacquerware Maker", "Weaver", "Bronzeware Maker", "Kiln", "Paper Maker",
                "Jade Carver's Studio"
            ]
        )
        XCTAssertEqual(OriginalCampaignBuildingPermissionCatalog.menuName(forMenuID: 56), "Theatre Pavilion")
        XCTAssertNil(OriginalCampaignBuildingPermissionCatalog.menuName(forMenuID: 0))
        XCTAssertNil(OriginalCampaignBuildingPermissionCatalog.menuName(forMenuID: 57))

        let expectedMenuIDsByBuildingID = [
            43: 9, 53: 12, 59: 13, 54: 15,
            211: 17, 212: 18, 213: 19, 214: 20, 215: 21, 219: 25,
            72: 26, 207: 27, 208: 28, 125: 44
        ]
        for (buildingID, menuID) in expectedMenuIDsByBuildingID {
            XCTAssertEqual(
                OriginalCampaignBuildingPermissionCatalog.menuID(forBuildingID: buildingID),
                menuID
            )
        }
        XCTAssertNil(OriginalCampaignBuildingPermissionCatalog.menuID(forBuildingID: 35))
        XCTAssertEqual(
            OriginalCampaignBuildingPermissionCatalog.localResourceCommodityID(forBuildingID: 35),
            18
        )
    }

    func testCampaignConstructionPermissionsSeparateLocalResourcesFromTradeInputs() {
        let settings = CampaignMissionStartSettings(
            id: 0,
            startYear: -1606,
            startMonth: 6,
            initialFunds: 5_000,
            allowedBuildingMenuIDs: [15, 9],
            allowedResourceCommodityIDs: []
        )
        XCTAssertEqual(
            settings.constructionRestriction(forBuildingID: 53),
            .buildingNotAllowed(menuID: 12, name: "Mill")
        )
        XCTAssertEqual(
            settings.constructionRestriction(forBuildingID: 35),
            .localResourceNotAllowed(commodityID: 18)
        )
        XCTAssertEqual(
            settings.constructionRestriction(forBuildingID: 43),
            .requiredInputsUnavailable(options: [[18]])
        )
        XCTAssertNil(settings.constructionRestriction(forBuildingID: 54))

        let clayTrader = TradePartner(
            id: 7,
            name: "Clay Trader",
            routeKind: .land,
            supplyByCommodityID: [18: .low]
        )
        XCTAssertNil(settings.constructionRestriction(
            forBuildingID: 43,
            openTradePartners: [clayTrader]
        ))
        // The manual makes local resources the sole switch for raw producers;
        // an import route can unlock the kiln but not the clay pit.
        XCTAssertEqual(
            settings.constructionRestriction(
                forBuildingID: 35,
                openTradePartners: [clayTrader]
            ),
            .localResourceNotAllowed(commodityID: 18)
        )
    }

    func testCampaignResidentialProviderConstructionStaysFailClosedForUnrecoveredClasses() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let models = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: models)
        let settings = CampaignMissionStartSettings(
            id: 3,
            startYear: -1600,
            startMonth: 1,
            initialFunds: 10_000,
            allowedBuildingMenuIDs: Array(1...56),
            allowedResourceCommodityIDs: Array(1...28)
        )
        var city = DeterministicCityState(
            year: -1600,
            treasury: 10_000,
            mapWidth: 12,
            mapHeight: 6
        )
        let road = (0..<12).map { GridPoint(x: $0, y: 3) }
        XCTAssertEqual(city.buildRoad(road, rules: rules), road.count)
        city.continueCampaignMission(with: settings)
        let startingTreasury = city.economy.treasury

        for buildingID in [211, 212, 213] {
            XCTAssertFalse(
                city.isBuildingAvailableInCampaign(buildingID),
                "unrecovered provider #\(buildingID) must not enter campaign construction"
            )
            XCTAssertFalse(
                city.canConstructBuilding(
                    buildingID: buildingID,
                    at: GridPoint(x: 2, y: 2)
                ),
                "the public placement query must share the campaign provider gate"
            )
            XCTAssertNil(city.constructionFootprint(
                buildingID: buildingID,
                at: GridPoint(x: 2, y: 2)
            ))
            XCTAssertNil(city.constructResidentialServiceBuilding(
                buildingID: buildingID,
                serviceRoadStart: road[2],
                replaySeed: 0x51_52_4F_56_45_52,
                rules: rules
            ))
        }

        XCTAssertEqual(city.economy.treasury, startingTreasury)
        XCTAssertTrue(city.residentialServiceBuildings.isEmpty)
        XCTAssertTrue(city.walkers.walkers.isEmpty)
        XCTAssertTrue(city.placedBuildings.isEmpty)
        XCTAssertTrue(city.isBuildingAvailableInCampaign(72))
        XCTAssertTrue(city.isBuildingAvailableInCampaign(207))
        XCTAssertTrue(city.isBuildingAvailableInCampaign(124))
        XCTAssertTrue(city.isBuildingAvailableInCampaign(127))
    }

    func testCampaignConstructionCoreEnforcesPermissionsAndRoundTripsSettings() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let models = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: models)
        let settings = CampaignMissionStartSettings(
            id: 2,
            startYear: -1500,
            startMonth: 4,
            initialFunds: 2_000,
            allowedBuildingMenuIDs: [9],
            allowedResourceCommodityIDs: []
        )
        var city = DeterministicCityState(missionSettings: settings)
        let startingTreasury = city.economy.treasury

        XCTAssertFalse(city.isBuildingAvailableInCampaign(35))
        XCTAssertFalse(city.isBuildingAvailableInCampaign(43))
        XCTAssertNil(city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: models.buildings[buildingID: 35]?.employees ?? 0,
            rules: rules
        ))
        XCTAssertNil(city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: models.buildings[buildingID: 43]?.employees ?? 0,
            rules: rules
        ))
        XCTAssertEqual(city.economy.treasury, startingTreasury)

        XCTAssertTrue(city.addTradePartner(
            TradePartner(
                id: 8,
                name: "Imported Clay",
                routeKind: .land,
                supplyByCommodityID: [18: .low]
            ),
            rules: rules
        ))
        XCTAssertTrue(city.isBuildingAvailableInCampaign(43))
        XCTAssertNotNil(city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: models.buildings[buildingID: 43]?.employees ?? 0,
            rules: rules
        ))

        let restored = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONEncoder().encode(city)
        )
        XCTAssertEqual(restored, city)
        XCTAssertEqual(restored.missionSettings, settings)

        let sandbox = DeterministicCityState(year: -1500, treasury: 2_000)
        XCTAssertTrue(sandbox.isBuildingAvailableInCampaign(35))
        XCTAssertTrue(sandbox.isBuildingAvailableInCampaign(53))
    }

    func testLocalEveryCampaignStartSettingsTableIsStructurallyValid() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaigns = try CampaignCatalog.load(source)
        var missionCount = 0
        for campaign in campaigns {
            let settings = try CampaignMissionSettingsArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            XCTAssertEqual(settings.missions.count, campaign.missions.count, campaign.title)
            XCTAssertTrue(settings.missions.allSatisfy { (1...12).contains($0.startMonth) })
            XCTAssertTrue(settings.missions.allSatisfy { $0.allowedBuildingMenuIDs == $0.allowedBuildingMenuIDs.sorted() })
            XCTAssertTrue(settings.missions.allSatisfy { $0.allowedResourceCommodityIDs == $0.allowedResourceCommodityIDs.sorted() })
            missionCount += settings.missions.count
        }
        XCTAssertEqual(campaigns.count, 31)
        XCTAssertEqual(missionCount, 74)
    }

    func testLocalShangCampaignGoalArchive() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let url = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let goals = try CampaignGoalArchive(campaignURL: url, missionCount: campaign.missions.count)

        XCTAssertEqual(goals.sectionOffset, 0x6c900)
        XCTAssertEqual(goals.missions.map { $0.goals.count }, [2, 2, 3, 3, 4, 3, 3])
        XCTAssertEqual(goals.missions[0].goals.map(\.kind), [.housing, .yearlyProduction])
        XCTAssertEqual(goals.missions[0].goals[0].values, [7, 600, 0])
        XCTAssertEqual(goals.missions[0].goals[1].values, [25, 1_200, 0])
        XCTAssertEqual(goals.missions[1].goals.map(\.kind), [.tradingPartners, .yearlyProfit])
        XCTAssertEqual(goals.missions[1].goals[0].values, [4])
        XCTAssertEqual(goals.missions[1].goals[1].values, [1_200, 0])
    }

    func testShangMissionGoalEvaluationUsesOriginalInternalUnits() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let url = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let archive = try CampaignGoalArchive(campaignURL: url, missionCount: campaign.missions.count)
        let firstMission = archive.missions[0]

        let incomplete = CampaignGoalProgressSnapshot(
            housingPopulationByLevelCode: [7: 599],
            bestYearlyProductionUnitsByCommodityID: [25: 1_100]
        )
        XCTAssertFalse(CampaignGoalEvaluator.missionIsComplete(firstMission, against: incomplete))
        XCTAssertEqual(
            CampaignGoalEvaluator.evaluate(firstMission.goals[1], against: incomplete),
            CampaignGoalProgress(currentValue: 1_100, requiredValue: 1_200, isSatisfied: false)
        )

        let complete = CampaignGoalProgressSnapshot(
            housingPopulationByLevelCode: [7: 500, 8: 100],
            bestYearlyProductionUnitsByCommodityID: [25: 1_200]
        )
        XCTAssertTrue(CampaignGoalEvaluator.missionIsComplete(firstMission, against: complete))
    }

    func testLocalCampaignGoalArchivesUseTaggedMFCLayout() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaigns = try CampaignCatalog.load(source)
        var totalGoals = 0
        var archivesWithGoals = 0
        for campaign in campaigns {
            let archive: CampaignGoalArchive
            do {
                archive = try CampaignGoalArchive(
                    campaignURL: campaign.url,
                    missionCount: campaign.missions.count
                )
            } catch {
                XCTFail("\(campaign.title): \(error)")
                continue
            }
            XCTAssertEqual(archive.missions.count, campaign.missions.count, campaign.title)
            let goalCount = archive.missions.reduce(0) { $0 + $1.goals.count }
            totalGoals += goalCount
            if goalCount > 0 { archivesWithGoals += 1 }
        }
        XCTAssertEqual(archivesWithGoals, 28)
        XCTAssertEqual(totalGoals, 210)
    }

    func testVersion060EveryAuthoredGoalHasASatisfiableNativeProgressSource() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let campaigns = try CampaignCatalog.load(.openDefault())
        var kinds = Set<CampaignGoalKind>()
        var checkedGoalCount = 0
        for campaign in campaigns {
            let archive = try CampaignGoalArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            for mission in archive.missions where !mission.goals.isEmpty {
                var snapshot = CampaignGoalProgressSnapshot()
                for goal in mission.goals {
                    kinds.insert(goal.kind)
                    checkedGoalCount += 1
                    switch goal.requirement {
                    case let .alliedCities(required):
                        snapshot.alliedCityCount = max(snapshot.alliedCityCount, required)
                    case let .conqueredCities(required):
                        snapshot.conqueredCityCount = max(snapshot.conqueredCityCount, required)
                    case let .homage(required):
                        snapshot.homageProgress = max(snapshot.homageProgress, required)
                    case let .housing(minimumLevelCode, residents):
                        snapshot.housingPopulationByLevelCode[minimumLevelCode, default: 0] += residents
                    case let .menagerieSpecies(required):
                        snapshot.menagerieSpeciesCount = max(snapshot.menagerieSpeciesCount, required)
                    case let .monument(buildingID):
                        snapshot.completedMonumentBuildingIDs.insert(buildingID)
                    case let .population(required):
                        snapshot.population = max(snapshot.population, required)
                    case let .tradingPartners(required):
                        snapshot.tradingPartnerCount = max(snapshot.tradingPartnerCount, required)
                    case let .treasury(required):
                        snapshot.treasury = max(snapshot.treasury, required)
                    case let .yearlyProduction(commodityID, internalUnits):
                        snapshot.bestYearlyProductionUnitsByCommodityID[commodityID] = max(
                            snapshot.bestYearlyProductionUnitsByCommodityID[commodityID, default: 0],
                            internalUnits
                        )
                    case let .yearlyProfit(required):
                        snapshot.bestYearlyProfit = max(snapshot.bestYearlyProfit, required)
                    }
                }
                XCTAssertTrue(
                    CampaignGoalEvaluator.missionIsComplete(mission, against: snapshot),
                    "\(campaign.title) mission \(mission.id + 1)"
                )
            }
        }
        XCTAssertEqual(checkedGoalCount, 210)
        XCTAssertEqual(kinds, Set(CampaignGoalKind.allCases))
    }

    func testOriginalEventManagerRandomMatchesSeedWarmupAndWaitBranches() throws {
        XCTAssertEqual(OriginalEventManagerRandomState.directCallerAddresses.count, 45)
        XCTAssertTrue(
            OriginalEventManagerRandomState.directCallerAddresses.contains(0x0049_F8B0)
        )
        XCTAssertTrue(
            OriginalEventManagerRandomState.directCallerAddresses.contains(0x0049_25F0)
        )
        XCTAssertTrue(
            OriginalEventManagerRandomState.directCallerAddresses.contains(0x0053_71A0)
        )

        var random = OriginalEventManagerRandomState()
        XCTAssertEqual(random.advance(), 111)
        XCTAssertEqual(random.primaryState, 0x2923_21EF)
        XCTAssertEqual(random.secondaryState, 0x5D42_5705)

        var warmed = OriginalEventManagerRandomState()
        warmed.warmUp()
        XCTAssertEqual(warmed.primaryState, 0x0028_DB70)
        XCTAssertEqual(warmed.secondaryState, 0x298B_8960)
        XCTAssertEqual(warmed.advance(), 71)

        var waits = OriginalEventManagerRandomState()
        XCTAssertEqual(waits.nextWaitTicks(forRawEventType: 0), 17)
        XCTAssertEqual(waits.primaryState, 0x518A_02CE)
        XCTAssertEqual(waits.nextWaitTicks(forRawEventType: 9), 24)
        XCTAssertEqual(waits.primaryState, 0x22D6_3040)
        XCTAssertEqual(
            try JSONDecoder().decode(
                OriginalEventManagerRandomState.self,
                from: JSONEncoder().encode(waits)
            ),
            waits
        )
    }

    func testLocalShangCampaignEventArchive() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let url = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let events = try CampaignEventArchive(campaignURL: url, missionCount: campaign.missions.count)

        XCTAssertEqual(events.sectionOffset, 0x1819)
        XCTAssertEqual(events.archiveVersion, 9)
        XCTAssertEqual(events.serializedRecordByteCount, 263)
        XCTAssertEqual(events.missionSlotByteCount, 40_935)
        XCTAssertEqual(events.missions.map { $0.events.count }, [9, 11, 6, 11, 10, 13, 14])
        XCTAssertEqual(
            events.missions[0].events.map(\.kind),
            [.cityStatusChange, .cityStatusChange, .cityStatusChange, .request,
             .cityStatusChange, .request, .request, .gift, .demandIncrease]
        )

        let request = events.missions[0].events[3]
        XCTAssertEqual(request.product.bounds, 25...25)
        XCTAssertEqual(request.amount.bounds, 3...4)
        XCTAssertEqual(request.year.bounds, 1...1)
        XCTAssertEqual(request.monthNumber, 9)
        XCTAssertEqual(request.timeAllowed, 4)
        XCTAssertEqual(request.rawMemory.count, CampaignEventArchive.runtimeRecordByteCount)

        let firstMission = events.missions[0]
        XCTAssertEqual(firstMission.events.map(\.triggerMode).filter { $0 == .oneTime }.count, 5)
        XCTAssertEqual(firstMission.events.map(\.triggerMode).filter { $0 == .recurring }.count, 2)
        XCTAssertEqual(firstMission.events.map(\.triggerMode).filter { $0 == .missionComplete }.count, 2)

        var scheduled = CampaignEventScheduler(
            eventSet: CampaignMissionEventSet(id: 0, events: [firstMission.events[3], firstMission.events[8]]),
            replaySeed: 0x5348_414E_47
        )
        XCTAssertEqual(scheduled.advance(toRelativeYear: 1, month: 4).map(\.eventID), [8])
        XCTAssertEqual(scheduled.advance(toRelativeYear: 1, month: 9).map(\.eventID), [3])
        XCTAssertTrue(scheduled.advance(toRelativeYear: 1, month: 9).isEmpty)

        var completed = CampaignEventScheduler(
            eventSet: CampaignMissionEventSet(id: 0, events: Array(firstMission.events.prefix(2))),
            replaySeed: 0
        )
        XCTAssertEqual(
            completed.advance(toRelativeYear: 0, month: 1, missionCompleted: true).map(\.eventID),
            [0, 1]
        )
        XCTAssertTrue(completed.advance(toRelativeYear: 0, month: 1, missionCompleted: true).isEmpty)

        var recurring = CampaignEventScheduler(
            eventSet: CampaignMissionEventSet(id: 0, events: [firstMission.events[7]]),
            replaySeed: 42
        )
        let earlyGifts = recurring.advance(toRelativeYear: 2, month: 8)
        XCTAssertFalse(earlyGifts.isEmpty)
        XCTAssertTrue(earlyGifts.allSatisfy { $0.eventID == 7 && $0.triggerMode == .recurring })
        XCTAssertFalse(recurring.advance(toRelativeYear: 6, month: 8).isEmpty)
    }

    func testLocalQinMissionThreeHasNoRequestFulfillmentEvent() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let url = source.campaignsDirectory.appendingPathComponent("4 Qin Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let events = try CampaignEventArchive(
            campaignURL: url,
            missionCount: campaign.missions.count
        )

        // Qin mission 3 is the third zero-based event slot (Land of Annam).
        // Keep the decoded raw sequence as an authored-data regression: the
        // no kind-32 request-fulfillment event is authored for this mission;
        // do not use that separate event path as a migration shortcut.
        let missionThree = events.missions[2]
        XCTAssertEqual(missionThree.events.count, 18)
        XCTAssertEqual(
            missionThree.events.map(\.kindRawValue),
            [22, 1, 1, 26, 26, 22, 22, 10, 22, 22, 22, 22, 22, 22, 22, 14, 14, 16]
        )
        XCTAssertFalse(
            missionThree.events.contains {
                $0.kindRawValue == CampaignEventKind.requestFulfillment.rawValue
            }
        )
    }

    func testLocalCampaignRuntimeAppliesCashGiftsAndTradeChanges() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let models = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: models)
        let url = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let archive = try CampaignEventArchive(campaignURL: url, missionCount: campaign.missions.count)
        let mission = archive.missions[0]

        let giftEvent = try XCTUnwrap(mission.events.first { $0.kind == .gift })
        var giftRuntime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: 1600,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: 0, events: [giftEvent]),
            replaySeed: 0x5348_414E_47
        )
        var giftCity = DeterministicCityState(year: 1600, treasury: 1_000)
        let giftResult = giftRuntime.advance(
            settlementYear: 1602,
            month: giftEvent.monthNumber,
            city: &giftCity,
            rules: rules,
            goalSet: nil
        )
        let cashReceived = giftResult.occurrences.reduce(0) { $0 + ($1.amount ?? 0) }
        XCTAssertGreaterThan(cashReceived, 0)
        XCTAssertEqual(giftCity.economy.treasury, 1_000 + cashReceived)
        XCTAssertTrue(giftResult.effects.allSatisfy { $0.disposition == .applied })

        let demandEvent = try XCTUnwrap(mission.events.first { $0.kind == .demandIncrease })
        var tradeRuntime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: 1600,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: 0, events: [demandEvent]),
            replaySeed: 0x5348_414E_47
        )
        var tradeCity = DeterministicCityState(year: 1600, treasury: 1_000)
        let partnerID = try XCTUnwrap(demandEvent.cityFrom.bounds?.lowerBound)
        XCTAssertTrue(tradeCity.addTradePartner(
            TradePartner(id: partnerID, name: "Scripted Partner", routeKind: .land),
            rules: rules
        ))
        let demandYear = try XCTUnwrap(demandEvent.year.bounds?.upperBound)
        let tradeResult = tradeRuntime.advance(
            settlementYear: 1600 + demandYear,
            month: demandEvent.monthNumber,
            city: &tradeCity,
            rules: rules,
            goalSet: nil
        )
        let commodityID = try XCTUnwrap(tradeResult.occurrences.first?.productID)
        XCTAssertEqual(tradeCity.trade.partner(id: partnerID)?.demandByCommodityID[commodityID], .low)
        XCTAssertEqual(tradeResult.effects.first?.disposition, .applied)
    }

    func testLocalCampaignRequestsUsePhysicalStorageAndRoundTripInSave() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let models = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: models)
        let url = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let archive = try CampaignEventArchive(campaignURL: url, missionCount: campaign.missions.count)
        let requestEvent = try XCTUnwrap(archive.missions[0].events.first { $0.kind == .request })
        var runtime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: 1600,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: 0, events: [requestEvent]),
            replaySeed: 0x5348_414E_47
        )
        var city = DeterministicCityState(
            year: 1600,
            treasury: 10_000,
            mapWidth: 7,
            mapHeight: 5
        )
        _ = city.buildRoad((0...6).map { GridPoint(x: $0, y: 2) }, rules: rules)
        XCTAssertNotNil(city.constructWarehouse(
            serviceRoadStart: GridPoint(x: 3, y: 2),
            rules: rules
        ))
        let requestYear = try XCTUnwrap(requestEvent.year.bounds?.upperBound)
        let result = runtime.advance(
            settlementYear: 1600 + requestYear,
            month: requestEvent.monthNumber,
            city: &city,
            rules: rules,
            goalSet: nil
        )
        let request = try XCTUnwrap(runtime.pendingRequests.first)
        XCTAssertEqual(request.amount, (result.occurrences.first?.amount ?? 0) * 100)
        XCTAssertEqual(city.receiveCampaignCommodityGift(
            commodityID: request.productID,
            amount: request.amount
        ), request.amount)
        XCTAssertTrue(runtime.fulfillFirstPendingRequest(city: &city))
        XCTAssertTrue(runtime.pendingRequests.isEmpty)
        XCTAssertEqual(city.storedCampaignCommodityAmount(commodityID: request.productID), 0)

        let save = NativeSaveGame(
            campaignFileName: "2 Shang Dynasty.pak",
            missionIndex: 0,
            replaySeed: 0x5348_414E_47,
            city: city,
            campaignRuntime: runtime
        )
        XCTAssertEqual(try NativeSaveGameStore.decoded(NativeSaveGameStore.encoded(save)), save)
    }

    func testCampaignRuntimeCompletesGoalsAndFiresCompletionEventsOnce() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let models = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: models)
        let url = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let archive = try CampaignEventArchive(campaignURL: url, missionCount: campaign.missions.count)
        let completionEvent = try XCTUnwrap(
            archive.missions[0].events.first { $0.triggerMode == .missionComplete }
        )
        var runtime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: 1600,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: 0, events: [completionEvent]),
            replaySeed: 0x5348_414E_47
        )
        var city = DeterministicCityState(year: 1600, treasury: 1_000)
        let goalSet = CampaignMissionGoalSet(id: 0, goals: [
            CampaignMissionGoal(id: 0, kind: .treasury, values: [500])
        ])

        let first = runtime.advance(
            settlementYear: 1600,
            month: 1,
            city: &city,
            rules: rules,
            goalSet: goalSet
        )
        XCTAssertTrue(first.missionCompletedNow)
        XCTAssertTrue(runtime.missionCompleted)
        XCTAssertEqual(first.occurrences.map(\.eventID), [completionEvent.id])
        XCTAssertEqual(runtime.cityStatusMutations.count, 1)

        let second = runtime.advance(
            settlementYear: 1600,
            month: 1,
            city: &city,
            rules: rules,
            goalSet: goalSet
        )
        XCTAssertFalse(second.missionCompletedNow)
        XCTAssertTrue(second.occurrences.isEmpty)
        XCTAssertEqual(runtime.cityStatusMutations.count, 1)
    }

    func testLocalCampaignAnimalRequestConsumesMenagerieHeadcount() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let models = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: models)
        let url = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: url)
        let archive = try CampaignEventArchive(campaignURL: url, missionCount: campaign.missions.count)
        let requestEvent = try XCTUnwrap(archive.missions.flatMap(\.events).first { event in
            event.kind == .request
                && (event.product.bounds?.lowerBound ?? -1)
                    >= CampaignMissionRuntimeState.firstMenagerieProductID
        })
        let missionID = try XCTUnwrap(archive.missions.first { $0.events.contains(requestEvent) }?.id)
        var runtime = CampaignMissionRuntimeState(
            missionID: missionID,
            startYear: 1600,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: missionID, events: [requestEvent]),
            replaySeed: 0x5348_414E_47
        )
        var city = DeterministicCityState(year: 1600, treasury: 1_000)
        let requestYear = try XCTUnwrap(requestEvent.year.bounds?.upperBound)
        _ = runtime.advance(
            settlementYear: 1600 + requestYear,
            month: requestEvent.monthNumber,
            city: &city,
            rules: rules,
            goalSet: nil
        )
        let request = try XCTUnwrap(runtime.pendingRequests.first)
        XCTAssertTrue(try XCTUnwrap(requestEvent.amount.bounds).contains(request.amount))
        runtime.receiveMenagerieAnimals(productID: request.productID, amount: request.amount)
        XCTAssertEqual(runtime.menagerieAnimalCountsByProductID[request.productID], request.amount)
        XCTAssertTrue(runtime.fulfillFirstPendingRequest(city: &city))
        XCTAssertNil(runtime.menagerieAnimalCountsByProductID[request.productID])
        XCTAssertFalse(runtime.menagerieAnimalIDs.contains(request.productID))
    }

    func testLocalVersion8CampaignEventArchive() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let url = source.campaignsDirectory.appendingPathComponent("X Emperor Jin Wudi.pak")
        let campaign = try CampaignArchive(url: url)
        let events = try CampaignEventArchive(campaignURL: url, missionCount: campaign.missions.count)

        XCTAssertEqual(events.sectionOffset, 0x1814)
        XCTAssertEqual(events.archiveVersion, 8)
        XCTAssertEqual(events.serializedRecordByteCount, 255)
        XCTAssertEqual(events.missionSlotByteCount, 39_735)
        XCTAssertEqual(events.missions.map { $0.events.count }, [11, 7, 6])
        XCTAssertEqual(events.missions[1].events.map(\.kind).prefix(3), [.request, .drought, .flood])
        XCTAssertTrue(events.missions.flatMap(\.events).allSatisfy { $0.rawMemory.count == 268 })
    }

    func testLocalAllCampaignEventArchivesUseOriginalFixedTables() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let campaigns = try CampaignCatalog.load(.openDefault())
        var totalMissionSets = 0
        var totalEvents = 0
        var versions = Set<UInt16>()
        var triggerCounts: [CampaignEventTriggerMode: Int] = [:]
        for campaign in campaigns {
            let archive = try CampaignEventArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            XCTAssertEqual(archive.missions.count, campaign.missions.count, campaign.title)
            XCTAssertTrue(archive.missions.flatMap(\.events).allSatisfy {
                $0.kind != nil && $0.monthIndex < 12
            }, campaign.title)
            totalMissionSets += archive.missions.count
            totalEvents += archive.missions.reduce(0) { $0 + $1.events.count }
            for event in archive.missions.flatMap(\.events) {
                triggerCounts[event.triggerMode, default: 0] += 1
            }
            versions.insert(archive.archiveVersion)
        }
        XCTAssertEqual(campaigns.count, 31)
        XCTAssertEqual(totalMissionSets, 74)
        XCTAssertEqual(totalEvents, 948)
        XCTAssertEqual(versions, [8, 9])
        XCTAssertEqual(triggerCounts[.oneTime], 683)
        XCTAssertEqual(triggerCounts[.recurring], 113)
        XCTAssertEqual(triggerCounts[.missionComplete], 152)
    }

    func testLocalAllCampaignsUseDetectedMetadataLayout() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let campaigns = try CampaignCatalog.load(.openDefault())
        XCTAssertEqual(campaigns.count, 31)
        XCTAssertTrue(campaigns.allSatisfy { !$0.title.isEmpty && !$0.missions.isEmpty })
        XCTAssertTrue(campaigns.allSatisfy { campaign in
            campaign.missions.map(\.sequenceNumber) == Array(1...campaign.missions.count)
        })
        XCTAssertGreaterThan(Set(campaigns.map(\.detectedMissionTableOffset)).count, 1)
    }

    func testLocalErlitouMapContainer() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let probe = try MapProbe(url: source.citiesDirectory.appendingPathComponent("Erlitou.map"))
        XCTAssertEqual(probe.formatVersion, 5)
        XCTAssertEqual(probe.width, 112)
        XCTAssertEqual(probe.height, 112)
        XCTAssertEqual(probe.chunkCount, 58)
        XCTAssertEqual(probe.decodedByteCount, 1_878_018)
    }

    func testLocalTerrainSG3Metadata() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(contentsOf: source.dataDirectory.appendingPathComponent("China_Terrain.sg3"))
        XCTAssertEqual(archive.header.version, 213)
        XCTAssertEqual(archive.images.count, 1_444)
        XCTAssertGreaterThan(archive.images.filter { $0.width > 0 && $0.height > 0 }.count, 1_000)
    }

    func testLocalTerrainSpriteDecodesToTransparentRGBA() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(contentsOf: source.dataDirectory.appendingPathComponent("China_Terrain.sg3"))
        let pixels = try Data(contentsOf: source.dataDirectory.appendingPathComponent("China_Terrain.555"), options: [.mappedIfSafe])
        let sprite = try SpriteDecoder.decode(image: archive.images[201], pixelData: pixels)
        XCTAssertEqual(sprite.width, 78)
        XCTAssertEqual(sprite.height, 40)
        XCTAssertEqual(sprite.rgba.count, 78 * 40 * 4)
        let alpha = stride(from: 3, to: sprite.rgba.count, by: 4).map { sprite.rgba[$0] }
        XCTAssertEqual(alpha.filter { $0 > 0 }.count, 1_600)
        XCTAssertEqual(alpha.first, 0)
        XCTAssertEqual(alpha[19 * 78 + 39], 255)
        XCTAssertNotNil(sprite.makeCGImage())
    }

    func testLocalHousingSpriteCatalogMatchesOriginalArchive() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(contentsOf: source.dataDirectory.appendingPathComponent("China_General.sg3"))
        XCTAssertEqual(OriginalBuildingSpriteCatalog.housingSprite(forHouseLevelID: 0)?.imageID, 1_509)
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.housingSprite(forHouseLevelID: 7, orientation: .eastWest)?.imageID,
            1_524
        )
        XCTAssertEqual(OriginalBuildingSpriteCatalog.housingSprite(forHouseLevelID: 8)?.imageID, 1_525)
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.housingSprite(forHouseLevelID: 14, orientation: .eastWest)?.imageID,
            1_537
        )
        for imageID in 1_508...1_537 {
            let image = archive.images[imageID]
            XCTAssertEqual(image.bitmapGroupID, 7)
            XCTAssertEqual(archive.bitmapNames[image.bitmapGroupID], "China_Housing.bmp")
            XCTAssertEqual(image.type, 30)
        }
    }

    func testOriginalPlacedBuildingSpriteCatalogAndCompositeGeometry() {
        let primaryImageIDs = [
            35: 2_789,
            43: 2_810,
            53: 647,
            72: 1_559,
            125: 1_908,
            207: 1_580,
            208: 1_593,
            211: 589,
            212: 460,
            213: 501,
            214: 2_232,
            215: 2_245,
            216: 2_271,
            217: 2_258,
            218: 2_296,
            219: 2_309,
        ]
        for (buildingID, imageID) in primaryImageIDs {
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingSprite(
                    forBuildingID: buildingID
                )?.imageID,
                imageID
            )
        }

        let warehouse = OriginalBuildingSpriteCatalog.buildingComponents(
            forBuildingID: 54
        )
        XCTAssertEqual(warehouse.count, 9)
        XCTAssertEqual(
            warehouse.filter {
                $0.sprite.imageID == OriginalBuildingSpriteCatalog.foodWarehouseBayImageID
            }.count,
            1
        )
        XCTAssertEqual(
            Set(warehouse.flatMap {
                $0.footprint.points(at: GridPoint(x: $0.tileOffsetX, y: $0.tileOffsetY))
            }),
            Set(BuildingFootprint(width: 3, height: 3).points(at: GridPoint(x: 0, y: 0)))
        )

        for orientation in IsometricBuildingOrientation.allCases {
            let station = OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: TradeRouteKind.land.buildingID,
                orientation: orientation
            )
            XCTAssertEqual(station.count, 9)
            XCTAssertEqual(
                station.filter {
                    $0.sprite.imageID == OriginalBuildingSpriteCatalog.tradingStationOfficeImageID
                }.count,
                1
            )
            XCTAssertEqual(
                station.filter {
                    $0.sprite.imageID == OriginalBuildingSpriteCatalog.emptyWarehouseBayImageID
                }.count,
                8
            )
            XCTAssertEqual(
                Set(station.flatMap {
                    $0.footprint.points(at: GridPoint(x: $0.tileOffsetX, y: $0.tileOffsetY))
                }),
                Set(BuildingFootprint(width: 3, height: 3).points(at: GridPoint(x: 0, y: 0)))
            )
        }
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.constructionCatalogSprite(
                forBuildingID: TradeRouteKind.land.buildingID
            )?.imageID,
            OriginalBuildingSpriteCatalog.tradingStationOfficeImageID
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.constructionCatalogSprite(
                forBuildingID: TradeRouteKind.sea.buildingID
            )?.imageID,
            OriginalBuildingSpriteCatalog.quayHouseImageIDs[.north]
        )

        for edge in QuayWaterEdge.allCases {
            let quay = OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: TradeRouteKind.sea.buildingID,
                quayWaterEdge: edge
            )
            XCTAssertEqual(quay.count, 6)
            XCTAssertEqual(
                quay.filter {
                    $0.sprite.imageID == OriginalBuildingSpriteCatalog.quayHouseImageIDs[edge]
                }.count,
                1
            )
            XCTAssertEqual(
                quay.filter {
                    $0.sprite.imageID == OriginalBuildingSpriteCatalog.quayDeckImageIDs[edge]
                }.count,
                5
            )
            let covered = quay.flatMap {
                $0.footprint.points(at: GridPoint(x: $0.tileOffsetX, y: $0.tileOffsetY))
            }
            XCTAssertEqual(covered.count, 9)
            XCTAssertEqual(
                Set(covered),
                Set(BuildingFootprint(width: 3, height: 3).points(at: GridPoint(x: 0, y: 0)))
            )
        }

        for orientation in IsometricBuildingOrientation.allCases {
            let market = OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: 59,
                orientation: orientation
            )
            XCTAssertEqual(
                market.filter {
                    $0.sprite.imageID == OriginalBuildingSpriteCatalog.foodShopImageID
                }.count,
                1
            )
            XCTAssertEqual(
                market.filter {
                    $0.sprite.imageID == OriginalBuildingSpriteCatalog.marketEntertainmentAreaImageID
                }.count,
                1
            )
            let expectedFootprint = BuildingFootprint(width: 7, height: 4).oriented(orientation)
            let covered = market.flatMap {
                $0.footprint.points(at: GridPoint(x: $0.tileOffsetX, y: $0.tileOffsetY))
            }
            XCTAssertEqual(covered.count, expectedFootprint.width * expectedFootprint.height)
            XCTAssertEqual(
                Set(covered),
                Set(expectedFootprint.points(at: GridPoint(x: 0, y: 0)))
            )
        }

        for (buildingID, canonical, expectedImageIDs) in [
            (209, BuildingFootprint(width: 4, height: 8), [[1_904, 1_905], [1_906, 1_907]]),
            (110, BuildingFootprint(width: 5, height: 10), [[1_930, 1_931], [1_932, 1_933]]),
        ] {
            for orientation in IsometricBuildingOrientation.allCases {
                let components = OriginalBuildingSpriteCatalog.buildingComponents(
                    forBuildingID: buildingID,
                    orientation: orientation
                )
                XCTAssertEqual(
                    components.map(\.sprite.imageID),
                    expectedImageIDs[orientation.rawValue]
                )
                let expected = canonical.oriented(orientation)
                XCTAssertEqual(
                    Set(components.flatMap {
                        $0.footprint.points(at: GridPoint(
                            x: $0.tileOffsetX,
                            y: $0.tileOffsetY
                        ))
                    }),
                    Set(expected.points(at: GridPoint(x: 0, y: 0)))
                )
            }
        }
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: 130,
                orientation: .northSouth
            ).map(\.sprite.imageID),
            Array(898...902)
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: 130,
                orientation: .eastWest
            ).map(\.sprite.imageID),
            Array(903...907)
        )
    }

    func testLocalPlacedBuildingSpriteCatalogMatchesOriginalArchive() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_General.sg3")
        )
        let pixels = try Data(
            contentsOf: source.dataDirectory.appendingPathComponent("China_General.555"),
            options: [.mappedIfSafe]
        )
        var expectedTileSpanByImageID: [Int: Int] = [:]
        for buildingID in OriginalBuildingSpriteCatalog.supportedPlacedBuildingIDs {
            for orientation in IsometricBuildingOrientation.allCases {
                for component in OriginalBuildingSpriteCatalog.buildingComponents(
                    forBuildingID: buildingID,
                    orientation: orientation
                ) {
                    XCTAssertEqual(component.footprint.width, component.footprint.height)
                    // Water lifts overhang the bank and the laborers' camp
                    // includes its surrounding work yard, so their authored
                    // bitmap width intentionally exceeds the occupied tiles.
                    if buildingID != 203, buildingID != 233,
                       component.sprite.archiveBaseName
                        == OriginalBuildingSpriteCatalog.generalArchiveBaseName {
                        expectedTileSpanByImageID[component.sprite.imageID]
                            = component.footprint.width
                    }
                }
            }
        }
        for edge in QuayWaterEdge.allCases {
            for component in OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: TradeRouteKind.sea.buildingID,
                quayWaterEdge: edge
            ) {
                expectedTileSpanByImageID[component.sprite.imageID] = component.footprint.width
            }
        }
        for (imageID, tileSpan) in expectedTileSpanByImageID {
            XCTAssertTrue(archive.images.indices.contains(imageID))
            let image = archive.images[imageID]
            XCTAssertEqual(image.type, 30, "image #\(imageID)")
            XCTAssertEqual(image.width, tileSpan * 80 - 2, "image #\(imageID)")
            let decoded = try SpriteDecoder.decode(image: image, pixelData: pixels)
            XCTAssertEqual(decoded.width, image.width)
            XCTAssertEqual(decoded.height, image.height)
            XCTAssertNotNil(decoded.makeCGImage())
        }
    }

    func testLocalEmperorMapImageGrid() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let map = try EmperorMap(url: source.citiesDirectory.appendingPathComponent("Erlitou.map"))
        XCTAssertEqual(map.formatVersion, 5)
        XCTAssertEqual(map.width, 112)
        XCTAssertEqual(map.height, 112)
        XCTAssertEqual(map.startOffset, 13_282)
        XCTAssertEqual(map.borderSize, 116)
        XCTAssertEqual(map.imageIDs.count, 228 * 228)
        XCTAssertEqual(map.edgeValues.count, 228 * 228)
        XCTAssertEqual(map.terrainFlags.count, 228 * 228)
        XCTAssertEqual(map.appealFlags.count, 228 * 228)
        XCTAssertEqual(map.legacyByteGrids.count, 13)
        XCTAssertEqual(map.authoredPoints.landEntry, GridPoint(x: 58, y: 108))
        XCTAssertEqual(map.authoredPoints.landExit, GridPoint(x: 41, y: 96))
        XCTAssertEqual(map.authoredPoints.seaEntry, GridPoint(x: 75, y: 92))
        XCTAssertEqual(map.authoredPoints.seaExit, GridPoint(x: 28, y: 27))
        XCTAssertEqual(
            map.authoredPoints.landInvasion,
            [
                GridPoint(x: 4, y: 59), GridPoint(x: 8, y: 48),
                GridPoint(x: 20, y: 36), GridPoint(x: 51, y: 5),
            ]
        )
        XCTAssertEqual(
            map.authoredLandInvasionPointSlots,
            [
                .init(slotIndex: 0, point: GridPoint(x: 4, y: 59)),
                .init(slotIndex: 1, point: GridPoint(x: 8, y: 48)),
                .init(slotIndex: 2, point: GridPoint(x: 20, y: 36)),
                .init(slotIndex: 3, point: GridPoint(x: 51, y: 5)),
                .init(slotIndex: 4, point: nil), .init(slotIndex: 5, point: nil),
                .init(slotIndex: 6, point: nil), .init(slotIndex: 7, point: nil),
            ]
        )
        XCTAssertTrue(map.authoredPoints.seaInvasion.isEmpty)
        XCTAssertEqual(
            map.authoredPoints.fishing,
            [GridPoint(x: 23, y: 54), GridPoint(x: 85, y: 26), GridPoint(x: 28, y: 88)]
        )
        let active = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x in map.imageID(x: x, y: y) }
        }
        XCTAssertTrue(active.contains(EmperorMap.chinaTerrainGlobalImageBase + 268))
        let activeTerrain = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x in map.terrainFlags(x: x, y: y) }
        }
        XCTAssertGreaterThan(Set(activeTerrain).count, 1)
        let activeAppealFlags = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x in map.appealFlagsValue(x: x, y: y) }
        }
        XCTAssertEqual(activeAppealFlags.count, map.width * map.height)

        let terrainArchive = try SG3Archive(contentsOf: source.dataDirectory.appendingPathComponent("China_Terrain.sg3"))
        let baseLandFlags = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x -> UInt32? in
                map.chinaTerrainSpriteID(x: x, y: y, imageCount: terrainArchive.images.count) == 268
                    ? map.terrainFlags(x: x, y: y) : nil
            }
        }
        XCTAssertFalse(baseLandFlags.isEmpty)
        XCTAssertEqual(Set(baseLandFlags), [TerrainFlags.groundwater.rawValue])

        let roadPoints = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x in
                map.terrain(at: GridPoint(x: x, y: y))?.contains(.road) == true ? GridPoint(x: x, y: y) : nil
            }
        }
        let adjacentRoadPair = roadPoints.lazy.compactMap { point -> (GridPoint, GridPoint)? in
            let candidates = [GridPoint(x: point.x + 1, y: point.y), GridPoint(x: point.x, y: point.y + 1)]
            return candidates.first(where: { map.terrain(at: $0)?.contains(.road) == true }).map { (point, $0) }
        }.first
        XCTAssertNotNil(adjacentRoadPair)
        if let pair = adjacentRoadPair {
            XCTAssertEqual(map.shortestRoadPath(from: pair.0, to: pair.1), [pair.0, pair.1])
        }

        let nativeTerrain = DeterministicTerrainState(map: map)
        XCTAssertEqual(nativeTerrain.width, 112)
        XCTAssertEqual(nativeTerrain.height, 112)
        XCTAssertEqual(nativeTerrain.terrainRawValues.count, 112 * 112)
        XCTAssertEqual(nativeTerrain.appealFlagsRawValues?.count, 112 * 112)
        XCTAssertEqual(nativeTerrain.roadPoints, Set(roadPoints))
        XCTAssertEqual(nativeTerrain.authoredPoints, map.authoredPoints)
        XCTAssertGreaterThan(nativeTerrain.waterTileCount, 0)
        XCTAssertGreaterThan(nativeTerrain.clearLandTileCount, 0)

        var city = DeterministicCityState(year: 1600, treasury: 2_000, map: map)
        XCTAssertEqual(city.roadNetwork.width, map.width)
        XCTAssertEqual(city.roadNetwork.height, map.height)
        XCTAssertEqual(city.roadNetwork.points, Set(roadPoints))
        let location = try XCTUnwrap(city.nextHouseConstructionLocation())
        XCTAssertTrue(nativeTerrain.isClearLand(location))
        XCTAssertTrue(
            RoadServiceCoverage.orthogonalNeighbors(of: location).contains(where: city.roadNetwork.contains)
        )
        XCTAssertTrue(city.canConstructHouse(at: location))
        XCTAssertTrue(city.canConstructRoad(at: location))
        let models = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: models)
        XCTAssertNotNil(
            city.constructHouse(
                location: location,
                orientation: .eastWest,
                rules: rules
            )
        )
        XCTAssertEqual(city.houses.first?.orientation, .eastWest)
        let treasuryAfterHouse = city.economy.treasury
        XCTAssertFalse(city.canConstructHouse(at: location))
        XCTAssertFalse(city.canConstructRoad(at: location))
        XCTAssertNil(city.constructHouse(location: location, rules: rules))
        XCTAssertNil(city.buildRoad([location], rules: rules))
        XCTAssertEqual(city.economy.treasury, treasuryAfterHouse)
        let water = try XCTUnwrap((0..<map.height).lazy.compactMap { y in
            (0..<map.width).lazy.compactMap { x -> GridPoint? in
                let point = GridPoint(x: x, y: y)
                return nativeTerrain.terrain(at: point)?.contains(.water) == true ? point : nil
            }.first
        }.first)
        XCTAssertNil(city.buildRoad([water], rules: rules))
        XCTAssertEqual(city.economy.treasury, treasuryAfterHouse)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testFormatV5RoadWaterAuxiliaryGridUsesFinalDecodedLayer() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let mapURL = source.citiesDirectory.appendingPathComponent("Xiangjun.map")
        let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
        let offset = try XCTUnwrap(
            EmperorMap.roadWaterAuxiliaryGridOffset(decodedByteCount: decoded.count)
        )
        XCTAssertEqual(offset, decoded.count - EmperorMap.gridCellCount)
        XCTAssertNotEqual(offset, 0x10AFE7)

        let map = try EmperorMap(url: mapURL)
        XCTAssertEqual(map.roadWaterAuxiliaryValues?.count, EmperorMap.gridCellCount)
        XCTAssertTrue(map.roadWaterAuxiliaryValues?.allSatisfy { $0 == 0 } == true)
    }

    func testQinMapBuildingArchivePreambleMatchesOriginalLoader() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let mapURL = source.citiesDirectory.appendingPathComponent("Xiangjun.map")
        let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
        let archiveOffset = EmperorMap.buildingArchiveTransitionOffset
        XCTAssertEqual(archiveOffset, 0x10AFE7)
        XCTAssertGreaterThanOrEqual(decoded.count, archiveOffset + 8)

        // FUN_0042D790 reads a schema WORD, then a DWORD object-slot count;
        // FUN_0077FD90 consumes the first object tag from the same archive.
        XCTAssertEqual(
            UInt16(decoded[archiveOffset]) | UInt16(decoded[archiveOffset + 1]) << 8,
            1
        )
        XCTAssertEqual(
            UInt32(decoded[archiveOffset + 2])
                | UInt32(decoded[archiveOffset + 3]) << 8
                | UInt32(decoded[archiveOffset + 4]) << 16
                | UInt32(decoded[archiveOffset + 5]) << 24,
            4_000
        )
        XCTAssertEqual(
            Array(decoded[archiveOffset + 6 ..< archiveOffset + 8]),
            [0xFF, 0xFF]
        )
    }

    func testQinMapFirstBuildingRecordUsesRecoveredVersionedBoundary() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expected: [(String, UInt16, Int)] = [
            ("Haunxian", 4, 201),
            ("Xianyang", 4, 201),
            ("Xiangjun", 3, 199),
            ("Badaling", 4, 201),
        ]
        for (name, schema, nextClassDelta) in expected {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let archiveOffset = EmperorMap.buildingArchiveTransitionOffset
            XCTAssertGreaterThanOrEqual(decoded.count, archiveOffset + nextClassDelta + 2)
            XCTAssertEqual(
                UInt16(decoded[archiveOffset + 20])
                    | UInt16(decoded[archiveOffset + 21]) << 8,
                schema,
                name
            )
            // The first record ends at the next MFC class declaration.  The
            // class name varies by map, but the new-class tag is stable.
            XCTAssertEqual(
                Array(decoded[archiveOffset + nextClassDelta ..< archiveOffset + nextClassDelta + 2]),
                [0xFF, 0xFF],
                name
            )
        }
    }

    func testQinMapsHaveNoExplicitServiceClassMarkerInBuildingArchive() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let serviceMarkers = [
            "Well", "cWell", "Herbalist", "cHerbalist",
            "Acupuncturist", "cAcupuncturist", "cMarket"
        ].map { Data($0.utf8) }
        for name in ["Haunxian", "Xianyang", "Xiangjun", "Badaling"] {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            for marker in serviceMarkers {
                XCTAssertNil(
                    decoded.range(of: marker),
                    "\(name) must not expose an explicit service-class marker \(String(decoding: marker, as: UTF8.self))"
                )
            }
        }
    }

    func testQinBuildingArchiveClassInventoryAndFirstTypeWords() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expected: [String: [(String, UInt16)]] = [
            "Xiangjun": [("Building", 0), ("cResWall", 90), ("cResGate", 105)],
            "Haunxian": [("Building", 0), ("cMonumentBldg", 83), ("cIndustrialBldg", 173)],
            "Xianyang": [("Building", 0), ("cIndustrialBldg", 173)],
            "Badaling": [("Building", 0), ("cMonumentBldg", 257), ("cFillBldg", 94)],
        ]

        func uint16(_ data: Data, at offset: Int) -> UInt16 {
            UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
        }

        for (name, classes) in expected {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let archiveOffset = EmperorMap.buildingArchiveTransitionOffset
            let archiveEnd = decoded.count - EmperorMap.gridCellCount
            var declaredClassNames = Set<String>()
            if archiveEnd > archiveOffset + 6 {
                for offset in archiveOffset ..< (archiveEnd - 6) {
                    guard decoded[offset] == 0xFF, decoded[offset + 1] == 0xFF else { continue }
                    let nameLength = Int(uint16(decoded, at: offset + 4))
                    guard (1 ... 64).contains(nameLength),
                          offset + 6 + nameLength <= archiveEnd else { continue }
                    let bytes = decoded[(offset + 6) ..< (offset + 6 + nameLength)]
                    guard bytes.allSatisfy({ (0x20 ... 0x7E).contains($0) }) else { continue }
                    declaredClassNames.insert(String(decoding: bytes, as: UTF8.self))
                }
            }
            XCTAssertEqual(
                declaredClassNames,
                Set(classes.map(\.0)),
                "\(name) valid MFC new-class declarations"
            )
            var searchStart = archiveOffset
            for (className, expectedTypeWord) in classes {
                let marker = Data(className.utf8)
                guard let classRange = decoded.range(
                    of: marker,
                    options: [],
                    in: searchStart ..< decoded.endIndex
                ) else {
                    XCTFail("\(name) is missing MFC class \(className)")
                    continue
                }
                let classStart = classRange.lowerBound
                XCTAssertGreaterThanOrEqual(classStart, archiveOffset + 6, name)
                XCTAssertEqual(
                    Array(decoded[(classStart - 6) ..< (classStart - 2)]),
                    [0xFF, 0xFF, 0x00, 0x00],
                    "\(name) \(className) MFC new-class header"
                )
                XCTAssertEqual(
                    Int(uint16(decoded, at: classStart - 2)),
                    marker.count,
                    "\(name) \(className) class-name length"
                )
                let schemaOffset = classStart + marker.count
                XCTAssertEqual(
                    uint16(decoded, at: schemaOffset),
                    name == "Xiangjun" ? 3 : 4,
                    "\(name) \(className) object schema"
                )

                // The recovered cMonumentBldg parser locates the base
                // building type word at class-name-end + 16.  Preserve this
                // as a raw archive assertion; the semantic mapping for
                // generic Building records remains deliberately unknown.
                let typeWordOffset = classStart + marker.count + 16
                XCTAssertEqual(
                    uint16(decoded, at: typeWordOffset),
                    expectedTypeWord,
                    "\(name) \(className) first base type word"
                )
                searchStart = classRange.upperBound
            }
        }
    }

    func testQinMapArchiveClassCatalogMatchesDeclaredClassesAndTypeWords() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expected: [String: [(String, UInt16)]] = [
            "Xiangjun": [("Building", 0), ("cResWall", 90), ("cResGate", 105)],
            "Haunxian": [("Building", 0), ("cMonumentBldg", 83), ("cIndustrialBldg", 173)],
            "Xianyang": [("Building", 0), ("cIndustrialBldg", 173)],
            "Badaling": [("Building", 0), ("cMonumentBldg", 257), ("cFillBldg", 94)],
        ]
        let forbiddenServiceClasses = Set([
            "Well", "cWell", "Herbalist", "cHerbalist",
            "Acupuncturist", "cAcupuncturist", "cMarket"
        ])

        for (name, classes) in expected {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let archiveOffset = EmperorMap.buildingArchiveTransitionOffset
            let archiveEnd = decoded.count - EmperorMap.gridCellCount
            let declarations = OriginalMapArchiveClassCatalog.declarations(
                in: decoded,
                archiveRange: archiveOffset..<archiveEnd
            )
            XCTAssertEqual(
                declarations.map(\.className),
                classes.map(\.0),
                "\(name) MFC class declarations"
            )
            XCTAssertEqual(
                declarations.map(\.firstTypeWord),
                classes.map(\.1),
                "\(name) MFC first type words"
            )
            XCTAssertTrue(
                declarations.allSatisfy { !forbiddenServiceClasses.contains($0.className) },
                "\(name) must not declare a service-provider class"
            )
            XCTAssertTrue(
                declarations.allSatisfy { $0.formatVersion == (name == "Xiangjun" ? 3 : 4) },
                "\(name) class declaration schema"
            )
        }
    }

    func testQinEmperorMapRetainsArchiveClassDeclarationsWithoutSpecializingObjects() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expected: [String: [(String, UInt16)]] = [
            "Xiangjun": [("Building", 0), ("cResWall", 90), ("cResGate", 105)],
            "Haunxian": [("Building", 0), ("cMonumentBldg", 83), ("cIndustrialBldg", 173)],
            "Xianyang": [("Building", 0), ("cIndustrialBldg", 173)],
            "Badaling": [("Building", 0), ("cMonumentBldg", 257), ("cFillBldg", 94)],
        ]

        for (name, classes) in expected {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let map = try EmperorMap(url: mapURL)
            let archiveEnd = decoded.count - EmperorMap.gridCellCount
            let declarations = OriginalMapArchiveClassCatalog.declarations(
                in: decoded,
                archiveRange: EmperorMap.buildingArchiveTransitionOffset..<archiveEnd
            )

            XCTAssertEqual(map.archiveClassDeclarations, declarations, name)
            XCTAssertEqual(
                map.archiveClassDeclarations.map(\.className),
                classes.map(\.0),
                "\(name) retained class inventory"
            )
            XCTAssertTrue(
                map.archiveClassDeclarations.allSatisfy {
                    !["Well", "cWell", "Herbalist", "cHerbalist",
                      "Acupuncturist", "cAcupuncturist", "cMarket"].contains($0.className)
                },
                "\(name) must not expose a service-provider class"
            )
        }
    }

    func testQinEmperorMapRetainsArchivePreambleEvidence() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        for name in ["Xiangjun", "Haunxian", "Xianyang", "Badaling"] {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let map = try EmperorMap(url: mapURL)
            let preamble = try XCTUnwrap(map.archivePreamble, name)
            XCTAssertEqual(
                preamble.archiveOffset,
                EmperorMap.buildingArchiveTransitionOffset,
                "(name) archive transition"
            )
            XCTAssertEqual(preamble.archiveSchema, 1, "(name) archive schema")
            XCTAssertEqual(preamble.objectSlotCount, 4_000, "(name) object slots")
            XCTAssertEqual(
                preamble.firstClassDeclarationOffset,
                EmperorMap.buildingArchiveTransitionOffset + 6,
                "(name) first class declaration"
            )
            XCTAssertEqual(preamble.firstClassName, "Building", "(name) first class")
        }
    }

    func testQinIndustrialArchiveRunIsMapInvasionPointsNotProductionBuildings() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expected: [String: [(GridPoint, Int)]] = [
            "Haunxian": [
                (GridPoint(x: 106, y: 37), 18_618),
                (GridPoint(x: 34, y: 37), 18_546),
                (GridPoint(x: 15, y: 56), 22_859),
                (GridPoint(x: 5, y: 75), 27_181),
            ],
            "Xianyang": [
                (GridPoint(x: 114, y: 4), 1_255),
            ],
            "Xiangjun": [],
            "Badaling": [],
        ]

        for (name, expectedRecords) in expected {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let map = try EmperorMap(url: mapURL)
            let records = OriginalMapInvasionPointArchiveCatalog.archivedStates(
                in: decoded,
                mapWidth: map.width,
                mapHeight: map.height
            )
            XCTAssertEqual(
                map.archivedMapInvasionPointStates,
                records,
                "EmperorMap exposes the same archive-only map-point run for \(name)"
            )
            XCTAssertEqual(
                records.map(\.buildingID),
                Array(repeating: 173, count: expectedRecords.count),
                name
            )
            XCTAssertEqual(records.count, expectedRecords.count, name)
            for (record, expectedRecord) in zip(records, expectedRecords) {
                XCTAssertEqual(record.worldOrigin, expectedRecord.0, name)
                XCTAssertEqual(record.mapCellIndex, expectedRecord.1, name)
            }
            XCTAssertTrue(records.allSatisfy {
                $0.className == "cIndustrialBldg" && $0.formatVersion == 4
            })
        }
    }

    func testQinInvasionArchiveOriginsAreDistinctFromHeaderSlots() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expectedHeaderPoints: [String: [GridPoint]] = [
            "Xiangjun": [
                GridPoint(x: 8, y: 77), GridPoint(x: 31, y: 100),
                GridPoint(x: 50, y: 119), GridPoint(x: 84, y: 124),
                GridPoint(x: 95, y: 113), GridPoint(x: 121, y: 87),
                GridPoint(x: 15, y: 55), GridPoint(x: 43, y: 27),
            ],
            "Haunxian": [
                GridPoint(x: 5, y: 74), GridPoint(x: 15, y: 55),
                GridPoint(x: 34, y: 36), GridPoint(x: 47, y: 23),
                GridPoint(x: 68, y: 2), GridPoint(x: 80, y: 11),
                GridPoint(x: 106, y: 37),
            ],
            "Xianyang": [
                GridPoint(x: 52, y: 163), GridPoint(x: 22, y: 134),
                GridPoint(x: 6, y: 109), GridPoint(x: 24, y: 89),
                GridPoint(x: 45, y: 68), GridPoint(x: 82, y: 31),
                GridPoint(x: 97, y: 16), GridPoint(x: 114, y: 4),
            ],
            "Badaling": [
                GridPoint(x: 38, y: 122), GridPoint(x: 28, y: 112),
                GridPoint(x: 10, y: 94), GridPoint(x: 8, y: 77),
                GridPoint(x: 21, y: 64), GridPoint(x: 36, y: 49),
            ],
        ]
        for name in ["Xiangjun", "Haunxian", "Xianyang", "Badaling"] {
            let map = try EmperorMap(
                url: source.citiesDirectory.appendingPathComponent(name + ".map")
            )
            XCTAssertEqual(
                map.authoredLandInvasionPointSlots.compactMap(\.point),
                expectedHeaderPoints[name],
                "\(name) header slot order"
            )
            XCTAssertEqual(
                map.authoredPoints.landInvasion,
                expectedHeaderPoints[name],
                "\(name) header invasion points"
            )
            XCTAssertTrue(
                map.archivedMapInvasionPointStates.allSatisfy { $0.className == "cIndustrialBldg" },
                "\(name) archive class remains cIndustrialBldg evidence"
            )
            XCTAssertNotEqual(
                map.archivedMapInvasionPointStates.map(\.worldOrigin),
                map.authoredPoints.landInvasion,
                "\(name) archive records are a distinct source region"
            )
        }
    }

    func testOriginalMapInvasionPointSlotCatalogPreservesEightSlotValidityAndScanOrder() {
        XCTAssertEqual(OriginalMapInvasionPointSlotCatalog.slotCount, 8)
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.circularScanOrder(startingAtZeroBased: 6),
            [6, 7, 0, 1, 2, 3, 4, 5]
        )
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.circularScanOrder(startingAtZeroBased: -1),
            []
        )
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.slotStates(
                xCoordinates: [106, 34, 15, 5, nil, nil, nil, nil],
                yCoordinates: [37, 37, 56, 75, nil, nil, nil, nil]
            ),
            [
                .init(slotIndex: 0, point: GridPoint(x: 106, y: 37)),
                .init(slotIndex: 1, point: GridPoint(x: 34, y: 37)),
                .init(slotIndex: 2, point: GridPoint(x: 15, y: 56)),
                .init(slotIndex: 3, point: GridPoint(x: 5, y: 75)),
                .init(slotIndex: 4, point: nil), .init(slotIndex: 5, point: nil),
                .init(slotIndex: 6, point: nil), .init(slotIndex: 7, point: nil),
            ]
        )
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.slotStates(
                xCoordinates: [1, nil, 3, nil, nil, nil, nil, nil],
                yCoordinates: [2, 2, nil, nil, nil, nil, nil, nil]
            ).compactMap(\.point),
            [GridPoint(x: 1, y: 2)]
        )
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.slotStates(
                xCoordinates: [1, 2], yCoordinates: [1, 2]
            ),
            []
        )
    }

    func testOriginalExecutableRandomStateMatchesRecoveredLFSRTransition() {
        var state = OriginalExecutableRandomState()
        let first = state.advance()
        XCTAssertEqual(first.stateA, 0x2923_21ef)
        XCTAssertEqual(first.stateB, 0x5d42_5705)
        XCTAssertEqual(first.low15, 8_687)
        XCTAssertEqual(first.lowByte, 111)
        XCTAssertEqual(first.low3, 7)
        XCTAssertEqual(first.secondaryLow15, 22_277)
        XCTAssertEqual(state.historyIndex, 1)
        XCTAssertEqual(state.history[0], 0)

        let second = state.advance()
        XCTAssertEqual(second.stateA, 0x23b1_13f1)
        XCTAssertEqual(second.stateB, 0x7096_7275)
        XCTAssertEqual(second.low15, 5_105)
        XCTAssertEqual(second.lowByte, 113)
        XCTAssertEqual(state.history[1], 111)
    }

    func testOriginalExecutableRandomStartupAppliesExactHundredCallWarmup() {
        var explicit = OriginalExecutableRandomState()
        for _ in 0..<OriginalExecutableRandomState.historyCapacity {
            explicit.advance()
        }
        XCTAssertEqual(explicit, .startup())
        XCTAssertEqual(explicit.historyIndex, 0)
        XCTAssertEqual(explicit.stateA, 0x0028_db70)
        XCTAssertEqual(explicit.stateB, 0x298b_8960)
        XCTAssertEqual(explicit.low15, 23_408)
        XCTAssertEqual(explicit.lowByte, 112)
        XCTAssertEqual(explicit.low3, 0)
        XCTAssertEqual(explicit.secondaryLow15, 2_400)
    }

    func testQinGenericBuildingArchiveRecordsKeepZeroBaseTypeWord() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expectedGenericRecordCounts: [String: Int] = [
            "Xiangjun": 3_956,
            "Haunxian": 3_962,
            "Xianyang": 3_998,
            "Badaling": 3_906,
        ]

        func uint16(_ data: Data, at offset: Int) -> UInt16 {
            UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
        }

        for (name, expectedCount) in expectedGenericRecordCounts {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let archiveOffset = EmperorMap.buildingArchiveTransitionOffset
            let archiveEnd = decoded.count - EmperorMap.gridCellCount
            var genericRecordOffsets: [Int] = []
            for offset in archiveOffset ..< (archiveEnd - 24) {
                guard decoded[offset] == 0x01, decoded[offset + 1] == 0x80 else {
                    continue
                }
                let schema = uint16(decoded, at: offset + 2)
                guard schema == 3 || schema == 4 else { continue }
                genericRecordOffsets.append(offset)
            }
            XCTAssertEqual(
                genericRecordOffsets.count,
                expectedCount,
                "\(name) generic Building record count"
            )
            XCTAssertTrue(
                genericRecordOffsets.allSatisfy {
                    // Four bytes (stream token + schema) precede the packed
                    // field stream; object +0x14 is the 14th packed payload
                    // byte, hence stream offset +18.
                    uint16(decoded, at: $0 + 18) == 0
                },
                "\(name) generic Building records must keep a zero base type word"
            )
        }
    }

    func testQinGenericBuildingArchiveRecordsKeepUnboundProviderRegistrySlot() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()

        func uint16(_ data: Data, at offset: Int) -> UInt16 {
            UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
        }

        // FUN_00427430's generic read branches consume a 20-byte common tail:
        // +0xB4 (DWORD registry slot) followed by +0xB8 (16 bytes).  The
        // schema-specific payload is 157 bytes for schema 3 and 159 bytes
        // for schema 4, so a complete 0x8001 record is 181/183 bytes from
        // its two-byte stream token to the next record.
        let expectedGenericRecordCounts: [String: Int] = [
            "Xiangjun": 3_956,
            "Haunxian": 3_962,
            "Xianyang": 3_998,
            "Badaling": 3_906,
        ]
        for (name, expectedCount) in expectedGenericRecordCounts {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let archiveOffset = EmperorMap.buildingArchiveTransitionOffset
            let archiveEnd = decoded.count - EmperorMap.gridCellCount
            var genericRecordOffsets: [Int] = []
            for offset in archiveOffset ..< (archiveEnd - 24) {
                guard decoded[offset] == 0x01, decoded[offset + 1] == 0x80 else {
                    continue
                }
                let schema = uint16(decoded, at: offset + 2)
                guard schema == 3 || schema == 4 else { continue }
                genericRecordOffsets.append(offset)
            }
            XCTAssertEqual(
                genericRecordOffsets.count,
                expectedCount,
                "\(name) generic Building record count"
            )
            for offset in genericRecordOffsets {
                let schema = uint16(decoded, at: offset + 2)
                let recordLength = schema == 3 ? 181 : 183
                let tailStart = offset + recordLength - 20
                XCTAssertLessThanOrEqual(tailStart + 20, archiveEnd, "\(name) record tail")
                XCTAssertEqual(
                    UInt32(decoded[tailStart])
                        | UInt32(decoded[tailStart + 1]) << 8
                        | UInt32(decoded[tailStart + 2]) << 16
                        | UInt32(decoded[tailStart + 3]) << 24,
                    UInt32.max,
                    "\(name) generic Building provider slot must remain -1"
                )
            }
        }
    }

    func testQinGenericBuildingArchiveCatalogMatchesRecoveredRecordLayout() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let expectedGenericRecordCounts: [String: Int] = [
            "Xiangjun": 3_956,
            "Haunxian": 3_962,
            "Xianyang": 3_998,
            "Badaling": 3_906,
        ]

        for (name, expectedCount) in expectedGenericRecordCounts {
            let mapURL = source.citiesDirectory.appendingPathComponent(name + ".map")
            let decoded = try SierraChunkedFile(contentsOf: mapURL).decodedData
            let archiveOffset = EmperorMap.buildingArchiveTransitionOffset
            let archiveEnd = decoded.count - EmperorMap.gridCellCount
            let records = OriginalGenericBuildingArchiveCatalog.records(
                in: decoded,
                archiveRange: archiveOffset..<archiveEnd
            )
            XCTAssertEqual(records.count, expectedCount, "\(name) generic archive records")
            XCTAssertTrue(
                records.allSatisfy {
                    $0.baseTypeWord == 0
                        && $0.providerRegistrySlot == -1
                        && $0.serializedLoadEligibilityByte == 0
                        && $0.serializedHousePopulationEligibilityByte == 0
                        && $0.serializedMapCellWord == 0
                },
                "\(name) generic records retain zero base type, both eligibility bytes, and provider slot"
            )
            XCTAssertTrue(
                records.allSatisfy {
                    ($0.formatVersion == 3 && $0.recordLength == 181)
                        || ($0.formatVersion == 4 && $0.recordLength == 183)
                },
                "\(name) generic record stride follows FUN_00427430 schema branches"
            )
            XCTAssertTrue(
                records.allSatisfy {
                    $0.serializedCoordinateX == 0
                        && $0.serializedCoordinateY == 0
                        && $0.serializedPlacementValue == 0
                },
                "\(name) generic records contain zero serialized coordinates and placement result"
            )
            XCTAssertTrue(
                records.allSatisfy {
                    !OriginalMapLoaderRehydrationCatalog.rehydrates(
                        genericRecord: $0
                    )
                },
                "\(name) generic records are not in FUN_0052F030's rehydration whitelist"
            )

            // EmperorMap now retains the same source rows for the eventual
            // Qin object bridge. Keep this assertion independent from any
            // runtime projection: the loaded city must expose the exact
            // archive evidence while preserving the fail-closed provider
            // boundary.
            let map = try EmperorMap(url: mapURL)
            XCTAssertEqual(
                map.genericBuildingArchiveRecords,
                records,
                "\(name) map-owned generic archive rows"
            )
        }
    }

    func testOriginalMapLoaderRehydrationCatalogMatchesFUN0052F1D0Whitelist() {
        XCTAssertTrue(OriginalMapLoaderRehydrationCatalog.rehydrates(modelID: 0x53))
        XCTAssertTrue(OriginalMapLoaderRehydrationCatalog.rehydrates(modelID: 0x10C))
        XCTAssertFalse(OriginalMapLoaderRehydrationCatalog.rehydrates(modelID: 0x52))
        XCTAssertFalse(OriginalMapLoaderRehydrationCatalog.rehydrates(modelID: 0x10D))
        XCTAssertEqual(OriginalMapLoaderRehydrationCatalog.modelIDs.count, 30)

        XCTAssertEqual(OriginalHouseBldgFactoryCatalog.modelIDs, Set(2...17))
        XCTAssertTrue(
            (2...17).allSatisfy {
                OriginalHouseBldgFactoryCatalog.createsHouseBldg(modelID: $0)
            }
        )
        XCTAssertFalse(OriginalHouseBldgFactoryCatalog.createsHouseBldg(modelID: 1))
        XCTAssertFalse(OriginalHouseBldgFactoryCatalog.createsHouseBldg(modelID: 18))
        XCTAssertFalse(
            (2...17).contains {
                OriginalMapLoaderRehydrationCatalog.rehydrates(modelID: $0)
            }
        )
        XCTAssertEqual(OriginalHouseBldgFactoryCatalog.creationSetterAddress, 0x00428AA0)
        XCTAssertEqual(OriginalHouseBldgFactoryCatalog.creationSetterVTableSlot, 0x94)
        XCTAssertEqual(OriginalHouseBldgFactoryCatalog.eligibilityInitializerAddress, 0x00518B70)
        XCTAssertEqual(OriginalHouseBldgFactoryCatalog.eligibilityInitializerVTableSlot, 0x90)
    }

    func testOriginalPrimaryMapCacheCatalogMatchesCanonicalDirectCallCensus() {
        XCTAssertEqual(OriginalPrimaryMapCacheCatalog.rebuildAddress, 0x005AD440)
        XCTAssertEqual(OriginalPrimaryMapCacheCatalog.fullMapRebuildAddress, 0x005AD8F0)
        XCTAssertEqual(OriginalPrimaryMapCacheCatalog.cacheBaseAddress, 0x013789C0)
        XCTAssertEqual(OriginalPrimaryMapCacheCatalog.cacheRowStride, 0xE4)
        XCTAssertEqual(
            OriginalPrimaryMapCacheCatalog.directCallSites,
            [
                0x00415A9A, 0x00415F2D, 0x0042A940, 0x0042BB81, 0x0042BCBE,
                0x004AD39B, 0x004B170C, 0x004B299F, 0x004BE1F7, 0x004BE36F,
                0x004EC5D3, 0x004EC7E4, 0x005432FA, 0x005AD90A, 0x005E22BC,
            ]
        )
        XCTAssertEqual(
            OriginalPrimaryMapCacheCatalog.directCallerAddresses,
            [
                0x004158D0, 0x00415E30, 0x0042A5A0, 0x0042BA40, 0x0042BBD0,
                0x004AD260, 0x004B1250, 0x004B2680, 0x004BDF30, 0x004BE270,
                0x004EC4A0, 0x004EC4A0, 0x005431C0, 0x005AD8F0, 0x005E20F0,
            ]
        )
    }

    func testGenericBuildingArchivePackedFieldOffsetsFollowSerializerOrder() {
        func put16(_ value: Int16, into data: inout Data, at offset: Int) {
            let bits = UInt16(bitPattern: value)
            data[offset] = UInt8(bits & 0xFF)
            data[offset + 1] = UInt8(bits >> 8)
        }
        func put32(_ value: Int32, into data: inout Data, at offset: Int) {
            let bits = UInt32(bitPattern: value)
            data[offset] = UInt8(bits & 0xFF)
            data[offset + 1] = UInt8((bits >> 8) & 0xFF)
            data[offset + 2] = UInt8((bits >> 16) & 0xFF)
            data[offset + 3] = UInt8(bits >> 24)
        }

        var schema3 = Data(repeating: 0, count: 181)
        schema3[0] = 0x01
        schema3[1] = 0x80
        schema3[2] = 0x03
        schema3[OriginalGenericBuildingArchiveCatalog.loadEligibilityByteOffset] = 7
        schema3[14] = 0x78
        schema3[15] = 0x56
        schema3[16] = 0x34
        schema3[17] = 0x12
        put16(-7, into: &schema3, at: OriginalGenericBuildingArchiveCatalog.coordinateXOffset)
        put16(11, into: &schema3, at: OriginalGenericBuildingArchiveCatalog.coordinateYOffset)
        put32(-3, into: &schema3, at: OriginalGenericBuildingArchiveCatalog.placementValueOffsetSchema3)
        put32(-1, into: &schema3, at: schema3.count - OriginalGenericBuildingArchiveCatalog.commonTailLength)

        var schema4 = Data(repeating: 0, count: 183)
        schema4[0] = 0x01
        schema4[1] = 0x80
        schema4[2] = 0x04
        schema4[OriginalGenericBuildingArchiveCatalog.loadEligibilityByteOffset] = 9
        schema4[14] = 0xEF
        schema4[15] = 0xCD
        schema4[16] = 0xAB
        schema4[17] = 0x90
        put16(13, into: &schema4, at: OriginalGenericBuildingArchiveCatalog.coordinateXOffset)
        put16(-17, into: &schema4, at: OriginalGenericBuildingArchiveCatalog.coordinateYOffset)
        put32(5, into: &schema4, at: OriginalGenericBuildingArchiveCatalog.placementValueOffsetSchema4)
        put32(-1, into: &schema4, at: schema4.count - OriginalGenericBuildingArchiveCatalog.commonTailLength)

        let records3 = OriginalGenericBuildingArchiveCatalog.records(
            in: schema3,
            archiveRange: 0..<schema3.count
        )
        XCTAssertEqual(records3.count, 1)
        XCTAssertEqual(records3[0].baseTypeWord, 0)
        XCTAssertEqual(records3[0].serializedLoadEligibilityByte, 7)
        XCTAssertEqual(records3[0].serializedMapCellWord, 0x12345678)
        XCTAssertEqual(records3[0].serializedCoordinateX, -7)
        XCTAssertEqual(records3[0].serializedCoordinateY, 11)
        XCTAssertEqual(records3[0].serializedPlacementValue, -3)
        XCTAssertEqual(records3[0].providerRegistrySlot, -1)

        let records4 = OriginalGenericBuildingArchiveCatalog.records(
            in: schema4,
            archiveRange: 0..<schema4.count
        )
        XCTAssertEqual(records4.count, 1)
        XCTAssertEqual(records4[0].baseTypeWord, 0)
        XCTAssertEqual(records4[0].serializedLoadEligibilityByte, 9)
        XCTAssertEqual(records4[0].serializedMapCellWord, 0x90ABCDEF)
        XCTAssertEqual(records4[0].serializedCoordinateX, 13)
        XCTAssertEqual(records4[0].serializedCoordinateY, -17)
        XCTAssertEqual(records4[0].serializedPlacementValue, 5)
        XCTAssertEqual(records4[0].providerRegistrySlot, -1)
    }

    func testXiangjunResidentialBarrierArchiveRecordsUseSpecializedRuns() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let map = try EmperorMap(
            url: source.citiesDirectory.appendingPathComponent("Xiangjun.map")
        )

        // cResWall contributes 27 model-90 records and cResGate contributes
        // one model-105 gate followed by 15 model-90 barrier records.  The
        // coordinates are read from the common serializer's confirmed
        // origin fields; no provider or collision behavior is implied.
        XCTAssertEqual(map.residentialBarrierStates.count, 43)
        XCTAssertEqual(
            map.residentialBarrierStates.prefix(27).map(\.className),
            Array(repeating: "cResWall", count: 27)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.suffix(16).map(\.className),
            Array(repeating: "cResGate", count: 16)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.prefix(27).map(\.buildingID),
            Array(repeating: 90, count: 27)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.suffix(16).map(\.buildingID),
            [105] + Array(repeating: 90, count: 15)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.map(\.serializedRegistryIndex),
            Array(1...43),
            "specialized wall/gate records preserve serialized +0xB4 slots"
        )
        XCTAssertEqual(
            map.residentialBarrierStates.map(\.serializedFootprintSide),
            Array(repeating: 1, count: 43),
            "cResWall/cResGate object +0x07 is the one-cell grid-writer side"
        )
        XCTAssertEqual(
            map.residentialBarrierStates.map(\.serializedLoadEligibilityByte),
            Array(repeating: UInt8(3), count: 43),
            "specialized wall/gate records enter the original +0xC0 load callback"
        )
        let descriptor = try XCTUnwrap(map.originalRuntimeDescriptor)
        XCTAssertTrue(
            map.residentialBarrierStates.allSatisfy { state in
                state.mapCellIndex == descriptor.baseLinearOffset
                    + state.worldOrigin.y * OriginalMapObjectGridProjection.mapRowStride
                    + state.worldOrigin.x
            },
            "barrier map-cell words use the selected 140x140 runtime base/stride"
        )
        XCTAssertEqual(
            map.residentialBarrierStates.prefix(27).first?.worldOrigin,
            GridPoint(x: 74, y: 68)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.prefix(27).last?.worldOrigin,
            GridPoint(x: 92, y: 80)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.suffix(16).first?.worldOrigin,
            GridPoint(x: 93, y: 80)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.suffix(16).last?.worldOrigin,
            GridPoint(x: 96, y: 65)
        )
        XCTAssertEqual(
            map.residentialBarrierStates.first?.rawWordAfterBuildingID,
            0x9F00
        )
        XCTAssertEqual(
            map.residentialBarrierStates.last?.rawWordAfterBuildingID,
            0xC900
        )
    }

    func testResidentialBarrierLoadCallbacksMatchCanonicalVtables() {
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.wallVTableAddress,
            0x007AAAB8
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.gateVTableAddress,
            0x007AAFB0
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.loadCallbackAddress,
            0x0051CB80
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.wallAuxiliaryRefreshAddress,
            0x0051CC10
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.gateAuxiliaryRefreshAddress,
            0x0051CC10
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.postLoadCallbackAddress,
            0x00415AD0
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.postLoadCallbackVTableSlot,
            0x1C8
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCallbackAddress,
            0x004153B0
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCallbackVTableSlot,
            0x270
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCallbackArguments.0,
            0
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCallbackArguments.1,
            0
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCompletionAddress,
            0x004E1C40
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCompletionVTableSlot,
            0x268
        )
        XCTAssertTrue(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCompletionReturnsTrue
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCompletionStateBitMask,
            0x04
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCompletionStateIndexFieldOffset,
            0x10
        )
        XCTAssertTrue(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedCompletionStateIndexIsMapCell
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedGridWriterAddress,
            0x004B72B0
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedOverlayFlags(forBuildingID: 90),
            0x48
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedOverlayFlags(forBuildingID: 105),
            0x08
        )
        XCTAssertNil(
            OriginalResidentialBarrierLoadLifecycleCatalog.connectedOverlayFlags(forBuildingID: 89),
            "unsupported model branches remain unprojected"
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.auxiliaryRefreshInitializerAddress,
            0x00418E80
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.registrySlotAccessorAddress,
            0x0047F1B0
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.auxiliaryAllocationSize,
            0x20
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.auxiliaryStoredInputOffset,
            0x14
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.objectAuxiliaryFieldOffset,
            0x14C
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.auxiliaryRegistryInputOffset,
            0x14
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.loadEligibilityFieldOffset,
            0x04
        )
        XCTAssertEqual(
            OriginalResidentialBarrierLoadLifecycleCatalog.registryInputFieldOffset,
            0xB4
        )
        XCTAssertFalse(
            OriginalResidentialBarrierLoadLifecycleCatalog.invokesLoadCallback(
                eligibilityByte: 0
            )
        )
        XCTAssertTrue(
            OriginalResidentialBarrierLoadLifecycleCatalog.invokesLoadCallback(
                eligibilityByte: 3
            )
        )
    }

    func testOriginalMapRuntimeDescriptorCatalogUsesCanonicalBackingGrid() {
        let expected: [(Int, Int)] = [
            (56, 19_694), (84, 16_488), (112, 13_282),
            (140, 10_076), (170, 6_641), (226, 229),
        ]

        XCTAssertEqual(OriginalMapRuntimeDescriptorCatalog.rows.count, expected.count)
        for (descriptor, (side, base)) in zip(
            OriginalMapRuntimeDescriptorCatalog.rows,
            expected
        ) {
            XCTAssertEqual(descriptor.width, side)
            XCTAssertEqual(descriptor.height, side)
            XCTAssertEqual(descriptor.baseLinearOffset, base)
            XCTAssertEqual(descriptor.rowAdvance, EmperorMap.gridSide - side)
            XCTAssertEqual(descriptor.effectiveRowStride, EmperorMap.gridSide)
        }
        XCTAssertNil(OriginalMapRuntimeDescriptorCatalog.descriptor(width: 55, height: 55))
    }

    func testZhengzhouDirectElevationLayerResolvesToOriginalSprites() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let map = try EmperorMap(
            url: source.citiesDirectory.appendingPathComponent("Zhengzhou.map")
        )
        let archive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_Elevation.sg3")
        )
        let highGroundPoints = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x -> GridPoint? in
                map.terrain(at: GridPoint(x: x, y: y))?.contains(.elevation) == true
                    ? GridPoint(x: x, y: y) : nil
            }
        }
        XCTAssertEqual(highGroundPoints.count, 189)
        let spriteIDs = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x in
                map.localSpriteID(
                    x: x,
                    y: y,
                    globalImageBase: EmperorMap.chinaElevationGlobalImageBase,
                    imageCount: archive.images.count
                )
            }
        }
        XCTAssertEqual(spriteIDs.count, 181)
        XCTAssertEqual(
            Set(spriteIDs),
            Set([201] + Array(225...239) + Array(243...246) + [249])
        )
        XCTAssertEqual(spriteIDs.count { $0 == 201 }, 32)
    }

    func testAuthoredDirtElevationGreatWallAndCanalSpriteIntervals() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()

        let dirtMap = try EmperorMap(
            url: source.citiesDirectory.appendingPathComponent("MPWall3_S.map")
        )
        let dirtArchive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_Elevation_dirt.sg3")
        )
        let dirtIDs = (0..<dirtMap.height).flatMap { y in
            (0..<dirtMap.width).compactMap { x in
                dirtMap.chinaElevationDirtSpriteID(
                    x: x,
                    y: y,
                    imageCount: dirtArchive.images.count
                )
            }
        }
        XCTAssertEqual(dirtIDs.count, 10)
        XCTAssertEqual(Set(dirtIDs), [201, 203, 205, 207])

        let wallMap = try EmperorMap(
            url: source.citiesDirectory.appendingPathComponent("Badaling.map")
        )
        let wallArchive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_Mon_GreatWall_1.sg3")
        )
        let wallIDs = (0..<wallMap.height).flatMap { y in
            (0..<wallMap.width).compactMap { x in
                wallMap.chinaGreatWall1SpriteID(
                    x: x,
                    y: y,
                    imageCount: wallArchive.images.count
                )
            }
        }
        XCTAssertEqual(wallIDs.count, 40)
        XCTAssertEqual(Set(wallIDs), Set(201...216))
        let earthenWallArchive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent(
                "China_Mon_Earthen_Greatwall_1.sg3"
            )
        )
        let earthenWallIDs = (0..<wallMap.height).flatMap { y in
            (0..<wallMap.width).compactMap { x in
                wallMap.chinaEarthenGreatWall1SpriteID(
                    x: x,
                    y: y,
                    imageCount: earthenWallArchive.images.count
                )
            }
        }
        XCTAssertGreaterThan(earthenWallIDs.count, 700)
        XCTAssertTrue(Set(earthenWallIDs).isSubset(of: Set(earthenWallArchive.images.indices)))

        let canalMap = try EmperorMap(
            url: source.citiesDirectory.appendingPathComponent("MPcanal1.map")
        )
        let canalArchive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_Mon_Grand_Canal.sg3")
        )
        let canalIDs = (0..<canalMap.height).flatMap { y in
            (0..<canalMap.width).compactMap { x in
                canalMap.chinaGrandCanalSpriteID(
                    x: x,
                    y: y,
                    imageCount: canalArchive.images.count
                )
            }
        }
        XCTAssertEqual(canalIDs.count, 528)
        XCTAssertEqual(Set(canalIDs), [201])
    }

    func testLocalOriginalEconomyModels() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let models = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: models)

        XCTAssertEqual(models.trade.prices["Silk"], 225)
        XCTAssertEqual(models.trade.commodities.count, 29)
        XCTAssertEqual(models.trade[commodityID: 25]?.name, "Ceramics")
        XCTAssertEqual(models.trade[commodityID: 25]?.price, 75)
        XCTAssertEqual(models.trade.landCapacity, 800)
        XCTAssertEqual(models.trade.seaCapacity, 1_200)
        XCTAssertEqual(models.buildings.buildings.count, 269)
        XCTAssertEqual(models.buildings.houses.count, 15)
        XCTAssertEqual(models.buildings.houseDifficultyModifiers.count, 5)
        XCTAssertEqual(models.buildings.houses.first?.name, "1: Shelter")
        XCTAssertEqual(models.buildings.houses.first?.populationCapacity, 7)
        XCTAssertEqual(models.buildings.houses[7].taxRateMultiplier, 2)
        XCTAssertEqual(models.buildings.houses.last?.populationCapacity, 25)
        XCTAssertEqual(models.buildings.houses.last?.taxRateMultiplier, 24)
        XCTAssertGreaterThan(models.figures.figures.count, 80)
        XCTAssertEqual(models.figures[figureID: 27]?.name, "Tax Official")
        XCTAssertEqual(models.figures[figureID: 27]?.speed, 8)
        XCTAssertEqual(models.figures[figureID: 27]?.behaviorRange, 40)
        XCTAssertEqual(models.buildings[buildingID: 125]?.name, "Tax Office")
        XCTAssertEqual(models.buildings[buildingID: 125]?.employees, 8)
        let hazards = OriginalBuildingHazardRules(configuration: models.generalBuilding)
        XCTAssertEqual(hazards.fireRiskMultiplier, 5)
        XCTAssertEqual(hazards.fireCheckFrequency, 4)
        XCTAssertEqual(hazards.fireRiskLimit, 1_000)
        XCTAssertEqual(hazards.burnDamage, 100)
        XCTAssertEqual(hazards.fireDamageMultiplier, 10)
        XCTAssertEqual(hazards.collapseRiskLimit, 1_000)
        XCTAssertEqual(
            models.buildings.difficultyModifiers.map { $0.values[6] },
            [50, 80, 100, 120, 150]
        )
        XCTAssertEqual(
            models.buildings.difficultyModifiers.map { $0.values[7] },
            [50, 80, 100, 120, 150]
        )
        XCTAssertEqual(rules.constructionCost(buildingID: 125, difficulty: .veryEasy), 20)
        XCTAssertEqual(rules.constructionCost(buildingID: 125, difficulty: .normal), 40)
        XCTAssertEqual(rules.constructionCost(buildingID: 125, difficulty: .veryHard), 60)
        XCTAssertEqual(rules.taxRatePercent(bandID: 3), 9)
        XCTAssertEqual(rules.taxSentiment(bandID: 3, difficulty: .normal), -1)
        XCTAssertEqual(rules.taxSentiment(bandID: 6, difficulty: .veryHard), -6)
        XCTAssertEqual(rules.taxSentiment(bandID: 6, difficulty: .veryHard, hasMeaningfulCoverage: false), 0)

        var firstRun = DeterministicEconomyState(treasury: 100)
        var secondRun = DeterministicEconomyState(treasury: 100)
        XCTAssertTrue(firstRun.spendOnConstruction(buildingID: 125, rules: rules, difficulty: .normal))
        XCTAssertTrue(secondRun.spendOnConstruction(buildingID: 125, rules: rules, difficulty: .normal))
        firstRun.add(resource: "Silk", amount: 4)
        secondRun.add(resource: "Silk", amount: 4)
        XCTAssertEqual(firstRun, secondRun)
        XCTAssertEqual(firstRun.treasury, 60)
        XCTAssertEqual(firstRun.inventory["Silk"], 4)
    }

    func testLocalOriginalAudioCatalogResolvesNativePlayableFiles() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let audio = try OriginalAudioCatalog(source: .openDefault())
        XCTAssertEqual(audio.music.filter { $0.category == .general }.count, 12)
        XCTAssertEqual(audio.music.filter { $0.category == .combat }.count, 4)
        XCTAssertEqual(audio.buildingSounds.count, 127)
        XCTAssertEqual(audio.sound(forBuildingID: 43)?.url.lastPathComponent, "Kiln2.wav")
        XCTAssertEqual(audio.sound(forBuildingID: 12)?.volume, 0.5)
        XCTAssertTrue(audio.music.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
        XCTAssertTrue(audio.buildingSounds.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }

    func testDeterministicMonthlyPopulationAndTaxSettlement() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var first = DeterministicCityState(year: 1600, treasury: 1_000, taxBandID: 3)
        var second = first

        let commonID = first.addHouse(
            levelID: 2,
            residents: 22,
            hasTaxCoverage: true,
            models: original.buildings
        )
        _ = first.addHouse(
            levelID: 14,
            residents: 25,
            hasTaxCoverage: true,
            models: original.buildings
        )
        _ = second.addHouse(
            levelID: 2,
            residents: 22,
            hasTaxCoverage: true,
            models: original.buildings
        )
        _ = second.addHouse(
            levelID: 14,
            residents: 25,
            hasTaxCoverage: true,
            models: original.buildings
        )

        XCTAssertEqual(commonID, 1)
        XCTAssertEqual(first.population, 47)
        XCTAssertEqual(first.housingCapacity(using: original.buildings), 47)
        let firstLedger = first.advanceMonth(rules: rules)
        let secondLedger = second.advanceMonth(rules: rules)
        XCTAssertEqual(firstLedger, secondLedger)
        XCTAssertEqual(first, second)
        XCTAssertEqual(firstLedger.collectedTaxes, 27)
        XCTAssertEqual(firstLedger.taxSentiment, -1)
        XCTAssertEqual(first.economy.treasury, 1_027)
        XCTAssertEqual(first.calendar, SimulationCalendar(year: 1600, month: 2))
    }

    func testMonthlyTaxSentimentUsesOriginalElevenPercentCoverageFloor() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)

        var exactlyTenPercent = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            taxBandID: 3
        )
        _ = exactlyTenPercent.addHouse(
            levelID: 2,
            residents: 1,
            hasTaxCoverage: true,
            models: original.buildings
        )
        _ = exactlyTenPercent.addHouse(
            levelID: 2,
            residents: 9,
            hasTaxCoverage: false,
            models: original.buildings
        )

        var elevenPercent = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            taxBandID: 3
        )
        _ = elevenPercent.addHouse(
            levelID: 2,
            residents: 1,
            hasTaxCoverage: true,
            models: original.buildings
        )
        _ = elevenPercent.addHouse(
            levelID: 2,
            residents: 8,
            hasTaxCoverage: false,
            models: original.buildings
        )

        XCTAssertEqual(
            exactlyTenPercent.advanceMonth(rules: rules).taxSentiment,
            rules.taxSentiment(bandID: 0, difficulty: .normal)
        )
        XCTAssertEqual(
            elevenPercent.advanceMonth(rules: rules).taxSentiment,
            -1
        )
    }

    func testHouseConstructionUsesOriginalCostAtomically() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 1600, treasury: 100)

        let houseID = city.constructHouse(rules: rules)

        XCTAssertEqual(houseID, 1)
        XCTAssertEqual(city.houses.count, 1)
        XCTAssertEqual(city.housingCapacity(using: original.buildings), 7)
        XCTAssertEqual(rules.constructionCost(buildingID: 2, difficulty: .normal), 15)
        XCTAssertEqual(city.economy.treasury, 85)

        var poorCity = DeterministicCityState(year: 1600, treasury: 14)
        XCTAssertNil(poorCity.constructHouse(rules: rules))
        XCTAssertTrue(poorCity.houses.isEmpty)
        XCTAssertEqual(poorCity.economy.treasury, 14)

        var invalidLocationCity = DeterministicCityState(year: 1600, treasury: 100)
        XCTAssertNil(invalidLocationCity.constructHouse(
            location: GridPoint(x: 99, y: 99),
            rules: rules
        ))
        XCTAssertTrue(invalidLocationCity.houses.isEmpty)
        XCTAssertEqual(invalidLocationCity.economy.treasury, 100)
    }

    func testBuildingOperationSettingsPersistInCityState() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 100_000,
            mapWidth: 20,
            mapHeight: 10
        )
        _ = city.buildRoad((0..<20).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let producerID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            at: GridPoint(x: 1, y: 3),
            rules: rules
        ))
        let warehouseID = try XCTUnwrap(city.constructWarehouse(
            at: GridPoint(x: 4, y: 2),
            rules: rules
        ))
        XCTAssertTrue(city.addTradePartner(
            TradePartner(
                id: 99,
                name: "Settings Partner",
                routeKind: .land,
                demandByCommodityID: [25: .low],
                supplyByCommodityID: [5: .low]
            ),
            rules: rules
        ))
        let tradingID = try XCTUnwrap(city.constructTradingBuilding(
            partnerID: 99,
            serviceRoadStart: GridPoint(x: 10, y: 5),
            rules: rules
        ))

        XCTAssertTrue(city.setProductionEnabled(false, buildingInstanceID: producerID))
        XCTAssertTrue(city.setWarehousePolicy(
            .get,
            warehouseID: warehouseID,
            commodityIDs: original.trade.commodities.map(\.id)
        ))
        XCTAssertTrue(city.setTradeEnabled(true, tradingBuildingID: tradingID))

        XCTAssertEqual(
            city.production.buildings.first { $0.id == producerID }?.isEnabled,
            false
        )
        let disabledProducerPlacement = try XCTUnwrap(
            city.placedBuildings.first {
                $0.category == .production && $0.instanceID == producerID
            }
        )
        XCTAssertEqual(
            city.workforceAssignment(
                for: disabledProducerPlacement,
                models: original.buildings
            )?.requiredWorkers,
            0
        )
        XCTAssertTrue(
            original.trade.commodities.allSatisfy { commodity in
                city.logistics.warehouses.first { $0.id == warehouseID }?
                    .policy(for: commodity.id) == .get
            }
        )
        XCTAssertEqual(
            city.trade.building(id: tradingID)?.importingCommodityIDs,
            [5]
        )
        XCTAssertEqual(
            city.trade.building(id: tradingID)?.exportingCommodityIDs,
            [25]
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testOriginalWaterServiceEvolvesCommonHousingOneLevelPerMonth() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = city.buildRoad((0...7).map { GridPoint(x: $0, y: 2) }, rules: rules)
        _ = city.addHouse(
            levelID: 0,
            residents: 7,
            location: GridPoint(x: 3, y: 1),
            models: original.buildings
        )
        XCTAssertNotNil(city.constructResidentialServiceBuilding(
            buildingID: 72,
            serviceRoadStart: GridPoint(x: 3, y: 2),
            replaySeed: 0x5741_5445_52,
            rules: rules
        ))

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].houseLevelID, 1)
        XCTAssertTrue(city.houses[0].serviceCoverage.contains(.water))
        // Appeal-buffer occupancy/anchor projection is unresolved, so the
        // monthly path must preserve the initial value instead of applying
        // the old Manhattan fallback.
        XCTAssertEqual(city.houses[0].desirability, 0)
        XCTAssertEqual(city.lastHousingSettlement?.evolvedCount, 1)

        // The original gates each evolution on the **target** level's authored
        // food requirement: a Hut (food 0) cannot become a Plain Cottage
        // (food 20) without food, so water alone stops at level 1.
        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].houseLevelID, 1)
        XCTAssertEqual(city.lastHousingSettlement?.evolvedCount, 0)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].houseLevelID, 1)
        let missing = try XCTUnwrap(city.lastHousingSettlement?.evaluations.first)
            .missingEvolutionRequirements
        XCTAssertTrue(missing.contains(.foodQuality(current: 0, required: 20)))
        let liveEvaluation = try XCTUnwrap(DeterministicHousingEvolution.evaluate(
            house: city.houses[0],
            models: original.buildings,
            difficulty: city.difficulty
        ))
        XCTAssertEqual(liveEvaluation, city.lastHousingSettlement?.evaluations.first)
    }

    func testServiceWalkerUsesRecoveredOriginalStepAndSpawnPhases() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)

        // The model supplies speed 8/range 40. Figure-model selector 15 turns
        // that range into a 40 * 96 outbound budget; the executable
        // independently fixes 816 figure updates per month and runs the
        // building-spawn slice at scheduler phase 0x1f.
        XCTAssertEqual(original.figures[figureID: 23]?.speed, 8)
        XCTAssertEqual(original.figures[figureID: 23]?.behaviorRange, 60)
        XCTAssertEqual(original.figures[figureID: 28]?.speed, 8)
        XCTAssertEqual(original.figures[figureID: 28]?.behaviorRange, 40)
        for figureID in [32, 33, 34] {
            XCTAssertEqual(original.figures[figureID: figureID]?.speed, 8)
            XCTAssertEqual(original.figures[figureID: figureID]?.behaviorRange, 36)
        }

        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 16,
            mapHeight: 5
        )
        let roads = (0..<16).map { GridPoint(x: $0, y: 2) }
        XCTAssertEqual(city.buildRoad(roads, rules: rules), roads.count)
        XCTAssertNotNil(city.constructResidentialServiceBuilding(
            buildingID: 72,
            serviceRoadStart: roads[0],
            replaySeed: 0x5345_5256_4943_45,
            rules: rules
        ))

        let first = city.advanceTick(rules: rules)
        XCTAssertEqual(first.movement.walkers.requestedRoadSteps, 27)
        XCTAssertEqual(first.movement.walkers.movedRoadSteps, 0)
        XCTAssertEqual(city.walkers.walkers.first?.originalPhase, .dormant)

        _ = city.advanceTick(rules: rules)
        _ = city.advanceTick(rules: rules)
        let fourth = city.advanceTick(rules: rules)
        XCTAssertEqual(fourth.movement.walkers.requestedRoadSteps, 27)
        XCTAssertFalse(fourth.movement.walkers.visitedRoadPoints.isEmpty)
        XCTAssertEqual(
            fourth.movement.walkers.completedTrips,
            0,
            "range 40 is scaled to 3840 budget units, not exhausted as 40 raw units"
        )
    }

    func testGenericServiceReturnBuildsModeZeroRouteOnTheFollowingUpdate() {
        let road = RoadNetwork(
            width: 3,
            height: 1,
            points: [
                GridPoint(x: 0, y: 0),
                GridPoint(x: 1, y: 0),
                GridPoint(x: 2, y: 0),
            ]
        )
        var state = DeterministicWalkerState()
        XCTAssertNotNil(state.addWalker(
            figureID: 27,
            service: .tax,
            origin: GridPoint(x: 0, y: 0),
            maximumRoadSteps: 2,
            replaySeed: 7,
            roadNetwork: road,
            startsDormant: false
        ))
        var houses: [ResidentialUnit] = []
        let outbound = state.advanceRecoveredOriginalSteps(
            33,
            houses: &houses,
            roadNetwork: road,
            workerPercentByWalkerID: [:],
            primaryReturnPassability: [0x4, 0x10, 0x4],
            barrierPoints: []
        )
        XCTAssertEqual(state.walkers[0].originalPhase, .returning)
        XCTAssertEqual(state.walkers[0].completedTrips, 0)
        XCTAssertNotEqual(state.walkers[0].currentPoint, state.walkers[0].origin)
        XCTAssertFalse(outbound.visitedRoadPoints.isEmpty)

        _ = state.advanceRecoveredOriginalSteps(
            1,
            houses: &houses,
            roadNetwork: road,
            workerPercentByWalkerID: [:],
            primaryReturnPassability: [0x4, 0x10, 0x4],
            barrierPoints: []
        )
        XCTAssertEqual(state.walkers[0].currentPoint, state.walkers[0].origin)
        XCTAssertEqual(state.walkers[0].originalPhase, .dormant)
        XCTAssertEqual(state.walkers[0].completedTrips, 1)
    }

    func testWaterServiceUsesRecoveredOneOneTwoSubstepCadence() {
        let points = (0..<10).map { GridPoint(x: $0, y: 0) }
        let road = RoadNetwork(width: 10, height: 1, points: Set(points))
        var generic = DeterministicWalkerState()
        var water = DeterministicWalkerState()
        XCTAssertNotNil(generic.addWalker(
            figureID: 27,
            service: .tax,
            origin: points[0],
            maximumRoadSteps: 40,
            replaySeed: 1,
            roadNetwork: road
        ))
        XCTAssertNotNil(water.addWalker(
            figureID: 28,
            service: .water,
            origin: points[0],
            maximumRoadSteps: 40,
            replaySeed: 1,
            roadNetwork: road
        ))
        var genericHouses: [ResidentialUnit] = []
        var waterHouses: [ResidentialUnit] = []
        let genericMovement = generic.advanceRecoveredOriginalSteps(
            60,
            houses: &genericHouses,
            roadNetwork: road,
            workerPercentByWalkerID: [:]
        )
        let waterMovement = water.advanceRecoveredOriginalSteps(
            60,
            houses: &waterHouses,
            roadNetwork: road,
            workerPercentByWalkerID: [:]
        )
        XCTAssertEqual(genericMovement.movedRoadSteps, 3)
        XCTAssertEqual(waterMovement.movedRoadSteps, 4)
        XCTAssertEqual(generic.walkers[0].currentPoint, points[3])
        XCTAssertEqual(water.walkers[0].currentPoint, points[4])
    }

    func testWalkerPresentationMovesOnlyWhenItsRoutePositionChanges() {
        let points = (0..<10).map { GridPoint(x: $0, y: 0) }
        let road = RoadNetwork(width: 10, height: 1, points: Set(points))
        var state = DeterministicWalkerState()
        XCTAssertNotNil(state.addWalker(
            figureID: 28,
            service: .water,
            origin: points[0],
            maximumRoadSteps: 40,
            replaySeed: 1,
            roadNetwork: road
        ))
        var houses: [ResidentialUnit] = []

        var movementStep: Int?
        for step in 1...60 {
            _ = state.advanceRecoveredOriginalSteps(
                1,
                houses: &houses,
                roadNetwork: road,
                workerPercentByWalkerID: [:]
            )
            if state.walkers[0].movedOnLastSimulationStep {
                movementStep = step
                break
            }
        }
        XCTAssertNotNil(movementStep)
        XCTAssertTrue(state.walkers[0].movedOnLastSimulationStep)

        _ = state.advanceRecoveredOriginalSteps(
            1,
            houses: &houses,
            roadNetwork: road,
            workerPercentByWalkerID: [:]
        )
        XCTAssertFalse(state.walkers[0].movedOnLastSimulationStep)
    }

    func testRecoveredServiceCoverageWritesDecayIndependently() {
        var house = ResidentialUnit(id: 1, houseLevelID: 0, residents: 7)

        house.applyOriginalServiceVisit(.water)
        house.applyOriginalServiceVisit(.ancestor)
        house.applyOriginalServiceVisit(.tax)
        XCTAssertEqual(house.serviceCoverageRemainingSlices[.water], 0x60)
        XCTAssertEqual(house.serviceCoverageRemainingSlices[.ancestor], 0x28)
        XCTAssertEqual(house.taxCoverageRemainingSlices, 0x32)

        for _ in 0..<39 { house.advanceOriginalOrdinaryServiceSlice() }
        XCTAssertEqual(house.serviceCoverageRemainingSlices[.ancestor], 1)
        XCTAssertTrue(house.serviceCoverage.contains(.ancestor))
        XCTAssertEqual(house.serviceCoverageRemainingSlices[.water], 57)

        house.advanceOriginalOrdinaryServiceSlice()
        XCTAssertNil(house.serviceCoverageRemainingSlices[.ancestor])
        XCTAssertFalse(house.serviceCoverage.contains(.ancestor))
        XCTAssertTrue(house.serviceCoverage.contains(.water))

        for _ in 0..<49 { house.advanceOriginalTaxServiceSlice() }
        XCTAssertEqual(house.taxCoverageRemainingSlices, 1)
        XCTAssertTrue(house.hasTaxCoverage)
        house.advanceOriginalTaxServiceSlice()
        XCTAssertEqual(house.taxCoverageRemainingSlices, 0)
        XCTAssertFalse(house.hasTaxCoverage)

        for _ in 0..<56 { house.advanceOriginalOrdinaryServiceSlice() }
        XCTAssertNil(house.serviceCoverageRemainingSlices[.water])
        XCTAssertFalse(house.serviceCoverage.contains(.water))
    }

    func testRecoveredWaterBytesRemainIndependentAndPersistAsOptionalProjection() throws {
        var house = ResidentialUnit(id: 7, houseLevelID: 0, residents: 5)
        XCTAssertNil(house.originalWaterPrimaryRemainingSlices)
        XCTAssertNil(house.originalWaterSecondaryRemainingSlices)

        house.applyOriginalWaterVisit(destination: .primary32)
        house.setOriginalWaterRemainingSlices(3, destination: .secondary34)
        XCTAssertEqual(house.originalWaterPrimaryRemainingSlices, 0x60)
        XCTAssertEqual(house.originalWaterSecondaryRemainingSlices, 3)

        house.advanceOriginalWaterServiceSlice()
        XCTAssertEqual(house.originalWaterPrimaryRemainingSlices, 0x5F)
        XCTAssertEqual(house.originalWaterSecondaryRemainingSlices, 2)
        house.advanceOriginalWaterServiceSlice()
        XCTAssertEqual(house.originalWaterSecondaryRemainingSlices, 1)
        house.advanceOriginalWaterServiceSlice()
        XCTAssertEqual(house.originalWaterSecondaryRemainingSlices, 0)
        XCTAssertEqual(house.originalWaterPrimaryRemainingSlices, 0x5D)

        let encoded = try JSONEncoder().encode(house)
        let decoded = try JSONDecoder().decode(ResidentialUnit.self, from: encoded)
        XCTAssertEqual(decoded.originalWaterPrimaryRemainingSlices, 0x5D)
        XCTAssertEqual(decoded.originalWaterSecondaryRemainingSlices, 0)
    }

    func testRecoveredSchedulerDecaysProjectedWaterOnlyForExplicitEligibleHouses() {
        let road = RoadNetwork(width: 1, height: 1, points: [GridPoint(x: 0, y: 0)])
        var state = DeterministicWalkerState()
        let projected = ResidentialUnit(
            id: 7,
            houseLevelID: 0,
            originalWaterPrimaryRemainingSlices: 2,
            originalWaterSecondaryRemainingSlices: 1
        )
        let unprojected = ResidentialUnit(
            id: 8,
            houseLevelID: 0,
            originalWaterPrimaryRemainingSlices: 2,
            originalWaterSecondaryRemainingSlices: 1
        )
        var houses = [projected, unprojected]

        // Scheduler phase 0x23 is reached after exactly 0x24 steps from the
        // initial phase 0. The explicit ID set stands in for the unresolved
        // source provider/object eligibility bridge.
        _ = state.advanceRecoveredOriginalSteps(
            0x24,
            houses: &houses,
            roadNetwork: road,
            workerPercentByWalkerID: [:],
            waterDecayEligibleHouseIDs: [projected.id]
        )

        XCTAssertEqual(houses[0].originalWaterPrimaryRemainingSlices, 1)
        XCTAssertEqual(houses[0].originalWaterSecondaryRemainingSlices, 0)
        XCTAssertEqual(houses[1].originalWaterPrimaryRemainingSlices, 2)
        XCTAssertEqual(houses[1].originalWaterSecondaryRemainingSlices, 1)
    }

    func testRecoveredSchedulerDecaysEntertainmentOnlyForExplicitActiveProviders() {
        let road = RoadNetwork(width: 1, height: 1, points: [GridPoint(x: 0, y: 0)])
        var state = DeterministicWalkerState()
        var houses: [ResidentialUnit] = []
        var capacities: [Int: OriginalResidentialServiceCatalog.EntertainmentVenueProviderProjection] = [
            71: .init(
                activeState: 1,
                capacity: .init(acrobat: 2, actor: 1, musician: 1)
            ),
            75: .init(
                activeState: 2,
                capacity: .init(acrobat: 2, actor: 1, musician: 1)
            ),
        ]

        // Phase 0x21 is reached after exactly 0x22 steps from phase zero.
        // Only active states 1 and 3 dispatch the recovered +0x9C decay slot;
        // the explicit dictionaries stand in for the unresolved registry.
        _ = state.advanceRecoveredOriginalSteps(
            0x22,
            houses: &houses,
            roadNetwork: road,
            workerPercentByWalkerID: [:],
            entertainmentVenueCapacityByProviderID: &capacities
        )

        XCTAssertEqual(capacities[71]?.capacity.acrobat, 1)
        XCTAssertEqual(capacities[71]?.capacity.actor, 0)
        XCTAssertEqual(capacities[71]?.capacity.musician, 0)
        XCTAssertEqual(capacities[71]?.recordCount, 3)
        XCTAssertEqual(capacities[75]?.capacity.acrobat, 2)
        XCTAssertEqual(capacities[75]?.capacity.actor, 1)
        XCTAssertEqual(capacities[75]?.capacity.musician, 1)
        XCTAssertEqual(capacities[75]?.recordCount, 0)
    }

    func testRecoveredServiceCallbacksPreservePopulationAndEliteHousingGates() {
        let origin = GridPoint(x: 0, y: 0)
        let vacantCommon = ResidentialUnit(
            id: 1,
            houseLevelID: 0,
            residents: 0,
            location: GridPoint(x: 1, y: 0),
            vacantTypeID: 2
        )
        XCTAssertTrue(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .water,
            providerBuildingID: 72,
            houses: [vacantCommon],
            blockerPoints: []
        ).isEmpty)

        let vacantElite = ResidentialUnit(
            id: 2,
            houseLevelID: 10,
            residents: 0,
            location: GridPoint(x: 1, y: 0),
            vacantTypeID: 11
        )
        XCTAssertEqual(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .ancestor,
            providerBuildingID: 214,
            houses: [vacantElite],
            blockerPoints: []
        ), [0])

        let populatedCommon = ResidentialUnit(
            id: 3,
            houseLevelID: 0,
            residents: 8,
            location: GridPoint(x: 1, y: 0)
        )
        XCTAssertTrue(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .confucian,
            providerBuildingID: 219,
            houses: [populatedCommon],
            blockerPoints: []
        ).isEmpty)
        XCTAssertEqual(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .confucian,
            providerBuildingID: 219,
            houses: [vacantElite],
            blockerPoints: []
        ), [0])

        // The entertainment callback at 0x48AD20 uses the same populated-house
        // gate as the recovered health/water callbacks; its figure-specific
        // byte dispatch is separate from the generic walker FSM.
        XCTAssertEqual(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .music,
            providerBuildingID: 211,
            houses: [populatedCommon],
            blockerPoints: []
        ), [0])
        XCTAssertTrue(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .acrobat,
            providerBuildingID: 212,
            houses: [vacantCommon],
            blockerPoints: []
        ).isEmpty)

        // `object +0x07` is the authored multi-cell side byte, not the
        // construction-occupancy projection. Elite objects use 4×4; the
        // outer cells must therefore participate in the radius-two callback.
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.residentialObjectFootprint(
                forBuildingID: 2
            ),
            BuildingFootprint(width: 2, height: 2)
        )
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.residentialObjectFootprint(
                forBuildingID: 11
            ),
            BuildingFootprint(width: 4, height: 4)
        )
        XCTAssertNil(
            OriginalBuildingFootprintCatalog.residentialObjectFootprint(
                forBuildingID: 18
            )
        )
        let outerCellElite = ResidentialUnit(
            id: 4,
            houseLevelID: 8,
            residents: 8,
            location: GridPoint(x: -2, y: -2)
        )
        XCTAssertEqual(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: GridPoint(x: 2, y: 2),
            service: .water,
            providerBuildingID: 72,
            houses: [outerCellElite],
            blockerPoints: []
        ), [0])

        var entertainmentHouse = populatedCommon
        entertainmentHouse.applyOriginalServiceVisit(.music)
        XCTAssertEqual(
            entertainmentHouse.serviceCoverageRemainingSlices[.music],
            0x60
        )
    }

    func testEntertainmentProviderSpawnThresholdsUseRecoveredStrictGateTable() {
        let expected: [(Int, [Int])] = [
            (211, [3, 6, 12, 24, 32, 64]),
            (212, [3, 6, 12, 24, 32, 64]),
            (213, [6, 12, 24, 32, 48, 96]),
        ]
        for (providerID, thresholds) in expected {
            let expectedMethod: UInt32 = providerID == 213
                ? 0x0048B380
                : 0x005AB330
            XCTAssertEqual(
                OriginalResidentialServiceCatalog
                    .entertainmentSpawnThresholdMethodAddress(
                        providerBuildingID: providerID
                    ),
                expectedMethod
            )
            for (workerPercent, thresholdIndex) in [
                (100, 0), (101, 0), (75, 1), (99, 1), (50, 2),
                (74, 2), (25, 3), (49, 3), (1, 4), (24, 4), (0, 5),
            ] {
                XCTAssertEqual(
                    OriginalResidentialServiceCatalog.entertainmentSpawnThreshold(
                        providerBuildingID: providerID,
                        workerPercent: workerPercent
                    ),
                    thresholds[thresholdIndex],
                    "provider \(providerID), workerPercent \(workerPercent)"
                )
            }
        }
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentSpawnThreshold(
                providerBuildingID: 125,
                workerPercent: 100
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog
                .entertainmentSpawnThresholdMethodAddress(
                    providerBuildingID: 125
                )
        )
    }

    func testEntertainmentProviderStaffingPercentUsesRawGuardedRatio() {
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentProviderStaffingPercent(
                providerStateByte: 0,
                rawAssignedWord: 5,
                modelEmployeeField: 8
            ),
            62
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentProviderStaffingPercent(
                providerStateByte: 0,
                rawAssignedWord: -1,
                modelEmployeeField: 8
            ),
            -12
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentProviderStaffingPercent(
                providerStateByte: 1,
                rawAssignedWord: 8,
                modelEmployeeField: 8
            ),
            0,
            "a non-zero +0x6E byte makes the source +0x1B0 denominator zero"
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentProviderStaffingPercent(
                providerStateByte: 0,
                rawAssignedWord: 8,
                modelEmployeeField: 0
            ),
            0,
            "the source +0x1BC guard returns zero for a non-positive denominator"
        )
    }

    func testResidentialProviderRecordUpdatePreservesPhase14GateOrderAndBranches() {
        let blocked = OriginalResidentialServiceCatalog.updateProviderRecord(.init(
            globalGateOpen: false,
            objectActive: true,
            recordAdmissionPassed: true,
            providerReady: true,
            storedWorkCount: 10,
            accessGatePassed: true,
            parentUnclaimed: true,
            auxiliaryGatePassed: true,
            recordCountByte: 4,
            recordOpportunityByte: 7,
            recordProgressWord: 12
        ))
        XCTAssertFalse(blocked.didProcessProvider)
        XCTAssertEqual(blocked.recordCountByte, 4)
        XCTAssertEqual(blocked.recordOpportunityByte, 7)
        XCTAssertEqual(blocked.recordProgressWord, 12)

        let countBranch = OriginalResidentialServiceCatalog.updateProviderRecord(.init(
            globalGateOpen: true,
            objectActive: true,
            recordAdmissionPassed: true,
            providerReady: true,
            storedWorkCount: 10,
            accessGatePassed: true,
            parentUnclaimed: true,
            auxiliaryGatePassed: true,
            recordCountByte: 1,
            recordOpportunityByte: 7,
            recordProgressWord: 12,
            convertedIncrement: 50,
            recordUpperCapacity: 20
        ))
        XCTAssertTrue(countBranch.didProcessProvider)
        XCTAssertTrue(countBranch.didDecrementCountByte)
        XCTAssertFalse(countBranch.didDecrementOpportunityByte)
        XCTAssertEqual(countBranch.recordCountByte, 0)
        XCTAssertEqual(countBranch.recordOpportunityByte, 7)
        XCTAssertEqual(countBranch.recordProgressWord, 12)

        let progressBranch = OriginalResidentialServiceCatalog.updateProviderRecord(.init(
            globalGateOpen: true,
            objectActive: true,
            recordAdmissionPassed: true,
            providerReady: true,
            storedWorkCount: 10,
            accessGatePassed: true,
            parentUnclaimed: true,
            auxiliaryGatePassed: true,
            recordOpportunityByte: 2,
            recordProgressWord: 8,
            convertedIncrement: 7,
            recordUpperCapacity: 20
        ))
        XCTAssertTrue(progressBranch.didDecrementOpportunityByte)
        XCTAssertEqual(progressBranch.recordOpportunityByte, 1)
        XCTAssertEqual(progressBranch.recordProgressWord, 15)
        XCTAssertFalse(progressBranch.didClampProgress)

        let clamped = OriginalResidentialServiceCatalog.updateProviderRecord(.init(
            globalGateOpen: true,
            objectActive: true,
            recordAdmissionPassed: true,
            providerReady: true,
            storedWorkCount: 10,
            accessGatePassed: true,
            parentUnclaimed: true,
            auxiliaryGatePassed: true,
            recordProgressWord: 95,
            convertedIncrement: 10,
            recordUpperCapacity: 100
        ))
        XCTAssertEqual(clamped.recordProgressWord, 100)
        XCTAssertTrue(clamped.didClampProgress)
    }

    func testResidentialProviderRecordUpdatePreservesSignedWordAndByteWidths() {
        let wrapped = OriginalResidentialServiceCatalog.updateProviderRecord(.init(
            globalGateOpen: true,
            objectActive: true,
            recordAdmissionPassed: true,
            providerReady: true,
            storedWorkCount: 1,
            accessGatePassed: true,
            parentUnclaimed: true,
            auxiliaryGatePassed: true,
            recordCountByte: 0,
            recordOpportunityByte: 1,
            recordProgressWord: 32_767,
            convertedIncrement: 1,
            recordUpperCapacity: 32_767
        ))
        XCTAssertEqual(wrapped.recordOpportunityByte, 0)
        XCTAssertEqual(wrapped.recordProgressWord, Int16.min)
        XCTAssertFalse(wrapped.didClampProgress)

        let zeroWork = OriginalResidentialServiceCatalog.updateProviderRecord(.init(
            globalGateOpen: true,
            objectActive: true,
            recordAdmissionPassed: true,
            providerReady: true,
            storedWorkCount: 0,
            accessGatePassed: true,
            parentUnclaimed: true,
            auxiliaryGatePassed: true,
            recordCountByte: 5,
            recordOpportunityByte: 5,
            recordProgressWord: 9
        ))
        XCTAssertFalse(zeroWork.didProcessProvider)
        XCTAssertEqual(zeroWork.recordCountByte, 5)
        XCTAssertEqual(zeroWork.recordOpportunityByte, 5)
    }

    func testPhase14AdmissionFailureRecordUpdatePreservesObjectWhitelistAndCallbackOrder() {
        let unsupported = OriginalResidentialServiceCatalog.updateAdmissionFailureRecord(.init(
            objectModelID: 0x48,
            registryResetGate: true,
            recordCountByte: 4,
            recordProgressWord: 12,
            convertedIncrement: 9
        ))
        XCTAssertFalse(unsupported.didProcessAdmissionFailure)
        XCTAssertEqual(unsupported.recordCountByte, 4)
        XCTAssertEqual(unsupported.recordProgressWord, 12)

        let closedGlobalGate = OriginalResidentialServiceCatalog.updateAdmissionFailureRecord(.init(
            objectModelID: 0x1A,
            globalObjectGate: false,
            registryResetGate: true,
            recordCountByte: 4,
            recordProgressWord: 12,
            convertedIncrement: 9
        ))
        XCTAssertFalse(closedGlobalGate.didProcessAdmissionFailure)
        XCTAssertEqual(closedGlobalGate.recordCountByte, 4)

        for modelID in [0x1A, 0x1B, 0x1C, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7] {
            let outcome = OriginalResidentialServiceCatalog.updateAdmissionFailureRecord(.init(
                objectModelID: modelID,
                registryResetGate: false,
                recordCountByte: 1
            ))
            XCTAssertTrue(outcome.didProcessAdmissionFailure)
            XCTAssertEqual(outcome.recordCountByte, 0)
            XCTAssertFalse(outcome.didInvokeTerminalCallback)
        }

        let countBranch = OriginalResidentialServiceCatalog.updateAdmissionFailureRecord(.init(
            objectModelID: 0xC2,
            registryResetGate: true,
            recordCountByte: 1,
            recordProgressWord: 12,
            convertedIncrement: 50
        ))
        XCTAssertTrue(countBranch.didProcessAdmissionFailure)
        XCTAssertTrue(countBranch.didDecrementCountByte)
        XCTAssertFalse(countBranch.didInvokeTerminalCallback)
        XCTAssertEqual(countBranch.recordProgressWord, 12)
    }

    func testAdmissionFailureRecordUpdatePreservesSignedCapResetAndWrap() {
        let capped = OriginalResidentialServiceCatalog.updateAdmissionFailureRecord(.init(
            objectModelID: 0x1A,
            registryResetGate: false,
            recordProgressWord: 9_999,
            convertedIncrement: 2
        ))
        XCTAssertTrue(capped.didClampProgress)
        XCTAssertFalse(capped.didResetProgress)
        XCTAssertTrue(capped.didInvokeTerminalCallback)
        XCTAssertEqual(capped.recordProgressWord, 10_000)

        let reset = OriginalResidentialServiceCatalog.updateAdmissionFailureRecord(.init(
            objectModelID: 0x1A,
            registryResetGate: true,
            recordProgressWord: 100,
            convertedIncrement: 2
        ))
        XCTAssertTrue(reset.didResetProgress)
        XCTAssertEqual(reset.recordProgressWord, 0)
        XCTAssertTrue(reset.didInvokeTerminalCallback)

        let wrapped = OriginalResidentialServiceCatalog.updateAdmissionFailureRecord(.init(
            objectModelID: 0x1A,
            registryResetGate: false,
            recordProgressWord: 32_767,
            convertedIncrement: 1
        ))
        XCTAssertEqual(wrapped.recordProgressWord, Int16.min)
        XCTAssertFalse(wrapped.didClampProgress)
    }

    func testResidentialProviderSpawnThresholdsUseRecoveredFigureTables() {
        let cases: [(figureID: Int, expected: [Int])] = [
            (27, [1, 3, 5, 10, 15]),
            (28, [1, 3, 5, 10, 15]),
            (30, [1, 3, 5, 10, 15]),
            (31, [1, 3, 7, 15, 29]),
            (35, [3, 6, 12, 24, 32]),
        ]
        let workerBands = [
            (100, 0), (101, 0), (75, 1), (99, 1), (50, 2),
            (74, 2), (25, 3), (49, 3), (1, 4), (24, 4), (0, 4), (-1, 4),
        ]
        for item in cases {
            for (workerPercent, thresholdIndex) in workerBands {
                XCTAssertEqual(
                    OriginalResidentialServiceCatalog.residentialSpawnThreshold(
                        figureID: item.figureID,
                        workerPercent: workerPercent
                    ),
                    item.expected[thresholdIndex],
                    "figure \(item.figureID), workerPercent \(workerPercent)"
                )
            }
        }
        XCTAssertNil(
            OriginalResidentialServiceCatalog.residentialSpawnThreshold(
                figureID: 34,
                workerPercent: 100
            )
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.residentialSpawnThreshold(
                figureID: 28,
                workerPercent: 50,
                wellVTable224ReturnsNonZero: true
            ),
            1
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.residentialSpawnThreshold(
                figureID: 28,
                workerPercent: 25,
                wellVTable224ReturnsNonZero: true
            ),
            5
        )
    }

    func testProviderVTableSlot230DescriptorsMatchCanonicalTargets() {
        let descriptors = OriginalResidentialServiceCatalog.providerVTableSlot230Descriptors
        XCTAssertEqual(descriptors.count, 6)
        let expected: [([Int], UInt32, UInt32, Bool)] = [
            ([72, 73], 0x007B5EB4, 0x0051BAE0, true),
            ([207], 0x007B6114, 0x00507E40, false),
            ([208], 0x007B6374, 0x0051CF40, false),
            ([211], 0x007ACEDC, 0x005AB330, false),
            ([212], 0x007AD140, 0x005AB330, false),
            ([213], 0x007AD3A4, 0x0048B380, false),
        ]
        for (descriptor, expected) in zip(descriptors, expected) {
            XCTAssertEqual(descriptor.providerModelIDs, expected.0)
            XCTAssertEqual(descriptor.providerVTableAddress, expected.1)
            XCTAssertEqual(descriptor.slotOffset, 0x230)
            XCTAssertEqual(descriptor.targetAddress, expected.2)
            XCTAssertFalse(descriptor.targetIndexedInCorpus)
            XCTAssertEqual(
                descriptor.doublesInputWhenVTable224ReturnsNonZero,
                expected.3
            )
        }
        XCTAssertEqual(
            OriginalResidentialServiceCatalog
                .providerVTableSlot230Descriptor(forProviderModelID: 72)?.targetAddress,
            0x0051BAE0
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerVTableSlot230Descriptor(
                forProviderModelID: 214
            )
        )
    }

    func testResidentialProviderSpawnCounterPreservesStrictGateAndReset() {
        let blocked = OriginalResidentialServiceCatalog.residentialSpawnCounterTransition(
            figureID: 28,
            workerPercent: 100,
            counter: 7,
            providerAccessAllowed: false,
            providerWorkerGatePassed: true
        )
        XCTAssertEqual(blocked?.previousCounter, 7)
        XCTAssertEqual(blocked?.nextCounter, 7)
        XCTAssertEqual(blocked?.threshold, 1)
        XCTAssertEqual(blocked?.didRequestFigure, false)

        let beforeStrictGreater = OriginalResidentialServiceCatalog.residentialSpawnCounterTransition(
            figureID: 28,
            workerPercent: 100,
            counter: 0,
            providerAccessAllowed: true,
            providerWorkerGatePassed: true
        )
        XCTAssertEqual(beforeStrictGreater?.nextCounter, 1)
        XCTAssertEqual(beforeStrictGreater?.didRequestFigure, false)

        let spawned = OriginalResidentialServiceCatalog.residentialSpawnCounterTransition(
            figureID: 28,
            workerPercent: 100,
            counter: 1,
            providerAccessAllowed: true,
            providerWorkerGatePassed: true
        )
        XCTAssertEqual(spawned?.nextCounter, 0)
        XCTAssertEqual(spawned?.didRequestFigure, true)

        let noWorkers = OriginalResidentialServiceCatalog.residentialSpawnCounterTransition(
            figureID: 35,
            workerPercent: 0,
            counter: 31,
            providerAccessAllowed: true,
            providerWorkerGatePassed: true
        )
        XCTAssertEqual(noWorkers?.nextCounter, 31)
        XCTAssertEqual(noWorkers?.didRequestFigure, false)

        let wraps = OriginalResidentialServiceCatalog.residentialSpawnCounterTransition(
            figureID: 28,
            workerPercent: 100,
            counter: .max,
            providerAccessAllowed: true,
            providerWorkerGatePassed: true
        )
        XCTAssertEqual(wraps?.nextCounter, 0)
        XCTAssertEqual(wraps?.didRequestFigure, false)
    }

    func testResidentialProviderSpawnFigureHandoffPreservesSourceWrites() {
        let handoff = OriginalResidentialServiceCatalog.residentialSpawnFigureHandoff(
            figureRegistryIndex: 1234,
            providerRegistryIndex: 0x1_0001,
            providerHeading: 5
        )
        XCTAssertEqual(handoff.figureRegistryIndex, 1234)
        XCTAssertEqual(handoff.providerRegistryIndex, 1)
        XCTAssertEqual(handoff.providerHeadingBefore, 5)
        XCTAssertEqual(handoff.providerHeadingAfter, 1)
        XCTAssertEqual(handoff.figureParentProviderIndex, 1)
        XCTAssertEqual(handoff.figureHeadingAfter, 1)
        XCTAssertEqual(
            handoff.providerAttachVTableSlot,
            OriginalResidentialServiceCatalog.residentialSpawnProviderAttachVTableSlot
        )
        XCTAssertEqual(
            handoff.figureParentFieldOffset,
            OriginalResidentialServiceCatalog.residentialSpawnFigureParentFieldOffset
        )
        XCTAssertEqual(
            handoff.figureInitializeVTableSlot,
            OriginalResidentialServiceCatalog.residentialSpawnFigureInitializeVTableSlot
        )
        XCTAssertEqual(
            handoff.providerHeadingFieldOffset,
            OriginalResidentialServiceCatalog.residentialSpawnProviderHeadingFieldOffset
        )
        XCTAssertEqual(
            handoff.figureHeadingFieldOffset,
            OriginalResidentialServiceCatalog.residentialSpawnFigureHeadingFieldOffset
        )
        XCTAssertEqual(
            handoff.bootstrapAddress,
            OriginalResidentialServiceCatalog.residentialSpawnFigureBootstrapAddress
        )
    }

    func testOriginalInitialExitDirectionKeepsCacheAndCallbackBoundary() {
        typealias Candidate = OriginalResidentialServiceCatalog.InitialExitDirection.CandidateInput
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.InitialExitDirection.selectorAddress,
            0x004E6690
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.InitialExitDirection.candidateMask,
            0x0440
        )

        let candidates = OriginalResidentialServiceCatalog.InitialExitDirection.candidates([
            Candidate(rawCacheValue: 0x0440),
            Candidate(rawCacheValue: 0x0448, callbackSuppresses: true),
            Candidate(rawCacheValue: 0x0100),
            Candidate(rawCacheValue: 0x0000),
        ])
        XCTAssertEqual(candidates, [0])

        let twoWay = OriginalResidentialServiceCatalog.InitialExitDirection.candidates([
            Candidate(rawCacheValue: 0x0440),
            Candidate(rawCacheValue: 0x0440),
            Candidate(rawCacheValue: 0),
            Candidate(rawCacheValue: 0),
        ])
        XCTAssertEqual(twoWay, [0, 2])
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.InitialExitDirection.selectAtMostTwo(
                candidates: twoWay!,
                currentHeading: 2,
                forbiddenHeading: 2,
                directionIncrement: 2
            ),
            0
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.InitialExitDirection.selectAtMostTwo(
                candidates: [0, 2, 4],
                currentHeading: 0,
                directionIncrement: 2
            ),
            "multi-way selection remains behind the unresolved saved-byte/RNG path"
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.InitialExitDirection.candidates([
                Candidate(rawCacheValue: 0x0440),
            ])
        )
    }

    func testOriginalInitialExitDirectionMultiWayPreservesCounterAndFallbackBoundary() {
        typealias Selector = OriginalResidentialServiceCatalog.InitialExitDirection

        let direct = Selector.selectMultiWay(.init(
            candidates: [0, 2, 4],
            savedMapByte: 0,
            turnCounterByte: 0,
            directionIncrement: 2,
            fallbackCounter: 5
        ))
        XCTAssertEqual(direct?.heading, 0)
        XCTAssertEqual(direct?.nextFallbackCounter, 5)
        XCTAssertEqual(direct?.usedFallback, false)

        let rotated = Selector.selectMultiWay(.init(
            candidates: [0, 2, 4],
            savedMapByte: 0,
            turnCounterByte: 0,
            forbiddenHeading: 0,
            directionIncrement: 2,
            fallbackCounter: 2
        ))
        XCTAssertEqual(rotated?.heading, 2)
        XCTAssertEqual(rotated?.nextFallbackCounter, 1)
        XCTAssertEqual(rotated?.usedFallback, false)

        let fallback = Selector.selectMultiWay(.init(
            candidates: [0, 2, 4],
            savedMapByte: 0,
            turnCounterByte: 0,
            forbiddenHeading: 0,
            directionIncrement: 2,
            fallbackCounter: 1,
            fallbackHeading: 4,
            fallbackDirectionIncrement: -2
        ))
        XCTAssertEqual(fallback?.heading, 4)
        XCTAssertEqual(fallback?.nextFallbackCounter, 0)
        XCTAssertEqual(fallback?.usedFallback, true)

        let unresolvedFallback = Selector.selectMultiWay(.init(
            candidates: [0, 2, 4],
            savedMapByte: 0,
            turnCounterByte: 0,
            forbiddenHeading: 0,
            directionIncrement: 2,
            fallbackCounter: 1
        ))
        XCTAssertNil(unresolvedFallback?.heading)
        XCTAssertEqual(unresolvedFallback?.nextFallbackCounter, 0)
        XCTAssertEqual(unresolvedFallback?.usedFallback, true)

        XCTAssertNil(Selector.selectMultiWay(.init(
            candidates: [0, 2],
            savedMapByte: 0,
            turnCounterByte: 0,
            directionIncrement: 2,
            fallbackCounter: 1
        )))
    }

    func testOriginalInitialExitDirectionFallbackKeepsMinimumTieAndSignedIncrement() {
        typealias Selector = OriginalResidentialServiceCatalog.InitialExitDirection
        let selected = Selector.selectFallback(
            scores: [
                .init(heading: 0, visitValue: 3),
                .init(heading: 2, visitValue: 1),
                .init(heading: 4, visitValue: 1),
                .init(heading: 6, visitValue: 2),
            ],
            tieRandomValues: [1],
            rotationRandomValue: 0
        )
        XCTAssertEqual(selected?.heading, 4)
        XCTAssertEqual(selected?.directionIncrement, 2)
        XCTAssertEqual(selected?.fallbackCounter, 5)

        let keepPrevious = Selector.selectFallback(
            scores: [
                .init(heading: 0, visitValue: 1),
                .init(heading: 2, visitValue: 1),
            ],
            tieRandomValues: [0],
            rotationRandomValue: 1
        )
        XCTAssertEqual(keepPrevious?.heading, 0)
        XCTAssertEqual(keepPrevious?.directionIncrement, -2)

        XCTAssertNil(Selector.selectFallback(
            scores: [.init(heading: 1, visitValue: 0)],
            tieRandomValues: [],
            rotationRandomValue: 0
        ))
        XCTAssertNil(Selector.selectFallback(
            scores: [.init(heading: 0, visitValue: 8)],
            tieRandomValues: [],
            rotationRandomValue: 0
        ))
        XCTAssertNil(Selector.selectFallback(
            scores: [
                .init(heading: 0, visitValue: 1),
                .init(heading: 2, visitValue: 1),
            ],
            tieRandomValues: [],
            rotationRandomValue: 0
        ))
    }

    func testEntertainmentProviderCandidatesUseRecoveredTieredAdmissionAndWeights() {
        let providers = [
            OriginalResidentialServiceCatalog.EntertainmentProviderSelectionInput(
                registryID: 10, selectionValue: 100, supportsFigure: true,
                stateGate: true, workValue: 1, capacity: 16
            ),
            OriginalResidentialServiceCatalog.EntertainmentProviderSelectionInput(
                registryID: 11, selectionValue: 101, supportsFigure: true,
                stateGate: true, workValue: 1, capacity: 8
            ),
            OriginalResidentialServiceCatalog.EntertainmentProviderSelectionInput(
                registryID: 12, selectionValue: 102, supportsFigure: false,
                stateGate: true, workValue: 1, capacity: 4
            ),
            OriginalResidentialServiceCatalog.EntertainmentProviderSelectionInput(
                registryID: 13, selectionValue: 103, supportsFigure: true,
                stateGate: false, workValue: 1, capacity: 4
            ),
            OriginalResidentialServiceCatalog.EntertainmentProviderSelectionInput(
                registryID: 14, selectionValue: 104, supportsFigure: true,
                stateGate: true, workValue: 0, capacity: 4
            )
        ]

        // The first non-empty bucket is <= 8, so the later capacity-16
        // provider is intentionally excluded. Provider order is preserved.
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentProviderCandidates(
                figureModelID: 32, globalGate: true, providers: providers
            ),
            [
                .init(registryID: 11, selectionValue: 101, capacity: 8, weight: 16)
            ]
        )

        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentProviderCandidates(
                figureModelID: 34,
                globalGate: true,
                providers: [providers[0]]
            ),
            [
                .init(registryID: 10, selectionValue: 100, capacity: 16, weight: 32)
            ]
        )
        XCTAssertTrue(
            OriginalResidentialServiceCatalog.entertainmentProviderCandidates(
                figureModelID: 31, globalGate: true, providers: providers
            ).isEmpty
        )
        XCTAssertTrue(
            OriginalResidentialServiceCatalog.entertainmentProviderCandidates(
                figureModelID: 32, globalGate: false, providers: providers
            ).isEmpty
        )
    }

    func testEntertainmentProviderRotationRebuildUsesFirstThreeThenUnitIncrements() {
        let state = OriginalResidentialServiceCatalog.EntertainmentProviderRotationState.rebuilt(
            fromActiveProviderBuildingIDs: [
                211, 211, 212, 213, 213, 213, 72, 999
            ],
            initialCursor: 17
        )

        // FUN_0048F140's `count == 0 ? 3 : count + 1` update yields
        // music=4, acrobat=3, drama=5; unrelated provider models are ignored.
        XCTAssertEqual(state.musicSlots, 4)
        XCTAssertEqual(state.acrobatSlots, 3)
        XCTAssertEqual(state.dramaSlots, 5)
        XCTAssertEqual(state.totalSlots, 12)
        XCTAssertEqual(state.cursor, 5)
    }

    func testEntertainmentProviderRotationConsumesStrictBucketsAndRotatesCursor() {
        var musicBoundary =
            OriginalResidentialServiceCatalog.EntertainmentProviderRotationState(
                musicSlots: 2, acrobatSlots: 1, dramaSlots: 1, cursor: 2
            )
        XCTAssertEqual(musicBoundary.consume(randomOffset: 0), 5)
        XCTAssertEqual(musicBoundary.musicSlots, 2)
        XCTAssertEqual(musicBoundary.acrobatSlots, 0)
        XCTAssertEqual(musicBoundary.dramaSlots, 1)
        XCTAssertEqual(musicBoundary.totalSlots, 3)
        XCTAssertEqual(musicBoundary.cursor, 2)

        var dramaBoundary =
            OriginalResidentialServiceCatalog.EntertainmentProviderRotationState(
                musicSlots: 2, acrobatSlots: 1, dramaSlots: 1, cursor: 3
            )
        XCTAssertEqual(dramaBoundary.consume(randomOffset: 1), 6)
        XCTAssertEqual(dramaBoundary.totalSlots, 3)
        XCTAssertEqual(dramaBoundary.cursor, 1)

        var exhausted =
            OriginalResidentialServiceCatalog.EntertainmentProviderRotationState(
                musicSlots: 1, acrobatSlots: 0, dramaSlots: 0, cursor: 0
            )
        XCTAssertEqual(exhausted.consume(randomOffset: 0), 4)
        XCTAssertNil(exhausted.consume(randomOffset: 0))
        XCTAssertEqual(exhausted.cursor, 0)
    }

    func testEntertainmentProviderSelectionValueUsesRecoveredMapCellFormula() {
        let base = 98_117
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentProviderSelectionPoint(
                selectionValue: base + 3 + 2 * 0xE4,
                baseLinearOffset: base
            ),
            GridPoint(x: 3, y: 2)
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentProviderSelectionPoint(
                selectionValue: base - 1,
                baseLinearOffset: base
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentProviderSelectionPoint(
                selectionValue: base + 0xE4 * 0xE4,
                baseLinearOffset: base
            )
        )
    }

    func testEntertainmentVenueRawPairPreservesSourceTableAndUnknowns() {
        let expected: [(Int, Int, Int)] = [
            (32, 0xAF, -0x2D),
            (33, 0x97, 0x12),
            (34, 0x3E, -0x30),
        ]
        for (modelID, firstWord, secondWord) in expected {
            let pair = OriginalResidentialServiceCatalog.entertainmentVenueRawPair(
                dispatchModelID: modelID
            )
            XCTAssertEqual(pair?.firstWord, firstWord)
            XCTAssertEqual(pair?.secondWord, secondWord)
        }

        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueRawPair(
                dispatchModelID: 38,
                slot: 0
            ),
            .init(firstWord: 0xFD, secondWord: 0x29)
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueRawPair(
                dispatchModelID: 38,
                slot: 9
            ),
            .init(firstWord: 0xA0, secondWord: 0x5A)
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentVenueRawPair(
                dispatchModelID: 38,
                slot: 10
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentVenueRawPair(
                dispatchModelID: 35
            )
        )
    }

    func testTheatrePavilionSelectionKeepsFirstMinimumAfterSourceGates() {
        let servicePoint = GridPoint(x: 10, y: 10)
        let candidates = [
            OriginalResidentialServiceCatalog.TheatrePavilionSelectionInput(
                objectID: 7,
                callbackGatePassed: true,
                routeProbePassed: true,
                servicePoint: GridPoint(x: 8, y: 8),
                objectOrigin: GridPoint(x: 8, y: 8)
            ),
            OriginalResidentialServiceCatalog.TheatrePavilionSelectionInput(
                objectID: 11,
                callbackGatePassed: true,
                routeProbePassed: true,
                servicePoint: GridPoint(x: 12, y: 12),
                objectOrigin: GridPoint(x: 12, y: 12)
            ),
            OriginalResidentialServiceCatalog.TheatrePavilionSelectionInput(
                objectID: 13,
                callbackGatePassed: false,
                routeProbePassed: true,
                servicePoint: GridPoint(x: 10, y: 10),
                objectOrigin: GridPoint(x: 10, y: 11)
            ),
            OriginalResidentialServiceCatalog.TheatrePavilionSelectionInput(
                objectID: 17,
                isTheatrePavilion: false,
                callbackGatePassed: true,
                routeProbePassed: true,
                servicePoint: GridPoint(x: 10, y: 10),
                objectOrigin: GridPoint(x: 10, y: 10)
            ),
        ]

        let selected = OriginalResidentialServiceCatalog.selectTheatrePavilion(
            from: servicePoint,
            candidates: candidates
        )
        XCTAssertEqual(selected?.objectID, 7)
        XCTAssertNil(
            OriginalResidentialServiceCatalog.selectTheatrePavilion(
                from: servicePoint,
                candidates: candidates.map {
                    .init(
                        objectID: $0.objectID,
                        isTheatrePavilion: $0.isTheatrePavilion,
                        callbackGatePassed: $0.callbackGatePassed,
                        routeProbePassed: false,
                        servicePoint: $0.servicePoint,
                        objectOrigin: $0.objectOrigin
                    )
                }
            )
        )
    }

    func testEntertainmentVenueCapacityStateUsesModelSlotsAndRecoveredDecay() {
        XCTAssertEqual(OriginalResidentialServiceCatalog.entertainmentVenueDecayVTableOffset, 0x9C)
        XCTAssertEqual(OriginalResidentialServiceCatalog.entertainmentVenueDecaySchedulerPhase, 0x21)
        XCTAssertEqual(OriginalResidentialServiceCatalog.entertainmentVenueDecaySchedulerCycleLength, 0x33)
        XCTAssertEqual(OriginalResidentialServiceCatalog.entertainmentVenueFigureCleanupProviderCountOffset, 0x5C)
        XCTAssertTrue(OriginalResidentialServiceCatalog.entertainmentVenueDecayApplies(toActiveStateByte: 1))
        XCTAssertTrue(OriginalResidentialServiceCatalog.entertainmentVenueDecayApplies(toActiveStateByte: 3))
        XCTAssertFalse(OriginalResidentialServiceCatalog.entertainmentVenueDecayApplies(toActiveStateByte: 0))
        XCTAssertFalse(OriginalResidentialServiceCatalog.entertainmentVenueDecayApplies(toActiveStateByte: 2))

        var state = OriginalResidentialServiceCatalog.EntertainmentVenueCapacityState(
            acrobat: 2,
            actor: 0,
            musician: 1
        )
        XCTAssertEqual(state.capacity(forFigureModelID: 32), 2)
        XCTAssertEqual(state.capacity(forFigureModelID: 33), 0)
        XCTAssertEqual(state.capacity(forFigureModelID: 34), 1)
        // 0x48A950 returns the constant 32 for an unknown model; this is a
        // raw executable result, not a Native fallback capacity.
        XCTAssertEqual(state.capacity(forFigureModelID: 31), 32)

        XCTAssertEqual(state.decayOnce(), 2)
        XCTAssertEqual(state.acrobat, 1)
        XCTAssertEqual(state.actor, 0)
        XCTAssertEqual(state.musician, 0)
        XCTAssertEqual(state.decayOnce(), 1)
        XCTAssertEqual(state.acrobat, 0)
        XCTAssertEqual(state.decayOnce(), 0)

        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueProviderCountAfterFigureCleanup(
                figureModelID: 32,
                providerRecordCount: 3
            ),
            2
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueProviderCountAfterFigureCleanup(
                figureModelID: 33,
                providerRecordCount: 0
            ),
            0
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueProviderCountAfterFigureCleanup(
                figureModelID: 34,
                providerRecordCount: 1
            ),
            0
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentVenueProviderCountAfterFigureCleanup(
                figureModelID: 35,
                providerRecordCount: 3
            )
        )
    }

    func testEntertainmentVenuePerformanceWriteUsesRecoveredRecordOffsets() {
        let acrobat = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceWrite(
            figureModelID: 32
        )
        XCTAssertEqual(acrobat?.recordOffset, 0x5D)
        XCTAssertEqual(acrobat?.value, 32)
        XCTAssertEqual(acrobat?.incrementsAuxiliaryCounter, false)

        let actor = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceWrite(
            figureModelID: 33
        )
        XCTAssertEqual(actor?.recordOffset, 0x5F)
        XCTAssertEqual(actor?.auxiliaryCounterOffset, 0x64)
        XCTAssertEqual(actor?.auxiliaryCounterResetThreshold, 5)
        XCTAssertEqual(actor?.incrementsAuxiliaryCounter, true)

        let musician = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceWrite(
            figureModelID: 34
        )
        XCTAssertEqual(musician?.recordOffset, 0x5E)
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentVenuePerformanceWrite(
                figureModelID: 31
            )
        )
    }

    func testEntertainmentVenuePerformanceTransitionPreservesActorCounterReset() {
        let acrobat = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceTransition(
            figureModelID: 32,
            auxiliaryCounter: 7
        )
        XCTAssertEqual(acrobat?.recordOffset, 0x5D)
        XCTAssertEqual(acrobat?.recordValue, 0x20)
        XCTAssertEqual(acrobat?.auxiliaryCounterBefore, 7)
        XCTAssertEqual(acrobat?.auxiliaryCounterAfter, 7)
        XCTAssertFalse(acrobat?.auxiliaryCounterWasTouched ?? true)

        let actorBeforeReset = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceTransition(
            figureModelID: 33,
            auxiliaryCounter: 3
        )
        XCTAssertEqual(actorBeforeReset?.recordOffset, 0x5F)
        XCTAssertEqual(actorBeforeReset?.recordValue, 0x20)
        XCTAssertEqual(actorBeforeReset?.auxiliaryCounterBefore, 3)
        XCTAssertEqual(actorBeforeReset?.auxiliaryCounterAfter, 4)
        XCTAssertTrue(actorBeforeReset?.auxiliaryCounterWasTouched ?? false)
        XCTAssertFalse(actorBeforeReset?.auxiliaryCounterDidReset ?? true)

        let actorReset = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceTransition(
            figureModelID: 33,
            auxiliaryCounter: 4
        )
        XCTAssertEqual(actorReset?.auxiliaryCounterAfter, 0)
        XCTAssertTrue(actorReset?.auxiliaryCounterDidReset ?? false)

        let actorWrap = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceTransition(
            figureModelID: 33,
            auxiliaryCounter: .max
        )
        XCTAssertEqual(actorWrap?.auxiliaryCounterAfter, 0)
        XCTAssertFalse(actorWrap?.auxiliaryCounterDidReset ?? true)

        let musician = OriginalResidentialServiceCatalog.entertainmentVenuePerformanceTransition(
            figureModelID: 34,
            auxiliaryCounter: 2
        )
        XCTAssertEqual(musician?.recordOffset, 0x5E)
        XCTAssertEqual(musician?.auxiliaryCounterAfter, 2)
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentVenuePerformanceTransition(
                figureModelID: 35
            )
        )
    }

    func testWellCommandDispatchPreservesControllerEnvelopeGateOrder() {
        XCTAssertEqual(
            OriginalWaterProviderState.WellCommandStateTrigger.dispatcherAddress,
            0x00515800
        )
        XCTAssertEqual(
            OriginalWaterProviderState.WellCommandStateTrigger.callbackAddress,
            0x00511860
        )
        XCTAssertEqual(
            OriginalWaterProviderState.WellCommandStateTrigger.callbackCallSiteAddress,
            0x00515913
        )
        XCTAssertEqual(
            OriginalWaterProviderState.WellCommandStateTrigger.commandGlobalAddress,
            0x010C6F60
        )
        XCTAssertEqual(
            OriginalWaterProviderState.WellCommandStateTrigger.commandValue,
            0x69
        )
        XCTAssertFalse(
            OriginalWaterProviderState.WellCommandStateTrigger
                .isAutomaticSimulationProducer
        )

        let primary = OriginalWaterProviderState.controllerCommandDispatch(
            recordActive: true,
            primaryGateOpen: true,
            secondaryGateOneOpen: false,
            secondaryGateThreeOpen: false,
            recordMode: 3,
            command: 0x69,
            payload: 0x1234
        )
        XCTAssertEqual(primary?.command, 0x69)
        XCTAssertEqual(primary?.payload, 0x1234)
        XCTAssertEqual(primary?.callback, .primary14C)

        let secondaryOne = OriginalWaterProviderState.controllerCommandDispatch(
            recordActive: true,
            primaryGateOpen: false,
            secondaryGateOneOpen: true,
            secondaryGateThreeOpen: false,
            recordMode: 1,
            command: 0x69,
            payload: 7
        )
        XCTAssertEqual(secondaryOne?.callback, .secondary150)

        let secondaryThree = OriginalWaterProviderState.controllerCommandDispatch(
            recordActive: true,
            primaryGateOpen: false,
            secondaryGateOneOpen: false,
            secondaryGateThreeOpen: true,
            recordMode: 3,
            command: 0x69,
            payload: 8
        )
        XCTAssertEqual(secondaryThree?.callback, .secondary150)

        XCTAssertNil(
            OriginalWaterProviderState.controllerCommandDispatch(
                recordActive: false,
                primaryGateOpen: true,
                secondaryGateOneOpen: true,
                secondaryGateThreeOpen: true,
                recordMode: 1,
                command: 0x69,
                payload: 0
            )
        )
        XCTAssertNil(
            OriginalWaterProviderState.controllerCommandDispatch(
                recordActive: true,
                primaryGateOpen: false,
                secondaryGateOneOpen: true,
                secondaryGateThreeOpen: false,
                recordMode: 3,
                command: 0x69,
                payload: 0
            )
        )
    }

    func testEntertainmentHouseCoverageWriteUsesRecoveredGatesAndOffsets() {
        let acrobat = OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite(
            figureModelID: 32,
            targetIsEligible: true,
            targetPopulation: 1
        )
        XCTAssertEqual(acrobat?.houseInfoOffset, 0x2B)
        XCTAssertEqual(acrobat?.value, 0x60)

        let actor = OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite(
            figureModelID: 33,
            targetIsEligible: true,
            targetPopulation: 12
        )
        XCTAssertEqual(actor?.houseInfoOffset, 0x2E)

        let musician = OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite(
            figureModelID: 34,
            targetIsEligible: true,
            targetPopulation: 99
        )
        XCTAssertEqual(musician?.houseInfoOffset, 0x2C)

        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite(
                figureModelID: 32,
                targetIsEligible: false,
                targetPopulation: 10
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite(
                figureModelID: 32,
                targetIsEligible: true,
                targetPopulation: 0
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite(
                figureModelID: 31,
                targetIsEligible: true,
                targetPopulation: 10
            )
        )
    }

    func testEntertainmentVenueTerminalPredicateUsesRecoveredHeadingSet() {
        for heading in [8, 9, 10] {
            XCTAssertTrue(
                OriginalResidentialServiceCatalog.entertainmentVenueTerminalFailure(
                    heading: heading
                )
            )
        }
        for heading in [0, 7, 11, 12] {
            XCTAssertFalse(
                OriginalResidentialServiceCatalog.entertainmentVenueTerminalFailure(
                    heading: heading
                )
            )
        }
    }

    func testEntertainmentVenueFSMPreservesRecoveredRouteAndSelectionOrder() {
        let waiting = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .routeToVenueTick(countdownBeforeDecrement: 2, routeSucceeded: false)
        )
        XCTAssertEqual(waiting.sourceState, .routeToVenue)
        XCTAssertEqual(waiting.nextState, .routeToVenue)
        XCTAssertEqual(waiting.countdownAfterDecrement, 1)
        XCTAssertFalse(waiting.marksFailure)
        XCTAssertEqual(
            waiting.operations,
            [.setActiveFlag, .resetFigureTick, .clearAuxiliaryByte]
        )

        let routed = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .routeToVenueTick(countdownBeforeDecrement: 1, routeSucceeded: true)
        )
        XCTAssertEqual(routed.nextState, .selectVenue)
        XCTAssertEqual(routed.countdownAfterDecrement, 0)
        XCTAssertEqual(
            routed.operations,
            [
                .setActiveFlag, .resetFigureTick, .clearAuxiliaryByte,
                .requestRouteToVenue, .copyProviderEntryTarget,
                .initializeVenueRoute,
                .clearMovementBudget
            ]
        )

        let routeFailed = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .routeToVenueTick(countdownBeforeDecrement: 0, routeSucceeded: false)
        )
        XCTAssertEqual(routeFailed.nextState, .routeToVenue)
        XCTAssertTrue(routeFailed.marksFailure)
        XCTAssertEqual(routeFailed.operations.last, .markFailure)

        let selected = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .providerSelectionTick(succeeded: true)
        )
        XCTAssertEqual(selected.nextState, .walkToVenue)
        XCTAssertEqual(
            selected.operations,
            [
                .setVisitStateByte, .setActiveFlag, .setVenueFigureMode,
                .advanceProviderApproach,
                .selectVenueProvider, .copySelectedVenueTarget,
                .clearMovementBudget
            ]
        )

        let selectionFailed = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .providerSelectionTick(succeeded: false)
        )
        XCTAssertTrue(selectionFailed.marksFailure)
        XCTAssertEqual(selectionFailed.nextState, .selectVenue)
        XCTAssertEqual(selectionFailed.operations.last, .markFailure)
    }

    func testEntertainmentVenueFSMPreservesWalkGuardAndReturnBranches() {
        let belowGuard = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .walkToVenueTick(movementCounterBeforeIncrement: 3198)
        )
        XCTAssertEqual(belowGuard.movementCounterAfterIncrement, 3199)
        XCTAssertFalse(belowGuard.marksFailure)
        XCTAssertEqual(
            belowGuard.operations,
            [.setVenueFigureMode, .clearActiveFlag, .moveToVenue]
        )

        let hardGuard = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .walkToVenueTick(movementCounterBeforeIncrement: 3199)
        )
        XCTAssertEqual(hardGuard.movementCounterAfterIncrement, 3200)
        XCTAssertTrue(hardGuard.marksFailure)
        // The executable writes +0x16 = 2 but still calls 0x4E47A0 in this
        // same state-8 step.
        XCTAssertEqual(
            hardGuard.operations,
            [.setVenueFigureMode, .clearActiveFlag, .markFailure, .moveToVenue]
        )

        let waitingForBudget = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .returnBudgetBelowSavedTick
        )
        XCTAssertEqual(waitingForBudget.nextState, .returnToHome)
        XCTAssertEqual(
            waitingForBudget.operations,
            [.clearActiveFlag, .moveAlongReturnRoute]
        )

        let returnRouted = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .returnBudgetReachedTick(routeSucceeded: true)
        )
        XCTAssertEqual(returnRouted.nextState, .terminal)
        XCTAssertEqual(
            returnRouted.operations,
            [
                .clearActiveFlag, .requestReturnRoute,
                .copyOriginalProviderTarget, .moveAlongReturnRoute
            ]
        )

        let returnFailed = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .returnBudgetReachedTick(routeSucceeded: false)
        )
        XCTAssertTrue(returnFailed.marksFailure)
        XCTAssertEqual(
            returnFailed.operations,
            [
                .clearActiveFlag, .requestReturnRoute,
                .markFailure, .moveAlongReturnRoute
            ]
        )
    }

    func testEntertainmentVenueFSMTerminalCallbackFailureIsExplicit() {
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(for: .headingTick).operations,
            [.advanceHeading]
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(for: .schoolAnimationTick).operations,
            [.advanceSchoolAnimation]
        )

        let cleanup = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .clearRouteTick
        )
        XCTAssertEqual(cleanup.nextState, .clearRoute)
        XCTAssertEqual(cleanup.operations, [.clearRouteSlot])

        let success = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .terminalTick(callbackFailed: false)
        )
        XCTAssertFalse(success.marksFailure)
        XCTAssertEqual(success.operations, [.moveToReturnTarget, .invokeTerminalCallback])

        let failure = OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition(
            for: .terminalTick(callbackFailed: true)
        )
        XCTAssertTrue(failure.marksFailure)
        XCTAssertEqual(
            failure.operations,
            [.moveToReturnTarget, .invokeTerminalCallback, .markFailure]
        )
    }

    func testEntertainmentVenueFrameSelectionPreservesCommonTailArithmetic() {
        let acrobat = OriginalResidentialServiceCatalog.entertainmentVenueFrameSelection(
            modelID: 32,
            rawHeading: 2,
            savedHeading: 6,
            sharedDirection: 1,
            tick: 3,
            state: .walkToVenue,
            savedCountdown: 0
        )
        XCTAssertEqual(acrobat?.resourceKey, 19_604)
        XCTAssertEqual(acrobat?.alternateResourceKey, 19_608)
        XCTAssertEqual(acrobat?.normalizedHeading, 1)
        XCTAssertEqual(acrobat?.frameOffset, 25)

        let actor = OriginalResidentialServiceCatalog.entertainmentVenueFrameSelection(
            modelID: 33,
            rawHeading: 9,
            savedHeading: 6,
            sharedDirection: 7,
            tick: 0,
            state: .heading,
            savedCountdown: 12
        )
        // A raw heading >= 8 uses the saved heading, and state 4 caps the
        // signed countdown to frame 7 before resolving the alternate key.
        XCTAssertEqual(actor?.resourceKey, 19_631)
        XCTAssertEqual(actor?.alternateResourceKey, 19_627)
        XCTAssertEqual(actor?.normalizedHeading, 7)
        XCTAssertEqual(actor?.frameOffset, 7)

        let signedByte = OriginalResidentialServiceCatalog.entertainmentVenueFrameSelection(
            modelID: 33,
            rawHeading: 0xFF,
            savedHeading: 6,
            sharedDirection: 0,
            tick: 0,
            state: .walkToVenue,
            savedCountdown: 0
        )
        // The PE uses a signed `jl`; byte 0xFF is -1 and therefore does not
        // select the saved heading fallback.
        XCTAssertEqual(signedByte?.normalizedHeading, 7)

        let musician = OriginalResidentialServiceCatalog.entertainmentVenueFrameSelection(
            modelID: 34,
            rawHeading: 8,
            savedHeading: 0,
            sharedDirection: 3,
            tick: 1,
            state: .returnToHome,
            savedCountdown: -1
        )
        XCTAssertEqual(musician?.resourceKey, 19_559)
        XCTAssertEqual(musician?.normalizedHeading, 5)
        XCTAssertEqual(musician?.frameOffset, 13)
    }

    func testEntertainmentVenueMovementUpdatePlanMatchesRecoveredSelectorSwitch() {
        let cadence = (0...2).map {
            let plan = OriginalResidentialServiceCatalog.entertainmentVenueMovementUpdatePlan(
                selector: 8,
                phase: UInt8($0)
            )
            return [plan.movementUpdates, Int(plan.nextPhase)]
        }
        XCTAssertEqual(cadence, [[1, 1], [1, 2], [2, 0]])

        let recoveredBranches: [(Int, UInt8, Int, UInt8)] = [
            (0, 7, 0, 7),
            (1, 2, 0, 3), (1, 3, 1, 0),
            (2, 1, 0, 2), (2, 2, 1, 0),
            (3, 0, 1, 1), (3, 1, 2, 0),
            (4, 1, 1, 2), (4, 2, 2, 0),
            (5, 2, 1, 3), (5, 3, 2, 0),
            (6, 9, 1, 9),
            (7, 2, 1, 3), (7, 3, 2, 0),
            (8, 1, 1, 2), (8, 2, 2, 0),
            (9, 0, 1, 1), (9, 1, 2, 0),
            (10, 1, 2, 2), (10, 2, 1, 0),
            (11, 2, 2, 3), (11, 3, 1, 0),
            (12, 7, 2, 7),
            (13, 2, 2, 3), (13, 3, 3, 0),
            (14, 1, 2, 2), (14, 2, 3, 0),
            (15, 0, 3, 1), (15, 1, 2, 0),
            (16, 1, 3, 2), (16, 2, 2, 0),
            (17, 2, 3, 3), (17, 3, 2, 0),
            (18, 4, 3, 4),
        ]
        for (selector, phase, updates, nextPhase) in recoveredBranches {
            let plan = OriginalResidentialServiceCatalog.entertainmentVenueMovementUpdatePlan(
                selector: selector,
                phase: phase
            )
            XCTAssertEqual(plan.movementUpdates, updates, "selector \(selector), phase \(phase)")
            XCTAssertEqual(plan.nextPhase, nextPhase, "selector \(selector), phase \(phase)")
        }
    }

    func testSharedRouteAnchorMatchesRecoveredResidualAndAxisArithmetic() {
        let diagonal = OriginalResidentialServiceCatalog.sharedRouteAnchor(
            currentX: 10,
            currentY: 20,
            targetX: 14,
            targetY: 23,
            headingSource: .coordinateCallback,
            coordinateHeading: 3
        )
        XCTAssertEqual(diagonal.targetX, 14)
        XCTAssertEqual(diagonal.targetY, 23)
        XCTAssertEqual(diagonal.horizontalResidual, 4)
        XCTAssertEqual(diagonal.verticalResidual, 3)
        XCTAssertEqual(diagonal.diagonalResidual, 2)
        XCTAssertEqual(diagonal.movementAxis, 1)
        XCTAssertEqual(diagonal.heading, 3)

        let vertical = OriginalResidentialServiceCatalog.sharedRouteAnchor(
            currentX: 10,
            currentY: 20,
            targetX: 10,
            targetY: 25,
            headingSource: .coordinateCallback,
            coordinateHeading: 1
        )
        XCTAssertEqual(vertical.diagonalResidual, -5)
        XCTAssertEqual(vertical.movementAxis, 2)
        XCTAssertEqual(vertical.heading, 0)

        let horizontal = OriginalResidentialServiceCatalog.sharedRouteAnchor(
            currentX: 10,
            currentY: 20,
            targetX: 15,
            targetY: 20,
            headingSource: .coordinateCallback,
            coordinateHeading: 3
        )
        XCTAssertEqual(horizontal.diagonalResidual, -5)
        XCTAssertEqual(horizontal.movementAxis, 1)
        XCTAssertEqual(horizontal.heading, 2)
    }

    func testSharedRouteAnchorLeavesGlobalHeadingCallbackExplicitlyUnresolved() {
        let anchor = OriginalResidentialServiceCatalog.sharedRouteAnchor(
            currentX: 4,
            currentY: 7,
            targetX: 6,
            targetY: 8,
            headingSource: .sharedCallback
        )
        XCTAssertEqual(anchor.headingSource, .sharedCallback)
        XCTAssertNil(anchor.heading)
        XCTAssertEqual(anchor.horizontalResidual, 2)
        XCTAssertEqual(anchor.verticalResidual, 1)
        XCTAssertEqual(anchor.diagonalResidual, 0)
    }

    func testRecoveredFoodPopularityWalkPreservesRawQualityAndHouseFieldBranches() {
        let outcome = DeterministicMigration.originalFoodPopularityWalk(
            houses: [
                .init(
                    vectorIndex: 4,
                    residents: 20,
                    isEliteClass: false,
                    foodRequired: 20,
                    rawFoodQuality: 0,
                    foodShortageStreak: 0,
                    crimeValue: 5,
                    crimeIncrement: 10,
                    crimeBase: 20
                ),
                .init(
                    vectorIndex: 9,
                    residents: 20,
                    isEliteClass: true,
                    foodRequired: 20,
                    rawFoodQuality: 20,
                    crimeValue: 77,
                    crimeIncrement: 10,
                    crimeBase: 20
                ),
                .init(
                    vectorIndex: 12,
                    residents: 0,
                    isEliteClass: false,
                    foodRequired: 20,
                    rawFoodQuality: 0,
                    foodShortageStreak: 2,
                    crimeValue: 80
                ),
                .init(
                    vectorIndex: 15,
                    residents: 10,
                    isEliteClass: false,
                    foodRequired: 0,
                    rawFoodQuality: 0,
                    foodShortageStreak: 3,
                    crimeValue: 2
                )
            ],
            popularitySnapshot: 30,
            population: 500,
            neverExceeded349: true
        )

        XCTAssertEqual(outcome.popularityTerm, 0) // exact half does not round
        XCTAssertEqual(outcome.houseResults.map(\.vectorIndex), [4, 9, 12, 15])
        XCTAssertEqual(outcome.houseResults[0].foodShortageStreak, 1)
        XCTAssertEqual(outcome.houseResults[0].foodScore, -1)
        XCTAssertEqual(outcome.houseResults[0].crimeValue, 20)
        XCTAssertEqual(outcome.houseResults[1].foodScore, 2)
        XCTAssertEqual(outcome.houseResults[1].crimeValue, 77)
        XCTAssertNil(outcome.houseResults[2].foodScore)
        XCTAssertEqual(outcome.houseResults[2].crimeValue, 0)
        XCTAssertNil(outcome.houseResults[3].foodScore)
        XCTAssertEqual(outcome.houseResults[3].foodShortageStreak, 0)
    }

    func testOriginalPressurePassGeneratesArrivalAndCrossCooldown() {
        let outcome = DeterministicMigration.originalPressurePass(.init(
            popularity: 75,
            previousPressure: 50,
            population: 500,
            arrivalCooldown: 0,
            departureCooldown: 1
        ))

        XCTAssertEqual(outcome.pressure, 100)
        XCTAssertEqual(outcome.arrivalRequest, 12)
        XCTAssertEqual(outcome.departureRequest, 0)
        XCTAssertEqual(outcome.arrivalCooldown, 0)
        XCTAssertEqual(outcome.departureCooldown, 2)
        XCTAssertTrue(outcome.invokedOverlayRefresh)
    }

    func testOriginalMigrationRequestProducerCatalogMatchesSourceHandoff() {
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.pressureProducerAddress,
            0x005917E0
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.requestScaleHelperAddress,
            0x0059A1B0
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.dailyConsumerAddress,
            0x004AD4A0
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalAssignmentAddress,
            0x004ADA10
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.departureAssignmentAddress,
            0x004ADC90
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.pressureProducerDirectCallSites,
            [0x004AD4C0]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.dailyConsumerDirectCallSites,
            [0x004AC3E2]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalAssignmentDirectCallSites,
            [0x004AD4EB, 0x004AD508]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.departureAssignmentDirectCallSites,
            [0x004AD52C, 0x004AD544]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureWriterAddress,
            0x004ADE10
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.departureFigureWriterAddress,
            0x004ADED0
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureAllocatorAddress,
            0x004EA050
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureAllocatorDirectCallSites,
            [0x004ADE2B]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureAllocatorDirectCallerAddresses,
            [0x004ADE10]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureAllocatorFlags,
            1
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureWriterDirectCallSites,
            [
                0x004ADB04, 0x004ADB18, 0x004ADB92,
                0x004ADBA6, 0x004ADC1C, 0x004ADC2F,
            ]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.departureFigureWriterDirectCallSites,
            [0x004ADD04, 0x004ADD12]
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureTypeID,
            0x0B
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.departureFigureTypeID,
            0x0C
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.assignmentFigureStateOffset,
            0x40
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.assignmentFigureStateValue,
            6
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalFigureHouseIDOffset,
            0x64
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalHouseArgumentRegistryFieldOffset,
            0xB4
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.departureHouseArgumentRegistryFieldOffset,
            0xB4
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalHouseArgumentSourceAddress,
            0x004ADA10
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.departureHouseArgumentSourceAddress,
            0x004ADC90
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.houseArgumentRegistryLookupAddress,
            0x0047F1B0
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.arrivalHouseInFlightFigureOffset,
            0x32
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.houseResidentCountOffset,
            0x20
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.populationLedgerCallbackAddress,
            0x00591900
        )

        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.requestWordAddress(for: .arrival),
            0x01311F7C
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.requestWordAddress(for: .departure),
            0x01311F80
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.pendingWordAddress(for: .arrival),
            0x01311F88
        )
        XCTAssertEqual(
            OriginalMigrationRequestProducerCatalog.pendingWordAddress(for: .departure),
            0x01311F84
        )
    }

    func testOriginalMonumentMatchingCatalogMatchesCanonicalDirectCallCensus() {
        XCTAssertEqual(OriginalMonumentMatchingCatalog.address, 0x0055AE30)
        XCTAssertEqual(
            OriginalMonumentMatchingCatalog.directCallSites,
            [0x0055B6AB, 0x0055E498, 0x00591281, 0x005B8C4B]
        )
        XCTAssertEqual(
            OriginalMonumentMatchingCatalog.directCallerAddresses,
            [0x0055B6A0, 0x0055E490, 0x00591200, 0x005B8740]
        )
    }

    func testOriginalPressurePassHonorsCooldownAndPopulationDepartureGate() {
        let cooldown = DeterministicMigration.originalPressurePass(.init(
            popularity: 10,
            previousPressure: -17,
            population: 500,
            departureCooldown: 2
        ))
        XCTAssertEqual(cooldown.pressure, -25)
        XCTAssertEqual(cooldown.departureRequest, 0)
        XCTAssertEqual(cooldown.departureCooldown, 1)
        XCTAssertFalse(cooldown.invokedOverlayRefresh)

        let tooSmall = DeterministicMigration.originalPressurePass(.init(
            popularity: 10,
            previousPressure: -25,
            population: 100
        ))
        XCTAssertEqual(tooSmall.departureRequest, 0)
        XCTAssertEqual(tooSmall.arrivalCooldown, 0)
        XCTAssertFalse(tooSmall.invokedOverlayRefresh)
    }

    func testOriginalPressurePassWarAndPopulationCapsPreserveSourceEarlyReturns() {
        let war = DeterministicMigration.originalPressurePass(.init(
            popularity: 80,
            previousPressure: 50,
            population: 500,
            warTroopCount: 4
        ))
        XCTAssertEqual(war.pressure, 0)
        XCTAssertFalse(war.invokedOverlayRefresh)

        let populationCap = DeterministicMigration.originalPressurePass(.init(
            popularity: 80,
            previousPressure: 100,
            population: 200_000
        ))
        XCTAssertEqual(populationCap.pressure, 0)
        XCTAssertFalse(populationCap.invokedOverlayRefresh)
    }

    func testRecoveredFoodPopularityWalkUsesStrictMeanRoundingAndPopulationLatch() {
        let exactHalf = DeterministicMigration.originalFoodPopularityWalk(
            houses: [
                .init(vectorIndex: 0, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 0),
                .init(vectorIndex: 1, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 0, foodShortageStreak: 1)
            ],
            popularitySnapshot: 40,
            population: 500,
            neverExceeded349: true
        )
        // Sum -3 / 2 has an exact half remainder, so it stays -1.
        XCTAssertEqual(exactHalf.popularityTerm, -1)

        let roundsAway = DeterministicMigration.originalFoodPopularityWalk(
            houses: [
                .init(vectorIndex: 0, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 0),
                .init(vectorIndex: 1, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 0, foodShortageStreak: 1),
                .init(vectorIndex: 2, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 0, foodShortageStreak: 2)
            ],
            popularitySnapshot: 40,
            population: 500,
            neverExceeded349: true
        )
        // Sum -6 / 3 is integral; this also guards the third streak penalty.
        XCTAssertEqual(roundsAway.popularityTerm, -2)

        let strictRounding = DeterministicMigration.originalFoodPopularityWalk(
            houses: [
                .init(vectorIndex: 0, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 1),
                .init(vectorIndex: 1, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 1),
                .init(vectorIndex: 2, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 0, foodShortageStreak: 1)
            ],
            popularitySnapshot: 40,
            population: 500,
            neverExceeded349: true
        )
        // Sum +2 / 3 has a remainder greater than half, so it rounds to +1.
        XCTAssertEqual(strictRounding.popularityTerm, 1)

        let suppressed = DeterministicMigration.originalFoodPopularityWalk(
            houses: [
                .init(vectorIndex: 0, residents: 1, isEliteClass: false, foodRequired: 1, rawFoodQuality: 0)
            ],
            popularitySnapshot: 40,
            population: 349,
            neverExceeded349: false
        )
        XCTAssertEqual(suppressed.popularityTerm, 0)
    }

    func testMigrationTaxCoverageUsesOriginalElevenPercentFloorBoundary() {
        // 0x408BA0 truncates to an integer percentage and 0x591180 accepts
        // only values >= 11. Exactly 10% must still select the None row.
        XCTAssertFalse(
            DeterministicMigration.taxCoverageMeetsOriginalThreshold(
                taxedPopulation: 10,
                population: 100
            )
        )
        XCTAssertTrue(
            DeterministicMigration.taxCoverageMeetsOriginalThreshold(
                taxedPopulation: 11,
                population: 100
            )
        )
        // 1/9 = 11% after integer truncation, so this is the first positive
        // boundary for a non-round denominator.
        XCTAssertTrue(
            DeterministicMigration.taxCoverageMeetsOriginalThreshold(
                taxedPopulation: 1,
                population: 9
            )
        )
        XCTAssertFalse(
            DeterministicMigration.taxCoverageMeetsOriginalThreshold(
                taxedPopulation: 0,
                population: 0
            )
        )
    }

    func testOriginalFestivalPopularityAdjustmentsPreserveSeasonAndPopulationGates() {
        // FUN_0048EA40: (-(ret2 == ret) & 6) + 0xC => 12/18.
        XCTAssertEqual(
            DeterministicMigration.originalFestivalPositiveEffect(seasonMatches: false),
            12
        )
        XCTAssertEqual(
            DeterministicMigration.originalFestivalPositiveEffect(seasonMatches: true),
            18
        )

        // FUN_0048EAF0: (-(ret2 != ret) & 6) - 0x12, gated by population > 350
        // and any of DAT_00C5CE7E/80/82 being nonzero.
        XCTAssertEqual(
            DeterministicMigration.originalFestivalNegativeEffect(
                seasonMatches: false,
                populationAbove350: true,
                anyQualificationFlag: true
            ),
            -12
        )
        XCTAssertEqual(
            DeterministicMigration.originalFestivalNegativeEffect(
                seasonMatches: true,
                populationAbove350: true,
                anyQualificationFlag: true
            ),
            -18
        )
        XCTAssertEqual(
            DeterministicMigration.originalFestivalNegativeEffect(
                seasonMatches: true,
                populationAbove350: false,
                anyQualificationFlag: true
            ),
            0
        )
        XCTAssertEqual(
            DeterministicMigration.originalFestivalNegativeEffect(
                seasonMatches: true,
                populationAbove350: true,
                anyQualificationFlag: false
            ),
            0
        )
    }

    func testRecoveredWellProviderTransitionUsesAppealThresholdAndPredicate() {
        // 0x51CEC0 tests mode 0 first (appeal < threshold and predicate true),
        // then mode 1 (appeal >= threshold and predicate false); otherwise the
        // existing provider word is preserved.
        XCTAssertEqual(OriginalWaterProviderState.wellAppealThreshold, 40)
        XCTAssertEqual(
            OriginalWaterProviderState.nextFlag(
                currentFlag: 1,
                appealValue: 39,
                threshold: OriginalWaterProviderState.wellAppealThreshold,
                providerPredicate: true
            ),
            0
        )
        XCTAssertEqual(
            OriginalWaterProviderState.nextFlag(
                currentFlag: 0,
                appealValue: 40,
                threshold: OriginalWaterProviderState.wellAppealThreshold,
                providerPredicate: false
            ),
            1
        )
        XCTAssertEqual(
            OriginalWaterProviderState.nextFlag(
                currentFlag: 1,
                appealValue: 39,
                threshold: OriginalWaterProviderState.wellAppealThreshold,
                providerPredicate: false
            ),
            1
        )
        XCTAssertEqual(
            OriginalWaterProviderState.nextFlag(
                currentFlag: 0,
                appealValue: 40,
                threshold: OriginalWaterProviderState.wellAppealThreshold,
                providerPredicate: true
            ),
            0
        )
    }

    func testOriginalResidentialProviderFactoryCatalogMatchesExecutableDispatch() {
        let well = OriginalResidentialServiceCatalog.providerFactoryDescriptor(
            forBuildingModelID: 72
        )
        XCTAssertEqual(well?.family, .well)
        XCTAssertEqual(well?.buildingModelIDs, [72, 73])
        XCTAssertEqual(well?.dispatcherAddress, 0x0051C660)
        XCTAssertEqual(well?.admissionPredicateAddress, 0x0051BE30)
        XCTAssertEqual(well?.allocationSize, 0x150)
        XCTAssertEqual(well?.initializerAddress, 0x0051C090)
        XCTAssertEqual(well?.vtableAddress, 0x007B5EB4)

        let herbalist = OriginalResidentialServiceCatalog.providerFactoryDescriptor(
            forBuildingModelID: 207
        )
        XCTAssertEqual(herbalist?.family, .herbalist)
        XCTAssertEqual(herbalist?.dispatcherAddress, 0x0051C660)
        XCTAssertEqual(herbalist?.admissionPredicateAddress, 0x0051BE30)
        XCTAssertEqual(herbalist?.allocationSize, 0x150)
        XCTAssertEqual(herbalist?.initializerAddress, 0x0051C0B0)
        XCTAssertEqual(herbalist?.vtableAddress, 0x007B6114)

        let acupuncture = OriginalResidentialServiceCatalog.providerFactoryDescriptor(
            forBuildingModelID: 208
        )
        XCTAssertEqual(acupuncture?.family, .acupuncture)
        XCTAssertEqual(acupuncture?.dispatcherAddress, 0x0051C660)
        XCTAssertEqual(acupuncture?.admissionPredicateAddress, 0x0051BE30)
        XCTAssertEqual(acupuncture?.allocationSize, 0x150)
        XCTAssertEqual(acupuncture?.initializerAddress, 0x0051C0D0)
        XCTAssertEqual(acupuncture?.vtableAddress, 0x007B6374)

        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerFactoryDescriptor(
                forBuildingModelID: 71
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerFactoryDescriptor(
                forBuildingModelID: 209
            )
        )
    }

    func testOriginalResidentialProviderRuntimeClassCatalogMatchesExecutableRecords() {
        let expected: [(Int, String, UInt32, UInt32, UInt32, UInt32, UInt32)] = [
            (72, "cWellBldg", 0x00854360, 0x0051B9C0, 0x00854438, 0x0051BA20, 0x150),
            (73, "cWellBldg", 0x00854360, 0x0051B9C0, 0x00854438, 0x0051BA20, 0x150),
            (207, "cHerbalistBldg", 0x00854348, 0x0051B930, 0x00854438, 0x0051B990, 0x150),
            (208, "cAcupuncturistBldg", 0x00854330, 0x0051B8A0, 0x00854438, 0x0051B900, 0x150),
        ]
        for (modelID, name, record, create, base, accessor, size) in expected {
            let descriptor = OriginalResidentialServiceCatalog
                .providerRuntimeClassDescriptor(forBuildingModelID: modelID)
            XCTAssertEqual(descriptor?.className, name)
            XCTAssertEqual(descriptor?.runtimeClassAddress, record)
            XCTAssertEqual(descriptor?.createObjectAddress, create)
            XCTAssertEqual(descriptor?.baseClassAddress, base)
            XCTAssertEqual(descriptor?.runtimeClassAccessorAddress, accessor)
            XCTAssertEqual(descriptor?.objectSize, Int(size))
        }
        XCTAssertEqual(
            Set(OriginalResidentialServiceCatalog.providerRuntimeClassDescriptors.map(\.className)),
            ["cWellBldg", "cHerbalistBldg", "cAcupuncturistBldg"]
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerRuntimeClassDescriptor(
                forBuildingModelID: 71
            )
        )
    }

    func testOriginalResidentialProviderVTableSlot268CatalogPreservesPolymorphism() {
        let expected: [(Int, UInt32, UInt32, Bool)] = [
            (72, 0x007B5EB4, 0x0051CE00, true),
            (73, 0x007B5EB4, 0x0051CE00, true),
            (207, 0x007B6114, 0x0051CE00, true),
            (208, 0x007B6374, 0x0051C3A0, false),
        ]
        for (modelID, vtable, target, indexed) in expected {
            let descriptor = OriginalResidentialServiceCatalog
                .providerVTableSlot268Descriptor(forProviderModelID: modelID)
            XCTAssertEqual(descriptor?.providerVTableAddress, vtable)
            XCTAssertEqual(descriptor?.slotOffset, 0x268)
            XCTAssertEqual(descriptor?.targetAddress, target)
            XCTAssertEqual(descriptor?.targetIndexedInCorpus, indexed)
        }
        XCTAssertNil(
            OriginalResidentialServiceCatalog
                .providerVTableSlot268Descriptor(forProviderModelID: 71)
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.providerVTableSlot268Descriptors.count,
            3
        )
    }

    func testOriginalResidentialProviderCoverageCallbacksMatchExecutableVTables() {
        let expected: [(Int, UInt32, UInt32, [Int])] = [
            (72, 0x007B5EB4, 0x0051BC00, [0x32, 0x34]),
            (73, 0x007B5EB4, 0x0051BC00, [0x32, 0x34]),
            (207, 0x007B6114, 0x0051BD00, [0x2D]),
            (208, 0x007B6374, 0x0051BD90, [0x2A]),
        ]
        for (modelID, vtable, callback, offsets) in expected {
            let descriptor = OriginalResidentialServiceCatalog
                .providerCoverageCallbackDescriptor(forProviderModelID: modelID)
            XCTAssertEqual(descriptor?.providerModelIDs.contains(modelID), true)
            XCTAssertEqual(descriptor?.providerVTableAddress, vtable)
            XCTAssertEqual(descriptor?.callbackAddress, callback)
            XCTAssertEqual(descriptor?.houseInfoFieldOffsets, offsets)
        }
        XCTAssertNil(
            OriginalResidentialServiceCatalog
                .providerCoverageCallbackDescriptor(forProviderModelID: 71)
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog
                .providerCoverageCallbackDescriptor(forProviderModelID: 209)
        )
    }

    func testEntertainmentCoverageDispatchUsesDistinctSchoolCallback() {
        let dispatch = OriginalResidentialServiceCatalog
            .EntertainmentCoverageDispatchDescriptor.canonical
        XCTAssertEqual(dispatch.crossingFunctionAddress, 0x004EACD0)
        XCTAssertEqual(dispatch.radiusWrapperAddress, 0x00429DF0)
        XCTAssertEqual(dispatch.radiusScanAddress, 0x00429E10)
        XCTAssertEqual(
            dispatch.providerVTableAddresses,
            [0x007ACEDC, 0x007AD140, 0x007AD3A4]
        )
        XCTAssertEqual(dispatch.radiusVTableOffset, 0x28)
        XCTAssertEqual(dispatch.writerVTableOffset, 0x2C)
        XCTAssertEqual(dispatch.radius, 2)
        XCTAssertEqual(dispatch.writerAddress, 0x0048AD20)
    }

    func testResidentialProviderHouseCoverageWriteUsesRecoveredGatesAndOffsets() {
        let herbalist = OriginalResidentialServiceCatalog.residentialProviderHouseCoverageWrite(
            providerModelID: 207,
            globalGateOpen: true,
            targetIsEligible: true,
            targetPopulation: 1
        )
        XCTAssertEqual(herbalist?.houseInfoOffset, 0x2D)
        XCTAssertEqual(herbalist?.value, 0x60)

        let acupuncture = OriginalResidentialServiceCatalog.residentialProviderHouseCoverageWrite(
            providerModelID: 208,
            globalGateOpen: true,
            targetIsEligible: true,
            targetPopulation: 10
        )
        XCTAssertEqual(acupuncture?.houseInfoOffset, 0x2A)
        XCTAssertEqual(acupuncture?.value, 0x60)

        for (gate, eligible, population) in [
            (false, true, 10),
            (true, false, 10),
            (true, true, 0),
            (true, true, -1)
        ] {
            XCTAssertNil(
                OriginalResidentialServiceCatalog.residentialProviderHouseCoverageWrite(
                    providerModelID: 207,
                    globalGateOpen: gate,
                    targetIsEligible: eligible,
                    targetPopulation: population
                )
            )
        }
        XCTAssertNil(
            OriginalResidentialServiceCatalog.residentialProviderHouseCoverageWrite(
                providerModelID: 72,
                globalGateOpen: true,
                targetIsEligible: true,
                targetPopulation: 10
            )
        )
    }

    func testReligiousHouseCoverageWritePreservesEliteAndProviderRestrictions() {
        let ancestor = OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
            providerModelID: 214,
            globalGateOpen: true,
            targetModelID: 2,
            targetByte09NonZero: true,
            targetPopulation: 1,
            providerRestrictionByteNonZero: false
        )
        XCTAssertEqual(ancestor?.religionIndex, 0)
        XCTAssertEqual(ancestor?.houseInfoOffset, 0x0D)
        XCTAssertEqual(ancestor?.value, 0x28)

        let daoist = OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
            providerModelID: 216,
            globalGateOpen: true,
            targetModelID: 11,
            targetByte09NonZero: true,
            targetPopulation: 0,
            providerRestrictionByteNonZero: true
        )
        XCTAssertEqual(daoist?.religionIndex, 1)
        XCTAssertEqual(daoist?.houseInfoOffset, 0x0E)

        let buddhist = OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
            providerModelID: 217,
            globalGateOpen: true,
            targetModelID: 17,
            targetByte09NonZero: true,
            targetPopulation: 0,
            providerRestrictionByteNonZero: false
        )
        XCTAssertEqual(buddhist?.religionIndex, 2)
        XCTAssertEqual(buddhist?.houseInfoOffset, 0x0F)

        let confucian = OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
            providerModelID: 219,
            globalGateOpen: true,
            targetModelID: 10,
            targetByte09NonZero: true,
            targetPopulation: 1,
            providerRestrictionByteNonZero: false
        )
        XCTAssertEqual(confucian?.religionIndex, 3)
        XCTAssertEqual(confucian?.houseInfoOffset, 0x10)

        XCTAssertNil(
            OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
                providerModelID: 215,
                globalGateOpen: true,
                targetModelID: 10,
                targetByte09NonZero: true,
                targetPopulation: 0,
                providerRestrictionByteNonZero: false
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
                providerModelID: 219,
                globalGateOpen: true,
                targetModelID: 10,
                targetByte09NonZero: true,
                targetPopulation: 1,
                providerRestrictionByteNonZero: true
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
                providerModelID: 214,
                globalGateOpen: false,
                targetModelID: 2,
                targetByte09NonZero: true,
                targetPopulation: 1,
                providerRestrictionByteNonZero: false
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.religiousHouseCoverageWrite(
                providerModelID: 214,
                globalGateOpen: true,
                targetModelID: 2,
                targetByte09NonZero: false,
                targetPopulation: 1,
                providerRestrictionByteNonZero: false
            )
        )
    }

    func testProviderRegistryRefreshSeparatesTradingQuayCapacityAndModelCounters() {
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.providerRegistryRefreshAddress,
            0x0051CCA0
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.providerRegistryModelClassifierAddress,
            0x005E1720
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.providerRegistryFieldOffset,
            0x2D
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.providerVTableStaffingMethodOffset,
            0x1B4
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.maximumTradingQuayRegistryEntries,
            10
        )

        let quay = OriginalResidentialServiceCatalog.refreshProviderRegistry(
            modelID: 56,
            providerRegistryID: 27,
            providerVTableStaffingValue: 1,
            tradingQuayRegistryIDs: [3, 9]
        )
        XCTAssertEqual(quay?.modelCountDelta, 0)
        XCTAssertEqual(quay?.staffedModelCountDelta, 0)
        XCTAssertEqual(quay?.tradingQuayRegistryIDs, [3, 9, 27])
        XCTAssertEqual(quay?.tradingQuayStaffedCountDelta, 1)
        XCTAssertEqual(quay?.didAppendTradingQuayRegistryID, true)

        let fullQuay = OriginalResidentialServiceCatalog.refreshProviderRegistry(
            modelID: 56,
            providerRegistryID: 31,
            providerVTableStaffingValue: 1,
            tradingQuayRegistryIDs: Array(0..<10)
        )
        XCTAssertEqual(fullQuay?.tradingQuayRegistryIDs, Array(0..<10))
        XCTAssertEqual(fullQuay?.tradingQuayStaffedCountDelta, 0)
        XCTAssertEqual(fullQuay?.didAppendTradingQuayRegistryID, false)

        let well = OriginalResidentialServiceCatalog.refreshProviderRegistry(
            modelID: 72,
            providerRegistryID: 41,
            providerVTableStaffingValue: 0,
            tradingQuayRegistryIDs: [27]
        )
        XCTAssertEqual(well?.modelCountDelta, 1)
        XCTAssertEqual(well?.staffedModelCountDelta, 0)
        XCTAssertEqual(well?.tradingQuayRegistryIDs, [27])
        XCTAssertEqual(well?.tradingQuayStaffedCountDelta, 0)
        XCTAssertEqual(well?.didAppendTradingQuayRegistryID, false)

        XCTAssertNil(
            OriginalResidentialServiceCatalog.refreshProviderRegistry(
                modelID: 56,
                providerRegistryID: 1,
                providerVTableStaffingValue: 1,
                tradingQuayRegistryIDs: Array(0...10)
            )
        )
    }

    func testProviderRegistryRefreshDirectCallsitesRemainPostCreationBoundaries() {
        let callsites = OriginalResidentialServiceCatalog.providerRegistryRefreshDirectCallsites
        XCTAssertEqual(callsites.map(\.callsiteAddress), [0x0048AEB9, 0x004C1288])
        XCTAssertEqual(callsites.map(\.callerAddress), [0x0048AE30, 0x004C1240])
        XCTAssertEqual(
            callsites.map(\.role),
            [
                .entertainmentOpportunityDecay,
                .objectModelStatisticsRefresh,
            ]
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.providerRegistryRefreshCallsite(at: 0x0048AEB9)?.role,
            .entertainmentOpportunityDecay
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerRegistryRefreshCallsite(at: 0x0042D790),
            "the generic map loader has no direct refresh callsite"
        )
    }

    func testEntertainmentProviderObjectCountsSeparateSchoolsAndVenues() {
        let counts = OriginalResidentialServiceCatalog.EntertainmentProviderObjectCounts
            .rebuilt(
                fromActiveObjectModelIDs: [211, 212, 213, 211, 71, 75, 71, 999],
                globalGateOpen: true
            )
        XCTAssertEqual(counts.musicSchool, 2)
        XCTAssertEqual(counts.acrobatSchool, 1)
        XCTAssertEqual(counts.dramaSchool, 1)
        XCTAssertEqual(counts.entertainmentArea, 2)
        XCTAssertEqual(counts.theatrePavilion, 1)
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.EntertainmentProviderObjectCounts.sourceAddress,
            0x00410620
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.EntertainmentProviderObjectCounts.globalGateAddress,
            0x00426D10
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.EntertainmentProviderObjectCounts.schoolModelIDs,
            [211, 212, 213]
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.EntertainmentProviderObjectCounts.venueModelIDs,
            [71, 75]
        )

        let closed = OriginalResidentialServiceCatalog.EntertainmentProviderObjectCounts
            .rebuilt(
                fromActiveObjectModelIDs: [211, 71, 75],
                globalGateOpen: false
            )
        XCTAssertEqual(closed.musicSchool, 0)
        XCTAssertEqual(closed.entertainmentArea, 0)
        XCTAssertEqual(closed.theatrePavilion, 0)
    }

    func testEntertainmentProviderObjectCountsIgnoreQinGenericModelWords() {
        let counts = OriginalResidentialServiceCatalog.EntertainmentProviderObjectCounts
            .rebuilt(
                fromActiveObjectModelIDs: [0, 0, 90, 105, 211],
                globalGateOpen: true
            )

        // Qin generic Building records expose model word 0 in the packed
        // archive; wall/gate model words are separate archive families. Only
        // the explicitly admitted Music School contributes here.
        XCTAssertEqual(counts.musicSchool, 1)
        XCTAssertEqual(counts.acrobatSchool, 0)
        XCTAssertEqual(counts.dramaSchool, 0)
        XCTAssertEqual(counts.entertainmentArea, 0)
        XCTAssertEqual(counts.theatrePavilion, 0)
    }

    func testOriginalEntertainmentProviderFactoryCatalogMatchesExecutableDispatch() {
        let expected: [(Int, OriginalResidentialServiceCatalog.EntertainmentProviderFactoryDescriptor.Family, UInt32, UInt32)] = [
            (211, .music, 0x0048A8E0, 0x007ACEDC),
            (212, .acrobat, 0x0048A900, 0x007AD140),
            (213, .drama, 0x0048A920, 0x007AD3A4),
        ]
        for (buildingID, family, initializer, vtable) in expected {
            let descriptor = OriginalResidentialServiceCatalog
                .entertainmentProviderFactoryDescriptor(
                    forBuildingModelID: buildingID
                )
            XCTAssertEqual(descriptor?.family, family)
            XCTAssertEqual(descriptor?.buildingModelID, buildingID)
            XCTAssertEqual(descriptor?.dispatcherAddress, 0x0051C660)
            XCTAssertEqual(descriptor?.admissionPredicateAddress, 0x0048A7E0)
            XCTAssertEqual(descriptor?.allocationSize, 0x150)
            XCTAssertEqual(descriptor?.initializerAddress, initializer)
            XCTAssertEqual(descriptor?.vtableAddress, vtable)
        }
        XCTAssertNil(
            OriginalResidentialServiceCatalog
                .entertainmentProviderFactoryDescriptor(
                    forBuildingModelID: 210
                )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog
                .entertainmentProviderFactoryDescriptor(
                    forBuildingModelID: 214
                )
        )
    }

    func testEntertainmentFactoryAdmissionPreservesVenueAndSchoolModelSet() {
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentFactoryAdmissionModelIDs,
            Set([71, 75, 211, 212, 213])
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentFactoryAdmissionPredicateAddress,
            0x0048A7E0
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueAdmissionPredicateAddress,
            0x0048B540
        )
        for modelID in [71, 75, 211, 212, 213] {
            XCTAssertTrue(
                OriginalResidentialServiceCatalog.entertainmentFactoryAdmits(modelID: modelID)
            )
        }
        for modelID in [70, 76, 210, 214, 219] {
            XCTAssertFalse(
                OriginalResidentialServiceCatalog.entertainmentFactoryAdmits(modelID: modelID)
            )
        }
    }

    func testEntertainmentVenueVTable280KeepsDistinctAreaAndPavilionCallbacks() {
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueVTable280Offset,
            0x280
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueVTable280Descriptors,
            [
                .init(
                    venueModelID: 71,
                    vtableAddress: 0x007AD878,
                    callbackAddress: 0x0048CE90,
                    role: .figureBootstrap
                ),
                .init(
                    venueModelID: 75,
                    vtableAddress: 0x007AD608,
                    callbackAddress: 0x0048CC80,
                    role: .serialization
                ),
            ]
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueVTable280Descriptor(
                forVenueModelID: 71
            )?.callbackAddress,
            0x0048CE90
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.entertainmentVenueVTable280Descriptor(
                forVenueModelID: 75
            )?.callbackAddress,
            0x0048CC80
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentVenueVTable280Descriptor(
                forVenueModelID: 211
            )
        )
    }

    func testEntertainmentManagerRegistrationDescriptorSeparatesPlacementFromLoad() {
        let descriptor = OriginalResidentialServiceCatalog
            .entertainmentManagerRegistrationDescriptor

        XCTAssertEqual(descriptor.venueModelIDs, [71, 75])
        XCTAssertEqual(descriptor.baseVTableAddress, 0x007ADE08)
        XCTAssertEqual(descriptor.registrationVTableMethodOffset, 0x90)
        XCTAssertEqual(descriptor.registrationCallbackAddress, 0x0048B6D0)
        XCTAssertEqual(descriptor.managerAccessorAddress, 0x0048A340)
        XCTAssertEqual(descriptor.managerAppendWrapperAddress, 0x00490300)
        XCTAssertEqual(descriptor.managerVectorEndpointAddress, 0x004F8200)
        XCTAssertEqual(descriptor.managerVectorAppendAddress, 0x005F01F0)
        XCTAssertEqual(descriptor.venueVTableAddresses, [0x007AD878, 0x007AD608])
        XCTAssertEqual(descriptor.venuePlacementCallbackAddresses, [0x0048D6D0, 0x0048C270])
        XCTAssertEqual(descriptor.venueLoadCallbackAddresses, [0x0048D780, 0x0048BCB0])
        XCTAssertEqual(descriptor.loadRegistrationBridgeAddress, 0x0048B670)
        XCTAssertEqual(descriptor.providerLoadCallbackAddress, 0x0051CB80)

        // Venue load callbacks enter the same registration chain through the
        // base +0xC0 bridge after dispatching the provider-load callback.
        XCTAssertNotEqual(descriptor.registrationCallbackAddress, descriptor.loadRegistrationBridgeAddress)
    }

    func testEntertainmentVenueLifecycleDescriptorsMatchVenueCallbacks() {
        let area = OriginalResidentialServiceCatalog
            .entertainmentVenueLifecycleDescriptor(forVenueModelID: 71)
        XCTAssertEqual(area?.objectSize, 0x230)
        XCTAssertEqual(area?.auxiliaryObjectOffsets, [0x228, 0x22C])
        XCTAssertEqual(area?.auxiliaryConstructorAddresses, [0x0048DC20, 0x0048DB40])
        XCTAssertNil(area?.providerRecordPointerArrayOffset)
        XCTAssertEqual(area?.providerRecordCount, 0)
        XCTAssertEqual(area?.providerRecordPointerStride, 0)
        XCTAssertEqual(area?.refreshVTableMethodOffset, 0x27C)
        XCTAssertEqual(area?.refreshCallbackAddress, 0x0048CE40)

        let theatre = OriginalResidentialServiceCatalog
            .entertainmentVenueLifecycleDescriptor(forVenueModelID: 75)
        XCTAssertEqual(theatre?.objectSize, 0x184)
        XCTAssertEqual(theatre?.auxiliaryObjectOffsets, [0x150, 0x154, 0x158])
        XCTAssertEqual(
            theatre?.auxiliaryConstructorAddresses,
            [0x0048DC20, 0x0048DB40, 0x0048DD70]
        )
        XCTAssertEqual(theatre?.providerRecordPointerArrayOffset, 0x15C)
        XCTAssertEqual(theatre?.providerRecordCount, 10)
        XCTAssertEqual(theatre?.providerRecordPointerStride, 4)
        XCTAssertEqual(theatre?.providerRecordConstructorAddress, 0x00490450)
        XCTAssertEqual(theatre?.providerRecordObjectSize, 0x10)
        XCTAssertEqual(theatre?.providerRecordPayloadSize, 0x24)
        XCTAssertEqual(theatre?.refreshVTableMethodOffset, 0x268)
        XCTAssertEqual(theatre?.refreshCallbackAddress, 0x0048C230)
        XCTAssertNil(
            OriginalResidentialServiceCatalog
                .entertainmentVenueLifecycleDescriptor(forVenueModelID: 74)
        )
    }

    func testEntertainmentAreaSelectionPreservesRotatingVectorOrderAndGates() {
        let providers = [
            OriginalResidentialServiceCatalog.EntertainmentAreaSelectionInput(
                registryID: 10,
                modelID: 211,
                providerAccessAllowed: true,
                staffingValue: 100
            ),
            OriginalResidentialServiceCatalog.EntertainmentAreaSelectionInput(
                registryID: 11,
                modelID: 71,
                providerAccessAllowed: false,
                staffingValue: 100
            ),
            OriginalResidentialServiceCatalog.EntertainmentAreaSelectionInput(
                registryID: 12,
                modelID: 71,
                providerAccessAllowed: true,
                staffingValue: 1
            ),
            OriginalResidentialServiceCatalog.EntertainmentAreaSelectionInput(
                registryID: 13,
                modelID: 75,
                providerAccessAllowed: true,
                staffingValue: 100
            ),
        ]

        let selected = OriginalResidentialServiceCatalog.entertainmentAreaSelection(
            globalGate: true,
            startIndex: 1,
            providers: providers
        )
        XCTAssertEqual(selected?.vectorIndex, 2)
        XCTAssertEqual(selected?.registryID, 12)

        let wrapped = OriginalResidentialServiceCatalog.entertainmentAreaSelection(
            globalGate: true,
            startIndex: 3,
            providers: providers
        )
        XCTAssertEqual(wrapped?.vectorIndex, 2)
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentAreaSelection(
                globalGate: false,
                startIndex: 0,
                providers: providers
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentAreaSelection(
                globalGate: true,
                startIndex: -1,
                providers: providers
            )
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.entertainmentAreaSelection(
                globalGate: true,
                startIndex: providers.count,
                providers: providers
            )
        )
    }

    func testProviderLoadAuxiliaryDescriptorMatchesExecutableConstructionShape() {
        let descriptor = OriginalResidentialServiceCatalog.providerLoadAuxiliaryDescriptor
        XCTAssertEqual(descriptor.loadCallbackAddress, 0x0051CB80)
        XCTAssertEqual(descriptor.genericLoadCallbackAddress, 0x004271B0)
        XCTAssertEqual(descriptor.globalGateAddress, 0x00426D10)
        XCTAssertEqual(descriptor.auxiliaryFactoryAddress, 0x00526830)
        XCTAssertEqual(descriptor.auxiliaryDestructorAddress, 0x00526850)
        XCTAssertEqual(descriptor.auxiliaryReleaseInitializerAddress, 0x00526870)
        XCTAssertEqual(descriptor.auxiliaryAllocationSize, 0x20)
        XCTAssertEqual(descriptor.auxiliaryBaseConstructorAddress, 0x00418D70)
        XCTAssertEqual(descriptor.auxiliaryBaseVTableAddress, 0x007AB3F4)
        XCTAssertEqual(descriptor.auxiliaryDerivedVTableAddress, 0x007B6B3C)
        XCTAssertEqual(descriptor.auxiliaryStoredInputOffset, 0x14)
        XCTAssertEqual(descriptor.providerAuxiliaryFieldOffset, 0x14C)
        XCTAssertEqual(descriptor.providerCallbackVTableMethodOffset, 0x1FC)
        XCTAssertEqual(descriptor.providerAuxiliaryUpdateAddress, 0x0051CC10)
        XCTAssertEqual(descriptor.auxiliaryRefreshInitializerAddress, 0x00418D90)
        XCTAssertEqual(
            OriginalResidentialServiceCatalog.providerLoadCallbackDirectCallSiteAddresses,
            [
                0x0048B678, 0x004C1778, 0x004C3068, 0x00524368,
                0x0054118B, 0x005AB1F8, 0x005D4868, 0x005F11A8,
            ]
        )
    }

    func testProviderVTableSlot200DescriptorsMatchCanonicalTargets() {
        let descriptors = OriginalResidentialServiceCatalog.providerVTableSlot200Descriptors
        XCTAssertEqual(descriptors.count, 6)
        let expected: [([Int], UInt32, UInt32, [(Bool?, UInt32, UInt32, UInt32)])] = [
            ([72, 73], 0x007B5EB4, 0x0051BB60, [(nil, 0x4C55, 4, 100)]),
            ([207], 0x007B6114, 0x0051BCD0, [(nil, 0x4C1E, 4, 88)]),
            ([208], 0x007B6374, 0x0051BDE0, [(nil, 0x4C03, 4, 80)]),
            ([211], 0x007ACEDC, 0x0048B030, [
                (true, 0x4C67, 4, 100), (false, 0x4C69, 0, 100),
            ]),
            ([212], 0x007AD140, 0x0048B1E0, [
                (true, 0x4C94, 4, 80), (false, 0x4C96, 0, 80),
            ]),
            ([213], 0x007AD3A4, 0x0048B3D0, [
                (true, 0x4C6B, 4, 100), (false, 0x4C6D, 0, 100),
            ]),
        ]
        for (descriptor, expected) in zip(descriptors, expected) {
            XCTAssertEqual(descriptor.providerModelIDs, expected.0)
            XCTAssertEqual(descriptor.providerVTableAddress, expected.1)
            XCTAssertEqual(descriptor.slotOffset, 0x200)
            XCTAssertEqual(descriptor.targetAddress, expected.2)
            XCTAssertEqual(descriptor.callbackReturnValue, 1)
            XCTAssertEqual(descriptor.outputEnvelopes.count, expected.3.count)
            for (envelope, expectedEnvelope) in zip(descriptor.outputEnvelopes, expected.3) {
                XCTAssertEqual(envelope.objectWord2EIsNonZero, expectedEnvelope.0)
                XCTAssertEqual(envelope.outputWord0, expectedEnvelope.1)
                XCTAssertEqual(envelope.outputWord1, expectedEnvelope.2)
                XCTAssertEqual(envelope.outputWord2, expectedEnvelope.3)
            }
        }
        XCTAssertTrue(
            descriptors.allSatisfy { !$0.targetIndexedInCorpus },
            "the six callback bodies are direct PE evidence, not split-corpus semantic contracts"
        )
        XCTAssertEqual(
            OriginalResidentialServiceCatalog
                .providerVTableSlot200Descriptor(forProviderModelID: 211)?.targetAddress,
            0x0048B030
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerVTableSlot200Descriptor(
                forProviderModelID: 214
            )
        )
    }

    func testProviderVTableSlot234DescriptorsShareCanonicalSpawnTarget() {
        let descriptors = OriginalResidentialServiceCatalog.providerVTableSlot234Descriptors
        XCTAssertEqual(descriptors.count, 6)
        let expected: [([Int], UInt32)] = [
            ([72, 73], 0x007B5EB4),
            ([207], 0x007B6114),
            ([208], 0x007B6374),
            ([211], 0x007ACEDC),
            ([212], 0x007AD140),
            ([213], 0x007AD3A4),
        ]
        for (descriptor, expected) in zip(descriptors, expected) {
            XCTAssertEqual(descriptor.providerModelIDs, expected.0)
            XCTAssertEqual(descriptor.providerVTableAddress, expected.1)
            XCTAssertEqual(descriptor.slotOffset, 0x234)
            XCTAssertEqual(descriptor.targetAddress, 0x0051CF90)
            XCTAssertTrue(descriptor.targetIndexedInCorpus)
        }
        XCTAssertEqual(
            OriginalResidentialServiceCatalog
                .providerVTableSlot234Descriptor(forProviderModelID: 211)?.targetAddress,
            0x0051CF90
        )
        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerVTableSlot234Descriptor(
                forProviderModelID: 214
            )
        )
    }

    func testProviderLoadAuxiliaryOutcomePreservesGateAndCallbackOrder() {
        let closed = OriginalResidentialServiceCatalog
            .providerLoadAuxiliaryOutcome(
                globalGateOpen: false,
                allocationSucceeded: true,
                providerRegistryID: 17
            )
        XCTAssertTrue(closed.genericLoadCallbackInvoked)
        XCTAssertFalse(closed.allocationAttempted)
        XCTAssertFalse(closed.didAllocateAuxiliary)
        XCTAssertNil(closed.storedInput)
        XCTAssertFalse(closed.didInvokeProviderCallback)

        let allocationFailure = OriginalResidentialServiceCatalog
            .providerLoadAuxiliaryOutcome(
                globalGateOpen: true,
                allocationSucceeded: false,
                providerRegistryID: 23
            )
        XCTAssertTrue(allocationFailure.genericLoadCallbackInvoked)
        XCTAssertTrue(allocationFailure.allocationAttempted)
        XCTAssertFalse(allocationFailure.didAllocateAuxiliary)
        XCTAssertNil(allocationFailure.storedInput)
        XCTAssertFalse(allocationFailure.didInvokeProviderCallback)

        let loaded = OriginalResidentialServiceCatalog
            .providerLoadAuxiliaryOutcome(
                globalGateOpen: true,
                allocationSucceeded: true,
                providerRegistryID: 29
            )
        XCTAssertTrue(loaded.genericLoadCallbackInvoked)
        XCTAssertTrue(loaded.allocationAttempted)
        XCTAssertTrue(loaded.didAllocateAuxiliary)
        XCTAssertEqual(loaded.storedInput, 29)
        XCTAssertTrue(loaded.didInvokeProviderCallback)
    }

    func testQinArchiveRepairSwitchExcludesResidentialServiceProviderModels() {
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.predicateAddress,
            0x0052F1D0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.repairPassAddress,
            0x0052F030
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.admittedModelIDs,
            [
                83, 89, 90, 91, 104, 105, 106, 123, 129, 130, 131, 210,
                231, 232, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262,
                263, 264, 265, 266, 267, 268
            ]
        )

        let serviceModelIDs = Set(
            OriginalResidentialServiceCatalog.configurations.map(\.buildingID)
        )
        XCTAssertTrue(
            serviceModelIDs.isDisjoint(
                with: Set(OriginalMapArchiveRepairCatalog.admittedModelIDs)
            )
        )
        XCTAssertTrue(OriginalMapArchiveRepairCatalog.admits(modelID: 210))
        XCTAssertFalse(OriginalMapArchiveRepairCatalog.admits(modelID: 211))
        XCTAssertFalse(OriginalMapArchiveRepairCatalog.admits(modelID: 219))
    }

    func testQinMapArchiveLoaderKeepsGenericBuildingCallbackBoundary() {
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.mainMapLoadAddress,
            0x0052FDA0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.directPostLoadTailAddresses,
            [
                0x0042D790, 0x004E1E40, 0x00506240, 0x00480740,
                0x00510E60, 0x00564E30, 0x00593140, 0x0052CD90,
                0x00493F00, 0x005501B0,
            ]
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.mapSerializerAddress,
            0x0052E7C0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.buildingArchiveMinimumVersionExclusive,
            3
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.roadWaterAuxiliaryMinimumVersionExclusive,
            4
        )
        XCTAssertFalse(
            OriginalMapArchiveRepairCatalog.serializesBuildingArchive(formatVersion: 3)
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.serializesBuildingArchive(formatVersion: 4)
        )
        XCTAssertFalse(
            OriginalMapArchiveRepairCatalog.serializesRoadWaterAuxiliaryGrid(formatVersion: 4)
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.serializesRoadWaterAuxiliaryGrid(formatVersion: 5)
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.dynamicFactoryAddress,
            0x0042D360
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.dynamicFactoryDirectCallSiteAddresses,
            [0x0042715E, 0x0042D714]
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.dynamicFactoryDirectCallerAddresses,
            [0x00427150, 0x0042D540]
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.dynamicFactoryIndirectResidentialDispatcherAddress,
            0x0051C660
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.dynamicFactoryGenericCallerAddress,
            0x00427150
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.dynamicFactoryGenericCallerOnlyCallerAddress,
            0x00541110
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.mapLoaderAddress,
            0x0042D790
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.genericClassLoaderAddress,
            0x0042D0E0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.genericBuildingConstructorAddress,
            0x0042D050
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.genericBuildingVTableAddress,
            0x007AB59C
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.factoryFallbackConstructorAddress,
            0x0051C9A0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.factoryFallbackVTableAddress,
            0x007B65E4
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.listInsertAddress,
            0x0042B590
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.listInsertHelperAddress,
            0x005F01F0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.loadCallbackVTableOffset,
            0x000000C0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.loadCallbackEligibilityFieldOffset,
            0x04
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.postLoadObjectPassAddress,
            0x0042DA10
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.postLoadObjectCallbackVTableOffset,
            0x000001C8
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.postLoadObjectStateFieldOffset,
            0x04
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.postLoadObjectForcedStateByte,
            0x06
        )
        XCTAssertFalse(
            OriginalMapArchiveRepairCatalog.invokesPostLoadObjectCallback(
                globalGateOpen: false,
                objectStateByte: 0
            )
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.invokesPostLoadObjectCallback(
                globalGateOpen: true,
                objectStateByte: 0
            )
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.invokesPostLoadObjectCallback(
                globalGateOpen: false,
                objectStateByte: 0x06
            )
        )
        XCTAssertFalse(
            OriginalMapArchiveRepairCatalog.invokesPostLoadObjectCallback(
                globalGateOpen: false,
                objectStateByte: 0x05
            )
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.postLoadObjectNoOpCallbackAddress,
            0x00413A00
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.postLoadObjectNoOpVTableDescriptors.map(\.vtableAddress),
            [
                0x007AB59C, 0x007B5EB4, 0x007B6114, 0x007B6374,
                0x007AD878, 0x007ACEDC, 0x007AD140, 0x007AD3A4,
            ]
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.postLoadObjectNoOpVTableDescriptors.allSatisfy {
                $0.callbackAddress == 0x00413A00
            }
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.postLoadObjectNoOpVTableDescriptor(
                forVTableAddress: 0x007B5EB4
            )?.label,
            "Well"
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.postLoadObjectCallbackIsNoOp(
                forVTableAddress: 0x007AD878
            )
        )
        XCTAssertFalse(
            OriginalMapArchiveRepairCatalog.postLoadObjectCallbackIsNoOp(
                forVTableAddress: 0x007ABA38
            )
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.cMarketVTableAddress,
            0x007B6F3C
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.cMarketPostLoadThunkAddress,
            0x00543770
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.cMarketHelperPostLoadAddress(
                forMarketBuildingID: 59
            ),
            0x00413A00
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.cMarketHelperPostLoadAddress(
                forMarketBuildingID: 60
            ),
            0x00543360
        )
        XCTAssertNil(
            OriginalMapArchiveRepairCatalog.cMarketHelperPostLoadAddress(
                forMarketBuildingID: 61
            )
        )
        XCTAssertFalse(
            OriginalMapArchiveRepairCatalog.invokesLoadCallback(eligibilityByte: 0)
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.invokesLoadCallback(eligibilityByte: 1)
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.invokesLoadCallback(eligibilityByte: 0xFF)
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.genericLoadCallbackAddress,
            0x004271B0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.genericClassToken,
            "Building"
        )
    }

    func testMapLinkedObjectCallbackVTableBoundaryKeepsGenericQinRowsFailClosed() {
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.linkedObjectCallbackAddress,
            0x004B11F0
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.linkedObjectCallbackVTableOffset,
            0x100
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.genericBuildingLinkedCallbackAddress,
            0x00428F10
        )
        XCTAssertTrue(
            OriginalMapArchiveRepairCatalog.genericBuildingLinkedCallbackReturnsFalse
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.houseBldgLinkedCallbackAddress,
            0x00519F30
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.residentialServiceLinkedCallbackAddress,
            0x0051DD20
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.entertainmentAreaLinkedCallbackAddress,
            0x0048D230
        )

        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.linkedObjectCallbackVTableDescriptors.map(\.label),
            [
                "Building", "HouseBldg", "Well", "Herbalist", "Acupuncture",
                "Entertainment Area", "Music School", "Acrobat School", "Drama School",
            ]
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.linkedObjectCallbackAddress(
                forVTableAddress: 0x007AB59C
            ),
            0x00428F10
        )
        XCTAssertEqual(
            OriginalMapArchiveRepairCatalog.linkedObjectCallbackAddress(
                forVTableAddress: 0x007ABA38
            ),
            0x00519F30
        )
        XCTAssertNil(
            OriginalMapArchiveRepairCatalog.linkedObjectCallbackAddress(
                forVTableAddress: 0x007B65E4
            )
        )
    }

    func testQinMapLoadRehydrationChainMatchesCanonicalCallOrder() {
        XCTAssertEqual(OriginalMapLoadRehydrationChain.loadEntryAddress, 0x0043ABF0)
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.genericBuildingVTableAddress,
            0x007AB59C
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.genericBuildingLoadCallbackAddress,
            0x004271B0
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.genericBuildingLoadCallbackPredicateSlot,
            0x150
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.genericBuildingDefaultPredicateAddress,
            0x00413A00
        )
        XCTAssertTrue(
            OriginalMapLoadRehydrationChain.genericBuildingDefaultPredicateReturnsFalse
        )
        XCTAssertEqual(OriginalMapLoadRehydrationChain.rebuildSequenceAddress, 0x0053D100)
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.postRehydrationCallSequence,
            [
                0x0053D630, 0x0053CAE0, 0x0053CBD0,
                0x005ADDD0, 0x005ADD10, 0x005AD8F0,
                0x00522810, 0x005ADD40, 0x00468B80,
            ]
        )
        XCTAssertEqual(OriginalMapLoadRehydrationChain.rehydrationPassAddress, 0x0052F030)
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.rehydrationPredicateAddress,
            0x0052F1D0
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.rehydrationPassDirectCallerAddresses,
            [0x0053D100]
        )
        XCTAssertEqual(OriginalMapLoadRehydrationChain.rehydrationVectorStartIndex, 1)
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.rehydrationObjectActiveFieldOffset,
            0x04
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.rehydrationObjectModelFieldOffset,
            0x14
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.rehydrationObjectCoordinateXOffset,
            0x0A
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.rehydrationObjectCoordinateYOffset,
            0x0C
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.rehydrationCreationAddress,
            0x0042D540
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.creationRegistryFieldOffset,
            0xB4
        )
        XCTAssertEqual(
            OriginalMapLoadRehydrationChain.creationRegistryFieldSourceAddress,
            0x00413B40
        )
        XCTAssertTrue(
            OriginalMapLoadRehydrationChain.creationRegistryFieldStoresVectorSlot
        )
    }

    func testMapArchiveRuntimeClassDispatchMatchesMFCReaderBoundary() {
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.buildingRuntimeClassAddress,
            0x00817890
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.readObjectCallerAddress,
            0x0042D0E0
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.readObjectAddress,
            0x0077FD90
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.objectTagReaderAddress,
            0x0077FFC8
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.classNameResolverAddress,
            0x007802FE
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.newClassMarker,
            0xFFFF
        )
        XCTAssertTrue(
            OriginalMapArchiveRuntimeClassCatalog.resolverUsesExactClassNameMatch
        )
        XCTAssertTrue(
            OriginalMapArchiveRuntimeClassCatalog
                .invokesSelectedClassConstructorAndSerializer
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.mapLoaderDirectCallerAddresses,
            [0x0042D0E0]
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.archiveObjectVectorInsertAddress,
            0x0042B590
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.archiveObjectVectorInsertHelperAddress,
            0x005F01F0
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.archiveObjectVectorArrayInsertAddress,
            0x005C1670
        )
        XCTAssertTrue(
            OriginalMapArchiveRuntimeClassCatalog.archiveObjectVectorInsertUsesCurrentEnd
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.archiveObjectVectorInsertCount,
            1
        )
        XCTAssertFalse(
            OriginalMapArchiveRuntimeClassCatalog.archiveObjectVectorInsertWritesRegistryField
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.archiveReferenceWriterAddress,
            0x0077FD11
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.archiveReferenceWriteBridgeAddress,
            0x0042DC60
        )
        XCTAssertEqual(
            OriginalMapArchiveRuntimeClassCatalog.archiveReferenceTokenCounterOffset,
            0x30
        )
        XCTAssertTrue(
            OriginalMapArchiveRuntimeClassCatalog.archiveReferenceWriterUsesMFCReferenceTable
        )
        XCTAssertFalse(
            OriginalMapArchiveRuntimeClassCatalog.archiveReferenceWriterReadsModelField
        )
        XCTAssertFalse(
            OriginalMapArchiveRuntimeClassCatalog.archiveReferenceWriterReadsProviderRegistryField
        )
    }

    func testRecoveredWellProviderSelectsDistinctHouseInfoWaterByte() {
        // The helper receives the Well provider's recovered +0x224 result
        // explicitly. The ordinary context writes +0x32; only the recovered
        // active/3/4 context predicate selects +0x34 when that result is false.
        XCTAssertEqual(
            OriginalWaterProviderState.houseInfoWaterByte(
                providerVTable224: false,
                globalContextActive: false,
                globalState54: 3,
                globalState58: 4
            ),
            .primary32
        )
        XCTAssertEqual(
            OriginalWaterProviderState.houseInfoWaterByte(
                providerVTable224: false,
                globalContextActive: true,
                globalState54: 3,
                globalState58: 4
            ),
            .secondary34
        )
        XCTAssertEqual(
            OriginalWaterProviderState.houseInfoWaterByte(
                providerVTable224: true,
                globalContextActive: true,
                globalState54: 3,
                globalState58: 4
            ),
            .secondary34
        )
    }

    func testWellProviderPhase24SchedulerPreservesVectorOrderAndEligibilityGate() {
        // FUN_00517AD0 walks the live provider vector as stored; it does not
        // sort, compact, or update entries whose +0xB8 virtual eligibility
        // callback is false.
        XCTAssertEqual(
            OriginalWaterProviderState.phase24ProviderUpdateIndices(
                globalGateOpen: true,
                providerEligibility: [false, true, false, true]
            ),
            [1, 3]
        )
        XCTAssertEqual(
            OriginalWaterProviderState.phase24ProviderUpdateIndices(
                globalGateOpen: false,
                providerEligibility: [true, true, true]
            ),
            []
        )
        XCTAssertEqual(
            OriginalWaterProviderState.phase24ProviderUpdateIndices(
                globalGateOpen: true,
                providerEligibility: []
            ),
            []
        )
    }

    func testOriginalWaterProviderSchedulerBoundaryMatchesCanonicalCallCensus() {
        let boundary = OriginalWaterProviderState.ProviderSchedulerBoundary.self
        XCTAssertEqual(boundary.schedulerAddress, 0x00517AD0)
        XCTAssertEqual(boundary.phaseDispatcherAddress, 0x004AC2B0)
        XCTAssertEqual(boundary.phaseValue, 0x24)
        XCTAssertEqual(boundary.directCallSites, [0x004AC473])
        XCTAssertEqual(boundary.directCallerAddresses, [0x004AC2B0])
        XCTAssertEqual(boundary.providerEligibilityVTableOffset, 0xB8)
        XCTAssertEqual(boundary.providerUpdateVTableOffset, 0x218)
        XCTAssertEqual(boundary.globalGateAddress, 0x00426D10)
    }

    func testProviderSpawnAggregatePreservesThreeSourceGatesAndReturnReduction() {
        // FUN_00517A40 admits a vector row only after the global gate, +0xB8,
        // and +0x204 gates; +0x234's already-resolved return is then summed.
        let aggregate = OriginalResidentialServiceCatalog.providerSpawnAggregate(
            globalGateOpen: true,
            providerEligibility: [true, false, true, true],
            providerCapacityEligibility: [true, true, false, true],
            spawnResults: [1, 7, 11, 2]
        )
        XCTAssertEqual(aggregate?.admittedIndices, [0, 3])
        XCTAssertEqual(aggregate?.total, 3)

        let closed = OriginalResidentialServiceCatalog.providerSpawnAggregate(
            globalGateOpen: false,
            providerEligibility: [true],
            providerCapacityEligibility: [true],
            spawnResults: [9]
        )
        XCTAssertEqual(closed?.admittedIndices, [])
        XCTAssertEqual(closed?.total, 0)

        XCTAssertNil(
            OriginalResidentialServiceCatalog.providerSpawnAggregate(
                globalGateOpen: true,
                providerEligibility: [true],
                providerCapacityEligibility: [],
                spawnResults: [1]
            )
        )
    }

    func testNewWellProviderInitializesWaterPredicateInputsToZero() {
        let initial = OriginalWaterProviderState.NewlyConstructedProviderState.well
        XCTAssertEqual(initial.providerWord16, 0)
        XCTAssertEqual(initial.providerByte6F, 0)
        XCTAssertEqual(
            OriginalWaterProviderState.NewlyConstructedProviderState.sourceConstructorAddress,
            0x0051C2E0
        )
        XCTAssertEqual(
            OriginalWaterProviderState.houseInfoWaterByte(
                providerVTable224: OriginalWaterProviderState.providerVTable224Predicate(
                    providerWord16: initial.providerWord16,
                    providerByte6F: initial.providerByte6F
                ),
                globalContextActive: false,
                globalState54: 0,
                globalState58: 0
            ),
            .primary32
        )
    }

    func testRecoveredWellProviderPredicatePreservesFieldWidthsAndSignedness() {
        XCTAssertFalse(
            OriginalWaterProviderState.providerVTable224Predicate(
                providerWord16: 0,
                providerByte6F: 0
            )
        )
        XCTAssertTrue(
            OriginalWaterProviderState.providerVTable224Predicate(
                providerWord16: 1,
                providerByte6F: 0
            )
        )
        XCTAssertTrue(
            OriginalWaterProviderState.providerVTable224Predicate(
                providerWord16: 0,
                providerByte6F: 1
            )
        )
        // 0xFFFF is -1 for the signed word compare and must not satisfy `jg`.
        XCTAssertFalse(
            OriginalWaterProviderState.providerVTable224Predicate(
                providerWord16: -1,
                providerByte6F: 0
            )
        )
        XCTAssertTrue(
            OriginalWaterProviderState.providerVTable224Predicate(
                providerWord16: -1,
                providerByte6F: 0xFF
            )
        )
    }

    func testWellCommandStateWriterPreservesHigherExistingByte() {
        XCTAssertEqual(OriginalWaterProviderState.wellCommandStateValue, 0x60)
        XCTAssertEqual(
            OriginalWaterProviderState.raisedWellCommandState(currentByte6F: 0),
            0x60
        )
        XCTAssertEqual(
            OriginalWaterProviderState.raisedWellCommandState(currentByte6F: 0x5F),
            0x60
        )
        XCTAssertEqual(
            OriginalWaterProviderState.raisedWellCommandState(currentByte6F: 0x60),
            0x60
        )
        XCTAssertEqual(
            OriginalWaterProviderState.raisedWellCommandState(currentByte6F: 0xFF),
            0xFF
        )
    }

    func testWellAdjacencyTargetAdmissionPreservesControllerCategoryWhitelists() {
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 6, targetModelID: 72
            ),
            .accepted
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 6, targetModelID: 73
            ),
            .accepted
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 6, targetModelID: 71
            ),
            .rejected
        )

        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 0, targetModelID: 124
            ),
            .accepted
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 11, targetModelID: 58
            ),
            .accepted
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 11, targetModelID: 72
            ),
            .rejected
        )
    }

    func testWellAdjacencyTargetAdmissionKeepsActiveAndAuxiliaryGatesExplicit() {
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 6,
                targetModelID: 72,
                targetReportsActive: true
            ),
            .rejected
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 4, targetModelID: 59
            ),
            .requiresAuxiliaryCheck
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 4,
                targetModelID: 59,
                auxiliaryCheckPassed: true
            ),
            .accepted
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 4, targetModelID: 66
            ),
            .accepted
        )
        XCTAssertEqual(
            OriginalWaterProviderState.adjacentTargetAdmission(
                sourceCategory: 12, targetModelID: 72
            ),
            .rejected
        )
    }

    func testWellCommandStateDecayMatchesSchedulerWrapBoundary() {
        let closed = OriginalWaterProviderState.decayCommandState(
            currentByte6F: 0x60,
            globalGateOpen: false
        )
        XCTAssertEqual(closed.nextByte6F, 0x60)
        XCTAssertFalse(closed.didExpire)

        let ordinary = OriginalWaterProviderState.decayCommandState(
            currentByte6F: 2,
            globalGateOpen: true
        )
        XCTAssertEqual(ordinary.nextByte6F, 1)
        XCTAssertFalse(ordinary.didExpire)

        let expiry = OriginalWaterProviderState.decayCommandState(
            currentByte6F: 1,
            globalGateOpen: true
        )
        XCTAssertEqual(expiry.nextByte6F, 0)
        XCTAssertTrue(expiry.didExpire)

        let alreadyClear = OriginalWaterProviderState.decayCommandState(
            currentByte6F: 0,
            globalGateOpen: true
        )
        XCTAssertEqual(alreadyClear.nextByte6F, 0)
        XCTAssertFalse(alreadyClear.didExpire)
    }

    func testProviderParentShortIsClearedUnlessTargetIsActiveAndOwned() {
        XCTAssertEqual(
            OriginalWaterProviderState.validatedParentShort(
                parentShort: 17,
                targetActiveByte: 1,
                targetField68: 27,
                providerRegistryID: 27
            ),
            17
        )
        XCTAssertEqual(
            OriginalWaterProviderState.validatedParentShort(
                parentShort: 17,
                targetActiveByte: 0,
                targetField68: 27,
                providerRegistryID: 27
            ),
            0
        )
        XCTAssertEqual(
            OriginalWaterProviderState.validatedParentShort(
                parentShort: 17,
                targetActiveByte: 1,
                targetField68: 26,
                providerRegistryID: 27
            ),
            0
        )
        XCTAssertEqual(
            OriginalWaterProviderState.validatedParentShort(
                parentShort: 0,
                targetActiveByte: 0,
                targetField68: -1,
                providerRegistryID: 27
            ),
            0
        )
    }

    func testRegistryParentChainStopsAtSignedRootAndPreservesSourceHopLimit() {
        XCTAssertEqual(OriginalWaterProviderState.registryParentLinkFieldOffset, 0x3C)
        XCTAssertEqual(OriginalWaterProviderState.registryParentMaximumHops, 500)

        XCTAssertEqual(
            OriginalWaterProviderState.resolveRegistryParentChain(
                startRegistryID: 1,
                parentRegistryIDs: [1: 2, 2: 3, 3: 0]
            ),
            .terminal(registryID: 3)
        )
        XCTAssertEqual(
            OriginalWaterProviderState.resolveRegistryParentChain(
                startRegistryID: 1,
                parentRegistryIDs: [1: 2]
            ),
            .missing(registryID: 2)
        )

        let positiveChain = Dictionary(
            uniqueKeysWithValues: (1...501).map { ($0, Int16($0 + 1)) }
        )
        XCTAssertEqual(
            OriginalWaterProviderState.resolveRegistryParentChain(
                startRegistryID: 1,
                parentRegistryIDs: positiveChain
            ),
            .sourceZeroAfterHopLimit
        )
    }

    func testResidentialProviderLinkSlotsRequireSourceOwnershipAndActivation() {
        XCTAssertEqual(
            OriginalResidentialProviderLinkCatalog.Slot.allCases.map(\.rawValue),
            [0x2E, 0x6A, 0x6C]
        )
        XCTAssertTrue(
            OriginalResidentialProviderLinkCatalog.validatesTypedLink(
                providerActive: true,
                providerType: 0x12,
                acceptedTypeA: 0x11,
                acceptedTypeB: 0x12,
                providerParentID: 27,
                houseRegistryID: 27
            )
        )
        XCTAssertFalse(
            OriginalResidentialProviderLinkCatalog.validatesTypedLink(
                providerActive: true,
                providerType: 0x13,
                acceptedTypeA: 0x11,
                acceptedTypeB: 0x12,
                providerParentID: 27,
                houseRegistryID: 27
            )
        )
        XCTAssertFalse(
            OriginalResidentialProviderLinkCatalog.validatesTypedLink(
                providerActive: false,
                providerType: 0x12,
                acceptedTypeA: 0x11,
                acceptedTypeB: 0x12,
                providerParentID: 27,
                houseRegistryID: 27
            )
        )
        XCTAssertTrue(
            OriginalResidentialProviderLinkCatalog.validatesUntypedLink(
                providerActive: true,
                providerParentID: 27,
                houseRegistryID: 27
            )
        )
        XCTAssertFalse(
            OriginalResidentialProviderLinkCatalog.validatesUntypedLink(
                providerActive: true,
                providerParentID: 26,
                houseRegistryID: 27
            )
        )
    }

    func testRecoveredWaterCallbackWritesSelectedByteOnlyAfterAllGates() {
        let blocked = OriginalWaterProviderState.writeHouseInfoWater(
            globalGateOpen: true,
            targetVTableB8: true,
            targetField20: 0,
            providerVTable224: false,
            globalContextActive: false,
            globalState54: 0,
            globalState58: 0,
            primary32: 7,
            secondary34: 9
        )
        XCTAssertFalse(blocked.didWrite)
        XCTAssertNil(blocked.destination)
        XCTAssertEqual(blocked.primary32, 7)
        XCTAssertEqual(blocked.secondary34, 9)

        for (globalGateOpen, targetVTableB8, targetField20) in [
            (false, true, 1),
            (true, false, 1),
        ] {
            let gateBlocked = OriginalWaterProviderState.writeHouseInfoWater(
                globalGateOpen: globalGateOpen,
                targetVTableB8: targetVTableB8,
                targetField20: targetField20,
                providerVTable224: false,
                globalContextActive: false,
                globalState54: 0,
                globalState58: 0,
                primary32: 7,
                secondary34: 9
            )
            XCTAssertFalse(gateBlocked.didWrite)
            XCTAssertNil(gateBlocked.destination)
            XCTAssertEqual(gateBlocked.primary32, 7)
            XCTAssertEqual(gateBlocked.secondary34, 9)
        }

        let primary = OriginalWaterProviderState.writeHouseInfoWater(
            globalGateOpen: true,
            targetVTableB8: true,
            targetField20: 1,
            providerVTable224: false,
            globalContextActive: false,
            globalState54: 0,
            globalState58: 0,
            primary32: 7,
            secondary34: 9
        )
        XCTAssertTrue(primary.didWrite)
        XCTAssertEqual(primary.destination, .primary32)
        XCTAssertEqual(primary.primary32, 0x60)
        XCTAssertEqual(primary.secondary34, 9)

        let secondaryFromProvider = OriginalWaterProviderState.writeHouseInfoWater(
            globalGateOpen: true,
            targetVTableB8: true,
            targetField20: 1,
            providerVTable224: true,
            globalContextActive: false,
            globalState54: 0,
            globalState58: 0,
            primary32: 7,
            secondary34: 9
        )
        XCTAssertEqual(secondaryFromProvider.destination, .secondary34)
        XCTAssertEqual(secondaryFromProvider.primary32, 7)
        XCTAssertEqual(secondaryFromProvider.secondary34, 0x60)

        let secondaryFromGlobal = OriginalWaterProviderState.writeHouseInfoWater(
            globalGateOpen: true,
            targetVTableB8: true,
            targetField20: 1,
            providerVTable224: false,
            globalContextActive: true,
            globalState54: 3,
            globalState58: 4,
            primary32: 7,
            secondary34: 9
        )
        XCTAssertEqual(secondaryFromGlobal.destination, .secondary34)
        XCTAssertEqual(secondaryFromGlobal.primary32, 7)
        XCTAssertEqual(secondaryFromGlobal.secondary34, 0x60)
    }

    func testHouseVacantTypeTransitionPreservesSourceGateOrder() {
        XCTAssertEqual(
            OriginalHouseVacantTypeTransition.dispatchAddress,
            0x00519F30
        )
        XCTAssertEqual(
            OriginalHouseVacantTypeTransition.cHouseInfoGetterVTableOffset,
            0x1E4
        )
        XCTAssertEqual(
            OriginalHouseVacantTypeTransition.providerPredicateVTableOffset,
            0x204
        )
        XCTAssertEqual(
            OriginalHouseVacantTypeTransition.vacantRebuildAddress,
            0x00519060
        )
        XCTAssertEqual(
            OriginalHouseVacantTypeTransition.typeSwitchVTableOffset,
            0x230
        )

        XCTAssertEqual(
            OriginalHouseVacantTypeTransition.action(
                houseInfoGateIsZero: true,
                residentWordIsZero: true,
                providerPredicatePasses: false,
                objectRegistryIndex: 41,
                typeSwitchArgument: 3
            ),
            .rebuildVacant(objectRegistryIndex: 41)
        )

        for input in [
            (false, true, false),
            (true, false, false),
            (true, true, true),
        ] {
            XCTAssertEqual(
                OriginalHouseVacantTypeTransition.action(
                    houseInfoGateIsZero: input.0,
                    residentWordIsZero: input.1,
                    providerPredicatePasses: input.2,
                    objectRegistryIndex: 41,
                    typeSwitchArgument: 13
                ),
                .invokeTypeSwitch(argument: 13)
            )
        }
    }

    func testRecoveredWaterProjectsToBuildingStatusWithSecondaryPrecedence() {
        XCTAssertEqual(
            OriginalWaterProviderState.buildingWaterStatus(primary32: 0, secondary34: 0),
            .none
        )
        XCTAssertEqual(
            OriginalWaterProviderState.buildingWaterStatus(primary32: 0x60, secondary34: 0),
            .primary32
        )
        XCTAssertEqual(
            OriginalWaterProviderState.buildingWaterStatus(primary32: 0, secondary34: 0x60),
            .secondary34
        )
        XCTAssertEqual(
            OriginalWaterProviderState.buildingWaterStatus(primary32: 0x60, secondary34: 0x60),
            .secondary34
        )
    }

    func testOriginalHouseInfoServiceCountdownPreservesSourceGateAndExpiryOrder() {
        let closed = OriginalHouseInfoServiceCountdown.advance(
            globalGateOpen: false,
            objectEligible: true,
            flag3CSet: true,
            residentWord: 5,
            countdown: 2
        )
        XCTAssertEqual(closed.nextCountdown, 2)
        XCTAssertTrue(closed.nextFlag3C)
        XCTAssertEqual(closed.globalCounterDelta, 0)
        XCTAssertFalse(closed.didAdvance)

        let vacant = OriginalHouseInfoServiceCountdown.advance(
            globalGateOpen: true,
            objectEligible: true,
            flag3CSet: true,
            residentWord: 0,
            countdown: 2
        )
        XCTAssertEqual(vacant.nextCountdown, 0)
        XCTAssertFalse(vacant.nextFlag3C)
        XCTAssertEqual(vacant.globalCounterDelta, 0)
        XCTAssertFalse(vacant.didAdvance)
        XCTAssertTrue(vacant.didClearFlag)

        let active = OriginalHouseInfoServiceCountdown.advance(
            globalGateOpen: true,
            objectEligible: true,
            flag3CSet: true,
            residentWord: -1,
            countdown: 2
        )
        XCTAssertEqual(active.nextCountdown, 1)
        XCTAssertTrue(active.nextFlag3C)
        XCTAssertEqual(active.globalCounterDelta, 1)
        XCTAssertTrue(active.didAdvance)
        XCTAssertFalse(active.didClearFlag)

        let expired = OriginalHouseInfoServiceCountdown.advance(
            globalGateOpen: true,
            objectEligible: true,
            flag3CSet: true,
            residentWord: 1,
            countdown: 1
        )
        XCTAssertEqual(expired.nextCountdown, 0)
        XCTAssertFalse(expired.nextFlag3C)
        XCTAssertEqual(expired.globalCounterDelta, 1)
        XCTAssertTrue(expired.didAdvance)
        XCTAssertTrue(expired.didClearFlag)
    }

    func testOriginalHouseInfoCountdownDecayKeepsWaterBytesIndependent() {
        var state = OriginalHouseInfoCountdownState(
            field2A: 2,
            field2B: 1,
            field2C: 0x60,
            field2D: 0,
            field2E: 3,
            field32: 0x60,
            field33: 4,
            field34: 1,
            fields0DThrough10: [0, 1, 2, 0x60]
        )

        state.advanceOriginalServiceDecaySlice()

        // `0x517280` applies the <2→0 rule independently to +0x32 and
        // +0x34; one live water byte cannot clear the other.
        XCTAssertEqual(state.field2A, 1)
        XCTAssertEqual(state.field2B, 0)
        XCTAssertEqual(state.field2C, 0x5F)
        XCTAssertEqual(state.field2D, 0)
        XCTAssertEqual(state.field2E, 2)
        XCTAssertEqual(state.field32, 0x5F)
        XCTAssertEqual(state.field33, 3)
        XCTAssertEqual(state.field34, 0)
        XCTAssertEqual(state.fields0DThrough10, [0, 0, 1, 0x5F])

        state.advanceOriginalServiceDecaySlice()
        XCTAssertEqual(state.field2A, 0)
        XCTAssertEqual(state.field2E, 1)
        XCTAssertEqual(state.field32, 0x5E)
        XCTAssertEqual(state.fields0DThrough10, [0, 0, 0, 0x5E])
    }

    func testOriginalHouseInfoCountdownDecayNormalizesFixedWidthTransientFields() {
        var state = OriginalHouseInfoCountdownState(
            fields0DThrough10: [0x80, 0xFF]
        )
        XCTAssertEqual(state.fields0DThrough10.count, 4)

        state.advanceOriginalServiceDecaySlice()

        // The source uses a byte-sized `char*` loop and decrements every
        // non-zero element; wrapping is retained for high-bit values.
        XCTAssertEqual(state.fields0DThrough10, [0x7F, 0xFE, 0, 0])
    }

    func testRecoveredMapObjectGridWriterUsesSixBySixTableAndDirectionalEdge() throws {
        let table = OriginalMapObjectGridProjection.canonicalOffsetTable
        let base = 500
        let origin = GridPoint(x: 3, y: 4)
        let writes = try XCTUnwrap(OriginalMapObjectGridProjection.project(
            origin: origin,
            width: 3,
            height: 2,
            direction: 4,
            baseLinearOffset: base,
            registryID: 27,
            auxiliaryValue: 0x612,
            overlayFlags: 0x8008,
            priorTerrainWords: [
                base + origin.y * 0xE4 + origin.x: 0xFFFF_FFFF,
            ],
            offsetTable: table
        ))

        XCTAssertEqual(writes.map(\.tableIndex), [0, 1, 2, 6, 7, 8])
        XCTAssertEqual(writes.map(\.linearOffset), [
            500 + 4 * 0xE4 + 3,
            500 + 4 * 0xE4 + 3 + 1,
            500 + 4 * 0xE4 + 3 + 2,
            500 + 4 * 0xE4 + 3 + 0xE4,
            500 + 4 * 0xE4 + 3 + 0xE4 + 1,
            500 + 4 * 0xE4 + 3 + 0xE4 + 2,
        ])
        XCTAssertEqual(writes.map(\.directionByte), [0, 1, 2, 8, 9, 10])
        XCTAssertEqual(writes.map(\.footprintCode), [2, 2, 2, 2, 2, 2])
        XCTAssertEqual(writes.map(\.edgeMarked), [false, false, true, false, false, false])
        XCTAssertEqual(writes[0].terrainWord, 0x9387_2790 | 0x8008)
        XCTAssertEqual(writes[1].terrainWord, 0x8008)
        XCTAssertTrue(writes.allSatisfy {
            $0.registryID == 27 && $0.auxiliaryValue == 0x612
        })
    }

    func testRecoveredCanonicalMapObjectOffsetTableMatchesAuthoredSixBySixData() {
        let table = OriginalMapObjectGridProjection.canonicalOffsetTable
        XCTAssertEqual(table.count, 36)
        XCTAssertEqual(table[0].linearOffset, 0)
        XCTAssertEqual(table[5].linearOffset, 5)
        XCTAssertEqual(table[6].linearOffset, 0xE4)
        XCTAssertEqual(table[35].linearOffset, 0x474 + 5)
        XCTAssertEqual(table.map(\.directionByte), [
            0, 1, 2, 3, 4, 5,
            8, 9, 10, 11, 12, 13,
            16, 17, 18, 19, 20, 21,
            24, 25, 26, 27, 28, 29,
            32, 33, 34, 35, 36, 37,
            40, 41, 42, 43, 44, 45,
        ])
    }

    func testRecoveredMapObjectGridWriterRejectsUnsupportedTableOrDirection() {
        let table = [OriginalMapObjectGridProjection.OffsetEntry](repeating: .init(
            linearOffset: 0,
            directionByte: 0
        ), count: 36)
        XCTAssertNil(OriginalMapObjectGridProjection.project(
            origin: GridPoint(x: 0, y: 0),
            width: 7,
            height: 1,
            direction: 0,
            baseLinearOffset: 0,
            registryID: 1,
            auxiliaryValue: 0,
            overlayFlags: 0,
            priorTerrainWords: [:],
            offsetTable: table
        ))
        XCTAssertNil(OriginalMapObjectGridProjection.project(
            origin: GridPoint(x: 0, y: 0),
            width: 1,
            height: 1,
            direction: 1,
            baseLinearOffset: 0,
            registryID: 1,
            auxiliaryValue: 0,
            overlayFlags: 0,
            priorTerrainWords: [:],
            offsetTable: table
        ))
    }

    func testQinMapObjectRegistrySanitizationKeepsOnlyLiveModeledIDs() {
        let sanitizer = OriginalMapObjectRegistrySanitization.self
        XCTAssertEqual(sanitizer.sanitizerAddress, 0x0053D630)
        XCTAssertEqual(sanitizer.mapRegistryGridAddress, 0x00FC3750)
        XCTAssertEqual(sanitizer.mapRegistryGridEndExclusiveAddress, 0x00FDCD70)
        XCTAssertEqual(sanitizer.mapRegistryGridEntryWidthBytes, 2)
        XCTAssertEqual(sanitizer.mapRegistryGridSide, 228)
        XCTAssertEqual(sanitizer.mapRegistryGridCellCount, 228 * 228)
        XCTAssertEqual(sanitizer.liveObjectCountAddress, 0x00554C00)
        XCTAssertEqual(sanitizer.objectLookupAddress, 0x0047F1B0)
        XCTAssertEqual(sanitizer.modelWordOffset, 0x14)

        XCTAssertFalse(sanitizer.retains(registryID: 0, liveObjectCount: 10, modelWord: 1))
        XCTAssertFalse(sanitizer.retains(registryID: -1, liveObjectCount: 10, modelWord: 1))
        XCTAssertFalse(sanitizer.retains(registryID: 10, liveObjectCount: 10, modelWord: 1))
        XCTAssertFalse(sanitizer.retains(registryID: 3, liveObjectCount: 10, modelWord: 0))
        XCTAssertFalse(sanitizer.retains(registryID: 3, liveObjectCount: 10, modelWord: nil))
        XCTAssertTrue(sanitizer.retains(registryID: 1, liveObjectCount: 10, modelWord: 0x48))
    }

    func testQinAppealReaderUsesCanonicalObjectMapIndex() {
        let descriptor = OriginalAppealPropagationCatalog.commonSingleCellReaderDescriptor
        XCTAssertEqual(descriptor.functionAddress, 0x004273D0)
        XCTAssertEqual(descriptor.objectMapIndexOffset, 0x10)
        XCTAssertEqual(descriptor.appealBufferAddress, 0x00F11C70)
        XCTAssertEqual(descriptor.intermediateCallAddress, 0x0053C870)
        XCTAssertEqual(descriptor.bufferReadHelperAddress, 0x0044F180)
        XCTAssertEqual(descriptor.mapStride, 0xE4)
        XCTAssertEqual(descriptor.qinVTableAddresses, [
            0x007AB59C, 0x007ABA38, 0x007AD878,
            0x007B5EB4, 0x007B6114, 0x007B6374,
        ])
    }

    func testRecoveredAppealPropagationRingGeometry() {
        let single = try! XCTUnwrap(
            OriginalAppealPropagationCatalog.squareRingOffsets(
                footprintSide: 1,
                radius: 1
            )
        )
        XCTAssertEqual(single.count, 8)
        XCTAssertEqual(single.first, GridPoint(x: -1, y: -1))
        XCTAssertEqual(single.last, GridPoint(x: 1, y: 1))
        XCTAssertEqual(Set(single).count, single.count)

        for side in 1...6 {
            for radius in 1...10 {
                let ring = try! XCTUnwrap(
                    OriginalAppealPropagationCatalog.squareRingOffsets(
                        footprintSide: side,
                        radius: radius
                    )
                )
                let expectedCount = side == 1
                    ? 8 * radius
                    : 4 * (side + 2 * radius - 1)
                XCTAssertEqual(ring.count, expectedCount, "side \(side), radius \(radius)")
                XCTAssertEqual(Set(ring).count, ring.count, "side \(side), radius \(radius)")
                XCTAssertTrue(ring.allSatisfy { point in
                    if side == 1 {
                        return max(abs(point.x), abs(point.y)) == radius
                    }
                    let inside = point.x >= 0 && point.x < side && point.y >= 0 && point.y < side
                    return !inside
                        && point.x >= -radius
                        && point.x < side + radius
                        && point.y >= -radius
                        && point.y < side + radius
                })
            }
        }

        // `FUN_0044CDE0` is not an axis-symmetric rectangle generator.  Keep
        // the generated ring pinned to the recovered loop order (including
        // the one-cell top-left closure emitted by the original loops) so a future
        // cleanup cannot silently replace the PE's probe sequence.
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.squareRingOffsets(
                footprintSide: 2,
                radius: 1
            ),
            [
                GridPoint(x: 0, y: -1), GridPoint(x: 1, y: -1),
                GridPoint(x: 2, y: -1), GridPoint(x: 2, y: 0), GridPoint(x: 2, y: 1),
                GridPoint(x: 2, y: 2), GridPoint(x: 1, y: 2), GridPoint(x: 0, y: 2),
                GridPoint(x: -1, y: 2), GridPoint(x: -1, y: 1), GridPoint(x: -1, y: 0),
                GridPoint(x: -1, y: -1)
            ]
        )
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.squareRingOffsets(
                footprintSide: 2,
                radius: 2
            ),
            [
                GridPoint(x: 0, y: -2), GridPoint(x: 1, y: -2), GridPoint(x: 2, y: -2),
                GridPoint(x: 3, y: -2), GridPoint(x: 3, y: -1), GridPoint(x: 3, y: 0),
                GridPoint(x: 3, y: 1), GridPoint(x: 3, y: 2),
                GridPoint(x: 3, y: 3), GridPoint(x: 2, y: 3), GridPoint(x: 1, y: 3),
                GridPoint(x: 0, y: 3), GridPoint(x: -1, y: 3),
                GridPoint(x: -2, y: 3), GridPoint(x: -2, y: 2), GridPoint(x: -2, y: 1),
                GridPoint(x: -2, y: 0), GridPoint(x: -2, y: -1),
                GridPoint(x: -2, y: -2), GridPoint(x: -1, y: -2)
            ]
        )

        XCTAssertNil(
            OriginalAppealPropagationCatalog.squareRingOffsets(
                footprintSide: 7,
                radius: 1
            )
        )
        XCTAssertNil(
            OriginalAppealPropagationCatalog.squareRingOffsets(
                footprintSide: 2,
                radius: 11
            )
        )
    }

    func testRecoveredAppealPropagationValueScheduleAndZeroCrossing() {
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.propagatedValue(
                initialValue: 20,
                stepDistance: 2,
                stepSize: -7,
                radius: 1
            ),
            20
        )
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.propagatedValue(
                initialValue: 20,
                stepDistance: 2,
                stepSize: -7,
                radius: 3
            ),
            13
        )
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.propagatedValue(
                initialValue: 3,
                stepDistance: 1,
                stepSize: -7,
                radius: 2
            ),
            0
        )
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.propagatedValue(
                initialValue: -3,
                stepDistance: 1,
                stepSize: 7,
                radius: 2
            ),
            0
        )
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.propagatedValue(
                initialValue: 150,
                stepDistance: 1,
                stepSize: 0,
                radius: 1
            ),
            100
        )
        XCTAssertNil(
            OriginalAppealPropagationCatalog.propagatedValue(
                initialValue: 0,
                stepDistance: 1,
                stepSize: 1,
                radius: 1
            )
        )
    }

    func testOriginalAppealPopulationAccumulatorMatchesStrictBandsAndFixedPointRounding() {
        XCTAssertEqual(OriginalAppealPopulationAccumulator.defaultAppealScale, 9)

        let lower = OriginalAppealPopulationAccumulator.contribution(
            appealValue: 10,
            modelColumn0: 0,
            appealScale: 2,
            residentCount: 10,
            modelColumn18: 1,
            hasSelectorNineBlessing: false
        )
        XCTAssertEqual(lower?.appealScore, 20)
        XCTAssertEqual(lower?.rawFixedPoint, 2_000)
        XCTAssertEqual(lower?.roundedPopulationUnits, 0)

        let middle = OriginalAppealPopulationAccumulator.contribution(
            appealValue: 31,
            modelColumn0: 0,
            appealScale: 2,
            residentCount: 100,
            modelColumn18: 1,
            hasSelectorNineBlessing: true
        )
        // Delta 31 takes the strict (30, 41) branch: (2*10+15)*2 + 20.
        XCTAssertEqual(middle?.appealScore, 90)
        XCTAssertEqual(middle?.rawFixedPoint, 90_000)
        XCTAssertEqual(middle?.roundedPopulationUnits, 9)

        let upperBoundary = OriginalAppealPopulationAccumulator.contribution(
            appealValue: 51,
            modelColumn0: 0,
            appealScale: 2,
            residentCount: 1,
            modelColumn18: 1,
            hasSelectorNineBlessing: false
        )
        // Delta 51 is in the unsquared upper branch (2*10+25).
        XCTAssertEqual(upperBoundary?.appealScore, 45)
        XCTAssertEqual(upperBoundary?.rawFixedPoint, 450)
        XCTAssertEqual(upperBoundary?.roundedPopulationUnits, 0)

        let negative = OriginalAppealPopulationAccumulator.contribution(
            appealValue: -100,
            modelColumn0: 0,
            appealScale: 2,
            residentCount: 10,
            modelColumn18: 1,
            hasSelectorNineBlessing: false
        )
        XCTAssertEqual(negative?.appealScore, 20)
        XCTAssertEqual(negative?.rawFixedPoint, 2_000)
        XCTAssertEqual(negative?.roundedPopulationUnits, 0)
    }

    func testOriginalHouseAppealPopulationClassUsesSignedElevenBoundary() {
        XCTAssertFalse(
            OriginalHouseAppealPopulationClass.isUpperClass(houseField14: 10)
        )
        XCTAssertTrue(
            OriginalHouseAppealPopulationClass.isUpperClass(houseField14: 11)
        )
        XCTAssertFalse(
            OriginalHouseAppealPopulationClass.isUpperClass(houseField14: -1)
        )
    }

    func testOriginalAppealTaxLedgerPreservesBucketScaleAndMonthMultiplier() {
        let firstMonth = OriginalAppealTaxLedger.project(
            lowerWeightedUnits: 100,
            upperWeightedUnits: 50,
            lowerTaxDelta: 7,
            upperTaxDelta: -2,
            appealScale: 9,
            monthIndex: 0
        )
        XCTAssertEqual(firstMonth?.lowerScaledUnits, 9)
        XCTAssertEqual(firstMonth?.upperScaledUnits, 4)
        XCTAssertEqual(firstMonth?.appealTaxDelta, 5)
        XCTAssertEqual(firstMonth?.displayBase, 18)

        let laterMonth = OriginalAppealTaxLedger.project(
            lowerWeightedUnits: 100,
            upperWeightedUnits: 50,
            lowerTaxDelta: 0,
            upperTaxDelta: 0,
            appealScale: 9,
            monthIndex: 2
        )
        XCTAssertEqual(laterMonth?.displayBase, 143)
    }

    func testOriginalAppealTaxLedgerRejectsCheckedArithmeticOverflow() {
        let overflowed = OriginalAppealTaxLedger.project(
            lowerWeightedUnits: Int.max,
            upperWeightedUnits: 0,
            lowerTaxDelta: 0,
            upperTaxDelta: 0,
            appealScale: 2,
            monthIndex: 0
        )
        XCTAssertNil(overflowed)

        let deltaOverflow = OriginalAppealTaxLedger.project(
            lowerWeightedUnits: 0,
            upperWeightedUnits: 0,
            lowerTaxDelta: Int.max,
            upperTaxDelta: 1,
            appealScale: 9,
            monthIndex: 0
        )
        XCTAssertNil(deltaOverflow)
    }

    func testOriginalAppealTaxDeltaRoundsBothFixedPointEndpoints() throws {
        let projection = try XCTUnwrap(
            OriginalAppealTaxLedger.projectTaxDelta(
                previousFixedPoint: 9_999,
                incrementFixedPoint: 2
            )
        )
        // The source rounds each endpoint independently: 9,999 -> 1 and
        // 10,001 -> 1, so this crossing does not create a delta unit.
        XCTAssertEqual(projection.previousRoundedUnits, 1)
        XCTAssertEqual(projection.updatedRoundedUnits, 1)
        XCTAssertEqual(projection.deltaUnits, 0)

        let negative = try XCTUnwrap(
            OriginalAppealTaxLedger.projectTaxDelta(
                previousFixedPoint: -10_001,
                incrementFixedPoint: 2
            )
        )
        // Swift integer division has the same truncation-toward-zero behavior
        // as the original signed x86 division in this expression.
        XCTAssertEqual(negative.previousRoundedUnits, 0)
        XCTAssertEqual(negative.updatedRoundedUnits, 0)
        XCTAssertEqual(negative.deltaUnits, 0)
    }

    func testOriginalAppealTaxReaderUsesSignedFixedPointRounding() {
        XCTAssertEqual(
            OriginalAppealTaxLedger.roundedFixedPointUnits(9_999),
            1
        )
        XCTAssertEqual(
            OriginalAppealTaxLedger.roundedFixedPointUnits(-10_001),
            0
        )
        XCTAssertNil(
            OriginalAppealTaxLedger.roundedFixedPointUnits(Int.max)
        )
    }

    func testOriginalAppealTaxDeltaRejectsFixedPointOverflow() {
        XCTAssertNil(
            OriginalAppealTaxLedger.projectTaxDelta(
                previousFixedPoint: Int.max,
                incrementFixedPoint: 1
            )
        )
    }

    func testRecoveredAppealObjectCopyUsesSignedMaximumAndPostCopyOffset() {
        let buffer: [Int8] = [
            -20, 4, -8,
            12, -3, 7,
            9, 18, 6,
        ]

        // `anchorLinearIndex` is the top-left cell and the 3x3 test stride
        // stands in for the executable's canonical 0xE4 stride.
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.copyObjectAppeal(
                appealBuffer: buffer,
                anchorLinearIndex: 0,
                footprintSide: 2,
                objectOffset60NonZero: false,
                mapStride: 3
            ),
            12
        )
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.copyObjectAppeal(
                appealBuffer: buffer,
                anchorLinearIndex: 0,
                footprintSide: 2,
                objectOffset60NonZero: true,
                mapStride: 3
            ),
            22
        )
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.copyObjectAppeal(
                appealBuffer: [-100, -90, -110],
                anchorLinearIndex: 0,
                footprintSide: 1,
                objectOffset60NonZero: false,
                mapStride: 3
            ),
            -100
        )
    }

    func testRecoveredAppealObjectCopyRejectsInvalidFootprintOrAnchor() {
        let buffer: [Int8] = [0, 1, 2, 3]
        XCTAssertNil(
            OriginalAppealPropagationCatalog.copyObjectAppeal(
                appealBuffer: buffer,
                anchorLinearIndex: 0,
                footprintSide: 0,
                objectOffset60NonZero: false,
                mapStride: 2
            )
        )
        XCTAssertNil(
            OriginalAppealPropagationCatalog.copyObjectAppeal(
                appealBuffer: buffer,
                anchorLinearIndex: 3,
                footprintSide: 2,
                objectOffset60NonZero: false,
                mapStride: 2
            )
        )
        XCTAssertNil(
            OriginalAppealPropagationCatalog.copyObjectAppeal(
                appealBuffer: buffer,
                anchorLinearIndex: -1,
                footprintSide: 1,
                objectOffset60NonZero: false,
                mapStride: 2
            )
        )
    }

    func testRecoveredAppealObjectOffset60FlagScansOrderedPerimeterTerrain() {
        let stride = 8
        var terrain = [UInt32](repeating: 0, count: stride * stride)
        let origin = GridPoint(x: 3, y: 3)

        // A side-2 object scans the eight cells around its 2x2 footprint.
        // The interior origin is not part of the candidate row.
        terrain[origin.y * stride + origin.x] = 0x04
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.objectOffset60Flag(
                terrainFlags: terrain,
                origin: origin,
                footprintSide: 2,
                mapStride: stride
            ),
            false
        )

        terrain[(origin.y - 1) * stride + origin.x] = 0x04
        XCTAssertEqual(
            OriginalAppealPropagationCatalog.objectOffset60Flag(
                terrainFlags: terrain,
                origin: origin,
                footprintSide: 2,
                mapStride: stride
            ),
            true
        )
    }

    func testRecoveredAppealObjectOffset60FlagFailsClosedAtBackingEdge() {
        let stride = 8
        XCTAssertNil(
            OriginalAppealPropagationCatalog.objectOffset60Flag(
                terrainFlags: [UInt32](repeating: 0, count: stride * stride),
                origin: GridPoint(x: 0, y: 0),
                footprintSide: 2,
                mapStride: stride
            )
        )
        XCTAssertNil(
            OriginalAppealPropagationCatalog.objectOffset60Flag(
                terrainFlags: [UInt32](repeating: 0, count: 4),
                origin: GridPoint(x: 1, y: 1),
                footprintSide: 1,
                mapStride: stride
            )
        )
    }

    func testRecoveredNegativeAppealOccupancyArbitration() {
        let first = OriginalAppealPropagationCatalog.negativePropagationStep(
            occupied: true,
            sector: 2,
            radius: 3,
            ringCellCount: 12
        )
        XCTAssertFalse(first.shouldWrite)
        XCTAssertTrue(first.state.sectorActive[2])
        XCTAssertEqual(first.state.blockingRadius[2], 3)

        let later = OriginalAppealPropagationCatalog.negativePropagationStep(
            occupied: true,
            sector: 2,
            radius: 4,
            ringCellCount: 12,
            state: first.state
        )
        XCTAssertEqual(later.state, first.state)

        let nearer = OriginalAppealPropagationCatalog.negativePropagationStep(
            occupied: true,
            sector: 2,
            radius: 1,
            ringCellCount: 12,
            state: first.state
        )
        XCTAssertEqual(nearer.state.blockingRadius[2], 1)

        let openCell = OriginalAppealPropagationCatalog.negativePropagationStep(
            occupied: false,
            sector: 2,
            radius: 1,
            ringCellCount: 12,
            state: nearer.state
        )
        XCTAssertTrue(openCell.shouldWrite)

        var seededActive = Array(repeating: false, count: 16)
        seededActive[4] = true
        var seededRadius = Array(repeating: 0, count: 16)
        seededRadius[4] = 1
        let seeded = OriginalAppealPropagationCatalog.NegativePropagationState(
            sectorActive: seededActive,
            blockingRadius: seededRadius
        )
        let adjacent = OriginalAppealPropagationCatalog.negativePropagationStep(
            occupied: true,
            sector: 2,
            radius: 3,
            ringCellCount: 12,
            state: seeded
        )
        XCTAssertTrue(adjacent.state.sectorActive[3])
        XCTAssertEqual(adjacent.state.blockingRadius[3], 3)
        XCTAssertFalse(
            OriginalAppealPropagationCatalog.negativePropagationStep(
                occupied: true,
                sector: nil,
                radius: 1,
                ringCellCount: 12,
                state: adjacent.state
            ).shouldWrite
        )
        XCTAssertTrue(
            OriginalAppealPropagationCatalog.negativePropagationStep(
                occupied: false,
                sector: nil,
                radius: 1,
                ringCellCount: 12,
                state: adjacent.state
            ).shouldWrite
        )
    }

    func testRecoveredCoverageUsesWholeHouseFootprintAndSixteenSectorOcclusion() {
        let origin = GridPoint(x: 0, y: 0)
        let residentialWall = PlacedBuilding(
            category: .aesthetic,
            instanceID: 1,
            buildingID: 89,
            origin: GridPoint(x: 1, y: 0),
            orientation: .northSouth,
            footprint: BuildingFootprint(width: 1, height: 2),
            roadAccessPoint: origin
        )
        let ordinaryService = PlacedBuilding(
            category: .residentialService,
            instanceID: 2,
            buildingID: 125,
            origin: GridPoint(x: -1, y: 0),
            orientation: .northSouth,
            footprint: BuildingFootprint(width: 2, height: 2),
            roadAccessPoint: origin
        )
        XCTAssertEqual(
            OriginalResidentialServiceCoverage.blockerPoints(
                placements: [residentialWall, ordinaryService]
            ),
            Set(residentialWall.occupiedPoints)
        )

        let house = ResidentialUnit(
            id: 1,
            houseLevelID: 0,
            residents: 8,
            location: GridPoint(x: 2, y: 0)
        )
        XCTAssertEqual(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .tax,
            providerBuildingID: 125,
            houses: [house],
            blockerPoints: []
        ), [0])

        XCTAssertTrue(OriginalResidentialServiceCoverage.houseIndices(
            servicedFrom: origin,
            service: .tax,
            providerBuildingID: 125,
            houses: [house],
            blockerPoints: [GridPoint(x: 1, y: 0), GridPoint(x: 1, y: 1)]
        ).isEmpty)
    }

    func testRecoveredVisitFieldsAgeEveryEighthSchedulerSlice() {
        var state = DeterministicWalkerState()
        var houses: [ResidentialUnit] = []
        let roads = RoadNetwork(width: 1, height: 1, points: [])

        _ = state.advanceRecoveredOriginalSteps(
            352,
            houses: &houses,
            roadNetwork: roads,
            workerPercentByWalkerID: [:]
        )
        XCTAssertEqual(state.originalVisitDecayCounter, 7)

        _ = state.advanceRecoveredOriginalSteps(
            51,
            houses: &houses,
            roadNetwork: roads,
            workerPercentByWalkerID: [:]
        )
        XCTAssertEqual(state.originalVisitDecayCounter, 0)
    }

    func testRecoveredServiceSaveReplayPreservesSchedulerAndRoamerState() throws {
        let roadPoints = Set((0..<6).map { GridPoint(x: $0, y: 0) })
        let roads = RoadNetwork(width: 6, height: 1, points: roadPoints)
        var uninterrupted = DeterministicWalkerState()
        XCTAssertNotNil(uninterrupted.addWalker(
            figureID: 27,
            service: .tax,
            origin: GridPoint(x: 0, y: 0),
            maximumRoadSteps: 2,
            replaySeed: 0x5341_5645,
            roadNetwork: roads,
            startsDormant: false,
            providerBuildingID: 125
        ))
        var uninterruptedHouses = [ResidentialUnit(
            id: 1,
            houseLevelID: 0,
            residents: 8,
            location: GridPoint(x: 2, y: 0)
        )]
        _ = uninterrupted.advanceRecoveredOriginalSteps(
            117,
            houses: &uninterruptedHouses,
            roadNetwork: roads,
            workerPercentByWalkerID: [1: 100]
        )

        var restored = try JSONDecoder().decode(
            DeterministicWalkerState.self,
            from: JSONEncoder().encode(uninterrupted)
        )
        var restoredHouses = try JSONDecoder().decode(
            [ResidentialUnit].self,
            from: JSONEncoder().encode(uninterruptedHouses)
        )
        XCTAssertEqual(restored, uninterrupted)
        XCTAssertEqual(restoredHouses, uninterruptedHouses)

        let passability = [UInt16](repeating: 0x4, count: 6)
        let first = uninterrupted.advanceRecoveredOriginalSteps(
            150,
            houses: &uninterruptedHouses,
            roadNetwork: roads,
            workerPercentByWalkerID: [1: 100],
            primaryReturnPassability: passability
        )
        let second = restored.advanceRecoveredOriginalSteps(
            150,
            houses: &restoredHouses,
            roadNetwork: roads,
            workerPercentByWalkerID: [1: 100],
            primaryReturnPassability: passability
        )
        XCTAssertEqual(second, first)
        XCTAssertEqual(restored, uninterrupted)
        XCTAssertEqual(restoredHouses, uninterruptedHouses)
    }

    func testVacantEliteHousingCanEvolveBeforeItsFirstResidentsArrive() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var houses = [
            ResidentialUnit(
                id: 1,
                houseLevelID: 8,
                residents: 0,
                location: GridPoint(x: 2, y: 1),
                desirability: 100
            )
        ]
        XCTAssertEqual(original.buildings[houseLevelID: 8]?.populationCapacity, 0)

        let settlement = DeterministicHousingEvolution.settle(
            houses: &houses,
            models: original.buildings,
            difficulty: .normal
        )

        XCTAssertEqual(houses[0].houseLevelID, 9)
        XCTAssertEqual(settlement.changes.first?.direction, .evolved)
        XCTAssertEqual(settlement.changes.first?.displacedResidents, 0)
    }

    func testHousingDevolvesWhenPreviousLevelServiceIsLost() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 6,
            mapHeight: 5
        )
        _ = city.buildRoad((0...5).map { GridPoint(x: $0, y: 2) }, rules: rules)
        _ = city.addHouse(
            levelID: 2,
            residents: 14,
            location: GridPoint(x: 2, y: 1),
            models: original.buildings
        )
        // Fixture-only occupancy isolates the downgrade/displacement rule;
        // automatic migration waits for the original popularity producer.
        XCTAssertEqual(city.admitResidents(8, models: original.buildings), 8)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].houseLevelID, 1)
        XCTAssertEqual(city.lastHousingSettlement?.devolvedCount, 1)
        XCTAssertEqual(city.lastHousingSettlement?.changes.first?.direction, .devolved)
        // The full level-2 fixture exceeds level 1 capacity by eight residents.
        XCTAssertEqual(city.lastHousingSettlement?.changes.first?.displacedResidents, 8)
    }

    func testHousingEvolutionUsesOriginalFoodGoodsReligionAndDesirabilityFields() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var houses = [
            ResidentialUnit(
                id: 1,
                houseLevelID: 3,
                residents: 20,
                location: GridPoint(x: 2, y: 1),
                // The original gates evolution on the **target** level's
                // requirements: Spacious Dwelling (level 4) needs water,
                // herbalist, music, food 30 and hemp.
                serviceCoverage: [.water, .ancestor, .herbalist, .music],
                desirability: 20
            )
        ]
        houses[0].recordEvolutionSupplies(foodQuality: .plain, commodityIDs: [19])

        let settlement = DeterministicHousingEvolution.settle(
            houses: &houses,
            models: original.buildings,
            difficulty: .normal
        )

        XCTAssertEqual(houses[0].houseLevelID, 4)
        XCTAssertEqual(settlement.evolvedCount, 1)
        XCTAssertEqual(settlement.changes.first?.fromLevelID, 3)
        XCTAssertEqual(settlement.changes.first?.toLevelID, 4)
        XCTAssertTrue(settlement.evaluations.first?.missingEvolutionRequirements.isEmpty == true)
    }

    func testOriginalProductionCatalogAndWorkerScaledProcessing() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)

        XCTAssertEqual(OriginalProductionCatalog.recipes.count, 20)
        XCTAssertEqual(OriginalProductionCatalog.recipe(forBuildingID: 35)?.outputCommodityID, 18)
        XCTAssertEqual(OriginalProductionCatalog.recipe(forBuildingID: 43)?.outputCommodityID, 25)
        XCTAssertEqual(
            OriginalProductionCatalog.recipe(forBuildingID: 42)?.inputOptions.first,
            [ProductionInput(commodityID: 11, amount: 100), ProductionInput(commodityID: 18, amount: 100)]
        )
        XCTAssertTrue(OriginalProductionCatalog.recipes.allSatisfy { recipe in
            original.buildings[buildingID: recipe.buildingID] != nil &&
                original.trade[commodityID: recipe.outputCommodityID] != nil
        })

        var city = DeterministicCityState(year: 1600, treasury: 500)
        let clayPit = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: 14,
            rules: rules
        ))
        let kiln = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: 12,
            rules: rules
        ))
        XCTAssertEqual([clayPit, kiln], [1, 2])
        XCTAssertEqual(city.economy.treasury, 365)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.production[commodityID: 18], 100)
        XCTAssertEqual(city.production[commodityID: 25], 100)
        XCTAssertEqual(city.production.lastSettlement?.operations.map(\.buildingID), [35, 43])
        XCTAssertEqual(city.production.lastSettlement?.staffedWorkers, 26)
        XCTAssertEqual(city.production.lastSettlement?.requiredWorkers, 26)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.production[commodityID: 18], 200)
        XCTAssertEqual(city.production[commodityID: 25], 200)

        var understaffed = DeterministicProductionState()
        _ = understaffed.addBuilding(buildingID: 35, assignedWorkers: 7, models: original.buildings)
        XCTAssertTrue(understaffed.advanceMonth(models: original.buildings).operations.isEmpty)
        XCTAssertEqual(understaffed.advanceMonth(models: original.buildings).operations.count, 1)

        var weapons = DeterministicProductionState(inventoryByCommodityID: [15: 100])
        _ = weapons.addBuilding(buildingID: 226, assignedWorkers: 8, models: original.buildings)
        let weaponMonth = weapons.advanceMonth(models: original.buildings)
        XCTAssertEqual(weaponMonth.operations.first?.consumed, [ProductionInput(commodityID: 15, amount: 100)])
        XCTAssertEqual(weapons[commodityID: 15], 0)
        XCTAssertEqual(weapons[commodityID: 21], 100)
    }

    func testFebruaryToJanuaryProductionAccountingClosesExactlyOnce() {
        var accounting = DeterministicProductionAccounting()
        XCTAssertNil(accounting.recordMonth(
            year: 1600,
            month: 2,
            producedUnitsByCommodityID: [25: 100],
            lifetimeIncome: 40,
            lifetimeExpenses: 10
        ))
        // A duplicate UI/replay call is ignored rather than double-counted.
        XCTAssertNil(accounting.recordMonth(
            year: 1600,
            month: 2,
            producedUnitsByCommodityID: [25: 9_999],
            lifetimeIncome: 9_999,
            lifetimeExpenses: 10
        ))
        for month in 3...12 {
            XCTAssertNil(accounting.recordMonth(
                year: 1600,
                month: month,
                producedUnitsByCommodityID: [25: 100],
                lifetimeIncome: 40,
                lifetimeExpenses: 10
            ))
        }
        let completed = accounting.recordMonth(
            year: 1601,
            month: 1,
            producedUnitsByCommodityID: [25: 100],
            lifetimeIncome: 90,
            lifetimeExpenses: 25
        )

        XCTAssertEqual(completed?.startYear, 1600)
        XCTAssertEqual(completed?.endYear, 1601)
        XCTAssertEqual(completed?.productionUnitsByCommodityID[25], 1_200)
        XCTAssertEqual(completed?.income, 90)
        XCTAssertEqual(completed?.expenses, 25)
        XCTAssertEqual(completed?.profit, 65)
        XCTAssertEqual(accounting.bestYearlyProductionUnitsByCommodityID[25], 1_200)
        XCTAssertEqual(accounting.bestYearlyProfit, 65)
        XCTAssertEqual(accounting.completedCycleCount, 1)
        XCTAssertTrue(accounting.currentProductionUnitsByCommodityID.isEmpty)
    }

    func testCityProductionAccountingSatisfiesOriginalShangCeramicsGoal() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let original = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 1600, month: 2, treasury: 10_000)
        _ = city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: original.buildings[buildingID: 35]?.employees ?? 0,
            rules: rules
        )
        _ = city.addHouse(
            levelID: 4,
            residents: 12,
            models: original.buildings
        )
        _ = city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: original.buildings[buildingID: 43]?.employees ?? 0,
            rules: rules
        )

        for _ in 0..<12 { _ = city.advanceMonth(rules: rules) }

        XCTAssertEqual(city.calendar, SimulationCalendar(year: 1601, month: 2))
        XCTAssertEqual(city.productionAccounting.completedCycleCount, 1)
        XCTAssertEqual(city.productionAccounting.bestYearlyProductionUnitsByCommodityID[18], 2_400)
        XCTAssertEqual(city.productionAccounting.bestYearlyProductionUnitsByCommodityID[25], 1_200)
        XCTAssertEqual(city.productionAccounting.lastCompletedCycle?.expenses, city.economy.lifetimeExpenses)
        XCTAssertEqual(city.campaignGoalProgressSnapshot().housingPopulationByLevelCode[7], 12)

        let campaignURL = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: campaignURL)
        let goals = try CampaignGoalArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let ceramicsGoal = try XCTUnwrap(goals.missions[0].goals.first { $0.kind == .yearlyProduction })
        XCTAssertEqual(
            CampaignGoalEvaluator.evaluate(
                ceramicsGoal,
                against: city.campaignGoalProgressSnapshot()
            ),
            CampaignGoalProgress(currentValue: 1_200, requiredValue: 1_200, isSatisfied: true)
        )
    }

    func testLocalOriginalFarmConfigurationAndRegionalYield() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let agriculture = OriginalAgricultureRules(farm: original.farm)

        XCTAssertEqual(agriculture.minimumFertility, 10)
        XCTAssertEqual(agriculture.tendingRange(for: .field), 3)
        XCTAssertEqual(agriculture.tendingRange(for: .hemp), 3)
        XCTAssertEqual(agriculture.tendingRange(for: .orchard), 3)
        XCTAssertEqual(agriculture.maximumTendedFields(for: .field), 10)
        XCTAssertEqual(agriculture.maximumTendedFields(for: .hemp), 8)
        XCTAssertEqual(agriculture.maximumTendedFields(for: .orchard), 6)
        XCTAssertEqual(agriculture.harvesterCount(for: .field), 5)
        XCTAssertEqual(agriculture.harvesterCount(for: .hemp), 4)
        XCTAssertEqual(agriculture.harvesterCount(for: .orchard), 3)
        XCTAssertEqual(agriculture.harvestingFieldsPerHarvester(for: .field), 4)
        XCTAssertEqual(agriculture.harvestingFieldsPerHarvester(for: .hemp), 4)
        XCTAssertEqual(agriculture.harvestingFieldsPerHarvester(for: .orchard), 3)

        XCTAssertEqual(agriculture.regionalModifierPercent(crop: .wheat, climate: .arid), 70)
        XCTAssertEqual(agriculture.regionalModifierPercent(crop: .wheat, climate: .temperate), 80)
        XCTAssertEqual(agriculture.regionalModifierPercent(crop: .rice, climate: .humid), 100)
        XCTAssertEqual(agriculture.regionalModifierPercent(crop: .rice, climate: .arid), 45)
        XCTAssertEqual(agriculture.regionalModifierPercent(crop: .mulberry, climate: .temperate), 100)

        let wheat = agriculture.harvestAmount(
            configuration: AgriculturalConfiguration(
                crop: .wheat,
                fieldCount: 4,
                fertilityPercent: 100,
                climate: .temperate
            ),
            assignedWorkers: 12,
            requiredWorkers: 12
        )
        XCTAssertEqual(wheat.amount, 320)
        XCTAssertEqual(wheat.effectiveFields, 4)
        XCTAssertEqual(wheat.regionPercent, 80)
        XCTAssertEqual(wheat.workerPercent, 100)

        let barren = agriculture.harvestAmount(
            configuration: AgriculturalConfiguration(
                crop: .wheat,
                fieldCount: 4,
                fertilityPercent: 9,
                climate: .temperate
            ),
            assignedWorkers: 12,
            requiredWorkers: 12
        )
        XCTAssertEqual(barren.amount, 0)
    }

    func testSeasonalWheatHarvestTravelsFromFarmToMill() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            month: 6,
            treasury: 10_000,
            mapWidth: 7,
            mapHeight: 5
        )
        _ = city.buildRoad((0...6).map { GridPoint(x: $0, y: 2) }, rules: rules)
        let farmID = try XCTUnwrap(city.constructAgriculturalProducer(
            crop: .wheat,
            fieldCount: 4,
            fertilityPercent: 100,
            climate: .temperate,
            serviceRoadStart: GridPoint(x: 1, y: 2),
            rules: rules
        ))
        XCTAssertNotNil(city.constructMill(
            serviceRoadStart: GridPoint(x: 5, y: 2),
            rules: rules
        ))

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.calendar.month, 7)
        XCTAssertEqual(city.production.lastAgriculturalSettlement?.growingBuildingInstanceIDs, [farmID])
        XCTAssertTrue(city.production.lastAgriculturalSettlement?.harvests.isEmpty == true)
        XCTAssertEqual(city.logistics.mills[0].inventoryByCommodityID[7, default: 0], 0)

        _ = city.advanceMonth(rules: rules)
        let harvest = try XCTUnwrap(city.production.lastAgriculturalSettlement?.harvests.first)
        XCTAssertEqual(harvest.crop, .wheat)
        XCTAssertEqual(harvest.outputAmount, 320)
        XCTAssertEqual(harvest.effectiveFields, 4)
        XCTAssertEqual(city.production.localOutputAmount(
            buildingInstanceID: farmID,
            commodityID: AgriculturalCrop.wheat.outputCommodityID
        ), 220)
        XCTAssertEqual(city.logistics.mills[0].inventoryByCommodityID[7, default: 0], 0)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)

        for _ in 0..<8 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.logistics.mills[0].inventoryByCommodityID[7, default: 0], 100)
        XCTAssertEqual(city.production[commodityID: 7], 100)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
    }

    func testDeliveryCartUsesRecoveredTwentySubstepRouteCadence() {
        let points = (0..<4).map { GridPoint(x: $0, y: 0) }
        var walker = DeliveryWalker(
            id: 1,
            figureID: 22,
            source: .productionBuilding(1),
            destination: .mill(2),
            cargo: DeliveryCargo(commodityID: 4, amount: 100),
            outboundPath: points
        )

        for _ in 0..<19 {
            XCTAssertFalse(walker.advanceOriginalSimulationStep())
        }
        XCTAssertEqual(walker.currentPoint, points[0])
        XCTAssertFalse(walker.movedOnLastSimulationStep)

        XCTAssertTrue(walker.advanceOriginalSimulationStep())
        XCTAssertEqual(walker.currentPoint, points[1])
        XCTAssertTrue(walker.movedOnLastSimulationStep)

        walker.beginSimulationStep()
        XCTAssertFalse(walker.advanceOriginalSimulationStep())
        XCTAssertFalse(walker.movedOnLastSimulationStep)
    }

    func testCropSpecificAgriculturalPlotCreatesVisibleLinkedPlacement() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 10_000,
            mapWidth: 7,
            mapHeight: 5
        )
        _ = city.buildRoad((0...6).map { GridPoint(x: $0, y: 3) }, rules: rules)
        let plotPoint = GridPoint(x: 4, y: 1)

        XCTAssertFalse(city.canConstructAgriculturalPlot(crop: .rice, at: plotPoint))
        let producerID = try XCTUnwrap(city.constructAgriculturalProducer(
            crop: .rice,
            at: GridPoint(x: 1, y: 0),
            rules: rules
        ))
        XCTAssertTrue(city.canConstructAgriculturalPlot(
            crop: .rice,
            at: plotPoint,
            rules: rules
        ))
        XCTAssertEqual(producerID, city.constructAgriculturalPlot(
            crop: .rice,
            at: plotPoint,
            rules: rules
        ))
        let producerPlacement = try XCTUnwrap(city.placement(
            category: .production,
            instanceID: producerID
        ))
        XCTAssertEqual(producerPlacement.buildingID, AgriculturalCrop.rice.producerBuildingID)
        XCTAssertEqual(producerPlacement.origin, GridPoint(x: 1, y: 0))
        let plotPlacement = try XCTUnwrap(city.placedBuildings.first {
            $0.category == .agriculturalPlot && $0.origin == plotPoint
        })
        XCTAssertEqual(plotPlacement.instanceID, producerID)
        XCTAssertEqual(plotPlacement.buildingID, AgriculturalCrop.rice.plotBuildingID)
        XCTAssertEqual(
            city.production.buildings.first(where: { $0.id == producerID })?.agriculture?.crop,
            .rice
        )
        XCTAssertEqual(
            city.production.buildings.first(where: { $0.id == producerID })?
                .agriculture?.fieldCount,
            1
        )
        XCTAssertFalse(city.canConstructAgriculturalPlot(crop: .wheat, at: plotPoint))

        _ = city.demolish(at: plotPoint, rules: rules)
        XCTAssertFalse(city.placedBuildings.contains {
            $0.category == .agriculturalPlot && $0.origin == plotPoint
        })
        XCTAssertEqual(
            city.production.building(instanceID: producerID)?.agriculture?.fieldCount,
            0
        )

        XCTAssertEqual(producerID, city.constructAgriculturalPlot(
            crop: .rice,
            at: plotPoint,
            rules: rules
        ))
        _ = city.demolish(at: GridPoint(x: 1, y: 0), rules: rules)
        XCTAssertNil(city.production.building(instanceID: producerID))
        XCTAssertFalse(city.placedBuildings.contains {
            $0.category == .agriculturalPlot && $0.instanceID == producerID
        })
    }

    func testAgriculturalPlotWorkforceUsesProducerModelInsteadOfVisualFieldModel() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 10_000,
            mapWidth: 7,
            mapHeight: 5
        )
        city.workforceEnabled = true
        _ = city.buildRoad((0...6).map { GridPoint(x: $0, y: 3) }, rules: rules)
        for x in 0..<3 {
            XCTAssertNotNil(city.addHouse(
                levelID: 0,
                location: GridPoint(x: x, y: 4),
                models: original.buildings
            ))
        }
        let producerID = try XCTUnwrap(city.constructAgriculturalProducer(
            crop: .millet,
            at: GridPoint(x: 1, y: 0),
            rules: rules
        ))
        XCTAssertNotNil(city.constructAgriculturalPlot(
            crop: .millet,
            at: GridPoint(x: 4, y: 1),
            rules: rules
        ))

        let placement = try XCTUnwrap(city.placement(
            category: .production,
            instanceID: producerID
        ))
        XCTAssertEqual(placement.buildingID, AgriculturalCrop.millet.producerBuildingID)
        let assignment = try XCTUnwrap(city.workforceAssignment(
            for: placement,
            models: original.buildings
        ))
        XCTAssertEqual(
            assignment.requiredWorkers,
            original.buildings[buildingID: AgriculturalCrop.millet.producerBuildingID]?.employees
        )
        XCTAssertGreaterThan(assignment.requiredWorkers, 0)
    }

    func testEquidistantAgriculturalPlotPrefersTheMostRecentlyPlacedFarm() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let rules = EconomyRulesEngine(models: try OriginalEconomyModels(source: .openDefault()))
        var city = DeterministicCityState(
            year: 1600,
            treasury: 10_000,
            mapWidth: 10,
            mapHeight: 6
        )
        _ = city.buildRoad((0..<10).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let olderFarmID = try XCTUnwrap(city.constructAgriculturalProducer(
            crop: .rice,
            at: GridPoint(x: 1, y: 2),
            rules: rules
        ))
        let newerFarmID = try XCTUnwrap(city.constructAgriculturalProducer(
            crop: .rice,
            at: GridPoint(x: 5, y: 2),
            rules: rules
        ))

        XCTAssertEqual(newerFarmID, city.constructAgriculturalPlot(
            crop: .rice,
            at: GridPoint(x: 4, y: 2),
            rules: rules
        ))
        XCTAssertEqual(city.production.building(instanceID: olderFarmID)?.agriculture?.fieldCount, 0)
        XCTAssertEqual(city.production.building(instanceID: newerFarmID)?.agriculture?.fieldCount, 1)
    }

    func testLandTradeUsesOriginalQuotaCapacityPricesAndPhysicalRoadDelivery() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            month: 2,
            treasury: 10_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = city.buildRoad((0...7).map { GridPoint(x: $0, y: 2) }, rules: rules)
        _ = city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: original.buildings[buildingID: 35]?.employees ?? 0,
            serviceRoadStart: GridPoint(x: 0, y: 2),
            rules: rules
        )
        _ = city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: original.buildings[buildingID: 43]?.employees ?? 0,
            serviceRoadStart: GridPoint(x: 1, y: 2),
            rules: rules
        )
        _ = city.constructWarehouse(serviceRoadStart: GridPoint(x: 3, y: 2), rules: rules)
        _ = city.constructMill(serviceRoadStart: GridPoint(x: 4, y: 2), rules: rules)

        XCTAssertTrue(city.addTradePartner(
            TradePartner(
                id: 7,
                name: "Banpo",
                routeKind: .land,
                demandByCommodityID: [25: .high],
                supplyByCommodityID: [5: .low]
            ),
            rules: rules
        ))
        let stationID = try XCTUnwrap(city.constructTradingBuilding(
            partnerID: 7,
            serviceRoadStart: GridPoint(x: 6, y: 2),
            rules: rules
        ))
        city.setTradeImporting(true, commodityID: 5, tradingBuildingID: stationID)
        city.setTradeExporting(true, commodityID: 25, tradingBuildingID: stationID)

        let treasuryBeforeTrading = city.economy.treasury
        var allTransactions: [TradeTransaction] = []
        var exportedSettlementMonth: Int?
        for _ in 0..<4 {
            let settlement = city.advanceMonth(rules: rules)
            let transactions = city.trade.lastSettlement?.transactions ?? []
            allTransactions.append(contentsOf: transactions)
            if transactions.contains(where: { $0.direction == .exported }) {
                exportedSettlementMonth = settlement.month
            }
        }

        XCTAssertEqual(city.trade.building(id: stationID)?.capacity, 6_000)
        XCTAssertGreaterThanOrEqual(city.logistics.mills[0].inventoryByCommodityID[5, default: 0], 100)
        XCTAssertEqual(exportedSettlementMonth, 5)
        XCTAssertTrue(allTransactions.contains(TradeTransaction(
            partnerID: 7,
            tradingBuildingID: stationID,
            routeKind: .land,
            direction: .exported,
            commodityID: 25,
            amount: 100,
            loadPrice: 75,
            cashAmount: 75
        )))
        XCTAssertTrue(allTransactions.contains(TradeTransaction(
            partnerID: 7,
            tradingBuildingID: stationID,
            routeKind: .land,
            direction: .imported,
            commodityID: 5,
            amount: 100,
            loadPrice: 27,
            cashAmount: 27
        )))
        let exportIncome = allTransactions
            .filter { $0.direction == .exported }
            .reduce(0) { $0 + $1.cashAmount }
        let importSpending = allTransactions
            .filter { $0.direction == .imported }
            .reduce(0) { $0 + $1.cashAmount }
        XCTAssertEqual(city.economy.treasury, treasuryBeforeTrading + exportIncome - importSpending)
        XCTAssertEqual(city.campaignGoalProgressSnapshot().tradingPartnerCount, 1)
    }

    func testOriginalTradePartnerConstraintsAndVisitCapacity() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var trade = DeterministicTradeState()
        XCTAssertFalse(trade.addPartner(
            TradePartner(
                id: 1,
                name: "Invalid",
                routeKind: .land,
                demandByCommodityID: [1: .low, 2: .low, 3: .low, 4: .low, 5: .low]
            ),
            tradeRules: original.trade
        ))
        XCTAssertTrue(trade.addPartner(
            TradePartner(
                id: 2,
                name: "Land Partner",
                routeKind: .land,
                supplyByCommodityID: [5: .high]
            ),
            tradeRules: original.trade
        ))
        var road = RoadNetwork(width: 4, height: 3)
        _ = road.insert([GridPoint(x: 1, y: 1)])
        let buildingID = try XCTUnwrap(trade.addTradingBuilding(
            partnerID: 2,
            roadAccessPoint: GridPoint(x: 1, y: 1),
            assignedWorkers: original.buildings[buildingID: 58]?.employees ?? 0,
            models: original.buildings,
            roadNetwork: road
        ))
        trade.setImporting(true, commodityID: 5, tradingBuildingID: buildingID)
        var economy = DeterministicEconomyState(treasury: 10_000)
        let blocked = trade.advanceMonth(
            calendar: SimulationCalendar(year: 1600, month: 12),
            economy: &economy,
            models: original,
            visitorRoutesByBuildingID: [:]
        )
        XCTAssertTrue(blocked.transactions.isEmpty)
        XCTAssertEqual(blocked.inactiveTradingBuildingIDs, [buildingID])
        XCTAssertTrue(trade.visitors.isEmpty)
        let january = trade.advanceMonth(
            calendar: SimulationCalendar(year: 1601, month: 1),
            economy: &economy,
            models: original
        )
        // A high annual quota has 36 loads available by January, but one land
        // caravan is capped at the original eight loads / 800 internal units.
        XCTAssertEqual(january.transactions.first?.amount, original.trade.landCapacity)
        XCTAssertEqual(january.transactions.first?.amount, 800)
        XCTAssertEqual(trade.building(id: buildingID)?.storedAmount, 800)
    }

    func testTradeConstructionSelectorsFilterRouteOpenStateAndExistingBuilding() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var trade = DeterministicTradeState()
        for partner in [
            TradePartner(id: 9, name: "Sea", routeKind: .sea),
            TradePartner(id: 7, name: "Land B", routeKind: .land),
            TradePartner(id: 3, name: "Land A", routeKind: .land),
            TradePartner(id: 8, name: "Closed", routeKind: .land, isOpen: false),
        ] {
            XCTAssertTrue(trade.addPartner(partner, tradeRules: original.trade))
        }

        XCTAssertEqual(
            trade.availableConstructionPartners(for: .land).map(\.id),
            [3, 7]
        )
        XCTAssertEqual(
            trade.availableConstructionPartners(for: .sea).map(\.id),
            [9]
        )

        var road = RoadNetwork(width: 4, height: 3)
        _ = road.insert([GridPoint(x: 1, y: 1)])
        XCTAssertNotNil(trade.addTradingBuilding(
            partnerID: 7,
            roadAccessPoint: GridPoint(x: 1, y: 1),
            assignedWorkers: 0,
            models: original.buildings,
            roadNetwork: road
        ))
        XCTAssertEqual(
            trade.availableConstructionPartners(for: .land).map(\.id),
            [3]
        )
    }

    func testNativeSaveGameRoundTripsDeterministicCityState() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            month: 8,
            treasury: 20_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = city.addHouse(
            levelID: 3,
            residents: 17,
            hasTaxCoverage: true,
            location: GridPoint(x: 5, y: 0),
            models: original.buildings
        )
        _ = city.buildRoad((0...4).map { GridPoint(x: $0, y: 2) }, rules: rules)
        _ = city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: 14,
            serviceRoadStart: GridPoint(x: 1, y: 2),
            rules: rules
        )
        _ = city.constructAgriculturalProducer(
            crop: .hemp,
            fieldCount: 4,
            fertilityPercent: 80,
            climate: .temperate,
            serviceRoadStart: GridPoint(x: 2, y: 2),
            rules: rules
        )
        _ = city.constructWarehouse(serviceRoadStart: GridPoint(x: 4, y: 2), rules: rules)
        _ = city.constructMill(serviceRoadStart: GridPoint(x: 3, y: 2), rules: rules)
        _ = city.constructTaxOffice(
            serviceRoadStart: GridPoint(x: 0, y: 2),
            replaySeed: 0x454D_5045_524F_52,
            rules: rules
        )
        XCTAssertTrue(city.addTradePartner(
            TradePartner(
                id: 9,
                name: "Save Partner",
                routeKind: .land,
                demandByCommodityID: [25: .medium],
                supplyByCommodityID: [5: .low]
            ),
            rules: rules
        ))
        let savedTradeBuildingID = try XCTUnwrap(city.constructTradingBuilding(
            partnerID: 9,
            serviceRoadStart: GridPoint(x: 2, y: 2),
            rules: rules
        ))
        city.setTradeImporting(true, commodityID: 5, tradingBuildingID: savedTradeBuildingID)
        city.setTradeExporting(true, commodityID: 25, tradingBuildingID: savedTradeBuildingID)
        _ = city.advanceMonth(rules: rules)

        let save = NativeSaveGame(
            campaignFileName: "2 Shang Dynasty.pak",
            missionIndex: 0,
            replaySeed: 0x454D_5045_524F_52,
            city: city
        )
        let data = try NativeSaveGameStore.encoded(save)
        XCTAssertEqual(try NativeSaveGameStore.decoded(data), save)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"formatVersion\" : 1"))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmperorNativeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("city.emperor-save.json")
        try NativeSaveGameStore.save(save, to: url)
        XCTAssertEqual(try NativeSaveGameStore.load(from: url), save)

        var legacyRoot = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var legacyCity = try XCTUnwrap(legacyRoot["city"] as? [String: Any])
        legacyCity.removeValue(forKey: "walkerState")
        legacyCity.removeValue(forKey: "logisticsState")
        legacyCity.removeValue(forKey: "marketState")
        legacyCity.removeValue(forKey: "productionAccountingState")
        legacyCity.removeValue(forKey: "tradeState")
        var legacyEconomy = try XCTUnwrap(legacyCity["economy"] as? [String: Any])
        legacyEconomy.removeValue(forKey: "lifetimeIncomeStorage")
        legacyEconomy.removeValue(forKey: "lifetimeExpensesStorage")
        legacyCity["economy"] = legacyEconomy
        var legacyHouses = try XCTUnwrap(legacyCity["houses"] as? [[String: Any]])
        for index in legacyHouses.indices {
            legacyHouses[index].removeValue(forKey: "suppliesByCommodityID")
            legacyHouses[index].removeValue(forKey: "commodityShortageMonths")
            legacyHouses[index].removeValue(forKey: "foodSupplyAmount")
            legacyHouses[index].removeValue(forKey: "foodQualityRawValue")
        }
        legacyCity["houses"] = legacyHouses
        var legacyProduction = try XCTUnwrap(legacyCity["production"] as? [String: Any])
        var legacyBuildings = try XCTUnwrap(legacyProduction["buildings"] as? [[String: Any]])
        for index in legacyBuildings.indices {
            legacyBuildings[index].removeValue(forKey: "roadAccessPoint")
            legacyBuildings[index].removeValue(forKey: "inputInventoryByCommodityID")
            legacyBuildings[index].removeValue(forKey: "outputInventoryByCommodityID")
            legacyBuildings[index].removeValue(forKey: "activeDeliveryWalkerID")
            legacyBuildings[index].removeValue(forKey: "agriculture")
        }
        legacyProduction["buildings"] = legacyBuildings
        legacyCity["production"] = legacyProduction
        legacyRoot["city"] = legacyCity
        let legacyData = try JSONSerialization.data(withJSONObject: legacyRoot)
        let migrated = try NativeSaveGameStore.decoded(legacyData)
        XCTAssertTrue(migrated.city.walkers.walkers.isEmpty)
        XCTAssertTrue(migrated.city.logistics.warehouses.isEmpty)
        XCTAssertTrue(migrated.city.markets.markets.isEmpty)
        XCTAssertEqual(migrated.city.productionAccounting.completedCycleCount, 0)
        XCTAssertTrue(migrated.city.trade.partners.isEmpty)
        XCTAssertEqual(migrated.city.economy.lifetimeIncome, 0)
        XCTAssertEqual(migrated.city.economy.lifetimeExpenses, 0)
        XCTAssertTrue(migrated.city.houses[0].suppliesByCommodityID.isEmpty)
        XCTAssertNil(migrated.city.production.buildings.first?.roadAccessPoint)
    }

    func testMarketBuyerAndPeddlerDeliverWarehouseGoodsToHousing() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 2_000,
            mapWidth: 9,
            mapHeight: 5
        )
        city.housingEvolutionEnabled = false
        let road = (0...8).map { GridPoint(x: $0, y: 3) }
        _ = city.buildRoad(road, rules: rules)
        _ = city.addHouse(
            levelID: 5,
            residents: 10,
            location: GridPoint(x: 5, y: 2),
            models: original.buildings
        )
        _ = city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: 14,
            serviceRoadStart: GridPoint(x: 1, y: 3),
            rules: rules
        )
        _ = city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: 12,
            serviceRoadStart: GridPoint(x: 4, y: 3),
            rules: rules
        )
        _ = city.constructProductionBuilding(
            buildingID: 192,
            assignedWorkers: 18,
            serviceRoadStart: GridPoint(x: 2, y: 3),
            rules: rules
        )
        _ = city.constructWarehouse(
            serviceRoadStart: GridPoint(x: 7, y: 3),
            rules: rules
        )
        XCTAssertNotNil(city.constructMarket(
            serviceRoadStart: GridPoint(x: 0, y: 3),
            shopBuildingIDs: [65, 67],
            rules: rules
        ))

        var purchasedCommodityIDs: Set<Int> = []
        var deliveredCommodityIDs: Set<Int> = []
        var completionTick: UInt64?
        for _ in 0..<120 where completionTick == nil {
            let tick = city.advanceTick(rules: rules)
            purchasedCommodityIDs.formUnion(tick.movement.market.purchasedLoads.map(\.commodityID))
            deliveredCommodityIDs.formUnion(tick.movement.market.householdDeliveries.map(\.commodityID))
            if deliveredCommodityIDs.isSuperset(of: [19, 25]) {
                completionTick = tick.tickSequence
            }
        }

        XCTAssertEqual(purchasedCommodityIDs, [19, 25])
        XCTAssertEqual(deliveredCommodityIDs, [19, 25])
        // The 2x2 dwelling accepts delivery from every edge of its authored
        // footprint, not just the top-left anchor tile.
        // Buyer movement now uses the recovered selector-8 cadence; the
        // remaining peddler route is intentionally not an original-timing
        // contract, so assert bounded completion rather than the former
        // fixed-road-step tick.
        XCTAssertLessThanOrEqual(try XCTUnwrap(completionTick), 120)
        XCTAssertGreaterThan(city.houses[0][commodityID: 19], 0)
        XCTAssertGreaterThan(city.houses[0][commodityID: 25], 0)

        _ = city.advanceMonth(rules: rules)
        // Goods are physically present, but this Elegant Dwelling still lacks
        // Appetizing food, so the unified shortage streak remains active.
        XCTAssertGreaterThan(city.houses[0].commodityShortageMonths, 0)
        XCTAssertEqual(city.markets.lastSettlement?.underSuppliedHouseIDs, [1])
        XCTAssertTrue(city.markets.lastSettlement?.householdConsumption.contains {
            $0.commodityID == 19 && $0.consumedAmount > 0
        } == true)
        XCTAssertTrue(city.markets.lastSettlement?.householdConsumption.contains {
            $0.commodityID == 25 && $0.consumedAmount > 0
        } == true)
    }

    func testMillFoodBuyerAndPeddlerPreservePlainFoodQuality() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 2_000,
            mapWidth: 9,
            mapHeight: 5
        )
        city.housingEvolutionEnabled = false
        let road = (0...8).map { GridPoint(x: $0, y: 3) }
        _ = city.buildRoad(road, rules: rules)
        _ = city.addHouse(
            levelID: 2,
            residents: 10,
            location: GridPoint(x: 5, y: 2),
            models: original.buildings
        )
        // Fixture-only occupancy keeps this test about mill/market food
        // quantities, not the unsupported automatic migration producer.
        XCTAssertEqual(city.admitResidents(12, models: original.buildings), 12)
        _ = city.constructProductionBuilding(
            buildingID: 31,
            assignedWorkers: original.buildings[buildingID: 31]?.employees ?? 0,
            serviceRoadStart: GridPoint(x: 1, y: 3),
            rules: rules
        )
        _ = city.constructProductionBuilding(
            buildingID: 33,
            assignedWorkers: original.buildings[buildingID: 33]?.employees ?? 0,
            serviceRoadStart: GridPoint(x: 2, y: 3),
            rules: rules
        )
        XCTAssertNotNil(city.constructMill(
            serviceRoadStart: GridPoint(x: 7, y: 3),
            rules: rules
        ))
        XCTAssertNotNil(city.constructMarket(
            serviceRoadStart: GridPoint(x: 0, y: 3),
            shopBuildingIDs: [66],
            rules: rules
        ))

        var purchasedCommodityIDs: Set<Int> = []
        var foodDeliveries: [HouseholdCommodityDelivery] = []
        var completionTick: UInt64?
        var sawMeatDeliveryWalker = false
        for _ in 0..<90 where completionTick == nil {
            let tick = city.advanceTick(rules: rules)
            purchasedCommodityIDs.formUnion(tick.movement.market.purchasedLoads.map(\.commodityID))
            foodDeliveries.append(contentsOf: tick.movement.market.householdDeliveries)
            sawMeatDeliveryWalker = sawMeatDeliveryWalker
                || city.logistics.deliveryWalkers.contains { $0.cargo.commodityID == 4 }
            if city.houses[0].foodSupplyAmount >= 44 {
                completionTick = tick.tickSequence
            }
        }

        XCTAssertEqual(city.logistics.mills.count, 1)
        // The buyer may have withdrawn the mill's final stocked bundle by the
        // time the peddler delivers it; quality is therefore asserted at the
        // household/peddler boundary below, not from the inventory-derived
        // live mill quality after withdrawal.
        XCTAssertEqual(purchasedCommodityIDs, [2, 4])
        XCTAssertTrue(sawMeatDeliveryWalker)
        XCTAssertLessThanOrEqual(try XCTUnwrap(completionTick), 53)
        XCTAssertEqual(foodDeliveries, [
            HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11),
            HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11),
            HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11),
            HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11)
        ])
        XCTAssertEqual(city.houses[0].foodSupplyAmount, 44)
        XCTAssertEqual(city.houses[0].foodQuality, .plain)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].commodityShortageMonths, 0)
        XCTAssertEqual(
            Set(city.markets.lastSettlement?.purchasedLoads.map(\.commodityID) ?? []),
            [2, 4]
        )
        XCTAssertEqual(
            city.markets.lastSettlement?.householdDeliveries,
            [
                HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11),
                HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11),
                HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11),
                HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 11)
            ]
        )
        XCTAssertEqual(
            city.markets.lastSettlement?.householdConsumption,
            [HouseholdCommodityConsumption(
                houseID: 1,
                commodityID: -1,
                requestedAmount: 5,
                consumedAmount: 5
            )]
        )
    }

    func testMonthlyHouseholdConsumptionPreservesPersistedHouseVectorOrder() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        // The source monthly depletion walk (`FUN_00518690`) advances the
        // house vector directly. Reversing IDs makes an ID sort observable.
        var houses = [
            ResidentialUnit(
                id: 20,
                houseLevelID: 2,
                residents: 10,
                foodSupplyAmount: 5,
                foodQualityRawValue: FoodQuality.plain.rawValue
            ),
            ResidentialUnit(
                id: 3,
                houseLevelID: 2,
                residents: 10,
                foodSupplyAmount: 5,
                foodQualityRawValue: FoodQuality.plain.rawValue
            )
        ]
        var market = DeterministicMarketState()

        _ = market.settleMonth(houses: &houses, models: original.buildings)

        XCTAssertEqual(
            market.lastSettlement?.householdConsumption.map(\.houseID),
            [20, 3]
        )
    }

    func testCampaignMonthLeavesUnrecoveredMarketSettlementFailClosed() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let settings = CampaignMissionStartSettings(
            id: 3,
            startYear: 1600,
            startMonth: 1,
            initialFunds: 2_000,
            allowedBuildingMenuIDs: Array(0..<CampaignMissionSettingsArchive.allowedBuildingMenuCount),
            allowedResourceCommodityIDs: Array(0..<CampaignMissionSettingsArchive.allowedResourceCommodityCount)
        )
        var city = DeterministicCityState(
            missionSettings: settings,
            mapWidth: 9,
            mapHeight: 5
        )
        city.housingEvolutionEnabled = false
        let road = (0...8).map { GridPoint(x: $0, y: 3) }
        _ = city.buildRoad(road, rules: rules)
        _ = city.addHouse(
            levelID: 2,
            residents: 10,
            location: GridPoint(x: 5, y: 2),
            models: original.buildings
        )
        XCTAssertNotNil(city.constructMarket(
            serviceRoadStart: GridPoint(x: 0, y: 3),
            shopBuildingIDs: [65],
            rules: rules
        ))
        let before = city.houses[0]

        _ = city.advanceMonth(rules: rules)

        // Provider-record → cHouseInfo/Native inventory and quality mapping
        // is not recovered. Campaign month-end must not run the old Native
        // household-consumption approximation or publish a settlement record.
        XCTAssertEqual(city.houses[0].foodSupplyAmount, before.foodSupplyAmount)
        XCTAssertEqual(city.houses[0].foodQualityRawValue, before.foodQualityRawValue)
        XCTAssertEqual(city.houses[0].commodityShortageMonths, before.commodityShortageMonths)
        XCTAssertNil(city.markets.lastSettlement)
        // The recovered model-24 seam does not authorize Native warehouse-
        // targeted buyers in a campaign-backed Qin city.  Keep the campaign
        // market bridge fail-closed alongside the month-end settlement guard.
        XCTAssertTrue(city.markets.buyers.isEmpty)
        XCTAssertTrue(city.markets.peddlers.isEmpty)
    }

    func testHouseFoodDeliveryPreservesRecoveredRawQualityBytes() {
        var house = ResidentialUnit(
            id: 1,
            houseLevelID: 0,
            residents: 10,
            foodSupplyAmount: 100,
            foodQualityRawValue: 70
        )

        // The recovered market writer can blend an intermediate byte that is
        // not one of the five authored display bands.
        house.addFoodSupply(amount: 20, qualityRawValue: 45)
        XCTAssertEqual(house.foodSupplyAmount, 120)
        XCTAssertEqual(house.foodQualityRawValue, 63)
        XCTAssertEqual(house.foodQuality, .none)
        house.recordEvolutionSupplies(foodQualityRawValue: 63, commodityIDs: [])
        XCTAssertEqual(house.lastSuppliedFoodQualityRawValue, 63)

        // A higher raw market value replaces the byte, without an enum
        // round-trip that would erase the value.
        house.addFoodSupply(amount: 1, qualityRawValue: 80)
        XCTAssertEqual(house.foodQualityRawValue, 80)
        XCTAssertEqual(house.foodSupplyAmount, 121)
    }

    func testHouseFoodDeliveryUsesRecoveredSinglePrecisionLowerRatio() {
        // The PE stores the final blend threshold as the single-precision
        // value 0x3EA8F5C3 (0.33000001311302185), not an exact decimal 0.33.
        // This rational amount/stock pair is greater than 0.33 but still just
        // below that recovered float, so the original falls through to the
        // `(3 * current + market) / 4` arm and yields 75.
        var house = ResidentialUnit(
            id: 1,
            houseLevelID: 0,
            residents: 10,
            foodSupplyAmount: 762_603,
            foodQualityRawValue: 100
        )
        house.addFoodSupply(amount: 251_659, qualityRawValue: 0)
        XCTAssertEqual(house.foodQualityRawValue, 75)
        XCTAssertEqual(house.foodSupplyAmount, 1_014_262)
    }

    func testEliteMarketFoodQualityGateMapsBuildingModels11Through17() {
        var elite = ResidentialUnit(
            id: 1,
            houseLevelID: 11,
            residents: 10,
            foodSupplyAmount: 100,
            foodQualityRawValue: 70
        )
        elite.addFoodSupply(amount: 20, qualityRawValue: 45)
        XCTAssertEqual(elite.foodSupplyAmount, 120)
        XCTAssertEqual(elite.foodQualityRawValue, 70)

        var luxurious = ResidentialUnit(
            id: 2,
            houseLevelID: 7,
            residents: 10,
            foodSupplyAmount: 100,
            foodQualityRawValue: 70
        )
        luxurious.addFoodSupply(amount: 20, qualityRawValue: 45)
        XCTAssertEqual(luxurious.foodSupplyAmount, 120)
        XCTAssertEqual(luxurious.foodQualityRawValue, 63)

        var eliteBoundary = ResidentialUnit(
            id: 3,
            houseLevelID: 8,
            residents: 10,
            foodSupplyAmount: 100,
            foodQualityRawValue: 70
        )
        eliteBoundary.addFoodSupply(amount: 20, qualityRawValue: 45)
        XCTAssertEqual(eliteBoundary.foodSupplyAmount, 120)
        XCTAssertEqual(eliteBoundary.foodQualityRawValue, 70)
    }

    func testHousingEvolutionComparesRecoveredRawQualityByte() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let model = try XCTUnwrap(original.buildings[houseLevelID: 5])
        XCTAssertEqual(model.foodQualityRequired, 50)

        let house = ResidentialUnit(
            id: 1,
            houseLevelID: 4,
            residents: 10,
            foodSupplyAmount: 10,
            foodQualityRawValue: 63,
            lastSuppliedFoodQualityRawValue: 63
        )
        let missing = DeterministicHousingEvolution.requirementsMissing(
            model: model,
            house: house
        )
        XCTAssertFalse(missing.contains {
            if case .foodQuality = $0 { return true }
            return false
        })
    }

    func testPhysicalLogisticsMovesClayThroughKilnIntoWarehouse() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 9,
            mapHeight: 5
        )
        let road = (0...8).map { GridPoint(x: $0, y: 3) }
        XCTAssertEqual(city.buildRoad(road, rules: rules), road.count)
        let clayPitID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: 14,
            serviceRoadStart: GridPoint(x: 1, y: 3),
            rules: rules
        ))
        let kilnID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: 12,
            serviceRoadStart: GridPoint(x: 4, y: 3),
            rules: rules
        ))
        let warehouseID = try XCTUnwrap(city.constructWarehouse(
            serviceRoadStart: GridPoint(x: 7, y: 3),
            rules: rules
        ))

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.production.localOutputAmount(
            buildingInstanceID: clayPitID,
            commodityID: 18
        ), 100)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertEqual(city.production.localInputAmount(
            buildingInstanceID: kilnID,
            commodityID: 18
        ), 0)
        XCTAssertEqual(city.logistics[commodityID: 25], 0)

        // Original cadence (figure #22, 20 microsteps/cell, 27-28 per day):
        // walker 1 reaches the kiln around tick 3, returns around tick 5 and
        // is immediately re-dispatched on tick 6 for the remaining clay load
        // (monthly output 200, single cart load 100).
        for _ in 0..<6 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.production.localInputAmount(
            buildingInstanceID: kilnID,
            commodityID: 18
        ), 100)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertEqual(city.logistics.deliveryWalkers.first?.destination, .warehouse(warehouseID))
        XCTAssertEqual(city.production.localOutputAmount(
            buildingInstanceID: clayPitID,
            commodityID: 18
        ), 0)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 2)
        // 6 ticks after the second settlement the kiln has consumed its first
        // clay load and its brick cart has delivered 100 bricks; the remaining
        // clay is again on a fresh warehouse cart (tick 14 of the probe).
        for _ in 0..<6 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.production.localInputAmount(
            buildingInstanceID: kilnID,
            commodityID: 18
        ), 100)
        XCTAssertEqual(city.production.localOutputAmount(
            buildingInstanceID: kilnID,
            commodityID: 25
        ), 0)
        XCTAssertEqual(city.logistics[commodityID: 25], 100)
        XCTAssertEqual(city.production[commodityID: 25], 100)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertEqual(city.logistics.deliveryWalkers.first?.destination, .warehouse(warehouseID))
    }

    func testDistantWarehouseKeepsProducerBlockedUntilDeliverymanReturns() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 26,
            mapHeight: 3
        )
        let road = (0...25).map { GridPoint(x: $0, y: 1) }
        _ = city.buildRoad(road, rules: rules)
        let clayPitID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: 14,
            serviceRoadStart: GridPoint(x: 0, y: 1),
            rules: rules
        ))
        _ = city.constructWarehouse(
            serviceRoadStart: GridPoint(x: 20, y: 1),
            rules: rules
        )

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.logistics[commodityID: 18], 0)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertEqual(city.production.localOutputAmount(
            buildingInstanceID: clayPitID,
            commodityID: 18
        ), 100)
        XCTAssertNotNil(city.production.building(instanceID: clayPitID)?.activeDeliveryWalkerID)

        // Original cadence: 20 road cells one-way need about 15 days at the
        // recovered 20-microstep-per-cell / 27-28 steps-per-day figure #22
        // cadence, so the first cart has delivered by tick ~15 and is still
        // returning at tick 20.
        for _ in 0..<20 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.logistics[commodityID: 18], 100)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertNotNil(city.production.building(instanceID: clayPitID)?.activeDeliveryWalkerID)

        // The cart returns around tick 30 and is immediately re-dispatched
        // for the remaining 100 clay of the 200 monthly output.
        for _ in 0..<20 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertNotNil(city.production.building(instanceID: clayPitID)?.activeDeliveryWalkerID)
        XCTAssertEqual(city.production.localOutputAmount(
            buildingInstanceID: clayPitID,
            commodityID: 18
        ), 0)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        for _ in 0..<22 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.logistics[commodityID: 18], 300)
    }

    func testTaxOfficialWalksClosedDeterministicPatrolAndServicesPassedHouses() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 200,
            taxBandID: 3,
            mapWidth: 8,
            mapHeight: 6
        )
        let road = (0...6).map { GridPoint(x: $0, y: 3) }
            + (1...3).map { GridPoint(x: 3, y: $0) }
        XCTAssertEqual(city.buildRoad(road, rules: rules), Set(road).count)
        let firstCapacity = try XCTUnwrap(original.buildings[houseLevelID: 0]?.populationCapacity)
        let secondCapacity = try XCTUnwrap(original.buildings[houseLevelID: 2]?.populationCapacity)
        _ = city.addHouse(
            levelID: 0,
            residents: firstCapacity,
            location: GridPoint(x: 1, y: 2),
            models: original.buildings
        )
        _ = city.addHouse(
            levelID: 2,
            residents: secondCapacity,
            location: GridPoint(x: 5, y: 2),
            models: original.buildings
        )
        _ = city.addHouse(levelID: 1, residents: 4, models: original.buildings)

        let network = city.roadNetwork
        let origin = GridPoint(x: 0, y: 3)
        let route = DeterministicRoadPatrol.route(
            from: origin,
            maximumRoadSteps: 40,
            roadNetwork: network,
            replaySeed: 0x5348_414E_47,
            trip: 0
        )
        XCTAssertEqual(route.first, origin)
        XCTAssertEqual(route.last, origin)
        XCTAssertLessThanOrEqual(route.count - 1, 40)
        XCTAssertEqual(Set(route), network.points)
        XCTAssertEqual(
            route,
            DeterministicRoadPatrol.route(
                from: origin,
                maximumRoadSteps: 40,
                roadNetwork: network,
                replaySeed: 0x5348_414E_47,
                trip: 0
            )
        )

        XCTAssertNotNil(city.constructTaxOffice(
            serviceRoadStart: origin,
            replaySeed: 0x5348_414E_47,
            rules: rules
        ))
        XCTAssertEqual(city.walkers.walkers.count, 1)
        let movement = city.advanceServiceWalkers(roadStepsPerWalker: 40)
        XCTAssertGreaterThanOrEqual(movement.completedTrips, 1)
        XCTAssertEqual(movement.servicedHouseIDs.count, 2)
        XCTAssertEqual(city.houses.map(\.hasTaxCoverage), [true, true, false])

        let settlement = city.advanceMonth(rules: rules)
        XCTAssertEqual(settlement.taxedPopulation, firstCapacity + secondCapacity)
        XCTAssertEqual(settlement.untaxedPopulation, 4)
        XCTAssertGreaterThan(city.walkers.walkers[0].completedTrips, 1)
    }

    func testRoadblockBlocksRoamerPatrolAndCoverageButKeepsRoadForDestinationRoute() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 10,
            mapHeight: 10
        )
        // Horizontal road y=3 across x=0...7 plus a vertical road x=3 up y=0...7.
        // Grid halves meet at (3,3); a roadblock goes on the vertical road at (3,2).
        let roads = (0...7).map { GridPoint(x: $0, y: 3) }
            + (0...7).map { GridPoint(x: 3, y: $0) }
        XCTAssertEqual(city.buildRoad(roads, rules: rules), Set(roads).count)

        let roadblockPoint = GridPoint(x: 3, y: 2)
        XCTAssertTrue(city.canConstructRoadBlock(at: roadblockPoint))
        XCTAssertFalse(city.canConstructRoadBlock(at: GridPoint(x: 0, y: 0)))
        XCTAssertNil(city.constructRoadBlock(at: GridPoint(x: 0, y: 0), rules: rules))
        XCTAssertNotNil(city.constructRoadBlock(at: roadblockPoint, rules: rules))
        XCTAssertEqual(city.roadblockPoints, [roadblockPoint])

        // House beyond the roadblock (orthogonal road neighbour (3,1)).
        _ = city.addHouse(
            levelID: 0,
            residents: 5,
            location: GridPoint(x: 2, y: 0),
            models: original.buildings
        )
        // Control house on the same side as the service building (orthogonal
        // road neighbour (4,3) on the horizontal road).
        _ = city.addHouse(
            levelID: 0,
            residents: 5,
            location: GridPoint(x: 4, y: 4),
            models: original.buildings
        )
        let origin = GridPoint(x: 3, y: 7)
        XCTAssertNotNil(city.constructTaxOffice(
            serviceRoadStart: origin,
            replaySeed: 0x5242_4C_4B,
            rules: rules
        ))

        // Roamer patrol never enters the roadblock tile (turns away).
        let route = DeterministicRoadPatrol.route(
            from: origin,
            maximumRoadSteps: 40,
            roadNetwork: city.roadNetwork,
            replaySeed: 0x5242_4C_4B,
            trip: 0,
            barrierPoints: city.roadblockPoints
        )
        XCTAssertEqual(route.first, origin)
        XCTAssertEqual(route.last, origin)
        XCTAssertFalse(route.contains(roadblockPoint))

        // Coverage reachability also stops at the roadblock: only the control
        // house is covered.
        let covered = city.applyTaxCoverage(from: origin, maximumRoadSteps: 40)
        XCTAssertEqual(covered, 1)
        let coveredHouseIDs = Set(city.houses.compactMap { house in
            house.hasTaxCoverage ? house.id : nil
        })
        let controlHouseID = city.houses[1].id
        XCTAssertEqual(coveredHouseIDs, [controlHouseID])

        // The road itself stays intact, so a destination path still crosses the
        // roadblock tile.
        let destinationPath = try XCTUnwrap(GridPathfinder.shortestPath(
            width: city.roadNetwork.width,
            height: city.roadNetwork.height,
            from: origin,
            to: GridPoint(x: 3, y: 1),
            isPassable: city.roadNetwork.contains
        ))
        XCTAssertTrue(destinationPath.contains(roadblockPoint))
        XCTAssertTrue(city.roadNetwork.contains(roadblockPoint))

        // Walker movement visits neither the roadblock tile nor the far house.
        let movement = city.advanceServiceWalkers(roadStepsPerWalker: 40)
        XCTAssertFalse(movement.visitedRoadPoints.contains(roadblockPoint))
        XCTAssertEqual(movement.servicedHouseIDs, coveredHouseIDs)

        // Demolishing the roadblock reopens the road for roamers.
        XCTAssertNotNil(city.demolishBuilding(at: roadblockPoint, rules: rules))
        XCTAssertTrue(city.roadblockPoints.isEmpty)
        let reopenedCovered = city.applyTaxCoverage(from: origin, maximumRoadSteps: 40)
        XCTAssertEqual(reopenedCovered, 2)
    }

    func testRoadblockPlacedOnWalkerNextTileHoldsPositionWithoutTeleport() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 10,
            mapHeight: 10
        )
        let roads = (0...7).map { GridPoint(x: $0, y: 3) }
            + (0...7).map { GridPoint(x: 3, y: $0) }
        XCTAssertEqual(city.buildRoad(roads, rules: rules), Set(roads).count)

        let origin = GridPoint(x: 3, y: 7)
        XCTAssertNotNil(city.constructTaxOffice(
            serviceRoadStart: origin,
            replaySeed: 0x5242_4C_4B,
            rules: rules
        ))

        _ = city.advanceServiceWalkers(roadStepsPerWalker: 1)
        let positionBeforeBlock = try XCTUnwrap(city.walkers.walkers.first?.currentPoint)
        XCTAssertNotEqual(positionBeforeBlock, origin)
        let roadblockPoint = try XCTUnwrap(
            city.walkers.walkers.first?.route.dropFirst(
                (city.walkers.walkers.first?.routeIndex ?? 0) + 1
            ).first
        )
        XCTAssertNotNil(city.constructRoadBlock(at: roadblockPoint, rules: rules))
        let after = city.advanceServiceWalkers(roadStepsPerWalker: 1)
        XCTAssertFalse(after.visitedRoadPoints.contains(roadblockPoint))
        XCTAssertEqual(
            city.walkers.walkers.first?.currentPoint,
            positionBeforeBlock,
            "the unsupported post-collision turn choice must not become a teleport to origin"
        )
        XCTAssertNotNil(city.demolishBuilding(at: roadblockPoint, rules: rules))
        _ = city.advanceServiceWalkers(roadStepsPerWalker: 1)
        XCTAssertEqual(city.walkers.walkers.first?.currentPoint, roadblockPoint)
    }

    func testAdvanceTickBlocksExistingServiceWalkerAtNewRoadblock() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 8,
            mapHeight: 5
        )
        let roads = (0...5).map { GridPoint(x: $0, y: 2) }
        XCTAssertEqual(city.buildRoad(roads, rules: rules), roads.count)
        let origin = GridPoint(x: 0, y: 2)
        XCTAssertNotNil(city.constructTaxOffice(
            serviceRoadStart: origin,
            replaySeed: 0x5242_4C_4B,
            rules: rules
        ))
        let nextPoint = try XCTUnwrap(city.walkers.walkers.first?.route.dropFirst().first)
        XCTAssertEqual(nextPoint, GridPoint(x: 1, y: 2))
        XCTAssertNotNil(city.constructRoadBlock(at: nextPoint, rules: rules))

        _ = city.advanceTick(rules: rules)
        XCTAssertEqual(city.walkers.walkers.first?.currentPoint, origin)
        XCTAssertFalse(city.walkers.lastMovement?.visitedRoadPoints.contains(nextPoint) ?? true)
    }

    func testRoadServiceWalkerSaveRoundTripPreservesRouteState() throws {
        let origin = GridPoint(x: 0, y: 0)
        let barrier = GridPoint(x: 3, y: 0)
        let roads = RoadNetwork(
            width: 5,
            height: 1,
            points: Set((0...4).map { GridPoint(x: $0, y: 0) })
        )
        let walker = RoadServiceWalker(
            id: 1,
            figureID: 7,
            service: .tax,
            origin: origin,
            maximumRoadSteps: 8,
            replaySeed: 0x5242_4C_4B,
            roadNetwork: roads,
            barrierPoints: [barrier]
        )

        let decoded = try JSONDecoder().decode(
            RoadServiceWalker.self,
            from: JSONEncoder().encode(walker)
        )
        XCTAssertEqual(decoded, walker)
        XCTAssertFalse(decoded.route.contains(barrier))
    }

    func testOriginalMarketPeddlerCapacityUsesExecutableSlotType() {
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerCapacity(
                forMarketBuildingID: OriginalMarketCatalog.commonMarketBuildingID
            ),
            2
        )
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerCapacity(
                forMarketBuildingID: OriginalMarketCatalog.grandMarketBuildingID
            ),
            3
        )
    }

    func testOriginalMarketPeddlerCapacityGateChecksSourceSlotSet() {
        func gate(
            marketType: Int,
            primarySlotValid: Bool,
            attachedInfoSecondSlotValid: Bool,
            attachedInfoThirdSlotValid: Bool
        ) -> Bool {
            OriginalMarketCatalog.peddlerSlotsFullyOccupied(
                marketType: marketType,
                primarySlotValid: primarySlotValid,
                attachedInfoSecondSlotValid: attachedInfoSecondSlotValid,
                attachedInfoThirdSlotValid: attachedInfoThirdSlotValid
            )
        }

        XCTAssertTrue(gate(
            marketType: 1,
            primarySlotValid: true,
            attachedInfoSecondSlotValid: false,
            attachedInfoThirdSlotValid: false
        ))
        XCTAssertFalse(gate(
            marketType: 1,
            primarySlotValid: false,
            attachedInfoSecondSlotValid: true,
            attachedInfoThirdSlotValid: true
        ))
        XCTAssertTrue(gate(
            marketType: 2,
            primarySlotValid: true,
            attachedInfoSecondSlotValid: true,
            attachedInfoThirdSlotValid: false
        ))
        XCTAssertFalse(gate(
            marketType: 2,
            primarySlotValid: true,
            attachedInfoSecondSlotValid: false,
            attachedInfoThirdSlotValid: true
        ))
        XCTAssertTrue(gate(
            marketType: 3,
            primarySlotValid: true,
            attachedInfoSecondSlotValid: true,
            attachedInfoThirdSlotValid: true
        ))
        XCTAssertFalse(gate(
            marketType: 3,
            primarySlotValid: true,
            attachedInfoSecondSlotValid: true,
            attachedInfoThirdSlotValid: false
        ))
        XCTAssertTrue(gate(
            marketType: 99,
            primarySlotValid: true,
            attachedInfoSecondSlotValid: true,
            attachedInfoThirdSlotValid: true
        ))
    }

    func testOriginalMarketFactoryIdentityAdmitsOnlyTwoBuildingModels() {
        XCTAssertEqual(OriginalMarketCatalog.marketFactoryAddress, 0x005D3580)
        XCTAssertEqual(OriginalMarketCatalog.marketModelRecognizerAddress, 0x00543D90)
        XCTAssertEqual(OriginalMarketCatalog.marketConstructorAddress, 0x00543450)
        XCTAssertEqual(
            OriginalMarketCatalog.recognizedMarketBuildingIDs,
            [OriginalMarketCatalog.commonMarketBuildingID,
             OriginalMarketCatalog.grandMarketBuildingID]
        )
        XCTAssertFalse(OriginalMarketCatalog.recognizedMarketBuildingIDs.contains(0))
        XCTAssertFalse(OriginalMarketCatalog.recognizedMarketBuildingIDs.contains(59_000))
    }

    func testOriginalDestinationSelectorDispatchPreservesSixGlobalStrategies() {
        XCTAssertEqual(OriginalMarketCatalog.destinationSelectorDispatchAddress, 0x0051EB00)
        XCTAssertEqual(OriginalMarketCatalog.destinationSelectorConsumerAddress, 0x00521DF0)
        XCTAssertEqual(OriginalMarketCatalog.destinationSelectorRetryWrapperAddress, 0x00521C90)
        XCTAssertEqual(OriginalMarketCatalog.destinationSelectorStateUpdaterAddress, 0x00521D20)

        let descriptors = OriginalMarketCatalog.destinationSelectorDescriptors
        XCTAssertEqual(descriptors.map(\.selector), Array(0...5))
        XCTAssertEqual(descriptors.map(\.globalStateAddress), [
            0x010BFFB8, 0x010BFFB4, 0x010BFFB0,
            0x010BFFBC, 0x010BFFC0, 0x010BFFC4,
        ])
        XCTAssertEqual(descriptors.map(\.constructorAddress), [
            0x0051EA60, 0x0051EAA0, 0x0051EAE0,
            0x0051EA20, 0x0051E9E0, 0x0051E990,
        ])
        XCTAssertEqual(descriptors.map(\.vTableAddress), [
            0x007B6AF8, 0x007B6B0C, 0x007B6B20,
            0x007B6AE4, 0x007B6AD0, 0x007B6AA8,
        ])
        XCTAssertEqual(descriptors.map(\.admissionCallbackAddress), [
            0x0051FCE0, 0x0051F870, 0x0051F690,
            0x0051F1A0, 0x0051EF80, 0x0051EBA0,
        ])
        XCTAssertEqual(
            OriginalMarketCatalog.destinationSelectorDescriptor(for: 3)?.vTableAddress,
            0x007B6AE4
        )
        XCTAssertNil(OriginalMarketCatalog.destinationSelectorDescriptor(for: 6))
    }

    func testOriginalDestinationSelectorDirectCallsitesExcludeMapLoaders() {
        XCTAssertEqual(
            OriginalMarketCatalog.destinationSelectorDirectCallSites,
            [
                .init(callerAddress: 0x00521C90, callSiteAddress: 0x00521CBA),
                .init(callerAddress: 0x00521C90, callSiteAddress: 0x00521CFB),
                .init(callerAddress: 0x00521D20, callSiteAddress: 0x00521DDC),
            ]
        )
        XCTAssertTrue(
            OriginalMarketCatalog.destinationSelectorDirectCallSites
                .allSatisfy { $0.callerAddress != 0x0042D790 }
        )
    }

    func testOriginalMarketCommonAllocationWrapperIsExplicitConstructionMetadata() {
        XCTAssertEqual(
            OriginalMarketCatalog.commonMarketAllocationWrapperAddress,
            0x00540680
        )
        XCTAssertEqual(
            OriginalMarketCatalog.commonMarketAllocationWrapperAllocationSize,
            0x18c
        )
        XCTAssertEqual(
            OriginalMarketCatalog.commonMarketAllocationWrapperConstructorArgument,
            0
        )
        XCTAssertFalse(
            OriginalMarketCatalog.recognizedMarketBuildingIDs.contains(
                OriginalMarketCatalog.commonMarketAllocationWrapperConstructorArgument
            ),
            "wrapper argument is a constructor default, not a Qin archive model ID"
        )
    }

    func testOriginalMarketPeddlerSpawnThresholdUsesStrictCounterBands() {
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 100), 2)
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 75), 3)
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 50), 4)
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 25), 5)
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 1), 10)
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 0), 0)
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 74), 4)
        XCTAssertEqual(OriginalMarketCatalog.peddlerSpawnThreshold(workerPercent: 24), 10)
    }

    func testOriginalMarketPeddlerCoverageDispatchMatchesRecoveredCallbackChain() {
        let dispatch = OriginalMarketPeddlerCoverageDispatch.canonical

        XCTAssertEqual(dispatch.crossingFunctionAddress, 0x004EACD0)
        XCTAssertEqual(dispatch.marketRadiusWrapperAddress, 0x00429DF0)
        XCTAssertEqual(dispatch.radiusScanAddress, 0x00429E10)
        XCTAssertEqual(dispatch.marketVTableAddress, 0x007B6F3C)
        XCTAssertEqual(dispatch.marketRadiusVTableOffset, 0x28)
        XCTAssertEqual(dispatch.marketWriterVTableOffset, 0x2C)
        XCTAssertEqual(dispatch.radius, 2)
        XCTAssertEqual(dispatch.writerAddress, 0x005437B0)
    }

    func testOriginalMarketPeddlerModel23StartsInRecoveredRouteModeZero() {
        let route = OriginalMarketPeddlerRouteSearchDescriptor.canonical

        XCTAssertEqual(route.figureConstructorAddress, 0x004C71D0)
        XCTAssertEqual(route.figureInitializerAddress, 0x004C9160)
        XCTAssertEqual(route.routeDispatchAddress, 0x004E83E0)
        XCTAssertEqual(route.routeMode, 0)
        XCTAssertEqual(route.routeSearchAddress, 0x005AE740)
        XCTAssertEqual(route.neighbourExpansionAddress, 0x005AE840)
        XCTAssertEqual(route.searchResetAddress, 0x00521140)
        XCTAssertEqual(route.traversableMask, 0x0B1D)
        XCTAssertEqual(route.mapStride, 0xE4)
        XCTAssertEqual(route.queueCapacity, 0xCB10)
    }

    func testOriginalMarketStoredBandUsesExecutableStrictThresholds() {
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0), 0)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 1), 1)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x1D), 1)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x1E), 2)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x31), 2)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x32), 3)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x45), 3)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x46), 4)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x59), 4)
        XCTAssertEqual(OriginalMarketStoredBand.band(for: 0x5A), 5)
    }

    func testOriginalGrandMarketHelperAuxiliaryOffsetsPreserveModeTables() {
        let modeTwo = [
            0x17, 0x13, 0x0F, 0x14, 0x10, 0x0C, 0x16, 0x12,
            0x0E, 0x15, 0x11, 0x0D, 0x00, 0x06, 0x09, 0x03,
            0x01, 0x07, 0x0A, 0x04, 0x02, 0x08, 0x0B, 0x05
        ]
        let modeFour = [
            0x05, 0x04, 0x03, 0x02, 0x01, 0x00, 0x0B, 0x0A,
            0x09, 0x08, 0x07, 0x06, 0x17, 0x16, 0x15, 0x14,
            0x13, 0x12, 0x11, 0x10, 0x0F, 0x0E, 0x0D, 0x0C
        ]
        let modeSix = [
            0x0C, 0x10, 0x14, 0x0F, 0x13, 0x17, 0x0D, 0x11,
            0x15, 0x0E, 0x12, 0x16, 0x05, 0x0B, 0x08, 0x02,
            0x04, 0x0A, 0x07, 0x01, 0x03, 0x09, 0x06, 0x00
        ]

        for (index, expected) in modeTwo.enumerated() {
            XCTAssertEqual(
                OriginalMarketGrandHelperAuxiliaryOffset.offset(
                    auxiliary: 100 + index,
                    directionMode: 2
                ),
                expected
            )
        }
        for (index, expected) in modeFour.enumerated() {
            XCTAssertEqual(
                OriginalMarketGrandHelperAuxiliaryOffset.offset(
                    auxiliary: 100 + index,
                    directionMode: 4
                ),
                expected
            )
        }
        for (index, expected) in modeSix.enumerated() {
            XCTAssertEqual(
                OriginalMarketGrandHelperAuxiliaryOffset.offset(
                    auxiliary: 100 + index,
                    directionMode: 6
                ),
                expected
            )
        }

        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 100,
                directionMode: 6
            ),
            12
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 123,
                directionMode: 6
            ),
            0
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 100,
                directionMode: 1
            ),
            0
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 123,
                directionMode: 0
            ),
            23
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 124,
                directionMode: 0
            ),
            nil,
            "the city-stats input is required for the mode-0 tail"
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 124,
                directionMode: 0,
                cityStatsOffsetValue: 2
            ),
            2 * 12 + 0x23
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 124,
                directionMode: 4,
                cityStatsOffsetValue: 2
            ),
            2 * 12 + 0x1D
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 135,
                directionMode: 6,
                cityStatsOffsetValue: 3
            ),
            3 * 12 + 0x18
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 99,
                directionMode: 2
            ),
            nil
        )
        XCTAssertEqual(
            OriginalMarketGrandHelperAuxiliaryOffset.offset(
                auxiliary: 100,
                directionMode: -1
            ),
            nil
        )
    }

    func testOriginalMarketStoredStateAdvanceAppliesCapWithoutGuessingMeaning() {
        XCTAssertEqual(OriginalMarketStoredState.advance(currentValue: 0, maximumBand: 3), 20)
        XCTAssertEqual(OriginalMarketStoredState.advance(currentValue: 20, maximumBand: 3), 40)
        XCTAssertEqual(OriginalMarketStoredState.advance(currentValue: 40, maximumBand: 3), 60)
        XCTAssertEqual(OriginalMarketStoredState.advance(currentValue: 60, maximumBand: 3), 69)
        XCTAssertEqual(OriginalMarketStoredState.advance(currentValue: 0, maximumBand: 0), 0)
        XCTAssertEqual(OriginalMarketStoredState.advance(currentValue: 0, maximumBand: 5), 20)
    }

    func testOriginalMarketStoredStateRejectsInvalidOrOverflowingInputs() {
        XCTAssertNil(OriginalMarketStoredState.advance(currentValue: -1, maximumBand: 3))
        XCTAssertNil(OriginalMarketStoredState.advance(currentValue: 0, maximumBand: -1))
        XCTAssertNil(OriginalMarketStoredState.advance(currentValue: Int.max, maximumBand: 5))
    }

    func testOriginalMarketProviderAvailabilityFiltersEmptyRecordsAndSumsRawQuantity() {
        let records = [
            OriginalMarketProviderRecord(rawField4: 0, rawField8: 0),
            OriginalMarketProviderRecord(rawField4: 19, rawField8: 7),
            OriginalMarketProviderRecord(rawField4: 0, rawField8: 5),
            OriginalMarketProviderRecord(rawField4: 25, rawField8: 0),
            OriginalMarketProviderRecord(rawField4: 24, rawField8: -2),
        ]

        XCTAssertEqual(
            OriginalMarketProviderAvailability.total(records: records),
            10,
            "only the all-zero record is empty; every other rawField8 contributes"
        )
        XCTAssertEqual(
            OriginalMarketProviderAvailability.total(records: []),
            0,
            "a null/empty provider container yields zero availability"
        )
    }

    func testOriginalMarketWorkerAggregateUsesOnlyActiveAdmittedChildren() {
        let entries = [
            OriginalMarketWorkerAggregateEntry(
                isActive: true,
                passesSelectorMinusOne: true,
                workerValue: 7
            ),
            OriginalMarketWorkerAggregateEntry(
                isActive: false,
                passesSelectorMinusOne: true,
                workerValue: 100
            ),
            OriginalMarketWorkerAggregateEntry(
                isActive: true,
                passesSelectorMinusOne: false,
                workerValue: 200
            ),
            OriginalMarketWorkerAggregateEntry(
                isActive: true,
                passesSelectorMinusOne: true,
                workerValue: -2
            )
        ]

        XCTAssertEqual(OriginalMarketWorkerAggregate.slotCount, 6)
        XCTAssertEqual(OriginalMarketWorkerAggregate.selector, -1)
        XCTAssertEqual(OriginalMarketWorkerAggregate.total(entries: entries), 5)
        XCTAssertEqual(
            OriginalMarketWorkerAggregate.total(entries: []),
            0,
            "null cMarket slots contribute no child value"
        )
    }

    func testOriginalMarketWorkerAggregateRejectsMoreThanSixSlots() {
        let entries = (0...OriginalMarketWorkerAggregate.slotCount).map {
            OriginalMarketWorkerAggregateEntry(
                isActive: true,
                passesSelectorMinusOne: true,
                workerValue: $0
            )
        }

        XCTAssertNil(OriginalMarketWorkerAggregate.total(entries: entries))
    }

    func testOriginalMarketPeddlerWorkerAggregateSeparatesEmptyShopAndFilledShopInputs() {
        let aggregate = OriginalMarketPeddlerWorkerAggregate.from(entries: [
            .init(slotPresent: true, shopBuildingID: 62, rawField44: 0xFFFF),
            .init(slotPresent: true, shopBuildingID: 66, employeeField: 8),
            .init(slotPresent: true, shopBuildingID: 67, employeeField: 7),
            .init(slotPresent: false, shopBuildingID: 70, employeeField: 10),
        ])
        XCTAssertEqual(aggregate?.rawEmptyShopField44, -1)
        XCTAssertEqual(aggregate?.filledShopEmployeeUnits, 15)

        XCTAssertNil(
            OriginalMarketPeddlerWorkerAggregate.from(entries: (0..<7).map {
                .init(slotPresent: true, shopBuildingID: 62, rawField44: $0)
            })
        )
        XCTAssertNil(
            OriginalMarketPeddlerWorkerAggregate.from(entries: [
                .init(slotPresent: true, shopBuildingID: 59, employeeField: 8)
            ])
        )
    }

    func testOriginalMarketCStallCategoryCatalogMatchesRecoveredTable() {
        for buildingID in [62, 64, 65, 66, 67, 68, 69, 70] {
            XCTAssertEqual(
                OriginalMarketCStallCategoryCatalog.sourceCategoryIndex(forShopBuildingID: buildingID),
                2,
                "admitted cStall model \(buildingID) must read raw category slot 2"
            )
        }

        for buildingID in [0, 59, 63, 71, 207, 208] {
            XCTAssertNil(
                OriginalMarketCStallCategoryCatalog.sourceCategoryIndex(forShopBuildingID: buildingID),
                "unadmitted model \(buildingID) must not inherit the cStall category"
            )
        }
    }

    func testOriginalMarketPoolAdmissionPreservesCStallGateOrder() {
        let accepted = OriginalMarketPoolAdmissionInput(
            tableCategory: 2,
            globalActive: true,
            objectWord4E: 0,
            emptyShopConflict: false,
            objectWord3C: 0,
            specialCategoryConflict: false,
            callback198Accepted: true,
            callback78Accepted: true
        )
        XCTAssertTrue(OriginalMarketPoolAdmissionCatalog.accepts(accepted))

        let rejectors: [(String, (OriginalMarketPoolAdmissionInput) -> OriginalMarketPoolAdmissionInput)] = [
            ("global active", { .init(tableCategory: $0.tableCategory, globalActive: false, objectWord4E: $0.objectWord4E, emptyShopConflict: $0.emptyShopConflict, objectWord3C: $0.objectWord3C, specialCategoryConflict: $0.specialCategoryConflict, callback198Accepted: $0.callback198Accepted, callback78Accepted: $0.callback78Accepted) }),
            ("object +0x4e", { .init(tableCategory: $0.tableCategory, globalActive: $0.globalActive, objectWord4E: 1, emptyShopConflict: $0.emptyShopConflict, objectWord3C: $0.objectWord3C, specialCategoryConflict: $0.specialCategoryConflict, callback198Accepted: $0.callback198Accepted, callback78Accepted: $0.callback78Accepted) }),
            ("empty-shop conflict", { .init(tableCategory: $0.tableCategory, globalActive: $0.globalActive, objectWord4E: $0.objectWord4E, emptyShopConflict: true, objectWord3C: $0.objectWord3C, specialCategoryConflict: $0.specialCategoryConflict, callback198Accepted: $0.callback198Accepted, callback78Accepted: $0.callback78Accepted) }),
            ("object +0x3c", { .init(tableCategory: $0.tableCategory, globalActive: $0.globalActive, objectWord4E: $0.objectWord4E, emptyShopConflict: $0.emptyShopConflict, objectWord3C: 1, specialCategoryConflict: $0.specialCategoryConflict, callback198Accepted: $0.callback198Accepted, callback78Accepted: $0.callback78Accepted) }),
            ("vtable +0x198", { .init(tableCategory: $0.tableCategory, globalActive: $0.globalActive, objectWord4E: $0.objectWord4E, emptyShopConflict: $0.emptyShopConflict, objectWord3C: $0.objectWord3C, specialCategoryConflict: $0.specialCategoryConflict, callback198Accepted: false, callback78Accepted: $0.callback78Accepted) }),
            ("vtable +0x78", { .init(tableCategory: $0.tableCategory, globalActive: $0.globalActive, objectWord4E: $0.objectWord4E, emptyShopConflict: $0.emptyShopConflict, objectWord3C: $0.objectWord3C, specialCategoryConflict: $0.specialCategoryConflict, callback198Accepted: $0.callback198Accepted, callback78Accepted: false) }),
        ]
        for (label, mutate) in rejectors {
            let input = mutate(accepted)
            XCTAssertFalse(
                OriginalMarketPoolAdmissionCatalog.accepts(input),
                "source gate \(label) must reject"
            )
        }
    }

    func testOriginalMarketPoolAdmissionAppliesSpecialCategoryConflictOnlyToZeroOneSeven() {
        for category in [0, 1, 7] {
            let input = OriginalMarketPoolAdmissionInput(
                tableCategory: category,
                globalActive: true,
                objectWord4E: 0,
                emptyShopConflict: false,
                objectWord3C: 0,
                specialCategoryConflict: true,
                callback198Accepted: true,
                callback78Accepted: true
            )
            XCTAssertFalse(
                OriginalMarketPoolAdmissionCatalog.accepts(input),
                "category \(category) must apply FUN_004AE560 conflict gate"
            )
        }

        let categoryEight = OriginalMarketPoolAdmissionInput(
            tableCategory: 8,
            globalActive: true,
            objectWord4E: 0,
            emptyShopConflict: false,
            objectWord3C: 0,
            specialCategoryConflict: true,
            callback198Accepted: true,
            callback78Accepted: true
        )
        XCTAssertTrue(
            OriginalMarketPoolAdmissionCatalog.accepts(categoryEight),
            "category 8 must not call the special-category gate"
        )
    }

    func testOriginalMarketPoolAdmissionRejectsNegativeAndNineTableCategories() {
        for category in [-1, 9] {
            let input = OriginalMarketPoolAdmissionInput(
                tableCategory: category,
                globalActive: true,
                objectWord4E: 0,
                emptyShopConflict: false,
                objectWord3C: 0,
                specialCategoryConflict: false,
                callback198Accepted: true,
                callback78Accepted: true
            )
            XCTAssertFalse(OriginalMarketPoolAdmissionCatalog.accepts(input))
        }
    }

    func testOriginalMarketCStallPoolProjectionPreservesNineRowsAndUntouchedTenthSlot() {
        let records = (0..<9).map { index in
            OriginalMarketCStallPoolRecord(
                sourceWord0: 100 + index,
                sourceWord1: index == 1 ? 4 : 110 + index,
                sourceWord2: 0x200 + index,
                sourceWord3: index == 1 ? 3 : index,
                sourceWord4: index
            )
        }

        let projection = OriginalMarketCStallPoolProjectionCatalog.project(records: records)
        XCTAssertEqual(projection?.firstPool.count, 10)
        XCTAssertEqual(projection?.secondPool.count, 10)
        XCTAssertEqual(projection?.firstPool[1], 3)
        XCTAssertEqual(projection?.secondPool[1], 1)
        XCTAssertEqual(projection?.firstPool[0], 0)
        XCTAssertEqual(projection?.secondPool[0], 0)
        XCTAssertEqual(projection?.firstPool[9], 0)
        XCTAssertEqual(projection?.secondPool[9], 0)

        XCTAssertNil(
            OriginalMarketCStallPoolProjectionCatalog.project(records: Array(records.dropLast()))
        )
        XCTAssertNil(
            OriginalMarketCStallPoolProjectionCatalog.project(
                records: records + [records[0]]
            )
        )
    }

    func testOriginalMarketCStallPoolProjectionExposesSourceBoundary() {
        XCTAssertEqual(OriginalMarketCStallPoolProjectionCatalog.sourceAddress, 0x004F19A0)
        XCTAssertEqual(OriginalMarketCStallPoolProjectionCatalog.sourceTableAddress, 0x01312144)
        XCTAssertEqual(OriginalMarketCStallPoolProjectionCatalog.sourceRecordCount, 9)
        XCTAssertEqual(OriginalMarketCStallPoolProjectionCatalog.sourceRecordStride, 0x14)
        XCTAssertEqual(OriginalMarketCStallPoolProjectionCatalog.callbackPoolSlotCount, 10)
        XCTAssertEqual(OriginalMarketCStallPoolProjectionCatalog.callbackSelectors, [1, 2])
    }

    func testOriginalMarketCStallPoolBalanceCopiesRowsWhenTargetCoversSource() {
        let records = [
            OriginalMarketCStallPoolRecord(sourceWord0: 10, sourceWord1: 99, sourceWord2: 4, sourceWord3: 3, sourceWord4: 6),
            OriginalMarketCStallPoolRecord(sourceWord0: 5, sourceWord1: 0, sourceWord2: 2, sourceWord3: 1, sourceWord4: 4),
        ] + Array(repeating: OriginalMarketCStallPoolRecord(sourceWord0: 0, sourceWord1: 0, sourceWord2: 0, sourceWord3: 0, sourceWord4: 0), count: 7)

        let result = OriginalMarketCStallPoolBalanceCatalog.balance(
            records: records,
            targetTotal: 20
        )
        XCTAssertEqual(result?.sourceTotal, 15)
        XCTAssertEqual(result?.normalizedTotal, 15)
        XCTAssertEqual(result?.unallocatedTotal, 0)
        XCTAssertEqual(result?.normalizedShortfall, 5)
        XCTAssertEqual(result?.normalizedShortfallPercent, 25)
        XCTAssertEqual(result?.rows[0].sourceWord1, 10)
        XCTAssertEqual(result?.rows[0].sourceWord3, 4)
        XCTAssertEqual(result?.rows[0].sourceWord4, 3, "source only clamps word4 when it exceeds 5")
    }

    func testOriginalMarketCStallPoolBalancePreservesCategoryZeroTopUpOrder() {
        let records = [
            OriginalMarketCStallPoolRecord(sourceWord0: 100, sourceWord1: 0, sourceWord2: 20, sourceWord3: 7, sourceWord4: 0),
        ] + Array(repeating: OriginalMarketCStallPoolRecord(sourceWord0: 0, sourceWord1: 0, sourceWord2: 0, sourceWord3: 0, sourceWord4: 1), count: 8)

        let result = OriginalMarketCStallPoolBalanceCatalog.balance(
            records: records,
            targetTotal: 50
        )
        XCTAssertEqual(result?.rows[0].sourceWord0, 100)
        XCTAssertEqual(result?.rows[0].sourceWord1, 50)
        XCTAssertEqual(result?.rows[0].sourceWord2, 20)
        XCTAssertEqual(result?.rows[0].sourceWord3, 20)
        XCTAssertEqual(result?.unallocatedTotal, 50)
        XCTAssertEqual(result?.normalizedTotal, 50)
    }

    func testOriginalMarketCStallPoolBalanceTopUpFillsWordTwoBeforeWordZero() {
        let records = [
            OriginalMarketCStallPoolRecord(sourceWord0: 3, sourceWord1: 0, sourceWord2: 3, sourceWord3: 0, sourceWord4: 0),
            OriginalMarketCStallPoolRecord(sourceWord0: 3, sourceWord1: 0, sourceWord2: 3, sourceWord3: 0, sourceWord4: 0),
        ] + Array(repeating: OriginalMarketCStallPoolRecord(sourceWord0: 0, sourceWord1: 0, sourceWord2: 0, sourceWord3: 0, sourceWord4: 1), count: 7)

        let result = OriginalMarketCStallPoolBalanceCatalog.balance(
            records: records,
            targetTotal: 5
        )
        XCTAssertEqual(result?.rows[0].sourceWord0, 3)
        XCTAssertEqual(result?.rows[0].sourceWord1, 3)
        XCTAssertEqual(result?.rows[0].sourceWord2, 3)
        XCTAssertEqual(result?.rows[0].sourceWord3, 3)
        XCTAssertEqual(result?.rows[1].sourceWord1, 2)
        XCTAssertEqual(result?.rows[1].sourceWord3, 2)
    }

    func testOriginalMarketCStallPoolBalanceRequiresFixedNineRows() {
        XCTAssertNil(
            OriginalMarketCStallPoolBalanceCatalog.balance(
                records: [],
                targetTotal: 0
            )
        )
    }

    func testOriginalMarketCStallField44ProducerAppliesRatioAndPoolSelection() {
        let result = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: true,
            statusCode: 0,
            selector: 1,
            providerUsesPrimaryPool: true,
            providerCapacity: 30,
            currentField44: 99,
            primaryRatioNumerator: 2,
            primaryRatioDenominator: 5,
            primaryPoolValue: 20,
            secondaryPoolValue: 7
        ))
        XCTAssertEqual(result.ratioPercent, 40)
        XCTAssertEqual(result.allocatedAmount, 12)
        XCTAssertEqual(result.nextField44, 12)
        XCTAssertEqual(result.primaryPoolValue, 8)
        XCTAssertEqual(result.secondaryPoolValue, 7)

        let zeroDenominator = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: true,
            statusCode: 0,
            selector: 1,
            providerUsesPrimaryPool: true,
            providerCapacity: 30,
            currentField44: 0,
            primaryRatioNumerator: 9,
            primaryRatioDenominator: 0,
            primaryPoolValue: 20
        ))
        XCTAssertEqual(zeroDenominator.ratioPercent, 0)
        XCTAssertEqual(zeroDenominator.allocatedAmount, 0)
        XCTAssertEqual(zeroDenominator.nextField44, 0)
        XCTAssertEqual(zeroDenominator.primaryPoolValue, 20)

        let secondary = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: true,
            statusCode: 0,
            selector: 1,
            providerUsesPrimaryPool: false,
            providerCapacity: 30,
            currentField44: 0,
            secondaryRatioNumerator: 1,
            secondaryRatioDenominator: 4,
            primaryPoolValue: 20,
            secondaryPoolValue: 7
        ))
        XCTAssertEqual(secondary.allocatedAmount, 7)
        XCTAssertEqual(secondary.nextField44, 7)
        XCTAssertEqual(secondary.secondaryPoolValue, 0)
    }

    func testOriginalMarketCStallField44ProducerPreservesGatesAndTopUpWidth() {
        let cleared = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: false,
            statusCode: 8,
            selector: 1,
            providerUsesPrimaryPool: true,
            providerCapacity: 10,
            currentField44: 4,
            primaryPoolValue: 9,
            secondaryPoolValue: 3
        ))
        XCTAssertEqual(cleared.nextField44, 0)
        XCTAssertEqual(cleared.primaryPoolValue, 9)
        XCTAssertNil(cleared.allocatedAmount)

        let exempt = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: false,
            statusCode: 9,
            selector: 1,
            providerUsesPrimaryPool: true,
            providerCapacity: 10,
            currentField44: 4,
            primaryPoolValue: 9,
            secondaryPoolValue: 3
        ))
        XCTAssertEqual(exempt.nextField44, 4)
        XCTAssertEqual(exempt.primaryPoolValue, 9)
        XCTAssertEqual(exempt.secondaryPoolValue, 3)
        XCTAssertNil(exempt.allocatedAmount)

        let topUp = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: true,
            statusCode: 0,
            selector: 2,
            providerUsesPrimaryPool: false,
            providerCapacity: 40,
            currentField44: 30,
            primaryPoolValue: 4,
            secondaryPoolValue: 25
        ))
        XCTAssertEqual(topUp.nextField44, 40)
        XCTAssertEqual(topUp.secondaryPoolValue, 15)

        let alreadyFull = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: true,
            statusCode: 0,
            selector: 2,
            providerUsesPrimaryPool: false,
            providerCapacity: 40,
            currentField44: 40,
            secondaryPoolValue: 25
        ))
        XCTAssertEqual(alreadyFull.nextField44, 40)
        XCTAssertEqual(alreadyFull.secondaryPoolValue, 25)
        XCTAssertEqual(alreadyFull.consumedPoolValue, 0)

        let lowPool = OriginalMarketCStallField44Producer.apply(.init(
            callbackAccepted: true,
            statusCode: 0,
            selector: 2,
            providerUsesPrimaryPool: true,
            providerCapacity: 40,
            currentField44: 30,
            primaryPoolValue: 4
        ))
        XCTAssertEqual(lowPool.nextField44, 34)
        XCTAssertEqual(lowPool.primaryPoolValue, 0)
    }

    func testOriginalMarketMonthlyDinnersGateAcceptsSelectorMinusThree() {
        XCTAssertTrue(
            OriginalMarketMonthlyDinnersGate.isEligible(
                receiverModelID: OriginalMarketCatalog.commonMarketBuildingID
            )
        )
        XCTAssertTrue(
            OriginalMarketMonthlyDinnersGate.isEligible(
                receiverModelID: OriginalMarketCatalog.grandMarketBuildingID
            )
        )
        XCTAssertTrue(
            OriginalMarketMonthlyDinnersGate.isEligible(
                receiverModelID: 0,
                selector: -7
            )
        )
        XCTAssertTrue(
            OriginalMarketMonthlyDinnersGate.isEligible(
                receiverModelID: 59,
                selector: 123,
                auxiliaryResult: 123
            )
        )
        XCTAssertFalse(
            OriginalMarketMonthlyDinnersGate.isEligible(
                receiverModelID: 59,
                selector: 123,
                auxiliaryResult: 124
            )
        )
    }

    func testOriginalMarketProviderSelectionScorePreservesGatesAndIntegerRatio() {
        XCTAssertEqual(
            OriginalMarketProviderSelectionScore.score(
                resourceIndex: 1,
                state: 2,
                keyAccepted: true,
                quantity: 25,
                capacity: 200
            ),
            12
        )
        XCTAssertEqual(
            OriginalMarketProviderSelectionScore.score(
                resourceIndex: 0,
                state: 2,
                keyAccepted: true,
                quantity: 25,
                capacity: 200
            ),
            100
        )
        XCTAssertEqual(
            OriginalMarketProviderSelectionScore.score(
                resourceIndex: 1,
                state: 1,
                keyAccepted: true,
                quantity: 25,
                capacity: 200
            ),
            100
        )
        XCTAssertEqual(
            OriginalMarketProviderSelectionScore.score(
                resourceIndex: 1,
                state: 2,
                keyAccepted: false,
                quantity: 25,
                capacity: 200
            ),
            100
        )
        XCTAssertEqual(
            OriginalMarketProviderSelectionScore.score(
                resourceIndex: 1,
                state: 2,
                keyAccepted: true,
                quantity: 200,
                capacity: 200
            ),
            100
        )
        XCTAssertEqual(
            OriginalMarketProviderSelectionScore.score(
                resourceIndex: 1,
                state: 2,
                keyAccepted: true,
                quantity: 0,
                capacity: 0
            ),
            100
        )
        XCTAssertNil(
            OriginalMarketProviderSelectionScore.score(
                resourceIndex: 1,
                state: 2,
                keyAccepted: true,
                quantity: -1,
                capacity: 0
            )
        )
    }

    func testOriginalMarketProviderCandidateReductionPreservesStrictMinimumAndTies() {
        let selected = OriginalMarketProviderCandidateReduction.select([
            .init(sourceIdentity: 101, mapCellIndex: 10, floodValue: 0),
            .init(sourceIdentity: 102, mapCellIndex: 11, floodValue: 12),
            .init(sourceIdentity: 103, mapCellIndex: 12, floodValue: 12),
            .init(sourceIdentity: 104, mapCellIndex: 13, floodValue: 9_999),
            .init(sourceIdentity: 105, mapCellIndex: 14, floodValue: -1),
            .init(sourceIdentity: 106, mapCellIndex: 15, floodValue: 4)
        ])

        XCTAssertEqual(selected?.candidateOrdinal, 5)
        XCTAssertEqual(selected?.sourceIdentity, 106)
        XCTAssertEqual(selected?.floodValue, 4)

        let firstTie = OriginalMarketProviderCandidateReduction.select([
            .init(sourceIdentity: 201, mapCellIndex: 20, floodValue: 7),
            .init(sourceIdentity: 202, mapCellIndex: 21, floodValue: 7)
        ])
        XCTAssertEqual(firstTie?.sourceIdentity, 201)

        XCTAssertNil(
            OriginalMarketProviderCandidateReduction.select([
                .init(sourceIdentity: 301, mapCellIndex: 30, floodValue: 0),
                .init(sourceIdentity: 302, mapCellIndex: 31, floodValue: 9_999),
                .init(sourceIdentity: 303, mapCellIndex: 32, floodValue: -4)
            ])
        )
    }

    func testOriginalMarketResourceGroupCommodityMapPreservesExecutableSwitch() {
        XCTAssertEqual(
            (0...6).compactMap {
                OriginalMarketResourceGroupCommodityMap.commodityID(
                    forResourceGroupIndex: $0
                )
            },
            [0x1C, 0x13, 0x19, 0x18, 0x17, 0x16, 0x0D]
        )
        XCTAssertNil(
            OriginalMarketResourceGroupCommodityMap.commodityID(
                forResourceGroupIndex: -1
            )
        )
        XCTAssertNil(
            OriginalMarketResourceGroupCommodityMap.commodityID(
                forResourceGroupIndex: 7
            )
        )
    }

    func testOriginalMarketResourceGroupPriorityUsesFirstNonZeroAndTwentySevenSlotBound() {
        XCTAssertEqual(
            OriginalMarketResourceGroupPriority.firstNonZeroIndex(
                counts: [0, 0, 4, 1]
            ),
            2
        )
        XCTAssertEqual(
            OriginalMarketResourceGroupPriority.firstNonZeroIndex(
                counts: Array(repeating: 0, count: 27)
            ),
            nil
        )
        XCTAssertNil(
            OriginalMarketResourceGroupPriority.firstNonZeroIndex(
                counts: Array(repeating: 1, count: 28)
            )
        )
    }

    func testOriginalMarketProviderKeyAvailabilityPreservesDivisibilityAndCapacityGates() {
        XCTAssertFalse(
            OriginalMarketProviderKeyAvailability.isAvailable(
                recordCount: 7,
                nonEmptyRecordCount: 7,
                quantity: 800,
                capacity: 1_000
            ),
            "a full provider container at an exact 400-unit boundary is not admitted"
        )
        XCTAssertTrue(
            OriginalMarketProviderKeyAvailability.isAvailable(
                recordCount: 7,
                nonEmptyRecordCount: 7,
                quantity: 799,
                capacity: 1_000
            ),
            "a full provider container admits a non-boundary quantity below capacity"
        )
        XCTAssertTrue(
            OriginalMarketProviderKeyAvailability.isAvailable(
                recordCount: 7,
                nonEmptyRecordCount: 6,
                quantity: 800,
                capacity: 1_000
            ),
            "an empty provider slot admits an exact 400-unit boundary"
        )
        XCTAssertFalse(
            OriginalMarketProviderKeyAvailability.isAvailable(
                recordCount: 7,
                nonEmptyRecordCount: 6,
                quantity: 1_000,
                capacity: 1_000
            ),
            "capacity is a strict upper bound"
        )
    }

    func testOriginalMarketPeddlerEndpointSelectionUsesStrictComponentRankOrder() {
        let selected = OriginalMarketPeddlerEndpointSelection.select([
            .init(
                rawPoint: GridPoint(x: 4, y: 4),
                terrainFlags: 0x40,
                componentRank: 5
            ),
            .init(
                rawPoint: GridPoint(x: 5, y: 4),
                adjustedPoint: GridPoint(x: 6, y: 4),
                terrainFlags: 0x40,
                componentRank: 2
            ),
            .init(
                rawPoint: GridPoint(x: 7, y: 4),
                terrainFlags: 0x40,
                componentRank: 2
            )
        ])
        XCTAssertEqual(selected, GridPoint(x: 6, y: 4), "strict rank keeps the first tie")

        XCTAssertEqual(
            OriginalMarketPeddlerEndpointSelection.select([
                .init(rawPoint: GridPoint(x: 1, y: 1), terrainFlags: 0x44, componentRank: 0),
                .init(rawPoint: GridPoint(x: 2, y: 1), terrainFlags: 0x44, componentRank: 1),
                .init(
                    rawPoint: GridPoint(x: 3, y: 1),
                    terrainFlags: 0x40,
                    componentRank: nil
                )
            ]),
            GridPoint(x: 3, y: 1),
            "bit 0x04 rejects the first cell and rank-11 is the absent-entry sentinel"
        )
        XCTAssertEqual(
            OriginalMarketPeddlerEndpointSelection.select([
                .init(
                    rawPoint: GridPoint(x: 0, y: 0),
                    adjustedPoint: GridPoint(x: -1, y: 0),
                    terrainFlags: 0x40,
                    componentRank: 0
                ),
                .init(rawPoint: GridPoint(x: 1, y: 0), terrainFlags: 0x20, componentRank: 0)
            ]),
            GridPoint(x: -1, y: 0),
            "BA370 does not inspect the +0xD0 callback return; terrain is tested after the callback"
        )
    }

    func testOriginalMarketPeddlerEndpointScanMatchesRecoveredClampAndRowOrder() {
        XCTAssertEqual(
            OriginalMarketPeddlerEndpointScan.rectangularPoints(
                anchor: GridPoint(x: 3, y: 2),
                scanSpan: 2,
                rotation: 1,
                mapWidth: 8,
                mapHeight: 7
            ),
            [
                GridPoint(x: 2, y: 1), GridPoint(x: 3, y: 1),
                GridPoint(x: 4, y: 1), GridPoint(x: 5, y: 1),
                GridPoint(x: 2, y: 2), GridPoint(x: 3, y: 2),
                GridPoint(x: 4, y: 2), GridPoint(x: 5, y: 2),
                GridPoint(x: 2, y: 3), GridPoint(x: 3, y: 3),
                GridPoint(x: 4, y: 3), GridPoint(x: 5, y: 3),
                GridPoint(x: 2, y: 4), GridPoint(x: 3, y: 4),
                GridPoint(x: 4, y: 4), GridPoint(x: 5, y: 4),
            ]
        )
        XCTAssertEqual(
            OriginalMarketPeddlerEndpointScan.rectangularPoints(
                anchor: GridPoint(x: 0, y: 0),
                scanSpan: 2,
                rotation: 2,
                mapWidth: 3,
                mapHeight: 2
            ),
            [
                GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0), GridPoint(x: 2, y: 0),
                GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1),
            ],
            "clamping preserves the source's inclusive row-major scan"
        )
        XCTAssertEqual(
            OriginalMarketPeddlerEndpointScan.rectangularPoints(
                anchor: GridPoint(x: 5, y: 5),
                scanSpan: 2,
                rotation: 0,
                mapWidth: 4,
                mapHeight: 4
            ),
            [],
            "a fully out-of-map rectangle has no scan candidates"
        )
        XCTAssertNil(
            OriginalMarketPeddlerEndpointScan.rectangularPoints(
                anchor: GridPoint(x: 0, y: 0),
                scanSpan: 2,
                rotation: -1,
                mapWidth: 4,
                mapHeight: 4
            )
        )
    }

    func testOriginalMarketHouseDeliveryPassCatalogMatchesWriterOrder() {
        XCTAssertEqual(
            OriginalMarketHouseDeliveryPassCatalog.entries.map(\.commodityID),
            [0x13, 0x0D, 0x19, 0x16, 0x17, 0x18]
        )
        XCTAssertEqual(
            OriginalMarketHouseDeliveryPassCatalog.entries.map(\.providerRecordSlot),
            [1, 2, 3, 4, 5, 6]
        )
        XCTAssertEqual(
            OriginalMarketHouseDeliveryPassCatalog.entries.map(\.tableAddress),
            [0x00857344, 0x00857384, 0x008573C4,
             0x00857404, 0x00857444, 0x00857484]
        )
        XCTAssertEqual(
            OriginalMarketHouseDeliveryPassCatalog.entry(forCommodityID: 0x19)?.providerRecordSlot,
            3
        )
        XCTAssertNil(
            OriginalMarketHouseDeliveryPassCatalog.entry(forCommodityID: 0x1C),
            "Dinners is handled by the writer's separate pre-loop branch"
        )
    }

    func testOriginalMarketPeddlerHelperRecordCatalogMatchesCanonicalBanks() {
        XCTAssertEqual(
            OriginalMarketPeddlerHelperRecordCatalog.records(
                forMarketBuildingID: 59,
                orientationBank: 0
            )?.map(\.offset),
            [GridPoint(x: 0, y: 3), GridPoint(x: 3, y: 3)]
        )
        XCTAssertEqual(
            OriginalMarketPeddlerHelperRecordCatalog.records(
                forMarketBuildingID: 59,
                orientationBank: 1
            )?.map(\.offset),
            [GridPoint(x: 3, y: 0), GridPoint(x: 3, y: 3)]
        )
        XCTAssertEqual(
            OriginalMarketPeddlerHelperRecordCatalog.records(
                forMarketBuildingID: 60,
                orientationBank: 0
            )?.map(\.offset),
            [GridPoint(x: 0, y: 3), GridPoint(x: 5, y: 3)]
        )
        XCTAssertEqual(
            OriginalMarketPeddlerHelperRecordCatalog.records(
                forMarketBuildingID: 60,
                orientationBank: 1
            )?.map(\.offset),
            [GridPoint(x: 3, y: 0), GridPoint(x: 3, y: 5)]
        )
        XCTAssertNil(
            OriginalMarketPeddlerHelperRecordCatalog.records(
                forMarketBuildingID: 59,
                orientationBank: 2
            )
        )
    }

    func testOriginalMarketPeddlerHelperRecordCatalogUsesStrictNearestTieOrder() {
        XCTAssertEqual(
            OriginalMarketPeddlerHelperRecordCatalog.nearestTarget(
                target: GridPoint(x: 10, y: 10),
                marketOrigin: GridPoint(x: 0, y: 0),
                marketBuildingID: 59,
                orientationBank: 0
            ),
            GridPoint(x: 3, y: 3)
        )
        XCTAssertEqual(
            OriginalMarketPeddlerHelperRecordCatalog.nearestTarget(
                target: GridPoint(x: 1, y: 3),
                marketOrigin: GridPoint(x: 0, y: 0),
                marketBuildingID: 59,
                orientationBank: 0
            ),
            GridPoint(x: 0, y: 3)
        )
    }

    func testOriginalMarketAccessRefreshProjectsLinearCellAndPreservesFloodResult() {
        XCTAssertEqual(OriginalMarketAccessRefresh.callbackAddress, 0x00427410)
        XCTAssertEqual(OriginalMarketAccessRefresh.callbackDestinationOffset, 0x18)
        XCTAssertEqual(
            OriginalMarketProviderSelectionComponentGate.destinationOffset,
            0x18
        )
        XCTAssertTrue(
            OriginalMarketProviderSelectionComponentGate.accepts(componentLabel: 0)
        )
        XCTAssertTrue(
            OriginalMarketProviderSelectionComponentGate.accepts(componentLabel: 1)
        )
        XCTAssertFalse(
            OriginalMarketProviderSelectionComponentGate.accepts(componentLabel: 2)
        )

        let selected = OriginalMarketAccessRefresh.project(
            selectedLinearIndex: 1_000 + 3 + 4 * 228,
            mapBaseLinearIndex: 1_000,
            mapRowStride: 228,
            callbackInput: 0x2A,
            floodValue: 7
        )
        XCTAssertEqual(selected?.mapPoint, GridPoint(x: 3, y: 4))
        XCTAssertEqual(selected?.callbackInput, 0x2A)
        XCTAssertEqual(selected?.floodValue, 7)
        XCTAssertEqual(selected?.isReachable, true)

        let noFlood = OriginalMarketAccessRefresh.project(
            selectedLinearIndex: 1_000 + 227 + 2 * 228,
            mapBaseLinearIndex: 1_000,
            mapRowStride: 228,
            callbackInput: 0,
            floodValue: 0
        )
        XCTAssertEqual(noFlood?.mapPoint, GridPoint(x: 227, y: 2))
        XCTAssertEqual(noFlood?.isReachable, false)
        XCTAssertNil(
            OriginalMarketAccessRefresh.project(
                selectedLinearIndex: 999,
                mapBaseLinearIndex: 1_000,
                mapRowStride: 228,
                callbackInput: 0,
                floodValue: 1
            )
        )
        XCTAssertNil(
            OriginalMarketAccessRefresh.project(
                selectedLinearIndex: 1_000,
                mapBaseLinearIndex: 1_000,
                mapRowStride: 0,
                callbackInput: 0,
                floodValue: 1
            )
        )
    }

    func testOriginalMarketHelperAuxiliaryProjectsRecordOneFromMarketOrigin() {
        let auxiliary = Array(repeating: UInt8(0), count: 228 * 8)
            .enumerated()
            .map { UInt8($0.offset % 251) }
        let projected = OriginalMarketHelperAuxiliary.project(
            marketOrigin: GridPoint(x: 10, y: 3),
            helperRecordOffset: GridPoint(x: 2, y: -1),
            mapBaseLinearIndex: 4_000,
            mapRowStride: 228,
            auxiliaryValues: auxiliary
        )
        XCTAssertEqual(projected?.selectedLinearIndex, 4_000 + 12 + 2 * 228)
        XCTAssertEqual(projected?.helperRecordOffset, GridPoint(x: 2, y: -1))
        XCTAssertEqual(projected?.auxiliaryValue, auxiliary[12 + 2 * 228])

        XCTAssertNil(
            OriginalMarketHelperAuxiliary.project(
                marketOrigin: GridPoint(x: 0, y: 0),
                helperRecordOffset: GridPoint(x: 0, y: 0),
                mapBaseLinearIndex: 0,
                mapRowStride: 228,
                auxiliaryValues: []
            )
        )
        XCTAssertNil(
            OriginalMarketHelperAuxiliary.project(
                marketOrigin: GridPoint(x: 0, y: 0),
                helperRecordOffset: GridPoint(x: 0, y: 0),
                mapBaseLinearIndex: 0,
                mapRowStride: 0,
                auxiliaryValues: [0]
            )
        )
    }

    func testOriginalMarketProviderFillStatePreservesEmptyRecordPrecedenceAnd3200Threshold() {
        XCTAssertEqual(
            OriginalMarketProviderFillState.classify(records: []),
            .belowQuantityThreshold,
            "the executable returns 2 for a zero-length provider container"
        )
        XCTAssertEqual(
            OriginalMarketProviderFillState.classify(records: [
                OriginalMarketProviderRecord(rawField4: 0, rawField8: 0),
                OriginalMarketProviderRecord(rawField4: 19, rawField8: 4_000),
            ]),
            .hasEmptyRecord,
            "an all-zero record returns 0 before checking the sum"
        )
        XCTAssertEqual(
            OriginalMarketProviderFillState.classify(records: [
                OriginalMarketProviderRecord(rawField4: 19, rawField8: 3_199),
            ]),
            .belowQuantityThreshold
        )
        XCTAssertEqual(
            OriginalMarketProviderFillState.classify(records: [
                OriginalMarketProviderRecord(rawField4: 19, rawField8: 3_200),
            ]),
            .meetsQuantityThreshold
        )
    }

    func testOriginalMarketHouseInfoSlotMatchesRecoveredCommodityProjection() {
        XCTAssertEqual(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x1C), 0)
        XCTAssertEqual(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x13), 1)
        XCTAssertEqual(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x19), 2)
        XCTAssertEqual(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x18), 3)
        XCTAssertEqual(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x17), 4)
        XCTAssertEqual(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x16), 5)
        XCTAssertEqual(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x0D), 6)
        XCTAssertNil(OriginalMarketHouseInfoSlot.slot(forCommodityID: 0x1B))
    }

    func testOriginalMarketProviderSlotCatalogMatchesRecoveredPEShopTable() {
        XCTAssertEqual(
            OriginalMarketProviderSlotCatalog.entries,
            [
                .init(slotIndex: 0, shopBuildingID: 66, commodityID: 0x1C),
                .init(slotIndex: 1, shopBuildingID: 67, commodityID: 0x13),
                .init(slotIndex: 2, shopBuildingID: 70, commodityID: 0x0D),
                .init(slotIndex: 3, shopBuildingID: 65, commodityID: 0x19),
                .init(slotIndex: 4, shopBuildingID: 64, commodityID: 0x17),
                .init(slotIndex: 5, shopBuildingID: 68, commodityID: 0x16),
                .init(slotIndex: 6, shopBuildingID: 69, commodityID: 0x18),
            ]
        )
        XCTAssertEqual(
            OriginalMarketProviderSlotCatalog.entry(forShopBuildingID: 66)?.commodityID,
            0x1C
        )
        XCTAssertEqual(
            OriginalMarketProviderSlotCatalog.entry(forCommodityID: 0x18)?.shopBuildingID,
            69
        )
        XCTAssertEqual(
            OriginalMarketProviderSlotCatalog.entries.compactMap(\.placementCapacity),
            [800, 400, 400, 400, 400, 400, 400]
        )
        XCTAssertNil(OriginalMarketProviderSlotCatalog.entry(forShopBuildingID: 71))
        XCTAssertNil(OriginalMarketProviderSlotCatalog.entry(forCommodityID: 0x1B))
    }

    func testOriginalMarketPeddlerLinkStorageIsSeparateFromCommodityRecords() {
        XCTAssertEqual(
            OriginalMarketPeddlerLinkStorage.marketVTableAddress,
            0x007B6F3C
        )
        XCTAssertEqual(OriginalMarketPeddlerLinkStorage.accessorVTableOffset, 0x1E8)
        XCTAssertEqual(OriginalMarketPeddlerLinkStorage.accessorAddress, 0x00416B50)
        XCTAssertEqual(OriginalMarketPeddlerLinkStorage.attachedInfoOffset, 0xC8)
        XCTAssertEqual(
            OriginalMarketPeddlerLinkStorage.slotOffsets(forMarketType: 2),
            [0x2E, 0x6A]
        )
        XCTAssertEqual(
            OriginalMarketPeddlerLinkStorage.slotOffsets(forMarketType: 3),
            [0x2E, 0x6A, 0x6C]
        )
        XCTAssertNil(OriginalMarketPeddlerLinkStorage.slotOffsets(forMarketType: 1))
        XCTAssertEqual(
            (0...2).compactMap {
                OriginalMarketPeddlerLinkStorage.validatorAddress(forSlotOrdinal: $0)
            },
            [0x00429700, 0x00429780, 0x00429810]
        )
        XCTAssertNil(OriginalMarketPeddlerLinkStorage.validatorAddress(forSlotOrdinal: 3))
        XCTAssertEqual(OriginalMarketPeddlerLinkStorage.figureModelOffset, 0x12)
        XCTAssertEqual(OriginalMarketPeddlerLinkStorage.figureActiveOffset, 0x16)
        XCTAssertEqual(OriginalMarketPeddlerLinkStorage.figureParentMarketOffset, 0x62)
        XCTAssertEqual(OriginalMarketPeddlerLinkStorage.registrationAddress, 0x004272A0)
    }

    func testOriginalMarketPeddlerRegistrationPreservesSourceSlotOrder() {
        let storage = OriginalMarketPeddlerLinkStorage.self
        XCTAssertEqual(
            storage.registrationSlot(
                marketType: 1,
                primaryLink: 12,
                attachedInfoSecondLink: 14,
                attachedInfoThirdLink: 16,
                primaryFigureIsActive: true,
                thirdFigureIsActive: true
            ),
            .primaryMarket
        )
        XCTAssertEqual(
            storage.registrationSlot(
                marketType: 2,
                primaryLink: 0,
                attachedInfoSecondLink: 14,
                attachedInfoThirdLink: 16,
                primaryFigureIsActive: true,
                thirdFigureIsActive: true
            ),
            .primaryMarket
        )
        XCTAssertEqual(
            storage.registrationSlot(
                marketType: 2,
                primaryLink: 12,
                attachedInfoSecondLink: 0,
                attachedInfoThirdLink: 16,
                primaryFigureIsActive: true,
                thirdFigureIsActive: true
            ),
            .attachedInfoSecond
        )
        XCTAssertEqual(
            storage.registrationSlot(
                marketType: 3,
                primaryLink: 12,
                attachedInfoSecondLink: 14,
                attachedInfoThirdLink: 0,
                primaryFigureIsActive: true,
                thirdFigureIsActive: true
            ),
            .attachedInfoThird
        )
        XCTAssertEqual(
            storage.registrationSlot(
                marketType: 3,
                primaryLink: 12,
                attachedInfoSecondLink: 14,
                attachedInfoThirdLink: 16,
                primaryFigureIsActive: false,
                thirdFigureIsActive: true
            ),
            .primaryMarket
        )
        XCTAssertEqual(
            storage.registrationSlot(
                marketType: 3,
                primaryLink: 12,
                attachedInfoSecondLink: 14,
                attachedInfoThirdLink: 16,
                primaryFigureIsActive: true,
                thirdFigureIsActive: false
            ),
            .attachedInfoThird
        )
        XCTAssertEqual(
            storage.registrationSlot(
                marketType: 3,
                primaryLink: 12,
                attachedInfoSecondLink: 14,
                attachedInfoThirdLink: 16,
                primaryFigureIsActive: true,
                thirdFigureIsActive: true
            ),
            .attachedInfoSecond
        )
    }

    func testOriginalMarketPeddlerValidatorsPreserveEmptyAndClearBranches() {
        let storage = OriginalMarketPeddlerLinkStorage.self
        let valid = storage.validateLink(
            slot: .primaryMarket,
            storedLink: 12,
            figureExists: true,
            figureIsActive: true,
            figureModelID: 23,
            acceptedModelIDs: (23, 24),
            figureParentMarketID: 9,
            marketRegistryID: 9
        )
        XCTAssertEqual(valid, .init(isValid: true, clearsStoredLink: false))

        let emptyPrimary = storage.validateLink(
            slot: .primaryMarket,
            storedLink: 0,
            figureExists: false,
            figureIsActive: false,
            figureModelID: 0,
            acceptedModelIDs: (23, 24),
            figureParentMarketID: 0,
            marketRegistryID: 9
        )
        XCTAssertEqual(emptyPrimary, .init(isValid: false, clearsStoredLink: false))

        let emptySecond = storage.validateLink(
            slot: .attachedInfoSecond,
            storedLink: -1,
            figureExists: false,
            figureIsActive: false,
            figureModelID: 0,
            acceptedModelIDs: (23, 24),
            figureParentMarketID: 0,
            marketRegistryID: 9
        )
        XCTAssertEqual(emptySecond, .init(isValid: false, clearsStoredLink: false))

        let staleSecond = storage.validateLink(
            slot: .attachedInfoSecond,
            storedLink: 14,
            figureExists: true,
            figureIsActive: false,
            figureModelID: 23,
            acceptedModelIDs: (23, 24),
            figureParentMarketID: 9,
            marketRegistryID: 9
        )
        XCTAssertEqual(staleSecond, .init(isValid: false, clearsStoredLink: true))

        let wrongModelThird = storage.validateLink(
            slot: .attachedInfoThird,
            storedLink: 16,
            figureExists: true,
            figureIsActive: true,
            figureModelID: 25,
            acceptedModelIDs: (23, 24),
            figureParentMarketID: 9,
            marketRegistryID: 9
        )
        XCTAssertEqual(wrongModelThird, .init(isValid: false, clearsStoredLink: true))
    }

    func testOriginalMarketPeddlerMembershipMatcherPreservesRawTypeBranches() {
        let matcher = OriginalMarketPeddlerLinkStorage.registeredFigureMatchRaw

        XCTAssertEqual(matcher(1, 12, 12, 14, 16), 1)
        XCTAssertEqual(matcher(1, 13, 12, 13, 16), 0)
        XCTAssertEqual(matcher(2, 14, 12, 14, 16), 1)
        XCTAssertEqual(matcher(2, 16, 12, 14, 16), 0)
        XCTAssertEqual(matcher(3, 16, 12, 14, 16), 1)
        XCTAssertEqual(matcher(3, 18, 12, 14, 16), 0)
        XCTAssertEqual(matcher(99, 12, 12, 14, 16), 0)
        XCTAssertEqual(matcher(0x100, 12, 12, 14, 16), 0x100)
    }

    func testOriginalMarketPeddlerAllocationTailWritesOnlyAfterLiveFigure() {
        let tail = OriginalMarketPeddlerAllocationTail.self
        let failed = tail.resolve(
            allocationSucceeded: false,
            marketRegistryID: 9,
            oldMarketDirectionByte: 3
        )
        XCTAssertEqual(failed, .init(
            allocationSucceeded: false,
            figureActiveByte: nil,
            figureParentMarketID: nil,
            marketDirectionByte: nil,
            figureDirectionByte: nil,
            entersRoamInitialization: false
        ))

        let succeeded = tail.resolve(
            allocationSucceeded: true,
            marketRegistryID: 9,
            oldMarketDirectionByte: 3
        )
        XCTAssertEqual(succeeded.figureActiveByte, 1)
        XCTAssertEqual(succeeded.figureParentMarketID, 9)
        XCTAssertEqual(succeeded.marketDirectionByte, 7)
        XCTAssertEqual(succeeded.figureDirectionByte, 7)
        XCTAssertTrue(succeeded.entersRoamInitialization)

        let signedByte = tail.resolve(
            allocationSucceeded: true,
            marketRegistryID: 0xFFFF,
            oldMarketDirectionByte: 0xFF
        )
        XCTAssertEqual(signedByte.figureParentMarketID, -1)
        XCTAssertEqual(signedByte.marketDirectionByte, 3)
        XCTAssertEqual(signedByte.figureDirectionByte, 3)
    }

    func testOriginalMarketPeddlerWorkerRatioAndStockGateMatchRecoveredArithmetic() {
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerWorkerPercent(
                rawEmptyChildWorkerUnits: 4,
                filledShopEmployeeUnits: 4
            ),
            100
        )
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerWorkerPercent(
                rawEmptyChildWorkerUnits: 3,
                filledShopEmployeeUnits: 4
            ),
            75
        )
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerWorkerPercent(
                rawEmptyChildWorkerUnits: 1,
                filledShopEmployeeUnits: 6
            ),
            16,
            "FUN_00408BA0 truncates the raw percentage toward zero"
        )
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerSpawnGate(
                rawEmptyChildWorkerUnits: 4,
                filledShopEmployeeUnits: 4,
                hasMarketStock: true
            )?.threshold,
            2
        )
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerSpawnGate(
                rawEmptyChildWorkerUnits: 4,
                filledShopEmployeeUnits: 4,
                hasMarketStock: false
            )?.admits,
            false
        )
        XCTAssertEqual(
            OriginalMarketCatalog.peddlerWorkerPercent(
                rawEmptyChildWorkerUnits: 1,
                filledShopEmployeeUnits: 0
            ),
            0
        )
        XCTAssertNil(
            OriginalMarketCatalog.peddlerSpawnGate(
                rawEmptyChildWorkerUnits: Int.max,
                filledShopEmployeeUnits: 1,
                hasMarketStock: true
            )
        )
    }

    func testOriginalDirectionalAccessFloodUsesCurrentLayersAndCardinalOrder() {
        let passable = Array(repeating: OriginalDirectionalAccessFlood.unweightedPassMask, count: 9)
        XCTAssertEqual(
            OriginalDirectionalAccessFlood.build(
                width: 3,
                height: 3,
                seed: GridPoint(x: 1, y: 1),
                passMask: OriginalDirectionalAccessFlood.unweightedPassMask,
                northLayer: passable,
                eastLayer: passable,
                southLayer: passable,
                westLayer: passable
            ),
            [3, 2, 3, 2, 1, 2, 3, 2, 3]
        )

        var eastBlocked = Array(repeating: OriginalDirectionalAccessFlood.unweightedPassMask, count: 2)
        eastBlocked[0] = 0
        XCTAssertEqual(
            OriginalDirectionalAccessFlood.build(
                width: 2,
                height: 1,
                seed: GridPoint(x: 0, y: 0),
                passMask: OriginalDirectionalAccessFlood.unweightedPassMask,
                northLayer: eastBlocked,
                eastLayer: eastBlocked,
                southLayer: eastBlocked,
                westLayer: eastBlocked
            )?[1],
            0,
            "east checks the current cell's layer"
        )
        eastBlocked[0] = OriginalDirectionalAccessFlood.unweightedPassMask
        eastBlocked[1] = 0
        XCTAssertEqual(
            OriginalDirectionalAccessFlood.build(
                width: 2,
                height: 1,
                seed: GridPoint(x: 0, y: 0),
                passMask: OriginalDirectionalAccessFlood.unweightedPassMask,
                northLayer: eastBlocked,
                eastLayer: eastBlocked,
                southLayer: eastBlocked,
                westLayer: eastBlocked
            )?[1],
            2,
            "the current cell's open east layer admits the candidate"
        )
        XCTAssertNil(
            OriginalDirectionalAccessFlood.build(
                width: 3,
                height: 3,
                seed: GridPoint(x: 3, y: 1),
                passMask: OriginalDirectionalAccessFlood.unweightedPassMask,
                northLayer: passable,
                eastLayer: passable,
                southLayer: passable,
                westLayer: passable
            )
        )
    }

    func testOriginalMarketAccessFloodUsesMixedNorthAndCurrentLayerIndexing() {
        var north = Array(repeating: OriginalMarketAccessFlood.passMask, count: 2)
        north[0] = 0
        XCTAssertEqual(
            OriginalMarketAccessFlood.build(
                width: 1,
                height: 2,
                seed: GridPoint(x: 0, y: 1),
                northLayer: north,
                eastLayer: north,
                southLayer: north,
                westLayer: north
            )?[0],
            0,
            "market north admission reads the north candidate cell"
        )

        var east = Array(repeating: OriginalMarketAccessFlood.passMask, count: 2)
        east[1] = 0
        XCTAssertEqual(
            OriginalMarketAccessFlood.build(
                width: 2,
                height: 1,
                seed: GridPoint(x: 0, y: 0),
                northLayer: east,
                eastLayer: east,
                southLayer: east,
                westLayer: east
            )?[1],
            2,
            "market east admission reads the current cell"
        )
    }

    func testOriginalDirectionalLayerViewsPreservePaddedCacheOffsets() {
        XCTAssertEqual(OriginalDirectionalLayerViews.centralAddress, 0x013789C0)
        XCTAssertEqual(OriginalDirectionalLayerViews.storageRowStride, 228)
        XCTAssertEqual(OriginalDirectionalLayerViews.storageCellCount, 228 * 228)
        XCTAssertEqual(OriginalDirectionalLayerViews.storageDWordCount, 0x6588)
        XCTAssertEqual(OriginalDirectionalLayerViews.northAddress, 0x013787F8)
        XCTAssertEqual(OriginalDirectionalLayerViews.eastAddress, 0x013789C2)
        XCTAssertEqual(OriginalDirectionalLayerViews.southAddress, 0x01378B88)
        XCTAssertEqual(OriginalDirectionalLayerViews.westAddress, 0x013789BE)

        let centralIndex = 228 + 7
        let indices = OriginalDirectionalLayerViews.cellIndices(centralIndex: centralIndex)
        XCTAssertEqual(indices.north, centralIndex - 228)
        XCTAssertEqual(indices.east, centralIndex + 1)
        XCTAssertEqual(indices.south, centralIndex + 228)
        XCTAssertEqual(indices.west, centralIndex - 1)

        var storage = Array(repeating: UInt16(0), count: 228 * 3)
        storage[indices.north] = 11
        storage[indices.east] = 22
        storage[indices.south] = 33
        storage[indices.west] = 44
        XCTAssertEqual(
            OriginalDirectionalLayerViews.values(
                from: storage,
                centralIndex: centralIndex
            )?.north,
            11
        )
        XCTAssertEqual(
            OriginalDirectionalLayerViews.values(
                from: storage,
                centralIndex: centralIndex
            )?.east,
            22
        )
        XCTAssertEqual(
            OriginalDirectionalLayerViews.values(
                from: storage,
                centralIndex: centralIndex
            )?.south,
            33
        )
        XCTAssertEqual(
            OriginalDirectionalLayerViews.values(
                from: storage,
                centralIndex: centralIndex
            )?.west,
            44
        )
        XCTAssertNil(
            OriginalDirectionalLayerViews.values(
                from: Array(repeating: UInt16(0), count: 10),
                centralIndex: 0
            )
        )
    }

    func testOriginalDirectionalLayerViewsProjectOnlyInRectangleAliases() {
        let width = 3
        let height = 3
        let central = (0..<(width * height)).map(UInt16.init)
        let views = OriginalDirectionalLayerViews.activeRectangleValues(
            from: central,
            width: width,
            height: height,
            baseLinearOffset: 228 + 2
        )

        XCTAssertEqual(views?.north[4], 1)
        XCTAssertEqual(views?.east[4], 5)
        XCTAssertEqual(views?.south[4], 7)
        XCTAssertEqual(views?.west[4], 3)
        XCTAssertNil(views?.north[0], "north edge has no in-rectangle source")
        XCTAssertNil(views?.west[0], "west edge has no in-rectangle source")
        XCTAssertNil(views?.east[2], "east edge has no in-rectangle source")
        XCTAssertNil(views?.south[6], "south edge has no in-rectangle source")

        XCTAssertNil(
            OriginalDirectionalLayerViews.activeRectangleValues(
                from: [1, 2],
                width: width,
                height: height,
                baseLinearOffset: 0
            )
        )
    }

    func testOriginalMapCellInvalidationPreservesEightNeighborFanoutAndMasks() {
        XCTAssertEqual(OriginalMapCellInvalidation.fanoutAddress, 0x004ED700)
        XCTAssertEqual(OriginalMapCellInvalidation.writerAddress, 0x004ED840)
        XCTAssertEqual(OriginalMapCellInvalidation.routingCacheAddress, 0x013789C0)
        XCTAssertEqual(OriginalMapCellInvalidation.routingCacheBlockedValue, 2)
        XCTAssertEqual(OriginalMapCellInvalidation.terrainObjectORMask, 0x04000100)
        XCTAssertEqual(OriginalMapCellInvalidation.eventByteIncrement, 1)
        XCTAssertEqual(OriginalMapCellInvalidation.mapRowStride, 228)
        XCTAssertEqual(
            OriginalMapCellInvalidation.neighboringCellOffsets,
            [-228, 1, 228, -1, -227, 229, 227, -229]
        )

        let centralIndex = 228 * 4 + 9
        XCTAssertEqual(
            OriginalMapCellInvalidation.neighboringCellIndices(centralIndex: centralIndex),
            [centralIndex - 228, centralIndex + 1, centralIndex + 228, centralIndex - 1,
             centralIndex - 227, centralIndex + 229, centralIndex + 227, centralIndex - 229]
        )
        XCTAssertEqual(
            OriginalMapCellInvalidation.terrainObjectWord(afterInvalidation: 0x0000_0004),
            0x0400_0104
        )
    }

    func testOriginalDirectionalAccessFloodPreservesModeSpecificMasks() {
        var primaryOnly = Array(repeating: UInt16(0), count: 2)
        primaryOnly[0] = OriginalDirectionalAccessFlood.unweightedPassMask

        XCTAssertEqual(
            OriginalDirectionalAccessFlood.build(
                width: 2,
                height: 1,
                seed: GridPoint(x: 0, y: 0),
                passMask: OriginalDirectionalAccessFlood.unweightedPassMask,
                northLayer: primaryOnly,
                eastLayer: primaryOnly,
                southLayer: primaryOnly,
                westLayer: primaryOnly
            )?[1],
            2
        )
        XCTAssertEqual(
            OriginalDirectionalAccessFlood.build(
                width: 2,
                height: 1,
                seed: GridPoint(x: 0, y: 0),
                passMask: OriginalDirectionalAccessFlood.weightedPassMask,
                northLayer: primaryOnly,
                eastLayer: primaryOnly,
                southLayer: primaryOnly,
                westLayer: primaryOnly
            )?[1],
            2,
            "0x0B0C contains the mode-zero 0x010C admission bits"
        )

        primaryOnly[0] = 0x0800
        XCTAssertEqual(
            OriginalDirectionalAccessFlood.build(
                width: 2,
                height: 1,
                seed: GridPoint(x: 0, y: 0),
                passMask: OriginalDirectionalAccessFlood.unweightedPassMask,
                northLayer: primaryOnly,
                eastLayer: primaryOnly,
                southLayer: primaryOnly,
                westLayer: primaryOnly
            )?[1],
            0,
            "mode zero must reject a bit added only by 0x0B0C"
        )
        XCTAssertEqual(
            OriginalDirectionalAccessFlood.build(
                width: 2,
                height: 1,
                seed: GridPoint(x: 0, y: 0),
                passMask: OriginalDirectionalAccessFlood.weightedPassMask,
                northLayer: primaryOnly,
                eastLayer: primaryOnly,
                southLayer: primaryOnly,
                westLayer: primaryOnly
            )?[1],
            2
        )
    }

    func testOriginalMarketChildAdmissionMatchesCStallSelectorGate() {
        XCTAssertEqual(
            OriginalMarketChildAdmission.cStallAdmits(selector: -2, shopBuildingID: 62),
            true
        )
        XCTAssertEqual(
            OriginalMarketChildAdmission.cStallAdmits(selector: -2, shopBuildingID: 70),
            true
        )
        XCTAssertEqual(
            OriginalMarketChildAdmission.cStallAdmits(selector: -1, shopBuildingID: 62),
            true
        )
        for shopBuildingID in 64...70 {
            XCTAssertEqual(
                OriginalMarketChildAdmission.cStallAdmits(
                    selector: -1,
                    shopBuildingID: shopBuildingID
                ),
                false,
                "filled shop \(shopBuildingID) must fail selector -1"
            )
        }
        XCTAssertEqual(
            OriginalMarketChildAdmission.cStallAdmits(selector: 66, shopBuildingID: 66),
            true
        )
        XCTAssertEqual(
            OriginalMarketChildAdmission.cStallAdmits(selector: 66, shopBuildingID: 67),
            false
        )
        XCTAssertNil(
            OriginalMarketChildAdmission.cStallAdmits(selector: -1, shopBuildingID: 59)
        )
    }

    func testOriginalMarketChildWorkerValueReadsSignedCStallField() {
        XCTAssertEqual(OriginalMarketChildWorkerValue.vTableOffset, 0x1B8)
        XCTAssertEqual(OriginalMarketChildWorkerValue.sourceAddress, 0x00416B10)
        XCTAssertEqual(
            OriginalMarketChildWorkerValue.value(shopBuildingID: 62, rawField44: 0x7FFF),
            0x7FFF
        )
        XCTAssertEqual(
            OriginalMarketChildWorkerValue.value(shopBuildingID: 70, rawField44: 0xFFFF),
            -1,
            "the PE reads cStall +0x44 as a signed 16-bit value"
        )
        XCTAssertNil(
            OriginalMarketChildWorkerValue.value(shopBuildingID: 59, rawField44: 123),
            "market objects do not use the cStall +0x1B8 implementation"
        )
    }

    func testOriginalMarketActiveCommodityCountMatchesSixSlotDinnersScan() {
        XCTAssertEqual(OriginalMarketActiveCommodityCount.sourceAddress, 0x00544340)
        XCTAssertEqual(OriginalMarketActiveCommodityCount.maximumChildSlots, 6)

        let entries = [
            OriginalMarketActiveCommodityEntry(isActive: true, commodityID: 0x1C),
            OriginalMarketActiveCommodityEntry(isActive: false, commodityID: 0x1C),
            OriginalMarketActiveCommodityEntry(isActive: true, commodityID: 0x13),
            OriginalMarketActiveCommodityEntry(isActive: true, commodityID: 0x1C)
        ]
        XCTAssertEqual(
            OriginalMarketActiveCommodityCount.count(entries: entries, commodityID: 0x1C),
            2
        )
        XCTAssertEqual(
            OriginalMarketActiveCommodityCount.count(entries: entries, commodityID: 0x13),
            1
        )
        XCTAssertEqual(
            OriginalMarketActiveCommodityCount.count(entries: [], commodityID: 0x1C),
            0
        )
        XCTAssertNil(
            OriginalMarketActiveCommodityCount.count(
                entries: Array(
                    repeating: .init(isActive: true, commodityID: 0x1C),
                    count: 7
                ),
                commodityID: 0x1C
            )
        )
    }

    func testOriginalMarketQualityBlendMatchesRecoveredDinnersCartArithmetic() {
        let emptyMarket = OriginalMarketQualityBlend.blend(
            oldQuality: 0,
            oldStock: 0,
            acceptedAmount: 100,
            incomingTypeCount: 3
        )
        XCTAssertEqual(emptyMarket?.incomingQuality, 60)
        XCTAssertEqual(emptyMarket?.blendedQuality, 60)

        let equalStock = OriginalMarketQualityBlend.blend(
            oldQuality: 50,
            oldStock: 100,
            acceptedAmount: 100,
            incomingTypeCount: 5
        )
        XCTAssertEqual(equalStock?.blendedQuality, 75)

        let exactHalf = OriginalMarketQualityBlend.blend(
            oldQuality: 1,
            oldStock: 1,
            acceptedAmount: 1,
            incomingTypeCount: 1
        )
        XCTAssertEqual(exactHalf?.blendedQuality, 11)

        XCTAssertNil(
            OriginalMarketQualityBlend.blend(
                oldQuality: 0,
                oldStock: 0,
                acceptedAmount: 0,
                incomingTypeCount: 1
            )
        )
        XCTAssertNil(
            OriginalMarketQualityBlend.blend(
                oldQuality: 0,
                oldStock: 0,
                acceptedAmount: 1,
                incomingTypeCount: 256
            )
        )
    }

    func testOriginalMarketHouseQualityBlendMatchesRecoveredFiveRatioTable() {
        XCTAssertEqual(
            OriginalMarketHouseQualityBlend.resolve(
                currentQuality: 70,
                marketQuality: 45,
                existingStock: 100,
                deliveredAmount: 20
            ),
            63
        )
        XCTAssertEqual(
            OriginalMarketHouseQualityBlend.resolve(
                currentQuality: 100,
                marketQuality: 0,
                existingStock: 762_603,
                deliveredAmount: 251_659
            ),
            75
        )
        XCTAssertEqual(
            OriginalMarketHouseQualityBlend.resolve(
                currentQuality: 20,
                marketQuality: 80,
                existingStock: 10,
                deliveredAmount: 1
            ),
            80
        )
        XCTAssertNil(
            OriginalMarketHouseQualityBlend.resolve(
                currentQuality: 256,
                marketQuality: 40,
                existingStock: 10,
                deliveredAmount: 1
            )
        )
    }

    func testOriginalMarketLayoutCatalogMatchesRecoveredActiveBays() throws {
        XCTAssertEqual(OriginalMarketLayoutCatalog.maximumProviderRecordCount, 6)
        let common = try XCTUnwrap(
            OriginalMarketLayoutCatalog.descriptor(forMarketBuildingID: 59)
        )
        XCTAssertEqual(common.marketBuildingID, 59)
        XCTAssertEqual(common.helperEntryCount, 28)
        XCTAssertEqual(common.layoutBankAddress, 0x008574A8)
        XCTAssertEqual(common.activeLayoutEntryIndices, [0, 2, 20, 22])
        XCTAssertEqual(common.layoutEntries.count, 28)
        XCTAssertEqual(
            common.layoutEntries.filter(\.isActiveBay).map(\.index),
            common.activeLayoutEntryIndices
        )
        XCTAssertEqual(common.layoutEntry(at: 20), .init(index: 20, x: 0, y: 5, kind: 2, aux: 1))

        let grand = try XCTUnwrap(
            OriginalMarketLayoutCatalog.descriptor(forMarketBuildingID: 60)
        )
        XCTAssertEqual(grand.marketBuildingID, 60)
        XCTAssertEqual(grand.helperEntryCount, 42)
        XCTAssertEqual(grand.layoutBankAddress, 0x00857828)
        XCTAssertEqual(grand.activeLayoutEntryIndices, [0, 2, 4, 30, 32, 34])
        XCTAssertEqual(grand.layoutEntries.count, 42)
        XCTAssertEqual(
            grand.layoutEntries.filter(\.isActiveBay).map(\.index),
            grand.activeLayoutEntryIndices
        )
        XCTAssertEqual(grand.layoutEntry(at: 14), .init(index: 14, x: 2, y: 2, kind: 4, aux: 130))
        XCTAssertEqual(
            OriginalMarketLayoutCatalog.common.activeBayCount,
            4
        )
        XCTAssertEqual(
            OriginalMarketLayoutCatalog.grand.activeBayCount,
            6
        )
        XCTAssertEqual(OriginalMarketLayoutCatalog.common.runtimeSlot(forLayoutEntryIndex: 20), 2)
        XCTAssertNil(OriginalMarketLayoutCatalog.common.runtimeSlot(forLayoutEntryIndex: 1))
        XCTAssertNil(OriginalMarketLayoutCatalog.descriptor(forMarketBuildingID: 61))
    }

    func testOriginalMarketRuntimeShopBindingPreservesPlaceholderSlotsAndRawCapacity() throws {
        let common = try XCTUnwrap(
            OriginalMarketLayoutCatalog.descriptor(forMarketBuildingID: 59)
        )
        let bindings = try XCTUnwrap(
            OriginalMarketRuntimeShopBinding.bind(
                marketRegistryID: 900,
                layout: common,
                shopBuildingIDs: [62, 66, 67, 70],
                shopRegistryIDs: [100, 101, 102, 103]
            )
        )
        XCTAssertEqual(bindings.map(\.runtimeSlot), [0, 1, 2, 3])
        XCTAssertEqual(bindings.map(\.layoutEntryIndex), [0, 2, 20, 22])
        XCTAssertEqual(bindings.map(\.marketRegistryID), [900, 900, 900, 900])
        XCTAssertEqual(bindings.map(\.shopRegistryID), [100, 101, 102, 103])
        XCTAssertEqual(bindings.map(\.rawCapacityDelta), [nil, 800, 400, 400])

        XCTAssertEqual(
            OriginalMarketRuntimeShopBinding.rawQuantityAfterRemoval(
                currentRawQuantity: 900,
                shopBuildingID: 66
            ),
            100
        )
        XCTAssertEqual(
            OriginalMarketRuntimeShopBinding.rawQuantityAfterRemoval(
                currentRawQuantity: 200,
                shopBuildingID: 67
            ),
            0
        )
        XCTAssertNil(
            OriginalMarketRuntimeShopBinding.rawQuantityAfterRemoval(
                currentRawQuantity: 10,
                shopBuildingID: 62
            )
        )
    }

    func testOriginalMarketRuntimeShopBindingRejectsUnboundOrMalformedInputs() throws {
        let grand = try XCTUnwrap(
            OriginalMarketLayoutCatalog.descriptor(forMarketBuildingID: 60)
        )
        XCTAssertNil(
            OriginalMarketRuntimeShopBinding.bind(
                marketRegistryID: 1,
                layout: grand,
                shopBuildingIDs: [62],
                shopRegistryIDs: [1]
            )
        )
        XCTAssertNil(
            OriginalMarketRuntimeShopBinding.bind(
                marketRegistryID: 1,
                layout: grand,
                shopBuildingIDs: [62, 64, 65, 66, 67, 71],
                shopRegistryIDs: [1, 2, 3, 4, 5, 6]
            )
        )
        XCTAssertNil(
            OriginalMarketRuntimeShopBinding.rawQuantityAfterRemoval(
                currentRawQuantity: -1,
                shopBuildingID: 66
            )
        )
    }

    func testOriginalMarketShopRemovalBoundaryPreservesSourceEarlyReturns() throws {
        let admitted = try XCTUnwrap(
            OriginalMarketShopRemovalBoundary.remove(
                marketStatusByte: 0,
                parentLinkPresent: true,
                childBayOrdinal: 2,
                currentRawQuantity: 450,
                shopBuildingID: 66
            )
        )
        XCTAssertTrue(admitted.admitted)
        XCTAssertEqual(admitted.rawQuantityAfterRemoval, 0)
        XCTAssertTrue(admitted.recreatesEmptyShop)

        for status in [2, 6] {
            let result = try XCTUnwrap(
                OriginalMarketShopRemovalBoundary.remove(
                    marketStatusByte: status,
                    parentLinkPresent: true,
                    childBayOrdinal: 0,
                    currentRawQuantity: 450,
                    shopBuildingID: 66
                )
            )
            XCTAssertFalse(result.admitted)
            XCTAssertNil(result.rawQuantityAfterRemoval)
            XCTAssertFalse(result.recreatesEmptyShop)
        }

        let missingParent = try XCTUnwrap(
            OriginalMarketShopRemovalBoundary.remove(
                marketStatusByte: 0,
                parentLinkPresent: false,
                childBayOrdinal: 0,
                currentRawQuantity: 900,
                shopBuildingID: 67
            )
        )
        XCTAssertFalse(missingParent.admitted)

        let negativeOrdinal = try XCTUnwrap(
            OriginalMarketShopRemovalBoundary.remove(
                marketStatusByte: 0,
                parentLinkPresent: true,
                childBayOrdinal: -1,
                currentRawQuantity: 900,
                shopBuildingID: 67
            )
        )
        XCTAssertFalse(negativeOrdinal.admitted)

        XCTAssertNil(
            OriginalMarketShopRemovalBoundary.remove(
                marketStatusByte: 0,
                parentLinkPresent: true,
                childBayOrdinal: 0,
                currentRawQuantity: 900,
                shopBuildingID: 62
            )
        )
    }

    func testOriginalMarketPeddlerAvailabilityBoundaryPreservesSourceThresholds() {
        XCTAssertFalse(
            OriginalMarketPeddlerAvailabilityBoundary.admitsNextPeddler(
                parentLinkPresent: false,
                commodityID: OriginalMarketPeddlerAvailabilityBoundary.dinnersCommodityID,
                activeFigureCount: 0
            )
        )
        XCTAssertTrue(
            OriginalMarketPeddlerAvailabilityBoundary.admitsNextPeddler(
                parentLinkPresent: true,
                commodityID: OriginalMarketPeddlerAvailabilityBoundary.dinnersCommodityID,
                activeFigureCount: 399
            )
        )
        XCTAssertFalse(
            OriginalMarketPeddlerAvailabilityBoundary.admitsNextPeddler(
                parentLinkPresent: true,
                commodityID: OriginalMarketPeddlerAvailabilityBoundary.dinnersCommodityID,
                activeFigureCount: 400
            )
        )
        XCTAssertTrue(
            OriginalMarketPeddlerAvailabilityBoundary.admitsNextPeddler(
                parentLinkPresent: true,
                commodityID: 0x13,
                activeFigureCount: 199
            )
        )
        XCTAssertFalse(
            OriginalMarketPeddlerAvailabilityBoundary.admitsNextPeddler(
                parentLinkPresent: true,
                commodityID: 0x13,
                activeFigureCount: 200
            )
        )
    }

    func testOriginalMarketPeddlerSpawnPlacementPreservesCacheQuotientAndResidual() throws {
        let placement = try XCTUnwrap(
            OriginalMarketPeddlerSpawnPlacementBoundary.initialize(
                mapCacheAddress: 10_000 + 3 * 0xE4 + 17,
                mapCacheBaseAddress: 10_000,
                headingValue: 0xFFFF
            )
        )
        XCTAssertEqual(placement.mapRow, 3)
        XCTAssertEqual(placement.mapColumnResidual, 17)
        XCTAssertEqual(placement.headingValue, -1)
        XCTAssertTrue(placement.hasHeading)

        let negative = try XCTUnwrap(
            OriginalMarketPeddlerSpawnPlacementBoundary.initialize(
                mapCacheAddress: 10_000 - 0xE4 - 7,
                mapCacheBaseAddress: 10_000,
                headingValue: 0
            )
        )
        XCTAssertEqual(negative.mapRow, -1)
        XCTAssertEqual(negative.mapColumnResidual, -7)
        XCTAssertFalse(negative.hasHeading)
    }

    func testOriginalMarketCreationBoundaryKeepsMapLoadFailClosed() {
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.creatingAddress,
            0x0042D540
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.factoryAddress,
            0x0042D360
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.classDispatchAddress,
            0x0051C660
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.marketPredicateAddress,
            0x005D36E0
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.marketFactoryAddress,
            0x005D3580
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.marketConstructorAddress,
            0x00543450
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.tradeAndMarketPredicateModelIDs,
            [0x35, 0x36, 0x38, 0x3A, 0x3B, 0x3C]
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.initializerAddress,
            0x005428B0
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.wrapperAddress,
            0x00544220
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.eventMethodAddress,
            0x005451A0
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.marketVTableAddress,
            0x007B6F3C
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.eventMethodVTableByteOffset,
            0
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.eventMethodPointerFileOffset,
            0x003B703C
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.initializerDirectCallerAddresses,
            [0x00544220]
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.wrapperDirectCallerAddresses,
            [0x005451A0]
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.commonMarketBuildingID,
            59
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.grandMarketBuildingID,
            60
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.emptyShopBuildingID,
            62
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.generatedMarketAreaBuildingID,
            71
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.parentChildRegistrySlotsOffset,
            0x15C
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.childParentRegistryOffset,
            0x154
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.childBayOrdinalOffset,
            0x150
        )
        XCTAssertEqual(
            OriginalMarketCreationBoundaryCatalog.childPlacementValueOffset,
            0xA0
        )
        XCTAssertTrue(
            OriginalMarketCreationBoundaryCatalog.createsPlaceholderChildren(
                explicitCreation: true
            )
        )
        XCTAssertFalse(
            OriginalMarketCreationBoundaryCatalog.createsPlaceholderChildren(
                explicitCreation: false
            )
        )
        XCTAssertFalse(
            OriginalMarketCreationBoundaryCatalog.postLoadSequenceContainsInitializer
        )
    }

    func testOriginalResidentialRequirementTableMatchesRecoveredPEData() {
        XCTAssertEqual(
            (1...5).compactMap(OriginalResidentialRequirementTable.commodityID),
            [0x13, 0x19, 0x0D, 0x18, 0x16]
        )
        XCTAssertNil(OriginalResidentialRequirementTable.commodityID(forRequirementIndex: 0))

        XCTAssertEqual(
            (2...10).map { buildingID in
                (0..<4).map { requirementIndex in
                    OriginalResidentialRequirementTable.threshold(
                        buildingID: buildingID,
                        requirementIndex: requirementIndex
                    )!
                }
            },
            [
                [2, 0, 0, 0],
                [5, 0, 0, 0],
                [7, 2, 0, 0],
                [10, 2, 0, 0],
                [12, 2, 0, 0],
                [15, 2, 0, 0],
                [20, 2, 2, 0],
                [20, 2, 3, 0],
                [20, 2, 3, 2],
            ]
        )
        XCTAssertEqual(
            (11...17).map { buildingID in
                (0..<6).map { requirementIndex in
                    OriginalResidentialRequirementTable.threshold(
                        buildingID: buildingID,
                        requirementIndex: requirementIndex
                    )!
                }
            },
            [
                [1, 2, 2, 0, 0, 0],
                [1, 2, 2, 0, 0, 0],
                [1, 2, 2, 0, 0, 0],
                [2, 2, 2, 0, 0, 0],
                [4, 2, 2, 0, 0, 2],
                [5, 2, 2, 0, 2, 2],
                [5, 2, 2, 2, 2, 2],
            ]
        )
        XCTAssertNil(OriginalResidentialRequirementTable.threshold(buildingID: 18, requirementIndex: 0))
        XCTAssertNil(OriginalResidentialRequirementTable.threshold(buildingID: 13, requirementIndex: 6))
    }

    func testOriginalEliteHouseStockConsumptionMatchesRecoveredPassOrderAndDivision() throws {
        let source = try GameDataSource.openDefault()
        let models = try OriginalEconomyModels(source: source)
        // Native house level 14 projects to executable residential building 17.
        let model = try XCTUnwrap(models.buildings[houseLevelID: 14])

        XCTAssertEqual(
            OriginalEliteHouseStockConsumption.modelFieldIndexByPass,
            [12, 9, 10, 11, 13, 13, 17]
        )
        XCTAssertEqual(
            OriginalEliteHouseStockConsumption.houseInfoSlotByPass,
            [3, 1, 2, 6, 4, 5, 0]
        )

        let result = try XCTUnwrap(
            OriginalEliteHouseStockConsumption.consume(
                buildingID: 17,
                model: model,
                residentCount: 20,
                stockByHouseInfoSlot: [20, 5, 9, 7, 3, 8, 7]
            )
        )
        XCTAssertEqual(result.selectedAmountByPass, [1, 1, 2, 1, 0, 2, 12])
        XCTAssertEqual(result.deficitByPass, Array(repeating: 0, count: 7))
        XCTAssertEqual(result.stockByHouseInfoSlot, [8, 4, 7, 6, 3, 6, 6])

        // A resident count above the model capacity raises the Dinners target;
        // a short Dinners word is then cleared and the unfulfilled amount is
        // retained in the pass-local deficit, matching the source branch.
        let shortage = try XCTUnwrap(
            OriginalEliteHouseStockConsumption.consume(
                buildingID: 17,
                model: model,
                residentCount: 100,
                stockByHouseInfoSlot: [20, 5, 9, 7, 3, 8, 7]
            )
        )
        XCTAssertEqual(shortage.selectedAmountByPass[6], 25)
        XCTAssertEqual(shortage.deficitByPass[6], 5)
        XCTAssertEqual(shortage.stockByHouseInfoSlot[0], 0)

        let abandoned = try XCTUnwrap(models.buildings[houseLevelID: 9])
        XCTAssertNotNil(
            OriginalEliteHouseStockConsumption.consume(
                buildingID: 12,
                model: abandoned,
                residentCount: 0,
                stockByHouseInfoSlot: Array(repeating: 0, count: 7)
            )
        )
        XCTAssertNil(
            OriginalEliteHouseStockConsumption.consume(
                buildingID: 11,
                model: model,
                residentCount: 20,
                stockByHouseInfoSlot: Array(repeating: 0, count: 7)
            )
        )
        XCTAssertNil(
            OriginalEliteHouseStockConsumption.consume(
                buildingID: 17,
                model: model,
                residentCount: 20,
                stockByHouseInfoSlot: Array(repeating: 0, count: 6)
            )
        )
    }

    func testOriginalMarketPeddlerSpawnSelectorUsesRecoveredThreeThreeRecord() {
        for marketBuildingID in [
            OriginalMarketPeddlerSpawnSelector.commonMarketBuildingID,
            OriginalMarketPeddlerSpawnSelector.grandMarketBuildingID
        ] {
            for orientationBank in 0...1 {
                let selection = OriginalMarketPeddlerSpawnSelector.select(
                    marketBuildingID: marketBuildingID,
                    orientationBank: orientationBank
                )
                XCTAssertEqual(selection?.offset, GridPoint(x: 3, y: 3))
                XCTAssertEqual(
                    selection?.selectedRecordIndex,
                    marketBuildingID == OriginalMarketPeddlerSpawnSelector.commonMarketBuildingID
                        ? 15 : 21
                )
                XCTAssertEqual(
                    OriginalMarketPeddlerSpawnSelector.point(
                        marketOrigin: GridPoint(x: 10, y: 20),
                        marketBuildingID: marketBuildingID,
                        orientationBank: orientationBank
                    ),
                    GridPoint(x: 13, y: 23)
                )
            }
        }

        XCTAssertNil(
            OriginalMarketPeddlerSpawnSelector.select(
                marketBuildingID: 58,
                orientationBank: 0
            )
        )
        XCTAssertNil(
            OriginalMarketPeddlerSpawnSelector.select(
                marketBuildingID: 59,
                orientationBank: 2
            )
        )
    }

    func testOriginalMarketProviderAccumulatorUsesRawRecordIndexAndAmount() {
        let records = [
            OriginalMarketProviderRecord(rawField4: 0, rawField8: 0),
            OriginalMarketProviderRecord(rawField4: 19, rawField8: 7),
            OriginalMarketProviderRecord(rawField4: 0, rawField8: 5),
            OriginalMarketProviderRecord(rawField4: 19, rawField8: -2),
            OriginalMarketProviderRecord(rawField4: 25, rawField8: 4)
        ]

        XCTAssertEqual(
            OriginalMarketProviderAccumulator.add(
                records: records,
                to: [19: 1, 99: 3]
            ),
            [0: 5, 19: 6, 25: 4, 99: 3],
            "FUN_005D5B10 forwards rawField4 as the index and rawField8 as the amount"
        )
    }

    func testOriginalProviderCrossingAccumulatorPreservesSigned16BitWriteAndUpperClamp() {
        XCTAssertEqual(
            OriginalProviderCrossingAccumulator.nextValue(
                currentWord: 12,
                callbackResult: -5
            ),
            7
        )
        XCTAssertEqual(
            OriginalProviderCrossingAccumulator.nextValue(
                currentWord: 299,
                callbackResult: 2
            ),
            300,
            "FUN_004EACD0 clamps only the signed-short result above 300"
        )
        XCTAssertEqual(
            OriginalProviderCrossingAccumulator.nextValue(
                currentWord: -2,
                callbackResult: -3
            ),
            -5,
            "the source has no lower clamp"
        )
        XCTAssertEqual(
            OriginalProviderCrossingAccumulator.nextValue(
                currentWord: Int16.max,
                callbackResult: 1
            ),
            Int16.min,
            "the intermediate provider write is a wrapping signed 16-bit store"
        )
    }

    func testOriginalMarketProviderConsumptionUsesStrictMinimumAndReturnsRemainder() {
        let records = [
            OriginalMarketProviderRecord(rawField4: 19, rawField8: 7),
            OriginalMarketProviderRecord(rawField4: 25, rawField8: 4),
            OriginalMarketProviderRecord(rawField4: 19, rawField8: 7),
            OriginalMarketProviderRecord(rawField4: 19, rawField8: 3)
        ]

        let partial = OriginalMarketProviderConsumption.reduce(
            records: records,
            commodityID: 19,
            requestedAmount: 8,
            clearRecordWhenEmpty: true
        )
        // The strict-minimum scan consumes the 3-unit record first, then the
        // first 7-unit tie; the second tie remains untouched.
        XCTAssertEqual(partial.remainder, 0)
        XCTAssertEqual(partial.records.map(\.rawField4), [19, 25, 19, 0])
        XCTAssertEqual(partial.records.map(\.rawField8), [2, 4, 7, 0])

        let insufficient = OriginalMarketProviderConsumption.reduce(
            records: records,
            commodityID: 19,
            requestedAmount: 20,
            clearRecordWhenEmpty: false
        )
        XCTAssertEqual(insufficient.remainder, 3)
        XCTAssertEqual(insufficient.records.map(\.rawField4), [19, 25, 19, 19])
        XCTAssertEqual(insufficient.records.map(\.rawField8), [0, 4, 0, 0])
        XCTAssertEqual(
            OriginalMarketProviderConsumption.reduce(
                records: records,
                commodityID: 19,
                requestedAmount: 0,
                clearRecordWhenEmpty: true
            ),
            .init(records: records, remainder: 0)
        )
    }

    func testOriginalMarketProviderStockingWritesCommodityAndClipsAtRecordCapacity() {
        XCTAssertEqual(
            OriginalMarketProviderStocking.add(
                record: .init(rawField4: 25, rawField8: 390),
                commodityID: 19,
                amount: 30
            ),
            .init(
                record: .init(rawField4: 19, rawField8: 400),
                overflow: 20
            )
        )
        XCTAssertEqual(
            OriginalMarketProviderStocking.add(
                record: .init(rawField4: 0, rawField8: 0),
                commodityID: 25,
                amount: 7,
                capacity: 10
            ),
            .init(
                record: .init(rawField4: 25, rawField8: 7),
                overflow: 0
            )
        )
        // The source helper clips only the upper bound; a negative amount is
        // not silently clamped upward.
        XCTAssertEqual(
            OriginalMarketProviderStocking.add(
                record: .init(rawField4: 19, rawField8: 4),
                commodityID: 19,
                amount: -5,
                capacity: 400
            ),
            .init(
                record: .init(rawField4: 19, rawField8: -1),
                overflow: 0
            )
        )
    }

    func testOriginalMarketStallDepositSplitsAcceptedAndOverflowBeforeParentCallback() {
        let result = OriginalMarketStallDeposit.deposit(
            record: .init(rawField4: 25, rawField8: 390),
            commodityID: 19,
            amount: 30,
            capacity: 400
        )

        // cStall `+0x260` accepts 10 units into its own record and forwards
        // only the clipped 20-unit overflow to cMarket `+0x154`.
        XCTAssertEqual(result.record, .init(rawField4: 19, rawField8: 400))
        XCTAssertEqual(result.acceptedAmount, 10)
        XCTAssertEqual(result.overflowAmount, 20)

        let unfilled = OriginalMarketStallDeposit.deposit(
            record: .init(rawField4: 0, rawField8: 0),
            commodityID: 0x1C,
            amount: 100,
            capacity: 400
        )
        XCTAssertEqual(unfilled.acceptedAmount, 100)
        XCTAssertEqual(unfilled.overflowAmount, 0)
        XCTAssertEqual(unfilled.record, .init(rawField4: 0x1C, rawField8: 100))
    }

    func testOriginalMonthlyFoodDepletionMatchesNormalAndCheatBranches() {
        let normal = OriginalMarketMonthlyFoodDepletion.apply(
            stock: 100,
            qualityRawValue: 50,
            residents: 10,
            requiredQuality: 20,
            cheatEnabled: false
        )
        XCTAssertEqual(
            normal,
            .init(stock: 98, qualityRawValue: 50, consumedAmount: 2)
        )

        let drained = OriginalMarketMonthlyFoodDepletion.apply(
            stock: 1,
            qualityRawValue: 70,
            residents: 10,
            requiredQuality: 20,
            cheatEnabled: false
        )
        XCTAssertEqual(
            drained,
            .init(stock: 0, qualityRawValue: 0, consumedAmount: 1)
        )

        let zeroRequirement = OriginalMarketMonthlyFoodDepletion.apply(
            stock: 100,
            qualityRawValue: 70,
            residents: 10,
            requiredQuality: 0,
            cheatEnabled: false
        )
        XCTAssertEqual(
            zeroRequirement,
            .init(stock: 100, qualityRawValue: 70, consumedAmount: 0)
        )

        let cheat = OriginalMarketMonthlyFoodDepletion.apply(
            stock: 100,
            qualityRawValue: 70,
            residents: 10,
            requiredQuality: 20,
            cheatEnabled: true
        )
        XCTAssertEqual(
            cheat,
            .init(stock: 2, qualityRawValue: 20, consumedAmount: 0)
        )
    }

    func testOriginalMarketProviderWriterChoosesGreatestQuantityAndKeepsFirstTie() {
        let result = OriginalMarketProviderWriter.add(
            records: [
                .init(rawField4: 19, rawField8: 5),
                .init(rawField4: 19, rawField8: 5),
                .init(rawField4: 0, rawField8: 0)
            ],
            commodityID: 19,
            requestedUnits: 2,
            capacities: [10, 10, 10]
        )

        // `FUN_005D4E80` starts its best-quantity sentinel at -1 and uses a
        // strict greater-than comparison, so the first 5-unit tie is stocked
        // twice; this differs from the reducer's strict-minimum scan.
        XCTAssertEqual(result.selectedRecordIndices, [0, 0])
        XCTAssertEqual(result.records.map(\.rawField4), [19, 19, 0])
        XCTAssertEqual(result.records.map(\.rawField8), [7, 5, 0])
        XCTAssertEqual(result.callbackAmount, 2)
        XCTAssertEqual(result.returnValue, 2)
    }

    func testOriginalMarketProviderRefillKeepsOnlyMatchingRecords() {
        let result = OriginalMarketProviderRefill.add(
            records: [
                .init(rawField4: 19, rawField8: 5),
                .init(rawField4: 25, rawField8: 99),
                .init(rawField4: 19, rawField8: 5)
            ],
            commodityID: 19,
            requestedUnits: 2,
            capacities: [10, 100, 10]
        )

        // `FUN_00543BC0` filters by rawField4 before selecting the strict
        // greatest quantity; the first 5-unit tie is therefore refilled
        // twice and the unrelated 25-key record is untouched.
        XCTAssertEqual(result.selectedRecordIndices, [0, 0])
        XCTAssertEqual(result.records.map(\.rawField4), [19, 25, 19])
        XCTAssertEqual(result.records.map(\.rawField8), [7, 99, 5])
        XCTAssertEqual(result.returnValue, 2)

        let failed = OriginalMarketProviderRefill.add(
            records: [.init(rawField4: 19, rawField8: 10)],
            commodityID: 19,
            requestedUnits: 1,
            capacities: [10]
        )
        XCTAssertEqual(failed.returnValue, 0)
        XCTAssertEqual(failed.selectedRecordIndices, [])
        XCTAssertEqual(failed.records[0].rawField8, 10)
    }

    func testOriginalMapInvasionRandomStartMatchesSourceNormalization() {
        // FUN_00522AE0 masks the published primary value with 0x8000000F.
        // The recovered RNG publishes only 0x7FFF, so the normal path keeps
        // the low nibble unchanged, including the source's 8…15 range.
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomStartIndex(
                randomWord: 0x0000_000A
            ),
            10
        )
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomStartIndex(
                randomWord: 0x0000_7FFF
            ),
            15
        )

        // The signed fallback is reachable only for a raw word with bit 31
        // set; preserve the exact 32-bit expression even though canonical
        // DAT_010C7138 writes cannot produce it.
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomStartIndex(
                randomWord: 0x8000_0000
            ),
            0
        )
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomStartIndex(
                randomWord: 0x8000_0001
            ),
            -15
        )

        let allAbsent = Array(repeating: -1, count: 16)
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomScanIndex(
                randomWord: 0x0000_000A,
                xCoordinates: allAbsent
            ),
            7,
            "after eight checks the source returns the post-loop index"
        )

        var storage = allAbsent
        storage[1] = 42
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomScanIndex(
                randomWord: 0x0000_000A,
                xCoordinates: storage
            ),
            1,
            "low-nibble starts 10…15 inspect the initialized tail then wrap"
        )

        storage[10] = 99
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomScanIndex(
                randomWord: 0x0000_000A,
                xCoordinates: storage
            ),
            10
        )
        XCTAssertEqual(
            OriginalMapInvasionPointSlotCatalog.sourceRandomScanIndex(
                randomWord: 0x0000_000A,
                xCoordinates: Array(repeating: -1, count: 8)
            ),
            nil
        )
    }

    func testOriginalMarketFoodDeliveryDemandPreservesCallbackOutputOrderAndCap() {
        let occupied = OriginalMarketFoodDeliveryDemand.resolve(
            residents: 22,
            currentStock: 7
        )
        XCTAssertEqual(occupied.targetStock, 44)
        XCTAssertEqual(occupied.perCallbackCap, 11)
        XCTAssertEqual(occupied.requestedAmount, 11)

        let nearlyFull = OriginalMarketFoodDeliveryDemand.resolve(
            residents: 22,
            currentStock: 40
        )
        XCTAssertEqual(nearlyFull.requestedAmount, 4)

        let empty = OriginalMarketFoodDeliveryDemand.resolve(
            residents: 0,
            currentStock: 0
        )
        XCTAssertEqual(empty.targetStock, 10)
        XCTAssertEqual(empty.perCallbackCap, 5)
        XCTAssertEqual(empty.requestedAmount, 5)
    }

    func testOriginalMarketPeddlerSpawnSchedulerUsesPhase31AndPersistsCounter() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let models = try OriginalEconomyModels(source: .openDefault()).buildings
        let road = GridPoint(x: 0, y: 0)
        var state = DeterministicMarketState()
        _ = try XCTUnwrap(state.addMarket(
            buildingID: OriginalMarketCatalog.commonMarketBuildingID,
            roadAccessPoint: road,
            shopBuildingIDs: [],
            roadNetwork: RoadNetwork(width: 4, height: 4, points: [road])
        ))

        let roads = RoadNetwork(width: 4, height: 4, points: [road])
        state.advanceOriginalPeddlerSpawnScheduler(
            originalSteps: 31,
            houses: [],
            roadNetwork: roads,
            models: models,
            maximumRoadSteps: 60,
            replaySeed: 0x51CF90,
            activeMarketIDs: [1],
            workerPercentByMarketID: [1: 100]
        )
        XCTAssertEqual(
            state.markets[0].originalPeddlerSpawnCounter,
            0,
            "phase 0x1F is reached on the next (32nd) inner step"
        )

        state.advanceOriginalPeddlerSpawnScheduler(
            originalSteps: 1,
            houses: [],
            roadNetwork: roads,
            models: models,
            maximumRoadSteps: 60,
            replaySeed: 0x51CF90,
            activeMarketIDs: [1],
            workerPercentByMarketID: [1: 100]
        )
        XCTAssertEqual(state.markets[0].originalPeddlerSpawnCounter, 1)

        state.advanceOriginalPeddlerSpawnScheduler(
            originalSteps: 51,
            houses: [],
            roadNetwork: roads,
            models: models,
            maximumRoadSteps: 60,
            replaySeed: 0x51CF90,
            activeMarketIDs: [1],
            workerPercentByMarketID: [1: 100]
        )
        XCTAssertEqual(state.markets[0].originalPeddlerSpawnCounter, 2)

        state.advanceOriginalPeddlerSpawnScheduler(
            originalSteps: 51,
            houses: [],
            roadNetwork: roads,
            models: models,
            maximumRoadSteps: 60,
            replaySeed: 0x51CF90,
            activeMarketIDs: [1],
            workerPercentByMarketID: [1: 100]
        )
        XCTAssertEqual(
            state.markets[0].originalPeddlerSpawnCounter,
            0,
            "the third opportunity crosses threshold 2 and resets the byte"
        )

        let decoded = try JSONDecoder().decode(
            DeterministicMarketState.self,
            from: JSONEncoder().encode(state)
        )
        XCTAssertEqual(decoded, state)
    }

    func testOriginalMarketPeddlerSchedulerDoesNotAssumeMissingWorkerRatio() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var fixture = try makeStockedHempMarket(models: original.buildings)

        // The executable computes this ratio from cStall +0x44 and the
        // filled-shop employee aggregate. Omitting that unresolved raw input
        // must not silently become a 100% worker market.
        fixture.market.advanceOriginalPeddlerSpawnScheduler(
            originalSteps: 32 + 51 + 51,
            houses: fixture.houses,
            roadNetwork: fixture.roadNetwork,
            models: original.buildings,
            maximumRoadSteps: 60,
            replaySeed: 0x51CF90,
            activeMarketIDs: [1],
            allowCompatibilityRouteFallback: true
        )

        XCTAssertTrue(fixture.market.peddlers.isEmpty)
        XCTAssertEqual(fixture.market.markets[0].originalPeddlerSpawnCounter, 0)
        XCTAssertEqual(fixture.market.markets[0].inventoryByCommodityID[19], 100)
    }

    func testOriginalMarketPeddlerSpawnAdvancesRotationOnlyAfterAllocation() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var fixture = try makeStockedHempMarket(models: original.buildings)

        // The market starts at scheduler phase 0. Phase 0x1F is reached on
        // inner steps 32, 83, and 134; worker 100% uses threshold 2, so the
        // third opportunity is the first successful model-23 allocation.
        fixture.market.advanceOriginalPeddlerSpawnScheduler(
            originalSteps: 32 + 51,
            houses: fixture.houses,
            roadNetwork: fixture.roadNetwork,
            models: original.buildings,
            maximumRoadSteps: 60,
            replaySeed: 0x51CF90,
            activeMarketIDs: [1],
            workerPercentByMarketID: [1: 100],
            barrierPoints: [fixture.barrier],
            allowCompatibilityRouteFallback: true
        )

        XCTAssertTrue(fixture.market.peddlers.isEmpty)
        XCTAssertEqual(fixture.market.markets[0].originalPeddlerSpawnRotation, 0)

        fixture.market.advanceOriginalPeddlerSpawnScheduler(
            originalSteps: 51,
            houses: fixture.houses,
            roadNetwork: fixture.roadNetwork,
            models: original.buildings,
            maximumRoadSteps: 60,
            replaySeed: 0x51CF90,
            activeMarketIDs: [1],
            workerPercentByMarketID: [1: 100],
            barrierPoints: [fixture.barrier],
            allowCompatibilityRouteFallback: true
        )

        XCTAssertEqual(fixture.market.peddlers.count, 1)
        XCTAssertEqual(
            fixture.market.markets[0].originalPeddlerSpawnRotation,
            4,
            "FUN_00543ED0 rotates cMarket +0x38 only after model-23 creation"
        )

        let decoded = try JSONDecoder().decode(
            DeterministicMarketState.self,
            from: JSONEncoder().encode(fixture.market)
        )
        XCTAssertEqual(decoded.markets[0].originalPeddlerSpawnRotation, 4)
    }

    func testOriginalMarketPeddlerSchedulerStaysFailClosedWhenRouteIsUnknown() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        // Reuse the destination-buyer fixture to obtain authored hemp stock,
        // then pass a deliberately incomplete road graph to the original
        // timing bridge.  The market remains stocked while no house can be
        // reached through the recovered delivery-route contract.
        var fixture = try makeStockedHempMarket(models: original.buildings)
        let road = RoadNetwork(
            width: fixture.roadNetwork.width,
            height: fixture.roadNetwork.height,
            points: [fixture.marketRoad]
        )

        // Worker 100% uses threshold 2, so the third explicit opportunity
        // attempts allocation. The exact route/coverage contract is still
        // unresolved; the original-timing bridge must not substitute the
        // compatibility patrol route when no recovered route exists.
        for _ in 0..<3 {
            fixture.market.schedulePeddlers(
                houses: fixture.houses,
                roadNetwork: road,
                models: original.buildings,
                maximumRoadSteps: 60,
                replaySeed: 0x51CF90,
                activeMarketIDs: [1],
                originalSpawnGate: true,
                workerPercentByMarketID: [1: 100]
            )
        }
        XCTAssertTrue(fixture.market.peddlers.isEmpty)
        XCTAssertEqual(fixture.market.markets[0].inventoryByCommodityID[19], 100)
        XCTAssertEqual(fixture.market.markets[0].originalPeddlerSpawnCounter, 0)
    }

    func testOriginalMarketPeddlerSchedulerNeverUsesHouseholdRoute() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        // The complete fixture makes the compatibility household route
        // resolvable. The campaign bridge must still reject it because the
        // recovered model-23 endpoint starts from the original map cache,
        // not from Native ResidentialUnit targets.
        var fixture = try makeStockedHempMarket(models: original.buildings)
        for _ in 0..<3 {
            fixture.market.schedulePeddlers(
                houses: fixture.houses,
                roadNetwork: fixture.roadNetwork,
                models: original.buildings,
                maximumRoadSteps: 60,
                replaySeed: 0x51CF90,
                activeMarketIDs: [1],
                barrierPoints: [fixture.barrier],
                originalSpawnGate: true,
                workerPercentByMarketID: [1: 100]
            )
        }
        XCTAssertTrue(fixture.market.peddlers.isEmpty)
        XCTAssertEqual(fixture.market.markets[0].inventoryByCommodityID[19], 100)
        XCTAssertEqual(fixture.market.markets[0].originalPeddlerSpawnRotation, 0)
    }

    func testMarketBuyerUsesRecoveredSelectorEightSubstepCadence() throws {
        let path = (0...3).map { GridPoint(x: $0, y: 0) }
        var buyer = MarketBuyer(
            id: 1,
            marketID: 1,
            cargoes: [DeliveryCargo(commodityID: 19, amount: 10)],
            outboundPath: path
        )

        for _ in 0..<14 {
            _ = buyer.advanceOriginalFigureUpdate()
        }
        XCTAssertEqual(buyer.routeIndex, 0)
        _ = buyer.advanceOriginalFigureUpdate()
        XCTAssertEqual(buyer.routeIndex, 1)

        let decoded = try JSONDecoder().decode(
            MarketBuyer.self,
            from: JSONEncoder().encode(buyer)
        )
        XCTAssertEqual(decoded, buyer)
    }

    func testMarketPeddlerStartsAtRecoveredSelectorEightCrossingBoundary() throws {
        let path = (0...2).map { GridPoint(x: $0, y: 0) }
        var peddler = MarketPeddler(
            id: 1,
            marketID: 1,
            commodityID: 19,
            amount: 10,
            route: path
        )

        XCTAssertEqual(peddler.routeIndex, 0)
        _ = peddler.advanceOriginalFigureUpdate(barrierPoints: [])
        XCTAssertEqual(peddler.routeIndex, 1)

        let decoded = try JSONDecoder().decode(
            MarketPeddler.self,
            from: JSONEncoder().encode(peddler)
        )
        XCTAssertEqual(decoded, peddler)
    }

    func testOriginalMarketPeddlerReturnGateUsesFourFifthsAndSavedPoint() {
        let point = GridPoint(x: 3, y: 4)
        XCTAssertFalse(
            OriginalMarketPeddlerReturnGate.shouldReturn(
                modelID: 23,
                traveledBudget: 47,
                behaviorRange: 60,
                currentPoint: point,
                savedPoint: point
            )
        )
        XCTAssertTrue(
            OriginalMarketPeddlerReturnGate.shouldReturn(
                modelID: 23,
                traveledBudget: 48,
                behaviorRange: 60,
                currentPoint: point,
                savedPoint: point
            )
        )
        XCTAssertFalse(
            OriginalMarketPeddlerReturnGate.shouldReturn(
                modelID: 23,
                traveledBudget: 60,
                behaviorRange: 60,
                currentPoint: point,
                savedPoint: GridPoint(x: 4, y: 4)
            )
        )
    }

    func testOriginalMarketPeddlerReturnGateHonorsModelExemptions() {
        let point = GridPoint(x: 0, y: 0)
        for modelID in [
            OriginalMarketPeddlerReturnGate.percentModelID,
            OriginalMarketPeddlerReturnGate.letterOModelID,
        ] {
            XCTAssertFalse(
                OriginalMarketPeddlerReturnGate.shouldReturn(
                    modelID: modelID,
                    traveledBudget: 10_000,
                    behaviorRange: 60,
                    currentPoint: point,
                    savedPoint: point
                )
            )
        }
    }

    func testOriginalMarketPeddlerReturnRouteKeepsMarketEndpointAndStateBoundaries() {
        let route = OriginalMarketPeddlerReturnRouteDescriptor.canonical

        XCTAssertEqual(route.roamHandlerAddress, 0x004E3A80)
        XCTAssertEqual(route.returnGateAddress, 0x004E3A10)
        XCTAssertEqual(route.routeRetryAddress, 0x004BA580)
        XCTAssertEqual(route.marketEndpointSelectorAddress, 0x00544910)
        XCTAssertEqual(route.routeClearAddress, 0x004E8A30)
        XCTAssertEqual(route.marketClassWords, [0x3B, 0x3C])
        XCTAssertEqual(route.retryMaximumRotation, 2)
        XCTAssertEqual(route.successFigureState, 2)
        XCTAssertEqual(route.targetXOffset, 0x2C)
        XCTAssertEqual(route.targetYOffset, 0x2E)
        XCTAssertEqual(route.travelledBudgetOffset, 0x4C)
        XCTAssertTrue(OriginalMarketPeddlerReturnRouteDescriptor.usesMarketEntrance(forLinkedObjectClassWord: 0x3B))
        XCTAssertTrue(OriginalMarketPeddlerReturnRouteDescriptor.usesMarketEntrance(forLinkedObjectClassWord: 0x3C))
        XCTAssertFalse(OriginalMarketPeddlerReturnRouteDescriptor.usesMarketEntrance(forLinkedObjectClassWord: 0x3E))
    }

    private struct HempMarketFixture {
        var market: DeterministicMarketState
        var roadNetwork: RoadNetwork
        var houses: [ResidentialUnit]
        let marketRoad: GridPoint
        let barrier: GridPoint
        let nearHouseID: Int
        let farHouseID: Int
    }

    /// Builds a market whose hemp inventory is stocked through the destination
    /// buyer. The buyer visits a warehouse beyond `barrier`, so stocking itself
    /// exercises the buyer's market-to-warehouse route passing the roadblock.
    private func makeStockedHempMarket(models: BuildingModelTable) throws -> HempMarketFixture {
        let marketRoad = GridPoint(x: 0, y: 3)
        let barrier = GridPoint(x: 7, y: 3)
        let roadNetwork = RoadNetwork(
            width: 16,
            height: 10,
            points: Set((0...15).map { GridPoint(x: $0, y: 3) })
        )
        var market = DeterministicMarketState()
        _ = try XCTUnwrap(market.addMarket(
            buildingID: OriginalMarketCatalog.commonMarketBuildingID,
            roadAccessPoint: marketRoad,
            shopBuildingIDs: [67],
            roadNetwork: roadNetwork
        ))
        var logistics = DeterministicLogisticsState()
        _ = try XCTUnwrap(logistics.addWarehouse(
            roadAccessPoint: GridPoint(x: 14, y: 3),
            roadNetwork: roadNetwork
        ))
        var production = DeterministicProductionState()
        XCTAssertEqual(
            logistics.storeCampaignGift(commodityID: 19, amount: 100, production: &production),
            100
        )
        let houses = [
            ResidentialUnit(id: 1, houseLevelID: 4, residents: 10, location: GridPoint(x: 2, y: 4)),
            ResidentialUnit(id: 2, houseLevelID: 4, residents: 10, location: GridPoint(x: 12, y: 4))
        ]
        market.scheduleBuyers(
            houses: houses,
            logistics: &logistics,
            production: &production,
            roadNetwork: roadNetwork,
            models: models,
            maximumOneWayRoadSteps: 50
        )
        let buyer = try XCTUnwrap(market.buyers.first)
        XCTAssertTrue(buyer.route.contains(barrier),
                      "the buyer is a destination walker and stocks the market across the roadblock tile")
        _ = market.advanceBuyers(roadStepsPerBuyer: 50)
        XCTAssertEqual(market.markets[0].inventoryByCommodityID[19, default: 0], 100)
        return HempMarketFixture(
            market: market,
            roadNetwork: roadNetwork,
            houses: houses,
            marketRoad: marketRoad,
            barrier: barrier,
            nearHouseID: houses[0].id,
            farHouseID: houses[1].id
        )
    }

    func testCommodityPeddlerDispatchRouteAvoidsRoadblockAndNeverServesFarSide() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var fixture = try makeStockedHempMarket(models: original.buildings)

        fixture.market.schedulePeddlers(
            houses: fixture.houses,
            roadNetwork: fixture.roadNetwork,
            models: original.buildings,
            maximumRoadSteps: 60,
            replaySeed: 0x4D41_524B_4554,
            barrierPoints: [fixture.barrier]
        )
        XCTAssertFalse(fixture.market.peddlers.isEmpty)
        for peddler in fixture.market.peddlers {
            XCTAssertFalse(
                peddler.route.contains(fixture.barrier),
                "a commodity peddler patrol never enters a roadblock tile"
            )
            XCTAssertFalse(
                peddler.route.contains { $0.x > fixture.barrier.x },
                "the patrol turns before the barrier and stays on the market side"
            )
        }

        let deliveries = fixture.market.advancePeddlers(
            roadStepsPerPeddler: 60,
            houses: &fixture.houses,
            models: original.buildings,
            barrierPoints: [fixture.barrier]
        )
        XCTAssertFalse(
            deliveries.contains { $0.houseID == fixture.farHouseID },
            "the far-side house must never receive a commodity across the roadblock"
        )
        XCTAssertEqual(fixture.houses[1][commodityID: 19], 0)
        XCTAssertGreaterThan(
            fixture.houses[0][commodityID: 19],
            0,
            "the market-side house keeps receiving hemp"
        )
    }

    func testBuyerDestinationRoutePassesThroughRoadblockTile() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let marketRoad = GridPoint(x: 0, y: 3)
        let barrier = GridPoint(x: 7, y: 3)
        let roadNetwork = RoadNetwork(
            width: 16,
            height: 10,
            points: Set((0...15).map { GridPoint(x: $0, y: 3) })
        )
        var market = DeterministicMarketState()
        _ = try XCTUnwrap(market.addMarket(
            buildingID: OriginalMarketCatalog.commonMarketBuildingID,
            roadAccessPoint: marketRoad,
            shopBuildingIDs: [67],
            roadNetwork: roadNetwork
        ))
        var logistics = DeterministicLogisticsState()
        _ = try XCTUnwrap(logistics.addWarehouse(
            roadAccessPoint: GridPoint(x: 14, y: 3),
            roadNetwork: roadNetwork
        ))
        var production = DeterministicProductionState()
        XCTAssertEqual(
            logistics.storeCampaignGift(commodityID: 19, amount: 100, production: &production),
            100
        )
        let houses = [
            ResidentialUnit(id: 1, houseLevelID: 4, residents: 10, location: GridPoint(x: 2, y: 4))
        ]
        market.scheduleBuyers(
            houses: houses,
            logistics: &logistics,
            production: &production,
            roadNetwork: roadNetwork,
            models: original.buildings,
            maximumOneWayRoadSteps: 50
        )
        let buyer = try XCTUnwrap(market.buyers.first)
        XCTAssertTrue(
            buyer.route.contains(barrier),
            "the buyer keeps the roadblock tile on its market-to-warehouse destination route"
        )
        let purchased = market.advanceBuyers(roadStepsPerBuyer: 50)
        XCTAssertTrue(purchased.contains { $0.commodityID == 19 })
        XCTAssertEqual(market.markets[0].inventoryByCommodityID[19, default: 0], 100)
    }

    func testRoadblockOnExistingPeddlerNextTileHoldsWithoutEnterOrCompleteOrCargoReturn() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var fixture = try makeStockedHempMarket(models: original.buildings)

        fixture.market.schedulePeddlers(
            houses: fixture.houses,
            roadNetwork: fixture.roadNetwork,
            models: original.buildings,
            maximumRoadSteps: 60,
            replaySeed: 0x4D41_524B_4554
        )
        let peddlerBefore = try XCTUnwrap(fixture.market.peddlers.first)
        let startPoint = try XCTUnwrap(peddlerBefore.currentPoint)
        XCTAssertEqual(startPoint, fixture.marketRoad)
        let newlyBlockedTile = peddlerBefore.route[peddlerBefore.routeIndex + 1]

        // A roadblock is newly placed on the peddler's very next tile after the
        // peddler was already dispatched and is standing at a road tile.
        let deliveries = fixture.market.advancePeddlers(
            roadStepsPerPeddler: 60,
            houses: &fixture.houses,
            models: original.buildings,
            barrierPoints: [newlyBlockedTile]
        )
        XCTAssertTrue(deliveries.isEmpty)
        let peddlerAfter = try XCTUnwrap(fixture.market.peddlers.first)
        XCTAssertEqual(
            peddlerAfter.currentPoint,
            startPoint,
            "the blocked peddler must not enter the newly roadblocked next tile"
        )
        XCTAssertEqual(
            peddlerAfter.routeIndex,
            peddlerBefore.routeIndex,
            "position and completion state stay unchanged"
        )
        XCTAssertFalse(peddlerAfter.hasCompletedRoute)
        XCTAssertEqual(
            peddlerAfter.remainingAmount,
            100,
            "cargo is neither returned nor lost while the peddler is held at the barrier"
        )
        XCTAssertEqual(
            fixture.market.markets[0].inventoryByCommodityID[19, default: 0],
            0,
            "the market inventory is not restocked by a held peddler"
        )
        XCTAssertEqual(fixture.houses[0][commodityID: 19], 0,
                       "no delivery happens before the peddler moves")

        _ = fixture.market.advancePeddlers(
            roadStepsPerPeddler: 1,
            houses: &fixture.houses,
            models: original.buildings
        )
        XCTAssertEqual(fixture.market.peddlers.first?.currentPoint, newlyBlockedTile,
                       "removing the runtime barrier resumes the preserved route")
    }

    func testRoadConstructionAndTaxCoverageUseDeterministicRoutes() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 100,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = city.addHouse(
            levelID: 0,
            residents: 5,
            location: GridPoint(x: 2, y: 3),
            models: original.buildings
        )
        _ = city.addHouse(
            levelID: 2,
            residents: 8,
            location: GridPoint(x: 5, y: 3),
            models: original.buildings
        )
        _ = city.addHouse(levelID: 1, residents: 4, models: original.buildings)
        let road = (0...6).map { GridPoint(x: $0, y: 2) }

        XCTAssertEqual(city.buildRoad(road, rules: rules), 7)
        XCTAssertEqual(city.economy.treasury, 86)
        XCTAssertEqual(city.economy.transactionSequence, 1)
        XCTAssertEqual(city.applyTaxCoverage(from: road[0], maximumRoadSteps: 2), 1)
        XCTAssertEqual(city.houses.map(\.hasTaxCoverage), [true, false, false])

        let taxOfficialRange = try XCTUnwrap(original.figures[figureID: 27]?.behaviorRange)
        XCTAssertEqual(city.applyTaxCoverage(from: road[0], maximumRoadSteps: taxOfficialRange), 2)
        XCTAssertEqual(city.houses.map(\.hasTaxCoverage), [true, true, false])

        let beforeInvalidRoad = city
        XCTAssertNil(city.buildRoad([GridPoint(x: 8, y: 2)], rules: rules))
        XCTAssertEqual(city, beforeInvalidRoad)

        var poorCity = DeterministicCityState(year: 1600, treasury: 13, mapWidth: 8, mapHeight: 5)
        XCTAssertNil(poorCity.buildRoad(road, rules: rules))
        XCTAssertTrue(poorCity.roadNetwork.points.isEmpty)
        XCTAssertEqual(poorCity.economy.treasury, 13)
    }

    func testOriginalRectangularFootprintsRotateAndPlacedConstructionIsAtomic() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: 54),
            BuildingFootprint(width: 3, height: 3)
        )
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: 53),
            BuildingFootprint(width: 5, height: 5)
        )
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: 59,
                orientation: .eastWest
            ),
            BuildingFootprint(width: 4, height: 7)
        )

        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 2_000,
            mapWidth: 20,
            mapHeight: 12
        )
        let road = (1...18).map { GridPoint(x: $0, y: 1) }
        XCTAssertEqual(city.buildRoad(road, rules: rules), road.count)

        let warehouseID = try XCTUnwrap(city.constructWarehouse(
            at: GridPoint(x: 2, y: 2),
            rules: rules
        ))
        let warehouse = try XCTUnwrap(city.placement(
            category: .warehouse,
            instanceID: warehouseID
        ))
        XCTAssertEqual(warehouse.occupiedPoints.count, 9)
        XCTAssertEqual(warehouse.roadAccessPoint, GridPoint(x: 2, y: 1))
        XCTAssertFalse(city.canConstructRoad(at: GridPoint(x: 4, y: 4)))

        let beforeOverlap = city
        XCTAssertNil(city.constructProductionBuilding(
            buildingID: 43,
            at: GridPoint(x: 4, y: 3),
            assignedWorkers: 12,
            rules: rules
        ))
        XCTAssertEqual(city, beforeOverlap)

        XCTAssertNotNil(city.constructProductionBuilding(
            buildingID: 43,
            at: GridPoint(x: 5, y: 2),
            assignedWorkers: 12,
            rules: rules
        ))
        XCTAssertNotNil(city.constructTaxOffice(
            at: GridPoint(x: 8, y: 2),
            replaySeed: 0x504C_4143_454D_454E,
            rules: rules
        ))
        let marketID = try XCTUnwrap(city.constructMarket(
            at: GridPoint(x: 11, y: 2),
            orientation: .eastWest,
            shopBuildingIDs: [OriginalFoodCatalog.foodShopBuildingID],
            rules: rules
        ))
        let market = try XCTUnwrap(city.placement(category: .market, instanceID: marketID))
        XCTAssertEqual(market.footprint, BuildingFootprint(width: 4, height: 7))
        XCTAssertEqual(city.placedBuildings.count, 4)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testLandTradingStationsChooseMapOriginsCollideAndRoundTrip() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 5_000,
            mapWidth: 16,
            mapHeight: 10
        )
        XCTAssertEqual(
            city.buildRoad((1...14).map { GridPoint(x: $0, y: 1) }, rules: rules),
            14
        )
        for partner in [
            TradePartner(id: 7, name: "Banpo", routeKind: .land, supplyByCommodityID: [5: .low]),
            TradePartner(id: 8, name: "Chengdu", routeKind: .land, demandByCommodityID: [25: .low]),
            TradePartner(id: 9, name: "Quanzhou", routeKind: .sea, supplyByCommodityID: [2: .low]),
        ] {
            XCTAssertTrue(city.addTradePartner(partner, rules: rules))
        }

        let origin = try XCTUnwrap(city.nextBuildingConstructionLocation(buildingID: 58))
        let treasuryBeforeStation = city.economy.treasury
        let stationCost = try XCTUnwrap(rules.constructionCost(
            buildingID: 58,
            difficulty: city.difficulty
        ))
        let firstID = try XCTUnwrap(city.constructTradingBuilding(
            partnerID: 7,
            at: origin,
            rules: rules
        ))
        let placement = try XCTUnwrap(city.placement(category: .trading, instanceID: firstID))
        XCTAssertEqual(placement.buildingID, 58)
        XCTAssertEqual(placement.origin, origin)
        XCTAssertEqual(placement.footprint, BuildingFootprint(width: 3, height: 3))
        XCTAssertEqual(placement.occupiedPoints.count, 9)
        XCTAssertTrue(city.roadNetwork.contains(placement.roadAccessPoint))
        XCTAssertEqual(city.economy.treasury, treasuryBeforeStation - stationCost)

        let beforeOverlap = city
        XCTAssertNil(city.constructTradingBuilding(
            partnerID: 8,
            at: origin,
            rules: rules
        ))
        XCTAssertEqual(city, beforeOverlap)

        let secondOrigin = try XCTUnwrap(city.nextBuildingConstructionLocation(buildingID: 58))
        let secondID = try XCTUnwrap(city.constructTradingBuilding(
            partnerID: 8,
            at: secondOrigin,
            rules: rules
        ))
        XCTAssertNotEqual(secondOrigin, origin)
        XCTAssertNotNil(city.placement(category: .trading, instanceID: secondID))

        // The quay shares the land station's 3×3 footprint but requires
        // shoreline terrain; placement fails on this terrain-free sandbox map.
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: 56),
            BuildingFootprint(width: 3, height: 3)
        )
        let beforeSeaAttempt = city
        XCTAssertNil(city.constructTradingBuilding(
            partnerID: 9,
            at: GridPoint(x: 7, y: 2),
            rules: rules
        ))
        XCTAssertEqual(city, beforeSeaAttempt)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testCampaignTradePermissionBlocksPlacedStationAtomically() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let settings = CampaignMissionStartSettings(
            id: 0,
            startYear: -1500,
            startMonth: 6,
            initialFunds: 1_000,
            allowedBuildingMenuIDs: [],
            allowedResourceCommodityIDs: []
        )
        var city = DeterministicCityState(
            missionSettings: settings,
            mapWidth: 10,
            mapHeight: 8
        )
        XCTAssertEqual(
            city.buildRoad((1...8).map { GridPoint(x: $0, y: 1) }, rules: rules),
            8
        )
        XCTAssertTrue(city.addTradePartner(
            TradePartner(id: 3, name: "Blocked", routeKind: .land),
            rules: rules
        ))
        XCTAssertEqual(
            city.campaignConstructionRestriction(forBuildingID: 58),
            .buildingNotAllowed(menuID: 16, name: "Trade Buildings")
        )
        XCTAssertNil(city.nextBuildingConstructionLocation(buildingID: 58))
        let before = city
        XCTAssertNil(city.constructTradingBuilding(
            partnerID: 3,
            at: GridPoint(x: 2, y: 2),
            rules: rules
        ))
        XCTAssertEqual(city, before)
    }

    func testCityWithoutPlacementFieldStillDecodesAsLegacyFormatV1State() throws {
        let city = DeterministicCityState(year: 1600, treasury: 500)
        let encoded = try JSONEncoder().encode(city)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertNotNil(object.removeValue(forKey: "buildingPlacementState"))
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(DeterministicCityState.self, from: legacyData)
        XCTAssertTrue(decoded.placedBuildings.isEmpty)
        XCTAssertEqual(decoded.calendar, city.calendar)
        XCTAssertEqual(decoded.economy, city.economy)
    }

    func testDemolishRemovesBuildingsHousesAndRoadsWithPartialRefund() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let models = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: models)
        var city = DeterministicCityState(year: 1600, treasury: 10_000, mapWidth: 12, mapHeight: 9)

        // Lay a road row across the middle of the grid.
        _ = city.buildRoad((0...11).map { GridPoint(x: $0, y: 4) }, rules: rules)
        XCTAssertTrue(city.roadNetwork.contains(GridPoint(x: 5, y: 4)))

        // Place a 3×3 warehouse beside the road and then demolish it by clicking
        // one of its footprint tiles. The treasury must regain half the cost.
        let warehouseOrigin = GridPoint(x: 5, y: 5)
        guard city.constructWarehouse(at: warehouseOrigin, rules: rules) != nil else {
            throw XCTSkip("Warehouse could not be placed on the demo grid")
        }
        XCTAssertEqual(city.placedBuildings.count, 1)
        let treasuryAfterWarehouse = city.economy.treasury
        let warehouseRefund = (rules.constructionCost(buildingID: 54, difficulty: city.difficulty) ?? 0) / 2

        let buildingOutcome = city.demolish(at: warehouseOrigin, rules: rules)
        guard case let .building(buildingID, refund) = buildingOutcome else {
            return XCTFail("Expected a building demolish outcome, got \(buildingOutcome)")
        }
        XCTAssertEqual(buildingID, 54)
        XCTAssertEqual(refund, warehouseRefund)
        XCTAssertTrue(city.placedBuildings.isEmpty)
        XCTAssertEqual(city.economy.treasury, treasuryAfterWarehouse + warehouseRefund)

        // Place a house beside the road and demolish it; the house tile clears.
        let houseLocation = GridPoint(x: 4, y: 5)
        XCTAssertNotNil(city.constructHouse(location: houseLocation, rules: rules))
        XCTAssertEqual(city.houses.count, 1)
        let houseFarCorner = GridPoint(x: houseLocation.x + 1, y: houseLocation.y + 1)
        XCTAssertTrue(city.occupiedBuildingPoints.contains(houseFarCorner))
        XCTAssertFalse(city.canConstructRoad(at: houseFarCorner))
        let houseOutcome = city.demolish(at: houseFarCorner, rules: rules)
        guard case .house = houseOutcome else {
            return XCTFail("Expected a house demolish outcome, got \(houseOutcome)")
        }
        XCTAssertTrue(city.houses.isEmpty)

        // Demolish a road tile: it clears and refunds half the road cost.
        let roadTreasury = city.economy.treasury
        let roadRefund = (rules.constructionCost(buildingID: 22, difficulty: city.difficulty) ?? 0) / 2
        let roadOutcome = city.demolish(at: GridPoint(x: 5, y: 4), rules: rules)
        guard case let .road(refund: roadRefundActual) = roadOutcome else {
            return XCTFail("Expected a road demolish outcome, got \(roadOutcome)")
        }
        XCTAssertEqual(roadRefundActual, roadRefund)
        XCTAssertFalse(city.roadNetwork.contains(GridPoint(x: 5, y: 4)))
        XCTAssertEqual(city.economy.treasury, roadTreasury + roadRefund)

        // Demolishing an empty tile changes nothing.
        let emptyOutcome = city.demolish(at: GridPoint(x: 0, y: 0), rules: rules)
        XCTAssertEqual(emptyOutcome, .nothing)
        XCTAssertFalse(emptyOutcome.removedSomething)
        XCTAssertFalse(city.canDemolish(at: GridPoint(x: 0, y: 0)))
    }

    func testDemolishRemovesEveryBackingSimulationInstance() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)

        func preparedCity() -> DeterministicCityState {
            var city = DeterministicCityState(
                year: 1600,
                treasury: 100_000,
                mapWidth: 18,
                mapHeight: 12
            )
            XCTAssertEqual(
                city.buildRoad((0..<18).map { GridPoint(x: $0, y: 1) }, rules: rules),
                18
            )
            return city
        }

        var productionCity = preparedCity()
        let productionID = try XCTUnwrap(productionCity.constructProductionBuilding(
            buildingID: 35,
            at: GridPoint(x: 1, y: 2),
            assignedWorkers: 14,
            rules: rules
        ))
        XCTAssertNotNil(productionCity.production.building(instanceID: productionID))
        _ = productionCity.demolish(at: GridPoint(x: 2, y: 3), rules: rules)
        XCTAssertNil(productionCity.production.building(instanceID: productionID))

        var warehouseCity = preparedCity()
        let warehouseID = try XCTUnwrap(warehouseCity.constructWarehouse(
            at: GridPoint(x: 1, y: 2),
            rules: rules
        ))
        XCTAssertTrue(warehouseCity.logistics.warehouses.contains { $0.id == warehouseID })
        _ = warehouseCity.demolish(at: GridPoint(x: 2, y: 3), rules: rules)
        XCTAssertFalse(warehouseCity.logistics.warehouses.contains { $0.id == warehouseID })

        var millCity = preparedCity()
        let millID = try XCTUnwrap(millCity.constructMill(
            at: GridPoint(x: 1, y: 2),
            rules: rules
        ))
        XCTAssertTrue(millCity.logistics.mills.contains { $0.id == millID })
        _ = millCity.demolish(at: GridPoint(x: 3, y: 4), rules: rules)
        XCTAssertFalse(millCity.logistics.mills.contains { $0.id == millID })

        var marketCity = preparedCity()
        let marketID = try XCTUnwrap(marketCity.constructMarket(
            at: GridPoint(x: 1, y: 2),
            shopBuildingIDs: [OriginalFoodCatalog.foodShopBuildingID],
            rules: rules
        ))
        let marketCost = [59, OriginalFoodCatalog.foodShopBuildingID].reduce(0) {
            $0 + (rules.constructionCost(buildingID: $1, difficulty: marketCity.difficulty) ?? 0)
        }
        let treasuryBeforeMarketDemolition = marketCity.economy.treasury
        let marketOutcome = marketCity.demolish(at: GridPoint(x: 4, y: 4), rules: rules)
        XCTAssertEqual(marketOutcome, .building(buildingID: 59, refund: marketCost / 2))
        XCTAssertFalse(marketCity.markets.markets.contains { $0.id == marketID })
        XCTAssertEqual(marketCity.economy.treasury, treasuryBeforeMarketDemolition + marketCost / 2)

        var tradeCity = preparedCity()
        XCTAssertTrue(tradeCity.addTradePartner(
            TradePartner(id: 71, name: "Banpo", routeKind: .land),
            rules: rules
        ))
        let tradeID = try XCTUnwrap(tradeCity.constructTradingBuilding(
            partnerID: 71,
            at: GridPoint(x: 1, y: 2),
            rules: rules
        ))
        _ = tradeCity.demolish(at: GridPoint(x: 2, y: 3), rules: rules)
        XCTAssertNil(tradeCity.trade.building(id: tradeID))
        XCTAssertTrue(tradeCity.trade.partner(id: 71)?.isOpen == true)

        var serviceCity = preparedCity()
        let serviceID = try XCTUnwrap(serviceCity.constructTaxOffice(
            at: GridPoint(x: 1, y: 2),
            replaySeed: 42,
            rules: rules
        ))
        let walkerID = try XCTUnwrap(
            serviceCity.residentialServiceBuildings.first { $0.id == serviceID }?.walkerID
        )
        _ = serviceCity.demolish(at: GridPoint(x: 2, y: 3), rules: rules)
        XCTAssertFalse(serviceCity.residentialServiceBuildings.contains { $0.id == serviceID })
        XCTAssertFalse(serviceCity.walkers.walkers.contains { $0.id == walkerID })
    }

    func testMarketShopsAreBuiltIntoExistingMarketUpToAuthoredCapacity() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 10_000,
            mapWidth: 18,
            mapHeight: 12
        )
        XCTAssertEqual(
            city.buildRoad((0..<18).map { GridPoint(x: $0, y: 1) }, rules: rules),
            18
        )
        let origin = GridPoint(x: 1, y: 2)
        let marketID = try XCTUnwrap(city.constructMarket(
            at: origin,
            shopBuildingIDs: [],
            rules: rules
        ))
        XCTAssertEqual(city.markets.markets.first?.remainingShopCapacity, 4)

        for shopBuildingID in [66, 67, 65, 70] {
            XCTAssertTrue(city.canConstructMarketShop(
                shopBuildingID: shopBuildingID,
                at: origin
            ))
            XCTAssertEqual(
                city.constructMarketShop(
                    shopBuildingID: shopBuildingID,
                    at: origin,
                    rules: rules
                ),
                marketID
            )
        }
        XCTAssertEqual(
            city.markets.markets.first?.shopBuildingIDs,
            [66, 67, 65, 70]
        )
        XCTAssertEqual(city.markets.markets.first?.remainingShopCapacity, 0)
        XCTAssertFalse(city.canConstructMarketShop(shopBuildingID: 69, at: origin))
        XCTAssertNil(city.constructMarketShop(
            shopBuildingID: 69,
            at: origin,
            rules: rules
        ))
    }

    func testDemolishCancelsInFlightDeliveryAndReleasesItsSource() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 100_000,
            mapWidth: 30,
            mapHeight: 8
        )
        XCTAssertEqual(
            city.buildRoad((0..<30).map { GridPoint(x: $0, y: 3) }, rules: rules),
            30
        )
        let producerID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            at: GridPoint(x: 0, y: 4),
            assignedWorkers: 14,
            rules: rules
        ))
        let warehouseOrigin = GridPoint(x: 24, y: 4)
        let warehouseID = try XCTUnwrap(city.constructWarehouse(
            at: warehouseOrigin,
            rules: rules
        ))

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertNotNil(city.production.building(instanceID: producerID)?.activeDeliveryWalkerID)

        _ = city.demolish(at: warehouseOrigin, rules: rules)
        XCTAssertFalse(city.logistics.warehouses.contains { $0.id == warehouseID })
        XCTAssertTrue(city.logistics.deliveryWalkers.isEmpty)
        XCTAssertNil(city.production.building(instanceID: producerID)?.activeDeliveryWalkerID)
    }

    func testSeaQuayRequiresShorelineAndRoadAccess() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        // Build a 12×8 terrain: rows 0-1 are water, rows 2-7 are clear land.
        let width = 12
        let height = 8
        var rawValues = [UInt32](repeating: 0, count: width * height)
        for y in 0..<2 {
            for x in 0..<width {
                rawValues[y * width + x] = TerrainFlags.water.rawValue
            }
        }
        let terrain = try DeterministicTerrainState(
            width: width,
            height: height,
            terrainRawValues: rawValues,
            authoredPoints: EmperorMapAuthoredPoints(
                landEntry: GridPoint(x: 0, y: 7),
                landExit: GridPoint(x: 11, y: 7),
                seaEntry: GridPoint(x: 0, y: 0),
                seaExit: GridPoint(x: 11, y: 0)
            )
        )
        XCTAssertEqual(terrain.waterTileCount, width * 2)
        XCTAssertTrue(terrain.isShoreline(GridPoint(x: 5, y: 2)))
        XCTAssertFalse(terrain.isShoreline(GridPoint(x: 5, y: 4)))

        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 10_000,
            terrain: terrain
        )
        // Build a road along row 3 (land side, adjacent to quay site at row 2).
        XCTAssertEqual(
            city.buildRoad((2...9).map { GridPoint(x: $0, y: 3) }, rules: rules),
            8
        )
        XCTAssertTrue(city.addTradePartner(
            TradePartner(id: 5, name: "Quanzhou", routeKind: .sea, supplyByCommodityID: [2: .low]),
            rules: rules
        ))
        XCTAssertNil(city.nextTradingBuildingConstructionLocation(partnerID: 5))

        // Quay at (3,2): 3×3 footprint rows 2-4, north edge borders water row 1.
        // But row 4 is land and the footprint overlaps the road at row 3.
        // Place at (3,2) with footprint rows 2,3,4 — row 3 has road, so this fails.
        XCTAssertNil(city.constructTradingBuilding(
            partnerID: 5,
            at: GridPoint(x: 3, y: 2),
            rules: rules
        ))

        // Move road to row 5 instead so the quay footprint (rows 2-4) is clear.
        var city2 = DeterministicCityState(
            year: 1600,
            treasury: 10_000,
            terrain: terrain
        )
        XCTAssertEqual(
            city2.buildRoad((2...9).map { GridPoint(x: $0, y: 5) }, rules: rules),
            8
        )
        XCTAssertTrue(city2.addTradePartner(
            TradePartner(id: 5, name: "Quanzhou", routeKind: .sea, supplyByCommodityID: [2: .low]),
            rules: rules
        ))
        XCTAssertEqual(
            city2.nextTradingBuildingConstructionLocation(partnerID: 5),
            GridPoint(x: 0, y: 2)
        )

        // Quay at (3,2): footprint rows 2-4, north edge (row 1) is all water.
        // Road access: row 5 is adjacent to row 4 (south edge of footprint).
        let quayID = city2.constructTradingBuilding(
            partnerID: 5,
            at: GridPoint(x: 3, y: 2),
            rules: rules
        )
        XCTAssertNotNil(quayID)
        let placement = try XCTUnwrap(city2.placement(category: .trading, instanceID: quayID!))
        XCTAssertEqual(placement.buildingID, 56)
        XCTAssertEqual(placement.footprint, BuildingFootprint(width: 3, height: 3))
        XCTAssertTrue(city2.roadNetwork.contains(placement.roadAccessPoint))
        XCTAssertEqual(city2.quayWaterEdge(for: placement), .north)
        XCTAssertEqual(city2.quayWaterAccessPoint(for: placement), GridPoint(x: 4, y: 1))
        let route = try XCTUnwrap(city2.tradeVisitorRoutes()[quayID!])
        XCTAssertEqual(route.points.first, GridPoint(x: 0, y: 0))
        XCTAssertEqual(route.points.last, GridPoint(x: 11, y: 0))
        XCTAssertEqual(route.points[route.facilityPointIndex], GridPoint(x: 4, y: 1))

        city2.setTradeImporting(true, commodityID: 2, tradingBuildingID: quayID!)
        _ = city2.advanceMonth(rules: rules)
        XCTAssertEqual(city2.trade.lastSettlement?.visitingPartnerIDs, [5])
        XCTAssertEqual(city2.trade.lastSettlement?.transactions.first?.amount, 1_200)
        XCTAssertEqual(city2.trade.visitors.count, 1)
        XCTAssertEqual(city2.trade.visitors.first?.currentPoint, GridPoint(x: 0, y: 0))
        XCTAssertEqual(city2.trade.visitors.first?.figureID, TradeRouteKind.sea.traderFigureID)
        XCTAssertGreaterThan(city2.advanceTradeVisitors(stepsPerVisitor: 2), 0)

        // Placement away from water fails atomically.
        let beforeInland = city2
        XCTAssertNil(city2.constructTradingBuilding(
            partnerID: 5,
            at: GridPoint(x: 3, y: 5),
            rules: rules
        ))
        XCTAssertEqual(city2, beforeInland)

        // Save round-trip preserves the quay placement.
        let decoded = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONEncoder().encode(city2)
        )
        XCTAssertEqual(decoded, city2)
    }

    func testInstalledErlitouLandTradeRouteUsesAuthoredEntryAndExit() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let map = try EmperorMap(url: source.citiesDirectory.appendingPathComponent("Erlitou.map"))
        let original = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 1600, treasury: 50_000, map: map)
        city.workforceEnabled = false
        XCTAssertTrue(city.addTradePartner(
            TradePartner(id: 77, name: "Route Probe", routeKind: .land, supplyByCommodityID: [5: .low]),
            rules: rules
        ))
        let origin = try XCTUnwrap(city.nextTradingBuildingConstructionLocation(partnerID: 77))
        let stationID = try XCTUnwrap(city.constructTradingBuilding(
            partnerID: 77,
            at: origin,
            rules: rules
        ))
        let route = try XCTUnwrap(city.tradeVisitorRoutes()[stationID])
        XCTAssertEqual(route.points.first, map.authoredPoints.landEntry)
        XCTAssertEqual(route.points.last, map.authoredPoints.landExit)
        XCTAssertEqual(route.points[route.facilityPointIndex], city.trade.building(id: stationID)?.roadAccessPoint)
        city.setTradeImporting(true, commodityID: 5, tradingBuildingID: stationID)
        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.trade.visitors.first?.route.points, route.points)
        XCTAssertFalse(city.trade.lastSettlement?.transactions.isEmpty ?? true)
    }

    func testUninspectedBuildingsUseOriginalFireAndCollapseLimits() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 1600, treasury: 50_000, mapWidth: 12, mapHeight: 8)
        city.workforceEnabled = true
        city.housingEvolutionEnabled = false
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let kilnID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 43,
            at: GridPoint(x: 0, y: 3),
            assignedWorkers: 12,
            rules: rules
        ))
        let clayID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            at: GridPoint(x: 4, y: 3),
            assignedWorkers: 14,
            rules: rules
        ))
        var failures: [BuildingFailure] = []
        for _ in 0..<100 {
            _ = city.advanceMonth(rules: rules)
            failures.append(contentsOf: city.operations.lastSettlement?.failures ?? [])
        }
        XCTAssertTrue(failures.contains {
            $0.key.instanceID == kilnID
        })
        XCTAssertTrue(failures.contains {
            $0.key.instanceID == clayID && $0.kind == .collapse
        })
        XCTAssertFalse(city.production.buildings.contains { $0.id == kilnID || $0.id == clayID })
        let kilnRuin = try XCTUnwrap(city.placedBuildings.first {
            $0.category == .production && $0.instanceID == kilnID
        })
        XCTAssertEqual(kilnRuin.buildingID, OriginalBuildingSpriteCatalog.ruinBuildingID)
        let collapseRuin = try XCTUnwrap(city.placedBuildings.first {
            $0.category == .production && $0.instanceID == clayID
        })
        XCTAssertEqual(collapseRuin.buildingID, OriginalBuildingSpriteCatalog.ruinBuildingID)
        XCTAssertEqual(collapseRuin.footprint, BuildingFootprint(width: 2, height: 2))
        XCTAssertEqual(city.operations.lastSettlement?.workforce.availableWorkers, 0)
    }

    func testOriginalMaintenanceUsesSlottedVariableFireChecksAndInclusiveCollapsePriority() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let model = try XCTUnwrap(original.buildings[buildingID: 43])
        XCTAssertGreaterThan(model.fireRiskIncrement, 0)
        XCTAssertGreaterThan(model.damageRiskIncrement, 0)
        let placement = PlacedBuilding(
            category: .production,
            instanceID: 17,
            buildingID: model.id,
            origin: GridPoint(x: 3, y: 4),
            orientation: .northSouth,
            footprint: BuildingFootprint(width: 2, height: 2),
            roadAccessPoint: GridPoint(x: 3, y: 6)
        )
        let workforce = DeterministicCityOperationsState().workforce(
            population: 0,
            placements: [placement],
            models: original.buildings
        )
        let highLimits = OriginalBuildingHazardRules(configuration: LegacyINI(text: """
            [Fire]
            Multiplier=5
            Frequency=4
            BurnLimit=1000000
            BurnDamage=100
            FireDamageMult=10
            [Damage]
            DamageLimit=1000000
            """))
        var first = DeterministicCityOperationsState()
        var second = DeterministicCityOperationsState()
        var observedFireMultipliers: [Int] = []
        for offset in 0..<64 {
            let calendar = SimulationCalendar(year: 1600 + offset / 12, month: offset % 12 + 1)
            let before = first.risks.first?.fireRisk ?? 0
            _ = first.advanceMonth(
                calendar: calendar,
                workforce: workforce,
                placements: [placement],
                inspectedBuildingKeys: [],
                maintenanceRiskReduction: 0,
                models: original.buildings,
                difficulty: .normal,
                hazardRules: highLimits
            )
            _ = second.advanceMonth(
                calendar: calendar,
                workforce: workforce,
                placements: [placement],
                inspectedBuildingKeys: [],
                maintenanceRiskReduction: 0,
                models: original.buildings,
                difficulty: .normal,
                hazardRules: highLimits
            )
            let delta = try XCTUnwrap(first.risks.first).fireRisk - before
            if delta > 0 {
                XCTAssertEqual(delta % model.fireRiskIncrement, 0)
                observedFireMultipliers.append(delta / model.fireRiskIncrement)
            }
        }
        XCTAssertEqual(first, second)
        XCTAssertFalse(observedFireMultipliers.isEmpty)
        XCTAssertTrue(observedFireMultipliers.allSatisfy { (1...5).contains($0) })
        XCTAssertLessThan(observedFireMultipliers.count, 64)

        let exactLimits = OriginalBuildingHazardRules(configuration: LegacyINI(text: """
            [Fire]
            Multiplier=1
            Frequency=1
            BurnLimit=\(model.fireRiskIncrement)
            BurnDamage=100
            FireDamageMult=10
            [Damage]
            DamageLimit=\(model.damageRiskIncrement)
            """))
        var thresholdState = DeterministicCityOperationsState()
        let settlement = thresholdState.advanceMonth(
            calendar: SimulationCalendar(year: 1600),
            workforce: workforce,
            placements: [placement],
            inspectedBuildingKeys: [],
            maintenanceRiskReduction: 0,
            models: original.buildings,
            difficulty: .normal,
            hazardRules: exactLimits
        )
        XCTAssertEqual(settlement.failures.first?.kind, .collapse)

        let fireOnlyLimits = OriginalBuildingHazardRules(configuration: LegacyINI(text: """
            [Fire]
            Multiplier=1
            Frequency=1
            BurnLimit=\(model.fireRiskIncrement)
            BurnDamage=100
            FireDamageMult=10
            [Damage]
            DamageLimit=1000000
            """))
        var fireThresholdState = DeterministicCityOperationsState()
        let fireSettlement = fireThresholdState.advanceMonth(
            calendar: SimulationCalendar(year: 1600),
            workforce: workforce,
            placements: [placement],
            inspectedBuildingKeys: [],
            maintenanceRiskReduction: 0,
            models: original.buildings,
            difficulty: .normal,
            hazardRules: fireOnlyLimits
        )
        XCTAssertEqual(fireSettlement.failures.first?.kind, .fire)
    }

    func testUninspectedHouseParticipatesInOriginalMaintenanceRisk() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 50_000,
            mapWidth: 12,
            mapHeight: 8
        )
        city.workforceEnabled = true
        city.housingEvolutionEnabled = false
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            residents: 7,
            location: GridPoint(x: 2, y: 3),
            models: original.buildings
        ))

        var observedFailure: BuildingFailure?
        for _ in 0..<120 where observedFailure == nil {
            _ = city.advanceMonth(rules: rules)
            observedFailure = city.operations.lastSettlement?.failures.first {
                $0.key == OperationalBuildingKey(category: .residential, instanceID: houseID)
            }
        }

        XCTAssertFalse(city.houses.contains { $0.id == houseID })
        let ruin = try XCTUnwrap(city.placedBuildings.first {
            $0.category == .residential && $0.instanceID == houseID
        })
        XCTAssertEqual(ruin.buildingID, OriginalBuildingSpriteCatalog.ruinBuildingID)
        XCTAssertEqual(ruin.footprint, BuildingFootprint(width: 2, height: 2))
        XCTAssertEqual(observedFailure?.cause, .maintenance)
    }

    func testCityBreachDoesNotInventBatchBuildingFires() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 50_000,
            mapWidth: 12,
            mapHeight: 8
        )
        city.housingEvolutionEnabled = false
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            residents: 7,
            location: GridPoint(x: 2, y: 3),
            models: original.buildings
        ))
        let kilnID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 43,
            at: GridPoint(x: 6, y: 3),
            rules: rules
        ))
        let invasion = CampaignEventOccurrence(
            eventID: 7,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.invasion.rawValue,
            triggerMode: .oneTime,
            relativeYear: 0,
            month: 1,
            amount: 16
        )
        _ = city.applyCampaignCityEvent(invasion)

        let movement = city.advanceMilitary(
            maximumStepsPerUnit: 100,
            models: original.figures
        )

        XCTAssertEqual(movement.reports.first?.outcome, .cityBreached)
        XCTAssertTrue(city.houses.contains { $0.id == houseID })
        XCTAssertTrue(city.production.buildings.contains { $0.id == kilnID })
        XCTAssertEqual(
            city.placedBuildings.filter {
                $0.buildingID == OriginalBuildingSpriteCatalog.ruinBuildingID
            }.count,
            0
        )
        XCTAssertNil(city.operations.lastSettlement)
    }

    func testInspectorFSMStaysFailClosedUntilItsOriginalHandlerIsRecovered() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 1600, treasury: 50_000, mapWidth: 12, mapHeight: 8)
        city.workforceEnabled = true
        city.housingEvolutionEnabled = false
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let residentHouseID = try XCTUnwrap(city.addHouse(
            levelID: 14,
            residents: 100,
            location: GridPoint(x: 11, y: 4),
            models: original.buildings
        ))
        XCTAssertGreaterThanOrEqual(city.population, 17)
        let kilnID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 43,
            at: GridPoint(x: 0, y: 3),
            assignedWorkers: 12,
            rules: rules
        ))
        let inspectorID = try XCTUnwrap(city.constructResidentialServiceBuilding(
            buildingID: 124,
            at: GridPoint(x: 4, y: 3),
            replaySeed: 0x494E_5350_4543_54,
            rules: rules
        ))
        _ = city.advanceTick(rules: rules)
        XCTAssertTrue(city.production.buildings.contains { $0.id == kilnID })
        XCTAssertTrue(city.residentialServiceBuildings.contains { $0.id == inspectorID })
        let walker = try XCTUnwrap(city.walkers.walkers.first { $0.figureID == 39 })
        XCTAssertFalse(walker.supportsRecoveredResidentialRoam)
        XCTAssertEqual(walker.originalPhase, .dormant)
        XCTAssertNil(city.operations.lastSettlement)
        XCTAssertTrue(city.houses.contains { $0.id == residentHouseID })
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testEntertainmentFiguresKeepRecoveredVisitSelectorWhileRoamStaysFailClosed() {
        let road = RoadNetwork(width: 8, height: 8)
        let cases: [(figureID: Int, selector: Int)] = [(32, 3), (33, 3), (34, 3)]
        for item in cases {
            let walker = RoadServiceWalker(
                id: item.figureID,
                figureID: item.figureID,
                service: .music,
                origin: GridPoint(x: 1, y: 1),
                maximumRoadSteps: 36,
                replaySeed: UInt64(item.figureID),
                roadNetwork: road,
                startsDormant: true
            )
            XCTAssertEqual(walker.originalVisitFieldSelector, item.selector)
            XCTAssertFalse(walker.supportsRecoveredResidentialRoam)
            XCTAssertEqual(walker.originalPhase, .dormant)
        }
    }

    func testRecoveredHouseHealthAggregateUsesExactBucketsAndPrecedence() {
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0), 0)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(1), 1)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x1D), 1)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x1E), 2)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x31), 2)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x32), 3)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x45), 3)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x46), 4)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x59), 4)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x5A), 5)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(0x100), 0)
        XCTAssertEqual(OriginalHouseHealthAggregate.foodQualityBucket(-1), 5)

        XCTAssertEqual(
            OriginalHouseHealthAggregate.healthScore(
                field2A: 1,
                field2D: 1,
                field32: 1,
                field34: 1,
                foodQualityRaw: 0x5A
            ),
            100,
            "field34's 15 points must take precedence over field32's 5"
        )
        XCTAssertEqual(
            OriginalHouseHealthAggregate.goodsScore(field2B: 1, field2C: 1, field2E: 1),
            99
        )
        XCTAssertEqual(
            OriginalHouseHealthAggregate.populationScaledContribution(score: 1, population: 1),
            1,
            "positive score/population has a minimum contribution of one"
        )
        XCTAssertEqual(
            OriginalHouseHealthAggregate.populationScaledContribution(score: 0, population: 100),
            0
        )
        XCTAssertEqual(
            OriginalHouseHealthAggregate.populationScaledContribution(score: 100, population: 0x1_0001),
            1,
            "the original population input is a signed 16-bit short"
        )
    }

    func testRecoveredNaturalHealthPopulationPlanUsesSourceIntervalsAndLowerClassPath() {
        let cases: [(health: Int, rate: Int, direction: OriginalNaturalHealthPopulationPlan.Direction)] = [
            (0, 0, .none),
            (1, -5, .removeLowerClassResidents),
            (10, -5, .removeLowerClassResidents),
            (11, -3, .removeLowerClassResidents),
            (20, -3, .removeLowerClassResidents),
            (21, -2, .removeLowerClassResidents),
            (30, -2, .removeLowerClassResidents),
            (31, -1, .removeLowerClassResidents),
            (40, -1, .removeLowerClassResidents),
            (41, 1, .addLowerClassResidents),
            (50, 1, .addLowerClassResidents),
            (51, 2, .addLowerClassResidents),
            (60, 2, .addLowerClassResidents),
            (61, 3, .addLowerClassResidents),
            (70, 3, .addLowerClassResidents),
            (71, 4, .addLowerClassResidents),
            (80, 4, .addLowerClassResidents),
            (81, 6, .addLowerClassResidents),
            (100, 6, .addLowerClassResidents),
        ]
        for item in cases {
            let plan = OriginalNaturalHealthPopulationAdjustment.plan(
                naturalHealth: item.health,
                currentPopulation: 1_000
            )
            XCTAssertEqual(plan.naturalHealth, item.health)
            XCTAssertEqual(plan.ratePercent, item.rate)
            XCTAssertEqual(plan.direction, item.direction)
            XCTAssertEqual(plan.requestedResidents, abs(item.rate) * 10)
        }

        XCTAssertEqual(
            OriginalNaturalHealthPopulationAdjustment.plan(
                naturalHealth: 50,
                currentPopulation: 99
            ).requestedResidents,
            0,
            "FUN_00408B80 truncates the population percentage toward zero"
        )
        XCTAssertEqual(
            OriginalNaturalHealthPopulationAdjustment.plan(
                naturalHealth: 1,
                currentPopulation: 101
            ).requestedResidents,
            5,
            "the negative branch scales the same magnitude before FUN_00517E90 removes lower-class residents"
        )
    }

    func testRecoveredNaturalHealthAggregatePreservesPopulationCorrectionAndUpperClamp() {
        let lowPopulation = OriginalNaturalHealthAggregate.aggregate(
            totalPopulation: 1,
            weightedHealthSum: 0,
            bonusEnabled: false
        )
        XCTAssertEqual(lowPopulation.populationCorrection, 99)
        XCTAssertEqual(lowPopulation.bonus, 0)
        XCTAssertEqual(lowPopulation.naturalHealth, 99)

        let boundary = OriginalNaturalHealthAggregate.aggregate(
            totalPopulation: 999,
            weightedHealthSum: 999,
            bonusEnabled: true
        )
        XCTAssertEqual(boundary.populationCorrection, 0)
        XCTAssertEqual(boundary.bonus, 10)
        XCTAssertEqual(boundary.naturalHealth, 100,
                       "FUN_00518490 returns the upper-capped value")

        let noPopulation = OriginalNaturalHealthAggregate.aggregate(
            totalPopulation: 0,
            weightedHealthSum: 10_000,
            bonusEnabled: true
        )
        XCTAssertEqual(noPopulation.naturalHealth, 100,
                       "the source returns 100 when no positive population is enumerated")

        let signedAverage = OriginalNaturalHealthAggregate.aggregate(
            totalPopulation: 3,
            weightedHealthSum: -2,
            bonusEnabled: false
        )
        XCTAssertEqual(signedAverage.naturalHealth, 33,
                       "the average and low-population correction use signed integer division")
    }

    func testRecoveredNaturalHealthPopulationDistributorPreservesCursorAndWrapOrder() {
        let houses = [
            OriginalNaturalHealthPopulationHouse(
                vectorIndex: 1,
                passesGlobalAndHouseGate: true,
                classPredicate: false,
                gateWord24: 1,
                availableResidentCapacity: 2
            ),
            OriginalNaturalHealthPopulationHouse(
                vectorIndex: 2,
                passesGlobalAndHouseGate: true,
                classPredicate: false,
                gateWord24: 1,
                availableResidentCapacity: 4
            ),
            OriginalNaturalHealthPopulationHouse(
                vectorIndex: 3,
                passesGlobalAndHouseGate: true,
                classPredicate: true,
                gateWord24: 1,
                availableResidentCapacity: 8
            ),
        ]

        let plan = OriginalNaturalHealthPopulationDistributor.plan(
            request: 7,
            classSelectorIsUpper: false,
            startCursor: 2,
            vectorCount: 4,
            houses: houses
        )

        XCTAssertEqual(
            plan.assignments,
            [
                .init(vectorIndex: 1, peopleCount: 2),
                .init(vectorIndex: 2, peopleCount: 4),
            ],
            "the source increments before lookup, wraps, and selects only the requested class"
        )
        XCTAssertEqual(plan.appliedResidents, 6)
        XCTAssertEqual(plan.remainingRequest, 1)
        XCTAssertEqual(plan.nextCursor, 2)
    }

    func testRecoveredNaturalHealthPopulationDistributorCapsWritesAndSkipsGates() {
        let plan = OriginalNaturalHealthPopulationDistributor.plan(
            request: 9,
            classSelectorIsUpper: false,
            startCursor: 0,
            vectorCount: 5,
            houses: [
                .init(vectorIndex: 1, passesGlobalAndHouseGate: false, classPredicate: false, gateWord24: 1, availableResidentCapacity: 9),
                .init(vectorIndex: 2, passesGlobalAndHouseGate: true, classPredicate: false, gateWord24: 0, availableResidentCapacity: 9),
                .init(vectorIndex: 3, passesGlobalAndHouseGate: true, classPredicate: false, gateWord24: 1, availableResidentCapacity: 3),
                .init(vectorIndex: 4, passesGlobalAndHouseGate: true, classPredicate: false, gateWord24: 1, availableResidentCapacity: 4),
            ]
        )

        XCTAssertEqual(
            plan.assignments,
            [
                .init(vectorIndex: 3, peopleCount: 3),
                .init(vectorIndex: 4, peopleCount: 4),
            ]
        )
        XCTAssertEqual(plan.appliedResidents, 7)
        XCTAssertEqual(plan.remainingRequest, 2)
        XCTAssertEqual(plan.nextCursor, 4)
    }

    func testRecoveredNaturalHealthPopulationRemovalPlannerDrainsOneResidentPerWrite() {
        let plan = OriginalNaturalHealthPopulationRemovalPlanner.plan(
            request: 3,
            classSelectorIsUpper: false,
            startCursor: 2,
            vectorCount: 4,
            houses: [
                .init(vectorIndex: 1, passesGlobalAndHouseGate: true, classPredicate: false, residentCount: 2),
                .init(vectorIndex: 2, passesGlobalAndHouseGate: true, classPredicate: false, residentCount: 1),
                .init(vectorIndex: 3, passesGlobalAndHouseGate: true, classPredicate: true, residentCount: 8),
            ]
        )

        XCTAssertEqual(
            plan.assignments,
            [
                .init(vectorIndex: 1),
                .init(vectorIndex: 2),
                .init(vectorIndex: 1),
            ],
            "the source increments before lookup, wraps to index 1, and removes one resident per successful visit"
        )
        XCTAssertEqual(plan.removedResidents, 3)
        XCTAssertEqual(plan.remainingRequest, 0)
        XCTAssertEqual(plan.nextCursor, 1)
    }

    func testRecoveredNaturalHealthPopulationRemovalPlannerPreservesGatesAndCursorOnNoWrite() {
        let plan = OriginalNaturalHealthPopulationRemovalPlanner.plan(
            request: 3,
            classSelectorIsUpper: false,
            startCursor: 0,
            vectorCount: 5,
            houses: [
                .init(vectorIndex: 1, passesGlobalAndHouseGate: false, classPredicate: false, residentCount: 4),
                .init(vectorIndex: 2, passesGlobalAndHouseGate: true, classPredicate: true, residentCount: 4),
                .init(vectorIndex: 3, passesGlobalAndHouseGate: true, classPredicate: false, residentCount: 0),
                .init(vectorIndex: 4, passesGlobalAndHouseGate: true, classPredicate: false, residentCount: -1),
            ]
        )

        XCTAssertTrue(plan.assignments.isEmpty)
        XCTAssertEqual(plan.removedResidents, 0)
        XCTAssertEqual(plan.remainingRequest, 3)
        XCTAssertEqual(plan.nextCursor, 0)
    }

    func testOriginalHouseDiseaseAndCrimeIncidentsRemainFailClosed() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        var exposedHouses = [ResidentialUnit(
            id: 1,
            houseLevelID: 0,
            residents: 10,
            suppliesByCommodityID: [25: 100]
        )]
        var exposed = DeterministicPublicHealthSafetyState()
        let exposedBefore = exposedHouses
        let exposedSettlement = exposed.advanceMonth(
            calendar: SimulationCalendar(year: 1600, month: 1),
            houses: &exposedHouses,
            models: original.buildings
        )
        XCTAssertTrue(exposedSettlement.events.isEmpty)
        XCTAssertEqual(exposedSettlement.diseaseDeaths, 0)
        XCTAssertEqual(exposedSettlement.stolenCash, 0)
        XCTAssertEqual(exposedSettlement.medicallyCoveredHouseIDs, [])
        XCTAssertEqual(exposedSettlement.protectedHouseIDs, [])
        XCTAssertEqual(exposedHouses, exposedBefore)

        var protectedHouses = [ResidentialUnit(
            id: 2,
            houseLevelID: 0,
            residents: 10,
            hasTaxCoverage: true,
            foodSupplyAmount: 1_000,
            serviceCoverage: [.water, .herbalist, .acupuncture, .constable]
        )]
        var protected = DeterministicPublicHealthSafetyState()
        let protectedBefore = protectedHouses
        let protectedSettlement = protected.advanceMonth(
            calendar: SimulationCalendar(year: 1600, month: 1),
            houses: &protectedHouses,
            models: original.buildings
        )
        XCTAssertTrue(protectedSettlement.events.isEmpty)
        XCTAssertEqual(protectedSettlement.diseaseDeaths, 0)
        XCTAssertEqual(protectedSettlement.stolenCash, 0)
        XCTAssertEqual(protectedHouses, protectedBefore)
        XCTAssertEqual(protectedHouses[0].residents, 10)
    }

    func testWatchtowerGuardFSMStaysFailClosedUntilItsOriginalHandlerIsRecovered() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 1600, treasury: 20_000, mapWidth: 12, mapHeight: 8)
        city.publicSafetyEnabled = true
        city.housingEvolutionEnabled = false
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            residents: 7,
            location: GridPoint(x: 0, y: 4),
            models: original.buildings
        ))
        let towerID = try XCTUnwrap(city.constructResidentialServiceBuilding(
            buildingID: 127,
            at: GridPoint(x: 4, y: 3),
            replaySeed: 0x5741_5443_4854_52,
            rules: rules
        ))
        _ = city.advanceMonth(rules: rules)
        XCTAssertTrue(city.residentialServiceBuildings.contains {
            $0.id == towerID && $0.figureID == 29 && $0.service == .constable
        })
        let walker = try XCTUnwrap(city.walkers.walkers.first { $0.figureID == 29 })
        XCTAssertFalse(walker.supportsRecoveredResidentialRoam)
        XCTAssertEqual(walker.originalPhase, .dormant)
        XCTAssertFalse(city.houses.first { $0.id == houseID }?.serviceCoverage.contains(.constable) == true)
        XCTAssertFalse(city.publicHealthSafety.lastSettlement?.protectedHouseIDs.contains(houseID) == true)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testCampaignInvasionUsesAuthoredEntryAndCityEventsPersist() throws {
        let authoredEntry = GridPoint(x: 0, y: 6)
        let authoredInvasion = GridPoint(x: 1, y: 6)
        let terrain = try DeterministicTerrainState(
            width: 10,
            height: 7,
            terrainRawValues: [UInt32](repeating: 0, count: 70),
            authoredPoints: EmperorMapAuthoredPoints(
                landEntry: authoredEntry,
                landInvasion: [authoredInvasion]
            )
        )
        var city = DeterministicCityState(year: 1600, treasury: 1_000, terrain: terrain)
        let invasion = CampaignEventOccurrence(
            eventID: 4,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.invasion.rawValue,
            triggerMode: .oneTime,
            relativeYear: 1,
            month: 3,
            amount: 24,
            cityFromID: 9
        )
        let invasionApplication = city.applyCampaignCityEvent(invasion)
        XCTAssertEqual(invasionApplication.invasionAlertID, invasion.id)
        XCTAssertEqual(city.campaignEvents.invasions.first?.entryPoint, authoredInvasion)
        XCTAssertEqual(city.campaignEvents.invasions.first?.strength, 24)
        XCTAssertEqual(city.campaignEvents.invasions.first?.status, .awaitingDefense)

        let status = CampaignEventOccurrence(
            eventID: 5,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.cityStatusChange.rawValue,
            triggerMode: .oneTime,
            relativeYear: 1,
            month: 3,
            cityFromID: 9,
            statusChangeCode: 3
        )
        XCTAssertTrue(city.applyCampaignCityEvent(status).cityStatusApplied)
        XCTAssertEqual(city.campaignEvents.statusChangeCodeByCityID[9], 3)

        let message = CampaignEventOccurrence(
            eventID: 6,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.cityMessage.rawValue,
            triggerMode: .oneTime,
            relativeYear: 1,
            month: 3,
            productID: 11,
            amount: 2,
            cityFromID: 9
        )
        XCTAssertTrue(city.applyCampaignCityEvent(message).messageRecorded)
        XCTAssertEqual(city.campaignEvents.messages.last?.productID, 11)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testCampaignDisasterDestroysNearestBuildingAndDroughtExpires() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let disasterPoint = GridPoint(x: 4, y: 3)
        let terrain = try DeterministicTerrainState(
            width: 12,
            height: 8,
            terrainRawValues: [UInt32](repeating: 0, count: 96),
            authoredPoints: EmperorMapAuthoredPoints(disasters: [disasterPoint])
        )
        var city = DeterministicCityState(
            year: 1600,
            treasury: 50_000,
            terrain: terrain
        )
        city.workforceEnabled = false
        city.housingEvolutionEnabled = false
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 5) }, rules: rules)
        let kilnID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 43,
            at: GridPoint(x: 0, y: 3),
            assignedWorkers: 12,
            rules: rules
        ))
        let clayID = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            at: disasterPoint,
            assignedWorkers: 14,
            rules: rules
        ))
        let earthquake = CampaignEventOccurrence(
            eventID: 0,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.earthquake.rawValue,
            triggerMode: .oneTime,
            relativeYear: 0,
            month: 1,
            amount: 1
        )
        let application = city.applyCampaignCityEvent(earthquake)
        XCTAssertEqual(application.destroyedBuildingKeys, [
            OperationalBuildingKey(category: .production, instanceID: clayID)
        ])
        XCTAssertTrue(city.production.buildings.contains { $0.id == kilnID })
        XCTAssertFalse(city.production.buildings.contains { $0.id == clayID })
        XCTAssertEqual(
            city.placedBuildings.first {
                $0.category == .production && $0.instanceID == clayID
            }?.buildingID,
            OriginalBuildingSpriteCatalog.ruinBuildingID
        )
        XCTAssertEqual(
            city.operations.lastSettlement?.failures.first?.cause,
            .disaster
        )
        XCTAssertEqual(city.campaignEvents.disasters.last?.epicenter, disasterPoint)

        let drought = CampaignEventOccurrence(
            eventID: 2,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.drought.rawValue,
            triggerMode: .oneTime,
            relativeYear: 0,
            month: 1,
            amount: 2
        )
        XCTAssertEqual(city.applyCampaignCityEvent(drought).condition, .drought)
        XCTAssertEqual(city.campaignEvents.conditions.agriculturalYieldPercent, 50)
        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.campaignEvents.conditions.agriculturalYieldPercent, 50)
        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.campaignEvents.conditions.agriculturalYieldPercent, 100)
    }

    func testMilitaryFortMarchesToAuthoredInvasionAndResolvesOriginalCombat() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        XCTAssertEqual(original.figures[figureID: 64]?.name.trimmingCharacters(in: .whitespaces), "Friendly infantry")
        XCTAssertEqual(original.figures[enemyTypeID: 0]?.name, "Chinese Infantry")
        XCTAssertEqual(original.figures[enemyTypeID: 0]?.hitPoints, 150)

        let invasionPoint = GridPoint(x: 15, y: 6)
        let terrain = try DeterministicTerrainState(
            width: 16,
            height: 10,
            terrainRawValues: [UInt32](repeating: 0, count: 160),
            authoredPoints: EmperorMapAuthoredPoints(landInvasion: [invasionPoint])
        )
        var city = DeterministicCityState(
            year: 1600,
            treasury: 50_000,
            terrain: terrain
        )
        _ = city.buildRoad((0..<16).map { GridPoint(x: $0, y: 6) }, rules: rules)
        let fortID = try XCTUnwrap(city.constructMilitaryFort(
            buildingID: 221,
            at: GridPoint(x: 0, y: 2),
            rules: rules
        ))
        let unit = try XCTUnwrap(city.military.units.first)
        XCTAssertEqual(city.military.forts.first?.id, fortID)
        XCTAssertEqual(unit.figureID, 64)
        XCTAssertEqual(unit.originalSoldierCount, 16)

        let invasion = CampaignEventOccurrence(
            eventID: 0,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.invasion.rawValue,
            triggerMode: .oneTime,
            relativeYear: 0,
            month: 1,
            amount: 8,
            cityFromID: 2
        )
        _ = city.applyCampaignCityEvent(invasion)
        let movement = city.advanceMilitary(
            maximumStepsPerUnit: 100,
            models: original.figures
        )
        let report = try XCTUnwrap(movement.reports.first)
        XCTAssertEqual(report.outcome, .repelled)
        XCTAssertEqual(report.enemySoldiersBefore, 8)
        XCTAssertEqual(report.enemySoldiersLost, 8)
        XCTAssertGreaterThan(report.friendlySoldiersLost, 0)
        XCTAssertEqual(city.campaignEvents.invasions.first?.status, .repelled)
        XCTAssertEqual(
            city.military.units.first?.currentPoint,
            city.military.enemyForces.first?.targetPoint
        )
        XCTAssertEqual(city.military.units.first?.status, .victorious)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )

        _ = city.demolish(at: GridPoint(x: 0, y: 2), rules: rules)
        XCTAssertTrue(city.military.forts.isEmpty)
        XCTAssertTrue(city.military.units.isEmpty)
    }

    func testVersion075EnemyManeuversFromAuthoredEntryDoesNotInventSiegeEngines() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let invasionPoint = GridPoint(x: 19, y: 6)
        let terrain = try DeterministicTerrainState(
            width: 20,
            height: 10,
            terrainRawValues: [UInt32](repeating: 0, count: 200),
            authoredPoints: EmperorMapAuthoredPoints(landInvasion: [invasionPoint])
        )
        var city = DeterministicCityState(year: 1600, treasury: 80_000, terrain: terrain)
        _ = city.buildRoad((0..<20).map { GridPoint(x: $0, y: 6) }, rules: rules)
        _ = try XCTUnwrap(city.constructMilitaryFort(
            buildingID: 221,
            at: GridPoint(x: 0, y: 2),
            rules: rules
        ))
        _ = city.applyCampaignCityEvent(CampaignEventOccurrence(
            eventID: 75,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.invasion.rawValue,
            triggerMode: .oneTime,
            relativeYear: 0,
            month: 1,
            amount: 64,
            cityFromID: 2
        ))

        let first = city.advanceMilitary(maximumStepsPerUnit: 1, models: original.figures)
        XCTAssertTrue(first.reports.isEmpty)
        XCTAssertEqual(first.enemyMovedSteps, 1)
        let maneuvering = try XCTUnwrap(city.military.enemyForces.first)
        XCTAssertEqual(maneuvering.currentPoint, GridPoint(x: 18, y: 6))
        XCTAssertEqual(maneuvering.targetPoint, GridPoint(x: 0, y: 6))
        XCTAssertEqual(maneuvering.siegeEngineCount, 0)
        XCTAssertEqual(maneuvering.status, .maneuvering)

        let battle = city.advanceMilitary(maximumStepsPerUnit: 100, models: original.figures)
        let report = try XCTUnwrap(battle.reports.first)
        XCTAssertEqual(report.enemySiegeEngineCount, 0)
        XCTAssertNotEqual(city.military.enemyForces.first?.status, .maneuvering)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testQinNomadInvasionRetainsSecondarySelectorAndUsesAuthoredEnemyInfantry() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let invasionPoint = GridPoint(x: 9, y: 4)
        let terrain = try DeterministicTerrainState(
            width: 10,
            height: 8,
            terrainRawValues: [UInt32](repeating: 0, count: 80),
            authoredPoints: EmperorMapAuthoredPoints(landInvasion: [invasionPoint])
        )
        var city = DeterministicCityState(year: -209, treasury: 18_000, terrain: terrain)
        _ = city.buildRoad((0..<10).map { GridPoint(x: $0, y: 4) }, rules: rules)
        _ = try XCTUnwrap(city.constructMilitaryFort(
            buildingID: 221,
            at: GridPoint(x: 0, y: 0),
            rules: rules
        ))
        let occurrence = CampaignEventOccurrence(
            eventID: 2,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.invasion.rawValue,
            triggerMode: .oneTime,
            relativeYear: 6,
            month: 6,
            amount: 9,
            cityFromID: 0,
            secondarySelectionID: 10,
            timeAllowed: 6
        )

        _ = city.applyCampaignCityEvent(occurrence)
        XCTAssertEqual(city.campaignEvents.invasions.first?.secondarySelectionID, 10)
        XCTAssertEqual(city.campaignEvents.invasions.first?.strength, 9)
        _ = city.advanceMilitary(maximumStepsPerUnit: 1, models: original.figures)
        let force = try XCTUnwrap(city.military.enemyForces.first)
        XCTAssertEqual(force.enemyTypeID, 58)
        XCTAssertEqual(force.soldierCount, 9)
        XCTAssertEqual(force.route.first, invasionPoint)
        XCTAssertEqual(
            city.warCount,
            0,
            "aggregate invasion strength is not a recovered DAT_01312564 figure count"
        )
    }

    func testOriginalWarFigureCatalogMatchesExecutableGate() {
        XCTAssertEqual(
            OriginalWarFigureCatalog.contributingModelIDs,
            Set([58, 59, 60, 61, 62, 78])
        )
        for modelID in [58, 59, 60, 61, 62, 78] {
            XCTAssertTrue(OriginalWarFigureCatalog.contributesToWarCount(modelID: modelID))
        }
        for modelID in [0, 6, 57, 63, 64, 68, 77, 79] {
            XCTAssertFalse(OriginalWarFigureCatalog.contributesToWarCount(modelID: modelID))
        }
    }

    func testOriginalWarFigureLedgerMirrorsPerFigureLifecycleAndReset() {
        var ledger = OriginalWarFigureLedger()
        XCTAssertEqual(ledger.count, 0)

        XCTAssertEqual(ledger.apply(modelID: 58, created: true), 1)
        XCTAssertEqual(ledger.apply(modelID: 78, created: true), 2)
        XCTAssertEqual(ledger.apply(modelID: 64, created: true), 2)
        XCTAssertEqual(ledger.apply(modelID: 59, created: false), 1)
        XCTAssertEqual(ledger.apply(modelID: 59, created: false), 0)
        XCTAssertEqual(ledger.apply(modelID: 59, created: false), 0)

        ledger = OriginalWarFigureLedger(count: -10)
        XCTAssertEqual(ledger.count, 0)
        ledger.apply(modelID: 60, created: true)
        ledger.reset()
        XCTAssertEqual(ledger.count, 0)
    }

    func testOriginalMilitaryDefenseStaffingUsesSourceCapsAndVectorOrder() {
        XCTAssertEqual(
            OriginalMilitaryDefenseStaffingCatalog.workerCapByBuildingID,
            [130: 9, 131: 6]
        )
        let candidates = [
            OriginalMilitaryDefenseStaffingCandidate(
                vectorIndex: 1,
                buildingID: 130
            ),
            // Source skips a row whose +0x6E no-labor byte is set.
            OriginalMilitaryDefenseStaffingCandidate(
                vectorIndex: 2,
                buildingID: 131,
                noLaborFlag: true
            ),
            OriginalMilitaryDefenseStaffingCandidate(
                vectorIndex: 3,
                buildingID: 131
            ),
            // A later row cannot overtake an earlier eligible row.
            OriginalMilitaryDefenseStaffingCandidate(
                vectorIndex: 4,
                buildingID: 130
            )
        ]

        let assignments = OriginalMilitaryDefenseStaffingCatalog.plan(
            globalGateOpen: true,
            laborAllocatorGateOpen: true,
            sourceLaborAvailable: 12,
            candidates: candidates
        )
        XCTAssertEqual(
            assignments,
            [
                .init(vectorIndex: 1, buildingID: 130, assignedWorkers: 9),
                .init(vectorIndex: 3, buildingID: 131, assignedWorkers: 3)
            ]
        )
        XCTAssertTrue(
            OriginalMilitaryDefenseStaffingCatalog.plan(
                globalGateOpen: false,
                laborAllocatorGateOpen: true,
                sourceLaborAvailable: 100,
                candidates: candidates
            ).isEmpty
        )
        XCTAssertTrue(
            OriginalMilitaryDefenseStaffingCatalog.plan(
                globalGateOpen: true,
                laborAllocatorGateOpen: false,
                sourceLaborAvailable: 100,
                candidates: candidates
            ).isEmpty
        )
        XCTAssertNil(OriginalMilitaryDefenseStaffingCatalog.workerCap(forBuildingID: 129))
    }

    func testOriginalMilitaryDefenseLaborPoolUsesRecoveredTablesAndIntegerPercentage() {
        XCTAssertEqual(
            OriginalMilitaryDefenseLaborPoolCatalog.basePercentageByDifficultyIndex,
            [50, 45, 40, 37, 35]
        )
        XCTAssertEqual(
            OriginalMilitaryDefenseLaborPoolCatalog.rawAdjustmentBySourceIndex,
            [-10, -6, -3, 0, 3, 5, -2]
        )
        XCTAssertEqual(
            OriginalMilitaryDefenseLaborPoolCatalog.popularityBandAdjustment,
            [-2, -1, 0, 1, 2]
        )
        XCTAssertEqual(
            OriginalMilitaryDefenseLaborPoolCatalog.percentage(
                difficultyIndex: 0,
                sourceAdjustmentIndex: 0,
                popularityBandIndex: 0
            ),
            38
        )
        XCTAssertEqual(
            OriginalMilitaryDefenseLaborPoolCatalog.availableLabor(
                positiveObjectWorkerTotal: 101,
                difficultyIndex: 0,
                sourceAdjustmentIndex: 0,
                popularityBandIndex: 0
            ),
            38
        )
        XCTAssertNil(
            OriginalMilitaryDefenseLaborPoolCatalog.availableLabor(
                positiveObjectWorkerTotal: 10,
                difficultyIndex: 5,
                sourceAdjustmentIndex: 0,
                popularityBandIndex: 0
            )
        )
    }

    func testOriginalTaxCoverageIndexPreservesNearestThresholdAndFirstTie() {
        XCTAssertEqual(
            DeterministicMigration.OriginalTaxCoverageIndexCatalog.thresholds,
            [0, 3, 7, 9, 11, 15, 20]
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalTaxCoverageIndexCatalog.nearestIndex(
                coveragePercent: 5
            ),
            1,
            "5 is equally distant from 3 and 7; strict < keeps the first row"
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalTaxCoverageIndexCatalog.selectedIndex(
                coveragePercent: 10
            ),
            0,
            "the <11 coverage gate selects the None row"
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalTaxCoverageIndexCatalog.selectedIndex(
                coveragePercent: 11
            ),
            4
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalTaxCoverageIndexCatalog.selectedIndex(
                coveragePercent: 100
            ),
            6
        )
    }

    func testOriginalInvasionHeroEligibilityMatchesRawCityFieldGate() {
        for value in 0..<12 {
            XCTAssertTrue(
                OriginalInvasionHeroEligibility.rawCityFieldIsEligible(value),
                "FUN_00522D30 admits signed city +0x38 value \(value)"
            )
        }
        for value in [-1, 12, 13, Int.min, Int.max] {
            XCTAssertFalse(
                OriginalInvasionHeroEligibility.rawCityFieldIsEligible(value),
                "FUN_00522D30 rejects signed city +0x38 value \(value)"
            )
        }
    }

    func testOriginalInvasionThreatWeightsMatchExecutableAggregate() {
        XCTAssertEqual(
            OriginalInvasionThreatWeightCatalog.weightsByModelID,
            [59: 1.25, 60: 2.5, 61: 4.0, 62: 5.0, 78: 10.0]
        )
        XCTAssertEqual(
            OriginalInvasionThreatWeightCatalog.contribution(modelID: 59, quantity: 8),
            10
        )
        XCTAssertEqual(
            OriginalInvasionThreatWeightCatalog.contribution(modelID: 60, quantity: 8),
            20
        )
        XCTAssertEqual(
            OriginalInvasionThreatWeightCatalog.contribution(modelID: 61, quantity: 8),
            32
        )
        XCTAssertEqual(
            OriginalInvasionThreatWeightCatalog.contribution(modelID: 62, quantity: 8),
            40
        )
        XCTAssertEqual(
            OriginalInvasionThreatWeightCatalog.contribution(modelID: 78, quantity: 8),
            80
        )
        XCTAssertNil(OriginalInvasionThreatWeightCatalog.contribution(modelID: 58, quantity: 8))
        XCTAssertNil(OriginalInvasionThreatWeightCatalog.contribution(modelID: 59, quantity: 0))
    }

    func testOriginalInvasionThreatAggregateAppliesRawRecordPredicates() {
        let records = [
            OriginalInvasionThreatRecord(active: true, modelID: 59, quantity: 8, citySelector: 0),
            OriginalInvasionThreatRecord(active: true, modelID: 60, quantity: 8, citySelector: 0),
            OriginalInvasionThreatRecord(active: true, modelID: 62, quantity: 8, citySelector: 1),
            OriginalInvasionThreatRecord(active: false, modelID: 78, quantity: 8, citySelector: 0),
            OriginalInvasionThreatRecord(active: true, modelID: 58, quantity: 8, citySelector: 0),
            OriginalInvasionThreatRecord(active: true, modelID: 59, quantity: 0, citySelector: 0)
        ]
        XCTAssertEqual(
            OriginalInvasionThreatAggregate.value(citySelector: 0, records: records),
            30,
            "only active, selected-city records with recognized weighted models contribute"
        )
        XCTAssertEqual(
            OriginalInvasionThreatAggregate.value(citySelector: 1, records: records),
            40
        )
    }

    func testOriginalInvasionThreatRecordLifecycleAliasesUnifiedEnemySlice() {
        XCTAssertEqual(
            OriginalInvasionThreatRecordLifecycle.unifiedTableBaseAddress
                + OriginalInvasionThreatRecordLifecycle.enemyFirstSlot
                    * OriginalInvasionThreatRecordLifecycle.recordStride,
            OriginalInvasionThreatRecordLifecycle.enemyTableBaseAddress
        )
        XCTAssertEqual(
            OriginalInvasionThreatRecordLifecycle.quantityAddress(
                forSlot: OriginalInvasionThreatRecordLifecycle.enemyFirstSlot
            ),
            OriginalInvasionThreatRecordLifecycle.enemyQuantityAddress
        )
        XCTAssertNil(OriginalInvasionThreatRecordLifecycle.quantityAddress(forSlot: 34))
        XCTAssertNil(OriginalInvasionThreatRecordLifecycle.quantityAddress(forSlot: 99))
        XCTAssertEqual(
            OriginalInvasionThreatRecordLifecycle.quantityAfterSuccessfulFigureSpawns(0),
            0
        )
        XCTAssertEqual(
            OriginalInvasionThreatRecordLifecycle.quantityAfterSuccessfulFigureSpawns(16),
            16
        )
        XCTAssertNil(
            OriginalInvasionThreatRecordLifecycle.quantityAfterSuccessfulFigureSpawns(17)
        )

        var states = Array(
            repeating: OriginalInvasionThreatRecordLifecycle.SlotState(active: false),
            count: 64
        )
        states[0] = .init(active: true)
        states[1] = .init(active: false, lifecycleByte: 1)
        XCTAssertEqual(
            OriginalInvasionThreatRecordLifecycle.firstAllocatableSlot(states),
            OriginalInvasionThreatRecordLifecycle.enemyFirstSlot + 2
        )
        states[2] = .init(active: true)
        states[3] = .init(active: false, lifecycleByte: 7)
        XCTAssertEqual(
            OriginalInvasionThreatRecordLifecycle.firstAllocatableSlot(states),
            OriginalInvasionThreatRecordLifecycle.enemyFirstSlot + 4
        )
        XCTAssertNil(
            OriginalInvasionThreatRecordLifecycle.firstAllocatableSlot(
                Array(states.dropLast())
            )
        )
    }

    func testOriginalQinInvasionFormationPlanUsesAuthoredEnemyPeriods() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        XCTAssertEqual(OriginalInvasionFormationCatalog.periodIndex(forYear: -209), 3)
        XCTAssertEqual(OriginalInvasionFormationCatalog.periodIndex(forYear: -200), 4)
        XCTAssertEqual(OriginalInvasionFormationCatalog.periodIndex(forYear: -350), 3)
        XCTAssertEqual(OriginalInvasionFormationCatalog.periodIndex(forYear: -1_200), 1)

        let plan = try XCTUnwrap(OriginalInvasionFormationCatalog.plan(
            enemySetIndex: 0,
            year: -209,
            amount: 9,
            enemies: original.figures.enemies
        ))
        XCTAssertEqual(plan.periodIndex, 3)
        XCTAssertEqual(plan.modelIDs, [58, 59, 60, 61, 62])
        XCTAssertEqual(plan.counts, [3, 1, 1, 1, 1])
        XCTAssertEqual(plan.sourceFigureCount, 7)
        XCTAssertEqual(
            plan.groups,
            [
                .init(modelID: 58, groupIndex: 0, quantity: 3),
                .init(modelID: 59, groupIndex: 0, quantity: 1),
                .init(modelID: 60, groupIndex: 0, quantity: 1),
                .init(modelID: 61, groupIndex: 0, quantity: 1),
                .init(modelID: 62, groupIndex: 0, quantity: 1)
            ]
        )

        let clamped = try XCTUnwrap(OriginalInvasionFormationCatalog.plan(
            enemySetIndex: 0,
            periodIndex: 3,
            amount: 300,
            enemies: original.figures.enemies
        ))
        XCTAssertEqual(clamped.counts, [89, 51, 38, 38, 38])
        XCTAssertNil(OriginalInvasionFormationCatalog.plan(
            enemySetIndex: 7,
            periodIndex: 3,
            amount: 9,
            enemies: original.figures.enemies
        ))
    }

    func testCampaignInvasionSourceFormationPlanFeedsAggregateSoldierCount() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let invasionPoint = GridPoint(x: 9, y: 4)
        let terrain = try DeterministicTerrainState(
            width: 10,
            height: 8,
            terrainRawValues: [UInt32](repeating: 0, count: 80),
            authoredPoints: EmperorMapAuthoredPoints(landInvasion: [invasionPoint])
        )
        var city = DeterministicCityState(year: -209, treasury: 18_000, terrain: terrain)
        _ = city.buildRoad((0..<10).map { GridPoint(x: $0, y: 4) }, rules: rules)
        let occurrence = CampaignEventOccurrence(
            eventID: 2,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.invasion.rawValue,
            triggerMode: .oneTime,
            relativeYear: 0,
            month: 1,
            amount: 9,
            cityFromID: 0
        )
        let plan = try XCTUnwrap(OriginalInvasionFormationCatalog.plan(
            enemySetIndex: 0,
            year: -209,
            amount: 9,
            enemies: original.figures.enemies
        ))

        _ = city.applyCampaignCityEvent(occurrence, sourceFormationPlan: plan)
        let alert = try XCTUnwrap(city.campaignEvents.invasions.first)
        XCTAssertEqual(alert.sourceFormationPlan, plan)
        XCTAssertEqual(alert.sourceFigureCount, 7)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )

        _ = city.advanceMilitary(maximumStepsPerUnit: 1, models: original.figures)
        let force = try XCTUnwrap(city.military.enemyForces.first)
        XCTAssertEqual(force.soldierCount, 7)
        XCTAssertEqual(force.enemyTypeID, 58)
    }

    func testOriginalInvasionFormationGroupsMirrorSourceSplitAndCap() {
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: 0), [])
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: 15), [15])
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: 16), [16])
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: 17), [9, 8])
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: 31), [16, 15])
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: 32), [16, 16])
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: 33), [16, 9, 8])
        XCTAssertEqual(
            OriginalInvasionFormationCatalog.groups(forCount: 512),
            Array(repeating: 16, count: 32)
        )
        XCTAssertEqual(
            OriginalInvasionFormationCatalog.groups(forCount: 513),
            Array(repeating: 16, count: 32),
            "FUN_00522D30 caps each category at 0x200 before splitting"
        )
        XCTAssertEqual(OriginalInvasionFormationCatalog.groups(forCount: -1), [])
    }

    func testOriginalInvasionThreatSaveSerializerBoundaryMirrorsSource() {
        XCTAssertEqual(OriginalInvasionThreatRecordSerialization.serializerAddress, 0x005501B0)
        XCTAssertEqual(OriginalInvasionThreatRecordSerialization.mapSaveSerializerAddress, 0x0052FDA0)
        XCTAssertEqual(OriginalInvasionThreatRecordSerialization.directSaveEntryAddress, 0x004FD2A0)
        XCTAssertEqual(OriginalInvasionThreatRecordSerialization.unifiedTableBaseAddress, 0x011A2B08)
        XCTAssertEqual(OriginalInvasionThreatRecordSerialization.recordCount, 100)
        XCTAssertEqual(OriginalInvasionThreatRecordSerialization.recordStride, 0xB4)
        XCTAssertEqual(
            OriginalInvasionThreatRecordSerialization.canonicalFields.filter { $0.offset == 0xA4 },
            [.init(offset: 0xA4, width: 4), .init(offset: 0xA4, width: 4)]
        )
        XCTAssertTrue(
            OriginalInvasionThreatRecordSerialization.canonicalFields.contains(
                .init(offset: 0x78, width: 2)
            )
        )
        XCTAssertTrue(
            OriginalInvasionThreatRecordSerialization.canonicalFields.contains(
                .init(offset: 0x28, width: 1)
            )
        )
    }

    func testVersion031WallsGateTowerSentriesAndMultiFormationOrders() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let invasionPoint = GridPoint(x: 17, y: 6)
        let terrain = try DeterministicTerrainState(
            width: 20,
            height: 10,
            terrainRawValues: [UInt32](repeating: 0, count: 200),
            authoredPoints: EmperorMapAuthoredPoints(landInvasion: [invasionPoint])
        )
        var city = DeterministicCityState(year: 1600, treasury: 80_000, terrain: terrain)
        _ = city.buildRoad((0..<20).map { GridPoint(x: $0, y: 6) }, rules: rules)
        _ = city.buildRoad((5...7).map { GridPoint(x: 8, y: $0) }, rules: rules)

        for x in 6...10 {
            _ = try XCTUnwrap(city.constructMilitaryDefense(
                buildingID: 129,
                at: GridPoint(x: x, y: 6),
                rules: rules
            ))
        }
        XCTAssertTrue(city.militaryBlockedPoints.contains(GridPoint(x: 8, y: 6)))
        let gateID = try XCTUnwrap(city.constructMilitaryDefense(
            buildingID: 130,
            at: GridPoint(x: 6, y: 5),
            rules: rules
        ))
        XCTAssertFalse(city.militaryBlockedPoints.contains(GridPoint(x: 8, y: 6)))
        XCTAssertEqual(city.placement(category: .military, instanceID: gateID)?.footprint,
                       BuildingFootprint(width: 5, height: 3))
        XCTAssertEqual(city.military.defensiveStructures.first {
            $0.id == gateID
        }?.maximumIntegrity, 1_500)

        for y in 5...6 {
            for x in 16...17 {
                _ = try XCTUnwrap(city.constructMilitaryDefense(
                    buildingID: 129,
                    at: GridPoint(x: x, y: y),
                    rules: rules
                ))
            }
        }
        let towerID = try XCTUnwrap(city.constructMilitaryDefense(
            buildingID: 131,
            at: GridPoint(x: 16, y: 5),
            rules: rules
        ))
        XCTAssertEqual(Set(city.military.sentries.map(\.figureID)), Set([56, 57]))
        XCTAssertTrue(city.militaryBlockedPoints.contains(invasionPoint))

        _ = try XCTUnwrap(city.constructMilitaryFort(
            buildingID: 221,
            at: GridPoint(x: 0, y: 2),
            rules: rules
        ))
        _ = try XCTUnwrap(city.constructMilitaryFort(
            buildingID: 220,
            at: GridPoint(x: 11, y: 2),
            rules: rules
        ))
        XCTAssertEqual(city.issueMilitaryOrder(
            to: GridPoint(x: 12, y: 6),
            models: original.figures
        ), 2)
        XCTAssertGreaterThan(city.advanceMilitary(
            maximumStepsPerUnit: 100,
            models: original.figures
        ).movedSteps, 0)
        XCTAssertEqual(
            Set(city.military.units.map(\.currentPoint)),
            Set([GridPoint(x: 12, y: 6)])
        )

        _ = city.applyCampaignCityEvent(CampaignEventOccurrence(
            eventID: 31,
            occurrenceIndex: 0,
            kindRawValue: CampaignEventKind.invasion.rawValue,
            triggerMode: .oneTime,
            relativeYear: 0,
            month: 1,
            amount: 16,
            cityFromID: 2
        ))
        let report = try XCTUnwrap(city.advanceMilitary(
            maximumStepsPerUnit: 100,
            models: original.figures
        ).reports.first)
        XCTAssertEqual(Set(report.participatingUnitIDs ?? []), Set(city.military.units.map(\.id)))
        XCTAssertEqual(report.outcome, .repelled)
        XCTAssertEqual(city.campaignEvents.invasions.first?.status, .repelled)

        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
        _ = city.demolish(at: invasionPoint, rules: rules)
        XCTAssertFalse(city.military.defensiveStructures.contains { $0.id == towerID })
        XCTAssertTrue(city.military.sentries.isEmpty)
    }

    func testAestheticsFengShuiAndPhysicalGreatTempleConstruction() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let width = 50
        let height = 25
        var raw = [UInt32](repeating: 0, count: width * height)
        raw[16 * width + 31] = TerrainFlags.tree.rawValue
        let terrain = try DeterministicTerrainState(
            width: width,
            height: height,
            terrainRawValues: raw
        )
        var city = DeterministicCityState(
            year: 1600,
            treasury: 100_000,
            terrain: terrain
        )
        _ = city.buildRoad((0..<width).map { GridPoint(x: $0, y: 18) }, rules: rules)
        XCTAssertNotNil(city.constructWarehouse(at: GridPoint(x: 0, y: 15), rules: rules))
        XCTAssertNotNil(city.constructAestheticBuilding(
            buildingID: 233,
            at: GridPoint(x: 4, y: 16),
            rules: rules
        ))
        XCTAssertNotNil(city.constructAestheticBuilding(
            buildingID: 52,
            at: GridPoint(x: 7, y: 16),
            rules: rules
        ))
        XCTAssertNotNil(city.constructAestheticBuilding(
            buildingID: 236,
            at: GridPoint(x: 10, y: 16),
            rules: rules
        ))
        let templeID = try XCTUnwrap(city.constructAestheticBuilding(
            buildingID: 78,
            at: GridPoint(x: 14, y: 10),
            rules: rules
        ))
        let treeID = try XCTUnwrap(city.constructAestheticBuilding(
            buildingID: 118,
            at: GridPoint(x: 30, y: 16),
            rules: rules
        ))
        let treeEvaluation = city.fengShuiSummary(models: original.buildings)
            .evaluations.first {
                $0.buildingKey == OperationalBuildingKey(
                    category: .aesthetic,
                    instanceID: treeID
                )
            }
        XCTAssertEqual(treeEvaluation?.element, .wood)
        XCTAssertEqual(treeEvaluation?.quality, .harmonious)

        XCTAssertEqual(city.receiveCampaignCommodityGift(commodityID: 10, amount: 400), 400)
        XCTAssertEqual(city.receiveCampaignCommodityGift(commodityID: 18, amount: 400), 400)
        for _ in 0..<15 { _ = city.advanceMonuments() }
        let temple = try XCTUnwrap(city.aesthetics.monuments.first { $0.id == templeID })
        XCTAssertTrue(temple.isComplete)
        XCTAssertEqual(temple.completionPercent, 100)
        XCTAssertEqual(city.logistics[commodityID: 10], 0)
        XCTAssertEqual(city.logistics[commodityID: 18], 0)
        XCTAssertTrue(city.campaignGoalProgressSnapshot()
            .completedMonumentBuildingIDs.contains(78))
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )

        _ = city.demolish(at: GridPoint(x: 14, y: 10), rules: rules)
        XCTAssertFalse(city.aesthetics.completedMonumentBuildingIDs.contains(78))
    }

    func testVersion030CompletesFirstShangMissionFromOriginalWorldData() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        let campaignURL = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: campaignURL)
        let original = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: original)
        let settings = try CampaignMissionSettingsArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let maps = try CampaignMissionMapArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count,
            candidateMapURLs: catalog.maps.map(\.url)
        )
        let empire = try XCTUnwrap(try CampaignEmpireMap.loadIfPresent(campaignURL: campaignURL))
        let cityNames = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        let events = try CampaignEventArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let goals = try CampaignGoalArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let world = try CampaignMissionWorldState(
            missionID: 0,
            missionSettings: settings,
            missionMaps: maps,
            empireMap: empire,
            cityNames: cityNames,
            tradeRules: original.trade
        )
        XCTAssertEqual(world.playerCityName, "Bo")
        let originalMap = try EmperorMap(url: world.mapAssignment.embeddedMap.mapURL)
        var city = DeterministicCityState(
            missionSettings: world.startSettings,
            map: originalMap
        )
        city.housingEvolutionEnabled = false
        city.publicSafetyEnabled = false
        XCTAssertEqual(world.installTradePartners(in: &city, rules: rules), world.tradePartners.count)
        XCTAssertNotNil(city.addHouse(
            levelID: 4,
            residents: 600,
            footprintMultiplier: 50,
            models: original.buildings
        ))
        XCTAssertNotNil(city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: original.buildings[buildingID: 35]?.employees ?? 0,
            rules: rules
        ))
        XCTAssertNotNil(city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: original.buildings[buildingID: 43]?.employees ?? 0,
            rules: rules
        ))

        var runtime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: world.startSettings.startYear,
            startMonth: world.startSettings.startMonth,
            eventSet: events.missions[0],
            replaySeed: 0x3030_5348_414E_47
        )
        var completedNowCount = 0
        for _ in 0..<24 where !runtime.missionCompleted {
            let settlement = city.advanceMonth(rules: rules)
            let result = runtime.advance(
                settlementYear: settlement.year,
                month: settlement.month,
                city: &city,
                rules: rules,
                goalSet: goals.missions[0]
            )
            if result.missionCompletedNow { completedNowCount += 1 }
        }
        XCTAssertTrue(runtime.missionCompleted)
        XCTAssertEqual(completedNowCount, 1)
        XCTAssertGreaterThanOrEqual(
            city.productionAccounting.bestYearlyProductionUnitsByCommodityID[25, default: 0],
            1_200
        )
        XCTAssertTrue(CampaignGoalEvaluator.missionIsComplete(
            goals.missions[0],
            against: city.campaignGoalProgressSnapshot(
                menagerieSpeciesCount: runtime.menagerieAnimalIDs.count
            )
        ))
        XCTAssertTrue(runtime.effects.contains {
            $0.kind == .cityStatusChange && $0.disposition == .applied
        })

        let save = NativeSaveGame(
            campaignFileName: campaignURL.lastPathComponent,
            missionIndex: 0,
            replaySeed: runtime.replaySeed,
            city: city,
            campaignRuntime: runtime
        )
        XCTAssertEqual(try NativeSaveGameStore.decoded(NativeSaveGameStore.encoded(save)), save)
    }

    func testVersion040CompletesAllSevenShangGoalSetsThroughNativeRuntime() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        let campaignURL = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let campaign = try CampaignArchive(url: campaignURL)
        let original = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: original)
        let settings = try CampaignMissionSettingsArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let maps = try CampaignMissionMapArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count,
            candidateMapURLs: catalog.maps.map(\.url)
        )
        let empireMap = try XCTUnwrap(CampaignEmpireMap.loadIfPresent(campaignURL: campaignURL))
        let cityNames = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        let events = try CampaignEventArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let goals = try CampaignGoalArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )

        func addGoalHousing(
            _ goalSet: CampaignMissionGoalSet,
            to city: inout DeterministicCityState
        ) throws {
            for goal in goalSet.goals {
                switch goal.requirement {
                case let .housing(levelCode, residents):
                    let levelID = max(0, levelCode - 3)
                    let capacity = try XCTUnwrap(
                        original.buildings[houseLevelID: levelID]?.populationCapacity
                    )
                    let multiplier = max(1, (residents + capacity - 1) / capacity)
                    _ = try XCTUnwrap(city.addHouse(
                        levelID: levelID,
                        residents: residents,
                        footprintMultiplier: multiplier,
                        models: original.buildings
                    ))
                default:
                    break
                }
            }
            let requiredPopulation = goalSet.goals.compactMap { goal -> Int? in
                if case let .population(value) = goal.requirement { return value }
                return nil
            }.max() ?? 0
            if city.population < requiredPopulation {
                let missing = requiredPopulation - city.population
                let capacity = original.buildings[houseLevelID: 0]?.populationCapacity ?? 7
                _ = try XCTUnwrap(city.addHouse(
                    levelID: 0,
                    residents: missing,
                    footprintMultiplier: max(1, (missing + capacity - 1) / capacity),
                    models: original.buildings
                ))
            }
        }

        func prepareMonument(
            buildingID: Int,
            in city: inout DeterministicCityState
        ) throws {
            _ = try XCTUnwrap(city.constructWarehouse(
                at: GridPoint(x: 0, y: 33),
                rules: rules
            ))
            _ = try XCTUnwrap(city.constructAestheticBuilding(
                buildingID: 233,
                at: GridPoint(x: 4, y: 34),
                rules: rules
            ))
            _ = try XCTUnwrap(city.constructAestheticBuilding(
                buildingID: 52,
                at: GridPoint(x: 7, y: 34),
                rules: rules
            ))
            _ = try XCTUnwrap(city.constructAestheticBuilding(
                buildingID: 235,
                at: GridPoint(x: 10, y: 34),
                rules: rules
            ))
            _ = try XCTUnwrap(city.constructAestheticBuilding(
                buildingID: 236,
                at: GridPoint(x: 13, y: 34),
                rules: rules
            ))
            let footprint = try XCTUnwrap(
                OriginalBuildingFootprintCatalog.footprint(forBuildingID: buildingID)
            )
            _ = try XCTUnwrap(city.constructAestheticBuilding(
                buildingID: buildingID,
                at: GridPoint(x: 22, y: 28 - footprint.height),
                rules: rules
            ))
            let configuration = try XCTUnwrap(
                OriginalMonumentConfiguration.configuration(buildingID: buildingID)
            )
            for (commodityID, amount) in configuration.requiredCommodityUnits {
                XCTAssertEqual(
                    city.receiveCampaignCommodityGift(
                        commodityID: commodityID,
                        amount: amount
                    ),
                    amount
                )
            }
        }

        var completedMissionIDs: [Int] = []
        for missionID in campaign.missions.indices {
            let world = try CampaignMissionWorldState(
                missionID: missionID,
                missionSettings: settings,
                missionMaps: maps,
                empireMap: empireMap,
                cityNames: cityNames,
                tradeRules: original.trade
            )
            var city = DeterministicCityState(
                missionSettings: world.startSettings,
                mapWidth: 60,
                mapHeight: 40
            )
            city.housingEvolutionEnabled = false
            city.publicSafetyEnabled = false
            _ = city.buildRoad((0..<60).map { GridPoint(x: $0, y: 28) }, rules: rules)
            _ = city.buildRoad((0..<60).map { GridPoint(x: $0, y: 36) }, rules: rules)
            _ = world.installTradePartners(in: &city, rules: rules)
            try addGoalHousing(goals.missions[missionID], to: &city)

            for goal in goals.missions[missionID].goals {
                switch goal.requirement {
                case let .monument(buildingID):
                    try prepareMonument(buildingID: buildingID, in: &city)
                case let .yearlyProduction(commodityID, _):
                    switch commodityID {
                    case 25:
                        _ = try XCTUnwrap(city.constructProductionBuilding(
                            buildingID: 35,
                            assignedWorkers: original.buildings[buildingID: 35]?.employees ?? 0,
                            rules: rules
                        ))
                        _ = try XCTUnwrap(city.constructProductionBuilding(
                            buildingID: 43,
                            assignedWorkers: original.buildings[buildingID: 43]?.employees ?? 0,
                            rules: rules
                        ))
                    case 23:
                        _ = try XCTUnwrap(city.constructWarehouse(
                            serviceRoadStart: GridPoint(x: 0, y: 36),
                            rules: rules
                        ))
                        _ = try XCTUnwrap(city.constructWarehouse(
                            serviceRoadStart: GridPoint(x: 1, y: 36),
                            rules: rules
                        ))
                        XCTAssertEqual(city.receiveCampaignCommodityGift(
                            commodityID: 11,
                            amount: 3_000
                        ), 3_000)
                        XCTAssertEqual(city.receiveCampaignCommodityGift(
                            commodityID: 18,
                            amount: 3_000
                        ), 3_000)
                        for _ in 0..<2 {
                            _ = try XCTUnwrap(city.constructProductionBuilding(
                                buildingID: 42,
                                assignedWorkers: original.buildings[buildingID: 42]?.employees ?? 0,
                                rules: rules
                            ))
                        }
                    case 6:
                        for index in 0..<10 {
                            _ = try XCTUnwrap(city.constructAgriculturalProducer(
                                crop: .rice,
                                fieldCount: 10,
                                fertilityPercent: 100,
                                climate: .humid,
                                serviceRoadStart: GridPoint(x: index, y: 36),
                                rules: rules
                            ))
                        }
                    default:
                        XCTFail("Unhandled Shang production commodity \(commodityID)")
                    }
                case let .tradingPartners(required):
                    for partner in world.tradePartners.prefix(required) {
                        _ = try XCTUnwrap(city.constructTradingBuilding(
                            partnerID: partner.id,
                            serviceRoadStart: GridPoint(x: partner.id % 20, y: 36),
                            rules: rules
                        ))
                    }
                case .yearlyProfit:
                    let residents = 2_500
                    let capacity = original.buildings[houseLevelID: 14]?.populationCapacity ?? 25
                    _ = try XCTUnwrap(city.addHouse(
                        levelID: 14,
                        residents: residents,
                        hasTaxCoverage: true,
                        footprintMultiplier: (residents + capacity - 1) / capacity,
                        models: original.buildings
                    ))
                default:
                    break
                }
            }

            var runtime = CampaignMissionRuntimeState(
                missionID: missionID,
                startYear: world.startSettings.startYear,
                startMonth: world.startSettings.startMonth,
                eventSet: events.missions[missionID],
                replaySeed: 0x4000 + UInt64(missionID),
                empireMap: empireMap,
                playerCityID: try XCTUnwrap(world.playerCity).id,
                cityNames: cityNames
            )

            if goals.missions[missionID].goals.contains(where: {
                if case .homage = $0.requirement { return true }
                return false
            }) {
                let months = goals.missions[missionID].goals.compactMap { goal -> Int? in
                    if case let .homage(value) = goal.requirement { return value }
                    return nil
                }.max() ?? 0
                XCTAssertTrue(runtime.prepayHeroHomage(
                    heroID: 0,
                    city: &city,
                    months: months
                ))
            }

            if goals.missions[missionID].goals.contains(where: {
                if case .alliedCities = $0.requirement { return true }
                return false
            }), let target = runtime.empireState?.visibleForeignCities.max(by: {
                $0.favor < $1.favor
            }) {
                while runtime.empireState?.cities.first(where: {
                    $0.id == target.id
                })?.favor ?? 0 < 60 {
                    XCTAssertTrue(runtime.sendEmissary(to: target.id, city: &city))
                }
                XCTAssertTrue(runtime.sendEmissary(to: target.id, city: &city))
                XCTAssertTrue(runtime.requestAlliance(with: target.id))
            }

            if goals.missions[missionID].goals.contains(where: {
                if case .menagerieSpecies = $0.requirement { return true }
                return false
            }) {
                _ = try XCTUnwrap(city.constructAestheticBuilding(
                    buildingID: 110,
                    at: GridPoint(x: 0, y: 18),
                    rules: rules
                ))
                let required = goals.missions[missionID].goals.compactMap { goal -> Int? in
                    if case let .menagerieSpecies(value) = goal.requirement { return value }
                    return nil
                }.max() ?? 0
                let targetID = try XCTUnwrap(runtime.empireState?.visibleForeignCities.max(by: {
                    $0.favor < $1.favor
                })?.id)
                while runtime.menagerieAnimalIDs.count < required {
                    while runtime.empireState?.cities.first(where: {
                        $0.id == targetID
                    })?.favor ?? 0 < 60 {
                        XCTAssertTrue(runtime.sendEmissary(to: targetID, city: &city))
                    }
                    XCTAssertTrue(runtime.sendEmissary(to: targetID, city: &city))
                    _ = try XCTUnwrap(runtime.requestMenagerieAnimal(
                        from: targetID,
                        using: city
                    ))
                }
            }

            for _ in 0..<48 where !runtime.missionCompleted {
                let settlement = city.advanceMonth(rules: rules)
                _ = runtime.advance(
                    settlementYear: settlement.year,
                    month: settlement.month,
                    city: &city,
                    rules: rules,
                    goalSet: goals.missions[missionID]
                )
            }
            let finalSnapshot = city.campaignGoalProgressSnapshot(
                alliedCityCount: runtime.empireState?.alliedCityCount ?? 0,
                conqueredCityCount: runtime.empireState?.conqueredCityCount ?? 0,
                homageProgress: runtime.empireState?.homageProgress ?? 0,
                menagerieSpeciesCount: runtime.menagerieAnimalIDs.count
            )
            let progressText = goals.missions[missionID].goals.map {
                let progress = CampaignGoalEvaluator.evaluate($0, against: finalSnapshot)
                return "\($0.kind.rawValue)=\(progress.currentValue)/\(progress.requiredValue)"
            }.joined(separator: ", ")
            XCTAssertTrue(
                runtime.missionCompleted,
                "Shang mission \(missionID + 1) did not complete: \(progressText)"
            )
            if runtime.missionCompleted { completedMissionIDs.append(missionID) }
        }
        XCTAssertEqual(completedMissionIDs, Array(0..<7))
    }

    func testVersion040ContinuationRetainsWholeCityAndResetsMissionScope() throws {
        let first = CampaignMissionStartSettings(
            id: 0,
            startYear: -1606,
            startMonth: 6,
            initialFunds: 5_000,
            allowedBuildingMenuIDs: [9, 15],
            allowedResourceCommodityIDs: [18, 25]
        )
        let continuation = CampaignMissionStartSettings(
            id: 2,
            startYear: -1559,
            startMonth: 6,
            initialFunds: 9_000,
            allowedBuildingMenuIDs: [9, 15, 43],
            allowedResourceCommodityIDs: [18, 25]
        )
        var city = DeterministicCityState(
            missionSettings: first,
            mapWidth: 20,
            mapHeight: 10
        )
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        _ = city.buildRoad((0..<20).map { GridPoint(x: $0, y: 6) }, rules: rules)
        _ = try XCTUnwrap(city.addHouse(
            levelID: 4,
            residents: 100,
            footprintMultiplier: 10,
            models: original.buildings
        ))
        _ = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: original.buildings[buildingID: 35]?.employees ?? 0,
            rules: rules
        ))
        city.continueCampaignMission(with: continuation)
        XCTAssertEqual(city.calendar, SimulationCalendar(year: -1559, month: 6))
        XCTAssertEqual(city.missionSettings, continuation)
        XCTAssertEqual(city.population, 100)
        XCTAssertEqual(city.production.buildings.count, 1)
        XCTAssertEqual(city.roadNetwork.points.count, 20)
        XCTAssertEqual(city.economy.treasury, 9_000)
        XCTAssertTrue(city.campaignEvents.invasions.isEmpty)
    }

    func testVersion050MigratesPre032FormatOneSaveWithoutNewOptionalState() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let campaignURL = source.campaignsDirectory.appendingPathComponent("2 Shang Dynasty.pak")
        let empire = try XCTUnwrap(CampaignEmpireMap.loadIfPresent(campaignURL: campaignURL))
        let names = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        let runtime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: -1606,
            startMonth: 6,
            eventSet: CampaignMissionEventSet(id: 0, events: []),
            replaySeed: 0x5000,
            empireMap: empire,
            playerCityID: 13,
            cityNames: names
        )
        let save = NativeSaveGame(
            campaignFileName: campaignURL.lastPathComponent,
            missionIndex: 0,
            replaySeed: 0x5000,
            city: DeterministicCityState(year: -1606, month: 6, treasury: 12_345),
            campaignRuntime: runtime
        )
        let encoded = try NativeSaveGameStore.encoded(save)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var cityJSON = try XCTUnwrap(json["city"] as? [String: Any])
        var militaryJSON = try XCTUnwrap(cityJSON["militaryState"] as? [String: Any])
        XCTAssertNotNil(militaryJSON.removeValue(forKey: "defensiveStructuresState"))
        XCTAssertNotNil(militaryJSON.removeValue(forKey: "sentriesState"))
        XCTAssertNotNil(militaryJSON.removeValue(forKey: "enemyForcesState"))
        cityJSON["militaryState"] = militaryJSON
        json["city"] = cityJSON
        var runtimeJSON = try XCTUnwrap(json["campaignRuntime"] as? [String: Any])
        XCTAssertNotNil(runtimeJSON.removeValue(forKey: "empireState"))
        json["campaignRuntime"] = runtimeJSON

        let legacyFixture = try JSONSerialization.data(
            withJSONObject: json,
            options: [.sortedKeys]
        )
        let migrated = try NativeSaveGameStore.decoded(legacyFixture)
        XCTAssertEqual(migrated.formatVersion, NativeSaveGame.currentFormatVersion)
        XCTAssertEqual(migrated.city.economy.treasury, 12_345)
        XCTAssertTrue(migrated.city.military.defensiveStructures.isEmpty)
        XCTAssertTrue(migrated.city.military.sentries.isEmpty)
        XCTAssertTrue(migrated.city.military.enemyForces.isEmpty)
        XCTAssertNil(migrated.campaignRuntime?.empireState)
    }

    func testVersion060StartsAllPlayableMissionsAndClassifiesNetworkScenarios() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        let campaigns = try CampaignCatalog.load(source)
        let original = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: original)
        let names = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        var startedMissionCount = 0
        var advancedMissionCount = 0
        var originalMapMissionCount = 0
        var maplessNetworkScenarioCount = 0
        var standaloneMissionCount = 0

        for campaign in campaigns {
            let settings = try CampaignMissionSettingsArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let maps = try CampaignMissionMapArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count,
                candidateMapURLs: catalog.maps.map(\.url)
            )
            let events = try CampaignEventArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let goals = try CampaignGoalArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let empire = try CampaignEmpireMap.loadIfPresent(campaignURL: campaign.url)
            if maps.isMaplessNetworkScenario {
                XCTAssertEqual(campaign.missions.count, 1, campaign.title)
                XCTAssertTrue(maps.missions.isEmpty, campaign.title)
                XCTAssertEqual(campaign.containerChunkCount, 29, campaign.title)
                maplessNetworkScenarioCount += 1
                continue
            }
            XCTAssertEqual(maps.missions.count, campaign.missions.count, campaign.title)
            for mission in campaign.missions {
                let assignment = maps.missions[mission.id]
                let originalMap = try EmperorMap(url: assignment.embeddedMap.mapURL)
                var city = DeterministicCityState(
                    missionSettings: settings.missions[mission.id],
                    map: originalMap
                )
                originalMapMissionCount += 1
                city.housingEvolutionEnabled = false
                city.publicSafetyEnabled = false
                let world = try CampaignMissionWorldState(
                    missionID: mission.id,
                    missionSettings: settings,
                    missionMaps: maps,
                    empireMap: empire,
                    cityNames: names,
                    tradeRules: original.trade
                )
                if empire == nil { standaloneMissionCount += 1 }
                _ = world.installTradePartners(in: &city, rules: rules)
                var runtime = CampaignMissionRuntimeState(
                    missionID: mission.id,
                    startYear: settings.missions[mission.id].startYear,
                    startMonth: settings.missions[mission.id].startMonth,
                    eventSet: events.missions[mission.id],
                    replaySeed: 0x5000 + UInt64(startedMissionCount),
                    empireMap: empire,
                    playerCityID: world.playerCity?.id,
                    cityNames: names
                )
                startedMissionCount += 1
                let settlement = city.advanceMonth(rules: rules)
                _ = runtime.advance(
                    settlementYear: settlement.year,
                    month: settlement.month,
                    city: &city,
                    rules: rules,
                    goalSet: goals.missions[mission.id]
                )
                XCTAssertEqual(city.calendar.month, settlement.month == 12 ? 1 : settlement.month + 1)
                advancedMissionCount += 1
            }
        }
        XCTAssertEqual(campaigns.count, 31)
        XCTAssertEqual(startedMissionCount, 62)
        XCTAssertEqual(advancedMissionCount, startedMissionCount)
        XCTAssertEqual(originalMapMissionCount, 62)
        XCTAssertEqual(maplessNetworkScenarioCount, 12)
        XCTAssertGreaterThan(standaloneMissionCount, 0)
        print(
            "0.60 campaign smoke: \(originalMapMissionCount) playable map missions, "
                + "\(maplessNetworkScenarioCount) original network scenarios"
        )
    }

    func testVersion090RunsEveryOfficialMissionForFiveYearsDeterministically() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        let original = try OriginalEconomyModels(source: source)
        let rules = EconomyRulesEngine(models: original)
        let names = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        let officialFiles = [
            "1 Xia Dynasty - Tutorials.pak",
            "2 Shang Dynasty.pak",
            "3 Zhou Dynasty.pak",
            "4 Qin Dynasty.pak",
            "5 Han Dynasty.pak",
            "6 Sui - Tang Dynasties.pak",
            "7 Song - Jin  Dynasties.pak",
            "8 Jin Great Wall.pak",
        ]
        var missionCount = 0
        var monthCount = 0
        for fileName in officialFiles {
            let campaign = try CampaignArchive(
                url: source.campaignsDirectory.appendingPathComponent(fileName)
            )
            let settings = try CampaignMissionSettingsArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let maps = try CampaignMissionMapArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count,
                candidateMapURLs: catalog.maps.map(\.url)
            )
            let events = try CampaignEventArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let goals = try CampaignGoalArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let empire = try CampaignEmpireMap.loadIfPresent(campaignURL: campaign.url)
            for mission in campaign.missions {
                let world = try CampaignMissionWorldState(
                    missionID: mission.id,
                    missionSettings: settings,
                    missionMaps: maps,
                    empireMap: empire,
                    cityNames: names,
                    tradeRules: original.trade
                )
                var first = DeterministicCityState(
                    missionSettings: world.startSettings,
                    map: try EmperorMap(url: world.mapAssignment.embeddedMap.mapURL)
                )
                first.housingEvolutionEnabled = false
                first.publicSafetyEnabled = false
                _ = world.installTradePartners(in: &first, rules: rules)
                var second = first
                var firstRuntime = CampaignMissionRuntimeState(
                    missionID: mission.id,
                    startYear: world.startSettings.startYear,
                    startMonth: world.startSettings.startMonth,
                    eventSet: events.missions[mission.id],
                    replaySeed: 0x9000 + UInt64(missionCount),
                    empireMap: empire,
                    playerCityID: world.playerCity?.id,
                    cityNames: names
                )
                var secondRuntime = firstRuntime
                for _ in 0..<60 {
                    let firstSettlement = first.advanceMonth(rules: rules)
                    _ = firstRuntime.advance(
                        settlementYear: firstSettlement.year,
                        month: firstSettlement.month,
                        city: &first,
                        rules: rules,
                        goalSet: goals.missions[mission.id]
                    )
                    let secondSettlement = second.advanceMonth(rules: rules)
                    _ = secondRuntime.advance(
                        settlementYear: secondSettlement.year,
                        month: secondSettlement.month,
                        city: &second,
                        rules: rules,
                        goalSet: goals.missions[mission.id]
                    )
                    monthCount += 1
                }
                XCTAssertEqual(first, second, "\(fileName) mission \(mission.id + 1)")
                XCTAssertEqual(firstRuntime, secondRuntime, "\(fileName) mission \(mission.id + 1)")
                if mission.id == 0 {
                    let save = NativeSaveGame(
                        campaignFileName: fileName,
                        missionIndex: mission.id,
                        replaySeed: 0x9000 + UInt64(missionCount),
                        city: first,
                        campaignRuntime: firstRuntime
                    )
                    XCTAssertEqual(
                        try NativeSaveGameStore.decoded(NativeSaveGameStore.encoded(save)),
                        save
                    )
                }
                missionCount += 1
            }
        }
        XCTAssertEqual(missionCount, 49)
        XCTAssertEqual(monthCount, 2_940)
    }

    func testVersion050ProfilesDeterministic140MapForTwentyFourMonths() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let side = 140
        let terrain = try DeterministicTerrainState(
            width: side,
            height: side,
            terrainRawValues: [UInt32](repeating: 0, count: side * side)
        )
        var baseline = DeterministicCityState(
            year: 1600,
            treasury: 2_000_000,
            terrain: terrain
        )
        baseline.housingEvolutionEnabled = false
        _ = baseline.buildRoad((0..<side).map { GridPoint(x: $0, y: side / 2) }, rules: rules)
        for index in 0..<300 {
            _ = try XCTUnwrap(baseline.addHouse(
                levelID: index % 8,
                residents: 6 + index % 10,
                hasTaxCoverage: index.isMultiple(of: 3),
                models: original.buildings
            ))
        }
        for index in 0..<40 {
            let roadPoint = GridPoint(x: 2 + index * 3, y: side / 2)
            _ = try XCTUnwrap(baseline.constructProductionBuilding(
                buildingID: index.isMultiple(of: 2) ? 35 : 43,
                assignedWorkers: 14,
                serviceRoadStart: roadPoint,
                rules: rules
            ))
        }
        for index in 0..<8 {
            _ = try XCTUnwrap(baseline.constructWarehouse(
                serviceRoadStart: GridPoint(x: 10 + index * 16, y: side / 2),
                rules: rules
            ))
        }

        let startedAt = Date.timeIntervalSinceReferenceDate
        for offset in 0..<24 {
            let start = GridPoint(x: 0, y: offset * 5 % side)
            let end = GridPoint(x: side - 1, y: side - 1 - offset * 7 % side)
            XCTAssertNotNil(terrain.shortestLandVisitorPath(
                from: start,
                to: end,
                blocked: []
            ))
        }
        var firstReplay = baseline
        var secondReplay = baseline
        for _ in 0..<24 { _ = firstReplay.advanceMonth(rules: rules) }
        for _ in 0..<24 { _ = secondReplay.advanceMonth(rules: rules) }
        let elapsed = Date.timeIntervalSinceReferenceDate - startedAt

        XCTAssertEqual(firstReplay, secondReplay)
        XCTAssertEqual(firstReplay.calendar, SimulationCalendar(year: 1602, month: 1))
        XCTAssertLessThan(elapsed, 8.0, "140x140 profile exceeded the 0.50 eight-second guardrail")
        print(String(format: "0.50 140x140/24-month profile: %.3fs", elapsed))
    }


}
