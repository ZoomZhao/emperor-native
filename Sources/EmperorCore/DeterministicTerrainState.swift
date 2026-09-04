import Foundation

public enum QuayWaterEdge: String, CaseIterable, Sendable, Hashable, Codable {
    case north
    case east
    case south
    case west
}

/// The active, mission-sized portion of an original Emperor map.
///
/// Original files keep every layer in a centered 228×228 backing grid. Native
/// simulation uses coordinates relative to the playable rectangle so a 112×112
/// or 140×140 mission does not pay the cost of traversing the unused border.
public struct DeterministicTerrainState: Sendable, Equatable, Codable {
    public let width: Int
    public let height: Int
    public private(set) var terrainRawValues: [UInt32]
    /// Exact mission-sized projection of serialized `DAT_00F37DA0` map words.
    /// Bit 0x04 is consumed by the original negative-appeal arbitration, but
    /// dynamic writers are not yet reproduced; retaining the authored layer
    /// must not be mistaken for enabling that live contract.
    public let appealFlagsRawValues: [UInt32]?
    /// Exact mission-sized projections of the two serialized auxiliary layers
    /// consumed by the recovered worker routing builders. Optional fields keep
    /// saves written before this source-layer recovery decodable.
    public let primaryElevationClassRawValues: [UInt8]?
    public let roadWaterAuxiliaryValues: [UInt8]?
    /// Mission-sized projection of serialized `DAT_00FDCD70`. The original
    /// Way-object callback (`FUN_00420EB0`) reads this byte when a Way cell
    /// lacks road bit `0x40`; optional keeps older Native saves decodable.
    public let roadDirectionRawValues: [UInt8]?
    /// Optional keeps native saves from releases before authored map points
    /// were decoded backwards compatible.
    public let authoredPoints: EmperorMapAuthoredPoints?
    /// Predetermined Great Wall root recovered by matching the map's authored
    /// wall-image footprint to the original multipart layout files. Optional
    /// preserves native saves written before this map contract was decoded.
    public let greatWallPlacement: OriginalGreatWallLayoutCatalog.MapPlacement?
    /// Predetermined Grand Canal reserve recovered from the authored map
    /// image footprint. Optional preserves earlier Native saves.
    public let grandCanalPlacement: OriginalGrandCanalLayoutCatalog.MapPlacement?

    public init(map: EmperorMap) {
        width = map.width
        height = map.height
        terrainRawValues = (0..<map.height).flatMap { y in
            (0..<map.width).map { x in map.terrainFlags(x: x, y: y) ?? 0 }
        }
        appealFlagsRawValues = (0..<map.height).flatMap { y in
            (0..<map.width).map { x in map.appealFlagsValue(x: x, y: y) ?? 0 }
        }
        primaryElevationClassRawValues = (0..<map.height).flatMap { y in
            (0..<map.width).map { x in
                UInt8(bitPattern: map.primaryElevationClassValue(x: x, y: y) ?? -1)
            }
        }
        roadWaterAuxiliaryValues = map.roadWaterAuxiliaryValues.map { _ in
            (0..<map.height).flatMap { y in
                (0..<map.width).map { x in map.roadWaterAuxiliaryValue(x: x, y: y) ?? 0 }
            }
        }
        roadDirectionRawValues = (0..<map.height).flatMap { y in
            (0..<map.width).map { x in map.edgeValue(x: x, y: y) ?? 0 }
        }
        authoredPoints = map.authoredPoints
        greatWallPlacement = OriginalGreatWallLayoutCatalog.campaignPlacement(in: map)
        grandCanalPlacement = OriginalGrandCanalLayoutCatalog.campaignPlacement(in: map)
    }

    public init(
        width: Int,
        height: Int,
        terrainRawValues: [UInt32],
        appealFlagsRawValues: [UInt32]? = nil,
        primaryElevationClassRawValues: [UInt8]? = nil,
        roadWaterAuxiliaryValues: [UInt8]? = nil,
        roadDirectionRawValues: [UInt8]? = nil,
        authoredPoints: EmperorMapAuthoredPoints? = nil,
        greatWallPlacement: OriginalGreatWallLayoutCatalog.MapPlacement? = nil,
        grandCanalPlacement: OriginalGrandCanalLayoutCatalog.MapPlacement? = nil
    ) throws {
        guard width > 0, height > 0, terrainRawValues.count == width * height,
              appealFlagsRawValues.map({ $0.count == width * height }) ?? true,
              primaryElevationClassRawValues.map({ $0.count == width * height }) ?? true,
              roadWaterAuxiliaryValues.map({ $0.count == width * height }) ?? true,
              roadDirectionRawValues.map({ $0.count == width * height }) ?? true else {
            throw GameDataError.malformedFile("native terrain dimensions")
        }
        self.width = width
        self.height = height
        self.terrainRawValues = terrainRawValues
        self.appealFlagsRawValues = appealFlagsRawValues
        self.primaryElevationClassRawValues = primaryElevationClassRawValues
        self.roadWaterAuxiliaryValues = roadWaterAuxiliaryValues
        self.roadDirectionRawValues = roadDirectionRawValues
        self.authoredPoints = authoredPoints
        self.greatWallPlacement = greatWallPlacement
        self.grandCanalPlacement = grandCanalPlacement
    }

    public func contains(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
    }

    public func terrain(at point: GridPoint) -> TerrainFlags? {
        guard contains(point) else { return nil }
        return TerrainFlags(rawValue: terrainRawValues[point.y * width + point.x])
    }

    public func appealFlags(at point: GridPoint) -> UInt32? {
        guard contains(point), let appealFlagsRawValues else { return nil }
        return appealFlagsRawValues[point.y * width + point.x]
    }

    public func primaryElevationClass(at point: GridPoint) -> Int8? {
        guard contains(point), let primaryElevationClassRawValues else { return nil }
        return Int8(bitPattern: primaryElevationClassRawValues[point.y * width + point.x])
    }

    public func roadWaterAuxiliary(at point: GridPoint) -> UInt8? {
        guard contains(point), let roadWaterAuxiliaryValues else { return nil }
        return roadWaterAuxiliaryValues[point.y * width + point.x]
    }

    public func roadDirection(at point: GridPoint) -> UInt8? {
        guard contains(point), let roadDirectionRawValues else { return nil }
        return roadDirectionRawValues[point.y * width + point.x]
    }

    /// Returns the authored terrain layer in the original executable's
    /// linear backing-grid coordinates. The map loader stores the active
    /// rectangle at the descriptor's centered `baseLinearOffset` with the
    /// canonical 228-cell row stride; this projection preserves that address
    /// arithmetic without adding any dynamic object or registry overlays.
    ///
    /// `nil` is returned for dimensions outside the recovered descriptor
    /// table. Dynamic writes from `FUN_004B72B0` are intentionally absent and
    /// must not be inferred from Native occupancy.
    public func originalAuthoredTerrainWords() -> [Int: UInt32]? {
        guard let descriptor = OriginalMapRuntimeDescriptorCatalog.descriptor(
            width: width,
            height: height
        ) else { return nil }
        var words: [Int: UInt32] = [:]
        words.reserveCapacity(terrainRawValues.count)
        for y in 0..<height {
            for x in 0..<width {
                let localIndex = y * width + x
                let backingIndex = descriptor.baseLinearOffset
                    + y * descriptor.effectiveRowStride + x
                words[backingIndex] = terrainRawValues[localIndex]
            }
        }
        return words
    }

    /// Original roadblock terrain guard (recovered from `0x46D110`, roadblock
    /// branches, and documented in
    /// `docs/exe-research/roadblock-path-blocking.md` §2.1). The block may sit
    /// only on a plain road tile: no `0x400` special-crossing surface, no
    /// occupied-surface marker (`0x8`), and a zero road-water auxiliary byte.
    public func canPlaceRoadBlock(at point: GridPoint) -> Bool {
        guard let flags = terrain(at: point) else { return false }
        return flags.contains(.road)
            && flags.rawValue & Self.roadBlockSpecialCrossingSurfaceMask == 0
            && !flags.contains(.building)
            && (roadWaterAuxiliary(at: point) ?? 0) == 0
    }

    public var roadPoints: Set<GridPoint> {
        var result: Set<GridPoint> = []
        for y in 0..<height {
            for x in 0..<width {
                let point = GridPoint(x: x, y: y)
                if terrain(at: point)?.contains(.road) == true { result.insert(point) }
            }
        }
        return result
    }

    public var waterTileCount: Int {
        terrainRawValues.count { raw in
            TerrainFlags(rawValue: raw).contains(.water)
        }
    }

    public var clearLandTileCount: Int {
        terrainRawValues.count { raw in
            !Self.blocksConstruction(TerrainFlags(rawValue: raw))
        }
    }

    public func isClearLand(_ point: GridPoint) -> Bool {
        guard let terrain = terrain(at: point) else { return false }
        return !Self.blocksConstruction(terrain)
    }

    public func canClearVegetation(at point: GridPoint) -> Bool {
        guard let terrain = terrain(at: point) else { return false }
        return !terrain.intersection([.tree, .scrub]).isEmpty
    }

    /// Removes vegetation while preserving fertility, ore and all authored
    /// height/water metadata underneath it.
    @discardableResult
    public mutating func clearVegetation(at point: GridPoint) -> Bool {
        guard canClearVegetation(at: point) else { return false }
        let index = point.y * width + point.x
        terrainRawValues[index] &= ~TerrainFlags([.tree, .scrub]).rawValue
        return true
    }


    public func isWater(_ point: GridPoint) -> Bool {
        guard let terrain = terrain(at: point) else { return false }
        return terrain.contains(.water) || terrain.contains(.deepWater)
    }

    /// External caravans may cross ordinary undeveloped land and roads. The
    /// original editor can place a land entry in its unrendered diamond-edge
    /// band (`0x04080005`), so that exact authored border value is traversable
    /// for entry/exit purposes even though it carries water-like flag bits.
    public func isLandVisitorPassable(_ point: GridPoint) -> Bool {
        guard contains(point), let terrain = terrain(at: point) else { return false }
        if terrain.rawValue == 0x0408_0005 { return true }
        if terrain.contains(.road) { return true }
        return terrain.intersection([.tree, .rock, .water, .elevation, .deepWater]).isEmpty
    }

    public func shortestLandVisitorPath(
        from start: GridPoint,
        to destination: GridPoint,
        blocked: Set<GridPoint> = []
    ) -> [GridPoint]? {
        let ordinary = GridPathfinder.shortestPath(
            width: width,
            height: height,
            from: start,
            to: destination
        ) { point in
            (point == start || point == destination || !blocked.contains(point))
                && self.isLandVisitorPassable(point)
        }
        if let ordinary { return ordinary }

        // Campaign Creator entry banners may sit in the unrendered part of the
        // diamond edge, separated from playable land by a few authored border
        // cells. Join that banner to the closest tile in the destination's
        // traversable component, preserving every intermediate map coordinate.
        let component = reachableLandComponent(from: destination, blocked: blocked)
        guard let connectorEnd = component.min(by: { lhs, rhs in
            let lhsDistance = abs(lhs.x - start.x) + abs(lhs.y - start.y)
            let rhsDistance = abs(rhs.x - start.x) + abs(rhs.y - start.y)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            return lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
        }),
        let connector = GridPathfinder.shortestPath(
            width: width,
            height: height,
            from: start,
            to: connectorEnd,
            isPassable: { _ in true }
        ),
        let interior = GridPathfinder.shortestPath(
            width: width,
            height: height,
            from: connectorEnd,
            to: destination,
            isPassable: { point in
            (point == destination || !blocked.contains(point))
                && self.isLandVisitorPassable(point)
            }
        ) else { return nil }
        return connector + interior.dropFirst()
    }

    public func shortestWaterPath(from start: GridPoint, to destination: GridPoint) -> [GridPoint]? {
        GridPathfinder.shortestPath(
            width: width,
            height: height,
            from: start,
            to: destination,
            isPassable: isWater
        )
    }

    public func isShoreline(_ point: GridPoint) -> Bool {
        guard isClearLand(point) else { return false }
        return orthogonalNeighbors(of: point).contains { isWater($0) }
    }

    public var shorelinePoints: Set<GridPoint> {
        var result: Set<GridPoint> = []
        for y in 0..<height {
            for x in 0..<width {
                let point = GridPoint(x: x, y: y)
                if isShoreline(point) { result.insert(point) }
            }
        }
        return result
    }

    /// Returns the first full water-facing edge in deterministic clockwise
    /// order. Requiring a complete straight edge matches the original quay
    /// placement rule and also selects its directional sprite set.
    public func quayWaterEdge(
        footprintPoints: [GridPoint],
        footprintWidth: Int,
        footprintHeight: Int,
        origin: GridPoint
    ) -> QuayWaterEdge? {
        guard footprintPoints.allSatisfy(isClearLand) else { return nil }
        let candidates = QuayWaterEdge.allCases.map { edge in
            (edge, quayWaterPoints(
                edge: edge,
                footprintWidth: footprintWidth,
                footprintHeight: footprintHeight,
                origin: origin
            ))
        }
        return candidates.first { _, edge in edge.allSatisfy(isWater) }?.0
    }

    public func quayWaterPoints(
        edge: QuayWaterEdge,
        footprintWidth: Int,
        footprintHeight: Int,
        origin: GridPoint
    ) -> [GridPoint] {
        switch edge {
        case .north:
            (0..<footprintWidth).map { GridPoint(x: origin.x + $0, y: origin.y - 1) }
        case .east:
            (0..<footprintHeight).map { GridPoint(x: origin.x + footprintWidth, y: origin.y + $0) }
        case .south:
            (0..<footprintWidth).map { GridPoint(x: origin.x + $0, y: origin.y + footprintHeight) }
        case .west:
            (0..<footprintHeight).map { GridPoint(x: origin.x - 1, y: origin.y + $0) }
        }
    }

    /// Returns true when every tile in the footprint is clear land and at
    /// least one full edge of the footprint borders water.
    public func isValidQuaySite(
        footprintPoints: [GridPoint],
        footprintWidth: Int,
        footprintHeight: Int,
        origin: GridPoint
    ) -> Bool {
        quayWaterEdge(
            footprintPoints: footprintPoints,
            footprintWidth: footprintWidth,
            footprintHeight: footprintHeight,
            origin: origin
        ) != nil
    }

    private func orthogonalNeighbors(of point: GridPoint) -> [GridPoint] {
        [
            GridPoint(x: point.x, y: point.y - 1),
            GridPoint(x: point.x + 1, y: point.y),
            GridPoint(x: point.x, y: point.y + 1),
            GridPoint(x: point.x - 1, y: point.y)
        ]
    }

    private func reachableLandComponent(
        from start: GridPoint,
        blocked: Set<GridPoint>
    ) -> Set<GridPoint> {
        guard contains(start), isLandVisitorPassable(start) else { return [] }
        var visited: Set<GridPoint> = [start]
        var queue = [start]
        var index = 0
        while index < queue.count {
            let current = queue[index]
            index += 1
            for next in orthogonalNeighbors(of: current) where
                contains(next)
                    && !visited.contains(next)
                    && (next == start || !blocked.contains(next))
                    && isLandVisitorPassable(next) {
                visited.insert(next)
                queue.append(next)
            }
        }
        return visited
    }

    /// `1 << 10` was not added to `TerrainFlags`' verified set because the
    /// native water/road parsing never asserts on it; it exists only as the
    /// original special-crossing surface that blocks roadblock placement.
    private static let roadBlockSpecialCrossingSurfaceMask: UInt32 = 1 << 10

    private static let constructionObstacles: TerrainFlags = [
        .tree, .rock, .water, .building, .scrub, .garden,
        .road, .irrigation, .wall, .beach, .quarry, .saltMarsh,
        .offMap, .pinnacle, .deepWater, .monument
    ]

    private static func blocksConstruction(_ terrain: TerrainFlags) -> Bool {
        if !terrain.intersection(constructionObstacles).isEmpty { return true }
        // Bit 9 alone is flat raised land and remains buildable. The original
        // maps add one of these high bits to cliff/slope faces, which must not
        // accept a footprint.
        let cliffOrSlopeMask: UInt32 = 0x20C0_0000
        return terrain.contains(.elevation)
            && terrain.rawValue & cliffOrSlopeMask != 0
    }
}
