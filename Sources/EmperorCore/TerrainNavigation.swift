import Foundation

public struct TerrainFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // Original Emperor terrain bit field. These positions are cross-checked
    // against Citybuilding Mappers' Emperor parser and the local map files.
    public static let tree = Self(rawValue: 1 << 0)
    public static let rock = Self(rawValue: 1 << 1)
    public static let water = Self(rawValue: 1 << 2)
    public static let building = Self(rawValue: 1 << 3)
    public static let scrub = Self(rawValue: 1 << 4)
    public static let garden = Self(rawValue: 1 << 5)
    public static let road = Self(rawValue: 1 << 6)
    public static let fertile = Self(rawValue: 1 << 7)
    /// Compatibility spelling used by existing native saves while the
    /// separate water-saturation byte grid is decoded.
    public static let groundwater = fertile
    @available(*, deprecated, renamed: "fertile")
    public static let meadow = fertile
    public static let flood = Self(rawValue: 1 << 8)
    public static let elevation = Self(rawValue: 1 << 9)
    public static let irrigation = Self(rawValue: 1 << 11)
    public static let wall = Self(rawValue: 1 << 14)
    public static let beach = Self(rawValue: 1 << 16)
    public static let quarry = Self(rawValue: 1 << 17)
    public static let saltMarsh = Self(rawValue: 1 << 18)
    public static let offMap = Self(rawValue: 1 << 19)
    public static let copperOre = Self(rawValue: 1 << 20)
    public static let ironOre = Self(rawValue: 1 << 21)
    public static let pinnacle = Self(rawValue: 1 << 25)
    public static let deepWater = Self(rawValue: 1 << 26)
    public static let monument = Self(rawValue: 1 << 28)
    public static let sand = Self(rawValue: 1 << 31)

    public static let verifiedMask: Self = [
        .tree, .rock, .water, .building, .scrub, .garden, .road,
        .fertile, .flood, .elevation, .irrigation, .wall, .beach,
        .quarry, .saltMarsh, .offMap, .copperOre, .ironOre,
        .pinnacle, .deepWater, .monument, .sand
    ]

    public var unclassifiedRawValue: UInt32 {
        rawValue & ~Self.verifiedMask.rawValue
    }
}

public struct GridPoint: Sendable, Hashable, Codable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public enum GridPathfinder {
    public static func shortestPath(
        width: Int,
        height: Int,
        from start: GridPoint,
        to destination: GridPoint,
        isPassable: (GridPoint) -> Bool
    ) -> [GridPoint]? {
        guard width > 0, height > 0,
              contains(start, width: width, height: height),
              contains(destination, width: width, height: height),
              isPassable(start), isPassable(destination) else { return nil }

        let startIndex = start.y * width + start.x
        let destinationIndex = destination.y * width + destination.x
        var previous = [Int](repeating: -2, count: width * height)
        previous[startIndex] = -1
        var queue = [Int](repeating: 0, count: width * height)
        queue[0] = startIndex
        var head = 0
        var tail = 1
        let directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]

        while head < tail {
            let currentIndex = queue[head]
            head += 1
            if currentIndex == destinationIndex { break }
            let current = GridPoint(x: currentIndex % width, y: currentIndex / width)
            for direction in directions {
                let next = GridPoint(x: current.x + direction.0, y: current.y + direction.1)
                guard contains(next, width: width, height: height) else { continue }
                let nextIndex = next.y * width + next.x
                guard previous[nextIndex] == -2, isPassable(next) else { continue }
                previous[nextIndex] = currentIndex
                queue[tail] = nextIndex
                tail += 1
            }
        }

        guard previous[destinationIndex] != -2 else { return nil }
        var reversed: [GridPoint] = []
        var index = destinationIndex
        while index >= 0 {
            reversed.append(GridPoint(x: index % width, y: index / width))
            index = previous[index]
        }
        return reversed.reversed()
    }

    private static func contains(_ point: GridPoint, width: Int, height: Int) -> Bool {
        point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
    }
}

public extension EmperorMap {
    func terrain(at point: GridPoint) -> TerrainFlags? {
        terrainFlags(x: point.x, y: point.y).map(TerrainFlags.init(rawValue:))
    }

    func shortestRoadPath(from start: GridPoint, to destination: GridPoint) -> [GridPoint]? {
        GridPathfinder.shortestPath(width: width, height: height, from: start, to: destination) { point in
            terrain(at: point)?.contains(.road) == true
        }
    }
}
