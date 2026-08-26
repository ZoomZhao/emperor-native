import XCTest
import EmperorCore
@testable import EmperorGameplay

final class Xia1PlayerPlaythroughTests: XCTestCase {
    private let expectedReplayFingerprint: UInt64 = 0x8b48_db19_e013_9f4f

    func testPlayerCommandsCompleteOriginalXiaTutorialOne() throws {
        try requireAutomaticMigrationProducer()
        let controller = try startedController()
        XCTAssertEqual(controller.snapshot.replayFingerprint, expectedReplayFingerprint)
        try buildWinningCity(with: controller)
        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)

        for _ in 0..<(30 * 12 * 10) where controller.campaignRuntime?.outcome == .running {
            let result = controller.perform(.advanceOneTick)
            XCTAssertTrue(result.wasApplied, result.message)
        }

        guard case .victory? = controller.campaignRuntime?.outcome else {
            let city = try XCTUnwrap(controller.city)
            let population = city.houses.reduce(0) { $0 + $1.residents }
            let levels = Dictionary(grouping: city.houses, by: \ResidentialUnit.houseLevelID)
                .mapValues(\.count)
            var floodDiagnostics = "flood=n/a"
            if let terrain = city.terrain,
               let entry = terrain.authoredPoints?.landEntry {
                do {
                    let grids = try city.grandCanalWorkerRoutingGrids()
                    let flood = DeterministicMigration.landEntryFloodDepths(
                        width: grids.width,
                        height: grids.height,
                        primaryPassability: grids.primaryPassability,
                        seed: entry
                    )
                    let reached = flood.compactMap { $0 }.count
                    let roadsReached = city.roadNetwork.points.filter {
                        let index = $0.y * grids.width + $0.x
                        return flood.indices.contains(index) && flood[index] != nil
                    }.count
                    floodDiagnostics =
                        "floodReached=\(reached); roadsTotal=\(city.roadNetwork.points.count); "
                        + "roadsReached=\(roadsReached)"
                } catch {
                    floodDiagnostics = "gridError=\(error)"
                }
            }
            return XCTFail(
                "expected victory; blockers: \(controller.snapshot.lastBlockReason ?? "none"); "
                    + "houses=\(city.houses.count); population=\(population); levels=\(levels); "
                    + "placed=\(city.placedBuildings.count); "
                    + "\(floodDiagnostics); "
                    + "walkers=\(city.migration.immigrantWalkers.count); "
                    + "pop=\(city.migration.popularity); pres=\(city.migration.pressure); "
                    + "assigned=\(city.migration.assignedThisMonth); "
                    + "unfulfilled=\(city.migration.unfulfilledArrivalCarry); "
                    + "entry=\(String(describing: city.terrain?.authoredPoints?.landEntry)); "
                    + "evidence=\(controller.evidence)"
            )
        }
        let city = try XCTUnwrap(controller.city)
        XCTAssertGreaterThanOrEqual(
            city.houses.filter { $0.houseLevelID + 3 >= 5 }
                .reduce(0) { $0 + $1.residents },
            150
        )
        let evidence = controller.evidence
        if !evidence.sawStaffedProducer
            || !evidence.sawProducerStock
            || !evidence.sawDeliveryWalker
            || !evidence.sawMillStock
            || !evidence.sawBuyer
            || !evidence.sawPeddler
            || !evidence.sawHouseFood {
            let city = try XCTUnwrap(controller.city)
            let production = city.production.buildings.map {
                "\($0.buildingID):w\($0.assignedWorkers)o\($0.outputInventoryByCommodityID)"
            }.joined(separator: ";")
            let logistics = "delivery=\(city.logistics.deliveryWalkers.count) "
                + "mills=\(city.logistics.mills.map { $0.inventoryByCommodityID })"
            let markets = "buyers=\(city.markets.buyers.count) "
                + "peddlers=\(city.markets.peddlers.count) "
                + "shops=\(city.markets.markets.flatMap { $0.shopBuildingIDs }.count)"
            return XCTFail(
                "evidence incomplete: staffed=\(evidence.sawStaffedProducer); "
                    + "stock=\(evidence.sawProducerStock); delivery=\(evidence.sawDeliveryWalker); "
                    + "mill=\(evidence.sawMillStock); buyer=\(evidence.sawBuyer); "
                    + "peddler=\(evidence.sawPeddler); houseFood=\(evidence.sawHouseFood); "
                    + "production=[\(production)]; logistics=[\(logistics)]; markets=[\(markets)]"
            )
        }
        XCTAssertTrue(evidence.sawWaterService)
        XCTAssertTrue(evidence.sawAncestorService)
        // Inspector figure 39 uses its own unrecovered `0x4CD230` FSM. The
        // generic residential-roamer bridge must not manufacture inspection.
        XCTAssertFalse(evidence.sawInspectionService)
        XCTAssertEqual(evidence.outcomeChangeCount, 1)
        XCTAssertEqual(controller.speed, 0)
        XCTAssertFalse(controller.perform(.setSpeed(3)).wasApplied)
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        XCTAssertFalse(controller.perform(
            .placeSelectedConstruction(
                at: GridPoint(x: 24, y: 77),
                orientation: .northSouth
            )
        ).wasApplied)
    }

    func testBrokenRoadAndMissingMarketDoNotAccidentallyWin() throws {
        let controller = try startedController()
        try buildWinningCity(with: controller, includeMarket: false)
        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        for _ in 0..<(30 * 12 * 2) where controller.campaignRuntime?.outcome == .running {
            XCTAssertTrue(controller.perform(.advanceOneTick).wasApplied)
        }
        if controller.campaignRuntime?.outcome != .running {
            let city = try XCTUnwrap(controller.city)
            let levels = Dictionary(grouping: city.houses, by: \ResidentialUnit.houseLevelID)
                .mapValues { $0.reduce(0) { $0 + $1.residents } }
            let food = city.houses.map {
                "\($0.houseLevelID):q\($0.lastSuppliedFoodQuality.rawValue)/\($0.foodQualityRawValue)"
            }.joined(separator: ";")
            return XCTFail(
                "counterexample won: levels=\(levels); food=\(food); "
                    + "population=\(city.population)"
            )
        }
        XCTAssertFalse(controller.evidence.sawPeddler)

        let road = try XCTUnwrap(controller.city?.roadNetwork.points.sorted {
            $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
        }.first)
        XCTAssertTrue(controller.perform(.demolish(at: road)).wasApplied)
        for _ in 0..<(30 * 12 * 2) where controller.campaignRuntime?.outcome == .running {
            XCTAssertTrue(controller.perform(.advanceOneTick).wasApplied)
        }
        if case .victory? = controller.campaignRuntime?.outcome {
            XCTFail("missing market and broken road must not satisfy the tutorial goals")
        }
    }

    private func requireAutomaticMigrationProducer() throws {
        // The recovered popularity/factor producer is implemented and
        // integration-verified; this gate is now a no-op.
    }

    private func startedController() throws -> GameSessionController {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let controller = try GameSessionController()
        let campaignID = try XCTUnwrap(
            controller.campaignID(fileName: "1 Xia Dynasty - Tutorials.pak")
        )
        let result = controller.perform(
            .startCampaignMission(campaignID: campaignID, missionID: 0)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        let city = try XCTUnwrap(controller.city)
        XCTAssertEqual(city.calendar.year, -2038)
        XCTAssertEqual(city.calendar.month, 6)
        XCTAssertEqual(city.economy.treasury, 2_000)
        XCTAssertEqual(city.missionSettings?.allowedBuildingMenuIDs, [1, 12, 13, 20, 26, 29])
        return controller
    }

    private func buildWinningCity(
        with controller: GameSessionController,
        includeMarket: Bool = true
    ) throws {
        // Immigrants walk from the authored land entry along roads, so the
        // city must be reachable from the entry (recovered producer contract,
        // §5/§10.4). Lay a road from the entry along the land-entry flood to
        // the nearest existing road before the economy is built.
        try connectEntryToRoads(with: controller)
        try placeNext(.huntingCamp, with: controller)
        try placeNext(.mill, with: controller)
        if includeMarket {
            try placeNext(.market, with: controller)
            try placeNext(.foodShop, with: controller)
        }
        for _ in 0..<8 { try placeNext(.well, with: controller) }
        try placeNext(.inspectorTower, with: controller)
        for _ in 0..<6 { try placeNext(.ancestralShrine, with: controller) }
        for _ in 0..<26 { try placeNext(.house, with: controller) }
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

    private func placeNext(
        _ tool: PlayerConstructionTool,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let point: GridPoint?
        if tool == .house {
            point = city.nextHouseConstructionLocation()
        } else if let buildingID = tool.buildingID,
                  OriginalMarketCatalog.supports(shopBuildingID: buildingID) {
            point = city.placedBuildings.first(where: {
                $0.category == .market
                    && city.canConstructMarketShop(
                        shopBuildingID: buildingID,
                        at: $0.origin
                    )
            })?.origin
        } else if let buildingID = tool.buildingID {
            point = city.nextBuildingConstructionLocation(buildingID: buildingID)
        } else {
            point = nil
        }
        try place(tool, at: try XCTUnwrap(point, "no valid \(tool.rawValue) site"), with: controller)
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
}
