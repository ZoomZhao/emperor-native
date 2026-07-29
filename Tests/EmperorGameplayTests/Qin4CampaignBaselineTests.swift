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
        let earlySegment = controller.perform(.advanceEarthenGreatWallSegment(index: 0))
        XCTAssertFalse(earlySegment.wasApplied)
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
