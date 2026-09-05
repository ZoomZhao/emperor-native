import Foundation

/// Placement-time terrain category returned by `FUN_0042B090 @ 0x42B090`.
///
/// The executable scans the 8×8 window `[center-4, center+3]` in both axes.
/// This is a raw map-word classifier used by `FUN_0042B250`; it is not the
/// later city-wide feng-shui percentage and does not identify a building's
/// semantic element.
public enum OriginalFengShuiTerrainClassification {
    /// Classifies the authored (static) terrain layer of a mission-sized
    /// Native map using its recovered PE descriptor. This overload deliberately
    /// does not include later object-grid writes; callers that need the full
    /// executable state must supply an independently recovered projection via
    /// `mapWords` below.
    public static func classify(
        center: GridPoint,
        terrain: DeterministicTerrainState
    ) -> Int? {
        guard let descriptor = OriginalMapRuntimeDescriptorCatalog.descriptor(
            width: terrain.width,
            height: terrain.height
        ), let words = terrain.originalAuthoredTerrainWords() else {
            return nil
        }
        return classify(
            center: center,
            mapWords: words,
            baseLinearOffset: descriptor.baseLinearOffset,
            rowStride: descriptor.effectiveRowStride
        )
    }

    /// Replays the executable's category result for an already projected raw
    /// map-word layer. `baseLinearOffset` and `rowStride` are explicit because
    /// Native's compact mission rectangle is not proven to share the PE's
    /// 228-cell backing-grid origin. Missing cells fail closed rather than
    /// treating absent object-grid data as clear terrain.
    public static func classify(
        center: GridPoint,
        mapWords: [Int: UInt32],
        baseLinearOffset: Int,
        rowStride: Int = OriginalMapObjectGridProjection.mapRowStride
    ) -> Int? {
        guard rowStride > 0 else { return nil }

        var nearestCategoryOne = Int.max
        var nearestCategoryTwo = Int.max
        // The source's `local_c` slot is the distance for result category 4;
        // result category 3 is reserved for the no-neighbour fallback below.
        var nearestCategoryFour = Int.max
        var sawCell = false

        for yOffset in -4...3 {
            for xOffset in -4...3 {
                let linearIndex = baseLinearOffset
                    + (center.y + yOffset) * rowStride
                    + center.x + xOffset
                guard let word = mapWords[linearIndex] else { return nil }
                sawCell = true
                // `FUN_0042B090` ignores cells with the 0x80000 occupancy bit.
                guard word & 0x80000 == 0 else { continue }
                let distance = xOffset * xOffset + yOffset * yOffset

                if word & 1 == 0 {
                    let maskedKind = word & 0x300002
                    if maskedKind == 0x100002 || maskedKind == 0x200002 {
                        nearestCategoryTwo = min(nearestCategoryTwo, distance)
                    } else if (word & 0xC20000 != 0) || maskedKind == 2 {
                        nearestCategoryOne = min(nearestCategoryOne, distance)
                    }
                } else {
                    nearestCategoryFour = min(nearestCategoryFour, distance)
                }
            }
        }

        guard sawCell else { return nil }
        let noNearbyCategory = nearestCategoryOne == Int.max
            && nearestCategoryTwo == Int.max
            && nearestCategoryFour == Int.max
        if noNearbyCategory {
            let centerIndex = baseLinearOffset + center.y * rowStride + center.x
            guard let centerWord = mapWords[centerIndex] else { return nil }
            // Exact fallback from the source: 5 for a plain center cell, 3
            // when either 0x84 or 0x4000000 is present.
            return centerWord & 0x84 == 0 && centerWord & 0x4000000 == 0 ? 5 : 3
        }

        if nearestCategoryOne <= nearestCategoryTwo,
           nearestCategoryOne <= nearestCategoryFour {
            return 1
        }
        // The decompiled expression is `(local_c < local_1c[2] ? 4 : 2)`.
        return nearestCategoryFour < nearestCategoryTwo ? 4 : 2
    }

    /// Samples the geometry offsets used by the non-custom branch of
    /// `FUN_0042B250` and feeds the resulting category counters into the
    /// recovered arithmetic helper. This remains a pure diagnostic bridge:
    /// it does not write object `+0xA0`, mutate terrain, or register a map
    /// object. Models whose geometry group is not present in the executable
    /// table fail closed because they may use `FUN_0042C930` custom sampling.
    public static func samplePlacement(
        buildingID: Int,
        modelValue: Int,
        origin: GridPoint,
        mapRotation: Int,
        mapWords: [Int: UInt32],
        baseLinearOffset: Int,
        rowStride: Int = OriginalMapObjectGridProjection.mapRowStride,
        customOrientationBank: Int? = nil
    ) -> DeterministicMigration.OriginalFengShuiPlacementOutcome? {
        guard rowStride > 0, (1...5).contains(modelValue) else {
            return DeterministicMigration.originalFengShuiPlacementResult(
                modelValue: modelValue
            )
        }
        let offsets: [Int]
        if let customOrientationBank {
            guard let geometry = OriginalBuildingGeometryCatalog.customGeometry(
                forBuildingID: buildingID
            ), let points = geometry.transformedPoints(
                forOrientationBank: customOrientationBank,
                mapRotation: mapRotation
            ) else { return nil }
            offsets = points.map { $0.y * rowStride + $0.x }
        } else {
            guard let ordinaryOffsets = OriginalBuildingGeometryCatalog.relativeLinearOffsets(
                forBuildingID: buildingID,
                mapRotation: mapRotation
            ) else { return nil }
            // Custom samplers require an explicit bank.  Do not silently
            // substitute ordinary geometry for an unresolved callback.
            guard OriginalBuildingGeometryCatalog.customGeometry(
                forBuildingID: buildingID
            ) == nil else { return nil }
            offsets = ordinaryOffsets
        }

        func floorQuotient(_ value: Int, _ divisor: Int) -> Int {
            let quotient = value / divisor
            let remainder = value % divisor
            return remainder < 0 ? quotient - 1 : quotient
        }

        var counts = [Int](repeating: 0, count: 5)
        for relativeOffset in offsets {
            let linearIndex = baseLinearOffset
                + origin.y * rowStride
                + origin.x
                + relativeOffset
            let y = floorQuotient(linearIndex - baseLinearOffset, rowStride)
            let x = linearIndex - baseLinearOffset - y * rowStride
            guard let category = classify(
                center: GridPoint(x: x, y: y),
                mapWords: mapWords,
                baseLinearOffset: baseLinearOffset,
                rowStride: rowStride
            ), (1...5).contains(category) else { return nil }
            counts[category - 1] += 1
        }

        return DeterministicMigration.originalFengShuiPlacementResult(
            modelValue: modelValue,
            counts: .init(
                slot1: counts[0],
                slot2: counts[1],
                slot3: counts[2],
                slot4: counts[3],
                slot5: counts[4]
            )
        )
    }
}
