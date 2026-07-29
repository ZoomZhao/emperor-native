import Foundation
import XCTest
@testable import EmperorCore

final class EarthenGreatWallSimulationTests: XCTestCase {
    func testOriginalSubsFileParsesThirtyFiveIndependentSegments() throws {
        let sourceURL = GameDataSource.defaultRoot
            .appendingPathComponent("Model/Mon_Earthen_Great_Wall_subs.txt")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let text = try String(contentsOf: sourceURL, encoding: .utf8)
        let layout = try XCTUnwrap(
            EarthenGreatWallLayout.parse(subBuildingText: text)
        )

        XCTAssertEqual(layout.segments.count, 35)
        XCTAssertEqual(layout.phaseRules.count, 8)
        XCTAssertEqual(layout.segments.first?.localOrigin, GridPoint(x: -36, y: 32))
        XCTAssertEqual(layout.segments.last?.localOrigin, GridPoint(x: 28, y: -40))
        XCTAssertEqual(Set(layout.segments.map(\.elevation)), [-1, 0, 1, 2])
        XCTAssertTrue(layout.segments.allSatisfy { (0...25).contains($0.cutVariant) })
        XCTAssertTrue(layout.phaseRules.allSatisfy {
            $0.firstSegmentIndex == 0 && $0.lastSegmentIndex == 34
        })
        XCTAssertEqual(layout.phaseRules.last?.lastSubBuildingPhase, 11)
    }

    func testAllSegmentsMustReachFinalStageBeforeProjectCompletes() throws {
        let project = fullyFundedProject()
        var wall = EarthenGreatWallProjectRuntime(projectID: project.id)
        let randomOrder = (0..<35).map { ($0 * 17) % 35 }

        for stage in 1...EarthenGreatWallProjectRuntime.finalStage {
            for index in randomOrder {
                XCTAssertTrue(wall.advanceSegment(index: index, project: project))
                XCTAssertEqual(
                    wall.segments.first(where: { $0.index == index })?.stage,
                    stage
                )
            }
            XCTAssertEqual(
                wall.isComplete,
                stage == EarthenGreatWallProjectRuntime.finalStage
            )
        }

        XCTAssertEqual(wall.completionPercent, 100)
        XCTAssertEqual(
            wall.segments.reduce(0) { $0 + $1.deliveredWood },
            project.requiredCommodityUnits[10]
        )
        XCTAssertEqual(
            wall.segments.reduce(0) { $0 + $1.deliveredStone },
            project.requiredCommodityUnits[20]
        )
        XCTAssertEqual(
            wall.segments.reduce(0) { $0 + $1.completedWork },
            project.requiredWork
        )
        let data = try JSONEncoder().encode(wall)
        XCTAssertEqual(
            try JSONDecoder().decode(EarthenGreatWallProjectRuntime.self, from: data),
            wall
        )
    }

    func testFundedMapProjectDoesNotAutoCompleteWithoutSegmentCommands() throws {
        var state = DeterministicAestheticState()
        for (buildingID, kind) in [
            (233, AestheticConstructionKind.laborersCamp),
            (52, .carpentersGuild),
            (235, .masonsGuild),
        ] {
            _ = state.addConstruction(
                buildingID: buildingID,
                kind: kind,
                location: GridPoint(x: buildingID, y: 1)
            )
        }
        let id = try XCTUnwrap(
            state.addMapMonument(buildingID: EarthenGreatWallProjectRuntime.buildingID)
        )
        var logistics = DeterministicLogisticsState()
        var roads = RoadNetwork(width: 8, height: 8)
        _ = roads.insert([GridPoint(x: 1, y: 1)])
        _ = try XCTUnwrap(logistics.addWarehouse(
            roadAccessPoint: GridPoint(x: 1, y: 1),
            roadNetwork: roads
        ))
        var production = DeterministicProductionState()
        XCTAssertEqual(
            logistics.storeCampaignGift(
                commodityID: 10,
                amount: 800,
                production: &production
            ),
            800
        )
        XCTAssertEqual(
            logistics.storeCampaignGift(
                commodityID: 20,
                amount: 1_200,
                production: &production
            ),
            1_200
        )
        for _ in 0..<60 {
            _ = state.advanceMonuments(logistics: &logistics, production: &production)
        }
        let project = try XCTUnwrap(state.monuments.first(where: { $0.id == id }))
        XCTAssertEqual(project.completedWork, project.requiredWork)
        XCTAssertFalse(project.isComplete)
        XCTAssertFalse(state.completedMonumentBuildingIDs.contains(85))

        for stage in 0..<EarthenGreatWallProjectRuntime.finalStage {
            for index in 0..<EarthenGreatWallProjectRuntime.segmentCount {
                XCTAssertEqual(
                    state.advanceEarthenGreatWallSegment(index: index),
                    index
                )
            }
            XCTAssertEqual(
                state.completedMonumentBuildingIDs.contains(85),
                stage == EarthenGreatWallProjectRuntime.finalStage - 1
            )
        }
    }

    private func fullyFundedProject() -> MonumentProject {
        var project = MonumentProject(
            id: 85,
            buildingID: EarthenGreatWallProjectRuntime.buildingID,
            requiredWork: 3_600,
            requiredCommodityUnits: [10: 800, 20: 1_200],
            requiredSupportKinds: [.laborersCamp, .carpentersGuild, .masonsGuild],
            deliveredCommodityUnits: [:],
            completedWork: 0,
            isComplete: false
        )
        project.recordDelivery(commodityID: 10, amount: 800)
        project.recordDelivery(commodityID: 20, amount: 1_200)
        project.performWork(3_600, allowCompletion: false)
        return project
    }
}
