import EmperorCore
import XCTest

final class RoadBlockPlacementTests: XCTestCase {
    func testRoadBlockPreviewAcceptsOnlyUnoccupiedRoadTiles() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let models = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: models)
        var city = DeterministicCityState(
            year: -2038,
            treasury: 10_000,
            mapWidth: 8,
            mapHeight: 6
        )
        let roadPoint = GridPoint(x: 3, y: 2)
        XCTAssertEqual(city.buildRoad([roadPoint], rules: rules), 1)

        XCTAssertTrue(city.canConstructRoadBlock(at: roadPoint))
        XCTAssertFalse(city.canConstructRoadBlock(at: GridPoint(x: 3, y: 3)))

        XCTAssertNotNil(city.constructRoadBlock(at: roadPoint, rules: rules))
        XCTAssertFalse(city.canConstructRoadBlock(at: roadPoint))
        XCTAssertTrue(city.roadNetwork.contains(roadPoint))
    }
}
