import XCTest
import EmperorCore
@testable import EmperorGameplay

final class Xia1PlayerPlaythroughTests: XCTestCase {
    private let expectedReplayFingerprint: UInt64 = 0x8b48_db19_e013_9f4f

    func testPlayerCommandsCompleteOriginalXiaTutorialOne() throws {
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
            return XCTFail(
                "expected victory; blockers: \(controller.snapshot.lastBlockReason ?? "none"); "
                    + "houses=\(city.houses.count); population=\(population); levels=\(levels); "
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
        XCTAssertTrue(evidence.sawStaffedProducer)
        XCTAssertTrue(evidence.sawProducerStock)
        XCTAssertTrue(evidence.sawDeliveryWalker)
        XCTAssertTrue(evidence.sawMillStock)
        XCTAssertTrue(evidence.sawBuyer)
        XCTAssertTrue(evidence.sawPeddler)
        XCTAssertTrue(evidence.sawHouseFood)
        XCTAssertTrue(evidence.sawWaterService)
        XCTAssertTrue(evidence.sawAncestorService)
        XCTAssertTrue(evidence.sawInspectionService)
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
        XCTAssertEqual(controller.campaignRuntime?.outcome, .running)
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
