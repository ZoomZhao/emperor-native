import Foundation
import XCTest
@testable import EmperorCore

final class LargePalaceSimulationTests: XCTestCase {
    func testOriginalPalaceSubsParsesAllSubBuildingsAndJoinedPhases() throws {
        let url = GameDataSource.defaultRoot
            .appendingPathComponent("Model/Mon_Palace_subs.txt")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let layout = try XCTUnwrap(
            LargePalaceLayout.parse(
                subBuildingText: String(contentsOf: url, encoding: .utf8)
            )
        )

        XCTAssertEqual(layout.subBuildings.count, 153)
        XCTAssertEqual(
            Dictionary(grouping: layout.subBuildings, by: \.kind).mapValues(\.count),
            [
                .templeSteps: 128,
                .palace: 12,
                .causeway: 3,
                .courtyard: 6,
                .palaceSteps: 4,
            ]
        )
        XCTAssertEqual(
            layout.subBuildings.filter {
                $0.kind == .palaceSteps && $0.isRoadEntrance
            }.map(\.index),
            [85, 87]
        )
        XCTAssertEqual(Set(layout.phaseRules.map(\.monumentPhase)), Set(0...15))
        XCTAssertTrue(layout.phaseRules.filter { (5...13).contains($0.monumentPhase) }.allSatisfy(\.isJoined))
    }

    func testSixteenPhasesConsumeExactMaterialsAndRoundTrip() throws {
        let project = fullyFundedProject()
        var palace = LargePalaceProjectRuntime(
            projectID: project.id,
            origin: GridPoint(x: 20, y: 30),
            orientation: .northSouth
        )

        for phase in 1...LargePalaceProjectRuntime.phaseCount {
            XCTAssertTrue(palace.advance(project: project))
            XCTAssertEqual(palace.completedPhaseCount, phase)
        }

        XCTAssertTrue(palace.isComplete)
        XCTAssertEqual(palace.completedWork, 2_800)
        XCTAssertEqual(palace.deliveredCommodityUnits, [10: 800, 18: 800, 20: 800])
        XCTAssertTrue(palace.contains(GridPoint(x: 31, y: 41)))
        XCTAssertFalse(palace.contains(GridPoint(x: 32, y: 41)))
        let data = try JSONEncoder().encode(palace)
        XCTAssertEqual(
            try JSONDecoder().decode(LargePalaceProjectRuntime.self, from: data),
            palace
        )
    }

    private func fullyFundedProject() -> MonumentProject {
        var project = MonumentProject(
            id: 42,
            buildingID: 82,
            requiredWork: 2_800,
            requiredCommodityUnits: [10: 800, 18: 800, 20: 800],
            requiredSupportKinds: [
                .laborersCamp, .carpentersGuild, .ceramistsGuild, .masonsGuild,
            ],
            deliveredCommodityUnits: [:],
            completedWork: 0,
            isComplete: false
        )
        for commodityID in [10, 18, 20] {
            project.recordDelivery(commodityID: commodityID, amount: 800)
        }
        project.performWork(2_800, allowCompletion: false)
        return project
    }
}
