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
        XCTAssertEqual(
            PhasedMonumentLayout.original(buildingID: 84),
            vault
        )

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
        XCTAssertEqual(
            PhasedMonumentLayout.original(buildingID: 77),
            tumulus
        )
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

    func testGrandTumulusAcceptsLacquerwareOrBronzewareAsBurialProvision() throws {
        let configuration = try XCTUnwrap(
            OriginalMonumentConfiguration.configuration(buildingID: 77)
        )
        XCTAssertEqual(
            configuration.requiredCommodityUnits,
            [10: 8_900, 21: 700, 22: 1_100, 24: 1_000, 25: 900, 26: 400]
        )

        var project = MonumentProject(
            id: 77,
            buildingID: 77,
            requiredWork: configuration.requiredWork,
            requiredCommodityUnits: configuration.requiredCommodityUnits,
            requiredSupportKinds: configuration.requiredSupportKinds,
            deliveredCommodityUnits: [:],
            completedWork: 0,
            isComplete: false
        )
        project.recordDelivery(commodityID: 22, amount: 600)
        project.recordDelivery(commodityID: 23, amount: 500)
        XCTAssertEqual(
            project.deliveredUnits(satisfyingRequirementFor: 22),
            1_100
        )
        XCTAssertTrue(project.hasDelivered([22: 1_100]))
        XCTAssertFalse(project.hasDelivered([22: 1_101]))
    }

    func testAuthoredPhaseOnlyAdvancesItsDeclaredSubBuildings() throws {
        let vault = try XCTUnwrap(PhasedMonumentLayout.original(buildingID: 84))
        let configuration = try XCTUnwrap(
            OriginalMonumentConfiguration.configuration(buildingID: 84)
        )
        let project = fullyFundedProject(
            buildingID: 84,
            configuration: configuration
        )
        var runtime = try XCTUnwrap(PhasedMonumentProjectRuntime(
            projectID: 84,
            buildingID: 84,
            origin: GridPoint(x: 10, y: 10),
            orientation: .northSouth
        ))

        XCTAssertTrue(runtime.advance(project: project, layout: vault))
        XCTAssertEqual(runtime.subBuildingPhase(index: 337), 1)
        XCTAssertEqual(runtime.subBuildingPhase(index: 339), 1)
        XCTAssertEqual(runtime.subBuildingPhase(index: 336), 0)
        XCTAssertEqual(runtime.subBuildingPhase(index: 0), 0)

        XCTAssertTrue(runtime.advance(project: project, layout: vault))
        XCTAssertEqual(runtime.subBuildingPhase(index: 0), 1)
        XCTAssertEqual(runtime.subBuildingPhase(index: 336), 1)
        XCTAssertEqual(runtime.subBuildingPhase(index: 337), 1)

        let data = try JSONEncoder().encode(runtime)
        XCTAssertEqual(
            try JSONDecoder().decode(
                PhasedMonumentProjectRuntime.self,
                from: data
            ),
            runtime
        )
    }

    func testGrandTumulusRampDirectionsUseVerifiedFrames() throws {
        let tumulus = try XCTUnwrap(PhasedMonumentLayout.original(buildingID: 77))
        let ramps = tumulus.subBuildings.filter {
            $0.kind == "SB_TUMULUS_RAMP"
        }
        XCTAssertEqual(ramps.map(\.orientation), ["NORTH", "WEST", "EAST", "SOUTH"])
        XCTAssertEqual(
            ramps.compactMap {
                OriginalBuildingSpriteCatalog.phasedMonumentSubBuildingSprite(
                    buildingID: 77,
                    subBuilding: $0,
                    currentSubBuildingPhase: 1
                )?.imageID
            },
            [371, 374, 372, 373]
        )
        XCTAssertTrue((371...374).allSatisfy {
            OriginalBuildingSpriteCatalog.requiredImageIDsByArchive[
                OriginalBuildingSpriteCatalog.tumulusArchiveBaseName,
                default: []
            ].contains($0)
        })
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

    private func fullyFundedProject(
        buildingID: Int,
        configuration: OriginalMonumentConfiguration
    ) -> MonumentProject {
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
        return project
    }
}
