import Foundation

public enum WalkerServiceKind: String, Sendable, Equatable, Hashable, Codable {
    case inspection
    case constable
    case tax
    case water
    case herbalist
    case acupuncture
    case music
    case acrobat
    case drama
    case ancestor
    case confucian
    case daoistOrBuddhist
}

public struct RoadServiceWalker: Identifiable, Sendable, Equatable, Codable {
    public let id: Int
    public let figureID: Int
    public let service: WalkerServiceKind
    public let origin: GridPoint
    public let maximumRoadSteps: Int
    public let replaySeed: UInt64
    public private(set) var route: [GridPoint]
    public private(set) var routeIndex: Int
    public private(set) var completedTrips: Int

    public var currentPoint: GridPoint {
        guard route.indices.contains(routeIndex) else { return origin }
        return route[routeIndex]
    }

    public init(
        id: Int,
        figureID: Int,
        service: WalkerServiceKind,
        origin: GridPoint,
        maximumRoadSteps: Int,
        replaySeed: UInt64,
        roadNetwork: RoadNetwork
    ) {
        self.id = id
        self.figureID = figureID
        self.service = service
        self.origin = origin
        self.maximumRoadSteps = max(0, maximumRoadSteps)
        self.replaySeed = replaySeed
        route = DeterministicRoadPatrol.route(
            from: origin,
            maximumRoadSteps: max(0, maximumRoadSteps),
            roadNetwork: roadNetwork,
            replaySeed: replaySeed,
            trip: 0
        )
        routeIndex = 0
        completedTrips = 0
    }

    mutating func advanceOneRoadStep(on roadNetwork: RoadNetwork) -> Bool {
        guard maximumRoadSteps > 0, roadNetwork.contains(origin) else { return false }
        if route.isEmpty || !route.allSatisfy(roadNetwork.contains) {
            rebuildRoute(on: roadNetwork)
        }
        guard route.count > 1 else { return false }

        routeIndex = min(routeIndex + 1, route.count - 1)
        if routeIndex == route.count - 1 {
            completedTrips += 1
            rebuildRoute(on: roadNetwork)
        }
        return true
    }

    private mutating func rebuildRoute(on roadNetwork: RoadNetwork) {
        route = DeterministicRoadPatrol.route(
            from: origin,
            maximumRoadSteps: maximumRoadSteps,
            roadNetwork: roadNetwork,
            replaySeed: replaySeed,
            trip: completedTrips
        )
        routeIndex = 0
    }
}

public struct WalkerMovementSummary: Sendable, Equatable, Codable {
    public let requestedRoadSteps: Int
    public let movedRoadSteps: Int
    public let completedTrips: Int
    public let visitedRoadPoints: Set<GridPoint>
    public let servicedHouseIDs: Set<Int>
    public let servicedHouseIDsByService: [WalkerServiceKind: Set<Int>]

    public init(
        requestedRoadSteps: Int,
        movedRoadSteps: Int,
        completedTrips: Int,
        visitedRoadPoints: Set<GridPoint>,
        servicedHouseIDs: Set<Int>,
        servicedHouseIDsByService: [WalkerServiceKind: Set<Int>] = [:]
    ) {
        self.requestedRoadSteps = requestedRoadSteps
        self.movedRoadSteps = movedRoadSteps
        self.completedTrips = completedTrips
        self.visitedRoadPoints = visitedRoadPoints
        self.servicedHouseIDs = servicedHouseIDs
        self.servicedHouseIDsByService = servicedHouseIDsByService
    }

    private enum CodingKeys: String, CodingKey {
        case requestedRoadSteps, movedRoadSteps, completedTrips
        case visitedRoadPoints, servicedHouseIDs, servicedHouseIDsByService
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestedRoadSteps = try container.decode(Int.self, forKey: .requestedRoadSteps)
        movedRoadSteps = try container.decode(Int.self, forKey: .movedRoadSteps)
        completedTrips = try container.decode(Int.self, forKey: .completedTrips)
        visitedRoadPoints = try container.decode(Set<GridPoint>.self, forKey: .visitedRoadPoints)
        servicedHouseIDs = try container.decode(Set<Int>.self, forKey: .servicedHouseIDs)
        servicedHouseIDsByService = try container.decodeIfPresent(
            [WalkerServiceKind: Set<Int>].self,
            forKey: .servicedHouseIDsByService
        ) ?? (servicedHouseIDs.isEmpty ? [:] : [.tax: servicedHouseIDs])
    }

    public static let empty = Self(
        requestedRoadSteps: 0,
        movedRoadSteps: 0,
        completedTrips: 0,
        visitedRoadPoints: [],
        servicedHouseIDs: [],
        servicedHouseIDsByService: [:]
    )
}

public struct DeterministicWalkerState: Sendable, Equatable, Codable {
    public private(set) var walkers: [RoadServiceWalker]
    public private(set) var lastMovement: WalkerMovementSummary?
    private var nextWalkerID: Int

    public init() {
        walkers = []
        lastMovement = nil
        nextWalkerID = 1
    }

    @discardableResult
    public mutating func addWalker(
        figureID: Int,
        service: WalkerServiceKind,
        origin: GridPoint,
        maximumRoadSteps: Int,
        replaySeed: UInt64,
        roadNetwork: RoadNetwork
    ) -> Int? {
        guard maximumRoadSteps > 0, roadNetwork.contains(origin) else { return nil }
        let id = nextWalkerID
        nextWalkerID += 1
        walkers.append(RoadServiceWalker(
            id: id,
            figureID: figureID,
            service: service,
            origin: origin,
            maximumRoadSteps: maximumRoadSteps,
            replaySeed: replaySeed,
            roadNetwork: roadNetwork
        ))
        return id
    }

    @discardableResult
    public mutating func removeWalker(id: Int) -> RoadServiceWalker? {
        guard let index = walkers.firstIndex(where: { $0.id == id }) else { return nil }
        return walkers.remove(at: index)
    }

    @discardableResult
    public mutating func advance(
        roadStepsPerWalker: Int,
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        activeWalkerIDs: Set<Int>? = nil
    ) -> WalkerMovementSummary {
        let steps = max(0, roadStepsPerWalker)
        var moved = 0
        var completedTrips = 0
        var visited: Set<GridPoint> = []
        var servicedHouseIDs: Set<Int> = []
        var servicedByService: [WalkerServiceKind: Set<Int>] = [:]

        for index in walkers.indices.sorted(by: { walkers[$0].id < walkers[$1].id }) where
            activeWalkerIDs == nil || activeWalkerIDs?.contains(walkers[index].id) == true {
            let previousTrips = walkers[index].completedTrips
            visit(
                walkers[index].currentPoint,
                service: walkers[index].service,
                houses: houses,
                visited: &visited,
                servicedHouseIDs: &servicedHouseIDs,
                servicedByService: &servicedByService
            )
            for _ in 0..<steps {
                if walkers[index].advanceOneRoadStep(on: roadNetwork) {
                    moved += 1
                }
                visit(
                    walkers[index].currentPoint,
                    service: walkers[index].service,
                    houses: houses,
                    visited: &visited,
                    servicedHouseIDs: &servicedHouseIDs,
                    servicedByService: &servicedByService
                )
            }
            completedTrips += walkers[index].completedTrips - previousTrips
        }

        let result = WalkerMovementSummary(
            requestedRoadSteps: steps * walkers.count,
            movedRoadSteps: moved,
            completedTrips: completedTrips,
            visitedRoadPoints: visited,
            servicedHouseIDs: servicedHouseIDs,
            servicedHouseIDsByService: servicedByService
        )
        lastMovement = result
        return result
    }

    @discardableResult
    public mutating func advanceOnePatrolPerWalker(
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        activeWalkerIDs: Set<Int>? = nil
    ) -> WalkerMovementSummary {
        var requested = 0
        var moved = 0
        var completedTrips = 0
        var visited: Set<GridPoint> = []
        var servicedHouseIDs: Set<Int> = []
        var servicedByService: [WalkerServiceKind: Set<Int>] = [:]

        for index in walkers.indices.sorted(by: { walkers[$0].id < walkers[$1].id }) where
            activeWalkerIDs == nil || activeWalkerIDs?.contains(walkers[index].id) == true {
            let steps = walkers[index].maximumRoadSteps
            requested += steps
            let previousTrips = walkers[index].completedTrips
            visit(
                walkers[index].currentPoint,
                service: walkers[index].service,
                houses: houses,
                visited: &visited,
                servicedHouseIDs: &servicedHouseIDs,
                servicedByService: &servicedByService
            )
            for _ in 0..<steps {
                if walkers[index].advanceOneRoadStep(on: roadNetwork) {
                    moved += 1
                }
                visit(
                    walkers[index].currentPoint,
                    service: walkers[index].service,
                    houses: houses,
                    visited: &visited,
                    servicedHouseIDs: &servicedHouseIDs,
                    servicedByService: &servicedByService
                )
            }
            completedTrips += walkers[index].completedTrips - previousTrips
        }

        let result = WalkerMovementSummary(
            requestedRoadSteps: requested,
            movedRoadSteps: moved,
            completedTrips: completedTrips,
            visitedRoadPoints: visited,
            servicedHouseIDs: servicedHouseIDs,
            servicedHouseIDsByService: servicedByService
        )
        lastMovement = result
        return result
    }

    private func visit(
        _ roadPoint: GridPoint,
        service: WalkerServiceKind,
        houses: [ResidentialUnit],
        visited: inout Set<GridPoint>,
        servicedHouseIDs: inout Set<Int>,
        servicedByService: inout [WalkerServiceKind: Set<Int>]
    ) {
        visited.insert(roadPoint)
        for house in houses {
            guard let location = house.location,
                  RoadServiceCoverage.orthogonalNeighbors(of: location).contains(roadPoint) else { continue }
            servicedHouseIDs.insert(house.id)
            servicedByService[service, default: []].insert(house.id)
        }
    }
}

public enum DeterministicRoadPatrol {
    /// Builds a closed, depth-first patrol. The walker always has enough budget
    /// to retrace the current branch to its origin, so the serialized route never
    /// exceeds the original figure model's roaming range.
    public static func route(
        from origin: GridPoint,
        maximumRoadSteps: Int,
        roadNetwork: RoadNetwork,
        replaySeed: UInt64,
        trip: Int
    ) -> [GridPoint] {
        guard maximumRoadSteps > 0, roadNetwork.contains(origin) else { return [] }
        var route = [origin]
        var stack = [origin]
        var visited: Set<GridPoint> = [origin]

        while let current = stack.last {
            let usedSteps = route.count - 1
            let candidates = neighbors(of: current, in: roadNetwork)
                .filter { !visited.contains($0) }
                .sorted {
                    patrolRank($0, seed: replaySeed, trip: trip) < patrolRank($1, seed: replaySeed, trip: trip)
                }

            // Moving to a child at this depth must still leave one step per
            // ancestor edge for the return to the service building.
            if let next = candidates.first,
               usedSteps + 1 + stack.count <= maximumRoadSteps {
                visited.insert(next)
                stack.append(next)
                route.append(next)
                continue
            }

            guard stack.count > 1 else { break }
            stack.removeLast()
            route.append(stack[stack.count - 1])
        }
        return route
    }

    private static func neighbors(of point: GridPoint, in roadNetwork: RoadNetwork) -> [GridPoint] {
        [
            GridPoint(x: point.x, y: point.y - 1),
            GridPoint(x: point.x + 1, y: point.y),
            GridPoint(x: point.x, y: point.y + 1),
            GridPoint(x: point.x - 1, y: point.y)
        ].filter(roadNetwork.contains)
    }

    private static func patrolRank(_ point: GridPoint, seed: UInt64, trip: Int) -> UInt64 {
        var value = seed
        value ^= UInt64(bitPattern: Int64(trip)) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(bitPattern: Int64(point.x)) &* 0xBF58_476D_1CE4_E5B9
        value ^= UInt64(bitPattern: Int64(point.y)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
