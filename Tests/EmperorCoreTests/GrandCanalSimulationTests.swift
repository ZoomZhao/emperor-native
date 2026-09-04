import Foundation
import XCTest
@testable import EmperorCore

final class GrandCanalSimulationTests: XCTestCase {
    func testRecoveredBuildingFootprintPredicatesAreExplicitAndFailClosed() {
        typealias Catalog = OriginalGrandCanalLayoutCatalog.BuildingFootprintPredicateCatalog
        XCTAssertEqual(
            Catalog.constantFalseBuildingIDs,
            Set(3...17).union([
                27, 28, 29, 31, 33, 35, 36, 37, 43, 46, 48, 53, 54, 56, 58,
                59, 60, 71, 72, 73, 116, 117, 124, 125, 126, 192, 193, 207, 208,
                194, 195, 196, 197, 198, 199, 211, 214, 215, 216, 217, 218, 219,
                233, 237, 238, 239, 243,
                244, 245, 246, 247, 248
            ])
        )
        for buildingID in Catalog.constantFalseBuildingIDs {
            XCTAssertEqual(
                Catalog.genericFootprintPredicate(forBuildingID: buildingID),
                false,
                "confirmed +0xCC predicate should be false for building \(buildingID)"
            )
        }
        XCTAssertNil(Catalog.genericFootprintPredicate(forBuildingID: 203))
        XCTAssertEqual(Catalog.genericFootprintPredicate(forBuildingID: 126), false)
    }

    func testRoutingBuildersUseRecoveredFootprintCatalogWhenCellOmitsPredicate() throws {
        // Warehouse 54 is one of the classes whose live-object `+0xCC`
        // callback is directly recovered as constant false.  A caller that
        // has only the authored building ID must therefore get the same
        // source-backed result as a caller that supplied `false` explicitly.
        let omitted = try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
            from: .init(
                point: GridPoint(x: 2, y: 3),
                terrainRawValue: 0x8008,
                occupancy: .init(buildingID: 54)
            )
        )
        let explicit = try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
            from: .init(
                point: GridPoint(x: 2, y: 3),
                terrainRawValue: 0x8008,
                occupancy: .init(buildingID: 54, genericFootprintPredicate: false)
            )
        )
        XCTAssertEqual(omitted, explicit)
        XCTAssertEqual(omitted.primaryPassability, 0x2)
        XCTAssertEqual(omitted.fallbackCellClass, 0x4)

        XCTAssertThrowsError(
            try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
                from: .init(
                    point: GridPoint(x: 2, y: 3),
                    terrainRawValue: 0x8008,
                    occupancy: .init(buildingID: 130)
                )
            )
        ) { error in
            guard case OriginalGrandCanalLayoutCatalog.WorkerRoutingCacheDerivationError
                .missingGenericFootprintPredicate = error else {
                XCTFail("expected unknown +0xCC predicate to remain fail-closed, got \(error)")
                return
            }
        }
    }

    func testRecoveredRoutingModelPredicatesKeepModelAndBuildingDomainsSeparate() {
        let primary = OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
            .primaryOccupiedModelIDs
        XCTAssertEqual(primary, Set([0xDC, 0xDD, 0xDF, 0xE0, 0xE1]))
        XCTAssertTrue(primary.allSatisfy {
            OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
                .isPrimaryOccupiedModel($0)
        })
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
                .isPrimaryOccupiedModel(0xDE)
        )

        let secondary = OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
            .secondaryModelFamilyIDs
        XCTAssertEqual(
            secondary,
            Set([0x1A, 0x1B, 0x1C, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7])
        )
        XCTAssertTrue(
            OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
                .isSecondaryModelFamily(0xC7)
        )
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
                .isSecondaryModelFamily(0xC1)
        )

        let special = OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
            .postSecondaryModelIDs
        XCTAssertEqual(
            special,
            Set(0x4C...0x56).union([0x5C, 0x5D]).union(0xFD...0x10C)
        )
        XCTAssertTrue(
            OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
                .isPostSecondaryModel(0xFD)
        )
        XCTAssertTrue(
            OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
                .isPostSecondaryModel(0x10C)
        )
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog
                .isPostSecondaryModel(0x57)
        )
    }

    func testOriginalSubsFileParsesAllIndependentSegmentsAndFivePhases() throws {
        let sourceURL = GameDataSource.defaultRoot
            .appendingPathComponent("Model/Mon_Grand_Canal_subs.txt")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let text = try String(contentsOf: sourceURL, encoding: .utf8)
        let layout = try XCTUnwrap(GrandCanalLayout.parse(subBuildingText: text))

        XCTAssertEqual(layout, .original)
        XCTAssertEqual(layout.segments.count, 33)
        XCTAssertEqual(
            layout.segments.filter(\.isRoadCrossing).map(\.index),
            [10, 16, 22]
        )
        XCTAssertEqual(layout.segments.first?.localOrigin, GridPoint(x: 0, y: 0))
        XCTAssertEqual(layout.segments.last?.localOrigin, GridPoint(x: 128, y: 0))
        XCTAssertEqual(layout.phaseRules.map(\.monumentPhase), Array(0..<5))
        for (phase, rule) in layout.phaseRules.enumerated() {
            XCTAssertEqual(rule.firstSegmentIndex, 0)
            XCTAssertEqual(rule.lastSegmentIndex, 32)
            XCTAssertEqual(rule.firstSubBuildingPhase, phase)
            XCTAssertEqual(rule.lastSubBuildingPhase, phase + 1)
        }
    }

    func testHaunxianRestoresAllArchivedPerPartMonumentPhases() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        let states = map.grandCanalPartStates

        XCTAssertEqual(states.count, 33)
        XCTAssertEqual(states.map(\.subBuildingIndex), Array(0..<33))
        XCTAssertEqual(states.map(\.buildingID), Array(repeating: 83, count: 33))
        XCTAssertEqual(
            states.map(\.worldOrigin),
            (0..<33).map { GridPoint(x: 4 + $0 * 4, y: 68) }
        )
        XCTAssertEqual(
            states.map(\.mapCellIndex),
            (0..<33).map { map.startOffset + 68 * EmperorMap.gridSide + 4 + $0 * 4 }
        )
        XCTAssertEqual(states.map(\.baseBuildingSchema), Array(repeating: 4, count: 33))
        XCTAssertEqual(states.map(\.monumentWrapperSchema), Array(repeating: 1, count: 33))
        XCTAssertEqual(states.map(\.monumentStateSchema), Array(repeating: 9, count: 33))
        XCTAssertEqual(states.map(\.currentSubBuildingPhase), Array(repeating: 4, count: 33))
        XCTAssertEqual(states.map(\.wholeMonumentPhase), Array(repeating: 4, count: 33))
        XCTAssertEqual(states.map(\.onSiteLaborerWorkUpdates), Array(repeating: 0, count: 33))
        XCTAssertEqual(states.map(\.deliveredStoneUnits), Array(repeating: 0, count: 33))

        XCTAssertEqual(
            map.terrainVisualVariationValues,
            map.legacyByteGrids[5]
        )
        for state in states {
            XCTAssertNotNil(map.terrainVisualVariationValue(
                x: state.worldOrigin.x,
                y: state.worldOrigin.y
            ))
        }
    }

    func testHaunxianPhaseFourUsesOneExactBodyAndCrossingOverlayPerPart() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        let crossingIndexes = Set(GrandCanalLayout.original.segments
            .filter(\.isRoadCrossing).map(\.index))

        for state in map.grandCanalPartStates {
            let crossing = crossingIndexes.contains(state.subBuildingIndex)
            let body = try XCTUnwrap(
                OriginalBuildingSpriteCatalog.grandCanalMapPartBodySprite(
                    currentPhase: state.currentSubBuildingPhase,
                    firstNeighborPhase: 4,
                    secondNeighborPhase: 4,
                    isRoadCrossing: crossing,
                    terrainVariation: map.terrainVisualVariationValue(
                        x: state.worldOrigin.x,
                        y: state.worldOrigin.y
                    ) ?? 0
                )
            )
            XCTAssertEqual(body.archiveBaseName, "China_Mon_Grand_Canal")
            XCTAssertEqual(body.imageID, crossing ? 232 : 233)
            if crossing {
                XCTAssertEqual(
                    OriginalBuildingSpriteCatalog
                        .grandCanalRoadCrossingOverlaySprite(currentPhase: 4)?.imageID,
                    240
                )
                let offset = try XCTUnwrap(
                    OriginalBuildingSpriteCatalog
                        .grandCanalRoadCrossingOverlayTopLeftOffset(currentPhase: 4)
                )
                XCTAssertEqual(offset.x, 56)
                XCTAssertEqual(offset.y, -86)
            }
        }
    }

    func testGrandCanalConstructionBodyJumpTableVariants() throws {
        func image(
            phase: Int,
            first: Int,
            second: Int,
            crossing: Bool,
            variation: UInt8 = 0
        ) -> Int? {
            OriginalBuildingSpriteCatalog.grandCanalMapPartBodySprite(
                currentPhase: phase,
                firstNeighborPhase: first,
                secondNeighborPhase: second,
                isRoadCrossing: crossing,
                terrainVariation: variation
            )?.imageID
        }

        XCTAssertEqual(image(phase: 1, first: 1, second: 1, crossing: false), 208)
        XCTAssertEqual(image(phase: 1, first: 1, second: 1, crossing: false, variation: 1), 209)
        XCTAssertEqual(image(phase: 1, first: 1, second: 1, crossing: true), 205)
        XCTAssertEqual(image(phase: 2, first: 2, second: 2, crossing: false), 219)
        XCTAssertEqual(image(phase: 2, first: 2, second: 2, crossing: true), 216)
        XCTAssertEqual(image(phase: 3, first: 3, second: 3, crossing: false), 229)
        XCTAssertEqual(image(phase: 3, first: 3, second: 3, crossing: true), 228)
        XCTAssertEqual(image(phase: 4, first: 4, second: 4, crossing: false), 233)
        XCTAssertEqual(image(phase: 4, first: 4, second: 4, crossing: true), 232)
        XCTAssertEqual(image(phase: 5, first: 5, second: 5, crossing: false), 233)
        XCTAssertNil(image(phase: 0, first: 0, second: 0, crossing: false))

        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.grandCanalPhaseZeroTerrainImageID(
                isRoadCrossing: false,
                isCrossingRoadCell: false,
                terrainVariation: 8
            ),
            247
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.grandCanalPhaseZeroTerrainImageID(
                isRoadCrossing: true,
                isCrossingRoadCell: false,
                terrainVariation: 8
            ),
            255
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.grandCanalPhaseZeroTerrainImageID(
                isRoadCrossing: true,
                isCrossingRoadCell: true,
                terrainVariation: 8
            ),
            782
        )
    }

    func testMapWithoutGrandCanalHasNoArchivedCanalState() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Erlitou.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        XCTAssertTrue(try EmperorMap(url: mapURL).grandCanalPartStates.isEmpty)
    }

    func testOtherArchivedCanalSchemaIsNotDecodedWithSchemaNineOffsets() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Yangzhou.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        XCTAssertTrue(try EmperorMap(url: mapURL).grandCanalPartStates.isEmpty)
    }

    func testNativeCitySavePreservesOriginalPerPartCanalState() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        let city = DeterministicCityState(year: -246, treasury: 15_000, map: map)

        XCTAssertEqual(city.aesthetics.grandCanalMapPartStates, map.grandCanalPartStates)
        let save = NativeSaveGame(replaySeed: 83, city: city)
        let restored = try NativeSaveGameStore.decoded(
            NativeSaveGameStore.encoded(save)
        )
        XCTAssertEqual(
            restored.city.aesthetics.grandCanalMapPartStates,
            map.grandCanalPartStates
        )
        XCTAssertNil(restored.city.aesthetics.grandCanalProject)
    }

    func testHaunxianCanalFootprintDerivesOriginalTwoRoutingCaches() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        var occupancy: [GridPoint: GrandCanalMapPartState] = [:]
        for state in map.grandCanalPartStates {
            for point in BuildingFootprint(width: 4, height: 4).points(at: state.worldOrigin) {
                XCTAssertNil(occupancy.updateValue(state, forKey: point))
            }
        }
        XCTAssertEqual(occupancy.count, 528)

        var primary: [UInt16: Int] = [:]
        var fallback: [UInt32: Int] = [:]
        var terrain: [UInt32: Int] = [:]
        for (point, state) in occupancy {
            let raw = try XCTUnwrap(map.terrainFlags(x: point.x, y: point.y))
            let values = try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
                from: .init(
                    point: point,
                    terrainRawValue: raw,
                    occupancy: .init(
                        buildingID: state.buildingID,
                        currentMonumentSubBuildingPhase: state.currentSubBuildingPhase
                    )
                )
            )
            terrain[raw, default: 0] += 1
            primary[values.primaryPassability, default: 0] += 1
            fallback[values.fallbackCellClass, default: 0] += 1
        }

        XCTAssertEqual(terrain, [0x10000088: 506, 0x100000C8: 21, 0x10000008: 1])
        XCTAssertEqual(primary, [0x20: 507, 0x4: 21])
        XCTAssertEqual(fallback, [0x4C001000: 507, 0x40: 21])
    }

    func testHaunxianCityRebuildsCompleteWorkerRoutingGridsAndCanalAccesses() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let city = DeterministicCityState(
            year: -246,
            treasury: 15_000,
            map: try EmperorMap(url: mapURL)
        )

        let grids = try city.grandCanalWorkerRoutingGrids()
        XCTAssertEqual(grids.width, 140)
        XCTAssertEqual(grids.height, 140)
        XCTAssertEqual(grids.primaryPassability.count, 140 * 140)
        XCTAssertEqual(grids.fallbackCellClass.count, 140 * 140)
        XCTAssertFalse(try city.grandCanalPhaseLaborTargetAccesses(
            routingGrids: grids
        ).isEmpty)
    }

    /// Plan 006 Phase 1a: the Native primary cache must stay inside the
    /// recovered `FUN_005AD440` write domain, and the recovered immigrant
    /// flood pass mask `0xB7C` (`FUN_005AE240`) must discriminate the
    /// produced values exactly as the original does.
    func testNativePrimaryRoutingCacheMatchesRecoveredWriteDomainAndFloodMask() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let city = DeterministicCityState(
            year: -246,
            treasury: 15_000,
            map: try EmperorMap(url: mapURL)
        )
        let grids = try city.grandCanalWorkerRoutingGrids()

        // Recovered primary write domain (DESIGN.md; migration-popularity-producer.md
        // §10.4): base values 1/2/4/0x10/0x20/0x80/0x100/0x400/0x1000/0x4000 plus
        // the ferry post-pass masks 0x200/0x800.
        let baseDomain: UInt16 =
            0x1 | 0x2 | 0x4 | 0x10 | 0x20 | 0x80 | 0x100 | 0x400 | 0x1000 | 0x4000
        let ferryPostProcessMasks: UInt16 = 0x200 | 0x800
        let writeDomain = baseDomain | ferryPostProcessMasks

        var produced = Set<UInt16>()
        for (index, value) in grids.primaryPassability.enumerated() {
            XCTAssertEqual(
                value & ~writeDomain,
                0,
                "primary cache produced a bit outside the recovered write domain "
                    + "at cell \(index): 0x\(String(value, radix: 16))"
            )
            produced.insert(value)
        }

        // `FUN_005AE240`: a neighbour passes the flood iff its main-cache word
        // has a nonzero intersection with 0xB7C.
        let floodMask: UInt16 = 0xB7C
        let passing = produced.filter { $0 & floodMask != 0 }
        let blocking = produced.filter { $0 & floodMask == 0 }
        XCTAssertFalse(passing.isEmpty, "expected some produced cells to be flood-passable")
        XCTAssertFalse(blocking.isEmpty, "expected some produced cells to block the flood")
        // Bits 0x8/0x40 are in the mask but have no producer in this build; every
        // passing value must carry at least one effectively-produced bit.
        let effectiveProducedBits: UInt16 = 0x4 | 0x10 | 0x20 | 0x100 | 0x200 | 0x800
        for value in passing {
            XCTAssertNotEqual(
                value & effectiveProducedBits,
                0,
                "flood-passing value 0x\(String(value, radix: 16)) lacks an "
                    + "effectively-produced bit"
            )
        }

        // Recorded divergence (migration-popularity-producer.md §10.4): the ferry
        // post-pass is documented in `PrimaryRoutingClassRule` but not applied by
        // the city grid projection, so ferry masks cannot be produced today. This
        // assertion flips when the post-pass lands.
        XCTAssertTrue(
            produced.isDisjoint(with: [UInt16(0x200), UInt16(0x800)]),
            "ferry masks are produced; update this test and §10.4 once the post-pass lands"
        )
    }

    /// Plan 006 Phase 1a: a placed Ferry (building 210) currently reaches the
    /// unclassified generic-footprint branch and must fail closed instead of
    /// inventing a footprint predicate. Flip this when the ferry post-pass
    /// (0x800 footprint / 0x200 connector chain) is wired.
    func testFerryOccupancyStaysFailClosedUntilPostPassIsWired() throws {
        XCTAssertThrowsError(
            try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
                from: .init(
                    point: GridPoint(x: 10, y: 10),
                    terrainRawValue: 0x8008,
                    occupancy: .init(buildingID: 210)
                )
            )
        ) { error in
            guard case OriginalGrandCanalLayoutCatalog.WorkerRoutingCacheDerivationError
                .missingGenericFootprintPredicate = error else {
                XCTFail("expected missingGenericFootprintPredicate, got \(error)")
                return
            }
        }
    }

    func testFerryWaterEdgeLayerReplaysTerrainSupportAndBoundaryBytes() throws {
        let width = 3
        let height = 3
        let supported = UInt32(0x04 | 0x0408_0000)
        var terrain = Array(repeating: supported, count: width * height)
        // The center must be water (`0x4`) without the source's own
        // `0x80000` exclusion bit; that bit is still present on every
        // neighbouring support word.
        terrain[4] = 0x0400_0004
        let occupancy = Array(
            repeating: OriginalGrandCanalLayoutCatalog.FerryEdgeOccupancy.none,
            count: width * height
        )

        let result = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: width,
                height: height,
                terrainRawValues: terrain,
                roadWaterAuxiliaryValues: Array(repeating: 0, count: terrain.count),
                occupancy: occupancy
            )
        )

        // The center has all eight supported neighbours and follows the
        // source's `(x <= width-2 ? -1 : 0) & 0xFE` result. Without the PE's
        // padded border, an out-of-bounds neighbour fails the all-neighbour
        // test, leaving the outer ring at the reset sentinel.
        XCTAssertEqual(result[4], -2)
        XCTAssertEqual(result[0], -1)
        XCTAssertEqual(result[1], -1)
    }

    func testFerryWaterEdgeLayerHonorsExistingSentinelAndModelBlockers() throws {
        let width = 3
        let height = 3
        let supported = UInt32(0x04 | 0x0408_0000)
        var terrain = Array(repeating: supported, count: width * height)
        terrain[4] = 0x0400_0004
        let baseOccupancy = Array(
            repeating: OriginalGrandCanalLayoutCatalog.FerryEdgeOccupancy.none,
            count: terrain.count
        )

        var blockedByModel = baseOccupancy
        blockedByModel[4] = .model(id: 0x38)
        let modelBlocked = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: width,
                height: height,
                terrainRawValues: terrain,
                roadWaterAuxiliaryValues: Array(repeating: 0, count: terrain.count),
                occupancy: blockedByModel
            )
        )
        XCTAssertEqual(modelBlocked[4], -1)

        var secondBlockedByModel = baseOccupancy
        secondBlockedByModel[4] = .model(id: 0xD2)
        let secondModelBlocked = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: width,
                height: height,
                terrainRawValues: terrain,
                roadWaterAuxiliaryValues: Array(repeating: 0, count: terrain.count),
                occupancy: secondBlockedByModel
            )
        )
        XCTAssertEqual(secondModelBlocked[4], -1)

        var retainedByModel = baseOccupancy
        retainedByModel[4] = .model(id: 0x1F)
        let modelRetained = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: width,
                height: height,
                terrainRawValues: terrain,
                roadWaterAuxiliaryValues: Array(repeating: 0, count: terrain.count),
                occupancy: retainedByModel
            )
        )
        XCTAssertEqual(modelRetained[4], -2)

        var previous = Array(repeating: Int8(-1), count: terrain.count)
        previous[4] = -6
        let preservedSentinel = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: width,
                height: height,
                terrainRawValues: terrain,
                roadWaterAuxiliaryValues: Array(repeating: 0, count: terrain.count),
                existingEdgeValues: previous,
                occupancy: baseOccupancy
            )
        )
        XCTAssertEqual(preservedSentinel[4], -1)

        var unknown = baseOccupancy
        unknown[4] = .occupiedModelUnknown
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: width,
                height: height,
                terrainRawValues: terrain,
                roadWaterAuxiliaryValues: Array(repeating: 0, count: terrain.count),
                occupancy: unknown
            )
        )
    }

    func testFerryWaterEdgeLayerRejectsUnmappedInputShapes() {
        let occupancy = Array(
            repeating: OriginalGrandCanalLayoutCatalog.FerryEdgeOccupancy.none,
            count: 9
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: 3,
                height: 3,
                terrainRawValues: Array(repeating: 4, count: 8),
                roadWaterAuxiliaryValues: Array(repeating: 0, count: 9),
                occupancy: occupancy
            )
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer(
                width: 3,
                height: 3,
                terrainRawValues: Array(repeating: 4, count: 9),
                roadWaterAuxiliaryValues: Array(repeating: 0, count: 9),
                occupancy: Array(occupancy.dropLast())
            )
        )
    }

    /// The recovered Ferry post-pass is exposed as a pure primitive while
    /// connector discovery remains unresolved. It must preserve the base
    /// cache, OR `0x800` over the supplied footprint, and then OR `0x200` over
    /// the supplied connector chain (including overlap with the footprint).
    func testFerryPrimaryPostpassAddsFootprintAndExplicitConnectorMasks() throws {
        let base: [UInt16] = [
            0x000, 0x004, 0x100,
            0x002, 0x010, 0x020,
            0x000, 0x080, 0x400
        ]
        let footprint = [
            GridPoint(x: 0, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: 1, y: 1)
        ]
        let connectors = [
            GridPoint(x: 2, y: 2),
            GridPoint(x: 1, y: 1)
        ]

        let result = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.applyFerryPrimaryPostpass(
                primaryValues: base,
                width: 3,
                height: 3,
                footprintPoints: footprint,
                connectorPoints: connectors
            )
        )

        XCTAssertEqual(result[0], 0x800)
        XCTAssertEqual(result[1], 0x804)
        XCTAssertEqual(result[4], 0x810 | 0x800 | 0x200)
        XCTAssertEqual(result[8], 0x400 | 0x200)
        XCTAssertEqual(result, [
            0x800, 0x804, 0x100,
            0x002, 0xA10, 0x020,
            0x000, 0x080, 0x600
        ])
        XCTAssertEqual(base[4], 0x010, "post-pass must not mutate the base cache")
    }

    func testFerryPrimaryPostpassRejectsOutOfBoundsWithoutProducingCache() {
        let base: [UInt16] = [0, 1, 2, 3]

        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.applyFerryPrimaryPostpass(
                primaryValues: base,
                width: 2,
                height: 2,
                footprintPoints: [GridPoint(x: -1, y: 0)],
                connectorPoints: []
            )
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.applyFerryPrimaryPostpass(
                primaryValues: base,
                width: 2,
                height: 2,
                footprintPoints: [],
                connectorPoints: [GridPoint(x: 2, y: 1)]
            )
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.applyFerryPrimaryPostpass(
                primaryValues: [0, 1, 2],
                width: 2,
                height: 2,
                footprintPoints: [],
                connectorPoints: []
            )
        )
    }

    func testFerryStoredStateMatchesOriginalConstructorReset() {
        var state = OriginalGrandCanalLayoutCatalog.FerryStoredState()
        XCTAssertEqual(state.connectorCount, 0)
        XCTAssertEqual(
            state.connectorSlots.count,
            OriginalGrandCanalLayoutCatalog.FerryStoredState.connectorSlotCount
        )
        XCTAssertTrue(state.connectorSlots.allSatisfy { $0 == -1 })

        // Simulate stale runtime contents before the object is reconstructed.
        XCTAssertTrue(state.writeConnectorSlot(index: 0, value: 6))
        XCTAssertTrue(state.writeConnectorSlot(index: 499, value: 2))
        XCTAssertFalse(state.writeConnectorSlot(index: 500, value: 4))
        state.reset()

        XCTAssertEqual(state.connectorCount, 0)
        XCTAssertTrue(state.connectorSlots.allSatisfy { $0 == -1 })
    }

    func testFerryPlacementCallerChainMatchesIndexedSource() {
        let catalog = OriginalGrandCanalLayoutCatalog.FerryPlacementCallerCatalog.self
        XCTAssertEqual(catalog.selectedBuildingDispatchAddress, 0x0046CB40)
        XCTAssertEqual(catalog.ferryBuildingID, 0xD2)
        XCTAssertEqual(catalog.placementOrchestrationAddress, 0x004C5E10)
        XCTAssertEqual(catalog.connectorComputationAddress, 0x004C62C0)
        XCTAssertEqual(catalog.placementFloodAddress, 0x005B33C0)
        XCTAssertEqual(catalog.gradientWalkAddress, 0x005B3670)
        XCTAssertTrue(catalog.dispatchesFerry(buildingID: 210))
        XCTAssertFalse(catalog.dispatchesFerry(buildingID: 83))
    }

    func testFerryStoredStateRoundTripsItsRawSentinelBuffer() throws {
        let state = OriginalGrandCanalLayoutCatalog.FerryStoredState()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(
            OriginalGrandCanalLayoutCatalog.FerryStoredState.self,
            from: data
        )
        XCTAssertEqual(decoded, state)
    }

    func testFerryConnectorComputationGateStopsAtTheFirstFailedLookup() {
        let localFailure = OriginalGrandCanalLayoutCatalog
            .evaluateFerryConnectorComputationGate(
                localCoordinatesAvailable: false,
                pairedEndpointHandle: 1,
                partnerCoordinatesAvailable: true,
                computedDirectionCount: 4
            )
        XCTAssertEqual(localFailure.rejection, .localCoordinatesUnavailable)
        XCTAssertFalse(localFailure.placementFloodInvoked)
        XCTAssertFalse(localFailure.gradientWalkInvoked)
        XCTAssertNil(localFailure.storedConnectorCount)
        XCTAssertFalse(localFailure.succeeded)

        let endpointFailure = OriginalGrandCanalLayoutCatalog
            .evaluateFerryConnectorComputationGate(
                localCoordinatesAvailable: true,
                pairedEndpointHandle: 0,
                partnerCoordinatesAvailable: true,
                computedDirectionCount: 4
            )
        XCTAssertEqual(endpointFailure.rejection, .pairedEndpointUnavailable)
        XCTAssertFalse(endpointFailure.placementFloodInvoked)
        XCTAssertFalse(endpointFailure.gradientWalkInvoked)
        XCTAssertNil(endpointFailure.storedConnectorCount)

        let partnerFailure = OriginalGrandCanalLayoutCatalog
            .evaluateFerryConnectorComputationGate(
                localCoordinatesAvailable: true,
                pairedEndpointHandle: 1,
                partnerCoordinatesAvailable: false,
                computedDirectionCount: 4
            )
        XCTAssertEqual(partnerFailure.rejection, .partnerCoordinatesUnavailable)
        XCTAssertFalse(partnerFailure.placementFloodInvoked)
        XCTAssertFalse(partnerFailure.gradientWalkInvoked)
        XCTAssertNil(partnerFailure.storedConnectorCount)
    }

    func testFerryConnectorComputationGateStoresGradientCountOnlyAfterBothPairs() {
        let computed = OriginalGrandCanalLayoutCatalog
            .evaluateFerryConnectorComputationGate(
                localCoordinatesAvailable: true,
                pairedEndpointHandle: 7,
                partnerCoordinatesAvailable: true,
                computedDirectionCount: 4
            )
        XCTAssertNil(computed.rejection)
        XCTAssertTrue(computed.placementFloodInvoked)
        XCTAssertTrue(computed.gradientWalkInvoked)
        XCTAssertEqual(computed.storedConnectorCount, 4)
        XCTAssertTrue(computed.succeeded)

        let zero = OriginalGrandCanalLayoutCatalog
            .evaluateFerryConnectorComputationGate(
                localCoordinatesAvailable: true,
                pairedEndpointHandle: 7,
                partnerCoordinatesAvailable: true,
                computedDirectionCount: 0
            )
        XCTAssertEqual(zero.storedConnectorCount, 0)
        XCTAssertFalse(zero.succeeded)
    }

    func testFerryConnectorGradientWalkStoresOppositeCardinalDirections() throws {
        let directions = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryConnectorDirections(
                floodValues: [1, 2, 3, 4],
                width: 4,
                height: 1,
                start: GridPoint(x: 3, y: 0),
                globalOrientation: 0,
                useCellOrientationTieBreak: false
            )
        )

        // The walk moves west three times (selection code 6); the executable
        // stores the opposite connector code 2 for each step.
        XCTAssertEqual(directions, [2, 2, 2])
    }

    func testFerryConnectorGradientWalkAppliesRecoveredOrientationTieGate() throws {
        let flood: [UInt16] = [
            0, 2, 2,
            0, 0, 1
        ]
        let terrainOrientation: [UInt8] = [
            0, 1, 0,
            0, 0, 0
        ]

        let globalTieWalk = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryConnectorDirections(
                floodValues: flood,
                width: 3,
                height: 2,
                start: GridPoint(x: 1, y: 0),
                globalOrientation: 1,
                useCellOrientationTieBreak: false
            )
        )
        XCTAssertEqual(globalTieWalk, [6, 0])

        let cellTieWalk = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryConnectorDirections(
                floodValues: flood,
                width: 3,
                height: 2,
                start: GridPoint(x: 1, y: 0),
                globalOrientation: 1,
                useCellOrientationTieBreak: true,
                terrainOrientationByCell: terrainOrientation
            )
        )
        XCTAssertEqual(cellTieWalk, [6, 0])

        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.deriveFerryConnectorDirections(
                floodValues: flood,
                width: 3,
                height: 2,
                start: GridPoint(x: 1, y: 0),
                globalOrientation: 1,
                useCellOrientationTieBreak: true,
                terrainOrientationByCell: [
                    0, 0, 0,
                    0, 0, 0
                ] as [UInt8]
            )
        )
    }

    func testFerryConnectorGradientWalkExcludesImmediateReverseOnEqualFloodTie() {
        // Starting at the middle cell, the first equal-flood choice moves east
        // and stores the opposite connector code 6. At the east cell the only
        // remaining equal-flood candidate is the immediate reverse (west),
        // which the executable excludes via `local_4`; it therefore returns
        // no connector chain instead of bouncing back to the middle cell.
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.deriveFerryConnectorDirections(
                floodValues: [2, 2, 2],
                width: 3,
                height: 1,
                start: GridPoint(x: 1, y: 0),
                globalOrientation: 0,
                useCellOrientationTieBreak: false
            )
        )
    }

    func testFerryPlacementFloodUsesCardinalLayersAndForcedEndpoint() throws {
        let width = 5
        let height = 1
        let layers = Array(repeating: Array(repeating: Int8(0), count: width), count: 4)
        let terrain = Array(repeating: Array(repeating: UInt8(0), count: width), count: 4)

        let flood = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood(
                width: width,
                height: height,
                start: GridPoint(x: 0, y: 0),
                endpoint: GridPoint(x: 4, y: 0),
                startLayer: Array(repeating: Int8(0), count: width),
                passabilityByDirection: layers,
                terrainBlockByteByDirection: terrain
            )
        )
        XCTAssertEqual(flood, [1, 2, 3, 4, 5])

        let forcedEndpoint = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood(
                width: 2,
                height: 1,
                start: GridPoint(x: 0, y: 0),
                endpoint: GridPoint(x: 1, y: 0),
                startLayer: [0, 0],
                passabilityByDirection: Array(repeating: [Int8(-1), 0], count: 4),
                terrainBlockByteByDirection: Array(repeating: [0, 1], count: 4)
            )
        )
        XCTAssertEqual(forcedEndpoint, [1, 2])
    }

    func testFerryPlacementFloodPreservesAsymmetricTerrainByteIndexing() throws {
        let width = 3
        let height = 2
        let start = GridPoint(x: 1, y: 1)
        let endpoint = GridPoint(x: 0, y: 0)
        let passability = Array(repeating: Array(repeating: Int8(-1), count: width * height), count: 4)

        // East passability is indexed at the candidate, but its terrain byte
        // is read from the current cell. Blocking only the current cell must
        // therefore reject the east step.
        var eastPassability = passability[1]
        eastPassability[start.y * width + start.x + 1] = 0
        var eastTerrain = Array(repeating: UInt8(0), count: width * height)
        eastTerrain[start.y * width + start.x] = 1
        var passabilityByDirection = passability
        passabilityByDirection[1] = eastPassability
        var terrainByDirection = Array(repeating: Array(repeating: UInt8(0), count: width * height), count: 4)
        terrainByDirection[1] = eastTerrain

        let eastBlockedByCurrent = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood(
                width: width,
                height: height,
                start: start,
                endpoint: endpoint,
                startLayer: Array(repeating: Int8(0), count: width * height),
                passabilityByDirection: passabilityByDirection,
                terrainBlockByteByDirection: terrainByDirection
            )
        )
        XCTAssertEqual(eastBlockedByCurrent[start.y * width + start.x + 1], 0)

        // North terrain is indexed at the candidate. Blocking only the
        // candidate must reject that step even though the current cell is
        // clear.
        var northPassability = passabilityByDirection[0]
        northPassability[start.y * width + start.x - width] = 0
        passabilityByDirection[0] = northPassability
        var northTerrain = terrainByDirection[0]
        northTerrain[start.y * width + start.x - width] = 1
        terrainByDirection[0] = northTerrain

        let northBlockedByCandidate = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood(
                width: width,
                height: height,
                start: start,
                endpoint: endpoint,
                startLayer: Array(repeating: Int8(0), count: width * height),
                passabilityByDirection: passabilityByDirection,
                terrainBlockByteByDirection: terrainByDirection
            )
        )
        XCTAssertEqual(northBlockedByCandidate[start.y * width + start.x - width], 0)
    }

    func testFerryPlacementFloodRejectsInvalidLayerShapesAndStart() {
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood(
                width: 2,
                height: 1,
                start: GridPoint(x: 0, y: 0),
                endpoint: GridPoint(x: 1, y: 0),
                startLayer: [0],
                passabilityByDirection: Array(repeating: [0, 0], count: 4),
                terrainBlockByteByDirection: Array(repeating: [0, 0], count: 4)
            )
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood(
                width: 2,
                height: 1,
                start: GridPoint(x: -1, y: 0),
                endpoint: GridPoint(x: 1, y: 0),
                startLayer: [0, 0],
                passabilityByDirection: Array(repeating: [0, 0], count: 4),
                terrainBlockByteByDirection: Array(repeating: [0, 0], count: 4)
            )
        )
    }

    func testCanalRoutingCacheChangesAtRecoveredPhaseBoundary() throws {
        let point = GridPoint(x: 4, y: 68)
        let inactive = try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
            from: .init(
                point: point,
                terrainRawValue: 0x10000088,
                occupancy: .init(buildingID: 83, currentMonumentSubBuildingPhase: 0)
            )
        )
        let active = try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
            from: .init(
                point: point,
                terrainRawValue: 0x10000088,
                occupancy: .init(buildingID: 83, currentMonumentSubBuildingPhase: 4)
            )
        )
        let activeRoadCrossing = try OriginalGrandCanalLayoutCatalog
            .workerRoutingCellValues(
                from: .init(
                    point: point,
                    terrainRawValue: 0x100000C8,
                    occupancy: .init(buildingID: 83, currentMonumentSubBuildingPhase: 4)
                )
            )

        XCTAssertEqual(inactive.primaryPassability, 0x20)
        XCTAssertEqual(inactive.fallbackCellClass, 0x2)
        XCTAssertEqual(active.primaryPassability, 0x20)
        XCTAssertEqual(active.fallbackCellClass, 0x4C001000)
        XCTAssertEqual(activeRoadCrossing.primaryPassability, 0x4)
        XCTAssertEqual(activeRoadCrossing.fallbackCellClass, 0x40)
    }

    func testHaunxianWorkerFallsBackAcrossTheAuthoredCanalFootprint() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        var primary = [UInt16](repeating: 0x2, count: map.width * map.height)
        var fallback = [UInt32](repeating: 0x80000001, count: map.width * map.height)
        for state in map.grandCanalPartStates {
            for point in BuildingFootprint(width: 4, height: 4).points(at: state.worldOrigin) {
                let values = try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
                    from: .init(
                        point: point,
                        terrainRawValue: try XCTUnwrap(
                            map.terrainFlags(x: point.x, y: point.y)
                        ),
                        occupancy: .init(
                            buildingID: state.buildingID,
                            currentMonumentSubBuildingPhase: state.currentSubBuildingPhase
                        )
                    )
                )
                let index = point.y * map.width + point.x
                primary[index] = values.primaryPassability
                fallback[index] = values.fallbackCellClass
            }
        }

        let start = GridPoint(x: 46, y: 70)
        let destination = GridPoint(x: 68, y: 70)
        let route = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.workerRoute(
                primaryValues: primary,
                fallbackValues: fallback,
                width: map.width,
                height: map.height,
                from: start,
                to: destination
            )
        )

        XCTAssertEqual(route.grid, .fallbackCellClass)
        XCTAssertEqual(route.points.first, start)
        XCTAssertEqual(route.points.last, destination)
        XCTAssertTrue(route.points.allSatisfy { point in
            (4...135).contains(point.x) && (68...71).contains(point.y)
        })
    }

    func testHaunxianPhaseFourIsAlreadyTheOriginalTerminalState() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        var city = DeterministicCityState(year: -246, treasury: 15_000, map: map)

        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(83))
        for _ in 0..<62 {
            XCTAssertEqual(try city.advanceGrandCanalSchedulerCall(), .alreadyComplete)
        }
        XCTAssertEqual(city.aesthetics.grandCanalScheduler.callCounter, 0)
        XCTAssertEqual(
            city.aesthetics.grandCanalMapPartStates.map(\.currentSubBuildingPhase),
            Array(repeating: 4, count: 33)
        )
        XCTAssertEqual(
            city.aesthetics.grandCanalMapPartStates.map(\.wholeMonumentPhase),
            Array(repeating: 4, count: 33)
        )
        let restoredData = try NativeSaveGameStore.encoded(
            NativeSaveGame(replaySeed: 83, city: city)
        )
        var restored = try NativeSaveGameStore.decoded(restoredData).city
        XCTAssertEqual(restored.aesthetics.grandCanalScheduler, city.aesthetics.grandCanalScheduler)
        XCTAssertEqual(try restored.advanceGrandCanalSchedulerCall(), .alreadyComplete)
        XCTAssertEqual(
            restored.aesthetics.grandCanalMapPartStates.map(\.wholeMonumentPhase),
            Array(repeating: 4, count: 33)
        )
        XCTAssertTrue(restored.aesthetics.completedMonumentBuildingIDs.contains(83))
    }

    func testArchivedTerminalCanalSatisfiesMonumentGoalWithoutMutation() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        var city = DeterministicCityState(
            year: -246,
            treasury: 15_000,
            map: try EmperorMap(url: mapURL)
        )

        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(83))
        XCTAssertEqual(try city.advanceGrandCanalSchedulerCall(), .alreadyComplete)
        XCTAssertEqual(
            Set(city.aesthetics.grandCanalMapPartStates.map(\.currentSubBuildingPhase)),
            [4]
        )
    }

    func testNativeClockDistributesAllOriginalSchedulerCallsAcrossEachMonth() {
        let calls = (1...SimulationClockState.daysPerMonth).map {
            OriginalGrandCanalLayoutCatalog.schedulerCalls(forNativeDay: $0)
        }

        XCTAssertEqual(Set(calls), [27, 28])
        XCTAssertEqual(
            calls.reduce(0, +),
            OriginalGrandCanalLayoutCatalog.originalSimulationStepsPerMonth
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.originalSimulationStepsPerMonth,
            51 * 16
        )
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.schedulerCalls(forNativeDay: 0), 0)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.schedulerCalls(forNativeDay: 31), 0)
    }

    func testNativeDailyClockLeavesCompletedHaunxianCanalUnchanged() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        var city = DeterministicCityState(
            year: -246,
            treasury: 15_000,
            map: try EmperorMap(url: mapURL)
        )
        let models = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: models)

        _ = city.advanceTick(rules: rules)
        XCTAssertEqual(city.aesthetics.grandCanalScheduler.callCounter, 0)
        XCTAssertEqual(
            city.aesthetics.grandCanalMapPartStates.map(\.currentSubBuildingPhase),
            Array(repeating: 4, count: 33)
        )

        _ = city.advanceTick(rules: rules)
        XCTAssertEqual(city.aesthetics.grandCanalScheduler.callCounter, 0)
        XCTAssertEqual(
            city.aesthetics.grandCanalMapPartStates.map(\.currentSubBuildingPhase),
            Array(repeating: 4, count: 33)
        )
        XCTAssertEqual(
            city.aesthetics.grandCanalMapPartStates.map(\.wholeMonumentPhase),
            Array(repeating: 4, count: 33)
        )

        _ = city.advanceTick(rules: rules)
        XCTAssertEqual(city.aesthetics.grandCanalScheduler.callCounter, 0)
        XCTAssertEqual(
            city.aesthetics.grandCanalMapPartStates.map(\.wholeMonumentPhase),
            Array(repeating: 4, count: 33)
        )

        for _ in 3..<SimulationClockState.daysPerMonth {
            _ = city.advanceTick(rules: rules)
        }

        XCTAssertEqual(city.aesthetics.grandCanalScheduler.callCounter, 0)
        XCTAssertEqual(city.simulationClock.day, 1)
    }

    func testCompletedHaunxianCanalIsPresentAtGoalBoundarySnapshot() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        var city = DeterministicCityState(
            year: -246,
            treasury: 15_000,
            map: try EmperorMap(url: mapURL)
        )
        var encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(city))
                as? [String: Any]
        )
        var clock = try XCTUnwrap(encoded["simulationClockState"] as? [String: Any])
        clock["day"] = SimulationClockState.daysPerMonth
        encoded["simulationClockState"] = clock
        city = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONSerialization.data(withJSONObject: encoded)
        )

        let models = try OriginalEconomyModels(source: .openDefault())
        let result = city.advanceTick(rules: EconomyRulesEngine(models: models))
        let settlement = try XCTUnwrap(result.monthlySettlement)

        XCTAssertTrue(
            try XCTUnwrap(settlement.completedMonumentBuildingIDsAtBoundary).contains(83)
        )
        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(83))
    }

    func testRoadWaterFallbackBranchRequiresItsIndependentByteLayer() throws {
        let point = GridPoint(x: 2, y: 3)
        XCTAssertThrowsError(
            try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
                from: .init(point: point, terrainRawValue: 0x44)
            )
        ) { error in
            XCTAssertEqual(
                error as? OriginalGrandCanalLayoutCatalog.WorkerRoutingCacheDerivationError,
                .missingRoadWaterAuxiliary(point)
            )
        }
        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
                from: .init(
                    point: point,
                    terrainRawValue: 0x44,
                    roadWaterAuxiliaryByte: 1
                )
            ).fallbackCellClass,
            0x40
        )
        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.workerRoutingCellValues(
                from: .init(
                    point: point,
                    terrainRawValue: 0x44,
                    roadWaterAuxiliaryByte: 0
                )
            ).fallbackCellClass,
            0x10000200
        )
    }

    func testLegacyAestheticPayloadDecodesWithoutOriginalCanalParts() throws {
        let state = DeterministicAestheticState()
        let encoded = try JSONEncoder().encode(state)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "grandCanalMapPartStatesState")
        object.removeValue(forKey: "grandCanalSchedulerState")
        let legacy = try JSONSerialization.data(withJSONObject: object)

        XCTAssertTrue(
            try JSONDecoder().decode(
                DeterministicAestheticState.self,
                from: legacy
            ).grandCanalMapPartStates.isEmpty
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicAestheticState.self,
                from: legacy
            ).grandCanalScheduler,
            GrandCanalSchedulerState()
        )
    }

    func testLegacyCanalPartStateDecodesWithoutDeliveredStoneCounter() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let original = try XCTUnwrap(EmperorMap(url: mapURL).grandCanalPartStates.first)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(original))
                as? [String: Any]
        )
        object.removeValue(forKey: "deliveredStoneUnits")

        let restored = try JSONDecoder().decode(
            GrandCanalMapPartState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(restored.deliveredStoneUnits, 0)
        XCTAssertEqual(restored.currentSubBuildingPhase, 4)
        XCTAssertEqual(restored.wholeMonumentPhase, 4)
    }

    func testPhaseTwoStoneDeliveryFillsOnlyRemainderAndReturnsExcessCargo() {
        var state = GrandCanalMapPartState(
            worldOrigin: GridPoint(x: 4, y: 68),
            mapCellIndex: 25_584,
            buildingID: 83,
            subBuildingIndex: 0,
            baseBuildingSchema: 4,
            monumentWrapperSchema: 1,
            monumentStateSchema: 9,
            currentSubBuildingPhase: 2,
            wholeMonumentPhase: 2
        )

        XCTAssertEqual(state.acceptPhaseTwoStoneCargo(250), 0)
        XCTAssertEqual(state.deliveredStoneUnits, 250)
        XCTAssertEqual(state.remainingPhaseTwoStoneUnits, 150)
        XCTAssertEqual(state.acceptPhaseTwoStoneCargo(200), 50)
        XCTAssertEqual(state.deliveredStoneUnits, 400)
        XCTAssertEqual(state.remainingPhaseTwoStoneUnits, 0)
    }

    func testStoneCargoDoesNotApplyOutsidePhaseTwo() {
        var state = GrandCanalMapPartState(
            worldOrigin: GridPoint(x: 4, y: 68),
            mapCellIndex: 25_584,
            buildingID: 83,
            subBuildingIndex: 0,
            baseBuildingSchema: 4,
            monumentWrapperSchema: 1,
            monumentStateSchema: 9,
            currentSubBuildingPhase: 1,
            wholeMonumentPhase: 1
        )

        XCTAssertEqual(state.acceptPhaseTwoStoneCargo(100), 100)
        XCTAssertEqual(state.deliveredStoneUnits, 0)
    }

    func testAuthoredCanalModelParsesPerPhaseOnSiteWorkTicks() throws {
        let modelURL = GameDataSource.defaultRoot
            .appendingPathComponent("Model/SB_CANAL.txt")
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let text = try String(contentsOf: modelURL, encoding: .utf8)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.parseOnSiteWorkTicks(
                subBuildingModelText: text
            ),
            [
                0: [80, 40, 50, 40],
                1: [50, 40, 80, 10],
                2: [60, 60, 30, 60, 60],
                3: [],
                4: [],
            ]
        )
    }

    func testLaborerArrivalDoesNotCompleteUntilAuthoredOnSiteWorkFinishes() {
        var state = GrandCanalMapPartState(
            worldOrigin: GridPoint(x: 4, y: 68),
            mapCellIndex: 25_584,
            buildingID: 83,
            subBuildingIndex: 0,
            baseBuildingSchema: 4,
            monumentWrapperSchema: 1,
            monumentStateSchema: 9,
            currentSubBuildingPhase: 0,
            wholeMonumentPhase: 0
        )

        for _ in 0..<209 {
            XCTAssertFalse(state.recordOnSiteLaborerWorkUpdate(xiWangMuActive: false))
        }
        XCTAssertEqual(state.currentSubBuildingPhase, 0)
        XCTAssertEqual(state.onSiteLaborerWorkUpdates, 209)
        XCTAssertTrue(state.recordOnSiteLaborerWorkUpdate(xiWangMuActive: false))
        XCTAssertEqual(state.currentSubBuildingPhase, 1)
        XCTAssertEqual(state.onSiteLaborerWorkUpdates, 0)
    }

    func testXiWangMuHalvesEachCanalWorkRecordBeforeSumming() {
        var state = GrandCanalMapPartState(
            worldOrigin: GridPoint(x: 4, y: 68),
            mapCellIndex: 25_584,
            buildingID: 83,
            subBuildingIndex: 0,
            baseBuildingSchema: 4,
            monumentWrapperSchema: 1,
            monumentStateSchema: 9,
            currentSubBuildingPhase: 1,
            wholeMonumentPhase: 1
        )

        for _ in 0..<89 {
            XCTAssertFalse(state.recordOnSiteLaborerWorkUpdate(xiWangMuActive: true))
        }
        XCTAssertTrue(state.recordOnSiteLaborerWorkUpdate(xiWangMuActive: true))
        XCTAssertEqual(state.currentSubBuildingPhase, 2)
        XCTAssertEqual(state.onSiteLaborerWorkUpdates, 0)
    }

    func testLegacyCanalPartStateDecodesWithoutOnSiteWorkCounter() throws {
        let state = GrandCanalMapPartState(
            worldOrigin: GridPoint(x: 4, y: 68),
            mapCellIndex: 25_584,
            buildingID: 83,
            subBuildingIndex: 0,
            baseBuildingSchema: 4,
            monumentWrapperSchema: 1,
            monumentStateSchema: 9,
            currentSubBuildingPhase: 0,
            wholeMonumentPhase: 0,
            onSiteLaborerWorkUpdates: 17
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
                as? [String: Any]
        )
        object.removeValue(forKey: "onSiteLaborerWorkUpdates")

        let restored = try JSONDecoder().decode(
            GrandCanalMapPartState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(restored.onSiteLaborerWorkUpdates, 0)
    }

    func testLaborProviderCapacityAndDistanceUseRecoveredOriginalBoundaries() {
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseLaborProviderCapacity(
            efficiencyPercent: 49
        ), 0)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseLaborProviderCapacity(
            efficiencyPercent: 50
        ), 1)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseLaborProviderCapacity(
            efficiencyPercent: 69
        ), 1)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseLaborProviderCapacity(
            efficiencyPercent: 70
        ), 2)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseLaborProviderCapacity(
            efficiencyPercent: 80
        ), 3)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseLaborProviderEfficiencyPercent(
                requiredWorkers: 10,
                assignedWorkers: 7
            ),
            70
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseLaborProviderEfficiencyPercent(
                requiredWorkers: 0,
                assignedWorkers: 7
            ),
            0
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseLaborProviderDistance(
                from: .init(x: 0, y: 0),
                to: .init(x: 8, y: 4)
            ),
            8
        )

        let candidates = [
            OriginalGrandCanalLayoutCatalog.PhaseLaborProviderCandidate(
                objectID: 1,
                buildingID: 233,
                isActive: true,
                efficiencyPercent: 49,
                activeMonumentWorkerCount: 0,
                origin: .init(x: 4, y: 4)
            ),
            .init(
                objectID: 2,
                buildingID: 233,
                isActive: true,
                efficiencyPercent: 80,
                activeMonumentWorkerCount: 2,
                origin: .init(x: 12, y: 8)
            ),
            .init(
                objectID: 3,
                buildingID: 233,
                isActive: true,
                efficiencyPercent: 100,
                activeMonumentWorkerCount: 0,
                origin: .init(x: 14, y: 8)
            ),
        ]
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectPhaseLaborProvider(
                for: .init(x: 16, y: 8),
                candidates: candidates
            )?.objectID,
            3
        )
    }

    func testCityProjectsLaborCampWorkforceAndLiveDispatchCountIntoProvider() throws {
        let sourceURL = GameDataSource.defaultRoot
            .appendingPathComponent("Model/EmperorBuildingModels.txt")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let models = try BuildingModelTable(contentsOf: sourceURL)
        var city = DeterministicCityState(
            year: -246,
            treasury: 10_000,
            mapWidth: 20,
            mapHeight: 20
        )
        for index in 0..<7 {
            XCTAssertNotNil(city.addHouse(
                levelID: 0,
                residents: 1,
                location: .init(x: index, y: 0),
                models: models
            ))
        }
        let payload: [String: Any] = [
            "pendingRequests": [],
            "laborers": [[
                "figureID": 4,
                "providerObjectID": 42,
                "providerOrigin": ["x": 6, "y": 6],
                "currentPoint": ["x": 6, "y": 6],
                "targetPoint": ["x": 8, "y": 6],
                "state": 12,
                "initialRequestID": 0,
            ]],
            "nextFigureIDState": 5,
        ]
        var aesthetics = DeterministicAestheticState()
        aesthetics.restoreGrandCanalPhaseLaborCoordinator(try JSONDecoder().decode(
            OriginalGrandCanalLayoutCatalog.PhaseLaborCoordinatorRuntime.self,
            from: JSONSerialization.data(withJSONObject: payload)
        ))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(city))
                as? [String: Any]
        )
        object["buildingPlacementState"] = [[
            "category": "aesthetic",
            "instanceID": 42,
            "buildingID": 233,
            "origin": ["x": 6, "y": 6],
            "orientation": IsometricBuildingOrientation.northSouth.rawValue,
            "footprint": ["width": 3, "height": 3],
            "roadAccessPoint": ["x": 6, "y": 9],
        ]]
        object["aestheticState"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(aesthetics)
        )
        city = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        let provider = try XCTUnwrap(city.grandCanalPhaseLaborProviders(models: models).first)
        XCTAssertEqual(provider.objectID, 42)
        XCTAssertEqual(provider.efficiencyPercent, 20)
        XCTAssertEqual(provider.activeMonumentWorkerCount, 1)
        XCTAssertEqual(provider.origin, .init(x: 6, y: 6))
    }

    func testPhaseLaborSchedulerKeepsPendingUntilInitialArrivalThenBindsNearestTask() throws {
        var parts = (0..<33).map { index in
            GrandCanalMapPartState(
                worldOrigin: .init(x: 4 + index * 4, y: 68),
                mapCellIndex: index,
                buildingID: 83,
                subBuildingIndex: index,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 0,
                wholeMonumentPhase: 0
            )
        }
        var scheduler = GrandCanalSchedulerState(callCounter: 30)
        var coordinator = OriginalGrandCanalLayoutCatalog.PhaseLaborCoordinatorRuntime()
        let providers = [
            OriginalGrandCanalLayoutCatalog.PhaseLaborProviderCandidate(
                objectID: 2330,
                buildingID: 233,
                isActive: true,
                efficiencyPercent: 100,
                activeMonumentWorkerCount: 0,
                origin: .init(x: 0, y: 68)
            ),
        ]

        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.advancePhaseLaborSchedulerCall(
                parts: &parts,
                scheduler: &scheduler,
                coordinator: &coordinator,
                providers: providers,
                targetAccesses: (0..<33).map {
                    .init(
                        subBuildingIndex: $0,
                        worldOrigin: .init(x: 4 + $0 * 4, y: 68),
                        roadAccessPoint: .init(x: 3 + $0 * 4, y: 68)
                    )
                },
                xiWangMuActive: false
            ),
            .maintainedPhaseLabor(
                pendingCount: 33,
                activeLaborerCount: 1,
                dispatchedFigureID: 1
            )
        )
        XCTAssertEqual(coordinator.pendingRequests.count, 33)
        XCTAssertEqual(coordinator.laborers[0].state, .initialTravelToMonument)
        XCTAssertEqual(coordinator.laborers[0].targetPoint, .init(x: 3, y: 68))
        XCTAssertEqual(coordinator.laborers[0].initialRequestID, 0)

        XCTAssertEqual(
            coordinator.recordArrival(figureID: 1, at: .init(x: 3, y: 68)),
            .assigned(requestID: 0)
        )
        XCTAssertEqual(coordinator.pendingRequests.count, 32)
        XCTAssertEqual(coordinator.laborers[0].state, .travelingToAssignedTask)
        XCTAssertEqual(coordinator.laborers[0].targetPoint, .init(x: 4, y: 68))
        XCTAssertNil(coordinator.laborers[0].initialRequestID)
        XCTAssertEqual(
            coordinator.recordArrival(figureID: 1, at: .init(x: 4, y: 68)),
            .beganOnSiteWork(requestID: 0)
        )
        XCTAssertEqual(coordinator.laborers[0].state, .workingOnSite)
    }

    func testPhaseLaborerMovementUsesInitialStepThenRecoveredTwentySubstepCadence() {
        var parts = (0..<33).map { index in
            GrandCanalMapPartState(
                worldOrigin: .init(x: 3 + index * 4, y: 1),
                mapCellIndex: index,
                buildingID: 83,
                subBuildingIndex: index,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 0,
                wholeMonumentPhase: 0
            )
        }
        var coordinator = OriginalGrandCanalLayoutCatalog.PhaseLaborCoordinatorRuntime(
            laborers: [.init(
                figureID: 1,
                providerObjectID: 9,
                providerOrigin: .init(x: 1, y: 1),
                targetPoint: .init(x: 3, y: 1),
                initialRequestID: 0
            )],
            nextFigureID: 2
        )
        let grids = OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids(
            width: 6,
            height: 3,
            primaryPassability: [UInt16](repeating: 0x4, count: 18),
            fallbackCellClass: [UInt32](repeating: 0x2, count: 18)
        )

        XCTAssertEqual(coordinator.advanceFigureUpdates(
            parts: &parts,
            routingGrids: grids,
            xiWangMuActive: false
        ), 1)
        XCTAssertEqual(coordinator.laborers.first?.currentPoint, .init(x: 2, y: 1))
        XCTAssertEqual(coordinator.laborers.first?.movement?.routeIndex, 1)
        XCTAssertEqual(coordinator.laborers.first?.previousPoint, .init(x: 1, y: 1))
        XCTAssertEqual(coordinator.laborers.first?.animationFrame, 1)

        for _ in 0..<14 {
            XCTAssertEqual(coordinator.advanceFigureUpdates(
                parts: &parts,
                routingGrids: grids,
                xiWangMuActive: false
            ), 0)
        }
        XCTAssertEqual(coordinator.laborers.first?.currentPoint, .init(x: 2, y: 1))
        XCTAssertEqual(coordinator.laborers.first?.previousPoint, .init(x: 1, y: 1))
        XCTAssertEqual(coordinator.advanceFigureUpdates(
            parts: &parts,
            routingGrids: grids,
            xiWangMuActive: false
        ), 1)
        XCTAssertEqual(coordinator.laborers.first?.currentPoint, .init(x: 3, y: 1))
        XCTAssertEqual(coordinator.laborers.first?.state, .returningToProvider)
    }

    func testNativeCityClockDispatchesAndMovesPhaseZeroCanalLaborer() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: -246,
            treasury: 100_000,
            map: try EmperorMap(url: mapURL)
        )
        var aesthetics = city.aesthetics
        var phaseZeroParts = aesthetics.grandCanalMapPartStates
        for index in phaseZeroParts.indices {
            phaseZeroParts[index].setConstructionPhases(
                currentSubBuildingPhase: 0,
                wholeMonumentPhase: 0
            )
        }
        aesthetics.restoreGrandCanalMapPartStates(phaseZeroParts)
        var encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(city))
                as? [String: Any]
        )
        encoded["aestheticState"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(aesthetics)
        )
        city = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONSerialization.data(withJSONObject: encoded)
        )

        let campOrigin = try XCTUnwrap(city.nextBuildingConstructionLocation(
            buildingID: 233
        ))
        XCTAssertNotNil(city.constructAestheticBuilding(
            buildingID: 233,
            at: campOrigin,
            rules: rules
        ))
        for _ in 0..<5 {
            let houseOrigin = try XCTUnwrap(city.nextHouseConstructionLocation())
            XCTAssertNotNil(city.addHouse(
                levelID: 0,
                residents: 7,
                location: houseOrigin,
                models: original.buildings
            ))
        }

        let providerBeforeTick = try XCTUnwrap(
            city.grandCanalPhaseLaborProviders(models: original.buildings).first
        )
        XCTAssertGreaterThanOrEqual(providerBeforeTick.efficiencyPercent, 50)
        let gridsBeforeTick = try city.grandCanalWorkerRoutingGrids()
        XCTAssertFalse(try city.grandCanalPhaseLaborTargetAccesses(
            routingGrids: gridsBeforeTick
        ).isEmpty)

        _ = city.advanceTick(rules: rules)
        XCTAssertTrue(city.aesthetics.grandCanalPhaseLaborCoordinator.laborers.isEmpty)
        _ = city.advanceTick(rules: rules)
        let laborer = try XCTUnwrap(
            city.aesthetics.grandCanalPhaseLaborCoordinator.laborers.first
        )
        XCTAssertNotEqual(laborer.currentPoint, laborer.providerOrigin)
        XCTAssertNotNil(laborer.movement)
        XCTAssertNotNil(laborer.previousPoint)
        XCTAssertGreaterThan(laborer.animationFrame, 0)
        let restoredLaborer = try XCTUnwrap(
            JSONDecoder().decode(
                DeterministicCityState.self,
                from: JSONEncoder().encode(city)
            ).aesthetics.grandCanalPhaseLaborCoordinator.laborers.first
        )
        XCTAssertEqual(
            restoredLaborer.movement,
            laborer.movement
        )
        XCTAssertEqual(restoredLaborer.previousPoint, laborer.previousPoint)
        XCTAssertEqual(restoredLaborer.animationFrame, laborer.animationFrame)
    }

    func testNativeCityClockWithdrawsWarehouseStoneAndCreatesPhaseTwoConvoy() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: -246,
            treasury: 100_000,
            map: try EmperorMap(url: mapURL)
        )
        var aesthetics = city.aesthetics
        var phaseTwoParts = aesthetics.grandCanalMapPartStates
        for index in phaseTwoParts.indices {
            phaseTwoParts[index].setConstructionPhases(
                currentSubBuildingPhase: 2,
                wholeMonumentPhase: 2
            )
        }
        aesthetics.restoreGrandCanalMapPartStates(phaseTwoParts)
        var encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(city))
                as? [String: Any]
        )
        encoded["aestheticState"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(aesthetics)
        )
        city = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONSerialization.data(withJSONObject: encoded)
        )

        let warehouseOrigin = try XCTUnwrap(city.nextBuildingConstructionLocation(
            buildingID: 54
        ))
        let warehouseID = try XCTUnwrap(city.constructWarehouse(
            at: warehouseOrigin,
            rules: rules
        ))
        XCTAssertEqual(city.receiveCampaignCommodityGift(
            commodityID: 20,
            amount: 400
        ), 400)
        let sourcePoint = try XCTUnwrap(
            city.logistics.warehouses.first(where: { $0.id == warehouseID })
        ).roadAccessPoint

        _ = city.advanceTick(rules: rules)
        XCTAssertTrue(city.aesthetics.grandCanalPhaseTwoConvoys.isEmpty)
        XCTAssertEqual(city.storedCampaignCommodityAmount(commodityID: 20), 400)

        _ = city.advanceTick(rules: rules)
        let convoy = try XCTUnwrap(city.aesthetics.grandCanalPhaseTwoConvoys.first)
        XCTAssertEqual(city.storedCampaignCommodityAmount(commodityID: 20), 0)
        XCTAssertEqual(convoy.sourceObjectID, warehouseID)
        XCTAssertEqual(convoy.sourceOrigin, sourcePoint)
        XCTAssertEqual(convoy.cargoUnits, 400)
        XCTAssertNotEqual(convoy.currentPoint, sourcePoint)
        XCTAssertFalse(
            city.aesthetics.grandCanalPhaseTwoCoordinator.carrierBoundRequests.isEmpty
        )

        let restored = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONEncoder().encode(city)
        )
        XCTAssertEqual(restored.aesthetics.grandCanalPhaseTwoConvoys, [convoy])
        XCTAssertEqual(
            restored.aesthetics.grandCanalPhaseTwoCoordinator.nextFigureID,
            4
        )

        var deliveredCity = restored
        for _ in 0..<120 where
            deliveredCity.aesthetics.grandCanalMapPartStates.reduce(0, {
                $0 + $1.deliveredStoneUnits
            }) < 400 {
            _ = deliveredCity.advanceTick(rules: rules)
        }
        XCTAssertEqual(
            deliveredCity.aesthetics.grandCanalMapPartStates.reduce(0, {
                $0 + $1.deliveredStoneUnits
            }),
            400
        )
        XCTAssertTrue(
            deliveredCity.aesthetics.grandCanalPhaseTwoCoordinator
                .carrierBoundRequests.isEmpty
        )
        for _ in 0..<120 where
            !deliveredCity.aesthetics.grandCanalPhaseTwoConvoys.isEmpty {
            _ = deliveredCity.advanceTick(rules: rules)
        }
        XCTAssertTrue(deliveredCity.aesthetics.grandCanalPhaseTwoConvoys.isEmpty)
    }

    func testPhaseLaborerCompletesOneTask102ThenReturnsAndWholePhaseWaitsForQueueDrain() throws {
        var parts = (0..<33).map { index in
            GrandCanalMapPartState(
                worldOrigin: .init(x: 4 + index * 4, y: 68),
                mapCellIndex: index,
                buildingID: 83,
                subBuildingIndex: index,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: index == 0 ? 0 : 1,
                wholeMonumentPhase: 0
            )
        }
        var coordinator = OriginalGrandCanalLayoutCatalog.PhaseLaborCoordinatorRuntime(
            pendingRequests: [
                .init(
                    requestID: 0,
                    phase: 0,
                    taskID: 102,
                    workerFigureID: 10,
                    targetPoint: .init(x: 4, y: 68)
                ),
            ],
            laborers: [
                .init(
                    figureID: 7,
                    providerObjectID: 2330,
                    providerOrigin: .init(x: 0, y: 68),
                    targetPoint: .init(x: 4, y: 68)
                ),
            ]
        )
        XCTAssertEqual(
            coordinator.recordArrival(figureID: 7, at: .init(x: 4, y: 68)),
            .assigned(requestID: 0)
        )
        XCTAssertEqual(
            coordinator.recordArrival(figureID: 7, at: .init(x: 4, y: 68)),
            .beganOnSiteWork(requestID: 0)
        )
        for update in 1..<210 {
            XCTAssertEqual(
                coordinator.recordOnSiteWorkUpdate(
                    figureID: 7,
                    parts: &parts,
                    xiWangMuActive: false
                ),
                .working(requestID: 0, completedUpdates: update)
            )
        }
        XCTAssertEqual(
            coordinator.recordOnSiteWorkUpdate(
                figureID: 7,
                parts: &parts,
                xiWangMuActive: false
            ),
            .completedAndReturning(completedRequestID: 0)
        )
        XCTAssertEqual(parts[0].currentSubBuildingPhase, 1)
        XCTAssertEqual(coordinator.laborers[0].state, .returningToProvider)
        XCTAssertEqual(
            coordinator.recordArrival(figureID: 7, at: .init(x: 0, y: 68)),
            .returnedToProvider(providerObjectID: 2330)
        )
        XCTAssertTrue(coordinator.laborers.isEmpty)

        var scheduler = GrandCanalSchedulerState(callCounter: 30)
        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.advancePhaseLaborSchedulerCall(
                parts: &parts,
                scheduler: &scheduler,
                coordinator: &coordinator,
                providers: [],
                targetAccesses: [],
                xiWangMuActive: false
            ),
            .advancedWholeMonumentPhase(from: 0, to: 1)
        )
        XCTAssertEqual(Set(parts.map(\.wholeMonumentPhase)), [1])
    }

    func testPhaseLaborCoordinatorPersistsThroughNativeAestheticSave() throws {
        var state = DeterministicAestheticState()
        state.restoreGrandCanalPhaseLaborCoordinator(.init(
            pendingRequests: [
                .init(
                    requestID: 3,
                    phase: 1,
                    taskID: 102,
                    workerFigureID: 10,
                    targetPoint: .init(x: 16, y: 68)
                ),
            ],
            nextFigureID: 9
        ))
        let restored = try JSONDecoder().decode(
            DeterministicAestheticState.self,
            from: JSONEncoder().encode(state)
        )
        XCTAssertEqual(restored.grandCanalPhaseLaborCoordinator, state.grandCanalPhaseLaborCoordinator)
        XCTAssertEqual(restored.grandCanalPhaseLaborCoordinator.nextFigureID, 9)
    }

    func testPhaseTwoSourceRequestMergesAndSplitsAtOriginalFourHundredUnits() {
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.nextPhaseTwoSourceRequest(
                sameCommodityPendingUnits: []
            )
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.nextPhaseTwoSourceRequest(
                sameCommodityPendingUnits: [120, 80, 150]
            ),
            350
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.nextPhaseTwoSourceRequest(
                sameCommodityPendingUnits: [120, 80, 250, 400]
            ),
            400
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.nextPhaseTwoSourceRequest(
                sameCommodityPendingUnits: [650]
            ),
            400
        )
    }

    func testPhaseTwoStoneSourcePredicatesMatchOriginalBuildingBranches() {
        let request = 400
        let requestingObjectID = 83
        let warehouse = OriginalGrandCanalLayoutCatalog.PhaseTwoMaterialSourceCandidate(
            objectID: 10,
            buildingID: 54,
            isActive: true,
            availableStoneUnits: request
        )
        XCTAssertTrue(
            OriginalGrandCanalLayoutCatalog.isEligiblePhaseTwoMaterialSource(
                warehouse,
                requestingObjectID: requestingObjectID,
                requestedUnits: request
            )
        )

        for buildingID in [56, 58] {
            for state in [0, 6, 8] {
                XCTAssertTrue(
                    OriginalGrandCanalLayoutCatalog.isEligiblePhaseTwoMaterialSource(
                        .init(
                            objectID: buildingID,
                            buildingID: buildingID,
                            isActive: true,
                            availableStoneUnits: request,
                            commodityTradeState: state
                        ),
                        requestingObjectID: requestingObjectID,
                        requestedUnits: request
                    )
                )
            }
            for state in [7, 9] {
                XCTAssertFalse(
                    OriginalGrandCanalLayoutCatalog.isEligiblePhaseTwoMaterialSource(
                        .init(
                            objectID: buildingID,
                            buildingID: buildingID,
                            isActive: true,
                            availableStoneUnits: request,
                            commodityTradeState: state
                        ),
                        requestingObjectID: requestingObjectID,
                        requestedUnits: request
                    )
                )
            }
        }

        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.isEligiblePhaseTwoMaterialSource(
                .init(
                    objectID: 53,
                    buildingID: 53,
                    isActive: true,
                    availableStoneUnits: 800
                ),
                requestingObjectID: requestingObjectID,
                requestedUnits: request
            )
        )
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.isEligiblePhaseTwoMaterialSource(
                .init(
                    objectID: 11,
                    buildingID: 54,
                    isActive: true,
                    availableStoneUnits: request - 1
                ),
                requestingObjectID: requestingObjectID,
                requestedUnits: request
            )
        )
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.isEligiblePhaseTwoMaterialSource(
                .init(
                    objectID: requestingObjectID,
                    buildingID: 54,
                    isActive: true,
                    availableStoneUnits: request
                ),
                requestingObjectID: requestingObjectID,
                requestedUnits: request
            )
        )
    }

    func testPhaseTwoTradeCommodityStateTransitionMatchesOriginalWriter() {
        let expected: [Int: Int] = [
            5: 6,
            6: 5,
            7: 8,
            8: 7,
            0: 9,
            9: 9,
            255: 9,
        ]

        for (currentState, nextState) in expected {
            XCTAssertEqual(
                OriginalGrandCanalLayoutCatalog.phaseTwoTradeCommodityStateTransition(currentState),
                nextState,
                "unexpected raw trade state transition for \(currentState)"
            )
        }
    }

    func testPhaseTwoWithdrawalReturnValueBecomesActualCarrierCargo() {
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.PhaseTwoInventoryWithdrawal(
                requestedUnits: 400,
                unfulfilledUnits: 0
            ).cargoUnits,
            400
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.PhaseTwoInventoryWithdrawal(
                requestedUnits: 400,
                unfulfilledUnits: 150
            ).cargoUnits,
            250
        )
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.PhaseTwoInventoryWithdrawal(
                requestedUnits: 400,
                unfulfilledUnits: 400
            ).createsCarrier
        )
    }

    func testPhaseTwoSourceSelectionUsesOriginalBreadthFirstQueueOrder() {
        let width = 5
        let height = 5
        let roads = [UInt16](repeating: 0x4, count: width * height)
        let start = GridPoint(x: 2, y: 2)
        let candidates = [
            GridPoint(x: 2, y: 3), // down
            GridPoint(x: 3, y: 2), // right: visited first at the same depth
            GridPoint(x: 2, y: 1), // up: visited before both despite array order
        ]
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoSourceCandidateIndex(
                primaryValues: roads,
                width: width,
                height: height,
                from: start,
                orderedCandidatePoints: candidates
            ),
            2
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoSourceSearchNeighborOffsets,
            [
                GridPoint(x: 0, y: -1),
                GridPoint(x: 1, y: 0),
                GridPoint(x: 0, y: 1),
                GridPoint(x: -1, y: 0),
            ]
        )
    }

    func testPhaseTwoSourceSelectionKeepsCandidateOrderAndPassabilityMask() {
        let width = 5
        let height = 3
        var grid = [UInt16](repeating: 0, count: width * height)
        let start = GridPoint(x: 0, y: 1)
        grid[1 * width + 1] = 0x10 // bare land is rejected by 0x0B0C
        grid[1 * width + 2] = 0x4
        let sharedCandidate = GridPoint(x: 2, y: 1)
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.phaseTwoSourceCandidateIndex(
                primaryValues: grid,
                width: width,
                height: height,
                from: start,
                orderedCandidatePoints: [sharedCandidate, sharedCandidate]
            )
        )

        grid[1 * width + 1] = 0x100
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoSourceCandidateIndex(
                primaryValues: grid,
                width: width,
                height: height,
                from: start,
                orderedCandidatePoints: [sharedCandidate, sharedCandidate]
            ),
            0
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoSourceCandidateIndex(
                primaryValues: [0],
                width: 1,
                height: 1,
                from: .init(x: 0, y: 0),
                orderedCandidatePoints: [.init(x: 0, y: 0)]
            ),
            0,
            "The original checks the start cell before any passability expansion"
        )
    }

    func testPhaseTwoMultipartTargetAccessesUseOriginDistanceAndStableAuthoredOrder() {
        let candidates = [
            OriginalGrandCanalLayoutCatalog.PhaseTwoTargetAccessCandidate(
                subBuildingIndex: 0,
                worldOrigin: .init(x: 4, y: 68),
                roadAccessPoint: .init(x: 3, y: 68)
            ),
            .init(
                subBuildingIndex: 1,
                worldOrigin: .init(x: 8, y: 68),
                roadAccessPoint: .init(x: 8, y: 67)
            ),
            .init(
                subBuildingIndex: 2,
                worldOrigin: .init(x: 12, y: 68),
                roadAccessPoint: .init(x: 13, y: 68)
            ),
            .init(
                subBuildingIndex: 3,
                worldOrigin: .init(x: 16, y: 68),
                roadAccessPoint: .init(x: 16, y: 67)
            ),
        ]
        let ordered = OriginalGrandCanalLayoutCatalog.orderedPhaseTwoTargetAccesses(
            requestingSubBuildingOrigin: .init(x: 10, y: 68),
            authoredAccessibleCandidates: candidates
        )

        XCTAssertEqual(ordered.map(\.subBuildingIndex), [1, 2, 0, 3])
        XCTAssertEqual(
            ordered.map(\.roadAccessPoint),
            [
                GridPoint(x: 8, y: 67),
                GridPoint(x: 13, y: 68),
                GridPoint(x: 3, y: 68),
                GridPoint(x: 16, y: 67),
            ],
            "Ranking uses origins while source BFS starts from access points"
        )
    }

    func testPhaseTwoRoadAccessUsesOriginalSizeFourPerimeterAndComponentPriority() {
        let origin = GridPoint(x: 20, y: 30)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoFourByFourRoadAccessOffsets,
            [
                .init(x: 0, y: -1), .init(x: 1, y: -1),
                .init(x: 2, y: -1), .init(x: 3, y: -1),
                .init(x: 4, y: 0), .init(x: 4, y: 1),
                .init(x: 4, y: 2), .init(x: 4, y: 3),
                .init(x: 3, y: 4), .init(x: 2, y: 4),
                .init(x: 1, y: 4), .init(x: 0, y: 4),
                .init(x: -1, y: 3), .init(x: -1, y: 2),
                .init(x: -1, y: 1), .init(x: -1, y: 0),
            ]
        )
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.roadAccessOffsetTableSlotCount, 24)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.roadAccessComponentRankLimit, 10)

        let firstPerimeterPoint = GridPoint(x: 20, y: 29)
        let laterSameComponentPoint = GridPoint(x: 24, y: 31)
        let bestComponentPoint = GridPoint(x: 19, y: 30)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoRoadAccessPoint(
                subBuildingOrigin: origin,
                roadComponentRankByPoint: [
                    firstPerimeterPoint: 2,
                    laterSameComponentPoint: 2,
                    bestComponentPoint: 0,
                ]
            ),
            bestComponentPoint
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoRoadAccessPoint(
                subBuildingOrigin: origin,
                roadComponentRankByPoint: [
                    firstPerimeterPoint: 2,
                    laterSameComponentPoint: 2,
                ]
            ),
            firstPerimeterPoint,
            "A strict rank improvement preserves perimeter-table order on ties"
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.phaseTwoRoadAccessPoint(
                subBuildingOrigin: origin,
                roadComponentRankByPoint: [firstPerimeterPoint: 10]
            )
        )
    }

    func testRoadComponentRankingUsesPrimaryConnectorsAndStableSizeTies() throws {
        let width = 10
        let height = 4
        var terrain = [UInt32](repeating: 0, count: width * height)
        var primary = [UInt16](repeating: 0x10, count: width * height)
        func set(_ point: GridPoint, terrain raw: UInt32, primary value: UInt16) {
            let index = point.y * width + point.x
            terrain[index] = raw
            primary[index] = value
        }

        // Two size-three road components tie; row-major discovery keeps the
        // western one first. The middle cell of that component is a Ferry-like
        // primary connector and is not an ordinary road terrain cell.
        set(.init(x: 1, y: 1), terrain: 0x40, primary: 0x4)
        set(.init(x: 2, y: 1), terrain: 0, primary: 0x200)
        set(.init(x: 3, y: 1), terrain: 0x40, primary: 0x4)
        set(.init(x: 6, y: 1), terrain: 0x40, primary: 0x4)
        set(.init(x: 7, y: 1), terrain: 0x40, primary: 0x4)
        set(.init(x: 8, y: 1), terrain: 0x40, primary: 0x4)

        let ranks = try OriginalGrandCanalLayoutCatalog.workerRoadComponentRankByPoint(
            width: width,
            height: height,
            terrainRawValues: terrain,
            primaryPassability: primary
        )
        XCTAssertEqual(ranks[.init(x: 1, y: 1)], 0)
        XCTAssertNil(ranks[.init(x: 2, y: 1)])
        XCTAssertEqual(ranks[.init(x: 3, y: 1)], 0)
        XCTAssertEqual(ranks[.init(x: 6, y: 1)], 1)
    }

    func testPhaseLaborAccessesUseRecoveredComponentRankAndPerimeterOrder() {
        let parts = [
            GrandCanalMapPartState(
                worldOrigin: .init(x: 20, y: 30),
                mapCellIndex: 0,
                buildingID: 83,
                subBuildingIndex: 0,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 0,
                wholeMonumentPhase: 0
            ),
        ]
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseLaborTargetAccesses(
                parts: parts,
                roadComponentRankByPoint: [
                    .init(x: 20, y: 29): 2,
                    .init(x: 24, y: 1 + 30): 2,
                    .init(x: 19, y: 30): 0,
                ]
            ),
            [.init(
                subBuildingIndex: 0,
                worldOrigin: .init(x: 20, y: 30),
                roadAccessPoint: .init(x: 19, y: 30)
            )]
        )
    }

    func testPhaseTwoCarrierAllocationUsesNearestRequestAndStableTieOrder() {
        var requests = [
            OriginalGrandCanalLayoutCatalog.PhaseTwoPendingMaterialRequest(
                requestID: 30,
                commodityID: 20,
                targetPoint: .init(x: 15, y: 10),
                remainingUnits: 100
            ),
            .init(
                requestID: 31,
                commodityID: 20,
                targetPoint: .init(x: 5, y: 10),
                remainingUnits: 150
            ),
            .init(
                requestID: 32,
                commodityID: 19,
                targetPoint: .init(x: 10, y: 10),
                remainingUnits: 400
            ),
        ]

        let allocation = OriginalGrandCanalLayoutCatalog.allocatePhaseTwoCarrierCargo(
            cargoUnits: 400,
            commodityID: 20,
            currentPoint: .init(x: 10, y: 10),
            pendingRequests: &requests
        )

        XCTAssertEqual(
            allocation.deliveries,
            [
                .init(requestID: 30, deliveredUnits: 100),
                .init(requestID: 31, deliveredUnits: 150),
            ],
            "Strict distance comparison preserves enumeration order on a tie"
        )
        XCTAssertEqual(allocation.remainingCargoUnits, 150)
        XCTAssertEqual(requests.map(\.remainingUnits), [400])
        XCTAssertEqual(requests.map(\.commodityID), [19])
    }

    func testPhaseTwoDispatchBatchMovesOnlySuccessfulFourHundredUnitPrefix() {
        let original = [
            OriginalGrandCanalLayoutCatalog.PhaseTwoPendingMaterialRequest(
                requestID: 1,
                commodityID: 20,
                targetPoint: .init(x: 4, y: 68),
                remainingUnits: 250
            ),
            .init(
                requestID: 2,
                commodityID: 19,
                targetPoint: .init(x: 8, y: 68),
                remainingUnits: 100
            ),
            .init(
                requestID: 3,
                commodityID: 20,
                targetPoint: .init(x: 12, y: 68),
                remainingUnits: 300
            ),
        ]

        var failed = original
        let failedBatch = OriginalGrandCanalLayoutCatalog.dispatchPhaseTwoMaterialBatch(
            pendingRequests: &failed,
            carrierCreated: false
        )
        XCTAssertEqual(failedBatch?.commodityID, 20)
        XCTAssertEqual(failedBatch?.requestedUnits, 400)
        XCTAssertTrue(failedBatch?.assignedRequests.isEmpty == true)
        XCTAssertEqual(failed, original)

        var succeeded = original
        let batch = OriginalGrandCanalLayoutCatalog.dispatchPhaseTwoMaterialBatch(
            pendingRequests: &succeeded,
            carrierCreated: true
        )
        XCTAssertEqual(batch?.commodityID, 20)
        XCTAssertEqual(batch?.requestedUnits, 400)
        XCTAssertEqual(batch?.assignedRequests.map(\.requestID), [1, 3])
        XCTAssertEqual(batch?.assignedRequests.map(\.remainingUnits), [250, 150])
        XCTAssertEqual(succeeded.map(\.requestID), [2, 3])
        XCTAssertEqual(succeeded.map(\.remainingUnits), [100, 150])
    }

    func testPhaseTwoCoordinatorGeneratesStablePerPartRequestsAndAppliesArrival() {
        var parts = [
            GrandCanalMapPartState(
                worldOrigin: .init(x: 4, y: 68),
                mapCellIndex: 0,
                buildingID: 83,
                subBuildingIndex: 0,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 2,
                wholeMonumentPhase: 2,
                deliveredStoneUnits: 150
            ),
            GrandCanalMapPartState(
                worldOrigin: .init(x: 8, y: 68),
                mapCellIndex: 1,
                buildingID: 83,
                subBuildingIndex: 1,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 2,
                wholeMonumentPhase: 2,
                deliveredStoneUnits: 0
            ),
            GrandCanalMapPartState(
                worldOrigin: .init(x: 12, y: 68),
                mapCellIndex: 2,
                buildingID: 83,
                subBuildingIndex: 2,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 1,
                wholeMonumentPhase: 2
            ),
        ]
        var coordinator = OriginalGrandCanalLayoutCatalog.PhaseTwoCoordinatorRuntime()
        coordinator.enqueueMissingRequests(from: Array(parts.reversed()))
        coordinator.enqueueMissingRequests(from: parts)
        XCTAssertEqual(coordinator.pendingRequests.map(\.requestID), [0, 1])
        XCTAssertEqual(coordinator.pendingRequests.map(\.remainingUnits), [250, 400])

        let batch = coordinator.dispatchNextBatch(carrierCreated: true)
        XCTAssertEqual(batch?.assignedRequests.map(\.requestID), [0, 1])
        XCTAssertEqual(batch?.assignedRequests.map(\.remainingUnits), [250, 150])
        XCTAssertEqual(coordinator.pendingRequests.map(\.remainingUnits), [250])
        XCTAssertEqual(coordinator.carrierBoundRequests.map(\.remainingUnits), [250, 150])

        let allocation = coordinator.allocateCarrierCargo(
            cargoUnits: 400,
            commodityID: 20,
            currentPoint: .init(x: 6, y: 67),
            parts: &parts
        )
        XCTAssertEqual(allocation.remainingCargoUnits, 0)
        XCTAssertTrue(coordinator.carrierBoundRequests.isEmpty)
        XCTAssertEqual(parts[0].deliveredStoneUnits, 400)
        XCTAssertEqual(parts[1].deliveredStoneUnits, 150)

        coordinator.enqueueMissingRequests(from: parts)
        XCTAssertEqual(coordinator.pendingRequests.map(\.requestID), [1])
        XCTAssertEqual(coordinator.pendingRequests.map(\.remainingUnits), [250])
    }

    func testPhaseTwoSchedulerCreatesRequestsAtThirtyFirstCallAndUsesActiveThreshold() throws {
        var parts = (0..<33).map { index in
            GrandCanalMapPartState(
                worldOrigin: .init(x: 4 + index * 4, y: 68),
                mapCellIndex: index,
                buildingID: 83,
                subBuildingIndex: index,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 2,
                wholeMonumentPhase: 2,
                deliveredStoneUnits: index == 0 ? 300 : 0
            )
        }
        var scheduler = GrandCanalSchedulerState()
        var coordinator = OriginalGrandCanalLayoutCatalog.PhaseTwoCoordinatorRuntime()
        for _ in 1...30 {
            XCTAssertEqual(
                try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                    parts: &parts,
                    scheduler: &scheduler,
                    coordinator: &coordinator
                ),
                .waiting
            )
        }
        XCTAssertTrue(coordinator.pendingRequests.isEmpty)
        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                parts: &parts,
                scheduler: &scheduler,
                coordinator: &coordinator
            ),
            .maintainedPhaseTwoMaterialRequests(
                pendingCount: 33,
                carrierBoundCount: 0
            )
        )
        XCTAssertEqual(coordinator.pendingRequests.first?.remainingUnits, 100)
        XCTAssertEqual(scheduler.callCounter, 0)
        XCTAssertEqual(
            scheduler.triggerThreshold,
            OriginalGrandCanalLayoutCatalog.schedulerTicksWithActiveWorkQueues
        )
        for _ in 1...50 {
            XCTAssertEqual(
                try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                    parts: &parts,
                    scheduler: &scheduler,
                    coordinator: &coordinator
                ),
                .waiting
            )
        }
        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                parts: &parts,
                scheduler: &scheduler,
                coordinator: &coordinator
            ),
            .maintainedPhaseTwoMaterialRequests(
                pendingCount: 33,
                carrierBoundCount: 0
            )
        )
    }

    func testPhaseTwoSchedulerAutomaticallyAdvancesOnlyAfterAllStoneIsDelivered() throws {
        var parts = (0..<33).map { index in
            GrandCanalMapPartState(
                worldOrigin: .init(x: 4 + index * 4, y: 68),
                mapCellIndex: index,
                buildingID: 83,
                subBuildingIndex: index,
                baseBuildingSchema: 4,
                monumentWrapperSchema: 1,
                monumentStateSchema: 9,
                currentSubBuildingPhase: 2,
                wholeMonumentPhase: 2,
                deliveredStoneUnits: 400
            )
        }
        var scheduler = GrandCanalSchedulerState()
        var coordinator = OriginalGrandCanalLayoutCatalog.PhaseTwoCoordinatorRuntime()

        for _ in 1...30 {
            XCTAssertEqual(
                try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                    parts: &parts,
                    scheduler: &scheduler,
                    coordinator: &coordinator
                ),
                .waiting
            )
        }
        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                parts: &parts,
                scheduler: &scheduler,
                coordinator: &coordinator
            ),
            .automaticallyAdvancedSubBuildings(indices: Array(0..<33))
        )
        XCTAssertEqual(Set(parts.map(\.currentSubBuildingPhase)), [3])
        XCTAssertEqual(Set(parts.map(\.wholeMonumentPhase)), [2])
        XCTAssertEqual(
            scheduler.triggerThreshold,
            OriginalGrandCanalLayoutCatalog.schedulerTicksWithoutActiveWorkQueues
        )

        for _ in 1...30 {
            XCTAssertEqual(
                try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                    parts: &parts,
                    scheduler: &scheduler,
                    coordinator: &coordinator
                ),
                .waiting
            )
        }
        XCTAssertEqual(
            try OriginalGrandCanalLayoutCatalog.advancePhaseTwoSchedulerCall(
                parts: &parts,
                scheduler: &scheduler,
                coordinator: &coordinator
            ),
            .advancedWholeMonumentPhase(from: 2, to: 3)
        )
        XCTAssertEqual(Set(parts.map(\.wholeMonumentPhase)), [3])
    }

    func testPhaseTwoCarrierConvoyPreservesOriginalArrivalAndReturnTicks() throws {
        var convoy = OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime(
            carrierFigureID: 500,
            firstHelperFigureID: 501,
            secondHelperFigureID: 502,
            sourceObjectID: 90,
            sourceBuildingID: 54,
            commodityID: 20,
            sourceOrigin: .init(x: 50, y: 50),
            monumentAccessPoint: .init(x: 12, y: 67),
            cargoUnits: 400
        )
        XCTAssertEqual(convoy.carrierState, .travelingToMonument)
        XCTAssertEqual(convoy.stateCounter, 30)
        XCTAssertEqual(convoy.helpers.map(\.state), [6, 8])

        convoy.recordMovementArrival()
        XCTAssertEqual(convoy.carrierState, .allocatingAtMonument)
        XCTAssertEqual(convoy.stateCounter, 0)

        var requests = [
            OriginalGrandCanalLayoutCatalog.PhaseTwoPendingMaterialRequest(
                requestID: 1,
                commodityID: 20,
                targetPoint: .init(x: 12, y: 68),
                remainingUnits: 250
            )
        ]
        let allocation = try XCTUnwrap(
            convoy.allocateAtMonument(
                currentPoint: .init(x: 12, y: 67),
                pendingRequests: &requests
            )
        )
        XCTAssertEqual(allocation.remainingCargoUnits, 150)
        XCTAssertEqual(convoy.carrierState, .returningWithCargo)

        convoy.recordMovementArrival()
        XCTAssertEqual(convoy.carrierState, .restoringCargoAtSource)
        for counter in 1...10 {
            XCTAssertEqual(convoy.advanceAtSource(), .waiting)
            XCTAssertEqual(convoy.stateCounter, counter)
        }
        XCTAssertEqual(convoy.advanceAtSource(), .sourceTransferDue(cargoUnits: 150))
        XCTAssertTrue(convoy.isCarrierActive)
        XCTAssertEqual(
            convoy.recordSourceTransfer(acceptedUnits: 150, nextProvider: nil),
            .fullyAccepted(units: 150)
        )
        XCTAssertEqual(convoy.carrierState, .returningEmpty)
        convoy.recordMovementArrival()
        XCTAssertEqual(convoy.advanceAtSource(), .destroyedEmpty)
        XCTAssertFalse(convoy.isCarrierActive)
        XCTAssertTrue(convoy.helpers.allSatisfy(\.isActive))

        convoy.updateHelperLiveness()
        XCTAssertTrue(convoy.helpers.allSatisfy { !$0.isActive })
        XCTAssertEqual(
            try JSONDecoder().decode(
                OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime.self,
                from: JSONEncoder().encode(convoy)
            ),
            convoy
        )
    }

    func testPhaseTwoFollowersPreserveRecoveredLinkedTwentyPhaseLag() {
        var convoy = OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime(
            carrierFigureID: 510,
            firstHelperFigureID: 511,
            secondHelperFigureID: 512,
            sourceObjectID: 90,
            sourceBuildingID: 54,
            commodityID: 20,
            sourceOrigin: .init(x: 10, y: 10),
            monumentAccessPoint: .init(x: 15, y: 10),
            cargoUnits: 400
        )
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoFirstFollowerLag, 18)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoSecondFollowerLag, 13)
        XCTAssertEqual(convoy.helpers.compactMap(\.currentPoint), [
            .init(x: 10, y: 10), .init(x: 10, y: 10),
        ])

        // Carrier phase zero gives follower phases 2 and 9. Neither is the
        // original 10/11 point-copy boundary.
        convoy.advanceAnimationAndFollowers()
        XCTAssertEqual(convoy.helpers.map(\.movementPhase), [2, 9])
        XCTAssertEqual(convoy.helpers.map(\.animationFrame), [1, 1])
        XCTAssertEqual(convoy.helpers.compactMap(\.currentPoint), [
            .init(x: 10, y: 10), .init(x: 10, y: 10),
        ])

        convoy.currentPoint = .init(x: 11, y: 10)
        convoy.movement = OriginalGrandCanalLayoutCatalog.PhaseLaborMovementRuntime(
            route: .init(
                grid: .primaryPassability,
                points: [.init(x: 11, y: 10)],
                directionCodes: []
            ),
            substepProgress: 8
        )
        convoy.advanceAnimationAndFollowers()
        XCTAssertEqual(convoy.helpers.map(\.movementPhase), [10, 17])
        XCTAssertEqual(convoy.helpers[0].currentPoint, .init(x: 11, y: 10))
        XCTAssertEqual(convoy.helpers[0].previousPoint, .init(x: 10, y: 10))
        XCTAssertEqual(convoy.helpers[1].currentPoint, .init(x: 10, y: 10))

        convoy.movement?.substepProgress = 1
        convoy.advanceAnimationAndFollowers()
        XCTAssertEqual(convoy.helpers.map(\.movementPhase), [3, 10])
        XCTAssertEqual(convoy.helpers[1].currentPoint, .init(x: 11, y: 10))
        XCTAssertEqual(convoy.helpers[1].previousPoint, .init(x: 10, y: 10))

        // The complete movement cadence/route test separately advances the
        // carrier. This fixture locks the linked phase arithmetic and its
        // save representation independently of route construction.
        let decoded = try! JSONDecoder().decode(
            OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime.self,
            from: JSONEncoder().encode(convoy)
        )
        XCTAssertEqual(decoded, convoy)
    }

    func testPhaseTwoEmptyReturnAndOutboundFailureKeepDistinctConsequences() {
        func makeConvoy() -> OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime {
            .init(
                carrierFigureID: 600,
                firstHelperFigureID: 601,
                secondHelperFigureID: 602,
                sourceObjectID: 91,
                sourceBuildingID: 56,
                commodityID: 20,
                sourceOrigin: .init(x: 40, y: 40),
                monumentAccessPoint: .init(x: 8, y: 67),
                cargoUnits: 200
            )
        }

        var emptyReturn = makeConvoy()
        emptyReturn.recordMovementArrival()
        var request = [
            OriginalGrandCanalLayoutCatalog.PhaseTwoPendingMaterialRequest(
                requestID: 2,
                commodityID: 20,
                targetPoint: .init(x: 8, y: 68),
                remainingUnits: 200
            )
        ]
        _ = emptyReturn.allocateAtMonument(
            currentPoint: .init(x: 8, y: 67),
            pendingRequests: &request
        )
        XCTAssertEqual(emptyReturn.carrierState, .returningEmpty)
        emptyReturn.recordMovementArrival()
        XCTAssertEqual(emptyReturn.carrierState, .emptyArrivalCleanup)
        XCTAssertEqual(emptyReturn.advanceAtSource(), .destroyedEmpty)
        XCTAssertFalse(emptyReturn.sourceRequestFlagRestored)

        var outboundFailure = makeConvoy()
        outboundFailure.recordRouteUnavailable()
        XCTAssertFalse(outboundFailure.isCarrierActive)
        XCTAssertTrue(outboundFailure.sourceRequestFlagRestored)

        var returnFailure = makeConvoy()
        returnFailure.recordMovementArrival()
        var noRequests: [OriginalGrandCanalLayoutCatalog.PhaseTwoPendingMaterialRequest] = []
        _ = returnFailure.allocateAtMonument(
            currentPoint: .init(x: 8, y: 67),
            pendingRequests: &noRequests
        )
        XCTAssertEqual(returnFailure.carrierState, .returningWithCargo)
        returnFailure.recordRouteUnavailable()
        XCTAssertFalse(returnFailure.sourceRequestFlagRestored)
    }

    func testPhaseTwoPartialSourceTransferKeepsCargoAndUsesProviderClassState() {
        var convoy = OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime(
            carrierFigureID: 650,
            firstHelperFigureID: 651,
            secondHelperFigureID: 652,
            sourceObjectID: 93,
            sourceBuildingID: 54,
            commodityID: 20,
            sourceOrigin: .init(x: 25, y: 25),
            monumentAccessPoint: .init(x: 20, y: 67),
            cargoUnits: 300
        )
        convoy.recordMovementArrival()
        var noRequests: [OriginalGrandCanalLayoutCatalog.PhaseTwoPendingMaterialRequest] = []
        _ = convoy.allocateAtMonument(
            currentPoint: .init(x: 20, y: 67),
            pendingRequests: &noRequests
        )
        convoy.recordMovementArrival()
        for _ in 0...OriginalGrandCanalLayoutCatalog.phaseTwoSourceReturnDelay {
            _ = convoy.advanceAtSource()
        }
        let quay = OriginalGrandCanalLayoutCatalog.PhaseTwoReturnProvider(
            objectID: 94,
            buildingID: 56,
            roadAccessPoint: .init(x: 35, y: 35)
        )
        XCTAssertEqual(
            convoy.recordSourceTransfer(acceptedUnits: 100, nextProvider: quay),
            .partiallyAcceptedAndRerouted(units: 100, providerObjectID: 94)
        )
        XCTAssertEqual(convoy.cargoUnits, 200)
        XCTAssertEqual(convoy.carrierState, .returningToAlternateSource)
        XCTAssertEqual(convoy.currentTargetObjectID, 94)
        XCTAssertEqual(convoy.currentTargetPoint, .init(x: 35, y: 35))

        var noProvider = convoy
        noProvider.recordMovementArrival()
        for _ in 0...OriginalGrandCanalLayoutCatalog.phaseTwoSourceReturnDelay {
            _ = noProvider.advanceAtSource()
        }
        XCTAssertEqual(
            noProvider.recordSourceTransfer(acceptedUnits: 50, nextProvider: nil),
            .partiallyAcceptedAwaitingProvider(units: 50)
        )
        XCTAssertEqual(noProvider.cargoUnits, 150)
        XCTAssertEqual(noProvider.carrierState, .routeFallback)
    }

    func testPhaseTwoRouteFallbackRetriesOnThirtyFirstUpdate() {
        var convoy = OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime(
            carrierFigureID: 680,
            firstHelperFigureID: 681,
            secondHelperFigureID: 682,
            sourceObjectID: 95,
            sourceBuildingID: 58,
            commodityID: 20,
            sourceOrigin: .init(x: 45, y: 45),
            monumentAccessPoint: .init(x: 24, y: 67),
            cargoUnits: 200
        )
        convoy.recordRouteBlocked(currentPrimaryGridValue: 0x4)
        XCTAssertEqual(convoy.carrierState, .routeFallback)
        for counter in 1...30 {
            XCTAssertEqual(convoy.advanceRouteFallback(nextProvider: nil), .waiting)
            XCTAssertEqual(convoy.stateCounter, counter)
        }
        XCTAssertEqual(convoy.advanceRouteFallback(nextProvider: nil), .noProvider)
        XCTAssertEqual(convoy.stateCounter, 0)
        for _ in 1...30 {
            _ = convoy.advanceRouteFallback(nextProvider: nil)
        }
        let warehouse = OriginalGrandCanalLayoutCatalog.PhaseTwoReturnProvider(
            objectID: 96,
            buildingID: 54,
            roadAccessPoint: .init(x: 46, y: 45)
        )
        XCTAssertEqual(
            convoy.advanceRouteFallback(nextProvider: warehouse),
            .rerouted(providerObjectID: 96)
        )
        XCTAssertEqual(convoy.carrierState, .returningWithCargo)
    }

    func testAestheticSavePreservesSourceBackedPhaseTwoConvoys() throws {
        let convoy = OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime(
            carrierFigureID: 720,
            firstHelperFigureID: 721,
            secondHelperFigureID: 722,
            sourceObjectID: 97,
            sourceBuildingID: 54,
            commodityID: 20,
            sourceOrigin: .init(x: 50, y: 50),
            monumentAccessPoint: .init(x: 28, y: 67),
            cargoUnits: 400
        )
        var aesthetics = DeterministicAestheticState()
        aesthetics.restoreGrandCanalPhaseTwoConvoys([convoy])
        var coordinator = OriginalGrandCanalLayoutCatalog.PhaseTwoCoordinatorRuntime()
        coordinator.pendingRequests = [
            .init(
                requestID: 0,
                commodityID: 20,
                targetPoint: .init(x: 4, y: 68),
                remainingUnits: 400
            )
        ]
        aesthetics.restoreGrandCanalPhaseTwoCoordinator(coordinator)
        let restored = try JSONDecoder().decode(
            DeterministicAestheticState.self,
            from: JSONEncoder().encode(aesthetics)
        )
        XCTAssertEqual(restored.grandCanalPhaseTwoConvoys, [convoy])
        XCTAssertEqual(restored.grandCanalPhaseTwoCoordinator, coordinator)

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(aesthetics))
                as? [String: Any]
        )
        object.removeValue(forKey: "grandCanalPhaseTwoConvoysState")
        object.removeValue(forKey: "grandCanalPhaseTwoCoordinatorState")
        let legacy = try JSONDecoder().decode(
            DeterministicAestheticState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertTrue(legacy.grandCanalPhaseTwoConvoys.isEmpty)
        XCTAssertTrue(legacy.grandCanalPhaseTwoCoordinator.pendingRequests.isEmpty)
    }

    func testPhaseTwoBlockedRouteUsesOriginalStateAndPrimaryBitBranch() {
        func makeConvoy() -> OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime {
            .init(
                carrierFigureID: 700,
                firstHelperFigureID: 701,
                secondHelperFigureID: 702,
                sourceObjectID: 92,
                sourceBuildingID: 58,
                commodityID: 20,
                sourceOrigin: .init(x: 30, y: 30),
                monumentAccessPoint: .init(x: 16, y: 67),
                cargoUnits: 200
            )
        }

        var outbound = makeConvoy()
        outbound.recordRouteBlocked(currentPrimaryGridValue: 0x4)
        XCTAssertEqual(outbound.carrierState, .routeFallback)
        XCTAssertEqual(outbound.stateCounter, 0)

        var syntheticBitEight = makeConvoy()
        syntheticBitEight.recordRouteBlocked(currentPrimaryGridValue: 0x8)
        XCTAssertEqual(syntheticBitEight.carrierState, .travelingToMonument)

        var emptyReturn = makeConvoy()
        emptyReturn.recordMovementArrival()
        var request = [
            OriginalGrandCanalLayoutCatalog.PhaseTwoPendingMaterialRequest(
                requestID: 4,
                commodityID: 20,
                targetPoint: .init(x: 16, y: 68),
                remainingUnits: 200
            )
        ]
        _ = emptyReturn.allocateAtMonument(
            currentPoint: .init(x: 16, y: 67),
            pendingRequests: &request
        )
        XCTAssertEqual(emptyReturn.carrierState, .returningEmpty)
        emptyReturn.recordRouteBlocked(currentPrimaryGridValue: 0x4)
        XCTAssertEqual(emptyReturn.carrierState, .returningEmpty)
    }

    func testRecoveredRequirementsPreserveOriginalIDsAmountsAndWorkers() {
        let requirements = OriginalGrandCanalLayoutCatalog.phaseRequirements
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.monumentPhaseCount, 5)
        XCTAssertEqual(requirements.map(\.phase), [0, 1, 2])
        XCTAssertEqual(requirements[0].kind, .internalWorkTask(id: 102))
        XCTAssertEqual(requirements[0].amountPerSubBuilding, 0)
        XCTAssertEqual(requirements[0].workerFigureID, 10)
        XCTAssertEqual(requirements[1].kind, .internalWorkTask(id: 102))
        XCTAssertEqual(requirements[1].amountPerSubBuilding, 0)
        XCTAssertEqual(requirements[1].workerFigureID, 10)
        XCTAssertEqual(requirements[2].kind, .commodity(id: 20))
        XCTAssertEqual(requirements[2].amountPerSubBuilding, 400)
        XCTAssertEqual(requirements[2].workerFigureID, 82)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.totalStoneUnits, 13_200)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoStoneCommodityID, 20)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoCarrierFigureType, 19)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoHelperFigureType, 20)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoCarrierInitialStateCounter, 30)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoStoneFirstHelperState, 6)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoStoneSecondHelperState, 8)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoSourceReturnDelay, 10)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoFallbackProviderSearchDelay,
            30
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoBlockedRouteRetentionMask,
            0x8
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoMaximumSourceRequestUnits,
            400
        )
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.phaseTwoExcludedMillBuildingID, 53)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoMaterialSourceBuildingIDs,
            [54, 56, 58]
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.phaseTwoRejectedTradeCommodityStates,
            [7, 9]
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.sourceInventoryLookupVtableOffset,
            0x264
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.sourceInventoryWithdrawalVtableOffset,
            0x298
        )
        XCTAssertFalse(requirements.contains { $0.phase == 3 || $0.phase == 4 })

        let behaviors = OriginalGrandCanalLayoutCatalog.phaseBehaviors
        XCTAssertEqual(behaviors.map(\.phase), Array(0..<5))
        XCTAssertEqual(behaviors[0].completion, .workerCompletesAuthoredOnSiteWork)
        XCTAssertEqual(behaviors[1].completion, .workerCompletesAuthoredOnSiteWork)
        XCTAssertEqual(behaviors[2].completion, .commodityAmountDelivered)
        XCTAssertEqual(behaviors[3].completion, .automaticAfterOtherQueuesDrain)
        XCTAssertEqual(behaviors[4].completion, .automaticAfterOtherQueuesDrain)
        XCTAssertNil(behaviors[3].requirement)
        XCTAssertNil(behaviors[4].requirement)
        XCTAssertFalse(OriginalGrandCanalLayoutCatalog.requiresWood)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.onSiteLaborerWorkTicksByPhase,
            [0: [80, 40, 50, 40], 1: [50, 40, 80, 10]]
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.onSiteLaborerWorkUpdates(
                forPhase: 0,
                xiWangMuActive: false
            ),
            210
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.onSiteLaborerWorkUpdates(
                forPhase: 1,
                xiWangMuActive: false
            ),
            180
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.onSiteLaborerWorkUpdates(
                forPhase: 0,
                xiWangMuActive: true
            ),
            105
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.onSiteLaborerWorkUpdates(
                forPhase: 1,
                xiWangMuActive: true
            ),
            90
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.missingPhaseModelFallbackWorkUpdates,
            51
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.workerProviders,
            [
                .init(figureID: 10, buildingID: 233),
                .init(figureID: 82, buildingID: 235),
            ]
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.normalDispatchLimits,
            .init(
                maximumArtisanWorkers: 3,
                maximumLaborerWorkers: 8,
                tasksPerLaborer: 7,
                tasksPerFigure80: 5,
                tasksPerFigure81: 3,
                tasksPerFigure82: 3
            )
        )
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.xiWangMuHeroEffectID, 3)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.xiWangMuDispatchLimits,
            .init(
                maximumArtisanWorkers: 6,
                maximumLaborerWorkers: 16,
                tasksPerLaborer: 14,
                tasksPerFigure80: 10,
                tasksPerFigure81: 6,
                tasksPerFigure82: 6
            )
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.providerCapacityRules,
            [
                .init(figureID: 10, baseCapacity: 3),
                .init(figureID: 80, baseCapacity: 1),
                .init(figureID: 81, baseCapacity: 1),
                .init(figureID: 82, baseCapacity: 1),
            ]
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.efficiencyCapacityPenalties,
            [
                .init(efficiencyBelow: 50, capacityPenalty: 3),
                .init(efficiencyBelow: 70, capacityPenalty: 2),
                .init(efficiencyBelow: 80, capacityPenalty: 1),
            ]
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.workerMovementRules,
            [10, 82, 19].map {
                .init(
                    figureID: $0,
                    figureModelSpeedValue: 8,
                    relativeSpeedNumerator: 4,
                    relativeSpeedDenominator: 3,
                    substepsPerFigureUpdateCycle: [1, 1, 2],
                    substepsPerRouteStep: 20,
                    initialSubstepProgress: 20
                )
            }
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.workerPathfindingRule,
            .init(
                primaryMovementMode: 1,
                primaryPassabilityMask: 0x0B0C,
                primaryAdmitsNonzeroMaskIntersection: true,
                fallbackMovementMode: 19,
                fallbackRuntimeCellMask: 0x4C001CCE,
                fallbackAdmitsNonzeroMaskIntersection: true,
                fallbackMaximumExpansions: 100_000,
                cardinalBreadthFirstSearch: true,
                maximumStoredDirections: 500,
                firstPathBufferSlot: 1,
                lastPathBufferSlot: 999,
                blockedDirection: 9,
                unreachableDirection: 10,
                retainsRouteWhileBlocked: true,
                retriesUnreachableRouteOnNextUpdate: true,
                usesFigureCollisionLinking: false
            )
        )
        let primaryMask = OriginalGrandCanalLayoutCatalog.workerPathfindingRule
            .primaryPassabilityMask
        XCTAssertEqual(
            (0..<16).compactMap { bit in
                primaryMask & (1 << bit) == 0 ? nil : 1 << bit
            },
            [0x4, 0x8, 0x100, 0x200, 0x800]
        )
        XCTAssertNotEqual(0x4 & primaryMask, 0)
        XCTAssertEqual(0x10 & primaryMask, 0)
        let fallbackMask = OriginalGrandCanalLayoutCatalog.workerPathfindingRule
            .fallbackRuntimeCellMask
        XCTAssertNotEqual(0x40000020 & fallbackMask, 0)
        XCTAssertNotEqual(0x4C000800 & fallbackMask, 0)
        XCTAssertEqual(0x10000200 & fallbackMask, 0)
        XCTAssertEqual(0x20000100 & fallbackMask, 0)
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.workerRoutingGridRule,
            .init(
                gridSide: 228,
                serializedTerrainCellByteCount: 4,
                primaryCellByteCount: 2,
                fallbackCellByteCount: 4,
                primaryResetValue: 0,
                fallbackResetValue: 0x80000001,
                serializedTerrainLoadsDirectlyIntoRuntimeLayer: true,
                derivedGridsAreSerialized: false,
                liveBuildingOccupancyParticipates: true,
                fullRebuildOrder: [.primaryPassability, .fallbackCellClass],
                localRebuildOrder: [.primaryPassability, .fallbackCellClass]
            )
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.primaryRoutingClassRule,
            .init(
                baseProducedValues: [
                    0x1, 0x2, 0x4, 0x10, 0x20, 0x80,
                    0x100, 0x400, 0x1000, 0x4000,
                ],
                postprocessedProducedMasks: [0x200, 0x800],
                admittedProducedValues: [0x4, 0x100, 0x200, 0x800],
                admittedMaskBitsWithoutRecoveredProducer: [0x8],
                bareLandValue: 0x10,
                roadValue: 0x4,
                blockedValue: 0x2,
                roadOnTerrainBit0x400Value: 0x100,
                ferryBuildingID: 210,
                ferryFootprintSide: 6,
                ferryFootprintMask: 0x800,
                ferryConnectorMask: 0x200,
                ferryConnectorDirectionCodes: [0, 2, 4, 6],
                ferryPostprocessingRunsAfterBaseDerivation: true
            )
        )
        XCTAssertNotEqual(
            Int(OriginalGrandCanalLayoutCatalog.primaryRoutingClassRule.ferryFootprintMask)
                & primaryMask,
            0
        )
        XCTAssertNotEqual(
            Int(OriginalGrandCanalLayoutCatalog.primaryRoutingClassRule.ferryConnectorMask)
                & primaryMask,
            0
        )
        let fallbackClasses = OriginalGrandCanalLayoutCatalog.fallbackRoutingClassRule
        XCTAssertEqual(
            fallbackClasses.producedValues,
            [
                0x2, 0x4, 0x8, 0x40,
                0x10000200, 0x20000100, 0x40000010, 0x40000020,
                0x48000400, 0x4C000800, 0x4C001000, 0x80000001,
            ]
        )
        XCTAssertEqual(
            fallbackClasses.producedValues.filter(
                OriginalGrandCanalLayoutCatalog.fallbackRouteAdmits(runtimeCellClass:)
            ),
            fallbackClasses.admittedProducedValues
        )
        XCTAssertEqual(
            fallbackClasses.producedValues.filter {
                !OriginalGrandCanalLayoutCatalog.fallbackRouteAdmits(runtimeCellClass: $0)
            },
            fallbackClasses.rejectedProducedValues
        )
        XCTAssertEqual(fallbackClasses.grandCanalBuildingID, 83)
        XCTAssertEqual(fallbackClasses.monumentStateBuildingOffset, 0xC8)
        XCTAssertEqual(fallbackClasses.monumentStateAccessorVtableOffset, 0x1EC)
        XCTAssertEqual(fallbackClasses.monumentSubBuildingPhaseOffset, 0x08)
        XCTAssertEqual(fallbackClasses.grandCanalActivePhaseLowerBound, 1)
        XCTAssertEqual(
            [
                fallbackClasses.grandCanalInactiveValue,
                fallbackClasses.grandCanalActiveWithoutRoadValue,
                fallbackClasses.grandCanalActiveWithRoadValue,
            ].map(OriginalGrandCanalLayoutCatalog.fallbackRouteAdmits(runtimeCellClass:)),
            [true, true, true]
        )
        XCTAssertEqual(fallbackClasses.cityGateBuildingID, 130)
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.fallbackRouteAdmits(
                runtimeCellClass: fallbackClasses.cityGateValue
            )
        )
        XCTAssertEqual(fallbackClasses.towerBuildingID, 131)
        XCTAssertTrue(
            OriginalGrandCanalLayoutCatalog.fallbackRouteAdmits(
                runtimeCellClass: fallbackClasses.towerValue
            )
        )
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.schedulerTicksWithoutActiveWorkQueues, 30)
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.schedulerTicksWithActiveWorkQueues, 50)
        XCTAssertTrue(
            OriginalGrandCanalLayoutCatalog.isAutomaticallyScheduledFromPredeterminedMapObject
        )
        XCTAssertEqual(OriginalGrandCanalLayoutCatalog.campaignGoalCompletionPercent, 100)
        XCTAssertTrue(
            OriginalGrandCanalLayoutCatalog.campaignGoalsEvaluatedAtMonthlySettlement
        )
        XCTAssertTrue(OriginalGrandCanalLayoutCatalog.campaignVictoryRequiresAllGoals)
        XCTAssertTrue(OriginalGrandCanalLayoutCatalog.usesGenericCampaignVictoryTransition)
        XCTAssertFalse(
            OriginalGrandCanalLayoutCatalog.hasCanalSpecificPostPhaseCompletionBranch
        )
    }

    func testRecoveredWorkerRouteUsesPrimaryThenMode19Fallback() throws {
        let width = 5
        let height = 5
        let start = GridPoint(x: 0, y: 2)
        let destination = GridPoint(x: 4, y: 2)
        var primary = [UInt16](repeating: 0x10, count: width * height)
        var fallback = [UInt32](repeating: 0x80000001, count: width * height)
        for x in 0..<width {
            primary[2 * width + x] = 0x4
            fallback[2 * width + x] = 0x2
        }

        let primaryRoute = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.workerRoute(
                primaryValues: primary,
                fallbackValues: fallback,
                width: width,
                height: height,
                from: start,
                to: destination
            )
        )
        XCTAssertEqual(primaryRoute.grid, .primaryPassability)
        XCTAssertEqual(primaryRoute.directionCodes, [2, 2, 2, 2])
        XCTAssertEqual(primaryRoute.points.first, start)
        XCTAssertEqual(primaryRoute.points.last, destination)

        primary = [UInt16](repeating: 0x10, count: width * height)
        fallback = [UInt32](repeating: 0x80000001, count: width * height)
        for point in [
            GridPoint(x: 0, y: 2), GridPoint(x: 0, y: 1),
            GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1),
            GridPoint(x: 3, y: 1), GridPoint(x: 4, y: 1),
            GridPoint(x: 4, y: 2),
        ] {
            fallback[point.y * width + point.x] = 0x2
        }
        let fallbackRoute = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.workerRoute(
                primaryValues: primary,
                fallbackValues: fallback,
                width: width,
                height: height,
                from: start,
                to: destination
            )
        )
        XCTAssertEqual(fallbackRoute.grid, .fallbackCellClass)
        XCTAssertEqual(fallbackRoute.points.first, start)
        XCTAssertEqual(fallbackRoute.points.last, destination)
        XCTAssertEqual(fallbackRoute.directionCodes, [1, 2, 2, 3])

        fallback = [UInt32](repeating: 0x80000001, count: width * height)
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.workerRoute(
                primaryValues: primary,
                fallbackValues: fallback,
                width: width,
                height: height,
                from: start,
                to: destination
            )
        )
    }

    func testPhaseTwoCarrierModeSevenUsesOnlyPrimaryMask0x12C() throws {
        let accepted: [UInt16] = [0x4, 0x8, 0x20, 0x100]
        let route = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.phaseTwoCarrierRoute(
                primaryValues: accepted,
                width: 4,
                height: 1,
                from: .init(x: 0, y: 0),
                to: .init(x: 3, y: 0)
            )
        )
        XCTAssertEqual(route.grid, .primaryPassability)
        XCTAssertEqual(route.directionCodes, [2, 2, 2])

        for rejected: UInt16 in [0x2, 0x10, 0x200, 0x800] {
            XCTAssertNil(
                OriginalGrandCanalLayoutCatalog.phaseTwoCarrierRoute(
                    primaryValues: [0x4, rejected, 0x4],
                    width: 3,
                    height: 1,
                    from: .init(x: 0, y: 0),
                    to: .init(x: 2, y: 0)
                )
            )
        }
    }

    func testResidentialServiceReturnUsesRecoveredModeZeroMaskAndRouteOrder() throws {
        let accepted: [UInt16] = [0x1, 0x4, 0x8, 0x10, 0x100, 0x200, 0x800]
        for value in accepted {
            let route = try XCTUnwrap(
                OriginalGrandCanalLayoutCatalog.residentialServiceReturnRoute(
                    primaryValues: [0x4, value, 0x4],
                    width: 3,
                    height: 1,
                    from: .init(x: 0, y: 0),
                    to: .init(x: 2, y: 0)
                )
            )
            XCTAssertEqual(route.grid, .primaryPassability)
            XCTAssertEqual(route.points, [
                .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 2, y: 0),
            ])
            XCTAssertEqual(route.directionCodes, [2, 2])
        }

        for value: UInt16 in [0x2, 0x20, 0x40, 0x80, 0x400, 0x1000] {
            XCTAssertNil(
                OriginalGrandCanalLayoutCatalog.residentialServiceReturnRoute(
                    primaryValues: [0x4, value, 0x4],
                    width: 3,
                    height: 1,
                    from: .init(x: 0, y: 0),
                    to: .init(x: 2, y: 0)
                )
            )
        }
    }

    func testEntertainmentVenueRouteUsesRecoveredMode12PrimaryMask() throws {
        let route = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.entertainmentVenueRoute(
                primaryValues: [0x4, 0x100, 0x4],
                width: 3,
                height: 1,
                from: .init(x: 0, y: 0),
                to: .init(x: 2, y: 0)
            )
        )
        XCTAssertEqual(route.grid, .primaryPassability)
        XCTAssertEqual(route.points, [
            .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 2, y: 0),
        ])
        XCTAssertEqual(route.directionCodes, [2, 2])

        for value: UInt16 in [0x1, 0x2, 0x10, 0x20, 0x40, 0x80, 0x200, 0x400] {
            XCTAssertNil(
                OriginalGrandCanalLayoutCatalog.entertainmentVenueRoute(
                    primaryValues: [0x4, value, 0x4],
                    width: 3,
                    height: 1,
                    from: .init(x: 0, y: 0),
                    to: .init(x: 2, y: 0)
                )
            )
        }
    }

    func testMarketPeddlerRouteUsesSharedMode12PrimaryMask() throws {
        let route = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.marketPeddlerRoute(
                primaryValues: [0x4, 0x100, 0x4],
                width: 3,
                height: 1,
                from: .init(x: 0, y: 0),
                to: .init(x: 2, y: 0)
            )
        )
        XCTAssertEqual(route.grid, .primaryPassability)
        XCTAssertEqual(route.points, [
            .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 2, y: 0),
        ])
        XCTAssertEqual(route.directionCodes, [2, 2])

        for value: UInt16 in [0x1, 0x2, 0x10, 0x20, 0x40, 0x80, 0x200, 0x400] {
            XCTAssertNil(
                OriginalGrandCanalLayoutCatalog.marketPeddlerRoute(
                    primaryValues: [0x4, value, 0x4],
                    width: 3,
                    height: 1,
                    from: .init(x: 0, y: 0),
                    to: .init(x: 2, y: 0)
                )
            )
        }
    }

    func testEntertainmentDirectionalRouteUsesCurrentCellForEastAdmission() throws {
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.entertainmentVenueDirectionalRoute(
                width: 3,
                height: 1,
                from: .init(x: 0, y: 0),
                to: .init(x: 2, y: 0),
                northLayer: [0, 0, 0],
                eastLayer: [0x100, 0, 0],
                southLayer: [0, 0, 0],
                westLayer: [0, 0, 0]
            )
        )

        let route = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.entertainmentVenueDirectionalRoute(
                width: 3,
                height: 1,
                from: .init(x: 0, y: 0),
                to: .init(x: 2, y: 0),
                northLayer: [0, 0, 0],
                eastLayer: [0x100, 0x100, 0],
                southLayer: [0, 0, 0],
                westLayer: [0, 0, 0]
            )
        )
        XCTAssertEqual(route.points, [
            .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 2, y: 0),
        ])

        let diagonal = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.entertainmentVenueDirectionalRoute(
                width: 2,
                height: 2,
                from: .init(x: 0, y: 0),
                to: .init(x: 1, y: 1),
                northLayer: [0x100, 0x100, 0x100, 0x100],
                eastLayer: [0x100, 0x100, 0x100, 0x100],
                southLayer: [0x100, 0x100, 0x100, 0x100],
                westLayer: [0x100, 0x100, 0x100, 0x100]
            )
        )
        XCTAssertEqual(
            diagonal.points,
            [
                .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1),
            ],
            "FUN_005B18B0 chooses the first cardinal tie when direct direction is diagonal"
        )
    }

    func testEntertainmentProviderRouteUsesWeightedModeOnePrimaryMask() throws {
        let route = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.entertainmentVenueProviderRoute(
                primaryValues: [0x4, 0x200, 0x4],
                width: 3,
                height: 1,
                from: .init(x: 0, y: 0),
                to: .init(x: 2, y: 0)
            )
        )
        XCTAssertEqual(route.points, [
            .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 2, y: 0),
        ])
        XCTAssertEqual(route.directionCodes, [2, 2])

        for value: UInt16 in [0x1, 0x2, 0x10, 0x20, 0x40, 0x80, 0x400, 0x1000] {
            XCTAssertNil(
                OriginalGrandCanalLayoutCatalog.entertainmentVenueProviderRoute(
                    primaryValues: [0x4, value, 0x4],
                    width: 3,
                    height: 1,
                    from: .init(x: 0, y: 0),
                    to: .init(x: 2, y: 0)
                )
            )
        }
    }

    func testEntertainmentProviderChooserPreservesRecoveredWeightedTieOrder() {
        let candidates = [
            OriginalGrandCanalLayoutCatalog.EntertainmentVenueRouteCandidate(
                ordinal: 0,
                target: .init(x: 1, y: 0),
                baseWeight: 10
            ),
            OriginalGrandCanalLayoutCatalog.EntertainmentVenueRouteCandidate(
                ordinal: 1,
                target: .init(x: 3, y: 0),
                baseWeight: 1
            ),
        ]
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidate(
                primaryValues: [0x4, 0x4, 0x4, 0x200],
                width: 4,
                height: 1,
                from: .init(x: 0, y: 0),
                candidates: candidates
            ),
            2
        )

        let tied = candidates.map {
            OriginalGrandCanalLayoutCatalog.EntertainmentVenueRouteCandidate(
                ordinal: $0.ordinal,
                target: $0.target,
                baseWeight: $0.ordinal == 0 ? 2 : 0
            )
        }
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidate(
                primaryValues: [0x4, 0x4, 0x4, 0x200],
                width: 4,
                height: 1,
                from: .init(x: 0, y: 0),
                candidates: tied
            ),
            1
        )

        let nineEqualCandidates = (0..<9).map {
            OriginalGrandCanalLayoutCatalog.EntertainmentVenueRouteCandidate(
                ordinal: $0,
                target: .init(x: 0, y: 0),
                baseWeight: 0
            )
        }
        // The >8 quicksort path moves its middle pivot to the left before the
        // reverse scan; with all equal weights this leaves ordinal 8 first.
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidate(
                primaryValues: [0x4],
                width: 1,
                height: 1,
                from: .init(x: 0, y: 0),
                candidates: nineEqualCandidates
            ),
            9
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidate(
                primaryValues: [0x4, 0x400, 0x4],
                width: 3,
                height: 1,
                from: .init(x: 0, y: 0),
                candidates: [
                    .init(ordinal: 0, target: .init(x: 1, y: 0), baseWeight: 0),
                ]
            )
        )
    }

    func testEntertainmentVenueCandidateFloodPreservesSourceMasksAndOrder() {
        let candidate = [GridPoint(x: 2, y: 0)]
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex(
                primaryValues: [0x4, 0x1, 0x4], width: 3, height: 1,
                from: .init(x: 0, y: 0), candidatePoints: candidate,
                mode: .residentialModeZero
            ),
            1
        )
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex(
                primaryValues: [0x4, 0x400, 0x4], width: 3, height: 1,
                from: .init(x: 0, y: 0), candidatePoints: candidate,
                mode: .residentialModeZero
            )
        )

        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex(
                primaryValues: [0x4, 0x200, 0x4], width: 3, height: 1,
                from: .init(x: 0, y: 0), candidatePoints: candidate,
                mode: .venueModeZero
            )
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex(
                primaryValues: [0x4, 0x200, 0x4], width: 3, height: 1,
                from: .init(x: 0, y: 0), candidatePoints: candidate,
                mode: .venueModeOne
            ),
            1
        )

        let duplicate = [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 0)]
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex(
                primaryValues: [0x4], width: 1, height: 1,
                from: .init(x: 0, y: 0), candidatePoints: duplicate,
                mode: .residentialModeZero
            ),
            2
        )
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex(
                primaryValues: [0x4], width: 1, height: 1,
                from: .init(x: 0, y: 0), candidatePoints: duplicate,
                mode: .venueModeZero
            ),
            1
        )

        let northAndEast = [GridPoint(x: 2, y: 1), GridPoint(x: 1, y: 0)]
        XCTAssertEqual(
            OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex(
                primaryValues: Array(repeating: 0x4, count: 9), width: 3, height: 3,
                from: .init(x: 1, y: 1), candidatePoints: northAndEast,
                mode: .venueModeZero
            ),
            2
        )
    }

    func testPhaseTwoCarrierMovementUsesOriginalSpeedAndArrivalBoundary() throws {
        var convoy = OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime(
            carrierFigureID: 800,
            firstHelperFigureID: 801,
            secondHelperFigureID: 802,
            sourceObjectID: 90,
            sourceBuildingID: 54,
            commodityID: 20,
            sourceOrigin: .init(x: 0, y: 0),
            monumentAccessPoint: .init(x: 2, y: 0),
            cargoUnits: 400
        )
        let grids = OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids(
            width: 3,
            height: 1,
            primaryPassability: [0x4, 0x4, 0x4],
            fallbackCellClass: [0x80000001, 0x80000001, 0x80000001]
        )

        XCTAssertTrue(convoy.advanceMovement(routingGrids: grids))
        XCTAssertEqual(convoy.currentPoint, .init(x: 1, y: 0))
        XCTAssertEqual(convoy.carrierState, .travelingToMonument)

        for _ in 0..<14 {
            XCTAssertFalse(convoy.advanceMovement(routingGrids: grids))
        }
        XCTAssertEqual(convoy.currentPoint, .init(x: 1, y: 0))
        XCTAssertTrue(convoy.advanceMovement(routingGrids: grids))
        XCTAssertEqual(convoy.currentPoint, .init(x: 2, y: 0))
        XCTAssertEqual(convoy.carrierState, .allocatingAtMonument)
        XCTAssertNil(convoy.movement)

        let data = try JSONEncoder().encode(convoy)
        XCTAssertEqual(
            try JSONDecoder().decode(
                OriginalGrandCanalLayoutCatalog.PhaseTwoCarrierConvoyRuntime.self,
                from: data
            ),
            convoy
        )
    }

    func testRecoveredWorkerRouteRejectsTheOriginalFiveHundredStepBoundary() throws {
        func route(width: Int) -> OriginalGrandCanalLayoutCatalog.WorkerRoute? {
            OriginalGrandCanalLayoutCatalog.workerRoute(
                primaryValues: [UInt16](repeating: 0x4, count: width),
                fallbackValues: [UInt32](repeating: 0x2, count: width),
                width: width,
                height: 1,
                from: GridPoint(x: 0, y: 0),
                to: GridPoint(x: width - 1, y: 0)
            )
        }

        XCTAssertEqual(route(width: 500)?.directionCodes.count, 499)
        XCTAssertNil(route(width: 501))
    }

    func testAuthoredGrandCanalWorkerSpeedsMatchRecoveredMovementRules() throws {
        let sourceURL = GameDataSource.defaultRoot
            .appendingPathComponent("Model/EmperorFigureModels.txt")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let figures = try FigureModelTable(contentsOf: sourceURL)

        for rule in OriginalGrandCanalLayoutCatalog.workerMovementRules {
            XCTAssertEqual(figures[figureID: rule.figureID]?.speed, 8)
        }
    }

    func testAuthoredHeroThreeIsXiWangMu() throws {
        let sourceURL = GameDataSource.defaultRoot
            .appendingPathComponent("Model/EmperorFigureModels.txt")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("Original Emperor model data is not installed")
        }
        let text = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(text.contains("3,Xiwangmu (Daoist)"))
    }

    func testQinFirstMissionAuthoredGoalTargetsGrandCanal() throws {
        let campaignURL = GameDataSource.defaultRoot
            .appendingPathComponent("Campaigns/4 Qin Dynasty.pak")
        guard FileManager.default.fileExists(atPath: campaignURL.path) else {
            throw XCTSkip("Original Emperor campaign data is not installed")
        }
        let campaign = try CampaignArchive(url: campaignURL)
        let mission = try XCTUnwrap(
            CampaignGoalArchive(
                campaignURL: campaignURL,
                missionCount: campaign.missions.count
            ).missions.first
        )
        let monument = try XCTUnwrap(mission.goals.first { $0.kind == .monument })

        XCTAssertEqual(campaign.missions.first?.title, "Zheng Guo's Canal")
        XCTAssertEqual(monument.typeID, 2)
        XCTAssertEqual(monument.variant, 2)
        XCTAssertEqual(monument.values, [83, 0])
        XCTAssertEqual(monument.requirement, .monument(buildingID: 83))
    }

    func testQinFirstMissionVictoryRequiresCanalAndProductionGoalsTogether() throws {
        let campaignURL = GameDataSource.defaultRoot
            .appendingPathComponent("Campaigns/4 Qin Dynasty.pak")
        guard FileManager.default.fileExists(atPath: campaignURL.path) else {
            throw XCTSkip("Original Emperor campaign data is not installed")
        }
        let campaign = try CampaignArchive(url: campaignURL)
        let mission = try XCTUnwrap(
            CampaignGoalArchive(
                campaignURL: campaignURL,
                missionCount: campaign.missions.count
            ).missions.first
        )
        var progress = CampaignGoalProgressSnapshot(
            completedMonumentBuildingIDs: [83]
        )

        XCTAssertFalse(CampaignGoalEvaluator.missionIsComplete(mission, against: progress))
        progress.bestYearlyProductionUnitsByCommodityID[15] = 1_800
        XCTAssertTrue(CampaignGoalEvaluator.missionIsComplete(mission, against: progress))
    }

    func testHaunxianMapMatchesTheCompleteAuthoredReserve() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        let placement = try XCTUnwrap(
            OriginalGrandCanalLayoutCatalog.campaignPlacement(in: map)
        )
        XCTAssertEqual(placement.origin, GridPoint(x: 4, y: 68))
        XCTAssertEqual(placement.quarterTurnsClockwise, 0)

        let parts = OriginalGrandCanalLayoutCatalog.placedSubBuildings(for: placement)
        XCTAssertEqual(parts.map(\.index), Array(0..<33))
        XCTAssertEqual(parts.filter(\.isRoadCrossing).map(\.index), [10, 16, 22])
        XCTAssertEqual(parts.first?.worldOrigin, GridPoint(x: 4, y: 68))
        XCTAssertEqual(parts.last?.worldOrigin, GridPoint(x: 132, y: 68))
        XCTAssertEqual(Set(parts.flatMap(\.footprintCells)).count, 528)

        let terrain = DeterministicTerrainState(map: map)
        XCTAssertEqual(terrain.grandCanalPlacement, placement)
        XCTAssertEqual(
            try JSONDecoder().decode(
                DeterministicTerrainState.self,
                from: JSONEncoder().encode(terrain)
            ).grandCanalPlacement,
            placement
        )
    }

    func testOrdinaryCampaignMapDoesNotProduceFalseCanalPlacement() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Erlitou.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        XCTAssertNil(
            OriginalGrandCanalLayoutCatalog.campaignPlacement(
                in: try EmperorMap(url: mapURL)
            )
        )
    }

    func testLegacyNativeRuntimeStillDecodesWithoutBecomingOriginalEvidence() throws {
        let legacy = GrandCanalProjectRuntime(projectID: 7)
        let data = try JSONEncoder().encode(legacy)
        XCTAssertEqual(
            try JSONDecoder().decode(GrandCanalProjectRuntime.self, from: data),
            legacy
        )
        XCTAssertEqual(legacy.segments.count, 33)
        XCTAssertFalse(legacy.isComplete)
    }

    func testTerrainSaveBeforeMapPlacementFieldsStillDecodes() throws {
        let legacyJSON = Data(
            #"{"width":1,"height":1,"terrainRawValues":[0],"authoredPoints":null}"#.utf8
        )
        let terrain = try JSONDecoder().decode(
            DeterministicTerrainState.self,
            from: legacyJSON
        )
        XCTAssertNil(terrain.grandCanalPlacement)
        XCTAssertNil(terrain.greatWallPlacement)
    }
}
