import EmperorCore
import XCTest
@testable import EmperorGameplay

final class Qin1PlayerPlaythroughTests: XCTestCase {
    func testPlayerCommandsCompleteZhengGuoCanalMission() throws {
        let controller = try startedController()

        try placeNext(.house, count: 30, with: controller)
        try placeNext(.huntingCamp, with: controller)
        try placeNext(.mill, with: controller)
        try placeNext(.market, with: controller)
        try placeNext(.well, count: 4, with: controller)
        try placeNext(.ancestralShrine, count: 2, with: controller)
        try placeNext(.inspectorTower, count: 4, with: controller)

        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        for _ in 0..<(30 * 12) {
            XCTAssertTrue(controller.perform(.advanceOneTick).wasApplied)
        }
        XCTAssertTrue(controller.perform(.setSpeed(0)).wasApplied)

        try placeNext(.warehouse, count: 2, with: controller)
        try placeNext(.lumberMill, count: 2, with: controller)
        try placeNext(.quarry, count: 2, with: controller)
        try placeNext(.ironMine, count: 3, with: controller)
        try placeNext(.laborersCamp, with: controller)
        try placeNext(.carpentersGuild, with: controller)
        try placeNext(.masonsGuild, with: controller)

        let begin = controller.perform(.beginMapMonument(buildingID: 83))
        XCTAssertTrue(begin.wasApplied, begin.message)
        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)

        for _ in 0..<(30 * 12 * 8) where controller.campaignRuntime?.outcome == .running {
            let result = controller.perform(.advanceOneTick)
            XCTAssertTrue(result.wasApplied, result.message)
        }

        guard case .victory? = controller.campaignRuntime?.outcome else {
            let city = try XCTUnwrap(controller.city)
            let project = city.aesthetics.monuments.first(where: { $0.buildingID == 83 })
            let yearlyIron = city.productionAccounting
                .bestYearlyProductionUnitsByCommodityID[15, default: 0]
            return XCTFail(
                "expected Qin M1 victory; population=\(city.population); "
                    + "yearlyIron=\(yearlyIron); "
                    + "project=\(String(describing: project)); "
                    + "workforce=\(city.workforceSnapshot(models: controller.models.buildings))"
            )
        }

        let city = try XCTUnwrap(controller.city)
        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(83))
        XCTAssertGreaterThanOrEqual(
            city.productionAccounting.bestYearlyProductionUnitsByCommodityID[15, default: 0],
            1_800
        )
        XCTAssertEqual(controller.speed, 0)
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

    private func placeNext(
        _ tool: PlayerConstructionTool,
        count: Int = 1,
        with controller: GameSessionController
    ) throws {
        for index in 0..<count {
            var city = try XCTUnwrap(controller.city)
            var point: GridPoint?
            if tool == .house {
                point = city.nextHouseConstructionLocation()
                while point == nil {
                    try extendRoadTowardHousing(with: controller)
                    city = try XCTUnwrap(controller.city)
                    point = city.nextHouseConstructionLocation()
                }
            } else if let buildingID = tool.buildingID {
                point = city.nextBuildingConstructionLocation(buildingID: buildingID)
            } else {
                point = nil
            }
            let origin = try XCTUnwrap(
                point,
                "no valid \(tool.rawValue) site at placement \(index + 1)/\(count)"
            )
            XCTAssertTrue(controller.perform(.selectConstruction(tool)).wasApplied)
            let preview = controller.constructionPreview(at: origin)
            XCTAssertTrue(
                preview.isValid,
                "\(tool.rawValue) \(origin): \(preview.reason ?? "unknown")"
            )
            let result = controller.perform(
                .placeSelectedConstruction(at: origin, orientation: .northSouth)
            )
            XCTAssertTrue(result.wasApplied, result.message)
        }
    }

    private func extendRoadTowardHousing(
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
        }, "no clear road extension can open another housing plot")
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        let result = controller.perform(
            .placeSelectedConstruction(at: roadPoint, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
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
