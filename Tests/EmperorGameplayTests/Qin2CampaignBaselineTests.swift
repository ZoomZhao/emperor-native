import EmperorCore
import XCTest
@testable import EmperorGameplay

final class Qin2CampaignBaselineTests: XCTestCase {
    func testMissionStartsWithOriginalSettingsGoalsAndMenus() throws {
        let controller = try startedController()
        let city = try XCTUnwrap(controller.city)
        XCTAssertEqual(city.calendar.year, -221)
        XCTAssertEqual(city.calendar.month, 6)
        XCTAssertEqual(city.economy.treasury, 23_000)
        XCTAssertEqual(
            controller.activeWorld?.mapAssignment.embeddedMap.mapURL.lastPathComponent,
            "Xianyang.map"
        )
        XCTAssertEqual(
            city.missionSettings?.allowedResourceCommodityIDs,
            [1, 2, 5, 7, 10, 12, 15, 17, 18, 19, 20, 21, 22, 24, 25, 26]
        )

        let goals = try missionGoals(controller)
        XCTAssertTrue(goals.goals.contains {
            if case .monument(buildingID: 82) = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goals.goals.contains {
            if case .housing(minimumLevelCode: 16, residents: 200) = $0.requirement {
                return true
            }
            return false
        })
        for buildingID in [11, 226, 220, 221, 223, 224] {
            XCTAssertTrue(city.isBuildingAvailableInCampaign(buildingID))
        }
        XCTAssertFalse(city.isBuildingAvailableInCampaign(225))
        XCTAssertTrue(city.trade.partners.contains {
            $0.isOpen && $0.supplyByCommodityID[14] != nil
        })
    }

    func testLargePalaceNeedsAllSixteenPlayerVisiblePhases() throws {
        let controller = try startedController()
        let rules = EconomyRulesEngine(models: controller.models)
        var city = DeterministicCityState(
            year: -221,
            month: 6,
            treasury: 100_000,
            mapWidth: 48,
            mapHeight: 32
        )
        city.publicSafetyEnabled = false
        _ = city.buildRoad((0..<48).map { GridPoint(x: $0, y: 10) }, rules: rules)
        _ = try XCTUnwrap(city.constructWarehouse(
            at: GridPoint(x: 0, y: 7),
            rules: rules
        ))
        for (buildingID, x) in [(233, 4), (52, 7), (236, 10), (235, 13)] {
            _ = try XCTUnwrap(city.constructAestheticBuilding(
                buildingID: buildingID,
                at: GridPoint(x: x, y: 8),
                rules: rules
            ))
        }
        let palaceOrigin = GridPoint(x: 18, y: 11)
        _ = try XCTUnwrap(city.constructAestheticBuilding(
            buildingID: 82,
            at: palaceOrigin,
            rules: rules
        ))
        for (commodityID, amount) in [10: 800, 18: 800, 20: 800] {
            XCTAssertEqual(
                city.receiveCampaignCommodityGift(
                    commodityID: commodityID,
                    amount: amount
                ),
                amount
            )
        }
        XCTAssertFalse(city.aesthetics.completedMonumentBuildingIDs.contains(82))

        for phase in 1...LargePalaceProjectRuntime.phaseCount {
            var waitedMonths = 0
            while !city.canAdvanceLargePalacePhase(at: palaceOrigin), waitedMonths < 12 {
                _ = city.advanceMonth(rules: rules)
                waitedMonths += 1
            }
            XCTAssertLessThan(waitedMonths, 12, "phase \(phase) never reached its gate")
            XCTAssertEqual(
                city.advanceLargePalacePhase(at: palaceOrigin),
                phase
            )
        }
        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(82))
        XCTAssertTrue(city.aesthetics.largePalaceProject?.isComplete == true)
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
            .startCampaignMission(campaignID: campaignID, missionID: 1)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return controller
    }

    private func missionGoals(
        _ controller: GameSessionController
    ) throws -> CampaignMissionGoalSet {
        let campaignID = try XCTUnwrap(controller.selectedCampaignID)
        let campaign = controller.campaigns[campaignID]
        let archive = try CampaignGoalArchive(
            campaignURL: campaign.url,
            missionCount: campaign.missions.count
        )
        return archive.missions[1]
    }
}
