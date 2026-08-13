import EmperorCore
import XCTest

final class RoadBlockPlacementTests: XCTestCase {
    func testRoadblockTerrainGuardRejects0x8And0x400AndWaterAux() throws {
        let terrain = try DeterministicTerrainState(
            width: 6,
            height: 1,
            terrainRawValues: [0x40, 0x48, 0x440, 0x40, 0x40, 0x0],
            roadWaterAuxiliaryValues: [0, 0, 0, 1, 0, 0]
        )
        func point(_ x: Int) -> GridPoint { GridPoint(x: x, y: 0) }

        XCTAssertTrue(terrain.canPlaceRoadBlock(at: point(0)))
        XCTAssertFalse(terrain.canPlaceRoadBlock(at: point(1)),
                       "raw 0x48 (0x40 | 0x8) keeps the occupied-surface marker and must be rejected")
        XCTAssertFalse(terrain.canPlaceRoadBlock(at: point(2)),
                       "raw 0x440 (0x40 | 0x400) is the special-crossing surface and must be rejected")
        XCTAssertFalse(terrain.canPlaceRoadBlock(at: point(3)),
                       "a non-zero road-water auxiliary byte must be rejected")
        XCTAssertTrue(terrain.canPlaceRoadBlock(at: point(4)))
        XCTAssertFalse(terrain.canPlaceRoadBlock(at: point(5)),
                       "raw terrain without the confirmed 0x40 road bit must be rejected")

        // The CitySimulation caller keeps the road-network membership test, so a
        // tile with terrain bit 0x40 but no recorded road stays unplaceable.
        let city = DeterministicCityState(year: 1600, treasury: 1_000, terrain: terrain)
        XCTAssertTrue(city.canConstructRoadBlock(at: point(0)))
        XCTAssertFalse(city.canConstructRoadBlock(at: point(1)))
        XCTAssertFalse(city.canConstructRoadBlock(at: point(2)))
        XCTAssertFalse(city.canConstructRoadBlock(at: point(3)))
        XCTAssertTrue(city.canConstructRoadBlock(at: point(4)))
        XCTAssertFalse(city.canConstructRoadBlock(at: point(5)),
                       "the caller still requires road-network membership")
    }

    func testRoadblockTerrainLessProceduralCityKeepsRoadNetworkRule() {
        let city = DeterministicCityState(year: 1600, treasury: 1_000, mapWidth: 8, mapHeight: 8)
        XCTAssertFalse(city.canConstructRoadBlock(at: GridPoint(x: 1, y: 1)),
                       "a map-less procedural city has no terrain; road network gates placement")
    }
}
