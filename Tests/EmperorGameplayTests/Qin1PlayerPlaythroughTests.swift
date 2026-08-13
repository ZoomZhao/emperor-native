import EmperorCore
import XCTest
@testable import EmperorGameplay

final class Qin1PlayerPlaythroughTests: XCTestCase {
    func testCanalReserveBlocksRoadWhileNearbyClearTerrainAllowsIt() throws {
        let controller = try startedController()
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let canalReserve = GridPoint(x: 4, y: 68)
        let clearLand = GridPoint(x: 70, y: 50)

        XCTAssertTrue(terrain.terrain(at: canalReserve)?.contains(.monument) == true)
        XCTAssertFalse(terrain.isClearLand(canalReserve))
        XCTAssertFalse(city.canConstructRoad(at: canalReserve))

        XCTAssertTrue(terrain.isClearLand(clearLand))
        XCTAssertTrue(city.canConstructRoad(at: clearLand))
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        XCTAssertEqual(
            controller.constructionPreview(at: canalReserve).reason,
            "original terrain, including canal reserve tiles, blocks road construction"
        )
        XCTAssertTrue(controller.constructionPreview(at: clearLand).isValid)
    }

    func testPlayerCommandsCannotUseTheDisprovenCanalShortcut() throws {
        let controller = try startedController()
        XCTAssertFalse(
            controller.perform(.beginMapMonument(buildingID: 83)).wasApplied
        )
        XCTAssertFalse(
            controller.perform(.selectConstruction(.grandCanalSegment)).wasApplied
        )
        XCTAssertNil(controller.city?.aesthetics.grandCanalProject)
        XCTAssertTrue(
            controller.city?.aesthetics.completedMonumentBuildingIDs.contains(83) == true
        )
    }

    func testPlayerCommandsCompleteOriginalQinMissionOneFromArchivedState() throws {
        let controller = try startedController()

        try placeNext(.warehouse, count: 2, with: controller)
        try placeNext(.ironMine, count: 4, with: controller)
        try placeNext(.inspectorTower, count: 3, with: controller)
        try placeNext(.well, count: 3, with: controller)
        try placeNext(.house, count: 24, with: controller)

        XCTAssertTrue(controller.perform(.setSpeed(1)).wasApplied)
        var ticks = 0
        while controller.campaignRuntime?.outcome == .running, ticks < 30 * 48 {
            let result = controller.perform(.advanceOneTick)
            XCTAssertTrue(result.wasApplied, result.message)
            ticks += 1
        }

        guard case .victory? = controller.campaignRuntime?.outcome else {
            return XCTFail("Qin mission one did not reach victory")
        }
        let city = try XCTUnwrap(controller.city)
        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(83))
        XCTAssertGreaterThanOrEqual(
            city.productionAccounting.bestYearlyProductionUnitsByCommodityID[15, default: 0],
            1_800
        )
        XCTAssertGreaterThan(city.population, 0)
    }

    @discardableResult
    private func placeNext(
        _ tool: PlayerConstructionTool,
        count: Int = 1,
        with controller: GameSessionController
    ) throws -> [GridPoint] {
        var origins: [GridPoint] = []
        for _ in 0..<count {
            var city = try XCTUnwrap(controller.city)
            var point: GridPoint? = tool == .house
                ? city.nextHouseConstructionLocation()
                : tool.buildingID.flatMap { buildingID in
                    city.nextBuildingConstructionLocation(buildingID: buildingID)
                }
            var extensions = 0
            while point == nil, extensions < 80 {
                try extendRoad(with: controller)
                city = try XCTUnwrap(controller.city)
                point = tool == .house
                    ? city.nextHouseConstructionLocation()
                    : tool.buildingID.flatMap { buildingID in
                        city.nextBuildingConstructionLocation(buildingID: buildingID)
                    }
                extensions += 1
            }
            let origin = try XCTUnwrap(point, "no valid \(tool.rawValue) site")
            XCTAssertTrue(controller.perform(.selectConstruction(tool)).wasApplied)
            let preview = controller.constructionPreview(at: origin)
            XCTAssertTrue(preview.isValid, preview.reason ?? "invalid \(tool.rawValue)")
            let result = controller.perform(
                .placeSelectedConstruction(at: origin, orientation: .northSouth)
            )
            XCTAssertTrue(result.wasApplied, result.message)
            origins.append(origin)
        }
        return origins
    }

    private func extendRoad(with controller: GameSessionController) throws {
        let city = try XCTUnwrap(controller.city)
        let terrain = try XCTUnwrap(city.terrain)
        let occupied = city.occupiedBuildingPoints
        let point = try XCTUnwrap(
            Set(city.roadNetwork.points.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)))
                .filter {
                    city.roadNetwork.isInside($0)
                        && !city.roadNetwork.contains($0)
                        && !occupied.contains($0)
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

    private func startedController() throws -> GameSessionController {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let controller = try GameSessionController()
        let campaignID = try XCTUnwrap(
            controller.campaignID(fileName: "4 Qin Dynasty.pak")
        )
        let result = controller.perform(
            .startCampaignMission(campaignID: campaignID, missionID: 0)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return controller
    }
}
