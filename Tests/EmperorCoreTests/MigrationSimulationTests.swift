import EmperorCore
import XCTest

final class MigrationSimulationTests: XCTestCase {
    func testTickObservesRoadAdjacentHousingWithoutMovingResidents() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 12,
            mapHeight: 5
        )
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 2) }, rules: rules)
        let firstID = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 2, y: 1),
            models: original.buildings
        )
        let secondID = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 5, y: 1),
            models: original.buildings
        )

        let tick = city.advanceTick(rules: rules)

        XCTAssertEqual(tick.migratedResidents, 0)
        XCTAssertEqual(tick.migrationAssessment.eligibleHouseIDs, [firstID, secondID])
        XCTAssertEqual(tick.migrationAssessment.availableCapacity, 14)
        XCTAssertEqual(tick.migrationAssessment.plannedImmigrants, 0)
        XCTAssertNil(tick.migrationAssessment.blockReason)
        XCTAssertEqual(city.population, 0)
        XCTAssertEqual(
            city.migration.automaticMigrationAvailability,
            .unsupportedOriginalProducer
        )
        XCTAssertEqual(city.migration.lastDailyImmigrants, 0)
        XCTAssertEqual(city.migration.currentMonthImmigrants, 0)
        XCTAssertEqual(city.migration.lastMonthImmigrants, 0)
    }

    func testHousingObservationExcludesVacanciesWithoutRoadAccess() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = city.buildRoad([GridPoint(x: 0, y: 1)], rules: rules)
        let accessibleID = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 1, y: 1),
            models: original.buildings
        )
        _ = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 6, y: 4),
            models: original.buildings
        )

        let tick = city.advanceTick(rules: rules)

        XCTAssertEqual(tick.migrationAssessment.eligibleHouseIDs, [accessibleID])
        XCTAssertEqual(tick.migrationAssessment.availableCapacity, 7)
        XCTAssertEqual(tick.migratedResidents, 0)
        XCTAssertEqual(city.population, 0)
    }

    func testLegacyMigrationStateDecodesThenProductionTickClearsApproximation() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var source = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = source.buildRoad([GridPoint(x: 0, y: 1)], rules: rules)
        _ = source.addHouse(
            levelID: 0,
            location: GridPoint(x: 1, y: 1),
            models: original.buildings
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(source))
                as? [String: Any]
        )
        object["migrationState"] = [
            "lastDailyImmigrants": 5,
            "currentMonthImmigrants": 21,
            "lastMonthImmigrants": 17,
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        var restored = try JSONDecoder().decode(DeterministicCityState.self, from: legacyData)

        XCTAssertEqual(
            restored.migration.automaticMigrationAvailability,
            .unsupportedOriginalProducer
        )
        XCTAssertEqual(restored.migration.lastDailyImmigrants, 5)
        XCTAssertEqual(restored.migration.currentMonthImmigrants, 21)
        XCTAssertEqual(restored.migration.lastMonthImmigrants, 17)

        let tick = restored.advanceTick(rules: rules)

        XCTAssertEqual(tick.migratedResidents, 0)
        XCTAssertEqual(restored.population, 0)
        XCTAssertEqual(restored.migration.lastDailyImmigrants, 0)
        XCTAssertEqual(restored.migration.currentMonthImmigrants, 0)
        XCTAssertEqual(restored.migration.lastMonthImmigrants, 0)
        XCTAssertEqual(restored.migration.lastAssessment?.availableCapacity, 7)
    }

    func testUnsupportedMigrationSaveReplayIsIdenticalAndPopulationStaysFixed() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var uninterrupted = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 12,
            mapHeight: 5
        )
        _ = uninterrupted.buildRoad(
            (0..<12).map { GridPoint(x: $0, y: 2) },
            rules: rules
        )
        for x in [2, 5, 8] {
            _ = uninterrupted.addHouse(
                levelID: 0,
                location: GridPoint(x: x, y: 1),
                models: original.buildings
            )
        }
        for _ in 0..<3 { _ = uninterrupted.advanceTick(rules: rules) }

        let data = try JSONEncoder().encode(uninterrupted)
        var restored = try JSONDecoder().decode(DeterministicCityState.self, from: data)
        for _ in 0..<20 {
            _ = uninterrupted.advanceTick(rules: rules)
            _ = restored.advanceTick(rules: rules)
        }

        XCTAssertEqual(restored, uninterrupted)
        XCTAssertEqual(restored.population, 0)
        XCTAssertEqual(restored.migration.currentMonthImmigrants, 0)
    }

    private func installedModels() throws -> OriginalEconomyModels {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        return try OriginalEconomyModels(source: .openDefault())
    }

    func testLandEntryFloodFollowsRoadAndStopsAtWater() {
        let width = 7
        let height = 3
        var primary = [UInt16](repeating: 0x2, count: width * height)
        for x in 0..<width {
            primary[1 * width + x] = 0x4  // road row
        }

        let depths = DeterministicMigration.landEntryFloodDepths(
            width: width,
            height: height,
            primaryPassability: primary,
            seed: GridPoint(x: 0, y: 1)
        )

        XCTAssertEqual(depths.count, width * height)
        for x in 0..<width {
            XCTAssertEqual(depths[1 * width + x], x + 1, "road cell x=\(x)")
        }
        for y in [0, 2] {
            for x in 0..<width {
                XCTAssertNil(depths[y * width + x], "water cell (x=\(x), y=\(y)) must be unreached")
            }
        }
    }

    func testLandEntryFloodStopsAtBlockedGapAndPassesBareLand() {
        let width = 6
        let height = 1
        var primary = [UInt16](repeating: 0x10, count: width)  // bare land passes
        primary[3] = 0x2  // blocked gap

        let depths = DeterministicMigration.landEntryFloodDepths(
            width: width,
            height: height,
            primaryPassability: primary,
            seed: GridPoint(x: 0, y: 0)
        )

        XCTAssertEqual(depths[0], 1)
        XCTAssertEqual(depths[1], 2)
        XCTAssertEqual(depths[2], 3)
        XCTAssertNil(depths[3], "blocked gap must not flood")
        XCTAssertNil(depths[4], "cells beyond the gap must be unreached")
        XCTAssertNil(depths[5], "cells beyond the gap must be unreached")
    }

    func testLandEntryFloodMatchesRecoveredMaskOnHaunxianMap() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        guard let seed = map.authoredPoints.landEntry else {
            throw XCTSkip("Haunxian map has no authored land entry")
        }
        let city = DeterministicCityState(
            year: -246,
            treasury: 15_000,
            map: map
        )
        let grids = try city.grandCanalWorkerRoutingGrids()
        let flood = DeterministicMigration.landEntryFloodDepths(
            width: grids.width,
            height: grids.height,
            primaryPassability: grids.primaryPassability,
            seed: seed
        )

        XCTAssertEqual(flood.count, grids.primaryPassability.count)
        XCTAssertEqual(flood[seed.y * grids.width + seed.x], 1)

        var reached = 0
        var unreached = 0
        for (index, depth) in flood.enumerated() {
            if let depth {
                reached += 1
                XCTAssertGreaterThan(depth, 0)
                XCTAssertNotEqual(
                    grids.primaryPassability[index] & DeterministicMigration
                        .landEntryFloodPassMask,
                    0,
                    "reached cell \(index) must pass the 0xB7C mask"
                )
            } else {
                unreached += 1
            }
        }
        XCTAssertGreaterThan(reached, 0)
        XCTAssertGreaterThan(unreached, 0)

        // Determinism: same inputs, same depths.
        let again = DeterministicMigration.landEntryFloodDepths(
            width: grids.width,
            height: grids.height,
            primaryPassability: grids.primaryPassability,
            seed: seed
        )
        XCTAssertEqual(again, flood)
    }

    func testSettlingLockSetOnDevolutionDisplacement() throws {
        let models = try installedModels().buildings
        var house = ResidentialUnit(
            id: 1,
            houseLevelID: 1,
            residents: 40,
            location: GridPoint(x: 2, y: 2),
            desirability: -100
        )
        var houses = [house]

        let settlement = DeterministicHousingEvolution.settle(
            houses: &houses,
            models: models,
            difficulty: .normal
        )

        let devolve = settlement.changes.first {
            $0.direction == .devolved && $0.displacedResidents > 0
        }
        XCTAssertNotNil(devolve, "expected a devolution that displaces residents")
        XCTAssertEqual(houses[0].settlingLock, 2)
        XCTAssertEqual(houses[0].settlingLockRemainingSteps, 32)
        XCTAssertEqual(houses[0].residents, houses[0].capacity(using: models))
    }

    func testSettlingLockClearsAfterCountdownAndWhenEmpty() {
        var house = ResidentialUnit(id: 1, houseLevelID: 1, residents: 4)
        house.startSettlingLock()
        XCTAssertEqual(house.settlingLock, 2)
        XCTAssertEqual(house.settlingLockRemainingSteps, 32)

        for _ in 0..<31 {
            house.advanceSettlingLock()
        }
        XCTAssertEqual(house.settlingLock, 2, "lock must survive 31 daily advances")
        XCTAssertEqual(house.settlingLockRemainingSteps, 1)
        house.advanceSettlingLock()
        XCTAssertEqual(house.settlingLock, 0, "lock must clear on the 32nd advance")
        XCTAssertEqual(house.settlingLockRemainingSteps, 0)

        var emptied = ResidentialUnit(id: 2, houseLevelID: 1, residents: 0)
        emptied.startSettlingLock()
        emptied.advanceSettlingLock()
        XCTAssertEqual(emptied.settlingLock, 0, "empty house clears immediately")
        XCTAssertEqual(emptied.settlingLockRemainingSteps, 0)
    }

    func testSettlingLockPreservedBySaveRoundTrip() throws {
        var house = ResidentialUnit(id: 7, houseLevelID: 1, residents: 3)
        house.startSettlingLock()
        house.advanceSettlingLock()

        let data = try JSONEncoder().encode(house)
        let restored = try JSONDecoder().decode(ResidentialUnit.self, from: data)

        XCTAssertEqual(restored.settlingLock, house.settlingLock)
        XCTAssertEqual(restored.settlingLockRemainingSteps, house.settlingLockRemainingSteps)

        // Old saves without the fields decode as unlocked.
        let legacy = """
        {"id":1,"houseLevelID":0,"residents":2,"hasTaxCoverage":false,
         "footprintMultiplier":1,"location":{"x":1,"y":1},
         "orientation":0,"suppliesByCommodityID":{},
         "commodityShortageMonths":0,"foodSupplyAmount":0,
         "foodQualityRawValue":0,"serviceCoverage":[],
         "desirability":0,"lastSuppliedFoodQualityRawValue":0,
         "lastSuppliedCommodityIDs":[]}
        """
        let decoded = try JSONDecoder().decode(ResidentialUnit.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.settlingLock, 0)
        XCTAssertEqual(decoded.settlingLockRemainingSteps, 0)
    }

    func testImmigrantWalkerWaitsThenWalksThenArrives() {
        let route = [
            GridPoint(x: 0, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
        ]
        var walker = ImmigrantWalker(
            id: 1,
            houseID: 7,
            peopleCount: 3,
            entryPoint: route[0],
            route: route,
            waitSteps: 5
        )
        XCTAssertEqual(walker.state, .waiting)

        for _ in 0..<5 {
            XCTAssertFalse(walker.advanceOneUpdate())
        }
        XCTAssertEqual(walker.state, .walking)
        XCTAssertEqual(walker.waitStepsRemaining, 0)

        var arrived = false
        var updates = 0
        while updates < 500, !arrived {
            arrived = walker.advanceOneUpdate()
            updates += 1
        }
        XCTAssertTrue(arrived, "walker must arrive within 500 updates")
        XCTAssertEqual(walker.state, .arriving)
        XCTAssertEqual(walker.currentPoint, route[3])
    }

    func testImmigrantWalkerMovementCadenceMatchesRecoveredTiming() {
        // 6 route points = 5 crossings. Initial progress 20 makes the first
        // crossing immediate; then each crossing needs 20 substeps, which the
        // 1/1/2 pattern delivers in 15 updates.
        let route = (0..<6).map { GridPoint(x: $0, y: 0) }
        var walker = ImmigrantWalker(
            id: 2,
            houseID: 9,
            peopleCount: 1,
            entryPoint: route[0],
            route: route,
            waitSteps: 0
        )
        XCTAssertEqual(walker.state, .walking)
        XCTAssertEqual(walker.substepProgress, 20)

        var updates = 0
        var arrived = false
        while updates < 200, !arrived {
            arrived = walker.advanceOneUpdate()
            updates += 1
        }
        // Crossings at updates 1, 15, 30, 45, 60 (initial progress 20 makes
        // the first crossing immediate; each further crossing needs 20
        // substeps, delivered by the 1/1/2 pattern in 15 updates). The walker
        // reaches the last point on update 60 and the arrival fires on 61.
        XCTAssertEqual(updates, 61, "arrival must follow the recovered 1/1/2 cadence")
    }

    func testCitySpawnedImmigrantArrivesAndActivatesVacantHouse() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        guard let entry = map.authoredPoints.landEntry else {
            throw XCTSkip("Haunxian map has no authored land entry")
        }
        let original = try installedModels()
        let models = original.buildings
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: -246, treasury: 15_000, map: map)

        // Build a short road from the entry and put a common vacant house and
        // an elite vacant house beside it.
        var road = [entry]
        var cursor = entry
        var guardSteps = 0
        while road.count < 5, guardSteps < 80 {
            guardSteps += 1
            let next = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
                .first { point in
                    city.terrain?.isClearLand(point) == true
                        && !city.roadNetwork.contains(point)
                        && !city.occupiedBuildingPoints.contains(point)
                }
            guard let next else { break }
            _ = city.buildRoad([next], rules: rules)
            road.append(next)
            cursor = next
        }
        XCTAssertGreaterThanOrEqual(road.count, 3, "could not lay a road from the entry")

        let candidateHousePoint = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
            .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            .first { city.terrain?.isClearLand($0) == true }
        let housePoint = try XCTUnwrap(candidateHousePoint)
        let commonID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            location: housePoint,
            vacantTypeID: 2,
            models: models
        ))

        let grids = try city.grandCanalWorkerRoutingGrids()
        let walkerID = try XCTUnwrap(city.spawnImmigrant(
            houseID: commonID,
            peopleCount: 4,
            grids: grids
        ))
        XCTAssertEqual(walkerID, 1)
        XCTAssertEqual(city.migration.immigrantWalkers.count, 1)

        var ticks = 0
        while city.migration.immigrantWalkers.contains(where: { $0.id == walkerID }),
              ticks < 30 * 12 {
            _ = city.advanceTick(rules: rules)
            ticks += 1
        }

        XCTAssertFalse(
            city.migration.immigrantWalkers.contains(where: { $0.id == walkerID }),
            "immigrant must arrive within 12 months"
        )
        let house = try XCTUnwrap(city.houses.first(where: { $0.id == commonID }))
        XCTAssertGreaterThan(house.residents, 0)
        XCTAssertNil(house.vacantTypeID, "first arrival must activate the vacant house")
    }

    func testImmigrantArrivalSkippedWhileSettlingLockIsSet() throws {
        let original = try installedModels()
        let models = original.buildings
        var city = DeterministicCityState(year: -246, treasury: 15_000, mapWidth: 12, mapHeight: 5)
        _ = city.buildRoad((0..<6).map { GridPoint(x: $0, y: 2) }, rules: EconomyRulesEngine(models: original))
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            residents: 0,
            location: GridPoint(x: 2, y: 1),
            models: models
        ))
        let house = try XCTUnwrap(city.houses.first(where: { $0.id == houseID }))

        // Directly exercise the arrival write against the settling gate.
        XCTAssertTrue(city.startHouseSettlingLock(houseID: houseID))
        XCTAssertFalse(city.applyImmigrantArrival(
            ImmigrantArrival(houseID: houseID, peopleCount: 3),
            models: models
        ))
        XCTAssertEqual(city.houses[0].residents, 0)

        // Drain the countdown through the daily tick loop.
        var ticks = 0
        while city.houses[0].settlingLock != 0, ticks < 40 {
            _ = city.advanceTick(rules: EconomyRulesEngine(models: original))
            ticks += 1
        }
        XCTAssertEqual(city.houses[0].settlingLock, 0)
        XCTAssertTrue(city.applyImmigrantArrival(
            ImmigrantArrival(houseID: houseID, peopleCount: 3),
            models: models
        ))
        XCTAssertEqual(city.houses[0].residents, 3)
    }

    func testPopularityFactorMathAndPressureBands() {
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 30), 0)
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 20), -5)
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 26), -2)
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 40), 4)

        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 4), 1)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 8), 0)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 14), -1)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 20), -2)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 30), -3)

        XCTAssertEqual(DeterministicMigration.debtEffect(debtYears: 2, treasuryIsNegative: true), 0)
        XCTAssertEqual(DeterministicMigration.debtEffect(debtYears: 3, treasuryIsNegative: true), 1)

        XCTAssertEqual(DeterministicMigration.fengShuiEffect(population: 100, harmonyPercent: 100), 0)
        XCTAssertEqual(DeterministicMigration.fengShuiEffect(population: 400, harmonyPercent: 95), 1)
        XCTAssertEqual(DeterministicMigration.fengShuiEffect(population: 400, harmonyPercent: 55), -3)

        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 100, watchtowerCount: 2), 0)
        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 400, watchtowerCount: 0), 0)
        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 400, watchtowerCount: 1), -1)
        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 1000, watchtowerCount: 10), -4)

        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 10), -25)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 30), -8)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 45), 0)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 60), 50)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 80), 100)
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 50), 6)
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 75), 9)

        // §2 exact apply branches: raw sum when popularity < 61 or sum >= 0
        // under 41; biased otherwise, clamped when the biased sum crosses zero.
        XCTAssertEqual(DeterministicMigration.dampedPopularityDelta(current: 60, factorSum: 10), 10)
        XCTAssertEqual(DeterministicMigration.dampedPopularityDelta(current: 10, factorSum: -2), 0)
        XCTAssertEqual(DeterministicMigration.dampedPopularityDelta(current: 30, factorSum: -8), -6)

        XCTAssertEqual(
            DeterministicMigration.monumentPopularityTerm(
                goalBuildingIDs: [77, 85],
                completeRootBuildingIDs: [77, 253]
            ),
            4
        )
    }

    func testProducerSpawnsImmigrantsAndPopulationGrowsOnHaunxian() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        guard let entry = map.authoredPoints.landEntry else {
            throw XCTSkip("Haunxian map has no authored land entry")
        }
        let original = try installedModels()
        let models = original.buildings
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: -246, treasury: 15_000, map: map)

        // Road from the entry and a couple of vacant houses beside it.
        var cursor = entry
        var guardSteps = 0
        while guardSteps < 80 {
            guardSteps += 1
            let candidates = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            guard let next = candidates.first(where: {
                city.terrain?.isClearLand($0) == true
                    && !city.roadNetwork.contains($0)
                    && !city.occupiedBuildingPoints.contains($0)
            }) else { break }
            _ = city.buildRoad([next], rules: rules)
            cursor = next
            if city.roadNetwork.points.count >= 6 { break }
        }
        for offset in 0..<3 {
            let candidates = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            let point = candidates.first { candidate in
                candidate.y == cursor.y + 1 + offset
                    && city.terrain?.isClearLand(candidate) == true
                    && !city.occupiedBuildingPoints.contains(candidate)
            }
            if let point {
                _ = city.addHouse(
                    levelID: 0,
                    location: point,
                    vacantTypeID: 2,
                    models: models
                )
            }
        }
        XCTAssertGreaterThanOrEqual(city.houses.count, 1, "could not place houses")

        city.setAutomaticMigrationAvailability(.supportedOriginalProducer)
        city.setMigrationPopularity(60)

        var ticks = 0
        var sawWalker = false
        while city.population == 0, ticks < 30 * 12 {
            _ = city.advanceTick(rules: rules)
            ticks += 1
            if !city.migration.immigrantWalkers.isEmpty {
                sawWalker = true
            }
        }

        XCTAssertTrue(sawWalker, "producer must spawn immigrant figures")
        XCTAssertGreaterThan(city.population, 0, "immigrants must arrive within 12 months")
        XCTAssertGreaterThan(city.migration.assignedThisMonth, 0)
    }
}
