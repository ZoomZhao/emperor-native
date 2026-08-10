import EmperorCore
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

    func testFigureShadowMarkerBecomesTranslucentBlack() {
        let sprite = DecodedSprite(
            width: 2,
            height: 1,
            rgba: Data([255, 0, 0, 255, 255, 0, 8, 255])
        ).correctingFigureShadow()
        XCTAssertEqual(Array(sprite.rgba.prefix(4)), [0, 0, 0, 72])
        XCTAssertEqual(Array(sprite.rgba.suffix(4)), [255, 0, 8, 255])
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
            43: 2_788,
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
        XCTAssertEqual(city.houses[0].desirability, 4)
        XCTAssertEqual(city.lastHousingSettlement?.evolvedCount, 1)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].houseLevelID, 2)
        XCTAssertEqual(city.lastHousingSettlement?.changes.first?.fromLevelID, 1)
        XCTAssertEqual(city.lastHousingSettlement?.changes.first?.toLevelID, 2)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].houseLevelID, 2)
        let missing = try XCTUnwrap(city.lastHousingSettlement?.evaluations.first)
            .missingEvolutionRequirements
        XCTAssertTrue(missing.contains(.service(.ancestor)))
        XCTAssertTrue(missing.contains(.foodQuality(current: 0, required: 20)))
        let liveEvaluation = try XCTUnwrap(DeterministicHousingEvolution.evaluate(
            house: city.houses[0],
            models: original.buildings,
            difficulty: city.difficulty
        ))
        XCTAssertEqual(liveEvaluation, city.lastHousingSettlement?.evaluations.first)
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

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.houses[0].houseLevelID, 1)
        XCTAssertEqual(city.lastHousingSettlement?.devolvedCount, 1)
        XCTAssertEqual(city.lastHousingSettlement?.changes.first?.direction, .devolved)
        // Daily migration fills the level-2 dwelling before it loses service;
        // the downgrade therefore displaces the eight residents over level 1's capacity.
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
                serviceCoverage: [.water, .ancestor],
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
        XCTAssertTrue(city.logistics.deliveryWalkers.isEmpty)
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
        _ = city.buildRoad((0...6).map { GridPoint(x: $0, y: 2) }, rules: rules)
        let plotPoint = GridPoint(x: 3, y: 1)

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
        _ = city.buildRoad((0...6).map { GridPoint(x: $0, y: 2) }, rules: rules)
        for x in 0..<3 {
            XCTAssertNotNil(city.addHouse(
                levelID: 0,
                location: GridPoint(x: x, y: 3),
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
            at: GridPoint(x: 3, y: 1),
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
        _ = city.buildRoad((0..<10).map { GridPoint(x: $0, y: 4) }, rules: rules)
        let olderFarmID = try XCTUnwrap(city.constructAgriculturalProducer(
            crop: .rice,
            at: GridPoint(x: 1, y: 2),
            rules: rules
        ))
        let newerFarmID = try XCTUnwrap(city.constructAgriculturalProducer(
            crop: .rice,
            at: GridPoint(x: 6, y: 2),
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
        XCTAssertEqual(completionTick, 64)
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
            if city.houses[0].foodSupplyAmount > 0 {
                completionTick = tick.tickSequence
            }
        }

        XCTAssertEqual(city.logistics.mills.count, 1)
        XCTAssertEqual(city.logistics.mills[0].foodQuality, .plain)
        XCTAssertEqual(purchasedCommodityIDs, [2, 4])
        XCTAssertTrue(sawMeatDeliveryWalker)
        XCTAssertLessThanOrEqual(try XCTUnwrap(completionTick), 53)
        XCTAssertEqual(foodDeliveries, [
            HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 44)
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
            [HouseholdCommodityDelivery(houseID: 1, commodityID: -1, amount: 44)]
        )
        XCTAssertEqual(
            city.markets.lastSettlement?.householdConsumption,
            [HouseholdCommodityConsumption(
                houseID: 1,
                commodityID: -1,
                requestedAmount: 22,
                consumedAmount: 22
            )]
        )
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
        XCTAssertNotNil(city.constructWarehouse(
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

        for _ in 0..<6 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.production.localInputAmount(
            buildingInstanceID: kilnID,
            commodityID: 18
        ), 100)
        XCTAssertTrue(city.logistics.deliveryWalkers.isEmpty)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 2)
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
        XCTAssertTrue(city.logistics.deliveryWalkers.isEmpty)
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

        for _ in 0..<20 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.logistics[commodityID: 18], 100)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        XCTAssertNotNil(city.production.building(instanceID: clayPitID)?.activeDeliveryWalkerID)

        for _ in 0..<20 { _ = city.advanceTick(rules: rules) }
        XCTAssertTrue(city.logistics.deliveryWalkers.isEmpty)
        XCTAssertNil(city.production.building(instanceID: clayPitID)?.activeDeliveryWalkerID)
        XCTAssertEqual(city.production.localOutputAmount(
            buildingInstanceID: clayPitID,
            commodityID: 18
        ), 100)

        _ = city.advanceMonth(rules: rules)
        XCTAssertEqual(city.logistics.deliveryWalkers.count, 1)
        for _ in 0..<20 { _ = city.advanceTick(rules: rules) }
        XCTAssertEqual(city.logistics[commodityID: 18], 200)
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

    func testWorkforceShortageCausesOriginalFireAndCollapseRisks() throws {
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
        for _ in 0..<14 {
            _ = city.advanceMonth(rules: rules)
            failures.append(contentsOf: city.operations.lastSettlement?.failures ?? [])
        }
        XCTAssertTrue(failures.contains {
            $0.key.instanceID == kilnID && $0.kind == .fire
        })
        XCTAssertTrue(failures.contains {
            $0.key.instanceID == clayID && $0.kind == .collapse
        })
        XCTAssertFalse(city.production.buildings.contains { $0.id == kilnID || $0.id == clayID })
        XCTAssertFalse(city.placedBuildings.contains {
            $0.category == .production && $0.instanceID == kilnID
        })
        let ruin = try XCTUnwrap(city.placedBuildings.first {
            $0.category == .production && $0.instanceID == clayID
        })
        XCTAssertEqual(ruin.buildingID, OriginalBuildingSpriteCatalog.ruinBuildingID)
        XCTAssertEqual(ruin.footprint, BuildingFootprint(width: 2, height: 2))
        XCTAssertEqual(city.operations.lastSettlement?.workforce.availableWorkers, 0)
    }

    func testStaffedInspectorPatrolRepairsBuildingRisk() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 1600, treasury: 50_000, mapWidth: 12, mapHeight: 8)
        city.workforceEnabled = true
        city.housingEvolutionEnabled = false
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 5) }, rules: rules)
        _ = city.addHouse(
            levelID: 14,
            residents: 100,
            location: GridPoint(x: 11, y: 4),
            models: original.buildings
        )
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
        for _ in 0..<12 { _ = city.advanceMonth(rules: rules) }
        XCTAssertTrue(city.production.buildings.contains { $0.id == kilnID })
        XCTAssertTrue(city.residentialServiceBuildings.contains { $0.id == inspectorID })
        let kilnKey = OperationalBuildingKey(category: .production, instanceID: kilnID)
        XCTAssertTrue(city.operations.lastSettlement?.inspectedBuildingKeys.contains(kilnKey) == true)
        XCTAssertGreaterThan(city.operations.lastSettlement?.repairedRiskByBuildingKey[kilnKey] ?? 0, 0)
        let kilnRisk = city.operations.risks.first { $0.key == kilnKey }
        XCTAssertEqual(kilnRisk?.fireRisk, 0)
        XCTAssertEqual(kilnRisk?.damageRisk, 0)
        XCTAssertEqual(
            city.operations.lastSettlement?.workforce.assignments.first {
                $0.key == kilnKey
            }?.assignedWorkers,
            original.buildings[buildingID: 43]?.employees
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testOriginalHouseDiseaseAndCrimeRisksRespondToRoadServices() throws {
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
        var exposedEvents: [HouseHealthSafetyEvent] = []
        var calendar = SimulationCalendar(year: 1600, month: 1)
        for _ in 0..<4 {
            exposedEvents += exposed.advanceMonth(
                calendar: calendar,
                houses: &exposedHouses,
                models: original.buildings
            ).events
            calendar.advanceMonth()
        }
        XCTAssertTrue(exposedEvents.contains { $0.kind == .diseaseOutbreak })
        XCTAssertTrue(exposedEvents.contains { $0.kind == .theft })
        XCTAssertLessThan(exposedHouses[0].residents, 10)
        XCTAssertEqual(exposedHouses[0][commodityID: 25], 0)

        var protectedHouses = [ResidentialUnit(
            id: 2,
            houseLevelID: 0,
            residents: 10,
            hasTaxCoverage: true,
            foodSupplyAmount: 1_000,
            serviceCoverage: [.water, .herbalist, .acupuncture, .constable]
        )]
        var protected = DeterministicPublicHealthSafetyState()
        var protectedEvents: [HouseHealthSafetyEvent] = []
        for month in 1...12 {
            protectedEvents += protected.advanceMonth(
                calendar: SimulationCalendar(year: 1600, month: month),
                houses: &protectedHouses,
                models: original.buildings
            ).events
        }
        XCTAssertTrue(protectedEvents.isEmpty)
        XCTAssertEqual(protected.records.first?.diseaseRisk, 0)
        XCTAssertEqual(protected.records.first?.crimeRisk, 0)
        XCTAssertEqual(protectedHouses[0].residents, 10)
    }

    func testWatchtowerGuardProvidesPhysicalCrimeCoverage() throws {
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
        XCTAssertTrue(city.houses.first { $0.id == houseID }?.serviceCoverage.contains(.constable) == true)
        XCTAssertTrue(city.publicHealthSafety.lastSettlement?.protectedHouseIDs.contains(houseID) == true)
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

    func testVersion075EnemyManeuversFromAuthoredEntryAndBringsSiegeEngines() throws {
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
        XCTAssertEqual(maneuvering.siegeEngineCount, 2)
        XCTAssertEqual(maneuvering.status, .maneuvering)

        let battle = city.advanceMilitary(maximumStepsPerUnit: 100, models: original.figures)
        let report = try XCTUnwrap(battle.reports.first)
        XCTAssertEqual(report.enemySiegeEngineCount, 2)
        XCTAssertNotEqual(city.military.enemyForces.first?.status, .maneuvering)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ),
            city
        )
    }

    func testQinNomadInvasionRetainsSecondarySelectorAndUsesXiongnuInfantry() throws {
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
        XCTAssertEqual(force.enemyTypeID, 6)
        XCTAssertEqual(force.soldierCount, 9)
        XCTAssertEqual(force.route.first, invasionPoint)
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
