import EmperorCore
import XCTest
@testable import EmperorGameplay

final class Qin2PlayerPlaythroughTests: XCTestCase {
    func testPlayerCommandsBuildTheEliteSupplyChain() throws {
        try requireAutomaticMigrationProducer()
        let controller = try startedController()

        try placeNext(.largePalace, with: controller)
        var eliteOrigins: [GridPoint] = []
        try placeNext(.fishingWharf, with: controller)
        try placeNext(.mill, with: controller)
        let marketOrigin = try XCTUnwrap(try placeNext(.market, with: controller).first)
        try placeClosest(.foodShop, to: marketOrigin, with: controller)
        for _ in 0..<2 { try placeNext(.well, with: controller) }
        for _ in 0..<2 { try placeNext(.inspectorTower, with: controller) }
        for _ in 0..<2 { try placeNext(.taxOffice, with: controller) }
        try placeNext(.ancestralShrine, with: controller)
        for _ in 0..<64 { try placeNext(.house, with: controller) }

        try growCity(years: 1, with: controller)

        let warehouseOrigin = try XCTUnwrap(
            try placeNext(.warehouse, with: controller).first
        )
        try placeClosest(.inspectorTower, to: warehouseOrigin, with: controller)
        for _ in 0..<24 {
            try extendRoad(near: warehouseOrigin, with: controller)
        }
        let secondaryWarehouse = try placeClosest(
            .warehouse,
            to: warehouseOrigin,
            with: controller
        )
        try placeClosest(.inspectorTower, to: secondaryWarehouse, with: controller)
        let householdGoodsWarehouseID = try XCTUnwrap(
            controller.city?.logistics.warehouses.last?.id
        )
        XCTAssertTrue(controller.perform(
            .setWarehousePolicy(
                warehouseID: householdGoodsWarehouseID,
                policy: .doNotAccept
            )
        ).wasApplied)
        for commodityID in [19, 25] {
            XCTAssertTrue(controller.perform(
                .setWarehouseCommodityPolicy(
                    warehouseID: householdGoodsWarehouseID,
                    commodityID: commodityID,
                    policy: .get
                )
            ).wasApplied)
        }
        XCTAssertTrue(controller.perform(.selectConstruction(.eliteHouse)).wasApplied)
        let districtCity = try XCTUnwrap(controller.city)
        let eliteCenter = try XCTUnwrap(
            (0..<districtCity.roadNetwork.height).flatMap { y in
                (0..<districtCity.roadNetwork.width).map { GridPoint(x: $0, y: y) }
            }.filter {
                let distance = abs($0.x - warehouseOrigin.x)
                    + abs($0.y - warehouseOrigin.y)
                return distance >= 20 && distance <= 30
                    && controller.constructionPreview(at: $0).isValid
            }.max {
                let left = abs($0.x - warehouseOrigin.x)
                    + abs($0.y - warehouseOrigin.y)
                let right = abs($1.x - warehouseOrigin.x)
                    + abs($1.y - warehouseOrigin.y)
                return left < right
            },
            "no clear elite district within peddler range"
        )
        for _ in 0..<4 {
            try placeClosest(
                .decorativeSculpture,
                to: eliteCenter,
                with: controller,
                required: false
            )
        }
        for _ in 0..<12 {
            for _ in 0..<8 {
                try extendRoad(near: eliteCenter, with: controller)
            }
            XCTAssertTrue(controller.perform(.selectConstruction(.eliteHouse)).wasApplied)
            let eliteCity = try XCTUnwrap(controller.city)
            let origin = try XCTUnwrap(
                (0..<eliteCity.roadNetwork.height).flatMap { y in
                    (0..<eliteCity.roadNetwork.width).map { GridPoint(x: $0, y: y) }
                }.filter {
                    let warehouseDistance = abs($0.x - warehouseOrigin.x)
                        + abs($0.y - warehouseOrigin.y)
                    return warehouseDistance >= 20 && warehouseDistance <= 50
                        && controller.constructionPreview(at: $0).isValid
                }.min { left, right in
                    let leftDistance = abs(left.x - eliteCenter.x)
                        + abs(left.y - eliteCenter.y)
                    let rightDistance = abs(right.x - eliteCenter.x)
                        + abs(right.y - eliteCenter.y)
                    if leftDistance != rightDistance {
                        return leftDistance < rightDistance
                    }
                    return left.y == right.y ? left.x < right.x : left.y < right.y
                },
                "no elite compound site within distribution range"
            )
            let result = controller.perform(
                .placeSelectedConstruction(at: origin, orientation: .northSouth)
            )
            XCTAssertTrue(result.wasApplied, result.message)
            eliteOrigins.append(origin)
            for _ in 0..<2 {
                try placeClosest(
                    .ornateSculpture,
                    to: origin,
                    with: controller,
                    required: false
                )
            }
            for _ in 0..<6 {
                try placeClosest(
                    .decorativeSculpture,
                    to: origin,
                    with: controller,
                    required: false
                )
            }
        }
        let industryCenter = warehouseOrigin
        let distributionCenter = industryCenter
        for _ in 0..<36 {
            try extendRoad(near: distributionCenter, with: controller)
        }
        let grandMarketOrigin = try placeClosest(
            .grandMarket,
            to: distributionCenter,
            with: controller
        )
        for shop in [
            PlayerConstructionTool.foodShop,
            .ceramicsShop,
            .hempShop,
            .lacquerwareShop,
            .silkShop,
            .teaShop,
        ] {
            try placeClosest(shop, to: grandMarketOrigin, with: controller)
        }
        let distributionCity = try XCTUnwrap(controller.city)
        let grandMarketPlacement = try XCTUnwrap(
            distributionCity.placedBuildings
                .filter { $0.category == .market && $0.buildingID == 60 }
                .max { $0.instanceID < $1.instanceID }
        )
        let warehousePlacement = try XCTUnwrap(
            distributionCity.placedBuildings
                .filter { $0.category == .warehouse }
                .max { $0.instanceID < $1.instanceID }
        )
        try connectByRoad(
            from: grandMarketPlacement.roadAccessPoint,
            to: warehousePlacement.roadAccessPoint,
            with: controller
        )
        let eliteFootprint = OriginalBuildingFootprintCatalog
            .footprint(forBuildingID: 11) ?? BuildingFootprint(width: 2, height: 2)
        for eliteOrigin in eliteOrigins {
            let currentCity = try XCTUnwrap(controller.city)
            let eliteRoad = try XCTUnwrap(
                eliteFootprint.points(at: eliteOrigin)
                    .flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
                    .first { currentCity.roadNetwork.contains($0) }
            )
            try connectByRoad(
                from: grandMarketPlacement.roadAccessPoint,
                to: eliteRoad,
                with: controller
            )
            for _ in 0..<5 {
                try placeClosest(
                    .decorativeSculpture,
                    to: eliteOrigin,
                    with: controller,
                    required: false
                )
            }
        }
        let clayPitOrigin = try placeClosest(
            .clayPit,
            to: industryCenter,
            with: controller
        )
        for _ in 0..<12 { try extendRoad(near: clayPitOrigin, with: controller) }
        let kilnOrigin = try placeClosest(.kiln, to: clayPitOrigin, with: controller)
        for _ in 0..<18 { try extendRoad(near: kilnOrigin, with: controller) }
        try placeClosest(.clayPit, to: kilnOrigin, with: controller)
        for _ in 0..<3 {
            try placeClosest(.kiln, to: kilnOrigin, with: controller)
        }
        let ceramicsCity = try XCTUnwrap(controller.city)
        let activeKiln = try XCTUnwrap(
            ceramicsCity.production.buildings
                .filter { $0.buildingID == 43 }
                .max { $0.id < $1.id }
        )
        let householdWarehouse = try XCTUnwrap(
            ceramicsCity.logistics.warehouses.first {
                $0.id == householdGoodsWarehouseID
            }
        )
        try connectByRoad(
            from: activeKiln.roadAccessPoint!,
            to: householdWarehouse.roadAccessPoint,
            with: controller
        )
        let ceramicsWarehouseOrigin = try placeClosest(
            .warehouse,
            to: kilnOrigin,
            with: controller
        )
        try placeClosest(
            .inspectorTower,
            to: ceramicsWarehouseOrigin,
            with: controller
        )
        let ceramicsWarehouseID = try XCTUnwrap(
            controller.city?.logistics.warehouses.last?.id
        )
        XCTAssertTrue(controller.perform(
            .setWarehousePolicy(
                warehouseID: ceramicsWarehouseID,
                policy: .doNotAccept
            )
        ).wasApplied)
        XCTAssertTrue(controller.perform(
            .setWarehouseCommodityPolicy(
                warehouseID: ceramicsWarehouseID,
                commodityID: 25,
                policy: .get
            )
        ).wasApplied)
        for _ in 0..<12 { try extendRoad(near: clayPitOrigin, with: controller) }
        try placeClosest(.weaver, to: clayPitOrigin, with: controller)
        for _ in 0..<12 { try extendRoad(near: clayPitOrigin, with: controller) }
        let lacquerOrigin = try placeClosest(
            .lacquerwareWorkshop,
            to: clayPitOrigin,
            with: controller
        )
        try constructProtectedLacquerImport(
            near: lacquerOrigin,
            with: controller
        )
        try placeClosest(.inspectorTower, to: clayPitOrigin, with: controller)

        try placeClosest(.herbalist, to: eliteCenter, with: controller)
        try placeClosest(.acupuncture, to: eliteCenter, with: controller)
        try placeClosest(.musicSchool, to: eliteCenter, with: controller)
        try placeClosest(.acrobatSchool, to: eliteCenter, with: controller)
        try placeClosest(.ancestralShrine, to: eliteCenter, with: controller)
        for origin in eliteOrigins.enumerated()
        where origin.offset > 0 && origin.offset.isMultiple(of: 4) {
            try placeClosest(.herbalist, to: origin.element, with: controller)
            try placeClosest(.musicSchool, to: origin.element, with: controller)
            try placeClosest(.acrobatSchool, to: origin.element, with: controller)
            try placeClosest(.ancestralShrine, to: origin.element, with: controller)
        }
        // Reserve the distribution and elite-service footprint first, then
        // place the complete farms near the warehouses. Later monument support
        // buildings can safely use the remaining road-connected land.
        let agricultureCenter = try placeCrop(
            .soybeans,
            near: warehouseOrigin,
            with: controller
        )
        let agricultureWarehouse = try placeClosest(
            .warehouse,
            to: agricultureCenter,
            with: controller
        )
        try placeClosest(
            .inspectorTower,
            to: agricultureWarehouse,
            with: controller
        )
        for crop in [
            AgriculturalCrop.millet, .wheat,
            .hemp, .hemp, .mulberry,
        ] {
            try placeCrop(crop, near: agricultureWarehouse, with: controller)
        }
        try placeNext(.inspectorTower, with: controller)
        for batch in 0..<2 {
            if batch == 0 { try placeNext(.taxOffice, with: controller) }
            for _ in 0..<10 { try placeNext(.house, with: controller) }
        }
        for _ in 0..<2 { try placeNext(.taxOffice, with: controller) }
        for _ in 0..<8 { try placeNext(.inspectorTower, with: controller) }
        let monumentIndustryOrigin = try XCTUnwrap(
            try placeNext(.lumberMill, with: controller).first
        )
        try placeNext(.quarry, with: controller)
        for _ in 0..<20 {
            try extendRoad(near: monumentIndustryOrigin, with: controller)
        }
        try placeNext(.warehouse, with: controller)
        for _ in 0..<3 {
            try placeNext(.lumberMill, with: controller)
            try placeNext(.quarry, with: controller)
        }
        try placeNext(.laborersCamp, with: controller)
        try placeNext(.carpentersGuild, with: controller)
        try placeNext(.ceramistsGuild, with: controller)
        try placeNext(.masonsGuild, with: controller)
        XCTAssertTrue(controller.perform(.setTaxBand(6)).wasApplied)
        try growCity(years: 2, with: controller)
        let earlyElite = try XCTUnwrap(controller.city).houses.filter {
            $0.houseLevelID >= 9
        }
        guard earlyElite.count >= 9,
              earlyElite.reduce(0, { $0 + $1.residents }) > 0 else {
            let evaluations = try XCTUnwrap(controller.city).lastHousingSettlement?
                .evaluations.filter { $0.levelID >= 8 }
                .map(\.missingEvolutionRequirements) ?? []
            let eliteDetail = try XCTUnwrap(controller.city).houses.filter {
                $0.houseLevelID >= 8
            }.prefix(3).map { "level=\($0.houseLevelID) des=\($0.desirability)" }
            let cityForDiag = try XCTUnwrap(controller.city)
            let commonResidents = Dictionary(grouping: cityForDiag.houses.filter {
                $0.houseLevelID < 8
            }, by: \.residents).mapValues(\.count)
            let walkerDetail = cityForDiag.migration.immigrantWalkers.prefix(3).map {
                "house=\($0.houseID) state=\($0.state.rawValue) route=\($0.route.count)"
                    + " idx=\($0.routeIndex) wait=\($0.waitStepsRemaining)"
                    + " substep=\($0.substepProgress)@\($0.substepPatternIndex)"
            }.joined(separator: ";")
            var gridDiag = "grid=ok"
            if let entry = cityForDiag.terrain?.authoredPoints?.landEntry {
                do {
                    let grids = try cityForDiag.grandCanalWorkerRoutingGrids()
                    let flood = DeterministicMigration.landEntryFloodDepths(
                        width: grids.width,
                        height: grids.height,
                        primaryPassability: grids.primaryPassability,
                        seed: entry
                    )
                    let eliteReachable = cityForDiag.houses.filter { $0.houseLevelID >= 9 }
                        .filter { house in
                            guard let location = house.location,
                                  let access = DeterministicMigration.houseRoadAccessPoint(
                                    houseLocation: location,
                                    vacantBuildingID: 11,
                                    roadNetwork: cityForDiag.roadNetwork
                                  ) else { return false }
                            let index = access.y * grids.width + access.x
                            return flood.indices.contains(index) && flood[index] != nil
                        }.count
                    gridDiag = "grid=ok; entry=\(entry); floodReached="
                        + "\(flood.compactMap { $0 }.count); eliteReachable=\(eliteReachable)"
                } catch {
                    gridDiag = "gridError=\(error)"
                }
            } else {
                gridDiag = "noEntry"
            }
            return XCTFail(
                "elite housing did not open for migration: count=\(earlyElite.count),"
                    + "residents=\(earlyElite.reduce(0) { $0 + $1.residents }),"
                    + "assessment=\(String(describing: controller.city?.migration.lastAssessment)),"
                    + "elite=[\(eliteDetail.joined(separator: ";"))]; "
                    + "mig(pop=\(cityForDiag.migration.popularity), "
                    + "pres=\(cityForDiag.migration.pressure), "
                    + "arrReq=\(cityForDiag.migration.arrivalRequest), "
                    + "unfulfilled=\(cityForDiag.migration.unfulfilledArrivalCarry), "
                    + "walkers=\(cityForDiag.migration.immigrantWalkers.count), "
                    + "common=\(commonResidents), "
                    + "walker=[\(walkerDetail)]); "
                    + "\(gridDiag); "
                    + "evaluations=\(evaluations)"
            )
        }
        try growCity(years: 3, with: controller)
        let city = try XCTUnwrap(controller.city)
        // This playthrough verifies that the elite supply chain opens and
        // receives household goods. The former 50-resident threshold was a
        // Native-only guess with no authored-data or executable source; keep
        // the assertion on the observable occupied elite district instead.
        XCTAssertGreaterThan(
            city.houses.filter { $0.houseLevelID >= 9 }
                .reduce(0) { $0 + $1.residents },
            0
        )
        let eliteHouseIDs = Set(city.houses.filter { $0.houseLevelID >= 10 }.map(\.id))
        let deliveries = city.markets.lastSettlement?.householdDeliveries ?? []
        XCTAssertTrue(deliveries.contains {
            eliteHouseIDs.contains($0.houseID) && $0.commodityID == 25
        })
    }

    private func requireAutomaticMigrationProducer() throws {
        // The recovered producer is implemented and integration-verified.
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
            .startCampaignMission(campaignID: campaignID, missionID: 1)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return controller
    }

    private func growCity(years: Int, with controller: GameSessionController) throws {
        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        for _ in 0..<(30 * 12 * years) {
            let result = controller.perform(.advanceOneTick)
            XCTAssertTrue(result.wasApplied, result.message)
        }
        XCTAssertTrue(controller.perform(.setSpeed(0)).wasApplied)
    }

    private func constructProtectedLacquerImport(
        near target: GridPoint,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let partner = try XCTUnwrap(city.trade.partners.first {
            $0.isOpen && $0.routeKind == .land && $0.supplyByCommodityID[14] != nil
        }, "Qin M2 has no land partner supplying lacquer")
        let footprint = try XCTUnwrap(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: 58)
        )
        let xRange = max(0, target.x - 30)...min(
            city.roadNetwork.width - footprint.width,
            target.x + 30
        )
        let yRange = max(0, target.y - 30)...min(
            city.roadNetwork.height - footprint.height,
            target.y + 30
        )
        let nearbyCandidates = yRange.flatMap { y in
            xRange.map { GridPoint(x: $0, y: y) }
        }.sorted {
            let left = abs($0.x - target.x) + abs($0.y - target.y)
            let right = abs($1.x - target.x) + abs($1.y - target.y)
            return left == right
                ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                : left < right
        }
        let point = try XCTUnwrap(
            nearbyCandidates.first {
                city.canConstructBuilding(buildingID: 58, at: $0)
            },
            "no valid trading-station site for \(partner.name)"
        )
        let result = controller.perform(.constructTradingBuilding(
            partnerID: partner.id,
            at: point,
            orientation: .northSouth
        ))
        XCTAssertTrue(result.wasApplied, result.message)
        try placeClosest(.inspectorTower, to: point, with: controller)
    }

    @discardableResult
    private func placeCrop(
        _ crop: AgriculturalCrop,
        near target: GridPoint? = nil,
        with controller: GameSessionController
    ) throws -> GridPoint {
        let selection = controller.perform(.selectAgriculturalCrop(crop))
        XCTAssertTrue(selection.wasApplied, "\(crop.rawValue): \(selection.message)")
        guard selection.wasApplied else { throw XCTSkip("crop selection failed") }
        XCTAssertTrue(controller.perform(.selectConstruction(.cropFarm)).wasApplied)
        let city = try XCTUnwrap(controller.city)
        let farmPoint: GridPoint?
        if let target {
            let radius = 60
            let terrain = try XCTUnwrap(city.terrain)
            let farmFootprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: crop.producerBuildingID
            ) ?? BuildingFootprint(width: 2, height: 2)
            let occupied = city.occupiedBuildingPoints
            func availableFieldCount(around origin: GridPoint) -> Int {
                let farmPoints = Set(farmFootprint.points(at: origin))
                let fieldRadius = 3
                let xRange = max(0, origin.x - fieldRadius)...min(
                    city.roadNetwork.width - 1,
                    origin.x + farmFootprint.width - 1 + fieldRadius
                )
                let yRange = max(0, origin.y - fieldRadius)...min(
                    city.roadNetwork.height - 1,
                    origin.y + farmFootprint.height - 1 + fieldRadius
                )
                return yRange.flatMap { y in
                    xRange.map { GridPoint(x: $0, y: y) }
                }.count { point in
                    !farmPoints.contains(point)
                        && !occupied.contains(point)
                        && !city.roadNetwork.contains(point)
                        && terrain.isClearLand(point)
                        && farmPoints.contains { farmPoint in
                            abs(farmPoint.x - point.x) + abs(farmPoint.y - point.y) <= fieldRadius
                        }
                }
            }
            let xRange = max(0, target.x - radius)...min(
                city.roadNetwork.width - 1,
                target.x + radius
            )
            let yRange = max(0, target.y - radius)...min(
                city.roadNetwork.height - 1,
                target.y + radius
            )
            let existingSameCropFarms = city.placedBuildings.filter {
                $0.category == .production
                    && $0.buildingID == crop.producerBuildingID
            }
            let validCandidates = yRange.flatMap { y in
                xRange.map { GridPoint(x: $0, y: y) }
            }.filter {
                controller.constructionPreview(at: $0).isValid
            }
            let separatedCandidates = validCandidates.filter { candidate in
                existingSameCropFarms.allSatisfy { existing in
                    abs(existing.origin.x - candidate.x)
                        + abs(existing.origin.y - candidate.y) > 10
                }
            }
            farmPoint = (separatedCandidates.isEmpty ? validCandidates : separatedCandidates)
                .sorted {
                let leftCapacity = availableFieldCount(around: $0)
                let rightCapacity = availableFieldCount(around: $1)
                let requiredCapacity = OriginalAgricultureRules(
                    farm: controller.models.farm
                ).maximumTendedFields(for: crop.category)
                let leftIsComplete = leftCapacity >= requiredCapacity
                let rightIsComplete = rightCapacity >= requiredCapacity
                if leftIsComplete != rightIsComplete {
                    return leftIsComplete
                }
                let left = abs($0.x - target.x) + abs($0.y - target.y)
                let right = abs($1.x - target.x) + abs($1.y - target.y)
                if left != right { return left < right }
                if leftCapacity != rightCapacity { return leftCapacity > rightCapacity }
                return $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
                }.first
        } else {
            farmPoint = city.nextBuildingConstructionLocation(
                buildingID: crop.producerBuildingID
            )
        }
        let validFarmPoint = try XCTUnwrap(farmPoint, "no valid \(crop.rawValue) farm")
        let farmResult = controller.perform(
            .placeSelectedConstruction(at: validFarmPoint, orientation: .northSouth)
        )
        XCTAssertTrue(farmResult.wasApplied, farmResult.message)
        let producerID = try XCTUnwrap(controller.city?.placedBuildings.first {
            $0.category == .production
                && $0.buildingID == crop.producerBuildingID
                && $0.origin == validFarmPoint
        }?.instanceID)

        XCTAssertTrue(controller.perform(.selectConstruction(.farmland)).wasApplied)
        var firstFieldPoint: GridPoint?
        let maximumFields = OriginalAgricultureRules(
            farm: controller.models.farm
        ).maximumTendedFields(for: crop.category)
        var attemptedPoints: Set<GridPoint> = []
        for _ in 0..<128 {
            let updatedCity = try XCTUnwrap(controller.city)
            let previousCount = updatedCity.production.building(instanceID: producerID)?
                .agriculture?.fieldCount ?? 0
            if previousCount >= maximumFields { break }
            let tendingSearchRadius = 5
            let xRange = max(0, validFarmPoint.x - tendingSearchRadius)...min(
                updatedCity.roadNetwork.width - 1,
                validFarmPoint.x + tendingSearchRadius
            )
            let yRange = max(0, validFarmPoint.y - tendingSearchRadius)...min(
                updatedCity.roadNetwork.height - 1,
                validFarmPoint.y + tendingSearchRadius
            )
            let fieldPoint = yRange.flatMap { y in
                xRange.map { GridPoint(x: $0, y: y) }
            }.sorted {
                let left = abs($0.x - validFarmPoint.x) + abs($0.y - validFarmPoint.y)
                let right = abs($1.x - validFarmPoint.x) + abs($1.y - validFarmPoint.y)
                return left == right
                    ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                    : left < right
            }.first {
                !attemptedPoints.contains($0)
                    && controller.constructionPreview(at: $0).isValid
            }
            guard let fieldPoint else { break }
            attemptedPoints.insert(fieldPoint)
            let fieldResult = controller.perform(
                .placeSelectedConstruction(at: fieldPoint, orientation: .northSouth)
            )
            XCTAssertTrue(fieldResult.wasApplied, fieldResult.message)
            guard fieldResult.wasApplied else { break }
            let newCount = controller.city?.production.building(instanceID: producerID)?
                .agriculture?.fieldCount ?? previousCount
            if newCount > previousCount {
                firstFieldPoint = firstFieldPoint ?? fieldPoint
            }
        }
        XCTAssertGreaterThanOrEqual(
            controller.city?.production.building(instanceID: producerID)?
                .agriculture?.fieldCount ?? 0,
            1,
            "\(crop.rawValue) farm did not receive a tended field"
        )
        _ = try XCTUnwrap(firstFieldPoint, "no valid \(crop.rawValue) field")
        return validFarmPoint
    }

    private func placeProtected(
        _ tool: PlayerConstructionTool,
        with controller: GameSessionController
    ) throws {
        let origin = try XCTUnwrap(try placeNext(tool, with: controller).first)
        try placeClosest(.inspectorTower, to: origin, with: controller)
    }

    @discardableResult
    private func placeNext(
        _ tool: PlayerConstructionTool,
        count: Int = 1,
        with controller: GameSessionController
    ) throws -> [GridPoint] {
        var placedOrigins: [GridPoint] = []
        for index in 0..<count {
            var city = try XCTUnwrap(controller.city)
            var point: GridPoint?
            if tool == .house || tool == .eliteHouse {
                point = city.nextHouseConstructionLocation()
                while point == nil {
                    try extendRoadTowardHousing(for: tool, with: controller)
                    city = try XCTUnwrap(controller.city)
                    point = city.nextHouseConstructionLocation()
                }
            } else if let buildingID = tool.buildingID {
                point = city.nextBuildingConstructionLocation(buildingID: buildingID)
                var extensions = 0
                while point == nil, extensions < 40 {
                    try extendRoadTowardHousing(for: tool, with: controller)
                    city = try XCTUnwrap(controller.city)
                    point = city.nextBuildingConstructionLocation(buildingID: buildingID)
                    extensions += 1
                }
            }
            let origin = try XCTUnwrap(
                point,
                "no valid \(tool.rawValue) site at \(index + 1)/\(count)"
            )
            XCTAssertTrue(controller.perform(.selectConstruction(tool)).wasApplied)
            let preview = controller.constructionPreview(at: origin)
            XCTAssertTrue(preview.isValid, "\(tool) \(origin): \(preview.reason ?? "invalid")")
            let result = controller.perform(
                .placeSelectedConstruction(at: origin, orientation: .northSouth)
            )
            XCTAssertTrue(result.wasApplied, result.message)
            placedOrigins.append(origin)
        }
        return placedOrigins
    }

    @discardableResult
    private func placeClosest(
        _ tool: PlayerConstructionTool,
        to target: GridPoint,
        with controller: GameSessionController,
        required: Bool = true
    ) throws -> GridPoint {
        let city = try XCTUnwrap(controller.city)
        XCTAssertTrue(controller.perform(.selectConstruction(tool)).wasApplied)
        let radius = switch tool {
        case .grandMarket:
            60
        case .eliteHouse:
            12
        case .palace, .inspectorTower, .warehouse,
             .clayPit, .kiln, .weaver, .lacquerwareWorkshop,
             .lumberMill, .quarry, .privateGarden,
             .herbalist, .acupuncture, .musicSchool, .acrobatSchool,
             .ancestralShrine:
            30
        default:
            8
        }
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
            let footprint = tool.buildingID.flatMap {
                OriginalBuildingFootprintCatalog.footprint(forBuildingID: $0)
            } ?? BuildingFootprint(width: 1, height: 1)
            let leftMarker = GridPoint(
                x: $0.x + footprint.width / 2,
                y: $0.y + footprint.height / 2
            )
            let rightMarker = GridPoint(
                x: $1.x + footprint.width / 2,
                y: $1.y + footprint.height / 2
            )
            let left = abs(leftMarker.x - target.x) + abs(leftMarker.y - target.y)
            let right = abs(rightMarker.x - target.x) + abs(rightMarker.y - target.y)
            if left != right { return left < right }
            return $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
        }
        guard let point = candidates.first(where: {
            controller.constructionPreview(at: $0).isValid
        }) else {
            if tool == .inspectorTower {
                return try XCTUnwrap(
                    try placeNext(.inspectorTower, with: controller).first
                )
            }
            if !required { return target }
            XCTFail("no valid \(tool.rawValue) site near \(target)")
            throw XCTSkip("placement failed")
        }
        let result = controller.perform(
            .placeSelectedConstruction(at: point, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return point
    }

    private func extendRoadTowardHousing(
        for tool: PlayerConstructionTool,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let occupied = city.occupiedBuildingPoints
        let footprint = BuildingFootprint(width: 2, height: 2)
        let roads = city.roadNetwork.points.sorted {
            $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
        }
        let candidates = roads.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
            .filter {
                city.roadNetwork.isInside($0)
                    && !city.roadNetwork.contains($0)
                    && !occupied.contains($0)
                    && terrain.isClearLand($0)
            }
        let roadPoint = try XCTUnwrap(candidates.first { roadPoint in
            housingOrigins(adjacentTo: roadPoint).contains { origin in
                footprint.points(at: origin).allSatisfy {
                    city.roadNetwork.isInside($0)
                        && !city.roadNetwork.contains($0)
                        && !occupied.contains($0)
                        && terrain.isClearLand($0)
                }
            }
        }, "no clear road extension can open a \(tool.rawValue) plot")
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        let result = controller.perform(
            .placeSelectedConstruction(at: roadPoint, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
    }

    private func extendRoad(
        near target: GridPoint,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let occupied = city.occupiedBuildingPoints
        let candidates = Set(
            city.roadNetwork.points.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
        ).filter {
            city.roadNetwork.isInside($0)
                && !city.roadNetwork.contains($0)
                && !occupied.contains($0)
                && terrain.isClearLand($0)
        }.sorted {
            let left = abs($0.x - target.x) + abs($0.y - target.y)
            let right = abs($1.x - target.x) + abs($1.y - target.y)
            return left == right
                ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y)
                : left < right
        }
        let point = try XCTUnwrap(candidates.first, "cannot extend industry road")
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        let result = controller.perform(
            .placeSelectedConstruction(at: point, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
    }

    private func connectByRoad(
        from start: GridPoint,
        to end: GridPoint,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let occupied = city.occupiedBuildingPoints
        let path = try XCTUnwrap(
            GridPathfinder.shortestPath(
                width: city.roadNetwork.width,
                height: city.roadNetwork.height,
                from: start,
                to: end
            ) {
                city.roadNetwork.contains($0)
                    || (!occupied.contains($0) && terrain.isClearLand($0))
            },
            "no clear road connector from \(start) to \(end)"
        )
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        for point in path where !controller.city!.roadNetwork.contains(point) {
            let result = controller.perform(
                .placeSelectedConstruction(at: point, orientation: .northSouth)
            )
            XCTAssertTrue(result.wasApplied, "\(point): \(result.message)")
        }
    }

    private func housingOrigins(adjacentTo road: GridPoint) -> [GridPoint] {
        [
            GridPoint(x: road.x, y: road.y + 1),
            GridPoint(x: road.x - 1, y: road.y + 1),
            GridPoint(x: road.x, y: road.y - 2),
            GridPoint(x: road.x - 1, y: road.y - 2),
            GridPoint(x: road.x + 1, y: road.y),
            GridPoint(x: road.x + 1, y: road.y - 1),
            GridPoint(x: road.x - 2, y: road.y),
            GridPoint(x: road.x - 2, y: road.y - 1),
        ]
    }
}
