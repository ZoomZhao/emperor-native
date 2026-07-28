import EmperorCore
import XCTest
@testable import EmperorGameplay

final class QinCampaignBaselineTests: XCTestCase {
    func testQinMissionOneStartsFromOriginalWorldData() throws {
        let controller = try startedQinMissionOne()
        let city = try XCTUnwrap(controller.city)
        XCTAssertEqual(city.calendar.year, -260)
        XCTAssertEqual(city.calendar.month, 6)
        XCTAssertEqual(city.economy.treasury, 15_000)
        XCTAssertEqual(
            controller.activeWorld?.mapAssignment.embeddedMap.mapURL.lastPathComponent,
            "Haunxian.map"
        )

        let goalSet = try qinMissionOneGoals(controller: controller)
        XCTAssertEqual(goalSet.goals.count, 2)
        XCTAssertTrue(goalSet.goals.contains {
            if case .monument(buildingID: 83) = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goalSet.goals.contains {
            if case .yearlyProduction(commodityID: 15, internalUnits: 1_800)
                = $0.requirement { return true }
            return false
        })

        let beginResult = controller.perform(.beginMapMonument(buildingID: 83))
        XCTAssertTrue(beginResult.wasApplied, beginResult.message)
        XCTAssertFalse(
            controller.perform(.beginMapMonument(buildingID: 83)).wasApplied
        )
    }

    func testQinMissionOneCanObserveCompletedGrandCanalGoal() throws {
        let controller = try startedQinMissionOne()
        let rules = EconomyRulesEngine(models: controller.models)
        var city = DeterministicCityState(
            year: -260,
            month: 6,
            treasury: 100_000,
            mapWidth: 40,
            mapHeight: 20
        )
        city.publicSafetyEnabled = false
        _ = city.buildRoad((0..<40).map { GridPoint(x: $0, y: 10) }, rules: rules)
        _ = try XCTUnwrap(city.constructWarehouse(
            at: GridPoint(x: 0, y: 7),
            rules: rules
        ))
        for (buildingID, x) in [(233, 4), (52, 7), (235, 10)] {
            _ = try XCTUnwrap(city.constructAestheticBuilding(
                buildingID: buildingID,
                at: GridPoint(x: x, y: 8),
                rules: rules
            ))
        }
        XCTAssertNotNil(city.beginMapMonument(buildingID: 83))
        XCTAssertNil(city.beginMapMonument(buildingID: 83))

        let configuration = try XCTUnwrap(
            OriginalMonumentConfiguration.configuration(buildingID: 83)
        )
        for (commodityID, amount) in configuration.requiredCommodityUnits {
            XCTAssertEqual(
                city.receiveCampaignCommodityGift(
                    commodityID: commodityID,
                    amount: amount
                ),
                amount
            )
        }
        for _ in 0..<40 where !city.aesthetics.completedMonumentBuildingIDs.contains(83) {
            _ = city.advanceMonth(rules: rules)
        }
        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(83))

        var snapshot = city.campaignGoalProgressSnapshot()
        snapshot.bestYearlyProductionUnitsByCommodityID[15] = 1_800
        XCTAssertTrue(
            CampaignGoalEvaluator.missionIsComplete(
                try qinMissionOneGoals(controller: controller),
                against: snapshot
            )
        )
    }

    func testEarthenGreatWallHasAProgressConfiguration() throws {
        let configuration = try XCTUnwrap(
            OriginalMonumentConfiguration.configuration(buildingID: 85)
        )
        XCTAssertEqual(configuration.buildingID, 85)
        XCTAssertGreaterThan(configuration.requiredWork, 0)
        XCTAssertFalse(configuration.requiredCommodityUnits.isEmpty)
        XCTAssertTrue(configuration.requiredSupportKinds.contains(.laborersCamp))
        XCTAssertTrue(configuration.requiredSupportKinds.contains(.masonsGuild))
    }

    private func startedQinMissionOne() throws -> GameSessionController {
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

    private func qinMissionOneGoals(
        controller: GameSessionController
    ) throws -> CampaignMissionGoalSet {
        let campaignID = try XCTUnwrap(controller.selectedCampaignID)
        let campaign = controller.campaigns[campaignID]
        let archive = try CampaignGoalArchive(
            campaignURL: campaign.url,
            missionCount: campaign.missions.count
        )
        return archive.missions[0]
    }
}
