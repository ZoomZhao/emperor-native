import EmperorCore
import XCTest

final class SimulationClockTests: XCTestCase {
    func testPureClockEndsExactlyEveryThirtyTicks() {
        var clock = SimulationClockState()

        for expectedSequence in 1...29 {
            let result = clock.advanceOneDay()
            XCTAssertEqual(result.tickSequence, UInt64(expectedSequence))
            XCTAssertFalse(result.didEndMonth)
        }
        XCTAssertEqual(clock.day, 30)

        let monthEnd = clock.advanceOneDay()
        XCTAssertTrue(monthEnd.didEndMonth)
        XCTAssertEqual(monthEnd.tickSequence, 30)
        XCTAssertEqual(clock.day, 1)
    }

    func testPureClockCrossesTwelveMonthsWithoutLosingTicks() {
        var clock = SimulationClockState()
        var monthEnds = 0
        for _ in 0..<(12 * SimulationClockState.daysPerMonth) {
            if clock.advanceOneDay().didEndMonth { monthEnds += 1 }
        }
        XCTAssertEqual(monthEnds, 12)
        XCTAssertEqual(clock.tickSequence, 360)
        XCTAssertEqual(clock.day, 1)
    }

    func testAdvanceMonthUsesTheSameTickPath() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var compatibility = DeterministicCityState(year: 1600, month: 12, treasury: 1_000)
        _ = compatibility.addHouse(
            levelID: 2,
            residents: 22,
            hasTaxCoverage: true,
            models: original.buildings
        )
        var ticking = compatibility

        let compatibilitySettlement = compatibility.advanceMonth(rules: rules)
        var tickingSettlement: MonthlySettlement?
        for _ in 0..<SimulationClockState.daysPerMonth {
            let result = ticking.advanceTick(rules: rules)
            if let settlement = result.monthlySettlement {
                XCTAssertNil(tickingSettlement)
                tickingSettlement = settlement
            }
        }

        XCTAssertEqual(tickingSettlement, compatibilitySettlement)
        XCTAssertEqual(ticking, compatibility)
        XCTAssertEqual(ticking.calendar, SimulationCalendar(year: 1601, month: 1))
    }

    func testMidMonthSaveReplayIsIdentical() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var uninterrupted = DeterministicCityState(year: 1600, treasury: 1_000)
        _ = uninterrupted.addHouse(
            levelID: 0,
            residents: 7,
            hasTaxCoverage: true,
            models: original.buildings
        )

        for _ in 0..<13 { _ = uninterrupted.advanceTick(rules: rules) }
        let encoded = try JSONEncoder().encode(uninterrupted)
        var restored = try JSONDecoder().decode(DeterministicCityState.self, from: encoded)

        for _ in 0..<47 {
            _ = uninterrupted.advanceTick(rules: rules)
            _ = restored.advanceTick(rules: rules)
        }

        XCTAssertEqual(restored, uninterrupted)
        XCTAssertEqual(restored.simulationClock.tickSequence, 60)
        XCTAssertEqual(restored.simulationClock.day, 1)
        XCTAssertEqual(restored.calendar, SimulationCalendar(year: 1600, month: 3))
    }

    func testWallClockSpeedChunkingCannotChangeSimulationState() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        let initial = DeterministicCityState(year: 1600, treasury: 1_000)
        var oneAtATime = initial
        var twoAtATime = initial
        var threeAtATime = initial

        for _ in 0..<60 { _ = oneAtATime.advanceTick(rules: rules) }
        for _ in 0..<30 {
            _ = twoAtATime.advanceTick(rules: rules)
            _ = twoAtATime.advanceTick(rules: rules)
        }
        for _ in 0..<20 {
            _ = threeAtATime.advanceTick(rules: rules)
            _ = threeAtATime.advanceTick(rules: rules)
            _ = threeAtATime.advanceTick(rules: rules)
        }

        XCTAssertEqual(twoAtATime, oneAtATime)
        XCTAssertEqual(threeAtATime, oneAtATime)
    }

    func testServiceWalkerMovesAtMostOneAdjacentRoadStepPerTick() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 1600,
            treasury: 1_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = city.buildRoad((0..<8).map { GridPoint(x: $0, y: 2) }, rules: rules)
        _ = city.addHouse(
            levelID: 0,
            residents: 7,
            location: GridPoint(x: 4, y: 1),
            models: original.buildings
        )
        XCTAssertNotNil(city.constructResidentialServiceBuilding(
            buildingID: 72,
            serviceRoadStart: GridPoint(x: 0, y: 2),
            replaySeed: 0x5449_434B,
            rules: rules
        ))
        let before = try XCTUnwrap(city.walkers.walkers.first?.currentPoint)

        let result = city.advanceTick(rules: rules)
        let after = try XCTUnwrap(city.walkers.walkers.first?.currentPoint)

        XCTAssertEqual(result.movement.walkers.movedRoadSteps, 1)
        XCTAssertEqual(abs(after.x - before.x) + abs(after.y - before.y), 1)
        XCTAssertNil(result.monthlySettlement)
    }

    func testLegacyCityWithoutContinuousClockFieldsStartsAtDayOne() throws {
        var city = DeterministicCityState(year: 1600, month: 4, treasury: 500)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(city)) as? [String: Any]
        )
        object.removeValue(forKey: "simulationClockState")
        object.removeValue(forKey: "monthlyServiceCoverageState")
        object.removeValue(forKey: "migrationState")
        city = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(city.simulationClock, SimulationClockState())
        XCTAssertEqual(city.migration, DeterministicMigrationState())
    }

    private func installedModels() throws -> OriginalEconomyModels {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        return try OriginalEconomyModels(source: .openDefault())
    }
}
