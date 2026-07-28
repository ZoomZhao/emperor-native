import EmperorCore
import XCTest

final class MigrationSimulationTests: XCTestCase {
    func testMigrationUsesRoadAdjacentVacanciesInHouseIDOrderAtFivePeoplePerDay() throws {
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

        let firstDay = city.advanceTick(rules: rules)
        XCTAssertEqual(firstDay.migratedResidents, 5)
        XCTAssertEqual(city.population, 5)
        XCTAssertEqual(city.houses.first(where: { $0.id == firstID })?.residents, 5)
        XCTAssertEqual(city.houses.first(where: { $0.id == secondID })?.residents, 0)

        let secondDay = city.advanceTick(rules: rules)
        XCTAssertEqual(secondDay.migratedResidents, 5)
        XCTAssertEqual(city.houses.first(where: { $0.id == firstID })?.residents, 7)
        XCTAssertEqual(city.houses.first(where: { $0.id == secondID })?.residents, 3)
    }

    func testMigrationFillsEliteCompoundsBeforeLowerTierVacancies() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 12,
            mapHeight: 5
        )
        _ = city.buildRoad(
            (0..<12).flatMap { x in
                [GridPoint(x: x, y: 0), GridPoint(x: x, y: 3)]
            },
            rules: rules
        )
        let commonID = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 2, y: 1),
            models: original.buildings
        )
        let eliteID = city.addHouse(
            levelID: 13,
            location: GridPoint(x: 5, y: 1),
            models: original.buildings
        )

        XCTAssertEqual(city.advanceTick(rules: rules).migratedResidents, 5)
        XCTAssertEqual(city.houses.first(where: { $0.id == eliteID })?.residents, 5)
        XCTAssertEqual(city.houses.first(where: { $0.id == commonID })?.residents, 0)
    }

    func testMigrationIgnoresHousingWithoutRoadAccessAndStopsAtCapacity() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 2038, treasury: 10_000, mapWidth: 8, mapHeight: 5)
        _ = city.buildRoad([GridPoint(x: 1, y: 2)], rules: rules)
        _ = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 6, y: 4),
            models: original.buildings
        )

        let blocked = city.advanceTick(rules: rules)
        XCTAssertEqual(blocked.migratedResidents, 0)
        XCTAssertEqual(blocked.migrationAssessment.blockReason, .noEligibleHousing)

        _ = city.buildRoad([GridPoint(x: 0, y: 1)], rules: rules)
        _ = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 1, y: 1),
            models: original.buildings
        )
        _ = city.advanceTick(rules: rules)
        let capped = city.advanceTick(rules: rules)
        XCTAssertEqual(city.population, 7)
        XCTAssertEqual(capped.migratedResidents, 2)
        XCTAssertEqual(city.migration.lastAssessment?.blockReason, nil)
    }

    func testMigrationPausesAtOneHundredFiftyWithHighUnemployment() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: 2038, treasury: 100_000, mapWidth: 40, mapHeight: 5)
        city.workforceEnabled = true
        _ = city.buildRoad((0..<40).map { GridPoint(x: $0, y: 2) }, rules: rules)
        for x in 1...23 {
            _ = city.addHouse(
                levelID: 0,
                location: GridPoint(x: x, y: 1),
                models: original.buildings
            )
        }

        while city.population < 150 {
            _ = city.advanceTick(rules: rules)
        }
        let blocked = city.advanceTick(rules: rules)

        XCTAssertEqual(city.population, 150)
        XCTAssertEqual(blocked.migratedResidents, 0)
        XCTAssertEqual(blocked.migrationAssessment.blockReason, .highUnemployment(percent: 100))
        XCTAssertEqual(city.migration.lastMonthImmigrants, 150)
        XCTAssertEqual(city.migration.currentMonthImmigrants, 0)
    }

    func testMigrationPausesAtOneHundredFiftyWhenTreasuryIsNegative() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        let width = 40
        let height = 5
        var terrain = Array(repeating: UInt32(0), count: width * height)
        for x in 0..<width {
            terrain[2 * width + x] = TerrainFlags.road.rawValue
        }
        let terrainState = try DeterministicTerrainState(
            width: width,
            height: height,
            terrainRawValues: terrain
        )
        var city = DeterministicCityState(year: 2038, treasury: -1, terrain: terrainState)
        for x in 1...23 {
            _ = city.addHouse(
                levelID: 0,
                location: GridPoint(x: x, y: 1),
                models: original.buildings
            )
        }

        while city.population < 150 {
            _ = city.advanceTick(rules: rules)
        }
        let blocked = city.advanceTick(rules: rules)

        XCTAssertEqual(city.population, 150)
        XCTAssertEqual(blocked.migratedResidents, 0)
        XCTAssertEqual(blocked.migrationAssessment.blockReason, .negativeTreasury)
    }

    func testMigrationMidMonthSaveReplayIsIdentical() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var uninterrupted = DeterministicCityState(year: 2038, treasury: 10_000, mapWidth: 12, mapHeight: 5)
        _ = uninterrupted.buildRoad((0..<12).map { GridPoint(x: $0, y: 2) }, rules: rules)
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
        XCTAssertEqual(restored.migration.currentMonthImmigrants, 21)
    }

    private func installedModels() throws -> OriginalEconomyModels {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        return try OriginalEconomyModels(source: .openDefault())
    }
}
