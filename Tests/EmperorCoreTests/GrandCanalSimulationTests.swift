import Foundation
import XCTest
@testable import EmperorCore

final class GrandCanalSimulationTests: XCTestCase {
    func testOriginalSubsFileParsesAllIndependentSegmentsAndPhases() throws {
        let sourceURL = GameDataSource.defaultRoot
            .appendingPathComponent("Model/Mon_Grand_Canal_subs.txt")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let text = try String(contentsOf: sourceURL, encoding: .utf8)
        let layout = try XCTUnwrap(GrandCanalLayout.parse(subBuildingText: text))

        XCTAssertEqual(layout.segments.count, 33)
        XCTAssertEqual(
            layout.segments.filter(\.isRoadCrossing).map(\.index),
            [10, 16, 22]
        )
        XCTAssertEqual(layout.segments.first?.localOrigin, GridPoint(x: 0, y: 0))
        XCTAssertEqual(layout.segments.last?.localOrigin, GridPoint(x: 128, y: 0))
        XCTAssertEqual(layout.phaseRules.count, 5)
        XCTAssertTrue(layout.phaseRules.allSatisfy {
            $0.firstSegmentIndex == 0 && $0.lastSegmentIndex == 32
        })
    }

    func testRandomSegmentOrderRequiresAllThirtyThreeSegments() throws {
        let project = fullyFundedProject()
        var canal = GrandCanalProjectRuntime(projectID: project.id)
        let randomOrder = (0..<33).map { ($0 * 17) % 33 }

        for stage in 1...GrandCanalProjectRuntime.finalStage {
            for index in randomOrder {
                XCTAssertTrue(canal.advanceSegment(index: index, project: project))
                XCTAssertEqual(
                    canal.segments.first(where: { $0.index == index })?.stage,
                    stage
                )
            }
        }

        XCTAssertTrue(canal.isComplete)
        XCTAssertEqual(canal.completionPercent, 100)
        XCTAssertEqual(
            canal.segments.reduce(0) { $0 + $1.deliveredWood },
            project.requiredCommodityUnits[10]
        )
        XCTAssertEqual(
            canal.segments.reduce(0) { $0 + $1.deliveredStone },
            project.requiredCommodityUnits[20]
        )
        XCTAssertEqual(
            canal.segments.reduce(0) { $0 + $1.completedWork },
            project.requiredWork
        )
    }

    func testOnlyClickedSegmentChangesAndSaveRoundTripPreservesIt() throws {
        let project = fullyFundedProject()
        var canal = GrandCanalProjectRuntime(projectID: project.id)
        XCTAssertTrue(canal.advanceSegment(index: 16, project: project))

        XCTAssertEqual(canal.segments.first(where: { $0.index == 16 })?.stage, 1)
        XCTAssertTrue(canal.segments.filter { $0.index != 16 }.allSatisfy { $0.stage == 0 })
        XCTAssertEqual(canal.segmentIndex(containing: GridPoint(x: 68, y: 69)), 16)
        XCTAssertTrue(canal.isRoadCrossing(segment: 16))

        let data = try JSONEncoder().encode(canal)
        let decoded = try JSONDecoder().decode(GrandCanalProjectRuntime.self, from: data)
        XCTAssertEqual(decoded, canal)
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.grandCanalSprite(
                stage: GrandCanalProjectRuntime.finalStage,
                isRoadCrossing: true
            )?.imageID,
            238
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.grandCanalSprite(
                stage: GrandCanalProjectRuntime.finalStage,
                isRoadCrossing: false
            )?.imageID,
            232
        )
    }

    private func fullyFundedProject() -> MonumentProject {
        var project = MonumentProject(
            id: 7,
            buildingID: GrandCanalProjectRuntime.buildingID,
            requiredWork: 2_400,
            requiredCommodityUnits: [10: 600, 20: 800],
            requiredSupportKinds: [.laborersCamp, .carpentersGuild, .masonsGuild],
            deliveredCommodityUnits: [:],
            completedWork: 0,
            isComplete: false
        )
        project.recordDelivery(commodityID: 10, amount: 600)
        project.recordDelivery(commodityID: 20, amount: 800)
        project.performWork(2_400, allowCompletion: false)
        return project
    }
}
