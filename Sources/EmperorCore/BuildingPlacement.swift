import Foundation

/// Tile dimensions used by the original Emperor executable. These values are
/// deliberately separate from the economy model file: the shipped model table
/// contains costs and risks, while footprint dimensions are executable rules.
public struct BuildingFootprint: Sendable, Hashable, Codable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    public func oriented(_ orientation: IsometricBuildingOrientation) -> BuildingFootprint {
        switch orientation {
        case .northSouth: self
        case .eastWest: BuildingFootprint(width: height, height: width)
        }
    }

    public func points(at origin: GridPoint) -> [GridPoint] {
        (0..<height).flatMap { row in
            (0..<width).map { column in
                GridPoint(x: origin.x + column, y: origin.y + row)
            }
        }
    }
}

/// Deterministic construction-drag geometry shared by the player canvas and
/// interaction tests. Paths preserve the tiles actually crossed by the
/// pointer, while grid placement advances by the authored footprint size.
public enum ConstructionDragPlanner {
    public static func orthogonalSegment(
        from start: GridPoint,
        to end: GridPoint
    ) -> [GridPoint] {
        let horizontal = inclusiveValues(from: start.x, to: end.x).map {
            GridPoint(x: $0, y: start.y)
        }
        let vertical = inclusiveValues(from: start.y, to: end.y).dropFirst().map {
            GridPoint(x: end.x, y: $0)
        }
        return horizontal + vertical
    }

    public static func appendingOrthogonalSegment(
        to existing: [GridPoint],
        endingAt end: GridPoint
    ) -> [GridPoint] {
        guard let start = existing.last else { return [end] }
        var result = existing
        var visited = Set(existing)
        for point in orthogonalSegment(from: start, to: end).dropFirst()
            where visited.insert(point).inserted {
            result.append(point)
        }
        return result
    }

    public static func rectangularPoints(
        from start: GridPoint,
        to end: GridPoint
    ) -> [GridPoint] {
        let minimumX = min(start.x, end.x)
        let maximumX = max(start.x, end.x)
        let minimumY = min(start.y, end.y)
        let maximumY = max(start.y, end.y)
        return (minimumY...maximumY).flatMap { y in
            (minimumX...maximumX).map { GridPoint(x: $0, y: y) }
        }
    }

    public static func tiledOrigins(
        from start: GridPoint,
        to end: GridPoint,
        footprint: BuildingFootprint
    ) -> [GridPoint] {
        inclusiveValues(from: start.y, to: end.y, step: footprint.height).flatMap { y in
            inclusiveValues(from: start.x, to: end.x, step: footprint.width).map { x in
                GridPoint(x: x, y: y)
            }
        }
    }

    private static func inclusiveValues(
        from start: Int,
        to end: Int,
        step: Int = 1
    ) -> [Int] {
        let signedStep = start <= end ? max(1, step) : -max(1, step)
        var result: [Int] = []
        var value = start
        while signedStep > 0 ? value <= end : value >= end {
            result.append(value)
            value += signedStep
        }
        return result
    }
}

/// Original non-monument footprints used by the native construction layer.
/// Rectangular buildings can be rotated by swapping these authored dimensions.
public enum OriginalBuildingFootprintCatalog {
    public static func footprint(forBuildingID buildingID: Int) -> BuildingFootprint? {
        switch buildingID {
        // Every residential plot in the original game occupies a 2×2 block.
        // Building #2 is the vacant/common-housing construction tool; later
        // house levels keep the same plot while their sprite evolves.
        case 2...17:
            BuildingFootprint(width: 2, height: 2)

        // Individually placed crop plots and orchards. The producer buildings
        // use their own larger footprints, but every tended plot occupies one
        // original map tile.
        case 26...28, 194...199, 203:
            BuildingFootprint(width: 1, height: 1)

        // Extraction and light industry.
        case 31, 33, 35, 36, 38, 42...47, 192, 193, 226, 237...239:
            BuildingFootprint(width: 2, height: 2)
        case 37, 39...41:
            BuildingFootprint(width: 3, height: 3)

        // Storage, food distribution, markets, and land trade.
        case 53:
            BuildingFootprint(width: 5, height: 5)
        case 54, 56, 58:
            BuildingFootprint(width: 3, height: 3)
        case 59:
            BuildingFootprint(width: 7, height: 4)
        case 60:
            BuildingFootprint(width: 7, height: 6)

        // Housing services and government.
        case 72, 124, 125, 127, 207, 208, 211, 214, 215, 217:
            BuildingFootprint(width: 2, height: 2)
        case 126:
            BuildingFootprint(width: 1, height: 1)
        case 212, 213, 219:
            BuildingFootprint(width: 3, height: 3)
        case 216, 218:
            BuildingFootprint(width: 4, height: 4)
        case 209:
            // Administrative City is authored as two adjacent 4x4 courts.
            BuildingFootprint(width: 4, height: 8)
        case 110:
            // Palace is authored as two adjacent 5x5 compounds.
            BuildingFootprint(width: 5, height: 10)

        // Original troop forts occupy a four-tile square.
        case 220, 221, 223...225:
            BuildingFootprint(width: 4, height: 4)

        // City walls are painted one tile at a time. The original executable
        // reserves a 5x3 rectangle for a gatehouse and a 2x2 square for a
        // staffed tower; rotation swaps the gatehouse axes.
        case 129:
            BuildingFootprint(width: 1, height: 1)
        case 130:
            BuildingFootprint(width: 5, height: 3)
        case 131:
            BuildingFootprint(width: 2, height: 2)

        // Aesthetic structures do not need roads. Small sculptures and trees
        // use one tile; the original manual specifies four tiles for ornate
        // sculptures and increasingly large recreational areas.
        case 115, 116, 118, 243...245, 249, 250:
            BuildingFootprint(width: 1, height: 1)
        case 117, 119, 246...248, 251:
            BuildingFootprint(width: 2, height: 2)
        case 120, 252:
            BuildingFootprint(width: 3, height: 3)
        case 121:
            BuildingFootprint(width: 4, height: 4)
        case 122:
            BuildingFootprint(width: 5, height: 5)

        // Monument support buildings.
        case 52, 233, 235, 236:
            BuildingFootprint(width: 2, height: 2)

        // Self-contained monuments. Great Wall and canal segments use map-
        // authored locations and are handled separately from these plots.
        case 76, 78, 93:
            BuildingFootprint(width: 8, height: 8)
        case 77, 79:
            BuildingFootprint(width: 10, height: 10)
        case 80, 82, 84:
            BuildingFootprint(width: 12, height: 12)
        case 81:
            BuildingFootprint(width: 14, height: 14)
        case 92:
            BuildingFootprint(width: 6, height: 6)
        default:
            nil
        }
    }

    public static func footprint(
        forBuildingID buildingID: Int,
        orientation: IsometricBuildingOrientation
    ) -> BuildingFootprint? {
        footprint(forBuildingID: buildingID)?.oriented(orientation)
    }
}

public enum PlacedBuildingCategory: String, Sendable, Hashable, Codable {
    case production
    case agriculturalPlot
    case warehouse
    case mill
    case market
    case trading
    case residentialService
    case military
    case aesthetic
}

/// Save-compatible geometry for a constructed simulation building. Instance
/// IDs point back into the existing production, logistics, market, trade, or
/// service state so geometry remains independent of those rule engines.
public struct PlacedBuilding: Identifiable, Sendable, Hashable, Codable {
    public let category: PlacedBuildingCategory
    public let instanceID: Int
    public let buildingID: Int
    public let origin: GridPoint
    public let orientation: IsometricBuildingOrientation
    public let footprint: BuildingFootprint
    public let roadAccessPoint: GridPoint

    public var id: String {
        category == .agriculturalPlot
            ? "\(category.rawValue)-\(instanceID)-\(origin.x)-\(origin.y)"
            : "\(category.rawValue)-\(instanceID)"
    }

    public var occupiedPoints: [GridPoint] { footprint.points(at: origin) }

    public var markerPoint: GridPoint {
        GridPoint(
            x: origin.x + (footprint.width - 1) / 2,
            y: origin.y + (footprint.height - 1) / 2
        )
    }

    public init(
        category: PlacedBuildingCategory,
        instanceID: Int,
        buildingID: Int,
        origin: GridPoint,
        orientation: IsometricBuildingOrientation,
        footprint: BuildingFootprint,
        roadAccessPoint: GridPoint
    ) {
        self.category = category
        self.instanceID = instanceID
        self.buildingID = buildingID
        self.origin = origin
        self.orientation = orientation
        self.footprint = footprint
        self.roadAccessPoint = roadAccessPoint
    }
}
