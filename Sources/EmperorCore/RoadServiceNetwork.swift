import Foundation

public struct RoadNetwork: Sendable, Equatable, Codable {
    public let width: Int
    public let height: Int
    public private(set) var points: Set<GridPoint>

    public init(width: Int, height: Int, points: Set<GridPoint> = []) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.points = points.filter { point in
            point.x >= 0 && point.x < max(1, width) && point.y >= 0 && point.y < max(1, height)
        }
    }

    public func contains(_ point: GridPoint) -> Bool {
        points.contains(point)
    }

    public func isInside(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
    }

    public func newPoints(in proposed: [GridPoint]) -> Set<GridPoint>? {
        guard proposed.allSatisfy(isInside) else { return nil }
        return Set(proposed).subtracting(points)
    }

    @discardableResult
    public mutating func insert(_ proposed: Set<GridPoint>) -> Int? {
        guard proposed.allSatisfy(isInside) else { return nil }
        let previousCount = points.count
        points.formUnion(proposed)
        return points.count - previousCount
    }

    /// Removes a single road tile, returning whether a tile was actually
    /// cleared. Used by the demolish tool to bulldoze individual road segments.
    @discardableResult
    public mutating func remove(_ point: GridPoint) -> Bool {
        points.remove(point) != nil
    }

    public func reachableDistances(
        from start: GridPoint,
        maximumSteps: Int,
        avoidingPoints: Set<GridPoint> = []
    ) -> [GridPoint: Int] {
        guard maximumSteps >= 0, points.contains(start), !avoidingPoints.contains(start) else { return [:] }
        var distances = [start: 0]
        var queue = [start]
        var head = 0
        let directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]

        while head < queue.count {
            let current = queue[head]
            head += 1
            let distance = distances[current] ?? 0
            guard distance < maximumSteps else { continue }
            for direction in directions {
                let next = GridPoint(x: current.x + direction.0, y: current.y + direction.1)
                guard points.contains(next),
                      !avoidingPoints.contains(next),
                      distances[next] == nil else { continue }
                distances[next] = distance + 1
                queue.append(next)
            }
        }
        return distances
    }
}

public enum RoadServiceCoverage {
    public static func coveredHouseIDs(
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        serviceRoadStart: GridPoint,
        maximumRoadSteps: Int,
        barrierPoints: Set<GridPoint> = []
    ) -> Set<Int> {
        let reachable = roadNetwork.reachableDistances(
            from: serviceRoadStart,
            maximumSteps: maximumRoadSteps,
            avoidingPoints: barrierPoints
        )
        guard !reachable.isEmpty else { return [] }
        return Set(houses.compactMap { house in
            guard let location = house.location else { return nil }
            return orthogonalNeighbors(of: location).contains(where: { reachable[$0] != nil }) ? house.id : nil
        })
    }

    public static func orthogonalNeighbors(of point: GridPoint) -> [GridPoint] {
        [
            GridPoint(x: point.x, y: point.y - 1),
            GridPoint(x: point.x + 1, y: point.y),
            GridPoint(x: point.x, y: point.y + 1),
            GridPoint(x: point.x - 1, y: point.y)
        ]
    }
}
