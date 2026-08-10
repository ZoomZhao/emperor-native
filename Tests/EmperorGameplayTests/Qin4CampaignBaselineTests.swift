import EmperorCore
import XCTest
@testable import EmperorGameplay

final class Qin4CampaignBaselineTests: XCTestCase {
    private let missionID = 3

    func testMissionStartsWithOriginalGreatWallSettingsGoalAndInvasions() throws {
        let controller = try startedController()
        let city = try XCTUnwrap(controller.city)
        XCTAssertEqual(city.calendar.year, -215)
        XCTAssertEqual(city.calendar.month, 6)
        XCTAssertEqual(city.economy.treasury, 18_000)
        XCTAssertEqual(
            controller.activeWorld?.mapAssignment.embeddedMap.mapURL.lastPathComponent,
            "Badaling.map"
        )
        XCTAssertEqual(
            city.missionSettings?.allowedResourceCommodityIDs,
            [1, 4, 5, 7, 10, 15, 18, 19, 21, 25, 26]
        )
        XCTAssertFalse(
            city.missionSettings?.allowedResourceCommodityIDs.contains(20) == true
        )
        for menuID in [3, 51, 52, 53, 55] {
            XCTAssertTrue(
                city.missionSettings?.allowedBuildingMenuIDs.contains(menuID) == true
            )
        }
        XCTAssertFalse(city.missionSettings?.allowedBuildingMenuIDs.contains(28) == true)
        let stonePartner = try XCTUnwrap(city.trade.partner(id: 13))
        XCTAssertTrue(stonePartner.isOpen)
        XCTAssertNotEqual(
            stonePartner.supplyByCommodityID[20],
            TradeVolumeLevel.none
        )

        let goals = try missionGoals(controller)
        XCTAssertEqual(goals.goals.count, 1)
        guard case .monument(buildingID: 85) = goals.goals[0].requirement else {
            return XCTFail("Qin M4 must have only the Earthen Great Wall goal")
        }

        let events = try missionEvents(controller)
        let invasions = events.events.filter { $0.kind == .invasion }
        XCTAssertEqual(invasions.count, 2)
        XCTAssertTrue(invasions.contains {
            $0.triggerMode == .oneTime
                && $0.secondarySelection.bounds == 10...10
                && $0.amount.bounds == 8...11
        })
        XCTAssertTrue(invasions.contains {
            $0.triggerMode == .recurring
                && $0.secondarySelection.bounds == 10...10
                && $0.amount.bounds == 15...20
        })

        let begin = controller.perform(.beginMapMonument(buildingID: 85))
        XCTAssertTrue(begin.wasApplied, begin.message)
        XCTAssertNotNil(controller.city?.aesthetics.earthenGreatWallProject)
        XCTAssertTrue(
            controller.perform(.selectConstruction(.earthenGreatWallSegment)).wasApplied
        )
        let firstWallPoint = try XCTUnwrap(
            EarthenGreatWallLayout.badalingMapBindings.first?.worldOrigin
        )
        XCTAssertTrue(
            controller.city?.aesthetics.earthenGreatWallProject?
                .segmentIndex(containing: firstWallPoint) == 0
        )
        let earlyClick = controller.perform(.placeSelectedConstruction(
            at: firstWallPoint,
            orientation: .northSouth
        ))
        XCTAssertFalse(earlyClick.wasApplied)
        let earlySegment = controller.perform(.advanceEarthenGreatWallSegment(index: 0))
        XCTAssertFalse(earlySegment.wasApplied)

        let tradingPoint = try XCTUnwrap(
            controller.city?.nextBuildingConstructionLocation(buildingID: 58)
        )
        let tradeBuild = controller.perform(.constructTradingBuilding(
            partnerID: 13,
            at: tradingPoint,
            orientation: .northSouth
        ))
        XCTAssertTrue(tradeBuild.wasApplied, tradeBuild.message)
        let tradingBuildingID = try XCTUnwrap(
            controller.city?.trade.buildings.first(where: { $0.partnerID == 13 })?.id
        )
        let importStone = controller.perform(.setTradeImporting(
            tradingBuildingID: tradingBuildingID,
            commodityID: 20,
            enabled: true
        ))
        XCTAssertTrue(importStone.wasApplied, importStone.message)
        XCTAssertTrue(
            controller.city?.trade.building(id: tradingBuildingID)?
                .importingCommodityIDs.contains(20) == true
        )
    }

    func testPlayerCommandBuildsAndRalliesAFormation() throws {
        let controller = try startedController()
        XCTAssertTrue(controller.perform(.selectConstruction(.fort)).wasApplied)
        let fortPoint = try XCTUnwrap(
            controller.city?.nextBuildingConstructionLocation(buildingID: 220),
            "Qin M4 should expose a valid infantry-fort site"
        )
        let build = controller.perform(
            .placeSelectedConstruction(at: fortPoint, orientation: .northSouth)
        )
        XCTAssertTrue(build.wasApplied, build.message)

        let unit = try XCTUnwrap(controller.city?.military.units.first)
        let city = try XCTUnwrap(controller.city)
        let destination = try XCTUnwrap(
            (0..<city.roadNetwork.height).lazy.flatMap { y in
                (0..<city.roadNetwork.width).lazy.map { GridPoint(x: $0, y: y) }
            }.first {
                $0 != unit.currentPoint && city.canIssueMilitaryOrder(to: $0)
            },
            "Qin M4 should expose a passable rally destination"
        )
        let order = controller.perform(
            .issueMilitaryOrder(unitIDs: [unit.id], to: destination)
        )
        XCTAssertTrue(order.wasApplied, order.message)
        let orderedUnit = try XCTUnwrap(controller.city?.military.units.first)
        XCTAssertEqual(orderedUnit.status, .marching)
        XCTAssertEqual(orderedUnit.rallyPoint, destination)
        XCTAssertFalse(orderedUnit.route.isEmpty)
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
            .startCampaignMission(campaignID: campaignID, missionID: missionID)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return controller
    }

    private func missionGoals(
        _ controller: GameSessionController
    ) throws -> CampaignMissionGoalSet {
        let campaignID = try XCTUnwrap(controller.selectedCampaignID)
        let campaign = controller.campaigns[campaignID]
        return try CampaignGoalArchive(
            campaignURL: campaign.url,
            missionCount: campaign.missions.count
        ).missions[missionID]
    }

    private func missionEvents(
        _ controller: GameSessionController
    ) throws -> CampaignMissionEventSet {
        let campaignID = try XCTUnwrap(controller.selectedCampaignID)
        let campaign = controller.campaigns[campaignID]
        return try CampaignEventArchive(
            campaignURL: campaign.url,
            missionCount: campaign.missions.count
        ).missions[missionID]
    }
}
