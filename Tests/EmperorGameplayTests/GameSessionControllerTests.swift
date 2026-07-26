import XCTest
import EmperorCore
@testable import EmperorGameplay

final class GameSessionControllerTests: XCTestCase {
    func testWarehouseCommodityPolicyCommandRoundTrips() throws {
        let command = PlayerCommand.setWarehouseCommodityPolicy(
            warehouseID: 7,
            commodityID: 25,
            policy: .get
        )

        let encoded = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(PlayerCommand.self, from: encoded)

        XCTAssertEqual(decoded, command)
    }

    func testAgriculturalCropSelectionCommandRoundTrips() throws {
        let command = PlayerCommand.selectAgriculturalCrop(.rice)
        let encoded = try JSONEncoder().encode(command)
        XCTAssertEqual(
            try JSONDecoder().decode(PlayerCommand.self, from: encoded),
            command
        )
    }

    func testMissionStartPauseAndInvalidConstructionCommands() throws {
        let controller = try controllerWithXiaOne()
        let snapshot = try XCTUnwrap(controller.snapshot.city)
        XCTAssertEqual(snapshot.calendar.year, -2038)
        XCTAssertEqual(snapshot.calendar.month, 6)
        XCTAssertEqual(snapshot.economy.treasury, 2_000)
        XCTAssertEqual(controller.snapshot.campaignRuntime?.outcome, .running)
        XCTAssertFalse(controller.perform(.advanceOneTick).wasApplied)

        let treasury = snapshot.economy.treasury
        XCTAssertTrue(controller.perform(.selectConstruction(.road)).wasApplied)
        let city = try XCTUnwrap(controller.city)
        let roadPoint = try XCTUnwrap((0..<city.roadNetwork.height).lazy.compactMap { y in
            (0..<city.roadNetwork.width).lazy.compactMap { x -> GridPoint? in
                let point = GridPoint(x: x, y: y)
                return city.canConstructRoad(at: point) ? point : nil
            }.first
        }.first)
        XCTAssertTrue(controller.constructionPreview(at: roadPoint).isValid)
        XCTAssertTrue(controller.perform(
            .placeSelectedConstruction(at: roadPoint, orientation: .northSouth)
        ).wasApplied)
        XCTAssertLessThan(try XCTUnwrap(controller.city).economy.treasury, treasury)

        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        XCTAssertTrue(controller.perform(.advanceOneTick).wasApplied)
        XCTAssertEqual(controller.snapshot.city?.simulationClock.tickSequence, 1)

        XCTAssertTrue(controller.perform(.selectConstruction(.market)).wasApplied)
        let impossible = GridPoint(x: -1, y: -1)
        XCTAssertFalse(controller.constructionPreview(at: impossible).isValid)
        XCTAssertFalse(controller.perform(
            .placeSelectedConstruction(at: impossible, orientation: .northSouth)
        ).wasApplied)
    }

    func testReplayRebuildsMissionScopedState() throws {
        let controller = try controllerWithXiaOne()
        let initial = controller.snapshot
        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        for _ in 0..<10 { XCTAssertTrue(controller.perform(.advanceOneTick).wasApplied) }
        XCTAssertNotEqual(controller.snapshot.city?.simulationClock.tickSequence, 0)
        XCTAssertTrue(controller.perform(.replayMission).wasApplied)
        XCTAssertEqual(controller.snapshot.city, initial.city)
        XCTAssertEqual(controller.snapshot.campaignRuntime, initial.campaignRuntime)
        XCTAssertEqual(controller.snapshot.speed, 0)
        XCTAssertEqual(controller.snapshot.selectedConstruction, .inspect)
    }

    func testRoadBlockCommandUsesRoadTileAndPersistsAfterTick() throws {
        let controller = try controllerWithXiaOne()
        let city = try XCTUnwrap(controller.city)
        let sortedRoadPoints = city.roadNetwork.points.sorted { lhs, rhs in
            lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
        }
        let candidate = sortedRoadPoints.first {
            city.canConstructRoadBlock(at: $0)
        }
        let roadPoint = try XCTUnwrap(candidate)

        XCTAssertTrue(controller.perform(.selectConstruction(.roadblock)).wasApplied)
        XCTAssertTrue(controller.constructionPreview(at: roadPoint).isValid)
        XCTAssertTrue(controller.perform(
            .placeSelectedConstruction(at: roadPoint, orientation: .northSouth)
        ).wasApplied)
        XCTAssertEqual(
            controller.city?.placedBuildings.filter { $0.buildingID == 126 }.count,
            1
        )

        XCTAssertTrue(controller.perform(.setSpeed(1)).wasApplied)
        XCTAssertTrue(controller.perform(.advanceOneTick).wasApplied)
        XCTAssertEqual(
            controller.city?.placedBuildings.filter { $0.buildingID == 126 }.count,
            1
        )
        XCTAssertEqual(controller.city?.roadNetwork.contains(roadPoint), true)
    }

    private func controllerWithXiaOne() throws -> GameSessionController {
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
        return controller
    }
}
