import XCTest
import EmperorCore
@testable import EmperorGameplay

final class Xia2PlayerPlaythroughTests: XCTestCase {
    private let milletCommodityID = AgriculturalCrop.millet.outputCommodityID

    func testPlayerCommandsContinueFromXiaOneAndAdvanceMilletHousingChain() throws {
        try requireAutomaticMigrationProducer()
        let controller = try startedController(missionID: 0, difficulty: .veryEasy)
        try buildXiaOneWinningCity(with: controller)
        try advanceUntilOutcome(with: controller, yearLimit: 10)
        guard case .victory? = controller.campaignRuntime?.outcome else {
            return XCTFail("Xia tutorial one did not reach victory")
        }

        let inheritedCity = try XCTUnwrap(controller.city)
        let inheritedFingerprint = controller.snapshot.replayFingerprint
        let inheritedHouseIDs = inheritedCity.houses.map(\.id)
        let inheritedPlacements = inheritedCity.placedBuildings

        let campaignID = try XCTUnwrap(controller.selectedCampaignID)
        let transition = controller.perform(
            .startCampaignMission(campaignID: campaignID, missionID: 1)
        )
        XCTAssertTrue(transition.wasApplied, transition.message)

        let continuedCity = try XCTUnwrap(controller.city)
        XCTAssertEqual(controller.selectedMissionID, 1)
        XCTAssertEqual(continuedCity.calendar, SimulationCalendar(year: -2002, month: 6))
        XCTAssertEqual(continuedCity.economy.treasury, 4_500)
        XCTAssertEqual(continuedCity.houses.map(\.id), inheritedHouseIDs)
        XCTAssertEqual(continuedCity.placedBuildings, inheritedPlacements)
        XCTAssertEqual(controller.snapshot.replayFingerprint, inheritedFingerprint)
        XCTAssertEqual(continuedCity.missionSettings?.allowedResourceCommodityIDs, [4, 5, 19])

        let houseLocations = continuedCity.houses.compactMap(\.location)
        try placeNext(.warehouse, with: controller)
        XCTAssertTrue(controller.perform(.selectAgriculturalCrop(.millet)).wasApplied)
        for _ in 0..<2 { try placeNext(.cropFarm, with: controller) }
        for _ in 0..<16 { try placeNext(.farmland, with: controller) }
        for index in [7, 15] {
            try placeClosest(.market, to: houseLocations[index], with: controller)
            try placeClosest(.foodShop, to: houseLocations[index], with: controller)
        }
        for index in stride(from: 1, through: 25, by: 3) {
            try placeClosest(.garden, to: houseLocations[index], with: controller)
        }

        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        var sawMilletHarvest = false
        var sawMilletDelivery = false
        var sawMilletAtMill = false
        for _ in 0..<(30 * 12) where controller.campaignRuntime?.outcome == .running {
            XCTAssertTrue(controller.perform(.advanceOneTick).wasApplied)
            guard let city = controller.city else { continue }
            sawMilletHarvest = sawMilletHarvest
                || city.production.lastAgriculturalSettlement?.harvests.contains {
                    $0.crop == .millet && $0.outputAmount > 0
                } == true
            sawMilletDelivery = sawMilletDelivery || city.logistics.deliveryWalkers.contains {
                $0.cargo.commodityID == milletCommodityID
            }
            sawMilletAtMill = sawMilletAtMill || city.logistics.mills.contains {
                $0.inventoryByCommodityID[milletCommodityID, default: 0] > 0
            }
        }

        let city = try XCTUnwrap(controller.city)
        XCTAssertGreaterThan(city.population, inheritedCity.population)
        XCTAssertGreaterThan(
            city.houses.filter { $0.houseLevelID + 3 >= 6 }
                .reduce(0) { $0 + $1.residents },
            0
        )
        XCTAssertFalse(city.logistics.warehouses.isEmpty)
        XCTAssertTrue(city.production.buildings.contains {
            $0.agriculture?.crop == .millet
        })
        XCTAssertTrue(sawMilletHarvest)
        XCTAssertTrue(sawMilletDelivery)
        XCTAssertTrue(sawMilletAtMill)
        XCTAssertTrue(controller.evidence.sawStaffedProducer)
        XCTAssertTrue(controller.evidence.sawProducerStock)
        XCTAssertTrue(controller.evidence.sawDeliveryWalker)
        XCTAssertTrue(controller.evidence.sawMillStock)
        XCTAssertTrue(controller.evidence.sawHouseFood)
    }

    private func requireAutomaticMigrationProducer() throws {
        throw XCTSkip(
            "BLOCKED BY UNKNOWN: original popularity/factor migration producer is not implemented"
        )
    }

    func testStartingXiaTwoDirectlyUsesOriginalSettingsWithoutInventingInheritance() throws {
        let controller = try startedController(missionID: 1)
        let city = try XCTUnwrap(controller.city)
        let settings = try XCTUnwrap(city.missionSettings)

        XCTAssertTrue(city.houses.isEmpty)
        XCTAssertTrue(city.placedBuildings.isEmpty)
        XCTAssertEqual(settings.startYear, -2002)
        XCTAssertEqual(settings.startMonth, 6)
        XCTAssertEqual(settings.initialFunds, 3_000)
        XCTAssertEqual(settings.allowedResourceCommodityIDs, [4, 5, 19])
        XCTAssertTrue(city.isAgriculturalCropAvailable(.millet))
        XCTAssertTrue(city.isAgriculturalCropAvailable(.hemp))
        XCTAssertFalse(city.isAgriculturalCropAvailable(.wheat))
        XCTAssertNil(city.campaignConstructionRestriction(forBuildingID: 54))
    }

    private func startedController(
        missionID: Int,
        difficulty: GameDifficulty = .normal
    ) throws -> GameSessionController {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let controller = try GameSessionController()
        let campaignID = try XCTUnwrap(
            controller.campaignID(fileName: "1 Xia Dynasty - Tutorials.pak")
        )
        XCTAssertTrue(controller.perform(.selectDifficulty(difficulty)).wasApplied)
        let result = controller.perform(
            .startCampaignMission(campaignID: campaignID, missionID: missionID)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return controller
    }

    private func buildXiaOneWinningCity(with controller: GameSessionController) throws {
        try placeNext(.huntingCamp, with: controller)
        try placeNext(.mill, with: controller)
        try placeNext(.market, with: controller)
        try placeNext(.foodShop, with: controller)
        for _ in 0..<8 { try placeNext(.well, with: controller) }
        try placeNext(.inspectorTower, with: controller)
        for _ in 0..<6 { try placeNext(.ancestralShrine, with: controller) }
        for _ in 0..<26 { try placeNext(.house, with: controller) }
    }

    private func advanceUntilOutcome(
        with controller: GameSessionController,
        yearLimit: Int
    ) throws {
        XCTAssertTrue(controller.perform(.setSpeed(3)).wasApplied)
        for _ in 0..<(30 * 12 * yearLimit)
        where controller.campaignRuntime?.outcome == .running {
            let result = controller.perform(.advanceOneTick)
            XCTAssertTrue(result.wasApplied, result.message)
        }
    }

    private func placeNext(
        _ tool: PlayerConstructionTool,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        let point: GridPoint?
        if tool == .house {
            point = city.nextHouseConstructionLocation()
        } else if tool == .cropFarm {
            point = city.nextBuildingConstructionLocation(
                buildingID: AgriculturalCrop.millet.producerBuildingID
            )
        } else if tool == .farmland {
            XCTAssertTrue(controller.perform(.selectConstruction(.farmland)).wasApplied)
            point = (0..<city.roadNetwork.height).lazy.flatMap { y in
                (0..<city.roadNetwork.width).lazy.map { GridPoint(x: $0, y: y) }
            }.first { controller.constructionPreview(at: $0).isValid }
        } else if let buildingID = tool.buildingID,
                  OriginalMarketCatalog.supports(shopBuildingID: buildingID) {
            point = city.placedBuildings.first {
                $0.category == .market
                    && city.canConstructMarketShop(
                        shopBuildingID: buildingID,
                        at: $0.origin
                    )
            }?.origin
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

    private func placeClosest(
        _ tool: PlayerConstructionTool,
        to target: GridPoint,
        with controller: GameSessionController
    ) throws {
        let city = try XCTUnwrap(controller.city)
        XCTAssertTrue(controller.perform(.selectConstruction(tool)).wasApplied)
        let candidates = (0..<city.roadNetwork.height).flatMap { y in
            (0..<city.roadNetwork.width).map { GridPoint(x: $0, y: y) }
        }.sorted {
            let left = abs($0.x - target.x) + abs($0.y - target.y)
            let right = abs($1.x - target.x) + abs($1.y - target.y)
            if left != right { return left < right }
            return $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
        }
        let point = try XCTUnwrap(
            candidates.first { controller.constructionPreview(at: $0).isValid },
            "no valid \(tool.rawValue) site near \(target)"
        )
        try place(tool, at: point, with: controller)
    }
}
