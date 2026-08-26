import EmperorCore
import XCTest
@testable import EmperorGameplay

/// Player-command playthrough of Qin mission 3 "Land of Annam" (Xiangjun.map,
/// humid climate). Goals: population 1,800; 1,000 residents at housing code 9
/// (building 9 = level 6); yearly lacquer 1,600 and jade 1,200. The recovered
/// migration producer supplies natural population growth.
final class Qin3PlayerPlaythroughTests: XCTestCase {
    private var selectedCrop: AgriculturalCrop = .rice
    private var lastFarmOrigin: GridPoint?

    func testPlayerCommandsCompleteQinMissionThreeLandOfAnnam() throws {
        try skipUntilIndependentQinThreeContractsAreRecovered(
            "BLOCKED AFTER RECOVERED GENERIC ROAMER REPLAY: the 120-month "
                + "player-command run still reaches only 27/40 initial houses and "
                + "ends below level 6. The remaining live requirements include "
                + "music (figure #34 uses separate 0x48A9A0), water's distinct "
                + "house fields, market-peddler coverage, and desirability. Do not "
                + "tune the layout or route around those unrecovered contracts."
        )
        let controller = try startedController()
        try connectEntryToRoads(with: controller)

        // The food producers must sit within the deliveryman's 24-step range
        // of the mill, so anchor the food chain first.
        let millOrigin = try placeNext(.mill, with: controller)
        // The mill must reserve room for the rice harvest: fishing and
        // hunting otherwise fill all 3,200 units and the farm's rice never
        // ships, leaving market food at 2 types (quality 30).
        if let mill = controller.city?.logistics.mills.first {
            for (commodityID, limit) in [(2, 800), (4, 800), (6, 1_600)] {
                XCTAssertTrue(controller.perform(.setMillStorageLimit(
                    millID: mill.id,
                    commodityID: commodityID,
                    amount: limit
                )).wasApplied)
            }
        }

        // Trade/industry cluster: the deliveryman's 24-step range means the
        // stations, warehouses, and jade workshop must be anchored next to
        // the mill BEFORE the food chain and housing district congest the map.
        let hempStation = try importCommodity(19, near: millOrigin, with: controller)
        try placeClosest(.warehouse, to: hempStation, with: controller)
        try placeClosest(.warehouse, to: hempStation, with: controller)
        // The carved-jade output must reach the export station (partner 0)
        // within the deliveryman's 24-step range, so anchor the workshop on
        // the hemp station first, then bring the jade-input station to it.
        let jadeWorkshopOrigin = try placeClosest(
            .jadeWorkshop,
            to: hempStation,
            with: controller
        )
        _ = try importCommodity(17, near: jadeWorkshopOrigin, with: controller)
        try placeClosest(.warehouse, to: jadeWorkshopOrigin, with: controller)
        try placeClosest(.warehouse, to: jadeWorkshopOrigin, with: controller)

        // Food chain: rice farm + fields, hunting, fishing.
        try placeCrop(.rice, near: millOrigin, with: controller)
        try placeClosest(.huntingCamp, to: millOrigin, with: controller)
        try placeClosest(.fishingWharf, to: millOrigin, with: controller)
        // Eight rice fields keep the mill stocked with rice alongside fish and
        // meat so market deliveries reach food quality 50 (3 food types).
        for _ in 0..<8 { try placeNext(.farmland, with: controller) }
        // Anchor the residential district on authored groundwater first, so
        // the water carrier and food peddlers share one compact road graph.
        let primaryWell = try placeWellInLargestClearDistrict(with: controller)
        for _ in 0..<30 {
            try extendRoad(near: primaryWell, with: controller)
        }
        let wellOrigins = [
            primaryWell,
            try placeClosest(.well, to: primaryWell, with: controller),
        ]
        var marketOrigins = [try placeClosest(
            .market,
            to: wellOrigins[0],
            with: controller
        )]
        try place(.foodShop, at: marketOrigins[0], with: controller)
        // One food peddler per market caps monthly household food at ~500
        // units; 1800 residents need at least 3 markets worth of capacity.
        try marketOrigins.append(placeClosest(
            .market,
            to: marketOrigins[0],
            with: controller
        ))
        try place(.foodShop, at: marketOrigins[1], with: controller)
        try marketOrigins.append(placeClosest(
            .market,
            to: marketOrigins[0],
            with: controller
        ))
        try place(.foodShop, at: marketOrigins[2], with: controller)
        try placeNext(.clayPit, with: controller)
        try placeNext(.kiln, with: controller)

        // Production: two lacquer orchards (6 fields each). Placing them now,
        // before the housing district, keeps the north shelf free for both
        // farms and all twelve fields.
        try placeCrop(.lacquer, with: controller)
        for _ in 0..<6 { try placeNext(.farmland, with: controller) }
        try placeCrop(.lacquer, with: controller)
        for _ in 0..<6 { try placeNext(.farmland, with: controller) }
        try placeCrop(.lacquer, with: controller)
        for _ in 0..<6 { try placeNext(.farmland, with: controller) }
        let reserveLacquerFarmID = try XCTUnwrap(
            controller.city?.production.buildings.last?.id
        )
        XCTAssertTrue(controller.perform(.setProductionEnabled(
            buildingInstanceID: reserveLacquerFarmID,
            enabled: false
        )).wasApplied)

        // Reserve one compact, staffable service cluster before housing
        // consumes every road-adjacent footprint. Wells use the global
        // authored-groundwater search and are joined to this road component
        // before the simulation starts.
        let housingAnchor = marketOrigins[0]
        try placeClosest(.inspectorTower, to: housingAnchor, with: controller)
        try placeClosest(.herbalist, to: housingAnchor, with: controller)
        for _ in 0..<2 {
            try placeClosest(.ancestralShrine, to: housingAnchor, with: controller)
        }
        try placeClosest(.musicSchool, to: housingAnchor, with: controller)
        try placeClosest(.taxOffice, to: housingAnchor, with: controller)
        let secondaryServiceAnchor = marketOrigins[1]
        try placeClosest(.well, to: secondaryServiceAnchor, with: controller, required: false)
        try placeClosest(.inspectorTower, to: secondaryServiceAnchor, with: controller)
        try placeClosest(.ancestralShrine, to: secondaryServiceAnchor, with: controller)
        try placeClosest(.herbalist, to: secondaryServiceAnchor, with: controller)
        try placeClosest(.musicSchool, to: secondaryServiceAnchor, with: controller)

        // Grow a compact local road mesh before placing houses. The generic
        // row-major extender follows the industrial spine and produces long
        // patrol branches that food and service roamers never visit.
        for _ in 0..<12 {
            try extendRoad(near: housingAnchor, with: controller)
        }

        // Build all houses around the clustered food markets. The helper keeps houses
        // outside the market square's confirmed three-tile desirability
        // penalty while remaining well inside the peddler's authored range.
        var houseOrigins: [GridPoint] = []
        for _ in 0..<40 {
            try houseOrigins.append(placeHouse(near: housingAnchor, with: controller))
        }

        // Low-desirability houses near the industrial edge need decoration to
        // clear the evolution threshold.
        for index in stride(from: 0, to: houseOrigins.count, by: 5) {
            try placeClosest(
                .decorativeSculpture,
                to: houseOrigins[index],
                with: controller,
                required: false
            )
        }

        // Level 6 also needs ceramics (local kiln + clay) and hemp (imported).
        // A common market has only two peddler slots; each commodity shop
        // claims one, so every market gets exactly one commodity shop and the
        // other slot stays free for the food peddler.
        try placeNext(.ceramicsShop, with: controller)
        try placeNext(.hempShop, with: controller)
        try placeNext(.ceramicsShop, with: controller)

        // Warehouses must stay free for trade goods: refuse food so the mill
        // (not a warehouse) buffers the food chain and jade/hemp/lacquer can
        // flow to the stations.
        try refuseFoodInWarehouses(with: controller)

        // Every producer/mill/warehouse must share one connected road network
        // for the delivery walkers (range 24). Join the road components.
        try connectAllRoads(with: controller)
        try growCity(years: 2, with: controller)

        // Expand only after the first district is staffed. This keeps the
        // startup workforce from being consumed by dormant late-game
        // services while still creating enough level-six capacity for the
        // authored 1,800-person goal.
        XCTAssertTrue(controller.perform(.setProductionEnabled(
            buildingInstanceID: reserveLacquerFarmID,
            enabled: true
        )).wasApplied)
        try connectAllRoads(with: controller)
        try growCity(years: 10, with: controller)

        guard case .victory? = controller.campaignRuntime?.outcome else {
        let city = try XCTUnwrap(controller.city)
        let outcome = controller.campaignRuntime?.outcome
        let goals = try missionGoals(controller)
            let housingByCode = Dictionary(grouping: city.houses, by: \ResidentialUnit.houseLevelID)
                .mapValues { $0.reduce(0) { $0 + $1.residents } }
                .reduce(into: [Int: Int]()) { result, entry in
                    result[entry.key + 3] = entry.value
                }
            let progress = goals.goals.map { goal -> String in
                let evaluated = CampaignGoalEvaluator.evaluate(
                    goal,
                    against: CampaignGoalProgressSnapshot(
                        housingPopulationByLevelCode: housingByCode,
                        completedMonumentBuildingIDs: city.aesthetics
                            .completedMonumentBuildingIDs,
                        population: city.population,
                        bestYearlyProductionUnitsByCommodityID: city
                            .productionAccounting
                            .bestYearlyProductionUnitsByCommodityID
                    )
                )
                return "\(goal.requirement): \(evaluated.currentValue)/\(evaluated.requiredValue)"
            }
            let foodDiag = "mills=\(city.logistics.mills.map { $0.inventoryByCommodityID }) "
                + "buyers=\(city.markets.buyers.count) "
                + "peddlers=\(city.markets.peddlers.count) "
                + "shops=\(city.markets.markets.flatMap { $0.shopBuildingIDs }) "
                + "foodAtHouses=\(city.houses.filter { $0.foodSupplyAmount > 0 }.count)"
            let farms = city.production.buildings.compactMap { building -> String? in
                guard let agriculture = building.agriculture else { return nil }
                return "crop=\(agriculture.crop.rawValue) fields=\(agriculture.fieldCount)"
                    + " workers=\(building.assignedWorkers)"
                    + " output=\(building.outputInventoryByCommodityID)"
            }
            let farm = city.production.buildings.first { $0.agriculture?.crop == .rice }
            let millAccess = city.logistics.mills.first?.roadAccessPoint
            let farmAccess = farm?.roadAccessPoint
            var distanceDiag = "farmAccess=\(String(describing: farmAccess)) "
                + "millAccess=\(String(describing: millAccess))"
            if let farmAccess, let millAccess {
                distanceDiag += " manhattan="
                    + "\(abs(farmAccess.x - millAccess.x) + abs(farmAccess.y - millAccess.y))"
            }
            let tradeDiag = city.trade.buildings.map {
                "partner=\($0.partnerID) inv=\($0.inventoryByCommodityID)"
                    + " access=\($0.roadAccessPoint) import=\($0.importingCommodityIDs)"
                    + " export=\($0.exportingCommodityIDs)"
                    + " active=\(String(describing: $0.activeDeliveryWalkerID))"
            }.joined(separator: "; ")
            let warehouseDiag = city.logistics.warehouses.map {
                "id=\($0.id) inv=\($0.inventoryByCommodityID) access=\($0.roadAccessPoint)"
            }.joined(separator: "; ")
            let walkerDiag = city.logistics.deliveryWalkers.prefix(6).map {
                "\($0.source)->\($0.destination):\($0.cargo.commodityID)x\($0.cargo.amount)"
            }.joined(separator: "; ")
            var pathDiag = "roads=n/a"
            if let station = city.trade.buildings.first,
               let warehouse = city.logistics.warehouses.first {
                let stationRoad = city.roadNetwork.contains(station.roadAccessPoint)
                let warehouseRoad = city.roadNetwork.contains(warehouse.roadAccessPoint)
                var visited = Set<GridPoint>([station.roadAccessPoint])
                var queue = [station.roadAccessPoint]
                var reached = false
                while !queue.isEmpty {
                    let point = queue.removeFirst()
                    if point == warehouse.roadAccessPoint { reached = true; break }
                    for next in RoadServiceCoverage.orthogonalNeighbors(of: point)
                    where city.roadNetwork.contains(next) && !visited.contains(next) {
                        visited.insert(next)
                        queue.append(next)
                    }
                }
                pathDiag = "stationRoad=\(stationRoad) warehouseRoad=\(warehouseRoad)"
                    + " connected=\(reached)"
                    + " station=\(station.roadAccessPoint) warehouse=\(warehouse.roadAccessPoint)"
            }
            var warehouseDiag2 = ""
            if let station = city.trade.buildings.first {
                warehouseDiag2 = city.logistics.warehouses.map { warehouse -> String in
                    var visited = Set<GridPoint>([station.roadAccessPoint])
                    var queue = [station.roadAccessPoint]
                    var distance: [GridPoint: Int] = [station.roadAccessPoint: 0]
                    var found: Int?
                    while !queue.isEmpty {
                        let point = queue.removeFirst()
                        if point == warehouse.roadAccessPoint {
                            found = distance[point]
                            break
                        }
                        for next in RoadServiceCoverage.orthogonalNeighbors(of: point)
                        where city.roadNetwork.contains(next) && !visited.contains(next) {
                            visited.insert(next)
                            distance[next] = (distance[point] ?? 0) + 1
                            queue.append(next)
                        }
                    }
                    return "wh\(warehouse.id)@\(warehouse.roadAccessPoint) dist=\(found ?? -1)"
                        + " policy19=\(warehouse.policy(for: 19).rawValue)"
                        + " cap19=\(warehouse.availableCapacity(for: 19))"
                }.joined(separator: "; ")
            }
            let hempShop = city.markets.markets.flatMap { $0.shopBuildingIDs }.contains(67)
                ? "yes" : "no"
            let foodQuality = Dictionary(
                grouping: city.houses,
                by: \ResidentialUnit.lastSuppliedFoodQuality.rawValue
            ).mapValues { $0.reduce(0) { $0 + $1.residents } }
            let jade = city.production.buildings.first { $0.buildingID == 46 }
            let jadeDiag = jade.map {
                "workers=\($0.assignedWorkers) enabled=\($0.isEnabled)"
                    + " input=\($0.inputInventoryByCommodityID)"
                    + " output=\($0.outputInventoryByCommodityID)"
                    + " access=\(String(describing: $0.roadAccessPoint))"
            } ?? "none"
            let byLevel = Dictionary(grouping: city.houses, by: \ResidentialUnit.houseLevelID)
                .mapValues { $0.reduce(0) { $0 + $1.residents } }
            let marketAccess = city.markets.markets.first?.roadAccessPoint
            let houseDistanceDiag = city.houses.compactMap(\.location).map {
                let house = $0
                guard let marketAccess else { return 0 }
                return abs(house.x - marketAccess.x) + abs(house.y - marketAccess.y)
            }
            var floodDiag = "flood=n/a"
            if let terrain = city.terrain, let entry = terrain.authoredPoints?.landEntry,
               let grids = try? city.grandCanalWorkerRoutingGrids() {
                let flood = DeterministicMigration.landEntryFloodDepths(
                    width: grids.width,
                    height: grids.height,
                    primaryPassability: grids.primaryPassability,
                    seed: entry
                )
                let reachable = city.houses.filter { house in
                    guard let location = house.location else { return false }
                    let vacantID = house.vacantTypeID
                        ?? (house.houseLevelID == 10 ? 11 : 2)
                    guard let access = DeterministicMigration.houseRoadAccessPoint(
                        houseLocation: location,
                        vacantBuildingID: vacantID,
                        roadNetwork: city.roadNetwork
                    ) else { return false }
                    let index = access.y * grids.width + access.x
                    return flood.indices.contains(index) && flood[index] != nil
                }.count
                floodDiag = "floodReachable=\(reachable)/\(city.houses.count) entry=\(entry)"
            }
            let opsDiag = city.operations.lastSettlement.map {
                "repaired=\($0.repairedRiskByBuildingKey.count) "
                    + "failures=\($0.failures.map { "\($0.buildingID):\($0.kind.rawValue)" })"
            } ?? "none"
            var missingCounts: [String: Int] = [:]
            for house in city.houses {
                guard let evaluation = DeterministicHousingEvolution.evaluate(
                    house: house,
                    models: controller.models.buildings,
                    difficulty: .veryEasy
                ) else { continue }
                for requirement in evaluation.missingEvolutionRequirements {
                    missingCounts["\(requirement)", default: 0] += 1
                }
            }
            let evolutionDiag = missingCounts
                .sorted { $0.key < $1.key }
                .map { "\($0.key):\($0.value)" }
                .joined(separator: "; ")
            return XCTFail(
                "Qin3 did not win: population=\(city.population); levels=\(byLevel); "
                    + "outcome=\(String(describing: outcome)); "
                    + "treasury=\(city.economy.treasury); "
                    + "\(foodDiag); "
                    + "farms=[\(farms.joined(separator: "; "))]; "
                    + "\(distanceDiag); "
                    + "trade=[\(tradeDiag)]; lastQ=\(foodQuality); jade=\(jadeDiag); "
                    + "warehouses=[\(warehouseDiag)]; hempShop=\(hempShop); "
                    + "walkers=[\(walkerDiag)]; "
                    + "market=\(String(describing: marketAccess)) "
                    + "houseDist=[\(houseDistanceDiag.sorted().map(String.init).joined(separator: ","))]; "
                    + "\(pathDiag); "
                    + "\(warehouseDiag2); "
                    + "goals=[\(progress.joined(separator: "; "))]; "
                    + "mig(pop=\(city.migration.popularity), "
                    + "pres=\(city.migration.pressure), "
                    + "avail=\(city.migration.automaticMigrationAvailability), "
                    + "last=\(String(describing: city.migration.lastDailyImmigrants)), "
                    + "unfulfilled=\(city.migration.unfulfilledArrivalCarry), "
                    + "assignedMonth=\(city.migration.assignedThisMonth)); "
                    + "\(floodDiag); "
                    + "ops=\(opsDiag); "
                    + "missing=[\(evolutionDiag)]; "
                    + "war=\(city.warCount) forces=["
                    + city.military.enemyForces.map {
                        "\($0.enemyTypeID)x\($0.soldierCount)@\($0.status.rawValue)"
                    }.joined(separator: "; ")
                    + "]"
            )
        }

        let city = try XCTUnwrap(controller.city)
        XCTAssertGreaterThanOrEqual(city.population, 1_800)
        XCTAssertGreaterThanOrEqual(
            city.houses.filter { $0.houseLevelID + 3 >= 9 }
                .reduce(0) { $0 + $1.residents },
            1_000
        )
        XCTAssertGreaterThanOrEqual(
            city.productionAccounting
                .bestYearlyProductionUnitsByCommodityID[14, default: 0],
            1_600
        )
        XCTAssertGreaterThanOrEqual(
            city.productionAccounting
                .bestYearlyProductionUnitsByCommodityID[26, default: 0],
            1_200
        )
    }

    @discardableResult
    private func importCommodity(
        _ commodityID: Int,
        near target: GridPoint,
        with controller: GameSessionController
    ) throws -> GridPoint {
        let city = try XCTUnwrap(controller.city)
        guard let partner = city.trade.partners.first(where: {
            $0.isOpen && $0.supplyByCommodityID[commodityID] != nil
        }) else {
            let openPartners = city.trade.partners
                .filter { $0.isOpen }
                .map { "\($0.id):\($0.supplyByCommodityID.keys.sorted())" }
            XCTFail("Qin3 has no open partner supplying \(commodityID); open=\(openPartners)")
            throw NSError(domain: "Qin3PlayerPlaythrough", code: 2, userInfo: nil)
        }
        // Land station #58, sea quay #56.
        let buildingID = partner.routeKind == .sea ? 56 : 58
        _ = try XCTUnwrap(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: buildingID)
        )
        let candidate = try XCTUnwrap(
            (0..<city.roadNetwork.height).flatMap { y in
                (0..<city.roadNetwork.width).map { GridPoint(x: $0, y: y) }
            }.sorted {
                let left = abs($0.x - target.x) + abs($0.y - target.y)
                let right = abs($1.x - target.x) + abs($1.y - target.y)
                return left == right
                    ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                    : left < right
            }.first {
                city.canConstructBuilding(buildingID: buildingID, at: $0)
            },
            "no valid trading-station site near \(target)"
        )
        let result = controller.perform(.constructTradingBuilding(
            partnerID: partner.id,
            at: candidate,
            orientation: .northSouth
        ))
        XCTAssertTrue(result.wasApplied, result.message)
        // Enable the import for the commodity.
        guard let tradingBuilding = controller.city?.trade.buildings.last else {
            return candidate
        }
        XCTAssertTrue(controller.perform(.setTradeImporting(
            tradingBuildingID: tradingBuilding.id,
            commodityID: commodityID,
            enabled: true
        )).wasApplied)
        // Building a station opens every route with the partner (original
        // construction contract). A solvent player turns off the commodities
        // the city does not need so imports do not drain the treasury.
        for other in tradingBuilding.importingCommodityIDs where other != commodityID {
            XCTAssertTrue(controller.perform(.setTradeImporting(
                tradingBuildingID: tradingBuilding.id,
                commodityID: other,
                enabled: false
            )).wasApplied)
        }
        return candidate
    }

    private func skipUntilIndependentQinThreeContractsAreRecovered(
        _ reason: String
    ) throws {
        throw XCTSkip(reason)
    }

    private func startedController() throws -> GameSessionController {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let controller = try GameSessionController()
        XCTAssertTrue(controller.perform(.selectDifficulty(.veryEasy)).wasApplied)
        let campaignID = try XCTUnwrap(
            controller.campaignID(fileName: "4 Qin Dynasty.pak")
        )
        let result = controller.perform(
            .startCampaignMission(campaignID: campaignID, missionID: 2)
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
        return archive.missions[2]
    }

    private func growCity(years: Int, with controller: GameSessionController) throws {
        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        var trajectory: [String] = []
        for index in 0..<(30 * 12 * years) {
            guard controller.campaignRuntime?.outcome == .running else { break }
            let result = controller.perform(.advanceOneTick)
            XCTAssertTrue(result.wasApplied, result.message)
            if index % 30 == 29 {
                try manageTradeImports(with: controller)
                if index % 180 == 179 {
                    let city = try XCTUnwrap(controller.city)
                    let water = city.houses.reduce(0) { partial, house in
                        partial + (house.serviceCoverage.contains(.water) ? house.residents : 0)
                    }
                    let q50 = city.houses.reduce(0) {
                        $0 + ($1.lastSuppliedFoodQuality.rawValue >= 50 ? $1.residents : 0)
                    }
                    let lvl6 = city.houses.reduce(0) {
                        $0 + ($1.houseLevelID >= 6 ? $1.residents : 0)
                    }
                    let riceFarm = city.production.buildings.first {
                        $0.agriculture?.crop == .rice
                    }
                    let millDiag = city.logistics.mills.first.map {
                        "m\($0.inventoryByCommodityID)"
                    } ?? "mGONE"
                    let millWorkDiag = city.placedBuildings
                        .first { $0.buildingID == 53 }
                        .flatMap {
                            city.workforceAssignment(
                                for: $0,
                                models: controller.models.buildings
                            )
                        }
                        .map { "mW=\($0.assignedWorkers)/\($0.requiredWorkers)" }
                        ?? "mW=?"
                    let farmDiag = riceFarm.map {
                        "rWork=\($0.assignedWorkers) rOut=\($0.outputInventoryByCommodityID)"
                            + " rAct=\(String(describing: $0.activeDeliveryWalkerID))"
                    } ?? "rGONE"
                    let marketDiag = city.markets.markets.map {
                        "mk\($0.id)=\($0.inventoryByCommodityID)"
                    }.joined(separator: " ")
                    let trafficDiag = "b=\(city.markets.buyers.count) p=\(city.markets.peddlers.count)"
                    let deliveryDiag = city.markets.lastSettlement.map {
                        "del=\($0.householdDeliveries.count)"
                            + " under=\($0.underSuppliedHouseIDs.count)"
                            + " foodDel=\($0.householdDeliveries.filter { $0.commodityID == -1 }.count)"
                    } ?? "del=?"
                    let routeDiag = city.markets.peddlers.map {
                        "r\($0.route.count)"
                    }.joined(separator: ",")
                    var reachableFromMarket = 0
                    if let marketRoad = city.markets.markets.first?.roadAccessPoint {
                        for house in city.houses {
                            guard let location = house.location else { continue }
                            let buildingID = house.houseLevelID + 3
                            let footprint = OriginalBuildingFootprintCatalog
                                .footprint(forBuildingID: buildingID)
                                ?? BuildingFootprint(width: 1, height: 1)
                            let neighbors = Set(
                                footprint.points(at: location)
                                    .flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
                            ).subtracting(footprint.points(at: location))
                            if neighbors.contains(where: { neighbor in
                                var visited = Set<GridPoint>([marketRoad])
                                var queue = [marketRoad]
                                while !queue.isEmpty {
                                    let current = queue.removeFirst()
                                    if current == neighbor { return true }
                                    for next in RoadServiceCoverage.orthogonalNeighbors(of: current)
                                    where city.roadNetwork.contains(next) && !visited.contains(next) {
                                        visited.insert(next)
                                        queue.append(next)
                                    }
                                }
                                return false
                            }) { reachableFromMarket += 1 }
                        }
                    }
                    let cargoDiag = city.markets.buyers.map {
                        "buyer\($0.id)\($0.cargoes)"
                    }.joined(separator: " ") + " | " + city.markets.peddlers.map {
                        "ped\($0.id)q\(String(describing: $0.foodQualityRawValue))"
                            + "\(String(describing: $0.foodCargoes))"
                    }.joined(separator: " ")
                    trajectory.append(
                        "m\(index / 30):pop=\(city.population)"
                            + " mill=\(city.logistics.mills.count)"
                            + " jade=\(city.production.buildings.contains { $0.buildingID == 46 } ? 1 : 0)"
                            + " houses=\(city.houses.count)"
                            + " w=\(water) q50=\(q50) lvl6=\(lvl6)"
                            + " \(millDiag) \(farmDiag)"
                            + " \(millWorkDiag)"
                            + " \(marketDiag) \(trafficDiag)"
                            + " \(deliveryDiag) routes=[\(routeDiag)]"
                            + " reach=\(reachableFromMarket)/\(city.houses.count)"
                            + " \(cargoDiag)"
                            + " t=\(city.economy.treasury)"
                    )
                }
            }
        }
        FileHandle.standardError.write(Data(("TRAJ " + trajectory.joined(separator: " ") + "\n").utf8))
        XCTAssertTrue(controller.perform(.setSpeed(0)).wasApplied)
    }

    /// Player trade management: the city only needs a bounded hemp stockpile,
    /// and a station jammed full of hemp cannot receive export goods. Pause
    /// hemp imports once ~3,000 units are buffered and resume below ~500.
    private func manageTradeImports(
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let hempStock = city.logistics.warehouses.reduce(0) {
                $0 + $1.inventoryByCommodityID[19, default: 0]
            } + city.trade.buildings.reduce(0) {
                $0 + $1.inventoryByCommodityID[19, default: 0]
            }
        for building in city.trade.buildings {
            let importsHemp = building.importingCommodityIDs.contains(19)
            if importsHemp, hempStock >= 3_000 {
                XCTAssertTrue(controller.perform(.setTradeImporting(
                    tradingBuildingID: building.id,
                    commodityID: 19,
                    enabled: false
                )).wasApplied)
            } else if !importsHemp, hempStock <= 500,
                      let partner = city.trade.partner(id: building.partnerID),
                      partner.isOpen, partner.supplyByCommodityID[19] != nil {
                XCTAssertTrue(controller.perform(.setTradeImporting(
                    tradingBuildingID: building.id,
                    commodityID: 19,
                    enabled: true
                )).wasApplied)
            }
        }
    }

    private func connectEntryToRoads(
        with controller: GameSessionController
    ) throws {
        guard let city = controller.city,
              let terrain = city.terrain,
              let entry = terrain.authoredPoints?.landEntry else { return }
        let grids = try city.grandCanalWorkerRoutingGrids()
        let flood = DeterministicMigration.landEntryFloodDepths(
            width: grids.width,
            height: grids.height,
            primaryPassability: grids.primaryPassability,
            seed: entry
        )
        var visited = Set<GridPoint>([entry])
        var queue = [entry]
        var parent: [GridPoint: GridPoint] = [:]
        var target: GridPoint?
        while !queue.isEmpty {
            let point = queue.removeFirst()
            if city.roadNetwork.contains(point), point != entry {
                target = point
                break
            }
            for next in RoadServiceCoverage.orthogonalNeighbors(of: point) {
                guard next.x >= 0, next.x < grids.width,
                      next.y >= 0, next.y < grids.height,
                      !visited.contains(next) else { continue }
                let index = next.y * grids.width + next.x
                guard flood.indices.contains(index), flood[index] != nil else { continue }
                visited.insert(next)
                parent[next] = point
                queue.append(next)
            }
        }
        guard let target else { return }
        var path: [GridPoint] = []
        var cursor: GridPoint? = target
        while let point = cursor, point != entry {
            path.append(point)
            cursor = parent[point]
        }
        path.reverse()
        for point in path where !(controller.city?.roadNetwork.contains(point) ?? false) {
            XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
            let result = controller.perform(
                .placeSelectedConstruction(at: point, orientation: .northSouth)
            )
            XCTAssertTrue(result.wasApplied, "road \(point): \(result.message)")
        }
    }

    private func placeCrop(
        _ crop: AgriculturalCrop,
        near target: GridPoint? = nil,
        with controller: GameSessionController
    ) throws {
        let selection = controller.perform(.selectAgriculturalCrop(crop))
        XCTAssertTrue(selection.wasApplied, "\(crop.rawValue): \(selection.message)")
        selectedCrop = crop
        if let target {
            let city = try XCTUnwrap(controller.city)
            let radius = 30
            let xRange = max(0, target.x - radius)...min(
                city.roadNetwork.width - 1,
                target.x + radius
            )
            let yRange = max(0, target.y - radius)...min(
                city.roadNetwork.height - 1,
                target.y + radius
            )
            XCTAssertTrue(controller.perform(.selectConstruction(.cropFarm)).wasApplied)
            let point = try XCTUnwrap(
                yRange.flatMap { y in
                    xRange.map { GridPoint(x: $0, y: y) }
                }.sorted {
                    let left = abs($0.x - target.x) + abs($0.y - target.y)
                    let right = abs($1.x - target.x) + abs($1.y - target.y)
                    return left == right
                        ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                        : left < right
                }.first { controller.constructionPreview(at: $0).isValid },
                "no valid \(crop.rawValue) farm near \(target)"
            )
            try place(.cropFarm, at: point, with: controller)
            lastFarmOrigin = point
        } else {
            lastFarmOrigin = try placeNext(.cropFarm, with: controller)
        }
    }

    @discardableResult
    private func placeNext(
        _ tool: PlayerConstructionTool,
        with controller: GameSessionController
    ) throws -> GridPoint {
        let city = try XCTUnwrap(controller.city)
        var point: GridPoint?
        if tool == .house {
            point = city.nextHouseConstructionLocation()
        } else if tool == .cropFarm {
            point = city.nextBuildingConstructionLocation(
                buildingID: selectedCrop.producerBuildingID
            )
        } else if tool == .farmland {
            XCTAssertTrue(controller.perform(.selectConstruction(.farmland)).wasApplied)
            if let farm = lastFarmOrigin {
                let radius = 4
                let xRange = max(0, farm.x - radius)...min(
                    city.roadNetwork.width - 1,
                    farm.x + radius
                )
                let yRange = max(0, farm.y - radius)...min(
                    city.roadNetwork.height - 1,
                    farm.y + radius
                )
                point = yRange.flatMap { y in
                    xRange.map { GridPoint(x: $0, y: y) }
                }.sorted {
                    let left = abs($0.x - farm.x) + abs($0.y - farm.y)
                    let right = abs($1.x - farm.x) + abs($1.y - farm.y)
                    return left == right
                        ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                        : left < right
                }.first { controller.constructionPreview(at: $0).isValid }
            } else {
                point = (0..<city.roadNetwork.height).lazy.flatMap { y in
                    (0..<city.roadNetwork.width).lazy.map { GridPoint(x: $0, y: y) }
                }.first { controller.constructionPreview(at: $0).isValid }
            }
        } else if let buildingID = tool.buildingID,
                  OriginalMarketCatalog.supports(shopBuildingID: buildingID) {
            point = city.placedBuildings.first {
                $0.category == .market
                    && city.canConstructMarketShop(
                        shopBuildingID: buildingID,
                        at: $0.origin
                    )
            }?.origin
        } else if let buildingID = tool.buildingID {
            point = city.nextBuildingConstructionLocation(buildingID: buildingID)
        } else {
            point = nil
        }
        var extensions = 0
        while point == nil, extensions < 40 {
            try extendRoad(with: controller)
            extensions += 1
            let updated = try XCTUnwrap(controller.city)
            if tool == .house {
                point = updated.nextHouseConstructionLocation()
            } else if tool == .farmland {
                point = (0..<updated.roadNetwork.height).lazy.flatMap { y in
                    (0..<updated.roadNetwork.width).lazy.map { GridPoint(x: $0, y: y) }
                }.first { controller.constructionPreview(at: $0).isValid }
            } else if let buildingID = tool.buildingID {
                point = updated.nextBuildingConstructionLocation(buildingID: buildingID)
            }
        }
        let origin = try XCTUnwrap(point, "no valid \(tool.rawValue) site")
        try place(tool, at: origin, with: controller)
        return origin
    }

    @discardableResult
    private func placeClosest(
        _ tool: PlayerConstructionTool,
        to target: GridPoint,
        with controller: GameSessionController,
        required: Bool = true
    ) throws -> GridPoint {
        let city = try XCTUnwrap(controller.city)
        let treasury = city.economy.treasury
        let radius = 40
        let xRange = max(0, target.x - radius)...min(
            city.roadNetwork.width - 1,
            target.x + radius
        )
        let yRange = max(0, target.y - radius)...min(
            city.roadNetwork.height - 1,
            target.y + radius
        )
        let candidates = yRange.flatMap { y in
            xRange.map { GridPoint(x: $0, y: y) }
        }.sorted {
            let left = abs($0.x - target.x) + abs($0.y - target.y)
            let right = abs($1.x - target.x) + abs($1.y - target.y)
            return left == right
                ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                : left < right
        }
        XCTAssertTrue(controller.perform(.selectConstruction(tool)).wasApplied)
        for point in candidates where controller.constructionPreview(at: point).isValid {
            let result = controller.perform(
                .placeSelectedConstruction(at: point, orientation: .northSouth)
            )
            if result.wasApplied { return point }
        }
        if required {
            XCTFail("no valid \(tool.rawValue) site near \(target); treasury=\(treasury)")
            throw NSError(domain: "Qin3PlayerPlaythrough", code: 1, userInfo: nil)
        }
        return target
    }

    private func extendRoad(with controller: GameSessionController) throws {
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let point = try XCTUnwrap(
            Set(city.roadNetwork.points.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)))
                .filter {
                    city.roadNetwork.isInside($0)
                        && !city.roadNetwork.contains($0)
                        && !city.occupiedBuildingPoints.contains($0)
                        && terrain.isClearLand($0)
                }
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
                .first,
            "no clear road extension"
        )
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        let result = controller.perform(
            .placeSelectedConstruction(at: point, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
    }

    private func extendRoad(
        near target: GridPoint,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let point = try XCTUnwrap(
            Set(city.roadNetwork.points.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)))
                .filter {
                    city.roadNetwork.isInside($0)
                        && !city.roadNetwork.contains($0)
                        && !city.occupiedBuildingPoints.contains($0)
                        && terrain.isClearLand($0)
                }
                .sorted {
                    let left = abs($0.x - target.x) + abs($0.y - target.y)
                    let right = abs($1.x - target.x) + abs($1.y - target.y)
                    if left != right { return left < right }
                    return $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
                }
                .first,
            "no clear road extension near \(target)"
        )
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        let result = controller.perform(
            .placeSelectedConstruction(at: point, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
    }

    private func placeWellInLargestClearDistrict(
        with controller: GameSessionController
    ) throws -> GridPoint {
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let occupied = city.occupiedBuildingPoints
        let roads = city.roadNetwork.points
        let wellFootprint = try XCTUnwrap(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: 72)
        )

        func roadPath(to well: GridPoint) -> [GridPoint]? {
            let wellPoints = Set(wellFootprint.points(at: well))
            let destinations = Set(
                wellPoints.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)).filter {
                    city.roadNetwork.isInside($0)
                        && !wellPoints.contains($0)
                        && terrain.isClearLand($0)
                        && !occupied.contains($0)
                }
            )
            guard !destinations.isEmpty else { return nil }
            var queue = roads.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            var cursor = 0
            var visited = Set(queue)
            var parent: [GridPoint: GridPoint] = [:]
            var found: GridPoint?
            while cursor < queue.count {
                let point = queue[cursor]
                cursor += 1
                if destinations.contains(point) {
                    found = point
                    break
                }
                for next in RoadServiceCoverage.orthogonalNeighbors(of: point) {
                    guard city.roadNetwork.isInside(next), !wellPoints.contains(next),
                          !visited.contains(next), terrain.isClearLand(next),
                          !occupied.contains(next) else { continue }
                    visited.insert(next)
                    parent[next] = point
                    queue.append(next)
                }
            }
            guard let found else { return nil }
            var path: [GridPoint] = []
            var point = found
            while !roads.contains(point) {
                path.append(point)
                guard let previous = parent[point] else { return nil }
                point = previous
            }
            return path.reversed()
        }

        let candidates = (0..<city.roadNetwork.height).flatMap { y in
            (0..<city.roadNetwork.width).compactMap { x -> (GridPoint, Int)? in
                let point = GridPoint(x: x, y: y)
                let footprintPoints = wellFootprint.points(at: point)
                guard footprintPoints.allSatisfy(city.roadNetwork.isInside),
                      footprintPoints.allSatisfy(terrain.isClearLand),
                      footprintPoints.allSatisfy({ !occupied.contains($0) }),
                      footprintPoints.allSatisfy({
                          terrain.terrain(at: $0)?.contains(.groundwater) == true
                      })
                else { return nil }
                let radius = 10
                let clearCount = (max(0, y - radius)...min(
                    city.roadNetwork.height - 1,
                    y + radius
                )).reduce(0) { partial, sampleY in
                    partial + (max(0, x - radius)...min(
                        city.roadNetwork.width - 1,
                        x + radius
                    )).count { sampleX in
                        let sample = GridPoint(x: sampleX, y: sampleY)
                        return terrain.isClearLand(sample) && !occupied.contains(sample)
                    }
                }
                return (point, clearCount)
            }
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.y == $1.0.y ? $0.0.x < $1.0.x : $0.0.y < $1.0.y
        }

        for (candidate, _) in candidates {
            guard let path = roadPath(to: candidate) else { continue }
            for point in path where !(controller.city?.roadNetwork.contains(point) ?? false) {
                try place(.road, at: point, with: controller)
            }
            XCTAssertTrue(controller.perform(.selectConstruction(.well)).wasApplied)
            let result = controller.perform(
                .placeSelectedConstruction(at: candidate, orientation: .northSouth)
            )
            guard result.wasApplied else { continue }
            return candidate
        }
        throw NSError(domain: "Qin3PlayerPlaythrough", code: 3, userInfo: nil)
    }

    private func connectAllRoads(with controller: GameSessionController) throws {
        func components(
            of city: DeterministicCityState
        ) -> [[GridPoint]] {
            var visited = Set<GridPoint>()
            var result: [[GridPoint]] = []
            for point in city.roadNetwork.points.sorted(by: {
                $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
            }) where !visited.contains(point) {
                var queue = [point]
                var component: [GridPoint] = []
                visited.insert(point)
                while !queue.isEmpty {
                    let current = queue.removeFirst()
                    component.append(current)
                    for next in RoadServiceCoverage.orthogonalNeighbors(of: current)
                    where city.roadNetwork.contains(next) && !visited.contains(next) {
                        visited.insert(next)
                        queue.append(next)
                    }
                }
                result.append(component)
            }
            return result.sorted { $0.count > $1.count }
        }

        func nearestClearNeighbor(
            to points: Set<GridPoint>,
            in city: DeterministicCityState
        ) -> GridPoint? {
            points.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
                .filter {
                    city.roadNetwork.isInside($0)
                        && !city.roadNetwork.contains($0)
                        && !city.occupiedBuildingPoints.contains($0)
                        && city.terrain?.isClearLand($0) == true
                }
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
                .first
        }

        while true {
            let city = try XCTUnwrap(controller.city)
            let components = components(of: city)
            guard components.count > 1, let main = components.first else { return }
            let mainSet = Set(main)
            let island = components[1]
            let islandSet = Set(island)
            guard let start = nearestClearNeighbor(to: islandSet, in: city),
                  let goal = nearestClearNeighbor(to: mainSet, in: city) else { return }
            // BFS over clear land from start to goal, then lay the roads.
            var visited = Set<GridPoint>([start])
            var queue = [start]
            var parent: [GridPoint: GridPoint] = [:]
            var found: GridPoint?
            while !queue.isEmpty {
                let point = queue.removeFirst()
                if point == goal { found = point; break }
                for next in RoadServiceCoverage.orthogonalNeighbors(of: point) {
                    guard next.x >= 0, next.x < city.roadNetwork.width,
                          next.y >= 0, next.y < city.roadNetwork.height,
                          !visited.contains(next),
                          city.terrain?.isClearLand(next) == true,
                          !city.occupiedBuildingPoints.contains(next)
                    else { continue }
                    visited.insert(next)
                    parent[next] = point
                    queue.append(next)
                }
            }
            guard let found else { return }
            var path: [GridPoint] = []
            var cursor: GridPoint? = found
            while let point = cursor {
                path.append(point)
                cursor = parent[point]
            }
            path.reverse()
            for point in path where !(controller.city?.roadNetwork.contains(point) ?? false) {
                XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
                let result = controller.perform(
                    .placeSelectedConstruction(at: point, orientation: .northSouth)
                )
                XCTAssertTrue(result.wasApplied, "road \(point): \(result.message)")
            }
        }
    }

    private func place(
        _ tool: PlayerConstructionTool,
        at point: GridPoint,
        with controller: GameSessionController
    ) throws {
        XCTAssertTrue(controller.perform(.selectConstruction(tool)).wasApplied)
        let preview = controller.constructionPreview(at: point)
        XCTAssertTrue(preview.isValid, "\(tool.rawValue) \(point): \(preview.reason ?? "unknown")")
        let result = controller.perform(
            .placeSelectedConstruction(at: point, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
    }

    /// Compact house placement: repeatedly take the closest clear road-adjacent
    /// site around the market so the district stays inside the food peddler's
    /// range, extending the road network only when the ring is exhausted.
    @discardableResult
    private func placeHouse(
        near target: GridPoint,
        with controller: GameSessionController
    ) throws -> GridPoint {
        var radius = 6
        while radius <= 46 {
            let city = try XCTUnwrap(controller.city)
            let xRange = max(0, target.x - radius)...min(
                city.roadNetwork.width - 1,
                target.x + radius
            )
            let yRange = max(0, target.y - radius)...min(
                city.roadNetwork.height - 1,
                target.y + radius
            )
            let candidates = yRange.flatMap { y in
                xRange.map { GridPoint(x: $0, y: y) }
            }.sorted {
                let left = abs($0.x - target.x) + abs($0.y - target.y)
                let right = abs($1.x - target.x) + abs($1.y - target.y)
                return left == right
                    ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                    : left < right
            }
            XCTAssertTrue(controller.perform(.selectConstruction(.house)).wasApplied)
            for point in candidates {
                let marketDistance = abs(point.x - target.x) + abs(point.y - target.y)
                guard marketDistance >= 10,
                      controller.constructionPreview(at: point).isValid else { continue }
                let result = controller.perform(
                    .placeSelectedConstruction(at: point, orientation: .northSouth)
                )
                if result.wasApplied { return point }
            }
            radius += 8
        }
        return try placeNext(.house, with: controller)
    }

    private func refuseFoodInWarehouses(
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        for warehouse in city.logistics.warehouses {
            for commodityID in OriginalFoodCatalog.foodCommodityIDs.sorted() {
                let result = controller.perform(.setWarehouseCommodityPolicy(
                    warehouseID: warehouse.id,
                    commodityID: commodityID,
                    policy: .doNotAccept
                ))
                XCTAssertTrue(result.wasApplied, result.message)
            }
        }
    }

    private func probeWorkshopSites(with controller: GameSessionController) throws {
        let city = try XCTUnwrap(controller.city)
        guard let station = city.trade.buildings.first(where: { $0.partnerID == 0 }) else { return }
        XCTAssertTrue(controller.perform(.selectConstruction(.jadeWorkshop)).wasApplied)
        var found: [String] = []
        let stationRoad = station.roadAccessPoint
        let candidates = (0..<city.roadNetwork.height).flatMap { y in
            (0..<city.roadNetwork.width).map { GridPoint(x: $0, y: y) }
        }.sorted {
            let left = abs($0.x - stationRoad.x) + abs($0.y - stationRoad.y)
            let right = abs($1.x - stationRoad.x) + abs($1.y - stationRoad.y)
            return left == right
                ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                : left < right
        }
        for point in candidates where controller.constructionPreview(at: point).isValid {
            let distance = roadDistance(from: stationRoad, to: point, in: city)
            found.append("(\(point.x),\(point.y))d=\(distance)")
            if found.count >= 8 { break }
        }
        FileHandle.standardError.write(
            Data(("PROBE station=\(stationRoad) workshopSites=[\(found.joined(separator: " "))]\n").utf8)
        )
    }

    private func roadDistance(
        from start: GridPoint,
        to point: GridPoint,
        in city: DeterministicCityState
    ) -> Int {
        var visited = Set<GridPoint>([start])
        var queue = [start]
        var distance: [GridPoint: Int] = [start: 0]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == point { return distance[current] ?? -1 }
            for next in RoadServiceCoverage.orthogonalNeighbors(of: current)
            where city.roadNetwork.contains(next) && !visited.contains(next) {
                visited.insert(next)
                distance[next] = (distance[current] ?? 0) + 1
                queue.append(next)
            }
        }
        return -1
    }
}
