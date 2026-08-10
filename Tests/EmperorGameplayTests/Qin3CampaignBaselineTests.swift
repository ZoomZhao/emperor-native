import EmperorCore
import XCTest
@testable import EmperorGameplay

final class Qin3CampaignBaselineTests: XCTestCase {
    private let missionID = 2

    func testMissionStartsWithOriginalSettingsGoalsMenusAndTradeRequirements() throws {
        let controller = try startedController()
        let city = try XCTUnwrap(controller.city)
        XCTAssertEqual(city.calendar.year, -219)
        XCTAssertEqual(city.calendar.month, 6)
        XCTAssertEqual(city.economy.treasury, 16_000)
        XCTAssertEqual(
            controller.activeWorld?.mapAssignment.embeddedMap.mapURL.lastPathComponent,
            "Xiangjun.map"
        )
        XCTAssertEqual(controller.activeWorld?.agriculturalClimate, .humid)
        XCTAssertEqual(
            city.missionSettings?.allowedResourceCommodityIDs,
            [2, 4, 6, 10, 14, 17, 18, 21, 22, 24, 25, 26]
        )
        for menuID in [6, 9, 11, 14, 16] {
            XCTAssertTrue(
                city.missionSettings?.allowedBuildingMenuIDs.contains(menuID) == true
            )
        }
        for menuID in [3, 7, 19, 43] {
            XCTAssertFalse(
                city.missionSettings?.allowedBuildingMenuIDs.contains(menuID) == true
            )
        }

        let goals = try missionGoals(controller)
        XCTAssertEqual(goals.goals.count, 4)
        XCTAssertTrue(goals.goals.contains {
            if case .population(1_800) = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goals.goals.contains {
            if case .housing(minimumLevelCode: 9, residents: 1_000) = $0.requirement {
                return true
            }
            return false
        })
        XCTAssertTrue(goals.goals.contains {
            if case .yearlyProduction(commodityID: 14, internalUnits: 1_600)
                = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goals.goals.contains {
            if case .yearlyProduction(commodityID: 26, internalUnits: 1_200)
                = $0.requirement { return true }
            return false
        })

        let southYue = try XCTUnwrap(city.trade.partner(id: 9))
        XCTAssertTrue(southYue.isOpen)
        XCTAssertNotEqual(southYue.supplyByCommodityID[17], TradeVolumeLevel.none)
        XCTAssertTrue(city.trade.partners.contains {
            $0.supplyByCommodityID[19, default: .none] != .none
        })
    }

    func testPlayerPlacedLacquerOrchardUsesXiangjunHumidClimate() throws {
        let controller = try startedController()
        XCTAssertTrue(controller.perform(.selectAgriculturalCrop(.lacquer)).wasApplied)
        XCTAssertTrue(controller.perform(.selectConstruction(.cropFarm)).wasApplied)
        let point = try XCTUnwrap(
            controller.city?.nextBuildingConstructionLocation(
                buildingID: AgriculturalCrop.lacquer.producerBuildingID
            )
        )
        let preview = controller.constructionPreview(at: point)
        XCTAssertTrue(preview.isValid, preview.reason ?? "invalid lacquer orchard")
        let result = controller.perform(
            .placeSelectedConstruction(at: point, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        let orchard = try XCTUnwrap(
            controller.city?.production.buildings.first {
                $0.agriculture?.crop == .lacquer
            }
        )
        XCTAssertEqual(orchard.agriculture?.climate, .humid)
    }

    func testTwoHumidLacquerOrchardsAndOneJadeWorkshopMeetAnnualTargets() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)

        var lacquerCity = productionTestCity(year: -219, month: 2)
        _ = lacquerCity.buildRoad(
            (0..<20).map { GridPoint(x: $0, y: 5) },
            rules: rules
        )
        _ = try XCTUnwrap(lacquerCity.constructWarehouse(
            serviceRoadStart: GridPoint(x: 8, y: 5),
            rules: rules
        ))
        for x in [6, 7] {
            _ = try XCTUnwrap(lacquerCity.constructAgriculturalProducer(
                crop: .lacquer,
                fieldCount: 6,
                fertilityPercent: 100,
                climate: .humid,
                serviceRoadStart: GridPoint(x: x, y: 5),
                rules: rules
            ))
        }
        for _ in 0..<12 { _ = lacquerCity.advanceMonth(rules: rules) }
        XCTAssertGreaterThanOrEqual(
            lacquerCity.productionAccounting
                .bestYearlyProductionUnitsByCommodityID[14, default: 0],
            1_600
        )

        var temperateCity = productionTestCity(year: -219, month: 2)
        _ = temperateCity.buildRoad(
            (0..<20).map { GridPoint(x: $0, y: 5) },
            rules: rules
        )
        _ = try XCTUnwrap(temperateCity.constructWarehouse(
            serviceRoadStart: GridPoint(x: 8, y: 5),
            rules: rules
        ))
        _ = try XCTUnwrap(temperateCity.constructAgriculturalProducer(
            crop: .lacquer,
            fieldCount: 6,
            fertilityPercent: 100,
            climate: .temperate,
            serviceRoadStart: GridPoint(x: 7, y: 5),
            rules: rules
        ))
        for _ in 0..<12 { _ = temperateCity.advanceMonth(rules: rules) }
        XCTAssertLessThanOrEqual(
            temperateCity.productionAccounting
                .bestYearlyProductionUnitsByCommodityID[14, default: 0],
            960
        )

        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        let campaignURL = source.campaignsDirectory
            .appendingPathComponent("4 Qin Dynasty.pak")
        let campaign = try CampaignArchive(url: campaignURL)
        let settings = try CampaignMissionSettingsArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let maps = try CampaignMissionMapArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count,
            candidateMapURLs: catalog.maps.map(\.url)
        )
        let empire = try XCTUnwrap(
            try CampaignEmpireMap.loadIfPresent(campaignURL: campaignURL)
        )
        let names = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        let world = try CampaignMissionWorldState(
            missionID: missionID,
            missionSettings: settings,
            missionMaps: maps,
            empireMap: empire,
            cityNames: names,
            tradeRules: original.trade
        )
        var jadeCity = productionTestCity(year: -220, month: 12)
        _ = jadeCity.buildRoad(
            (0..<20).map { GridPoint(x: $0, y: 5) },
            rules: rules
        )
        XCTAssertEqual(
            world.installTradePartners(in: &jadeCity, rules: rules),
            world.tradePartners.count
        )
        let tradingBuildingID = try XCTUnwrap(jadeCity.constructTradingBuilding(
            partnerID: 9,
            serviceRoadStart: GridPoint(x: 2, y: 5),
            rules: rules
        ))
        _ = try XCTUnwrap(jadeCity.constructWarehouse(
            serviceRoadStart: GridPoint(x: 8, y: 5),
            rules: rules
        ))
        jadeCity.setTradeImporting(
            true,
            commodityID: 17,
            tradingBuildingID: tradingBuildingID
        )
        let workshopID = try XCTUnwrap(jadeCity.constructProductionBuilding(
            buildingID: 46,
            assignedWorkers: 0,
            serviceRoadStart: GridPoint(x: 5, y: 5),
            rules: rules
        ))
        _ = jadeCity.advanceMonth(rules: rules)
        _ = jadeCity.advanceMonth(rules: rules)
        jadeCity.setProductionWorkers(
            original.buildings[buildingID: 46]?.employees ?? 0,
            buildingInstanceID: workshopID,
            models: original.buildings
        )
        for _ in 0..<12 { _ = jadeCity.advanceMonth(rules: rules) }
        XCTAssertGreaterThanOrEqual(
            jadeCity.productionAccounting
                .bestYearlyProductionUnitsByCommodityID[26, default: 0],
            1_200,
            "imports=\(jadeCity.trade.building(id: tradingBuildingID)?.importedUnitsThisCycleByCommodityID ?? [:]); "
                + "tradeStock=\(jadeCity.trade.building(id: tradingBuildingID)?.inventoryByCommodityID ?? [:]); "
                + "jadeInput=\(jadeCity.production.localInputAmount(buildingInstanceID: workshopID, commodityID: 17)); "
                + "jadeOutput=\(jadeCity.production.localOutputAmount(buildingInstanceID: workshopID, commodityID: 26)); "
                + "deliveries=\(jadeCity.logistics.deliveryWalkers.count)"
        )
        XCTAssertGreaterThanOrEqual(
            jadeCity.trade.building(id: tradingBuildingID)?
                .importedUnitsThisCycleByCommodityID[17, default: 0] ?? 0,
            1_200
        )
    }

    func testOriginalEventsActivateSouthYueAndApplyJadeTradeChanges() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try GameDataCatalog.scan(source)
        let campaignURL = source.campaignsDirectory
            .appendingPathComponent("4 Qin Dynasty.pak")
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
        let empire = try XCTUnwrap(
            try CampaignEmpireMap.loadIfPresent(campaignURL: campaignURL)
        )
        let names = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
        let events = try CampaignEventArchive(
            campaignURL: campaignURL,
            missionCount: campaign.missions.count
        )
        let world = try CampaignMissionWorldState(
            missionID: missionID,
            missionSettings: settings,
            missionMaps: maps,
            empireMap: empire,
            cityNames: names,
            tradeRules: original.trade
        )
        var city = DeterministicCityState(
            missionSettings: world.startSettings,
            mapWidth: 24,
            mapHeight: 12
        )
        XCTAssertEqual(world.installTradePartners(in: &city, rules: rules), world.tradePartners.count)
        let initialDemand = city.trade.partner(id: 0)?
            .demandByCommodityID[26, default: .none] ?? .none
        let jadePartners = city.trade.partners.filter {
            $0.demandByCommodityID[26] != nil || $0.supplyByCommodityID[26] != nil
        }
        let defaultJadePrice = original.trade[commodityID: 26]?.price ?? 0
        let initialPrices = Dictionary(uniqueKeysWithValues: jadePartners.map {
            ($0.id, $0.priceByCommodityID[26] ?? defaultJadePrice)
        })

        var runtime = CampaignMissionRuntimeState(
            missionID: missionID,
            startYear: world.startSettings.startYear,
            startMonth: world.startSettings.startMonth,
            eventSet: events.missions[missionID],
            replaySeed: 0x5149_4E33,
            empireMap: empire,
            playerCityID: world.playerCity?.id,
            cityNames: names
        )
        for _ in 0..<(12 * 10) {
            let settlement = city.advanceMonth(rules: rules)
            _ = runtime.advance(
                settlementYear: settlement.year,
                month: settlement.month,
                city: &city,
                rules: rules,
                goalSet: nil
            )
        }

        let southYue = try XCTUnwrap(city.trade.partner(id: 9))
        XCTAssertTrue(southYue.isOpen)
        let southYueEmpire = try XCTUnwrap(
            runtime.empireState?.cities.first(where: { $0.id == 9 })
        )
        XCTAssertTrue(southYueEmpire.isVisible)
        XCTAssertTrue(southYueEmpire.isActive)
        XCTAssertLessThan(southYueEmpire.favor, 25)
        XCTAssertGreaterThanOrEqual(
            city.trade.partner(id: 0)?.demandByCommodityID[26, default: .none]
                .rawValue ?? 0,
            min(TradeVolumeLevel.high.rawValue, initialDemand.rawValue + 1)
        )
        XCTAssertTrue(initialPrices.contains { partnerID, oldPrice in
            (city.trade.partner(id: partnerID)?.priceByCommodityID[26] ?? oldPrice)
                > oldPrice
        })
        XCTAssertTrue(runtime.occurrences.contains {
            $0.kind == .demandIncrease && $0.productID == 26
        })
        XCTAssertTrue(runtime.occurrences.contains {
            $0.kind == .priceIncrease && $0.productID == 26
        })
    }

    private func productionTestCity(year: Int, month: Int) -> DeterministicCityState {
        var city = DeterministicCityState(
            year: year,
            month: month,
            treasury: 100_000,
            mapWidth: 20,
            mapHeight: 10
        )
        city.housingEvolutionEnabled = false
        city.publicSafetyEnabled = false
        return city
    }

    private func startedController() throws -> GameSessionController {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let controller = try GameSessionController()
        let campaignID = try XCTUnwrap(
            controller.campaignID(fileName: "4 Qin Dynasty.pak")
        )
        let result = controller.perform(
            .startCampaignMission(campaignID: campaignID, missionID: missionID)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return controller
    }

    private func missionGoals(
        _ controller: GameSessionController
    ) throws -> CampaignMissionGoalSet {
        let campaignID = try XCTUnwrap(controller.selectedCampaignID)
        let campaign = controller.campaigns[campaignID]
        let archive = try CampaignGoalArchive(
            campaignURL: campaign.url,
            missionCount: campaign.missions.count
        )
        return archive.missions[missionID]
    }
}
