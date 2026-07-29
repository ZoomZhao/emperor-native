import XCTest
@testable import EmperorCore
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
        XCTAssertEqual(vault.requiredCommodityUnits, [10: 10_600, 18: 1_100])
        XCTAssertEqual(
            vault.requiredSupportKinds,
            [.laborersCamp, .carpentersGuild, .ceramistsGuild]
        )

        let tumulus = try XCTUnwrap(
            OriginalMonumentConfiguration.configuration(buildingID: 77)
        )
        XCTAssertEqual(tumulus.requiredWork, 2_400)
        XCTAssertEqual(
            tumulus.requiredCommodityUnits,
            [10: 8_900, 21: 700, 22: 1_100, 24: 1_000, 25: 900, 26: 400]
        )
        XCTAssertNil(tumulus.requiredCommodityUnits[17])
        XCTAssertNil(tumulus.requiredCommodityUnits[23])
        XCTAssertEqual(
            PhasedMonumentProjectRuntime.phaseCountsByBuildingID,
            [77: 43, 84: 9]
        )
    }

    func testM2ContinuationClosesAllFourQinFiveGoalsOnlyAfterFullPhases() throws {
        let controller = try startedController()
        let settings = try XCTUnwrap(controller.activeWorld?.startSettings)
        let goals = try missionGoals(controller)

        var inheritedCity = DeterministicCityState(year: -221, treasury: 151_234)
        inheritedCity.continueCampaignMission(with: settings)
        XCTAssertEqual(inheritedCity.calendar.year, -212)
        XCTAssertEqual(inheritedCity.calendar.month, 6)
        XCTAssertEqual(inheritedCity.economy.treasury, 151_234)

        var m2Runtime = CampaignMissionRuntimeState(
            missionID: 1,
            startYear: -221,
            startMonth: 6,
            eventSet: CampaignMissionEventSet(id: 1, events: []),
            replaySeed: 1
        )
        for figureID in 69...75 {
            m2Runtime.receiveMenagerieAnimals(productID: figureID, amount: 1)
        }
        var m5Runtime = CampaignMissionRuntimeState(
            missionID: missionID,
            startYear: -212,
            startMonth: 6,
            eventSet: CampaignMissionEventSet(id: missionID, events: []),
            replaySeed: 2
        )
        m5Runtime.inheritMenagerie(
            animalCountsByProductID: m2Runtime.menagerieAnimalCountsByProductID
        )
        m5Runtime.receiveMenagerieAnimals(productID: 76, amount: 1)
        XCTAssertEqual(m5Runtime.menagerieAnimalIDs.count, 8)

        var completedMonuments = Set<Int>()
        for buildingID in [84, 77] {
            let configuration = try XCTUnwrap(
                OriginalMonumentConfiguration.configuration(buildingID: buildingID)
            )
            var project = MonumentProject(
                id: buildingID,
                buildingID: buildingID,
                requiredWork: configuration.requiredWork,
                requiredCommodityUnits: configuration.requiredCommodityUnits,
                requiredSupportKinds: configuration.requiredSupportKinds,
                deliveredCommodityUnits: [:],
                completedWork: 0,
                isComplete: false
            )
            for (commodityID, amount) in configuration.requiredCommodityUnits {
                project.recordDelivery(commodityID: commodityID, amount: amount)
            }
            project.performWork(configuration.requiredWork, allowCompletion: false)
            var phased = try XCTUnwrap(PhasedMonumentProjectRuntime(
                projectID: buildingID,
                buildingID: buildingID,
                origin: GridPoint(x: buildingID, y: buildingID),
                orientation: .northSouth
            ))
            for _ in 0..<phased.phaseCount {
                XCTAssertTrue(phased.advance(project: project))
            }
            XCTAssertTrue(phased.isComplete)
            completedMonuments.insert(buildingID)
        }

        let completeSnapshot = inheritedCity.campaignGoalProgressSnapshot(
            menagerieSpeciesCount: m5Runtime.menagerieAnimalIDs.count,
            completedMonumentBuildingIDs: completedMonuments
        )
        XCTAssertTrue(
            CampaignGoalEvaluator.missionIsComplete(
                goals,
                against: completeSnapshot
            )
        )

        var missingSpecies = completeSnapshot
        missingSpecies.menagerieSpeciesCount = 7
        XCTAssertFalse(
            CampaignGoalEvaluator.missionIsComplete(goals, against: missingSpecies)
        )
        var shortTreasury = completeSnapshot
        shortTreasury.treasury = 149_999
        XCTAssertFalse(
            CampaignGoalEvaluator.missionIsComplete(goals, against: shortTreasury)
        )
        var missingTumulus = completeSnapshot
        missingTumulus.completedMonumentBuildingIDs.remove(77)
        XCTAssertFalse(
            CampaignGoalEvaluator.missionIsComplete(goals, against: missingTumulus)
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
