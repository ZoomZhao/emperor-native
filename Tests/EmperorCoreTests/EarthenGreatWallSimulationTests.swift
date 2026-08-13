import Foundation
import XCTest
@testable import EmperorCore

final class EarthenGreatWallSimulationTests: XCTestCase {
    func testLegacyNativeBindingsRemainStableForSaveCompatibility() throws {
        let bindings = EarthenGreatWallLayout.badalingMapBindings
        XCTAssertEqual(bindings.count, 35)
        XCTAssertEqual(Set(bindings.map(\.segmentIndex)), Set(0..<35))
        XCTAssertEqual(Set(bindings.map(\.worldOrigin)).count, 35)
        XCTAssertEqual(bindings.first?.worldOrigin, GridPoint(x: 71, y: 149))
        XCTAssertEqual(bindings.last?.worldOrigin, GridPoint(x: 55, y: 32))
        XCTAssertEqual(bindings.first?.modeImageID, 225)
        XCTAssertEqual(bindings.last?.modeImageID, 222)
        XCTAssertEqual(
            EarthenGreatWallLayout.original.badalingSegmentIndex(
                containing: GridPoint(x: 72, y: 150)
            ),
            0
        )
        XCTAssertNil(
            EarthenGreatWallLayout.original.badalingSegmentIndex(
                containing: GridPoint(x: 71, y: 141)
            )
        )
    }

    func testLegacyNativeStageSpriteReferencesRemainDecodable() throws {
        let early = OriginalBuildingSpriteCatalog.earthenGreatWallSprites(
            stage: 3,
            modeImageID: 225,
            cutVariant: 25
        )
        XCTAssertEqual(early, [
            BuildingSpriteReference(
                archiveBaseName: "China_Mon_Earthen_Greatwall_3",
                imageID: 225
            ),
            BuildingSpriteReference(
                archiveBaseName: "China_Mon_Tumulus",
                imageID: 507
            ),
        ])
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.earthenGreatWallSprites(
                stage: 11,
                modeImageID: 225,
                cutVariant: 25
            ),
            [BuildingSpriteReference(
                archiveBaseName: "China_Mon_Earthen_Greatwall_10",
                imageID: 225
            )]
        )
    }

    func testStandaloneEarthenWallEditorLayoutStillParses() throws {
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

    func testLegacyNativeProjectPayloadStillRoundTrips() throws {
        let wall = EarthenGreatWallProjectRuntime(projectID: 85)
        let data = try JSONEncoder().encode(wall)
        XCTAssertEqual(
            try JSONDecoder().decode(EarthenGreatWallProjectRuntime.self, from: data),
            wall
        )
    }

    func testNewStateRejectsSyntheticGreatWallProject() {
        var state = DeterministicAestheticState()
        XCTAssertNil(
            state.addMapMonument(
                buildingID: EarthenGreatWallProjectRuntime.buildingID
            )
        )
        XCTAssertNil(state.earthenGreatWallProject)
    }
}
