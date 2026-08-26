import XCTest
@testable import EmperorCore

final class XiaTutorialEconomyTests: XCTestCase {
    private let campaignName = "1 Xia Dynasty - Tutorials.pak"

    func testOriginalFirstMissionDataAndConstructionPermissions() throws {
        let source = try requireOriginalData()
        let url = source.campaignsDirectory.appendingPathComponent(campaignName)
        let campaign = try CampaignArchive(url: url)
        let settings = try CampaignMissionSettingsArchive(
            campaignURL: url,
            missionCount: campaign.missions.count
        ).missions[0]
        let goals = try CampaignGoalArchive(
            campaignURL: url,
            missionCount: campaign.missions.count
        ).missions[0]

        XCTAssertEqual(campaign.title, "Xia Dynasty Tutorials")
        XCTAssertEqual(campaign.missions[0].title, "Shelter and Sustenance")
        XCTAssertEqual(settings.startYear, -2038)
        XCTAssertEqual(settings.startMonth, 6)
        XCTAssertEqual(settings.initialFunds, 2_000)
        XCTAssertEqual(settings.allowedBuildingMenuIDs, [1, 12, 13, 20, 26, 29])
        XCTAssertEqual(settings.allowedResourceCommodityIDs, [4])
        XCTAssertEqual(goals.goals.count, 1)
        XCTAssertEqual(goals.goals[0].kind, .housing)
        XCTAssertEqual(goals.goals[0].values.map(Int.init), [5, 150, 0])

        let allowed = [33, 53, 59, 72, 124, 126, 214]
        XCTAssertTrue(allowed.allSatisfy { settings.constructionRestriction(forBuildingID: $0) == nil })
        XCTAssertNotNil(settings.constructionRestriction(forBuildingID: 35))
        XCTAssertEqual(OriginalProductionCatalog.recipe(forBuildingID: 33)?.outputCommodityID, 4)
    }

    func testUnifiedWorkforceStartsAtZeroThenReallocatesAfterResidentsAndDemolition() throws {
        let original = try OriginalEconomyModels(source: requireOriginalData())
        let rules = EconomyRulesEngine(models: original)
        var city = try makeRoadCity(rules: rules, houseCount: 4)
        let first = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 33,
            at: GridPoint(x: 2, y: 18),
            rules: rules
        ))
        let second = try XCTUnwrap(city.constructProductionBuilding(
            buildingID: 33,
            at: GridPoint(x: 5, y: 18),
            rules: rules
        ))

        var workforce = city.workforceSnapshot(models: original.buildings)
        XCTAssertEqual(workforce.availableWorkers, 0)
        XCTAssertEqual(workforce.assignments.map(\.assignedWorkers), [0, 0])
        XCTAssertTrue(city.production.buildings.allSatisfy { $0.assignedWorkers == 0 })

        // Fixture-only population setup isolates workforce allocation while
        // automatic migration waits for the original popularity producer.
        XCTAssertEqual(city.admitResidents(5, models: original.buildings), 5)
        _ = city.advanceTick(rules: rules)
        workforce = city.workforceSnapshot(models: original.buildings)
        XCTAssertEqual(workforce.availableWorkers, 5)
        XCTAssertEqual(workforce.assignments.map(\.assignedWorkers), [5, 0])
        XCTAssertTrue(city.production.buildings.allSatisfy { $0.assignedWorkers == 0 })

        XCTAssertEqual(city.admitResidents(10, models: original.buildings), 10)
        for _ in 0..<2 { _ = city.advanceTick(rules: rules) }
        workforce = city.workforceSnapshot(models: original.buildings)
        XCTAssertEqual(workforce.assignments.map(\.assignedWorkers), [15, 0])
        XCTAssertEqual(city.production.buildings.first(where: { $0.id == first })?.assignedWorkers, 15)

        XCTAssertEqual(city.admitResidents(5, models: original.buildings), 5)
        _ = city.advanceTick(rules: rules)
        workforce = city.workforceSnapshot(models: original.buildings)
        XCTAssertEqual(workforce.assignments.map(\.assignedWorkers), [15, 5])
        XCTAssertEqual(city.production.buildings.first(where: { $0.id == second })?.assignedWorkers, 0)

        _ = city.demolish(at: GridPoint(x: 2, y: 18), rules: rules)
        _ = city.advanceTick(rules: rules)
        workforce = city.workforceSnapshot(models: original.buildings)
        XCTAssertEqual(workforce.assignments.count, 1)
        XCTAssertEqual(workforce.assignments[0].assignedWorkers, 15)
        XCTAssertEqual(city.production.buildings.first(where: { $0.id == second })?.assignedWorkers, 15)
    }

    func testMarketLaborComesFromInstalledFoodShop() throws {
        let original = try OriginalEconomyModels(source: requireOriginalData())
        let rules = EconomyRulesEngine(models: original)
        var city = try makeRoadCity(rules: rules, houseCount: 1)
        let marketID = try XCTUnwrap(city.constructMarket(
            at: GridPoint(x: 2, y: 16),
            shopBuildingIDs: [OriginalFoodCatalog.foodShopBuildingID],
            rules: rules
        ))
        let placement = try XCTUnwrap(city.placement(category: .market, instanceID: marketID))
        var assignment = try XCTUnwrap(city.workforceAssignment(for: placement, models: original.buildings))
        XCTAssertEqual(assignment.requiredWorkers, 4)
        XCTAssertEqual(assignment.assignedWorkers, 0)
        XCTAssertEqual(city.admitResidents(4, models: original.buildings), 4)
        _ = city.advanceTick(rules: rules)
        assignment = try XCTUnwrap(city.workforceAssignment(for: placement, models: original.buildings))
        XCTAssertEqual(assignment.assignedWorkers, 4)
        XCTAssertTrue(assignment.isFullyStaffed)
    }

    func testMeatMovesThroughPhysicalMillBuyerAndPeddlerAndRecoveredServicesWriteCoverage() throws {
        let original = try OriginalEconomyModels(source: requireOriginalData())
        let rules = EconomyRulesEngine(models: original)
        // Keep all 24 houses between two original common markets. A single
        // peddler's 60-step route cannot cover every occupied address once
        // the corrected service cadence evolves the whole row together.
        var city = try makeRoadCity(rules: rules, houseCount: 24, houseStartX: 34)
        try placeTutorialFacilities(in: &city, rules: rules)
        // Fixture-only seeding lets this test continue validating the authored
        // downstream food/service chain without pretending migration is known.
        XCTAssertEqual(city.admitResidents(150, models: original.buildings), 150)

        var sawProducerStock = false
        var sawDeliveryWalker = false
        var sawAdjacentDeliverySteps = false
        var previousDeliveryPoint: GridPoint?
        var sawMillStock = false
        var sawBuyer = false
        var sawPeddler = false
        var sawHouseFood = false
        var sawWater = false
        var sawAncestor = false
        var sawInspection = false

        // The recovered producer gates each evolution on the **target** level's
        // food requirement, so houses only rise after the market delivers food
        // to them; give the far end of the row two years to be fed.
        for _ in 0..<(30 * 12 * 2) {
            let tick = city.advanceTick(rules: rules)
            sawProducerStock = sawProducerStock || city.production.buildings.contains {
                $0.buildingID == 33 && $0.outputInventoryByCommodityID[4, default: 0] > 0
            }
            if let walker = city.logistics.deliveryWalkers.first,
               let point = walker.currentPoint {
                sawDeliveryWalker = true
                if let previousDeliveryPoint {
                    let distance = abs(previousDeliveryPoint.x - point.x) + abs(previousDeliveryPoint.y - point.y)
                    sawAdjacentDeliverySteps = sawAdjacentDeliverySteps || distance == 1
                }
                previousDeliveryPoint = point
            }
            sawMillStock = sawMillStock || city.logistics.mills.contains {
                $0.inventoryByCommodityID[4, default: 0] > 0
            } || tick.movement.market.purchasedLoads.contains {
                $0.commodityID == 4 && $0.amount > 0
            }
            sawBuyer = sawBuyer
                || !city.markets.buyers.isEmpty
                || !tick.movement.market.purchasedLoads.isEmpty
            sawPeddler = sawPeddler
                || !city.markets.peddlers.isEmpty
                || !tick.movement.market.householdDeliveries.isEmpty
            sawHouseFood = sawHouseFood || city.houses.contains { $0.foodSupplyAmount > 0 }
            sawWater = sawWater || city.houses.contains { $0.serviceCoverage.contains(.water) }
            sawAncestor = sawAncestor || city.houses.contains { $0.serviceCoverage.contains(.ancestor) }
            sawInspection = sawInspection || city.houses.contains { $0.serviceCoverage.contains(.inspection) }
        }

        XCTAssertEqual(city.population, 150)
        XCTAssertTrue(sawProducerStock)
        XCTAssertTrue(sawDeliveryWalker)
        XCTAssertTrue(sawAdjacentDeliverySteps)
        XCTAssertTrue(sawMillStock)
        XCTAssertTrue(sawBuyer)
        XCTAssertTrue(sawPeddler)
        XCTAssertTrue(sawHouseFood)
        XCTAssertTrue(sawWater)
        XCTAssertTrue(sawAncestor)
        // Inspector figure #39 dispatches to its own 0x4CD230 FSM. The generic
        // residential-service bridge must not fabricate inspector coverage.
        XCTAssertFalse(sawInspection)
        // This fixture intentionally injects residents and still uses the
        // separate market-peddler approximation. The observations above prove
        // physical inventory movement and recovered service writes only; they
        // do not establish an original housing-evolution deadline or outcome.
    }

    private func requireOriginalData() throws -> GameDataSource {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        return try GameDataSource.openDefault()
    }

    private func makeRoadCity(
        rules: EconomyRulesEngine,
        houseCount: Int,
        houseStartX: Int = 1
    ) throws -> DeterministicCityState {
        var city = DeterministicCityState(
            year: -2038,
            month: 6,
            treasury: 20_000,
            mapWidth: 80,
            mapHeight: 40
        )
        city.workforceEnabled = true
        let road = (1...70).map { GridPoint(x: $0, y: 20) }
        XCTAssertEqual(city.buildRoad(road, rules: rules), road.count)
        // This fixture exercises the economy/service loop, not placement.
        // Keep its historical compact addresses through the direct state
        // seeding API; construction geometry is covered by dedicated tests.
        for x in houseStartX..<(houseStartX + houseCount) {
            XCTAssertNotNil(city.addHouse(
                levelID: 0,
                location: GridPoint(x: x, y: 21),
                models: rules.models.buildings
            ))
        }
        return city
    }

    private func placeTutorialFacilities(
        in city: inout DeterministicCityState,
        rules: EconomyRulesEngine
    ) throws {
        XCTAssertNotNil(city.constructProductionBuilding(
            buildingID: 33,
            at: GridPoint(x: 2, y: 18),
            rules: rules
        ))
        XCTAssertNotNil(city.constructProductionBuilding(
            buildingID: 33,
            at: GridPoint(x: 6, y: 18),
            rules: rules
        ))
        XCTAssertNotNil(city.constructMill(at: GridPoint(x: 12, y: 15), rules: rules))
        XCTAssertNotNil(city.constructMarket(
            at: GridPoint(x: 30, y: 16),
            shopBuildingIDs: [OriginalFoodCatalog.foodShopBuildingID],
            rules: rules
        ))
        XCTAssertNotNil(city.constructMarket(
            at: GridPoint(x: 60, y: 16),
            shopBuildingIDs: [OriginalFoodCatalog.foodShopBuildingID],
            rules: rules
        ))
        for (buildingID, x, seed) in [
            (72, 40, 0x101),
            (72, 48, 0x202),
            (72, 56, 0x303),
            (124, 38, 0x404),
            (214, 67, 0x505),
            (214, 44, 0x606),
        ] {
            XCTAssertNotNil(city.constructResidentialServiceBuilding(
                buildingID: buildingID,
                at: GridPoint(x: x, y: 18),
                replaySeed: UInt64(seed),
                rules: rules
            ), "service \(buildingID) at x=\(x)")
        }
    }
}
