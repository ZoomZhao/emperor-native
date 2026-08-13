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
}
