import Foundation
import XCTest
@testable import EmperorCore

final class GreatWallLayoutCatalogTests: XCTestCase {
    func testExecutableBuildingIDsMapToAuthoredFileNames() {
        XCTAssertEqual(OriginalGreatWallLayoutCatalog.buildingIDs, Array(253...268))
        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.fileName(forBuildingID: 253),
            "Mon_Great_Wall_01_subs.txt"
        )
        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.fileName(forBuildingID: 268),
            "Mon_Great_Wall_16_subs.txt"
        )
        XCTAssertNil(OriginalGreatWallLayoutCatalog.fileName(forBuildingID: 85))
    }

    func testAllOriginalLayoutsParseTheirAuthoredGeometry() throws {
        let expectedCounts = [
            50, 51, 39, 53, 53, 51, 51, 49,
            53, 53, 53, 53, 53, 53, 53, 53,
        ]
        let modelRoot = GameDataSource.defaultRoot.appendingPathComponent("Model")
        guard FileManager.default.fileExists(
            atPath: modelRoot.appendingPathComponent("Mon_Great_Wall_01_subs.txt").path
        ) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }

        for (offset, buildingID) in OriginalGreatWallLayoutCatalog.buildingIDs.enumerated() {
            let layout = try XCTUnwrap(
                OriginalGreatWallLayoutCatalog.layout(buildingID: buildingID),
                "building ID \(buildingID)"
            )
            XCTAssertEqual(layout.subBuildings.count, expectedCounts[offset])
            XCTAssertEqual(layout.subBuildings.map(\.index), Array(0..<expectedCounts[offset]))
            XCTAssertEqual(Set(layout.phaseRules.map(\.monumentPhase)), Set(0..<9))
            XCTAssertEqual(layout.subBuildings.filter { $0.kind == "SB_GREAT_WALL_GATE" }.count, 4)
            XCTAssertEqual(layout.subBuildings.filter { $0.kind == "SB_GREAT_WALL_ROAD" }.count, 4)
        }
    }

    func testTaskSelectsAuthoredWallMaterialFamily() {
        XCTAssertEqual(OriginalGreatWallLayoutCatalog.wallKind(forTaskBuildingID: 85), .earthen)
        XCTAssertEqual(OriginalGreatWallLayoutCatalog.wallKind(forTaskBuildingID: 86), .stone)
        XCTAssertNil(OriginalGreatWallLayoutCatalog.wallKind(forTaskBuildingID: 253))
    }

    func testBadalingTerminalSpritesFollowRecoveredPartVtables() throws {
        let layout = try XCTUnwrap(
            OriginalGreatWallLayoutCatalog.layout(buildingID: 257)
        )
        let wall = try XCTUnwrap(layout.subBuildings.first {
            $0.kind == "SB_GREAT_WALL" && $0.variant == "24"
        })
        let tower = try XCTUnwrap(layout.subBuildings.first {
            $0.kind == "SB_GREAT_WALL_TOWER" && $0.variant == "27"
        })
        let gates = layout.subBuildings.filter { $0.kind == "SB_GREAT_WALL_GATE" }
        let road = try XCTUnwrap(layout.subBuildings.first {
            $0.kind == "SB_GREAT_WALL_ROAD"
        })

        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.terminalSpriteReference(
                for: wall,
                wallKind: .earthen
            ),
            .init(archiveBaseName: "China_Mon_Earthen_Greatwall_10", imageID: 225)
        )
        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.terminalSpriteReference(
                for: tower,
                wallKind: .stone
            ),
            .init(archiveBaseName: "China_Mon_Greatwall_10", imageID: 228)
        )
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: gates.map {
                ($0.variant, OriginalGreatWallLayoutCatalog.terminalSpriteReference(
                    for: $0,
                    wallKind: .earthen
                )?.imageID)
            }),
            ["NW": 232, "NE": 229, "SW": 231, "SE": 230]
        )
        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.terminalSpriteReference(
                for: road,
                wallKind: .earthen
            )?.imageID,
            241
        )
    }

    func testBadalingArchivedPartsResolveFiftyThreeTerminalSprites() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Badaling.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        let layout = try XCTUnwrap(
            OriginalGreatWallLayoutCatalog.layout(buildingID: 257)
        )
        let references = map.greatWallPartStates.compactMap { part ->
            OriginalGreatWallLayoutCatalog.SpriteReference? in
            guard layout.subBuildings.indices.contains(part.subBuildingIndex),
                  OriginalGreatWallLayoutCatalog.isTerminal(part, layout: layout)
            else { return nil }
            return OriginalGreatWallLayoutCatalog.terminalSpriteReference(
                for: layout.subBuildings[part.subBuildingIndex],
                wallKind: .earthen
            )
        }
        XCTAssertEqual(references.count, 53)
        XCTAssertEqual(Set(references.map(\.archiveBaseName)), [
            "China_Mon_Earthen_Greatwall_10",
        ])
        XCTAssertTrue(Set(references.map(\.imageID)).isSubset(of: Set(201...242)))
    }

    func testGreatWallUsesRecoveredOneTwoAndFourCellRoadAccessRows() {
        XCTAssertEqual(
            OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(footprintSide: 1),
            [
                .init(x: 0, y: -1), .init(x: 1, y: 0),
                .init(x: 0, y: 1), .init(x: -1, y: 0),
            ]
        )
        XCTAssertEqual(
            OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(footprintSide: 2),
            [
                .init(x: 0, y: -1), .init(x: 1, y: -1),
                .init(x: 2, y: 0), .init(x: 2, y: 1),
                .init(x: 1, y: 2), .init(x: 0, y: 2),
                .init(x: -1, y: 1), .init(x: -1, y: 0),
            ]
        )
        XCTAssertEqual(
            OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(footprintSide: 4),
            OriginalGrandCanalLayoutCatalog.phaseTwoFourByFourRoadAccessOffsets
        )
        XCTAssertEqual(OriginalGreatWallLayoutCatalog.SubBuildingKind.wall.footprintSide, 4)
        XCTAssertEqual(OriginalGreatWallLayoutCatalog.SubBuildingKind.tower.footprintSide, 4)
        XCTAssertEqual(OriginalGreatWallLayoutCatalog.SubBuildingKind.gate.footprintSide, 2)
        XCTAssertEqual(OriginalGreatWallLayoutCatalog.SubBuildingKind.road.footprintSide, 1)
    }

    func testRoutingCatalogPreservesRecoveredThreeFiveAndSixCellRows() {
        XCTAssertEqual(
            OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(footprintSide: 3),
            [
                .init(x: 0, y: -1), .init(x: 1, y: -1), .init(x: 2, y: -1),
                .init(x: 3, y: 0), .init(x: 3, y: 1), .init(x: 3, y: 2),
                .init(x: 2, y: 3), .init(x: 1, y: 3), .init(x: 0, y: 3),
                .init(x: -1, y: 2), .init(x: -1, y: 1), .init(x: -1, y: 0),
            ]
        )
        XCTAssertEqual(
            OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(footprintSide: 5),
            [
                .init(x: 0, y: -1), .init(x: 1, y: -1), .init(x: 2, y: -1),
                .init(x: 3, y: -1), .init(x: 4, y: -1), .init(x: 5, y: 0),
                .init(x: 5, y: 1), .init(x: 5, y: 2), .init(x: 5, y: 3),
                .init(x: 5, y: 4), .init(x: 4, y: 5), .init(x: 3, y: 5),
                .init(x: 2, y: 5), .init(x: 1, y: 5), .init(x: 0, y: 5),
                .init(x: -1, y: 4), .init(x: -1, y: 3), .init(x: -1, y: 2),
                .init(x: -1, y: 1), .init(x: -1, y: 0),
            ]
        )
        XCTAssertEqual(
            OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(footprintSide: 6),
            [
                .init(x: 0, y: -1), .init(x: 1, y: -1), .init(x: 2, y: -1),
                .init(x: 3, y: -1), .init(x: 4, y: -1), .init(x: 5, y: -1),
                .init(x: 6, y: 0), .init(x: 6, y: 1), .init(x: 6, y: 2),
                .init(x: 6, y: 3), .init(x: 6, y: 4), .init(x: 6, y: 5),
                .init(x: 5, y: 6), .init(x: 4, y: 6), .init(x: 3, y: 6),
                .init(x: 2, y: 6), .init(x: 1, y: 6), .init(x: 0, y: 6),
                .init(x: -1, y: 5), .init(x: -1, y: 4), .init(x: -1, y: 3),
                .init(x: -1, y: 2), .init(x: -1, y: 1), .init(x: -1, y: 0),
            ]
        )
        for side in 3...6 {
            let offsets = OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(
                footprintSide: side
            )
            XCTAssertEqual(offsets.first, .init(x: 0, y: -1))
            XCTAssertEqual(offsets.last, .init(x: -1, y: 0))
            XCTAssertEqual(offsets.count, side * 4)
        }
    }

    func testGreatWallRoutingCacheValuesFollowRecoveredPartPredicates() throws {
        typealias Input = OriginalGrandCanalLayoutCatalog.WorkerRoutingCellInput
        typealias Occupancy = OriginalGrandCanalLayoutCatalog.WorkerRoutingCellOccupancy
        let point = GridPoint(x: 55, y: 32)
        func values(
            currentPhase: Int,
            rootPhase: Int,
            kind: OriginalGreatWallLayoutCatalog.SubBuildingKind
        ) throws -> OriginalGrandCanalLayoutCatalog.WorkerRoutingCellValues {
            try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(from: Input(
                point: point,
                terrainRawValue: 0x8008,
                occupancy: Occupancy(
                    buildingID: 257,
                    currentMonumentSubBuildingPhase: currentPhase,
                    greatWallRootSubBuildingPhase: rootPhase,
                    greatWallPartKind: kind,
                    genericFootprintPredicate: false
                ),
                primarySurfaceObjectIsAbsentOrNonblocking: true
            ))
        }

        XCTAssertEqual(try values(currentPhase: 0, rootPhase: 0, kind: .wall),
                       .init(primaryPassability: 0x20, fallbackCellClass: 0x2))
        XCTAssertEqual(try values(currentPhase: 1, rootPhase: 1, kind: .wall),
                       .init(primaryPassability: 0x2, fallbackCellClass: 0x4C000800))
        XCTAssertEqual(try values(currentPhase: 1, rootPhase: 1, kind: .tower),
                       .init(primaryPassability: 0x2, fallbackCellClass: 0x4C000800))
        XCTAssertEqual(try values(currentPhase: 1, rootPhase: 1, kind: .gate),
                       .init(primaryPassability: 0x2, fallbackCellClass: 0x48000400))
        XCTAssertEqual(try values(currentPhase: 2, rootPhase: 1, kind: .road),
                       .init(primaryPassability: 0x2, fallbackCellClass: 0x2))
    }

    func testRecoveredPartPhaseRequirementsUseOriginalResourcesAndWorkers() throws {
        let layout = try XCTUnwrap(
            OriginalGreatWallLayoutCatalog.layout(buildingID: 257)
        )
        let wall = try XCTUnwrap(layout.subBuildings.first { $0.kind == "SB_GREAT_WALL" })
        let tower = try XCTUnwrap(
            layout.subBuildings.first { $0.kind == "SB_GREAT_WALL_TOWER" }
        )
        let owningGate = try XCTUnwrap(
            layout.subBuildings.first {
                $0.kind == "SB_GREAT_WALL_GATE" && $0.variant == "NW"
            }
        )
        let otherGate = try XCTUnwrap(
            layout.subBuildings.first {
                $0.kind == "SB_GREAT_WALL_GATE" && $0.variant == "NE"
            }
        )

        let earthenWall = OriginalGreatWallLayoutCatalog.phaseRequirements(
            for: wall,
            wallKind: .earthen
        )
        XCTAssertEqual(earthenWall.map(\.phase), Array(0...8))
        XCTAssertEqual(earthenWall[0].kind, .commodity(id: 10))
        XCTAssertEqual(earthenWall[0].workerFigureID, 80)
        XCTAssertEqual(earthenWall[1].kind, .internalWorkTask(id: 100))
        XCTAssertEqual(earthenWall[1].workerFigureID, 10)
        XCTAssertEqual(earthenWall[2].kind, .internalWorkTask(id: 101))
        XCTAssertTrue(earthenWall.allSatisfy { $0.amount == 200 })

        let stoneTower = OriginalGreatWallLayoutCatalog.phaseRequirements(
            for: tower,
            wallKind: .stone
        )
        XCTAssertEqual(stoneTower.map(\.phase), Array(0...10))
        XCTAssertEqual(stoneTower[9].kind, .commodity(id: 20))
        XCTAssertEqual(stoneTower[10].kind, .commodity(id: 20))
        XCTAssertEqual(stoneTower[10].workerFigureID, 82)

        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.phaseRequirements(
                for: owningGate,
                wallKind: .earthen
            ).first?.kind,
            .internalWorkTask(id: 100)
        )
        XCTAssertTrue(
            OriginalGreatWallLayoutCatalog.phaseRequirements(
                for: otherGate,
                wallKind: .earthen
            ).isEmpty
        )
    }

    func testBadalingRequirementTotalsMatchRecoveredPartFunctions() throws {
        let layout = try XCTUnwrap(
            OriginalGreatWallLayoutCatalog.layout(buildingID: 257)
        )
        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.requirementTotals(
                layout: layout,
                wallKind: .earthen
            ),
            .init(
                commodityUnitsByID: [10: 27_000],
                internalWorkUnitsByTaskID: [100: 27_700, 101: 27_000]
            )
        )
        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.requirementTotals(
                layout: layout,
                wallKind: .stone
            ),
            .init(
                commodityUnitsByID: [20: 37_400],
                internalWorkUnitsByTaskID: [100: 27_000, 101: 27_000]
            )
        )
    }

    func testBadalingMapMatchesTheCompleteAuthoredLayout() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Badaling.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let placement = try XCTUnwrap(
            OriginalGreatWallLayoutCatalog.campaignPlacement(
                in: EmperorMap(url: mapURL)
            )
        )
        XCTAssertEqual(placement.buildingID, 257)
        XCTAssertEqual(placement.origin, GridPoint(x: 55, y: 32))
        XCTAssertEqual(placement.quarterTurnsClockwise, 0)

        let placedSubBuildings = try XCTUnwrap(
            OriginalGreatWallLayoutCatalog.placedSubBuildings(for: placement)
        )
        XCTAssertEqual(placedSubBuildings.map(\.index), Array(0..<53))
        XCTAssertEqual(placedSubBuildings.filter { $0.kind == "SB_GREAT_WALL" }.count, 39)
        XCTAssertEqual(placedSubBuildings.filter { $0.kind == "SB_GREAT_WALL_TOWER" }.count, 6)
        XCTAssertEqual(placedSubBuildings.filter { $0.kind == "SB_GREAT_WALL_GATE" }.count, 4)
        XCTAssertEqual(placedSubBuildings.filter { $0.kind == "SB_GREAT_WALL_ROAD" }.count, 4)
        XCTAssertEqual(placedSubBuildings.first?.worldOrigin, GridPoint(x: 55, y: 32))
        XCTAssertEqual(placedSubBuildings.last?.worldOrigin, GridPoint(x: 46, y: 74))
        XCTAssertEqual(
            Set(placedSubBuildings.flatMap(\.footprintCells)).count,
            740
        )

        let terrain = DeterministicTerrainState(map: try EmperorMap(url: mapURL))
        XCTAssertEqual(terrain.greatWallPlacement, placement)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicTerrainState.self,
                from: JSONEncoder().encode(terrain)
            ).greatWallPlacement,
            placement
        )

        let layout = try XCTUnwrap(
            OriginalGreatWallLayoutCatalog.layout(buildingID: placement.buildingID)
        )
        XCTAssertEqual(
            OriginalGreatWallLayoutCatalog.footprintCells(
                layout: layout,
                quarterTurnsClockwise: placement.quarterTurnsClockwise
            ).count,
            740
        )

        let map = try EmperorMap(url: mapURL)
        let archived = map.greatWallPartStates
        XCTAssertEqual(archived.count, 53)
        XCTAssertEqual(archived.map(\.buildingID), Array(repeating: 257, count: 53))
        XCTAssertEqual(archived.map(\.subBuildingIndex), Array(0..<53))
        XCTAssertEqual(Set(archived.map(\.baseBuildingSchema)), [4])
        XCTAssertEqual(Set(archived.map(\.monumentWrapperSchema)), [1])
        XCTAssertEqual(Set(archived.map(\.monumentStateSchema)), [10])
        XCTAssertEqual(Set(archived.map(\.wholeMonumentPhase)), [8])
        XCTAssertEqual(Set(archived.map(\.onSiteLaborerWorkUpdates)), [0])
        XCTAssertEqual(Set(archived.map(\.deliveredWoodUnits)), [0])
        XCTAssertEqual(Set(archived.map(\.completedInternalWorkUnits)), [0])
        XCTAssertEqual(Set(archived.map(\.deliveredStoneUnits)), [0])
        XCTAssertEqual(archived.map(\.worldOrigin), placedSubBuildings.map(\.worldOrigin))
        XCTAssertTrue(zip(archived, layout.subBuildings).allSatisfy { state, part in
            state.currentSubBuildingPhase
                == OriginalGreatWallLayoutCatalog.authoredTerminalSubBuildingPhase(
                    index: part.index,
                    layout: layout
                )
        })
    }

    func testNativeCitySavePreservesOriginalPerPartGreatWallState() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Badaling.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        let city = DeterministicCityState(year: -215, treasury: 18_000, map: map)
        XCTAssertEqual(city.aesthetics.greatWallMapPartStates, map.greatWallPartStates)

        let restored = try NativeSaveGameStore.decoded(
            NativeSaveGameStore.encoded(NativeSaveGame(replaySeed: 257, city: city))
        )
        XCTAssertEqual(
            restored.city.aesthetics.greatWallMapPartStates,
            map.greatWallPartStates
        )
        XCTAssertNil(restored.city.aesthetics.earthenGreatWallProject)
    }

    func testBadalingRebuildsGreatWallRoutingAndMultipartAccesses() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Badaling.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        let city = DeterministicCityState(year: -215, treasury: 18_000, map: map)
        let grids = try city.grandCanalWorkerRoutingGrids()
        let accesses = try city.greatWallTargetAccesses(routingGrids: grids)

        XCTAssertEqual(grids.width, map.width)
        XCTAssertEqual(grids.height, map.height)
        XCTAssertEqual(accesses.count, 8)
        XCTAssertEqual(accesses.map(\.subBuildingIndex), [13, 14, 15, 16, 49, 50, 51, 52])
        XCTAssertTrue(accesses.allSatisfy { map.greatWallPartStates.indices.contains($0.subBuildingIndex) })
        XCTAssertEqual(Set(accesses.map(\.subBuildingIndex)).count, accesses.count)
    }

    func testOrdinaryCampaignMapDoesNotProduceFalseGreatWallPlacement() throws {
        let mapURL = GameDataSource.defaultRoot.appendingPathComponent("Cities/Erlitou.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        XCTAssertNil(
            OriginalGreatWallLayoutCatalog.campaignPlacement(
                in: try EmperorMap(url: mapURL)
            )
        )
        XCTAssertTrue(try EmperorMap(url: mapURL).greatWallPartStates.isEmpty)
    }

    func testUnrelatedMonumentClassNamesDoNotProduceFalseGreatWallArchives() throws {
        let source = try GameDataSource.openDefault()
        for mapName in ["Banpo.map", "Zhengzhou.map", "Liangzhou.map"] {
            let mapURL = source.citiesDirectory.appendingPathComponent(mapName)
            guard FileManager.default.fileExists(atPath: mapURL.path) else { continue }
            XCTAssertTrue(
                try EmperorMap(url: mapURL).greatWallPartStates.isEmpty,
                mapName
            )
        }
    }

    func testCommodityDeliveryUsesCurrentPartRequirementAndRetainsExcessCargo() {
        var state = GreatWallMapPartState(
            worldOrigin: GridPoint(x: 55, y: 32),
            mapCellIndex: 13_992,
            buildingID: 257,
            subBuildingIndex: 0,
            baseBuildingSchema: 4,
            monumentWrapperSchema: 1,
            monumentStateSchema: 10,
            currentSubBuildingPhase: 0,
            wholeMonumentPhase: 0,
            deliveredWoodUnits: 170
        )
        let requirement = OriginalGreatWallLayoutCatalog.PhaseRequirement(
            subBuildingIndex: 0,
            phase: 0,
            kind: .commodity(id: 10),
            amount: 200,
            workerFigureID: 80
        )

        XCTAssertEqual(state.acceptCommodityCargo(80, for: requirement), 50)
        XCTAssertEqual(state.deliveredWoodUnits, 200)
        XCTAssertEqual(state.deliveredStoneUnits, 0)
        XCTAssertEqual(state.acceptCommodityCargo(25, for: requirement), 25)

        let wrongPhase = OriginalGreatWallLayoutCatalog.PhaseRequirement(
            subBuildingIndex: 0,
            phase: 3,
            kind: .commodity(id: 10),
            amount: 200,
            workerFigureID: 80
        )
        XCTAssertEqual(state.acceptCommodityCargo(25, for: wrongPhase), 25)
        XCTAssertEqual(state.deliveredWoodUnits, 200)
    }

    func testOlderNativeGreatWallPartRecordDefaultsNewCountersToZero() throws {
        let json = #"""
        {
          "worldOrigin":{"x":55,"y":32},
          "mapCellIndex":13992,
          "buildingID":257,
          "subBuildingIndex":0,
          "baseBuildingSchema":4,
          "monumentWrapperSchema":1,
          "monumentStateSchema":10,
          "currentSubBuildingPhase":10,
          "wholeMonumentPhase":8
        }
        """#.data(using: .utf8)!
        let state = try JSONDecoder().decode(GreatWallMapPartState.self, from: json)
        XCTAssertEqual(state.onSiteLaborerWorkUpdates, 0)
        XCTAssertEqual(state.deliveredWoodUnits, 0)
        XCTAssertEqual(state.completedInternalWorkUnits, 0)
        XCTAssertEqual(state.deliveredStoneUnits, 0)
    }

}
