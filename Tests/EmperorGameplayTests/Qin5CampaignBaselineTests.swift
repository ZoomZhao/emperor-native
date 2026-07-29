import EmperorCore
import XCTest
@testable import EmperorGameplay

final class Qin5CampaignBaselineTests: XCTestCase {
    private let missionID = 4

    func testMissionStartsWithOriginalContinuationSettingsAndFourGoals() throws {
        let controller = try startedController()
        let city = try XCTUnwrap(controller.city)
        XCTAssertEqual(city.calendar.year, -212)
        XCTAssertEqual(city.calendar.month, 6)
        XCTAssertEqual(city.economy.treasury, 0)
        XCTAssertEqual(
            controller.activeWorld?.mapAssignment.embeddedMap.mapURL.lastPathComponent,
            "Xianyang.map"
        )
        XCTAssertTrue(controller.activeWorld?.mapAssignment.isContinuation == true)
        XCTAssertEqual(controller.activeWorld?.mapAssignment.sourceMissionIndex, 1)
        XCTAssertTrue(city.missionSettings?.requiresInheritedTreasury == true)
        XCTAssertEqual(
            city.missionSettings?.allowedResourceCommodityIDs,
            [1, 2, 5, 7, 10, 12, 15, 17, 18, 19, 20, 21, 22, 24, 25, 26]
        )
        XCTAssertTrue(
            city.missionSettings?.allowedBuildingMenuIDs.contains(43) == true
        )

        let goals = try missionGoals(controller)
        XCTAssertEqual(goals.goals.count, 4)
        XCTAssertTrue(goals.goals.contains {
            if case .monument(buildingID: 84) = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goals.goals.contains {
            if case .monument(buildingID: 77) = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goals.goals.contains {
            if case .menagerieSpecies(8) = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goals.goals.contains {
            if case .treasury(150_000) = $0.requirement { return true }
            return false
        })

        let vault = try XCTUnwrap(
            OriginalMonumentConfiguration.configuration(buildingID: 84)
        )
        XCTAssertEqual(vault.requiredWork, 4_000)
        XCTAssertEqual(vault.requiredCommodityUnits, [10: 1_000, 18: 1_200])
        XCTAssertEqual(
            vault.requiredSupportKinds,
            [.laborersCamp, .carpentersGuild, .ceramistsGuild]
        )

        let tumulus = try XCTUnwrap(
            OriginalMonumentConfiguration.configuration(buildingID: 77)
        )
        XCTAssertEqual(tumulus.requiredWork, 2_400)
        XCTAssertEqual(
            PhasedMonumentProjectRuntime.phaseCountsByBuildingID,
            [77: 43, 84: 9]
        )
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
}
