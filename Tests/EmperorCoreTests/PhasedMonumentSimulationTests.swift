import Foundation
import XCTest
@testable import EmperorCore

final class PhasedMonumentSimulationTests: XCTestCase {
    func testOriginalQinFiveMausoleumLayoutsParseAuthoredGeometry() throws {
        let root = GameDataSource.defaultRoot.appendingPathComponent("Model")
        let vaultURL = root.appendingPathComponent("Mon_Underground_Vault_Subs.txt")
        let tumulusURL = root.appendingPathComponent("Mon_Grand_Tumulus_subs.txt")
        guard FileManager.default.fileExists(atPath: vaultURL.path),
              FileManager.default.fileExists(atPath: tumulusURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }

        let vault = try XCTUnwrap(PhasedMonumentLayout.parse(
            subBuildingText: String(contentsOf: vaultURL, encoding: .utf8),
            expectedSubBuildingCount: 340,
            expectedPhaseCount: 9
        ))
        XCTAssertEqual(
            Dictionary(grouping: vault.subBuildings, by: \.kind).mapValues(\.count),
            [
                "SB_VAULT_POLES": 106,
                "SB_VAULT_SOLDIERS": 230,
                "SB_VAULT_RAMP": 1,
                "SB_VAULT_KILN": 3,
            ]
        )
        XCTAssertTrue(vault.phaseRules.contains {
            $0.monumentPhase == 0
                && $0.isJoined
                && $0.firstSubBuildingIndex == 337
                && $0.lastSubBuildingIndex == 339
        })

        let tumulus = try XCTUnwrap(PhasedMonumentLayout.parse(
            subBuildingText: String(contentsOf: tumulusURL, encoding: .utf8),
            expectedSubBuildingCount: 148,
            expectedPhaseCount: 43
        ))
        XCTAssertEqual(
            Dictionary(grouping: tumulus.subBuildings, by: \.kind).mapValues(\.count),
            [
                "SB_TUMULUS_RAMP": 4,
                "SB_TUMULUS_UPPER": 128,
                "SB_TUMULUS_LOWER": 16,
            ]
        )
        XCTAssertEqual(tumulus.phaseRules.map(\.monumentPhase).max(), 42)
    }

    func testQinFiveProjectsRequireEveryPlayerVisiblePhase() throws {
        for (buildingID, expectedPhases) in [(77, 43), (84, 9)] {
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
            var runtime = try XCTUnwrap(PhasedMonumentProjectRuntime(
                projectID: project.id,
                buildingID: buildingID,
                origin: GridPoint(x: 10, y: 10),
                orientation: .northSouth
            ))

            for phase in 1...expectedPhases {
                XCTAssertTrue(runtime.advance(project: project))
                XCTAssertEqual(runtime.completedPhaseCount, phase)
                XCTAssertEqual(runtime.isComplete, phase == expectedPhases)
            }
            XCTAssertEqual(runtime.completionPercent, 100)
            let data = try JSONEncoder().encode(runtime)
            XCTAssertEqual(
                try JSONDecoder().decode(
                    PhasedMonumentProjectRuntime.self,
                    from: data
                ),
                runtime
            )
        }
    }

    func testAestheticStateCreatesAndPersistsBothQinFivePhaseRuntimes() throws {
        var state = DeterministicAestheticState()
        _ = state.addConstruction(
            buildingID: 77,
            kind: .monument,
            location: GridPoint(x: 2, y: 2),
            origin: GridPoint(x: 2, y: 2)
        )
        _ = state.addConstruction(
            buildingID: 84,
            kind: .monument,
            location: GridPoint(x: 30, y: 30),
            origin: GridPoint(x: 30, y: 30)
        )
        XCTAssertEqual(
            Dictionary(
                uniqueKeysWithValues: state.phasedMonumentProjects.map {
                    ($0.buildingID, $0.phaseCount)
                }
            ),
            [77: 43, 84: 9]
        )
        XCTAssertTrue(state.completedMonumentBuildingIDs.isEmpty)

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(
            DeterministicAestheticState.self,
            from: data
        )
        XCTAssertEqual(restored, state)
    }

    func testMenagerieNormalizesGiftFiguresAndPersistsAcrossContinuation() throws {
        var firstRuntime = CampaignMissionRuntimeState(
            missionID: 1,
            startYear: -221,
            startMonth: 6,
            eventSet: CampaignMissionEventSet(id: 1, events: []),
            replaySeed: 1
        )
        firstRuntime.receiveMenagerieAnimals(productID: 69, amount: 1)
        firstRuntime.receiveMenagerieAnimals(productID: 71, amount: 2)
        firstRuntime.receiveMenagerieAnimals(productID: 30, amount: 1)
        XCTAssertEqual(firstRuntime.menagerieAnimalIDs, [30, 32])
        XCTAssertEqual(firstRuntime.menagerieAnimalCountsByProductID[30], 2)

        var continuation = CampaignMissionRuntimeState(
            missionID: 4,
            startYear: -212,
            startMonth: 6,
            eventSet: CampaignMissionEventSet(id: 4, events: []),
            replaySeed: 2
        )
        continuation.inheritMenagerie(
            animalCountsByProductID: firstRuntime.menagerieAnimalCountsByProductID
        )
        continuation.receiveMenagerieAnimals(productID: 73, amount: 1)
        XCTAssertEqual(continuation.menagerieAnimalIDs, [30, 32, 34])
        XCTAssertEqual(
            CampaignMissionRuntimeState.canonicalMenagerieProductID(77),
            38
        )
    }
}
