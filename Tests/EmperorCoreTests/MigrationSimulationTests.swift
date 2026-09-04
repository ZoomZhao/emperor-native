import EmperorCore
import XCTest

final class MigrationSimulationTests: XCTestCase {
    func testOriginalAuthoredTerrainWordsUseRecoveredCenteredBackingIndex() throws {
        let side = 112
        var raw = [UInt32](repeating: 0, count: side * side)
        raw[56 * side + 55] = 0xC2_0000
        let terrain = try DeterministicTerrainState(
            width: side,
            height: side,
            terrainRawValues: raw
        )
        let words = try XCTUnwrap(terrain.originalAuthoredTerrainWords())
        let descriptor = try XCTUnwrap(
            OriginalMapRuntimeDescriptorCatalog.descriptor(width: side, height: side)
        )
        XCTAssertEqual(words.count, side * side)
        XCTAssertEqual(words[descriptor.baseLinearOffset], 0)
        XCTAssertEqual(
            words[descriptor.baseLinearOffset + 7 * descriptor.effectiveRowStride + 9],
            0
        )
        XCTAssertEqual(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 56, y: 56),
                terrain: terrain
            ),
            1
        )
        XCTAssertNil(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 0, y: 0),
                terrain: terrain
            )
        )
    }

    func testOriginalFengShuiTerrainClassificationMatchesEightByEightWindow() {
        let base = 10_000
        let stride = OriginalMapObjectGridProjection.mapRowStride
        func index(_ x: Int, _ y: Int) -> Int {
            base + y * stride + x
        }

        var words: [Int: UInt32] = [:]
        for y in -4...3 {
            for x in -4...3 {
                words[index(x, y)] = 0
            }
        }
        // Category 1 uses the nearest word carrying 0xC20000 (with bit 0 clear).
        words[index(-1, 0)] = 0xC2_0000
        XCTAssertEqual(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 0, y: 0),
                mapWords: words,
                baseLinearOffset: base
            ),
            1
        )

        // Category 2 accepts either 0x100002 or 0x200002 in the masked kind.
        words[index(-1, 0)] = 0x100002
        XCTAssertEqual(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 0, y: 0),
                mapWords: words,
                baseLinearOffset: base
            ),
            2
        )

        // Bit 0 routes the nearest cell into the source's category-4 slot; the
        // result is 4 when that distance beats category 2.
        words[index(-1, 0)] = 1
        XCTAssertEqual(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 0, y: 0),
                mapWords: words,
                baseLinearOffset: base
            ),
            4
        )
    }

    func testOriginalFengShuiTerrainClassificationFallbackAndMissingInputFailClosed() {
        let base = 2_000
        let stride = OriginalMapObjectGridProjection.mapRowStride
        func index(_ x: Int, _ y: Int) -> Int {
            base + y * stride + x
        }

        var clearWords: [Int: UInt32] = [:]
        for y in -4...3 {
            for x in -4...3 {
                clearWords[index(x, y)] = 0
            }
        }
        XCTAssertEqual(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 0, y: 0),
                mapWords: clearWords,
                baseLinearOffset: base
            ),
            5
        )
        clearWords[index(0, 0)] = 0x4000000
        XCTAssertEqual(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 0, y: 0),
                mapWords: clearWords,
                baseLinearOffset: base
            ),
            3
        )
        clearWords.removeValue(forKey: index(3, 3))
        XCTAssertNil(
            OriginalFengShuiTerrainClassification.classify(
                center: .init(x: 0, y: 0),
                mapWords: clearWords,
                baseLinearOffset: base
            )
        )
    }

    func testOriginalFengShuiWeightAggregateMatchesSpecialModelAndSmallValueBranches() {
        let aggregate = DeterministicMigration.originalFengShuiWeightAggregate(
            globalGateOpen: true,
            records: [
                .init(modelID: 1, placementValue: 1),
                .init(modelID: 2, placementValue: -1),
                .init(modelID: 3, placementValue: 4, state16: 0),
                .init(modelID: 0x4C, placementValue: 4, state16: 1),
                .init(modelID: 0x4C, placementValue: 4, state16: 0),
                .init(modelID: 4, placementValue: 0)
            ]
        )

        XCTAssertEqual(aggregate.acceptedRecordCount, 5)
        XCTAssertEqual(aggregate.totalWeight, 1 + 1 + 4 + 4)
        XCTAssertEqual(aggregate.harmoniousWeight, 1 + 4 + 4)
    }

    func testOriginalFengShuiWeightAggregateRespectsGlobalGateAndSpecialModelTable() {
        XCTAssertTrue(DeterministicMigration.originalFengShuiSpecialModel(modelID: 0x4C))
        XCTAssertTrue(DeterministicMigration.originalFengShuiSpecialModel(modelID: 0x10C))
        XCTAssertFalse(DeterministicMigration.originalFengShuiSpecialModel(modelID: 0x4B))

        let closed = DeterministicMigration.originalFengShuiWeightAggregate(
            globalGateOpen: false,
            records: [.init(modelID: 1, placementValue: 7)]
        )
        XCTAssertEqual(
            closed,
            .init(totalWeight: 0, harmoniousWeight: 0, acceptedRecordCount: 0)
        )
    }

    func testFengShuiConsumerDirectCallsitesMatchCanonicalPECensus() {
        XCTAssertEqual(
            DeterministicMigration.fengShuiConsumerDirectCallSiteAddresses,
            [0x0053C078, 0x0059129E, 0x0059165B, 0x005B8C08]
        )
    }

    func testMonthlyPopularityScheduleMatchesCanonicalPhaseBoundary() {
        XCTAssertEqual(OriginalMonthlyPopularitySchedule.tickDriverAddress, 0x005371A0)
        XCTAssertEqual(OriginalMonthlyPopularitySchedule.phaseDispatcherAddress, 0x004AC2B0)
        XCTAssertEqual(OriginalMonthlyPopularitySchedule.boundaryAddress, 0x004AC650)
        XCTAssertEqual(OriginalMonthlyPopularitySchedule.popularityProducerAddress, 0x00591200)
        XCTAssertEqual(OriginalMonthlyPopularitySchedule.dispatcherPhaseCount, 0x33)
        XCTAssertEqual(OriginalMonthlyPopularitySchedule.producerBoundarySlices, [0, 8])
    }

    func testOriginalHousingStatusScanPreservesVectorStartAndIntegerBoundaries() {
        let noObjects = OriginalHousingStatusScan.scan([])
        XCTAssertEqual(noObjects.compositionStatus, 0x17)
        XCTAssertEqual(noObjects.advisorStatus, 0x98)

        let mixed = OriginalHousingStatusScan.scan([
            // The source starts at vector index 1, so this record is ignored.
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x51),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x46),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x47),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x50),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x51)
        ])
        // Middle=2/4=50%, high=1/4=25%; both comparisons are strict on the
        // advisor path, while composition uses the corresponding < tests.
        XCTAssertEqual(mixed.eligibleCount, 4)
        XCTAssertEqual(mixed.middleBucketPercent, 50)
        XCTAssertEqual(mixed.highBucketPercent, 25)
        XCTAssertEqual(mixed.compositionStatus, 0x15)
        XCTAssertEqual(mixed.advisorStatus, 0x95)

        let middleMajority = OriginalHousingStatusScan.scan([
            .init(globalGateOpen: false, populationPredicatePasses: true, statusWord: 0x47),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x47),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x47),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x46)
        ])
        XCTAssertEqual(middleMajority.middleBucketPercent, 66)
        XCTAssertEqual(middleMajority.compositionStatus, 0x12)
        XCTAssertEqual(middleMajority.advisorStatus, 0x93)

        let highBand = OriginalHousingStatusScan.scan([
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x51),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x51),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x51),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x46),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x46),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x46),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x46),
            .init(globalGateOpen: true, populationPredicatePasses: true, statusWord: 0x46)
        ])
        // 2/7 truncates to 28%, admitting the high-band branch.
        XCTAssertEqual(highBand.highBucketPercent, 28)
        XCTAssertEqual(highBand.compositionStatus, 0x13)
        XCTAssertEqual(highBand.advisorStatus, 0x94)
        XCTAssertEqual(OriginalHousingStatusScan.integerPercent(1, 9), 11)
    }

    func testOriginalHousingStatusEventBridgePreservesRepeatSuppression() {
        XCTAssertEqual(
            OriginalHousingStatusScan.eventID(previousAdvisorStatus: 0, currentAdvisorStatus: 0x93),
            0xD6
        )
        XCTAssertEqual(
            OriginalHousingStatusScan.eventID(previousAdvisorStatus: 0x94, currentAdvisorStatus: 0x96),
            0xD9
        )
        XCTAssertEqual(
            OriginalHousingStatusScan.eventID(previousAdvisorStatus: 0x97, currentAdvisorStatus: 0x97),
            nil
        )
        XCTAssertEqual(
            OriginalHousingStatusScan.eventID(previousAdvisorStatus: 0x97, currentAdvisorStatus: 0x98),
            0xDB
        )
        XCTAssertNil(
            OriginalHousingStatusScan.eventID(previousAdvisorStatus: 0, currentAdvisorStatus: 0x01)
        )
    }

    func testFengShuiPlacementProducerDirectCallsitesMatchCanonicalPECensus() {
        XCTAssertEqual(
            OriginalFengShuiPlacementProducer.directCallSiteAddresses,
            [
                0x004150A9, 0x0042B55D, 0x004B2516, 0x004B2882,
                0x00540F34, 0x00542B16, 0x00544C53
            ]
        )
    }

    func testOriginalFengShuiPlacementFixedModelValues() throws {
        let counts = DeterministicMigration.OriginalFengShuiPlacementCounts(
            slot1: 9,
            slot2: 8,
            slot3: 7,
            slot4: 6,
            slot5: 5
        )

        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 0,
                    counts: counts
                )
            ),
            .init(modelValue: 0, result: 0, usedCounterSlots: false, diagnosticSlot: nil)
        )
        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 6,
                    counts: counts
                )
            ),
            .init(modelValue: 6, result: -1, usedCounterSlots: false, diagnosticSlot: nil)
        )
        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 7,
                    counts: counts
                )
            ),
            .init(modelValue: 7, result: 1, usedCounterSlots: false, diagnosticSlot: nil)
        )
        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 8,
                    counts: counts
                )
            ),
            .init(modelValue: 8, result: 8, usedCounterSlots: false, diagnosticSlot: nil)
        )
    }

    func testOriginalFengShuiPlacementCounterPairsAndDiagnosticOrder() throws {
        let harmonious = try XCTUnwrap(
            DeterministicMigration.originalFengShuiPlacementResult(
                modelValue: 1,
                counts: .init()
            )
        )
        XCTAssertEqual(harmonious.result, 1)
        XCTAssertNil(harmonious.diagnosticSlot)

        let lastConflictWins = try XCTUnwrap(
            DeterministicMigration.originalFengShuiPlacementResult(
                modelValue: 1,
                counts: .init(slot3: 1, slot4: 1)
            )
        )
        XCTAssertEqual(lastConflictWins.result, -1)
        XCTAssertEqual(lastConflictWins.diagnosticSlot, 4)

        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 2,
                    counts: .init(slot4: 1)
                )
            ).diagnosticSlot,
            4
        )
        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 3,
                    counts: .init(slot1: 1, slot5: 1)
                )
            ).diagnosticSlot,
            5
        )
        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 4,
                    counts: .init(slot1: 1, slot2: 1)
                )
            ).diagnosticSlot,
            2
        )
        XCTAssertEqual(
            try XCTUnwrap(
                DeterministicMigration.originalFengShuiPlacementResult(
                    modelValue: 5,
                    counts: .init(slot2: 1, slot3: 1)
                )
            ).diagnosticSlot,
            2
        )
    }

    func testOriginalFengShuiPlacementRejectsUnsupportedNegativeInputs() {
        XCTAssertNil(
            DeterministicMigration.originalFengShuiPlacementResult(modelValue: -1)
        )
        XCTAssertNil(
            DeterministicMigration.originalFengShuiPlacementResult(
                modelValue: 1,
                counts: .init(slot4: -1)
            )
        )
    }

    func testExecutableBuildingGeometryCatalogMatchesPlacementTables() throws {
        XCTAssertEqual(OriginalBuildingGeometryCatalog.executableModelCount, 269)
        XCTAssertNil(
            OriginalBuildingGeometryCatalog.geometryGroup(forBuildingID: 269)
        )
        XCTAssertEqual(
            OriginalBuildingGeometryCatalog.geometryGroup(forBuildingID: 2),
            2
        )
        XCTAssertEqual(
            OriginalBuildingGeometryCatalog.footprint(forBuildingID: 2),
            BuildingFootprint(width: 2, height: 2)
        )
        XCTAssertEqual(
            OriginalBuildingGeometryCatalog.geometryGroup(forBuildingID: 37),
            3
        )
        XCTAssertEqual(
            OriginalBuildingGeometryCatalog.footprint(forBuildingID: 37),
            BuildingFootprint(width: 3, height: 3)
        )
        XCTAssertNil(OriginalBuildingGeometryCatalog.footprint(forBuildingID: 0))
        XCTAssertEqual(
            try XCTUnwrap(
                OriginalBuildingGeometryCatalog.relativeLinearOffsets(
                    forBuildingID: 2,
                    mapRotation: 0
                )
            ),
            [0, 228, 1, 229]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                OriginalBuildingGeometryCatalog.relativeLinearOffsets(
                    forBuildingID: 2,
                    mapRotation: 2
                )
            ),
            [684, 3, 685, 231]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                OriginalBuildingGeometryCatalog.relativeLinearOffsets(
                    forBuildingID: 53,
                    mapRotation: 0
                )
            ).count,
            25
        )
        XCTAssertEqual(
            try XCTUnwrap(
                OriginalBuildingGeometryCatalog.relativeLinearOffsets(
                    forBuildingID: 56,
                    mapRotation: 0
                )
            ).count,
            16
        )
    }

    func testCustomFengShuiSamplerDispatchRemainsSeparateFromGeometryTables() {
        let market = OriginalBuildingGeometryCatalog.customSampler(forBuildingID: 59)
        XCTAssertEqual(market?.allocationBytes, 0x14)
        XCTAssertEqual(market?.constructorAddress, 0x42CCD0)
        XCTAssertEqual(market?.vtableAddress, 0x7AB800)
        XCTAssertNil(market?.selector)

        let gate = OriginalBuildingGeometryCatalog.customSampler(forBuildingID: 130)
        XCTAssertEqual(gate?.constructorAddress, 0x4F8EA0)
        XCTAssertEqual(gate?.vtableAddress, 0x7B4180)
        XCTAssertEqual(gate?.selector, -1)

        let forts = [220: 3, 221: 0, 223: 2, 224: 1, 225: 4]
        for (buildingID, selector) in forts {
            let descriptor = OriginalBuildingGeometryCatalog.customSampler(
                forBuildingID: buildingID
            )
            XCTAssertEqual(descriptor?.constructorAddress, 0x4EF240)
            XCTAssertEqual(descriptor?.vtableAddress, 0x7B2BF0)
            XCTAssertEqual(descriptor?.selector, selector)
        }

        // Building 23 has a normal geometry group and must not be classified
        // as a custom callback merely because both paths share the producer.
        XCTAssertNil(
            OriginalBuildingGeometryCatalog.customSampler(forBuildingID: 23)
        )
    }

    func testMarketCustomGeometryBanksMatchRecoveredPEPointTables() throws {
        let common = try XCTUnwrap(
            OriginalBuildingGeometryCatalog.customGeometry(forBuildingID: 59)
        )
        XCTAssertEqual(common.dataAddress, 0x8574A8)
        XCTAssertEqual(common.pointsPerBank, 28)
        XCTAssertEqual(common.banks.count, 2)
        XCTAssertEqual(common.banks[0].width, 4)
        XCTAssertEqual(common.banks[0].height, 7)
        XCTAssertEqual(common.banks[1].width, 7)
        XCTAssertEqual(common.banks[1].height, 4)
        XCTAssertEqual(
            common.points(forOrientationBank: 0)?.prefix(5).map { $0 },
            [
                GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0),
                GridPoint(x: 2, y: 0), GridPoint(x: 3, y: 0),
                GridPoint(x: 0, y: 1)
            ]
        )
        XCTAssertEqual(
            common.points(forOrientationBank: 1)?.prefix(5).map { $0 },
            [
                GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1),
                GridPoint(x: 0, y: 2), GridPoint(x: 0, y: 3),
                GridPoint(x: 1, y: 0)
            ]
        )

        let grand = try XCTUnwrap(
            OriginalBuildingGeometryCatalog.customGeometry(forBuildingID: 60)
        )
        XCTAssertEqual(grand.dataAddress, 0x857828)
        XCTAssertEqual(grand.pointsPerBank, 42)
        XCTAssertEqual(grand.banks.count, 2)
        XCTAssertEqual(grand.banks[0].width, 6)
        XCTAssertEqual(grand.banks[0].height, 7)
        XCTAssertEqual(grand.banks[1].width, 7)
        XCTAssertEqual(grand.banks[1].height, 6)
        XCTAssertEqual(grand.points(forOrientationBank: 0)?.count, 42)
        XCTAssertEqual(
            grand.points(forOrientationBank: 1)?.prefix(8).map { $0 },
            [
                GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1),
                GridPoint(x: 0, y: 2), GridPoint(x: 0, y: 3),
                GridPoint(x: 0, y: 4), GridPoint(x: 0, y: 5),
                GridPoint(x: 1, y: 0), GridPoint(x: 1, y: 1)
            ],
            "the transposed PE bank is stored column-major"
        )
        XCTAssertEqual(grand.points(forOrientationBank: 1)?.last, GridPoint(x: 6, y: 5))
        XCTAssertEqual(
            common.pointRecords(forOrientationBank: 0)?[8],
            .init(point: GridPoint(x: 0, y: 2), flags: 4, auxiliary: 0)
        )
        XCTAssertEqual(
            grand.pointRecords(forOrientationBank: 0)?[20],
            .init(point: GridPoint(x: 2, y: 3), flags: 1, auxiliary: 132)
        )
        XCTAssertEqual(
            grand.pointRecords(forOrientationBank: 1)?[12],
            .init(point: GridPoint(x: 2, y: 0), flags: 4, auxiliary: 103)
        )
        XCTAssertNil(grand.points(forOrientationBank: 2))

        XCTAssertEqual(
            common.transformedPoints(forOrientationBank: 0, mapRotation: 2)?.prefix(5).map { $0 },
            [
                GridPoint(x: 0, y: 0), GridPoint(x: -1, y: 0),
                GridPoint(x: -2, y: 0), GridPoint(x: -3, y: 0),
                GridPoint(x: 0, y: 1)
            ]
        )
        XCTAssertEqual(
            common.transformedPoints(forOrientationBank: 0, mapRotation: 4)?.last,
            GridPoint(x: -3, y: -6)
        )
        XCTAssertEqual(
            common.transformedPoints(forOrientationBank: 0, mapRotation: 6)?.last,
            GridPoint(x: 3, y: -6)
        )
    }

    func testMarketCustomSamplerCallbackSlotsMatchCanonicalENAndCHVTables() {
        let expectedOffsets = [0x28, 0x30, 0x34, 0x38, 0x3C, 0x40, 0x48, 0x4C, 0x50, 0x5C]
        let expectedAddresses = [
            0x416B80, 0x42A210, 0x66EFA0, 0x42CCC0, 0x4FA410,
            0x4E1C20, 0x416A50, 0x42C100, 0x42C750, 0x42C710
        ]
        for buildingID in [59, 60] {
            let slots = OriginalBuildingGeometryCatalog.customSamplerCallbackSlots(
                forBuildingID: buildingID
            )
            XCTAssertEqual(slots?.map(\.slotOffset), expectedOffsets)
            XCTAssertEqual(slots?.map(\.functionAddress), expectedAddresses)
        }
        XCTAssertNil(
            OriginalBuildingGeometryCatalog.customSamplerCallbackSlots(
                forBuildingID: 23
            )
        )
    }

    func testFengShuiPlacementSamplerUsesExecutableGeometryAndSupportsExplicitMarketBank() throws {
        var mapWords: [Int: UInt32] = [:]
        for y in 0..<24 {
            for x in 0..<228 {
                mapWords[y * 228 + x] = 0
            }
        }
        let sampled = try XCTUnwrap(
            OriginalFengShuiTerrainClassification.samplePlacement(
                buildingID: 2,
                modelValue: 2,
                origin: GridPoint(x: 10, y: 10),
                mapRotation: 0,
                mapWords: mapWords,
                baseLinearOffset: 0
            )
        )
        XCTAssertEqual(sampled.result, -1)
        XCTAssertEqual(sampled.diagnosticSlot, 5)
        XCTAssertEqual(sampled.usedCounterSlots, true)

        XCTAssertNil(
            OriginalFengShuiTerrainClassification.samplePlacement(
                buildingID: 23,
                modelValue: 2,
                origin: GridPoint(x: 10, y: 10),
                mapRotation: 0,
                mapWords: mapWords,
                baseLinearOffset: 0
            )
        )

        let marketSample = try XCTUnwrap(
            OriginalFengShuiTerrainClassification.samplePlacement(
                buildingID: 59,
                modelValue: 2,
                origin: GridPoint(x: 10, y: 10),
                mapRotation: 0,
                mapWords: mapWords,
                baseLinearOffset: 0,
                customOrientationBank: 0
            )
        )
        XCTAssertEqual(marketSample.result, -1)
        XCTAssertEqual(marketSample.diagnosticSlot, 5)
        XCTAssertEqual(marketSample.usedCounterSlots, true)

        XCTAssertNil(
            OriginalFengShuiTerrainClassification.samplePlacement(
                buildingID: 59,
                modelValue: 2,
                origin: GridPoint(x: 10, y: 10),
                mapRotation: 0,
                mapWords: mapWords,
                baseLinearOffset: 0
            )
        )
        XCTAssertEqual(
            OriginalFengShuiTerrainClassification.samplePlacement(
                buildingID: 23,
                modelValue: 7,
                origin: GridPoint(x: 10, y: 10),
                mapRotation: 0,
                mapWords: [:],
                baseLinearOffset: 0
            )?.result,
            1
        )
    }

    func testCustomOrientationBankSearchPreservesExecutableStartAndWrapOrder() {
        XCTAssertEqual(
            OriginalCustomOrientationBankSearch.searchOrder(
                bankCount: 2,
                persistedBank: 1,
                placementModeIsZero: true,
                alternateOrientationEnabled: false
            ),
            [1, 0]
        )
        XCTAssertEqual(
            OriginalCustomOrientationBankSearch.searchOrder(
                bankCount: 2,
                persistedBank: 7,
                placementModeIsZero: true,
                alternateOrientationEnabled: false
            ),
            [0, 1],
            "an out-of-range DAT_008C7628 falls through to the source default"
        )
        XCTAssertEqual(
            OriginalCustomOrientationBankSearch.searchOrder(
                bankCount: 2,
                persistedBank: 0,
                placementModeIsZero: false,
                alternateOrientationEnabled: true
            ),
            [1, 0],
            "the alternate gate starts at 1 % bankCount when placement mode is nonzero"
        )
        XCTAssertEqual(
            OriginalCustomOrientationBankSearch.searchOrder(
                bankCount: 1,
                persistedBank: nil,
                placementModeIsZero: false,
                alternateOrientationEnabled: true
            ),
            [0]
        )
        XCTAssertNil(
            OriginalCustomOrientationBankSearch.searchOrder(
                bankCount: 0,
                persistedBank: nil,
                placementModeIsZero: true,
                alternateOrientationEnabled: false
            )
        )
    }

    func testCustomOrientationBankSearchReturnsFirstAcceptedBankOnly() {
        XCTAssertEqual(
            OriginalCustomOrientationBankSearch.firstAcceptedBank(
                bankCount: 2,
                persistedBank: 1,
                placementModeIsZero: true,
                alternateOrientationEnabled: false,
                acceptedBanks: [true, false]
            ),
            0,
            "the source tests bank 1 first, then wraps to bank 0"
        )
        XCTAssertNil(
            OriginalCustomOrientationBankSearch.firstAcceptedBank(
                bankCount: 2,
                persistedBank: 0,
                placementModeIsZero: true,
                alternateOrientationEnabled: false,
                acceptedBanks: [false, false]
            )
        )
        XCTAssertNil(
            OriginalCustomOrientationBankSearch.firstAcceptedBank(
                bankCount: 2,
                persistedBank: 0,
                placementModeIsZero: true,
                alternateOrientationEnabled: false,
                acceptedBanks: [true]
            ),
            "acceptance results must cover the exact vtable bank count"
        )
    }

    func testCustomOrientationBankFallbackCandidateOrderMatchesSource() {
        let order = OriginalCustomOrientationBankSearch.fallbackCandidateOrder(
            center: GridPoint(x: 10, y: 20)
        )
        XCTAssertEqual(order.count, 121)
        XCTAssertEqual(order.first, GridPoint(x: 15, y: 25))
        XCTAssertEqual(order[1], GridPoint(x: 14, y: 25))
        XCTAssertEqual(order[10], GridPoint(x: 5, y: 25))
        XCTAssertEqual(order[11], GridPoint(x: 15, y: 24))
        XCTAssertEqual(order.last, GridPoint(x: 5, y: 15))

        var accepted = [Bool](repeating: false, count: 121)
        accepted[11] = true
        XCTAssertEqual(
            OriginalCustomOrientationBankSearch.firstAcceptedFallbackCandidate(
                center: GridPoint(x: 10, y: 20),
                acceptedCandidates: accepted
            ),
            GridPoint(x: 15, y: 24)
        )
        XCTAssertNil(
            OriginalCustomOrientationBankSearch.firstAcceptedFallbackCandidate(
                center: GridPoint(x: 10, y: 20),
                acceptedCandidates: Array(repeating: false, count: 120)
            )
        )
    }

    func testOriginalDepartureAssignmentPlannerPreservesLevelBucketsAndVectorOrder() {
        let plan = OriginalDepartureAssignmentPlanner.plan(
            request: 14,
            houses: [
                .init(houseVectorIndex: 0, houseLevelIndex: 3, residentCount: 2),
                .init(houseVectorIndex: 1, houseLevelIndex: 1, residentCount: 9),
                .init(houseVectorIndex: 2, houseLevelIndex: 1, residentCount: 4),
                .init(houseVectorIndex: 0, houseLevelIndex: 0, residentCount: 0),
                .init(houseVectorIndex: 3, houseLevelIndex: 14, residentCount: 20),
            ]
        )

        XCTAssertEqual(
            plan.assignments,
            [
                .init(houseVectorIndex: 1, houseLevelIndex: 1, peopleCount: 6),
                .init(houseVectorIndex: 2, houseLevelIndex: 1, peopleCount: 4),
                .init(houseVectorIndex: 0, houseLevelIndex: 3, peopleCount: 2),
            ]
        )
        XCTAssertEqual(plan.unassigned, 2)
    }

    func testOriginalDepartureWriteReproducesCommonExhaustionAndFigureInitialization() {
        let result = OriginalDepartureWrite.apply(.init(
            houseResidents: 3,
            peopleCount: 3,
            isCommonHouseType: true,
            isEliteHouseType: false,
            houseCleanupCallbackPassed: true,
            figureAllocationSucceeded: true
        ))

        XCTAssertEqual(result.populationLedgerDelta, -3)
        XCTAssertEqual(result.resultingResidents, 0)
        XCTAssertTrue(result.exhaustedHouse)
        XCTAssertTrue(result.invokedHouseCleanup)
        XCTAssertEqual(result.resultingHouseTypeID, 3)
        XCTAssertEqual(result.resultingHouseLevelIndex, 0)
        XCTAssertTrue(result.figureSpawnAttempted)
        XCTAssertTrue(result.figureSpawnSucceeded)
        XCTAssertEqual(result.figureState, 6)
        XCTAssertEqual(result.figureWaitWord, 0)
        XCTAssertEqual(result.figurePeopleByte, 3)
    }

    func testOriginalDepartureWriteKeepsOccupiedHouseAndSeparatesEliteConversion() {
        let partial = OriginalDepartureWrite.apply(.init(
            houseResidents: 10,
            peopleCount: 4,
            isCommonHouseType: false,
            isEliteHouseType: true,
            houseCleanupCallbackPassed: true,
            figureAllocationSucceeded: true
        ))
        XCTAssertEqual(partial.resultingResidents, 6)
        XCTAssertFalse(partial.exhaustedHouse)
        XCTAssertFalse(partial.invokedHouseCleanup)
        XCTAssertNil(partial.resultingHouseTypeID)
        XCTAssertNil(partial.resultingHouseLevelIndex)
        XCTAssertEqual(partial.figurePeopleByte, 4)

        let exhausted = OriginalDepartureWrite.apply(.init(
            houseResidents: 4,
            peopleCount: 4,
            isCommonHouseType: false,
            isEliteHouseType: true,
            houseCleanupCallbackPassed: true,
            figureAllocationSucceeded: false
        ))
        XCTAssertEqual(exhausted.resultingHouseTypeID, 12)
        XCTAssertEqual(exhausted.resultingHouseLevelIndex, 9)
        XCTAssertTrue(exhausted.figureSpawnAttempted)
        XCTAssertFalse(exhausted.figureSpawnSucceeded)
        XCTAssertNil(exhausted.figureState)
    }

    func testOriginalPopulationAggregateAppliesStateAndCallbackEligibility() {
        let aggregate = OriginalPopulationAggregate.evaluate(objects: [
            .init(state: 0, residentWord: 10, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: true),
            .init(state: 2, residentWord: 20, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: true),
            .init(state: 5, residentWord: 30, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: true),
            .init(state: 6, residentWord: 40, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: true),
            .init(state: 1, residentWord: 7, qualifiesForPopulation: false, qualifiesForSecondaryPopulation: true),
            .init(state: 1, residentWord: 8, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: false),
            .init(state: 1, residentWord: 9, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: true),
        ])

        XCTAssertEqual(aggregate.population, 17)
        XCTAssertEqual(aggregate.secondaryPopulation, 9)
    }

    func testOriginalPopulationAggregateUsesSignedResidentWord() {
        let aggregate = OriginalPopulationAggregate.evaluate(objects: [
            .init(state: 1, residentWord: 0xFFFF, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: true),
            .init(state: 1, residentWord: 0x8000, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: false),
            .init(state: 1, residentWord: 0x1_0000, qualifiesForPopulation: true, qualifiesForSecondaryPopulation: true),
        ])

        XCTAssertEqual(aggregate.population, -32_769)
        XCTAssertEqual(aggregate.secondaryPopulation, -1)
    }

    func testOriginalHousePopulationCallbackProjectionKeepsStateAndClassBoundaries() {
        let eligibleCommon = OriginalHousePopulationCallbackInput(
            objectStateByte: 1,
            houseEligibilityByte: 1,
            residentWord: 12,
            houseTypeWord: 10
        )
        XCTAssertTrue(eligibleCommon.isPopulationEligible)
        XCTAssertFalse(eligibleCommon.isSecondaryPopulationEligible)

        let eligibleUpper = OriginalHousePopulationCallbackInput(
            objectStateByte: 3,
            houseEligibilityByte: 0xFF,
            residentWord: 18,
            houseTypeWord: 11
        )
        XCTAssertTrue(eligibleUpper.isPopulationEligible)
        XCTAssertTrue(eligibleUpper.isSecondaryPopulationEligible)
        let aggregate = OriginalPopulationAggregate.evaluate(objects: [
            eligibleCommon.aggregateObject,
            eligibleUpper.aggregateObject,
        ])
        XCTAssertEqual(aggregate.population, 30)
        XCTAssertEqual(aggregate.secondaryPopulation, 18)

        for state in [0, 2, 5, 6] {
            let excluded = OriginalHousePopulationCallbackInput(
                objectStateByte: UInt8(state),
                houseEligibilityByte: 1,
                residentWord: 99,
                houseTypeWord: 17
            )
            XCTAssertFalse(excluded.isPopulationEligible, "state (state)")
            XCTAssertFalse(excluded.isSecondaryPopulationEligible, "state (state)")
        }
    }

    func testOriginalPopulationLedgerClampsAndTracksHighWaterMark() {
        var ledger = OriginalPopulationLedger(
            populationWord: 10,
            highWaterMark: 4
        )

        ledger.decrementPopulation(by: 3)
        XCTAssertEqual(ledger.populationWord, 7)
        XCTAssertEqual(ledger.highWaterMark, 10)

        ledger.decrementPopulation(by: 20)
        XCTAssertEqual(ledger.populationWord, 0)
        XCTAssertEqual(ledger.highWaterMark, 10)

        ledger.incrementPopulation(by: 6)
        XCTAssertEqual(ledger.populationWord, 6)
        XCTAssertEqual(ledger.highWaterMark, 10)
    }

    func testOriginalPopulationLedgerPreservesTypeDCompositeWordOrder() {
        var ledger = OriginalPopulationLedger(populationWord: 20)

        ledger.applyTypeDCountIncrease(6)
        XCTAssertEqual(ledger.unclassifiedDeltaWord, 6)
        XCTAssertEqual(ledger.populationWord, 14)

        ledger.applyTypeDCountDecrease(4)
        XCTAssertEqual(ledger.unclassifiedDeltaWord, 2)
        XCTAssertEqual(ledger.populationWord, 18)
        XCTAssertEqual(ledger.highWaterMark, 20)
    }

    func testOriginalDepartureAssignmentPlannerDoesNotReadHouseCapacityOrAccessState() {
        let plan = OriginalDepartureAssignmentPlanner.plan(
            request: 3,
            houses: [
                .init(houseVectorIndex: 4, houseLevelIndex: 0, residentCount: 100),
                .init(houseVectorIndex: 5, houseLevelIndex: 0, residentCount: 1),
            ]
        )

        XCTAssertEqual(
            plan.assignments,
            [.init(houseVectorIndex: 4, houseLevelIndex: 0, peopleCount: 3)]
        )
        XCTAssertEqual(plan.unassigned, 0)
    }

    func testOriginalDepartureAssignmentPlannerReturnsEmptyPlanForNonPositiveRequest() {
        XCTAssertEqual(
            OriginalDepartureAssignmentPlanner.plan(request: 0, houses: [
                .init(houseVectorIndex: 0, houseLevelIndex: 0, residentCount: 6)
            ]),
            .init(assignments: [], unassigned: 0)
        )
        XCTAssertEqual(
            OriginalDepartureAssignmentPlanner.plan(request: -1, houses: []),
            .init(assignments: [], unassigned: 0)
        )
    }

    func testOriginalImmigrantAssignmentPlannerPreservesThreePassOrderAndBatchRules() {
        let plan = OriginalImmigrantAssignmentPlanner.plan(
            request: 20,
            houses: [
                // Pass 1 ignores the numeric capacity and emits a six-person
                // batch for an empty accessible house with a non-zero word.
                .init(
                    houseVectorIndex: 0,
                    accessValue: 1,
                    residents: 0,
                    remainingCapacity: 2
                ),
                // Pass 2 and pass 3 deliberately rescan the same house; the
                // source does not mutate +0x22 between those passes.
                .init(
                    houseVectorIndex: 1,
                    accessValue: 1,
                    residents: 4,
                    remainingCapacity: 12
                ),
                .init(
                    houseVectorIndex: 2,
                    accessValue: 1,
                    residents: 3,
                    remainingCapacity: 2
                ),
            ]
        )

        XCTAssertEqual(
            plan.assignments,
            [
                .init(houseVectorIndex: 0, peopleCount: 6, pass: 1),
                .init(houseVectorIndex: 1, peopleCount: 6, pass: 2),
                .init(houseVectorIndex: 0, peopleCount: 2, pass: 3),
                .init(houseVectorIndex: 1, peopleCount: 6, pass: 3),
        ]
        )
        XCTAssertEqual(plan.unassigned, 0)
        XCTAssertTrue(plan.clearedHouseVectorIndices.isEmpty)

        let remainder = OriginalImmigrantAssignmentPlanner.plan(
            request: 40,
            houses: [
                .init(
                    houseVectorIndex: 0,
                    accessValue: 1,
                    residents: 0,
                    remainingCapacity: 2
                ),
            ]
        )
        XCTAssertEqual(
            remainder.assignments,
            [
                .init(houseVectorIndex: 0, peopleCount: 6, pass: 1),
                .init(houseVectorIndex: 0, peopleCount: 2, pass: 3),
            ]
        )
        XCTAssertEqual(remainder.unassigned, 32)
    }

    func testOriginalImmigrantAssignmentPlannerClearsInvalidLinksButKeepsActiveLinksBlocked() {
        let plan = OriginalImmigrantAssignmentPlanner.plan(
            request: 12,
            houses: [
                .init(
                    houseVectorIndex: 7,
                    accessValue: 1,
                    residents: 0,
                    remainingCapacity: 4,
                    houseLinkPresent: true,
                    linkedObjectModelID: 0xC,
                    linkedObjectState16: 1
                ),
                .init(
                    houseVectorIndex: 8,
                    accessValue: 1,
                    residents: 0,
                    remainingCapacity: 4,
                    houseLinkPresent: true,
                    linkedObjectModelID: 0xB,
                    linkedObjectState16: 1
                ),
                .init(
                    houseVectorIndex: 9,
                    accessValue: 1,
                    residents: 0,
                    remainingCapacity: 4
                ),
            ]
        )

        XCTAssertEqual(plan.clearedHouseVectorIndices, [7])
        XCTAssertEqual(
            plan.assignments,
            [
                .init(houseVectorIndex: 7, peopleCount: 6, pass: 1),
                .init(houseVectorIndex: 9, peopleCount: 6, pass: 1),
            ]
        )
        XCTAssertEqual(plan.unassigned, 0)
    }

    func testOriginalImmigrantFigureSpawnWritesExactFieldsAndAdvancesWaitWord() {
        let result = OriginalImmigrantFigureSpawn.apply(.init(
            allocationSucceeded: true,
            figureID: 42,
            houseObjectID: 17,
            peopleCount: 9,
            houseFlag51: 0x81,
            initialWaitWord: 0x1234,
            figureTableWord: 0x40
        ))

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.figureID, 42)
        XCTAssertEqual(result.figureState40, 6)
        XCTAssertEqual(result.figureHouseID64, 17)
        XCTAssertEqual(result.figureWaitWord3E, 0x1235)
        XCTAssertEqual(result.figurePeopleByte6E, 9)
        XCTAssertEqual(result.figureFlag13, 1)
        XCTAssertEqual(result.figureFlag49, 1)
        XCTAssertEqual(result.linkedHouseObjectID, 17)
        XCTAssertEqual(result.updatedWaitWord, 0x1266)
    }

    func testOriginalImmigrantFigureSpawnFailureLeavesAllWritesAbsentAndWaitUnchanged() {
        let result = OriginalImmigrantFigureSpawn.apply(.init(
            allocationSucceeded: false,
            houseObjectID: 17,
            peopleCount: 6,
            houseFlag51: 0xFF,
            initialWaitWord: 0x20
        ))

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.figureID)
        XCTAssertNil(result.figureState40)
        XCTAssertNil(result.figureHouseID64)
        XCTAssertNil(result.figureWaitWord3E)
        XCTAssertNil(result.figurePeopleByte6E)
        XCTAssertNil(result.figureFlag13)
        XCTAssertNil(result.figureFlag49)
        XCTAssertNil(result.linkedHouseObjectID)
        XCTAssertEqual(result.updatedWaitWord, 0x20)
    }

    func testOriginalFigureAllocatorSkipsInvalidCandidatesAndSelectsFirstInactiveObject() {
        let result = OriginalFigureAllocator.firstAvailable(candidates: [
            .init(candidateID: -1, objectPresent: true),
            .init(candidateID: 12, objectPresent: false),
            .init(candidateID: 13, objectPresent: true, objectState16: 4),
            .init(candidateID: 14, objectPresent: true),
        ])

        XCTAssertEqual(result.candidateID, 14)
        XCTAssertEqual(result.attemptCount, 4)
    }

    func testOriginalFigureAllocatorStopsAfterFiveCandidateCalls() {
        let result = OriginalFigureAllocator.firstAvailable(candidates: [
            .init(candidateID: 1, objectPresent: false),
            .init(candidateID: 2, objectPresent: false),
            .init(candidateID: 3, objectPresent: true, objectState16: 1),
            .init(candidateID: 4, objectPresent: false),
            .init(candidateID: 5, objectPresent: false),
            // The source returns zero before this sixth resolved result can
            // be consumed.
            .init(candidateID: 6, objectPresent: true),
        ])

        XCTAssertNil(result.candidateID)
        XCTAssertEqual(result.attemptCount, 5)
    }

    func testOriginalFigureAllocatorReturnsNoCandidateForEmptyOrAllRejectedInputs() {
        XCTAssertEqual(
            OriginalFigureAllocator.firstAvailable(candidates: []),
            .init(candidateID: nil, attemptCount: 0)
        )
        XCTAssertEqual(
            OriginalFigureAllocator.firstAvailable(candidates: [
                .init(candidateID: 0, objectPresent: true),
                .init(candidateID: 7, objectPresent: true, objectState16: -1),
            ]),
            .init(candidateID: nil, attemptCount: 2)
        )
    }

    func testOriginalFigureAllocatorStateWrapsAtTheRecoveredLastRingIndex() {
        var state = OriginalFigureAllocatorState(
            cursor: OriginalFigureAllocatorState.lastRingIndex,
            availableCount: 2
        )

        XCTAssertEqual(state.consume(slotValue: 101), 101)
        XCTAssertEqual(state.cursor, 0)
        XCTAssertEqual(state.availableCount, 1)
        XCTAssertEqual(state.consume(slotValue: -1), -1)
        XCTAssertEqual(state.cursor, 1)
        XCTAssertEqual(state.availableCount, 0)
    }

    func testOriginalFigureAllocatorStateZeroCountIsANoOpButNegativeCountStillConsumes() {
        var empty = OriginalFigureAllocatorState(cursor: 17, availableCount: 0)
        XCTAssertNil(empty.consume(slotValue: 42))
        XCTAssertEqual(empty.cursor, 17)
        XCTAssertEqual(empty.availableCount, 0)

        var raw = OriginalFigureAllocatorState(cursor: 17, availableCount: -1)
        XCTAssertEqual(raw.consume(slotValue: 42), 42)
        XCTAssertEqual(raw.cursor, 18)
        XCTAssertEqual(raw.availableCount, -2)
    }

    func testOriginalFigureAllocatorStateUsesAnIndependentWriteCursorAndResetsBothCursors() {
        var state = OriginalFigureAllocatorState(cursor: 9, writeCursor: 17)
        let first = state.enqueue(slotValue: 1999)
        XCTAssertEqual(first.slotIndex, 17)
        XCTAssertEqual(first.slotValue, 1999)
        XCTAssertEqual(state.cursor, 9)
        XCTAssertEqual(state.writeCursor, 18)
        XCTAssertEqual(state.availableCount, 1)

        state.reset()
        XCTAssertEqual(state.cursor, 0)
        XCTAssertEqual(state.writeCursor, 0)
        XCTAssertEqual(state.availableCount, 0)
    }

    func testOriginalFigureAllocatorStateEnqueueWrapsWithoutCapacityClamp() {
        var state = OriginalFigureAllocatorState(
            cursor: 4,
            writeCursor: OriginalFigureAllocatorState.lastRingIndex,
            availableCount: OriginalFigureAllocatorState.ringSlotCount
        )

        let result = state.enqueue(slotValue: 7)
        XCTAssertEqual(result.slotIndex, OriginalFigureAllocatorState.lastRingIndex)
        XCTAssertEqual(state.writeCursor, 0)
        XCTAssertEqual(state.availableCount, OriginalFigureAllocatorState.ringSlotCount + 1)
        XCTAssertEqual(state.cursor, 4)
    }

    func testOriginalFigureAllocatorStateMatchesCanonicalRingLayout() {
        XCTAssertEqual(OriginalFigureAllocatorState.sourceStateAddress, 0x01032678)
        XCTAssertEqual(OriginalFigureAllocatorState.cursorOffset, 0x00)
        XCTAssertEqual(OriginalFigureAllocatorState.writeCursorOffset, 0x04)
        XCTAssertEqual(OriginalFigureAllocatorState.availableCountOffset, 0x08)
        XCTAssertEqual(OriginalFigureAllocatorState.ringValuesOffset, 0x0C)
        XCTAssertEqual(OriginalFigureAllocatorState.ringResetAddress, 0x004EBBF0)
        XCTAssertEqual(OriginalFigureAllocatorState.ringSeedAddress, 0x004EBC00)
        XCTAssertEqual(OriginalFigureAllocatorState.ringSeedFirstID, 1)
        XCTAssertEqual(OriginalFigureAllocatorState.ringSeedExclusiveUpperBound, 2000)
        XCTAssertEqual(OriginalFigureAllocatorState.liveRegistryRebuildAddress, 0x004E9FE0)
        XCTAssertEqual(
            OriginalFigureAllocatorState.liveRegistryRebuildDirectCallSites,
            [0x00534D08]
        )
    }

    func testOriginalFigureAllocatorQueueRebuildsFreeIDsDescendingAndReportsSideEffectInputs() {
        let objects = (1...OriginalFigureAllocatorQueue.lastObjectID).map { objectID in
            switch objectID {
            case 1999, 1997:
                return OriginalFigureAllocatorObjectRecord(objectID: objectID, state16: 0)
            case 1998:
                return OriginalFigureAllocatorObjectRecord(objectID: objectID, state16: 2)
            case 1996:
                return OriginalFigureAllocatorObjectRecord(objectID: objectID, state16: 1, state12: 1)
            default:
                return OriginalFigureAllocatorObjectRecord(objectID: objectID, state16: 1)
            }
        }

        let result = OriginalFigureAllocatorQueue.rebuild(objects: objects)
        XCTAssertEqual(result?.freeObjectIDs, [1999, 1997])
        XCTAssertEqual(result?.counterUpdateObjectIDs, Array(stride(from: 1996, through: 1, by: -1)))
        XCTAssertEqual(result?.specialState12ObjectIDs, [1996])
    }

    func testOriginalFigureAllocatorQueueRejectsIncompleteOrDuplicateRegistryInput() {
        XCTAssertNil(OriginalFigureAllocatorQueue.rebuild(objects: []))

        var objects = (1...OriginalFigureAllocatorQueue.lastObjectID).map {
            OriginalFigureAllocatorObjectRecord(objectID: $0, state16: 0)
        }
        objects[1] = .init(objectID: 1, state16: 0)
        XCTAssertNil(OriginalFigureAllocatorQueue.rebuild(objects: objects))
    }

    func testOriginalFigureAllocatorQueueBootstrapUsesAscendingOneBasedIDs() {
        let ids = OriginalFigureAllocatorQueue.bootstrapObjectIDs()
        XCTAssertEqual(ids.count, OriginalFigureAllocatorState.ringSlotCount)
        XCTAssertEqual(ids.first, 1)
        XCTAssertEqual(ids.last, 1999)
    }

    func testOriginalFigureCounterClassificationMatchesBothRecoveredModelSets() {
        for modelID in 0x3A...0x3E {
            let classification = OriginalFigureCounterClassification.resolve(modelID: modelID)
            XCTAssertTrue(classification.updatesFirstCounter)
            XCTAssertFalse(classification.updatesSecondCounter)
        }
        XCTAssertTrue(OriginalFigureCounterClassification.resolve(modelID: 0x4E).updatesFirstCounter)

        for modelID in [0x38, 0x39, 0x40, 0x41, 0x42, 0x43, 0x44, 0x4F] {
            let classification = OriginalFigureCounterClassification.resolve(modelID: modelID)
            XCTAssertFalse(classification.updatesFirstCounter)
            XCTAssertTrue(classification.updatesSecondCounter)
        }
        XCTAssertFalse(OriginalFigureCounterClassification.resolve(modelID: 0x3F).updatesSecondCounter)
    }

    func testOriginalFigureGlobalCountersIncrementDecrementAndClampPerModelClass() {
        var counters = OriginalFigureGlobalCounters(first: 1, second: 1)
        counters.apply(objectID: 4, modelID: 0x3A, adding: true)
        XCTAssertEqual(counters.first, 2)
        XCTAssertEqual(counters.second, 1)

        counters.apply(objectID: 5, modelID: 0x40, adding: false)
        XCTAssertEqual(counters.first, 2)
        XCTAssertEqual(counters.second, 0)

        counters.apply(objectID: 6, modelID: 0x40, adding: false)
        XCTAssertEqual(counters.second, 0)
        counters.apply(objectID: 0, modelID: 0x3A, adding: true)
        XCTAssertEqual(counters.first, 2)
    }

    func testFoodPopularityWalkClearsStreakForZeroRequirementHouse() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 4,
            mapHeight: 4
        )
        _ = city.addHouse(
            levelID: 0,
            residents: 1,
            location: GridPoint(x: 1, y: 1),
            models: original.buildings
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(city))
                as? [String: Any]
        )
        var houses = try XCTUnwrap(object["houses"] as? [[String: Any]])
        houses[0]["foodShortageStreak"] = 3
        object["houses"] = houses
        city = try JSONDecoder().decode(
            DeterministicCityState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(city.houses[0].foodShortageStreak, 3)
        city.updateMigrationPopularity(rules: rules)
        XCTAssertEqual(city.houses[0].foodShortageStreak, 0)
    }

    func testAssignedCurrentMonthResetsAtMonthBoundary() {
        var migration = DeterministicMigrationState(
            assignedToday: 4,
            assignedThisMonth: 9
        )

        migration.finishMonth()

        XCTAssertEqual(migration.assignedToday, 4)
        XCTAssertEqual(migration.assignedThisMonth, 0)
    }

    func testImmigrantWaitStaggerUsesOneDailyDecrementAndPerSpawnIncrement() {
        // `FUN_004AD4A0` decrements DAT_00D62418 once before the assignment
        // walk; each successful `FUN_004ADE10` spawn then adds 0x32. The
        // per-house spawn path must not perform another daily decrement.
        var migration = DeterministicMigrationState(immigrantWaitGlobal: 100)
        migration.advanceImmigrantWaitGlobal()
        XCTAssertEqual(migration.immigrantWaitGlobal, 100 - 0x33)

        migration.registerImmigrantWalker(ImmigrantWalker(
            id: 1,
            houseID: 7,
            peopleCount: 1,
            entryPoint: GridPoint(x: 0, y: 0),
            route: [GridPoint(x: 0, y: 0)],
            waitSteps: 0
        ))
        XCTAssertEqual(migration.immigrantWaitGlobal, 100 - 0x33 + 0x32)
    }

    func testOriginalDailyMigrationBatchAccumulatesSmallRequestsThenClearsOnDispatch() {
        let first = DeterministicMigration.originalDailyMigrationBatch(.init(
            arrivalRequest: 2,
            departureRequest: 0,
            arrivalPending: 3
        ))
        XCTAssertEqual(first.arrivalPending, 5)
        XCTAssertNil(first.arrivalDispatchAmount)

        let second = DeterministicMigration.originalDailyMigrationBatch(.init(
            arrivalRequest: 1,
            departureRequest: 0,
            arrivalPending: first.arrivalPending
        ))
        XCTAssertEqual(second.arrivalPending, 0)
        XCTAssertEqual(second.arrivalDispatchAmount, 6)
        XCTAssertTrue(second.requestsCleared)
    }

    func testOriginalDailyMigrationBatchImmediateRequestsPreservePriorPendingWord() {
        let result = DeterministicMigration.originalDailyMigrationBatch(.init(
            arrivalRequest: 6,
            departureRequest: 9,
            arrivalPending: 4,
            departurePending: 2
        ))

        XCTAssertEqual(result.arrivalDispatchAmount, 6)
        XCTAssertEqual(result.arrivalPending, 4)
        XCTAssertEqual(result.departureDispatchAmount, 9)
        XCTAssertEqual(result.departurePending, 2)
    }

    func testOriginalDailyMigrationBatchKeepsIndependentStreamsAndZeroRequests() {
        let result = DeterministicMigration.originalDailyMigrationBatch(.init(
            arrivalRequest: 0,
            departureRequest: 4,
            arrivalPending: 7,
            departurePending: 1
        ))

        XCTAssertEqual(result.arrivalPending, 7)
        XCTAssertNil(result.arrivalDispatchAmount)
        XCTAssertEqual(result.departurePending, 5)
        XCTAssertNil(result.departureDispatchAmount)
    }

    func testTickObservesRoadAdjacentHousingWithoutMovingResidents() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 12,
            mapHeight: 5
        )
        _ = city.buildRoad((0..<12).map { GridPoint(x: $0, y: 2) }, rules: rules)
        let firstID = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 2, y: 1),
            models: original.buildings
        )
        let secondID = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 5, y: 1),
            models: original.buildings
        )

        let tick = city.advanceTick(rules: rules)

        XCTAssertEqual(tick.migratedResidents, 0)
        XCTAssertEqual(tick.migrationAssessment.eligibleHouseIDs, [firstID, secondID])
        XCTAssertEqual(tick.migrationAssessment.availableCapacity, 14)
        XCTAssertEqual(tick.migrationAssessment.plannedImmigrants, 0)
        XCTAssertNil(tick.migrationAssessment.blockReason)
        XCTAssertEqual(city.population, 0)
        XCTAssertEqual(
            city.migration.automaticMigrationAvailability,
            .unsupportedOriginalProducer
        )
        XCTAssertEqual(city.migration.lastDailyImmigrants, 0)
        XCTAssertEqual(city.migration.currentMonthImmigrants, 0)
        XCTAssertEqual(city.migration.lastMonthImmigrants, 0)
    }

    func testHousingObservationExcludesVacanciesWithoutRoadAccess() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = city.buildRoad([GridPoint(x: 0, y: 1)], rules: rules)
        let accessibleID = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 1, y: 1),
            models: original.buildings
        )
        _ = city.addHouse(
            levelID: 0,
            location: GridPoint(x: 6, y: 4),
            models: original.buildings
        )

        let tick = city.advanceTick(rules: rules)

        XCTAssertEqual(tick.migrationAssessment.eligibleHouseIDs, [accessibleID])
        XCTAssertEqual(tick.migrationAssessment.availableCapacity, 7)
        XCTAssertEqual(tick.migratedResidents, 0)
        XCTAssertEqual(city.population, 0)
    }

    func testLegacyMigrationStateDecodesThenProductionTickClearsApproximation() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var source = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 8,
            mapHeight: 5
        )
        _ = source.buildRoad([GridPoint(x: 0, y: 1)], rules: rules)
        _ = source.addHouse(
            levelID: 0,
            location: GridPoint(x: 1, y: 1),
            models: original.buildings
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(source))
                as? [String: Any]
        )
        object["migrationState"] = [
            "lastDailyImmigrants": 5,
            "currentMonthImmigrants": 21,
            "lastMonthImmigrants": 17,
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        var restored = try JSONDecoder().decode(DeterministicCityState.self, from: legacyData)

        XCTAssertEqual(
            restored.migration.automaticMigrationAvailability,
            .unsupportedOriginalProducer
        )
        XCTAssertEqual(restored.migration.lastDailyImmigrants, 5)
        XCTAssertEqual(restored.migration.currentMonthImmigrants, 21)
        XCTAssertEqual(restored.migration.lastMonthImmigrants, 17)

        let tick = restored.advanceTick(rules: rules)

        XCTAssertEqual(tick.migratedResidents, 0)
        XCTAssertEqual(restored.population, 0)
        XCTAssertEqual(restored.migration.lastDailyImmigrants, 0)
        XCTAssertEqual(restored.migration.currentMonthImmigrants, 0)
        XCTAssertEqual(restored.migration.lastMonthImmigrants, 0)
        XCTAssertEqual(restored.migration.lastAssessment?.availableCapacity, 7)
    }

    func testUnsupportedMigrationSaveReplayIsIdenticalAndPopulationStaysFixed() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var uninterrupted = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 12,
            mapHeight: 5
        )
        _ = uninterrupted.buildRoad(
            (0..<12).map { GridPoint(x: $0, y: 2) },
            rules: rules
        )
        for x in [2, 5, 8] {
            _ = uninterrupted.addHouse(
                levelID: 0,
                location: GridPoint(x: x, y: 1),
                models: original.buildings
            )
        }
        for _ in 0..<3 { _ = uninterrupted.advanceTick(rules: rules) }

        let data = try JSONEncoder().encode(uninterrupted)
        var restored = try JSONDecoder().decode(DeterministicCityState.self, from: data)
        for _ in 0..<20 {
            _ = uninterrupted.advanceTick(rules: rules)
            _ = restored.advanceTick(rules: rules)
        }

        XCTAssertEqual(restored, uninterrupted)
        XCTAssertEqual(restored.population, 0)
        XCTAssertEqual(restored.migration.currentMonthImmigrants, 0)
    }

    private func installedModels() throws -> OriginalEconomyModels {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        return try OriginalEconomyModels(source: .openDefault())
    }

    func testLandEntryFloodFollowsRoadAndStopsAtWater() {
        let width = 7
        let height = 3
        var primary = [UInt16](repeating: 0x2, count: width * height)
        for x in 0..<width {
            primary[1 * width + x] = 0x4  // road row
        }

        let depths = DeterministicMigration.landEntryFloodDepths(
            width: width,
            height: height,
            primaryPassability: primary,
            seed: GridPoint(x: 0, y: 1)
        )

        XCTAssertEqual(depths.count, width * height)
        for x in 0..<width {
            XCTAssertEqual(depths[1 * width + x], x + 1, "road cell x=\(x)")
        }
        for y in [0, 2] {
            for x in 0..<width {
                XCTAssertNil(depths[y * width + x], "water cell (x=\(x), y=\(y)) must be unreached")
            }
        }
    }

    func testLandEntryFloodStopsAtBlockedGapAndPassesBareLand() {
        let width = 6
        let height = 1
        var primary = [UInt16](repeating: 0x10, count: width)  // bare land passes
        primary[3] = 0x2  // blocked gap

        let depths = DeterministicMigration.landEntryFloodDepths(
            width: width,
            height: height,
            primaryPassability: primary,
            seed: GridPoint(x: 0, y: 0)
        )

        XCTAssertEqual(depths[0], 1)
        XCTAssertEqual(depths[1], 2)
        XCTAssertEqual(depths[2], 3)
        XCTAssertNil(depths[3], "blocked gap must not flood")
        XCTAssertNil(depths[4], "cells beyond the gap must be unreached")
        XCTAssertNil(depths[5], "cells beyond the gap must be unreached")
    }

    func testLandEntryFloodMatchesRecoveredMaskOnHaunxianMap() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        guard let seed = map.authoredPoints.landEntry else {
            throw XCTSkip("Haunxian map has no authored land entry")
        }
        let city = DeterministicCityState(
            year: -246,
            treasury: 15_000,
            map: map
        )
        let grids = try city.grandCanalWorkerRoutingGrids()
        let flood = DeterministicMigration.landEntryFloodDepths(
            width: grids.width,
            height: grids.height,
            primaryPassability: grids.primaryPassability,
            seed: seed
        )

        XCTAssertEqual(flood.count, grids.primaryPassability.count)
        XCTAssertEqual(flood[seed.y * grids.width + seed.x], 1)

        var reached = 0
        var unreached = 0
        for (index, depth) in flood.enumerated() {
            if let depth {
                reached += 1
                XCTAssertGreaterThan(depth, 0)
                XCTAssertNotEqual(
                    grids.primaryPassability[index] & DeterministicMigration
                        .landEntryFloodPassMask,
                    0,
                    "reached cell \(index) must pass the 0xB7C mask"
                )
            } else {
                unreached += 1
            }
        }
        XCTAssertGreaterThan(reached, 0)
        XCTAssertGreaterThan(unreached, 0)

        // Determinism: same inputs, same depths.
        let again = DeterministicMigration.landEntryFloodDepths(
            width: grids.width,
            height: grids.height,
            primaryPassability: grids.primaryPassability,
            seed: seed
        )
        XCTAssertEqual(again, flood)
    }

    func testHouseAccessRefreshStoresFloodDepthAndClearsRetry() {
        let access = GridPoint(x: 4, y: 7)
        let outcome = DeterministicMigration.refreshHouseAccess(
            .init(
                candidateFound: true,
                selectedAccessPoint: access,
                floodDepth: 12,
                retryCount: 3
            )
        )

        XCTAssertTrue(outcome.ready)
        XCTAssertEqual(outcome.retryCount, 0)
        XCTAssertEqual(outcome.qualityDepth, 12)
        XCTAssertEqual(outcome.selectedAccessPoint, access)
        XCTAssertFalse(outcome.stateTransitionedToTwo)
        XCTAssertFalse(outcome.repairRequested)
    }

    func testHouseAccessCandidatePrefersStrictlyBestComponentRank() {
        let selected = DeterministicMigration.selectHouseAccessCandidate([
            .init(
                offset: .init(x: 0, y: -1),
                adjustedOffset: .init(x: 9, y: 9),
                terrainFlags: 0x40,
                floodDepth: 3,
                componentRank: 4
            ),
            .init(
                offset: .init(x: 1, y: 0),
                adjustedOffset: .init(x: 8, y: 8),
                terrainFlags: 0x40,
                floodDepth: 9,
                componentRank: 1
            ),
            .init(
                offset: .init(x: 0, y: 1),
                adjustedOffset: .init(x: 7, y: 7),
                terrainFlags: 0x40,
                floodDepth: 1,
                componentRank: 1
            )
        ])

        // Strict rank comparison keeps the first rank-1 row even though the
        // later row has a smaller flood depth.
        XCTAssertEqual(selected, .init(x: 8, y: 8))
    }

    func testHouseAccessCandidateFallsBackToStrictlySmallestFloodOnRawOffset() {
        let selected = DeterministicMigration.selectHouseAccessCandidate([
            .init(
                offset: .init(x: 0, y: -1),
                adjustedOffset: .init(x: 4, y: 4),
                objectCallbackAllowed: false,
                terrainFlags: 0x40,
                floodDepth: 5,
                componentRank: 0
            ),
            .init(
                offset: .init(x: 1, y: 0),
                adjustedOffset: .init(x: 5, y: 5),
                terrainFlags: 0,
                floodDepth: 2,
                componentRank: nil
            ),
            .init(
                offset: .init(x: 0, y: 1),
                adjustedOffset: .init(x: 6, y: 6),
                terrainFlags: 0,
                floodDepth: 2,
                componentRank: nil
            )
        ])

        // No ranked row qualifies; fallback ignores the adjusted point and
        // preserves the first raw-offset row on an equal-depth tie.
        XCTAssertEqual(selected, .init(x: 1, y: 0))
    }

    func testOriginalHouseAccessCandidateUsesAdjustedPointOnlyForRankedPass() {
        let perimeter = OriginalMultipartMonumentRoutingCatalog
            .roadAccessOffsets(footprintSide: 2)
        let selected = DeterministicMigration.selectOriginalHouseAccessCandidate(
            perimeter.enumerated().map { index, offset in
                .init(
                    rawOffset: offset,
                    testedOffset: index == 2 ? .init(x: 99, y: 99) : offset,
                    terrainFlags: index == 2 ? 0x40 : 0,
                    componentRank: index == 2 ? 0 : nil
                )
            }
        )

        XCTAssertEqual(selected, .init(x: 99, y: 99))
    }

    func testOriginalHouseAccessCandidateKeepsFirstEqualRankAndHasNoFloodFallback() {
        let candidates = [
            DeterministicMigration.OriginalHouseAccessCandidate(
                rawOffset: .init(x: 0, y: -1),
                testedOffset: .init(x: 5, y: 5),
                terrainFlags: 0x40,
                componentRank: 3
            ),
            DeterministicMigration.OriginalHouseAccessCandidate(
                rawOffset: .init(x: 1, y: 0),
                testedOffset: .init(x: 6, y: 6),
                terrainFlags: 0x40,
                componentRank: 3
            ),
        ]

        XCTAssertEqual(
            DeterministicMigration.selectOriginalHouseAccessCandidate(candidates),
            .init(x: 5, y: 5)
        )
        XCTAssertNil(
            DeterministicMigration.selectOriginalHouseAccessCandidate([
                .init(
                    rawOffset: .init(x: 2, y: 0),
                    objectPathAccepted: false,
                    terrainFlags: 0x40
                )
            ])
        )
    }

    func testOriginalImmigrantHouseSelectorAppliesSourceGatesAndFirstStrictNearest() {
        let candidates = [
            DeterministicMigration.OriginalImmigrantHouseCandidate(
                vectorIndex: 1,
                houseCallbackAllowed: false,
                accessValue: 9,
                remainingCapacity: 4,
                rawDistancePoint: .init(x: 1, y: 1)
            ),
            DeterministicMigration.OriginalImmigrantHouseCandidate(
                vectorIndex: 2,
                accessValue: 0,
                remainingCapacity: 4,
                rawDistancePoint: .init(x: 2, y: 2)
            ),
            DeterministicMigration.OriginalImmigrantHouseCandidate(
                vectorIndex: 3,
                accessValue: 9,
                remainingCapacity: 4,
                linkedFigureID: 8,
                rawDistancePoint: .init(x: 3, y: 3)
            ),
            DeterministicMigration.OriginalImmigrantHouseCandidate(
                vectorIndex: 4,
                accessValue: 9,
                remainingCapacity: 4,
                rawDistancePoint: .init(x: 4, y: 4)
            ),
            DeterministicMigration.OriginalImmigrantHouseCandidate(
                vectorIndex: 5,
                accessValue: 9,
                remainingCapacity: 4,
                rawDistancePoint: .init(x: 4, y: 4)
            )
        ]

        XCTAssertEqual(
            DeterministicMigration.selectOriginalImmigrantHouse(
                from: .init(x: 0, y: 0),
                globalGateOpen: true,
                candidates: candidates
            ),
            4
        )
        XCTAssertNil(
            DeterministicMigration.selectOriginalImmigrantHouse(
                from: .init(x: 0, y: 0),
                globalGateOpen: false,
                candidates: candidates
            )
        )
    }

    func testOriginalImmigrantHouseSelectorPreservesSignedShortsAndDistanceSentinel() {
        let wrapped = DeterministicMigration.OriginalImmigrantHouseCandidate(
            vectorIndex: 1,
            accessValue: 0xFFFF,
            remainingCapacity: 0x0001,
            rawDistancePoint: .init(x: 0xFFFF, y: 0x0000)
        )
        XCTAssertEqual(wrapped.accessValue, -1)
        XCTAssertEqual(wrapped.rawDistancePoint.x, -1)

        let candidates = [
            DeterministicMigration.OriginalImmigrantHouseCandidate(
                vectorIndex: 1,
                accessValue: 1,
                remainingCapacity: 1,
                rawDistancePoint: .init(x: 1000, y: 0)
            ),
            DeterministicMigration.OriginalImmigrantHouseCandidate(
                vectorIndex: 2,
                accessValue: 1,
                remainingCapacity: 1,
                rawDistancePoint: .init(x: 999, y: 0)
            )
        ]
        XCTAssertEqual(
            DeterministicMigration.selectOriginalImmigrantHouse(
                from: .init(x: 0, y: 0),
                globalGateOpen: true,
                candidates: candidates
            ),
            2
        )
    }

    func testRecoveredHouseRoadAccessUsesOriginalPerimeterAndComponentRank() {
        let origin = GridPoint(x: 10, y: 10)
        let offsets = OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(
            footprintSide: 2
        )
        let ranks = Dictionary(uniqueKeysWithValues: offsets.enumerated().map {
            index, offset in
            let point = GridPoint(x: origin.x + offset.x, y: origin.y + offset.y)
            // A later rank-0 candidate beats earlier rank-1/2 candidates; a
            // second rank-0 candidate would lose to it by strict comparison.
            return (point, index == 6 ? 0 : (index == 0 ? 1 : 2))
        })

        XCTAssertEqual(
            DeterministicMigration.recoveredHouseRoadAccessPoint(
                houseLocation: origin,
                vacantBuildingID: 2,
                roadComponentRankByPoint: ranks
            ),
            GridPoint(x: 9, y: 11)
        )
        XCTAssertNil(
            DeterministicMigration.recoveredHouseRoadAccessPoint(
                houseLocation: origin,
                vacantBuildingID: 999,
                roadComponentRankByPoint: ranks
            )
        )
    }

    func testHouseAccessObjectCallbackRejectsRecoveredModelPredicateIDs() {
        let rejected = [0x7E, 0xE7, 0x5B, 0x5A, 0x59, 0xE8, 0x6A, 0x69, 0x68]
        for modelID in rejected {
            let outcome = DeterministicMigration.houseAccessObjectCallback(
                modelID: modelID,
                linearOffset: 1_000,
                terrainFlags: 0,
                roadDirectionByte: 1
            )
            XCTAssertEqual(outcome.callbackReturn, -1, "model 0x\(String(modelID, radix: 16))")
            XCTAssertFalse(outcome.accepted)
            XCTAssertEqual(outcome.adjustedLinearOffset, 1_000)
        }
    }

    func testHouseAccessObjectCallbackKeepsOrdinaryModelsAtRawOffset() {
        let outcome = DeterministicMigration.houseAccessObjectCallback(
            modelID: 2,
            linearOffset: 1_000,
            terrainFlags: 0,
            roadDirectionByte: 1
        )
        XCTAssertEqual(outcome.callbackReturn, 0)
        XCTAssertTrue(outcome.accepted)
        XCTAssertEqual(outcome.adjustedLinearOffset, 1_000)
    }

    func testHouseAccessObjectCallbackAppliesGrandWayDirectionOnlyOffRoad() {
        let east = DeterministicMigration.houseAccessObjectCallback(
            modelID: 0x6F,
            linearOffset: 1_000,
            terrainFlags: 0,
            roadDirectionByte: 1
        )
        let west = DeterministicMigration.houseAccessObjectCallback(
            modelID: 0x71,
            linearOffset: 1_000,
            terrainFlags: 0,
            roadDirectionByte: 2
        )
        let south = DeterministicMigration.houseAccessObjectCallback(
            modelID: 0x6F,
            linearOffset: 1_000,
            terrainFlags: 0,
            roadDirectionByte: 0x08
        )
        let north = DeterministicMigration.houseAccessObjectCallback(
            modelID: 0x71,
            linearOffset: 1_000,
            terrainFlags: 0,
            roadDirectionByte: 0
        )
        let alreadyRoad = DeterministicMigration.houseAccessObjectCallback(
            modelID: 0x6F,
            linearOffset: 1_000,
            terrainFlags: 0x40,
            roadDirectionByte: 1
        )

        XCTAssertEqual(east.adjustedLinearOffset, 1_001)
        XCTAssertEqual(west.adjustedLinearOffset, 999)
        XCTAssertEqual(south.adjustedLinearOffset, 1_000 + 0xE4)
        XCTAssertEqual(north.adjustedLinearOffset, 1_000 - 0xE4)
        XCTAssertEqual(alreadyRoad.adjustedLinearOffset, 1_000)
        XCTAssertEqual(east.callbackReturn, 1)
        XCTAssertEqual(alreadyRoad.callbackReturn, 1)
    }

    func testHouseAccessRefreshCandidateFailureUsesFourRetryRepairBoundary() {
        let outcome = DeterministicMigration.refreshHouseAccess(
            .init(candidateFound: false, retryCount: 4, houseField20: 1)
        )

        XCTAssertTrue(outcome.ready, "repair branch resets retry to zero")
        XCTAssertEqual(outcome.retryCount, 0)
        XCTAssertEqual(outcome.qualityDepth, 0)
        XCTAssertTrue(outcome.stateTransitionedToTwo)
        XCTAssertTrue(outcome.repairRequested)
    }

    func testHouseAccessRefreshZeroFloodExternalFallbackAndEightRetryBoundary() {
        let first = DeterministicMigration.refreshHouseAccess(
            .init(
                candidateFound: true,
                selectedAccessPoint: GridPoint(x: 1, y: 2),
                floodDepth: 0,
                retryCount: 0,
                houseType: 2,
                houseField20: 0,
                externalValue: 0,
                externalFallbackValue: 99
            )
        )
        XCTAssertFalse(first.ready)
        XCTAssertEqual(first.retryCount, 1)
        XCTAssertEqual(first.externalValue, 99)
        XCTAssertFalse(first.stateTransitionedToTwo)

        let exhausted = DeterministicMigration.refreshHouseAccess(
            .init(
                candidateFound: true,
                floodDepth: 0,
                retryCount: 8,
                houseType: 2,
                houseField20: 0,
                externalValue: 5,
                externalFallbackValue: 99
            )
        )
        XCTAssertTrue(exhausted.ready)
        XCTAssertEqual(exhausted.retryCount, 0)
        XCTAssertTrue(exhausted.stateTransitionedToTwo)
        XCTAssertFalse(exhausted.repairRequested)
    }

    func testSettlingLockSetOnDevolutionDisplacement() throws {
        let models = try installedModels().buildings
        var house = ResidentialUnit(
            id: 1,
            houseLevelID: 1,
            residents: 40,
            location: GridPoint(x: 2, y: 2),
            desirability: -100
        )
        var houses = [house]

        let settlement = DeterministicHousingEvolution.settle(
            houses: &houses,
            models: models,
            difficulty: .normal
        )

        let devolve = settlement.changes.first {
            $0.direction == .devolved && $0.displacedResidents > 0
        }
        XCTAssertNotNil(devolve, "expected a devolution that displaces residents")
        XCTAssertEqual(houses[0].settlingLock, 2)
        XCTAssertEqual(houses[0].settlingLockRemainingSteps, 32)
        XCTAssertEqual(houses[0].residents, houses[0].capacity(using: models))
    }

    func testSettlingLockClearsAfterCountdownAndWhenEmpty() {
        var house = ResidentialUnit(id: 1, houseLevelID: 1, residents: 4)
        house.startSettlingLock()
        XCTAssertEqual(house.settlingLock, 2)
        XCTAssertEqual(house.settlingLockRemainingSteps, 32)

        for _ in 0..<31 {
            house.advanceSettlingLock()
        }
        XCTAssertEqual(house.settlingLock, 2, "lock must survive 31 daily advances")
        XCTAssertEqual(house.settlingLockRemainingSteps, 1)
        house.advanceSettlingLock()
        XCTAssertEqual(house.settlingLock, 0, "lock must clear on the 32nd advance")
        XCTAssertEqual(house.settlingLockRemainingSteps, 0)

        var emptied = ResidentialUnit(id: 2, houseLevelID: 1, residents: 0)
        emptied.startSettlingLock()
        emptied.advanceSettlingLock()
        XCTAssertEqual(emptied.settlingLock, 0, "empty house clears immediately")
        XCTAssertEqual(emptied.settlingLockRemainingSteps, 0)
    }

    func testSettlingLockPreservedBySaveRoundTrip() throws {
        var house = ResidentialUnit(id: 7, houseLevelID: 1, residents: 3)
        house.startSettlingLock()
        house.advanceSettlingLock()
        house.setOriginalRemainingCapacity(-3)
        house.setOriginalInFlightFigureID(12)

        let data = try JSONEncoder().encode(house)
        let restored = try JSONDecoder().decode(ResidentialUnit.self, from: data)

        XCTAssertEqual(restored.settlingLock, house.settlingLock)
        XCTAssertEqual(restored.settlingLockRemainingSteps, house.settlingLockRemainingSteps)
        XCTAssertEqual(restored.originalRemainingCapacity, -3)
        XCTAssertEqual(restored.originalInFlightFigureID, 12)

        // Old saves without the fields decode as unlocked.
        let legacy = """
        {"id":1,"houseLevelID":0,"residents":2,"hasTaxCoverage":false,
         "footprintMultiplier":1,"location":{"x":1,"y":1},
         "orientation":0,"suppliesByCommodityID":{},
         "commodityShortageMonths":0,"foodSupplyAmount":0,
         "foodQualityRawValue":0,"serviceCoverage":[],
         "desirability":0,"lastSuppliedFoodQualityRawValue":0,
         "lastSuppliedCommodityIDs":[]}
        """
        let decoded = try JSONDecoder().decode(ResidentialUnit.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.settlingLock, 0)
        XCTAssertEqual(decoded.settlingLockRemainingSteps, 0)
        XCTAssertNil(decoded.originalRemainingCapacity)
        XCTAssertNil(decoded.originalInFlightFigureID)
    }

    func testRecoveredHouseAccessWordsPersistAsOptionalSignedProjection() throws {
        var house = ResidentialUnit(id: 8, houseLevelID: 0, residents: 4)
        XCTAssertNil(house.originalHouseAccessValue)
        XCTAssertNil(house.originalHouseAccessPoint)
        XCTAssertNil(house.originalHouseAccessRetryCount)
        XCTAssertNil(house.originalCapacityHighWater)

        house.setOriginalHouseAccess(
            value: 37_000,
            point: GridPoint(x: 4, y: 5),
            retryCount: -40_000
        )
        house.setOriginalCapacityHighWater(40_000)

        XCTAssertEqual(house.originalHouseAccessValue, Int(Int16.max))
        XCTAssertEqual(house.originalHouseAccessPoint, GridPoint(x: 4, y: 5))
        XCTAssertEqual(house.originalHouseAccessRetryCount, Int(Int16.min))
        XCTAssertEqual(house.originalCapacityHighWater, Int(Int16.max))

        let restored = try JSONDecoder().decode(
            ResidentialUnit.self,
            from: JSONEncoder().encode(house)
        )
        XCTAssertEqual(restored.originalHouseAccessValue, house.originalHouseAccessValue)
        XCTAssertEqual(restored.originalHouseAccessPoint, house.originalHouseAccessPoint)
        XCTAssertEqual(restored.originalHouseAccessRetryCount, house.originalHouseAccessRetryCount)
        XCTAssertEqual(restored.originalCapacityHighWater, house.originalCapacityHighWater)
    }

    func testImmigrantWalkerWaitsThenWalksThenArrives() {
        let route = [
            GridPoint(x: 0, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
        ]
        var walker = ImmigrantWalker(
            id: 1,
            houseID: 7,
            peopleCount: 3,
            entryPoint: route[0],
            route: route,
            waitSteps: 5
        )
        XCTAssertEqual(walker.state, .waiting)

        for _ in 0..<5 {
            XCTAssertFalse(walker.advanceOneUpdate())
        }
        XCTAssertEqual(walker.state, .walking)
        XCTAssertEqual(walker.waitStepsRemaining, 0)

        var arrived = false
        var updates = 0
        while updates < 500, !arrived {
            arrived = walker.advanceOneUpdate()
            updates += 1
        }
        XCTAssertTrue(arrived, "walker must arrive within 500 updates")
        XCTAssertEqual(walker.state, .arriving)
        XCTAssertEqual(walker.currentPoint, route[3])
    }

    func testImmigrantWalkerMovementCadenceMatchesRecoveredTiming() {
        // 6 route points = 5 crossings. Initial progress 20 makes the first
        // crossing immediate; then each crossing needs 20 substeps, which the
        // 1/1/2 pattern delivers in 15 updates.
        let route = (0..<6).map { GridPoint(x: $0, y: 0) }
        var walker = ImmigrantWalker(
            id: 2,
            houseID: 9,
            peopleCount: 1,
            entryPoint: route[0],
            route: route,
            waitSteps: 0
        )
        XCTAssertEqual(walker.state, .walking)
        XCTAssertEqual(walker.substepProgress, 20)

        var updates = 0
        var arrived = false
        while updates < 200, !arrived {
            arrived = walker.advanceOneUpdate()
            updates += 1
        }
        // Crossings at updates 1, 15, 30, 45, 60 (initial progress 20 makes
        // the first crossing immediate; each further crossing needs 20
        // substeps, delivered by the 1/1/2 pattern in 15 updates). The walker
        // reaches the last point on update 60 and the arrival fires on 61.
        XCTAssertEqual(updates, 61, "arrival must follow the recovered 1/1/2 cadence")
    }

    func testImmigrantWalkerAnimationFrameUsesSourceTwelveFrameCounter() {
        var walker = ImmigrantWalker(
            id: 3,
            houseID: 10,
            peopleCount: 1,
            entryPoint: GridPoint(x: 0, y: 0),
            route: [GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0)],
            waitSteps: 0
        )
        XCTAssertEqual(walker.sourceAnimationFrame, 0)
        XCTAssertFalse(walker.movedOnLastSimulationStep == true)

        for expected in 1...12 {
            _ = walker.advanceOneUpdate()
            XCTAssertEqual(walker.sourceAnimationFrame, expected % 12)
            if expected == 1 {
                XCTAssertTrue(walker.movedOnLastSimulationStep == true)
            }
        }
    }

    func testCitySpawnedImmigrantArrivesAndActivatesVacantHouse() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        guard let entry = map.authoredPoints.landEntry else {
            throw XCTSkip("Haunxian map has no authored land entry")
        }
        let original = try installedModels()
        let models = original.buildings
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: -246, treasury: 15_000, map: map)

        // Build a short road from the entry and put a common vacant house and
        // an elite vacant house beside it.
        var road = [entry]
        var cursor = entry
        var guardSteps = 0
        while road.count < 5, guardSteps < 80 {
            guardSteps += 1
            let next = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
                .first { point in
                    city.terrain?.isClearLand(point) == true
                        && !city.roadNetwork.contains(point)
                        && !city.occupiedBuildingPoints.contains(point)
                }
            guard let next else { break }
            _ = city.buildRoad([next], rules: rules)
            road.append(next)
            cursor = next
        }
        XCTAssertGreaterThanOrEqual(road.count, 3, "could not lay a road from the entry")

        let candidateHousePoint = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
            .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            .first { city.terrain?.isClearLand($0) == true }
        let housePoint = try XCTUnwrap(candidateHousePoint)
        let commonID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            location: housePoint,
            vacantTypeID: 2,
            models: models
        ))

        let grids = try city.grandCanalWorkerRoutingGrids()
        let walkerID = try XCTUnwrap(city.spawnImmigrant(
            houseID: commonID,
            peopleCount: 4,
            grids: grids
        ))
        XCTAssertEqual(walkerID, 1)
        XCTAssertEqual(city.migration.immigrantWalkers.count, 1)
        XCTAssertEqual(
            city.houses.first(where: { $0.id == commonID })?.originalInFlightFigureID,
            walkerID,
            "successful immigrant allocation must link house+0x32"
        )

        var ticks = 0
        while city.migration.immigrantWalkers.contains(where: { $0.id == walkerID }),
              ticks < 30 * 12 {
            _ = city.advanceTick(rules: rules)
            ticks += 1
        }

        XCTAssertFalse(
            city.migration.immigrantWalkers.contains(where: { $0.id == walkerID }),
            "immigrant must arrive within 12 months"
        )
        let house = try XCTUnwrap(city.houses.first(where: { $0.id == commonID }))
        XCTAssertGreaterThan(house.residents, 0)
        XCTAssertNil(house.vacantTypeID, "first arrival must activate the vacant house")
        XCTAssertNil(house.originalInFlightFigureID, "arrival must clear house+0x32")
        XCTAssertEqual(house.originalRemainingCapacity, 3, "arrival must retain the source spare-room word")
    }

    func testUnoccupiedEliteUsesNextLevelCapacityForAssignment() throws {
        let original = try installedModels()
        let models = original.buildings

        XCTAssertEqual(
            models[houseLevelID: 8]?.populationCapacity,
            0,
            "the authored Elite: Unoccupied placeholder is zero-capacity"
        )
        XCTAssertEqual(
            models[houseLevelID: 9]?.populationCapacity,
            1,
            "FUN_004AD3D0 adds one to the vacant elite level index"
        )
        XCTAssertEqual(
            DeterministicMigration.assignmentRemainingCapacity(
                houseLevelID: 8,
                vacantTypeID: 11,
                residents: 0,
                footprintMultiplier: 1,
                settlingLock: 0,
                models: models
            ),
            1
        )
        XCTAssertEqual(
            DeterministicMigration.assignmentRemainingCapacity(
                houseLevelID: 8,
                vacantTypeID: 11,
                residents: 0,
                footprintMultiplier: 1,
                settlingLock: 2,
                models: models
            ),
            0
        )
    }

    func testOriginalCapacityRefreshUsesAccessGateAndHighWater() throws {
        let models = try installedModels().buildings

        let eligible = DeterministicMigration.originalCapacityRefresh(
            .init(
                houseTypeID: 2,
                houseLevelIndex: 0,
                houseResidents: 3,
                houseAccessValue: 12,
                previousHighWater: 2
            ),
            models: models
        )
        XCTAssertEqual(eligible?.included, true)
        XCTAssertEqual(eligible?.capacityContribution, 7)
        XCTAssertEqual(eligible?.remainingCapacity, 4)
        XCTAssertEqual(eligible?.highWater, 3)

        let locked = DeterministicMigration.originalCapacityRefresh(
            .init(
                houseTypeID: 2,
                houseLevelIndex: 0,
                houseResidents: 3,
                houseAccessValue: 12,
                cHouseInfoSettlingByte: 2,
                previousHighWater: 5
            ),
            models: models
        )
        XCTAssertEqual(locked?.capacityContribution, 3)
        XCTAssertEqual(locked?.remainingCapacity, 0)
        XCTAssertEqual(locked?.highWater, 5)

        let inaccessible = DeterministicMigration.originalCapacityRefresh(
            .init(
                houseTypeID: 2,
                houseLevelIndex: 0,
                houseResidents: 3,
                houseAccessValue: 0,
                previousHighWater: 5
            ),
            models: models
        )
        XCTAssertEqual(inaccessible?.included, false)
        XCTAssertEqual(inaccessible?.remainingCapacity, 0)
        XCTAssertEqual(inaccessible?.highWater, 5)
    }

    func testImmigrantArrivalSkippedWhileSettlingLockIsSet() throws {
        let original = try installedModels()
        let models = original.buildings
        var city = DeterministicCityState(year: -246, treasury: 15_000, mapWidth: 12, mapHeight: 5)
        _ = city.buildRoad((0..<6).map { GridPoint(x: $0, y: 2) }, rules: EconomyRulesEngine(models: original))
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            residents: 0,
            location: GridPoint(x: 2, y: 1),
            models: models
        ))
        _ = try XCTUnwrap(city.houses.first(where: { $0.id == houseID }))

        // Directly exercise the arrival write against the settling gate.
        XCTAssertTrue(city.startHouseSettlingLock(houseID: houseID))
        XCTAssertFalse(city.applyImmigrantArrival(
            ImmigrantArrival(houseID: houseID, peopleCount: 3),
            models: models
        ))
        XCTAssertEqual(city.houses[0].residents, 0)

        // Drain the countdown through the daily tick loop.
        var ticks = 0
        while city.houses[0].settlingLock != 0, ticks < 40 {
            _ = city.advanceTick(rules: EconomyRulesEngine(models: original))
            ticks += 1
        }
        XCTAssertEqual(city.houses[0].settlingLock, 0)
        XCTAssertTrue(city.applyImmigrantArrival(
            ImmigrantArrival(houseID: houseID, peopleCount: 3),
            models: models
        ))
        XCTAssertEqual(city.houses[0].residents, 3)
    }

    func testImmigrantArrivalConvertsLockedVacantHouseBeforeSettlingGate() throws {
        let original = try installedModels()
        let models = original.buildings
        var city = DeterministicCityState(year: -246, treasury: 15_000, mapWidth: 12, mapHeight: 5)
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 8,
            residents: 0,
            location: GridPoint(x: 2, y: 1),
            vacantTypeID: 11,
            models: models
        ))

        XCTAssertTrue(city.startHouseSettlingLock(houseID: houseID))
        XCTAssertFalse(city.applyImmigrantArrival(
            ImmigrantArrival(houseID: houseID, peopleCount: 3),
            models: models
        ))

        let house = try XCTUnwrap(city.houses.first(where: { $0.id == houseID }))
        XCTAssertEqual(house.houseLevelID, 10, "vacant elite must switch before the settling gate")
        XCTAssertNil(house.vacantTypeID)
        XCTAssertEqual(house.residents, 0, "settling gate must still block the resident write")
    }

    func testImmigrantArrivalDoesNotReclampAlreadyOccupiedHouse() throws {
        let original = try installedModels()
        let models = original.buildings
        var city = DeterministicCityState(year: -246, treasury: 15_000, mapWidth: 12, mapHeight: 5)
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            residents: 6,
            location: GridPoint(x: 2, y: 1),
            models: models
        ))

        XCTAssertTrue(city.applyImmigrantArrival(
            ImmigrantArrival(houseID: houseID, peopleCount: 3),
            models: models
        ))

        let house = try XCTUnwrap(city.houses.first(where: { $0.id == houseID }))
        XCTAssertEqual(house.residents, 9, "occupied-house arrival writes the raw figure count")
    }

    func testOriginalHouseInfoRemovalLockPreservesLedgerWidthAndRefreshOrder() {
        let result = OriginalHouseInfoRemovalLock.apply(
            residentWord: 20,
            convertedCount: 7,
            cHouseInfoByte3C: 2,
            refreshedRegistryID: 41
        )
        XCTAssertEqual(result.residentWordAfter, 13)
        XCTAssertEqual(result.populationLedgerDelta, -7)
        XCTAssertEqual(result.cHouseInfoByte3C, 2)
        XCTAssertEqual(result.countdown98, 0x20)
        XCTAssertTrue(result.clearedFieldA4)
        XCTAssertEqual(result.refreshedRegistryID, 41)

        // The source passes the full `__ftol` result to the population
        // ledger, but truncates it to a signed short for house `+0x20`.
        let wrapped = OriginalHouseInfoRemovalLock.apply(
            residentWord: 0,
            convertedCount: 0xFFFF,
            cHouseInfoByte3C: 0xFF,
            refreshedRegistryID: 1
        )
        XCTAssertEqual(wrapped.residentWordAfter, 1)
        XCTAssertEqual(wrapped.populationLedgerDelta, -0xFFFF)
        XCTAssertEqual(wrapped.cHouseInfoByte3C, 0xFF)
        XCTAssertEqual(wrapped.countdown98, 32)

        let signed32 = OriginalHouseInfoRemovalLock.apply(
            residentWord: 10,
            convertedCount: Int(UInt32.max),
            cHouseInfoByte3C: 2,
            refreshedRegistryID: 9
        )
        XCTAssertEqual(signed32.residentWordAfter, 11)
        XCTAssertEqual(signed32.populationLedgerDelta, 1)
    }

    func testOriginalImmigrantArrivalWritePreservesSourceOrderingAndGates() {
        let lockedVacant = DeterministicMigration.originalImmigrantArrivalWrite(
            .init(
                houseTypeID: 2,
                houseResidents: 0,
                figurePeopleCount: 7,
                capacitySnapshot: 4,
                houseInfoSettlingByte: 2
            )
        )
        XCTAssertEqual(lockedVacant.vacantConversionArgument, 3)
        XCTAssertEqual(lockedVacant.resultingHouseTypeID, 3)
        XCTAssertEqual(lockedVacant.residentWriteCount, 4)
        XCTAssertEqual(lockedVacant.residentDelta, 0)
        XCTAssertEqual(lockedVacant.resultingResidents, 0)
        XCTAssertEqual(lockedVacant.remainingCapacity, 4)
        XCTAssertFalse(lockedVacant.invokedPopulationWriter)
        XCTAssertTrue(lockedVacant.clearedHouseLink)

        let occupied = DeterministicMigration.originalImmigrantArrivalWrite(
            .init(
                houseTypeID: 10,
                houseResidents: 3,
                figurePeopleCount: 9,
                capacitySnapshot: 5
            )
        )
        XCTAssertNil(occupied.vacantConversionArgument)
        XCTAssertEqual(occupied.residentWriteCount, 9)
        XCTAssertEqual(occupied.residentDelta, 9)
        XCTAssertEqual(occupied.resultingResidents, 12)
        XCTAssertEqual(occupied.remainingCapacity, -7)
        XCTAssertTrue(occupied.invokedPopulationWriter)

        let skippedSwitch = DeterministicMigration.originalImmigrantArrivalWrite(
            .init(
                houseTypeID: 11,
                houseResidents: 0,
                figurePeopleCount: 2,
                capacitySnapshot: 3,
                typeSwitchGateNonzero: true
            )
        )
        XCTAssertNil(skippedSwitch.vacantConversionArgument)
        XCTAssertEqual(skippedSwitch.resultingHouseTypeID, 11)
        XCTAssertEqual(skippedSwitch.residentDelta, 2)
        XCTAssertTrue(skippedSwitch.invokedPopulationWriter)
    }

    func testOriginalImmigrantCapacitySnapshotUsesLoaderRowsAndEliteSpecialCase() throws {
        let models = try installedModels().buildings

        // `ALL HOUSES` is loaded zero-based into DAT_00A63BFC; field 0x11 is
        // the population-capacity column.  The authored normal rows provide
        // an independent check against the generic Native level lookup.
        XCTAssertEqual(models.originalHouseCapacity(sourceRow: 0), 7)
        XCTAssertEqual(models.originalHouseCapacity(sourceRow: 8), 0)
        XCTAssertEqual(models.originalHouseCapacity(sourceRow: 9), 1)
        XCTAssertEqual(models.originalHouseCapacity(sourceRow: 11), 10)

        XCTAssertEqual(
            DeterministicMigration.originalImmigrantCapacitySnapshot(
                houseTypeID: 2,
                houseLevelIndex: 0,
                models: models
            ),
            7
        )
        XCTAssertEqual(
            DeterministicMigration.originalImmigrantCapacitySnapshot(
                houseTypeID: 11,
                houseLevelIndex: 8,
                models: models
            ),
            10,
            "arrival uses source row 0xB for Unoccupied Elite before +0x230"
        )
        XCTAssertNil(models.originalHouseCapacity(sourceRow: 99))
    }

    func testOriginalCapacityOverflowReconciliationPreservesMinimumResident() {
        let ordinary = DeterministicMigration.originalCapacityOverflowReconciliation(
            .init(residents: 10, remainingCapacity: -3)
        )
        XCTAssertEqual(ordinary.spawnedVagrantPeople, 3)
        XCTAssertEqual(ordinary.resultingResidents, 7)
        XCTAssertTrue(ordinary.invokedVagrantSpawn)

        let fullEviction = DeterministicMigration.originalCapacityOverflowReconciliation(
            .init(residents: 3, remainingCapacity: -3)
        )
        XCTAssertEqual(fullEviction.spawnedVagrantPeople, 3)
        XCTAssertEqual(fullEviction.resultingResidents, 1)

        let noOverflow = DeterministicMigration.originalCapacityOverflowReconciliation(
            .init(residents: 8, remainingCapacity: 0)
        )
        XCTAssertEqual(noOverflow.spawnedVagrantPeople, 0)
        XCTAssertEqual(noOverflow.resultingResidents, 8)
        XCTAssertFalse(noOverflow.invokedVagrantSpawn)
    }

    func testPopularityFactorMathAndPressureBands() {
        XCTAssertEqual(
            DeterministicMigration.OriginalWageEffectCatalog.thresholds,
            [0, 20, 26, 30, 34, 40]
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalWageEffectCatalog.effects,
            [-10, -5, -2, 0, 2, 4]
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalWageEffectCatalog.baselineWage,
            30
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalWageEffectCatalog.matcherAddress,
            0x00592BD0
        )
        XCTAssertEqual(
            DeterministicMigration.OriginalWageEffectCatalog.currentWageAddress,
            0x01312214
        )
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 30), 0)
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 20), -5)
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 26), -2)
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 40), 4)
        // 23 is equidistant from 20 and 26; the source's strict `<` keeps
        // the first threshold/effect row.
        XCTAssertEqual(DeterministicMigration.wageEffect(currentWage: 23), -5)

        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 4), 1)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 8), 0)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 14), -1)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 20), -2)
        XCTAssertEqual(DeterministicMigration.employmentEffect(unemploymentPercent: 30), -3)

        XCTAssertEqual(DeterministicMigration.debtEffect(debtYears: 2, treasuryIsNegative: true), 0)
        XCTAssertEqual(DeterministicMigration.debtEffect(debtYears: 3, treasuryIsNegative: true), 1)

        XCTAssertEqual(DeterministicMigration.fengShuiEffect(population: 100, harmonyPercent: 100), 0)
        XCTAssertEqual(DeterministicMigration.fengShuiEffect(population: 400, harmonyPercent: 95), 1)
        XCTAssertEqual(DeterministicMigration.fengShuiEffect(population: 400, harmonyPercent: 55), -3)

        // `FUN_00591670` first derives the truncated percentage from the
        // weighted object sums; classification itself remains a separate,
        // unresolved producer boundary.
        XCTAssertEqual(
            DeterministicMigration.fengShuiEffect(
                population: 350,
                harmoniousWeight: 100,
                totalWeight: 100
            ),
            0
        )
        XCTAssertEqual(
            DeterministicMigration.fengShuiEffect(
                population: 351,
                harmoniousWeight: 95,
                totalWeight: 100
            ),
            1
        )
        XCTAssertEqual(
            DeterministicMigration.fengShuiEffect(
                population: 351,
                harmoniousWeight: 55,
                totalWeight: 100
            ),
            -3
        )
        XCTAssertEqual(
            DeterministicMigration.fengShuiEffect(
                population: 351,
                harmoniousWeight: 1,
                totalWeight: 0
            ),
            0
        )

        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 100, watchtowerCount: 2), 0)
        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 400, watchtowerCount: 0), 0)
        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 400, watchtowerCount: 1), -1)
        XCTAssertEqual(DeterministicMigration.repressionEffect(population: 1000, watchtowerCount: 10), -4)

        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 10), -25)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 30), -8)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 45), 0)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 60), 50)
        XCTAssertEqual(DeterministicMigration.pressureBand(popularity: 80), 100)
        // FUN_0043B860 performs positive integer ceil division: non-integral
        // 12×amount/100 values advance to the next person rather than being
        // truncated. These boundaries distinguish the source helper from a
        // tempting floor implementation.
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 1), 1)
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 8), 1)
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 9), 2)
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 50), 6)
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 75), 9)
        XCTAssertEqual(DeterministicMigration.requestSize(forAbsolutePressure: 100), 12)

        // §2 exact apply branches: raw sum when popularity < 61 or sum >= 0
        // under 41; biased otherwise, clamped when the biased sum crosses zero.
        XCTAssertEqual(DeterministicMigration.dampedPopularityDelta(current: 60, factorSum: 10), 10)
        XCTAssertEqual(DeterministicMigration.dampedPopularityDelta(current: 10, factorSum: -2), 0)
        XCTAssertEqual(DeterministicMigration.dampedPopularityDelta(current: 30, factorSum: -8), -6)

        XCTAssertEqual(
            DeterministicMigration.monumentPopularityTerm(
                goalBuildingIDs: [77, 85],
                completeRootBuildingIDs: [77, 253]
            ),
            4
        )
    }

    func testPopularityProducerFactorPassPreservesSourceSumAndBlameOrder() {
        let foodFailure = DeterministicMigration
            .originalPopularityProducerFactors(
                .init(
                    currentPopularity: 30,
                    taxFactor: 0,
                    wageFactor: 0,
                    employmentFactor: -2,
                    foodFactor: -2,
                    debtFactor: 0,
                    monumentPairCount: 1,
                    fengShuiFactor: 0,
                    repressionFactor: 0,
                    previousFactorBlame: 4
                )
            )
        // 0 + 0 - 2 - 2 + 0 + (1 × 2) + 0 + 0 + 1 = -1.
        XCTAssertEqual(foodFailure.factorSum, -1)
        // At popularity 30 the source's positive bias is 1, so a -1 sum is
        // damped to zero rather than lowering the stored popularity.
        XCTAssertEqual(foodFailure.popularityDelta, 0)
        XCTAssertEqual(foodFailure.popularity, 30)
        XCTAssertEqual(foodFailure.factorBlame, 1)
        XCTAssertEqual(foodFailure.worstFactor, -2)

        let retainedBlame = DeterministicMigration
            .originalPopularityProducerFactors(
                .init(
                    currentPopularity: 60,
                    taxFactor: 0,
                    wageFactor: 0,
                    employmentFactor: 0,
                    foodFactor: 0,
                    debtFactor: 0,
                    monumentPairCount: 0,
                    fengShuiFactor: 0,
                    repressionFactor: 0,
                    factorSixForBlame: 0,
                    previousFactorBlame: 5
                )
            )
        XCTAssertEqual(retainedBlame.factorSum, 1)
        XCTAssertEqual(retainedBlame.popularity, 61)
        XCTAssertEqual(retainedBlame.factorBlame, 5)
        XCTAssertEqual(retainedBlame.worstFactor, 0)
    }

    func testPopularityProducerFactorPassClampsStoredPopularityAtSourceBoundary() {
        let upper = DeterministicMigration.originalPopularityProducerFactors(
            .init(
                currentPopularity: 99,
                taxFactor: 20,
                wageFactor: 20,
                employmentFactor: 20,
                foodFactor: 20,
                debtFactor: 20,
                monumentPairCount: 0,
                fengShuiFactor: 0,
                repressionFactor: 0
            )
        )
        XCTAssertGreaterThan(upper.popularityDelta, 0)
        XCTAssertEqual(upper.popularity, 100)

        let lower = DeterministicMigration.originalPopularityProducerFactors(
            .init(
                currentPopularity: 1,
                taxFactor: -20,
                wageFactor: -20,
                employmentFactor: -20,
                foodFactor: -20,
                debtFactor: -20,
                monumentPairCount: 0,
                fengShuiFactor: 0,
                repressionFactor: 0
            )
        )
        XCTAssertLessThan(lower.popularityDelta, 0)
        XCTAssertEqual(lower.popularity, 0)
    }

    func testMonumentMatchingWalkPreservesSourceGatesAndPairCount() {
        let outcome = DeterministicMigration.originalMonumentMatchingWalk(
            buildings: [
                .init(
                    vectorIndex: 0,
                    modelID: 77,
                    completionPercent: 100
                ),
                .init(
                    vectorIndex: 1,
                    modelID: 77,
                    completionPercent: 100
                ),
                .init(
                    vectorIndex: 2,
                    modelID: 253,
                    completionPercent: 100
                ),
                .init(
                    vectorIndex: 3,
                    modelID: 77,
                    subIndex: 1,
                    completionPercent: 100
                ),
                .init(
                    vectorIndex: 4,
                    isActive: false,
                    modelID: 77,
                    completionPercent: 100
                ),
                .init(
                    vectorIndex: 5,
                    modelID: 77,
                    completionPercent: 99
                ),
            ],
            goals: [
                .init(vectorIndex: 0, type: 2, buildingID: 77),
                .init(vectorIndex: 1, type: 2, buildingID: 0x55),
                .init(vectorIndex: 2, type: 1, buildingID: 77),
            ]
        )

        // The index-1 root model 77 counts once against goal 77; model 253
        // matches special goal 0x55 once. Index 0, non-root, inactive, and
        // incomplete rows do not enter the inner goal walk.
        XCTAssertEqual(outcome.matchingPairCount, 2)
        XCTAssertEqual(outcome.goals.map(\.vectorIndex), [0, 1, 2])
        XCTAssertEqual(outcome.goals.map(\.completed), [false, true, false])
        XCTAssertEqual(outcome.goals.map(\.wroteCompletionFlag), [true, true, false])

        XCTAssertTrue(DeterministicMigration.originalMonumentModelID(76))
        XCTAssertTrue(DeterministicMigration.originalMonumentModelID(253))
        XCTAssertFalse(DeterministicMigration.originalMonumentModelID(75))
        XCTAssertFalse(DeterministicMigration.originalMonumentModelID(87))
    }

    func testProducerSpawnsImmigrantsAndPopulationGrowsOnHaunxian() throws {
        let mapURL = GameDataSource.defaultRoot
            .appendingPathComponent("Cities/Haunxian.map")
        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            throw XCTSkip("Original Emperor map data is not installed")
        }
        let map = try EmperorMap(url: mapURL)
        guard let entry = map.authoredPoints.landEntry else {
            throw XCTSkip("Haunxian map has no authored land entry")
        }
        let original = try installedModels()
        let models = original.buildings
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(year: -246, treasury: 15_000, map: map)

        // Road from the entry and a couple of vacant houses beside it.
        var cursor = entry
        var guardSteps = 0
        while guardSteps < 80 {
            guardSteps += 1
            let candidates = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            guard let next = candidates.first(where: {
                city.terrain?.isClearLand($0) == true
                    && !city.roadNetwork.contains($0)
                    && !city.occupiedBuildingPoints.contains($0)
            }) else { break }
            _ = city.buildRoad([next], rules: rules)
            cursor = next
            if city.roadNetwork.points.count >= 6 { break }
        }
        for offset in 0..<3 {
            let candidates = RoadServiceCoverage.orthogonalNeighbors(of: cursor)
                .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            let point = candidates.first { candidate in
                candidate.y == cursor.y + 1 + offset
                    && city.terrain?.isClearLand(candidate) == true
                    && !city.occupiedBuildingPoints.contains(candidate)
            }
            if let point {
                _ = city.addHouse(
                    levelID: 0,
                    location: point,
                    vacantTypeID: 2,
                    models: models
                )
            }
        }
        XCTAssertGreaterThanOrEqual(city.houses.count, 1, "could not place houses")

        city.setAutomaticMigrationAvailability(.supportedOriginalProducer)
        city.setMigrationPopularity(60)

        var ticks = 0
        var sawWalker = false
        while city.population == 0, ticks < 30 * 12 {
            _ = city.advanceTick(rules: rules)
            ticks += 1
            if !city.migration.immigrantWalkers.isEmpty {
                sawWalker = true
            }
        }

        XCTAssertTrue(sawWalker, "producer must spawn immigrant figures")
        XCTAssertGreaterThan(city.population, 0, "immigrants must arrive within 12 months")
        XCTAssertGreaterThan(city.migration.assignedThisMonth, 0)
    }

    func testProducerUsesRemainingCapacityForOccupiedHousePass() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let original = try OriginalEconomyModels(source: .openDefault())
        let rules = EconomyRulesEngine(models: original)
        let width = 8
        let height = 5
        let terrain = try DeterministicTerrainState(
            width: width,
            height: height,
            terrainRawValues: [UInt32](repeating: 0, count: width * height),
            authoredPoints: EmperorMapAuthoredPoints(
                landEntry: GridPoint(x: 0, y: 2)
            )
        )
        var city = DeterministicCityState(year: 2038, treasury: 10_000, terrain: terrain)
        _ = city.buildRoad((0...3).map { GridPoint(x: $0, y: 2) }, rules: rules)

        let totalCapacity = try XCTUnwrap(
            original.buildings[houseLevelID: 0]?.populationCapacity
        )
        let houseID = try XCTUnwrap(city.addHouse(
            levelID: 0,
            residents: totalCapacity - 1,
            location: GridPoint(x: 2, y: 1),
            models: original.buildings
        ))

        city.setAutomaticMigrationAvailability(.supportedOriginalProducer)
        city.setMigrationPopularity(60)
        _ = city.advanceTick(rules: rules)

        let walkers = city.migration.immigrantWalkers.filter { $0.houseID == houseID }
        XCTAssertEqual(walkers.reduce(0) { $0 + $1.peopleCount }, 1)
        XCTAssertTrue(walkers.allSatisfy { $0.peopleCount <= 1 })
        XCTAssertEqual(city.migration.assignedToday, 1)
    }

    func testDailyMigrationAssignmentUsesRecoveredPressurePassOrdering() throws {
        let original = try installedModels()
        let rules = EconomyRulesEngine(models: original)
        var city = DeterministicCityState(
            year: 2038,
            treasury: 10_000,
            mapWidth: 4,
            mapHeight: 4
        )
        city.setAutomaticMigrationAvailability(.supportedOriginalProducer)
        city.setMigrationPopularity(75)

        city.dailyMigrationAssignment(rules: rules)

        // With no authored terrain the assignment cannot spawn a figure, but
        // the recovered pressure/request pass still determines the pressure,
        // cross-cooldown, and unfulfilled-request accounting.
        XCTAssertEqual(city.migration.pressure, 100)
        XCTAssertEqual(city.migration.arrivalCooldown, 0)
        XCTAssertEqual(city.migration.departureCooldown, 2)
        XCTAssertEqual(city.migration.arrivalRequest, 0)
        XCTAssertEqual(city.migration.unfulfilledArrivalCarry, 12)
    }
}
