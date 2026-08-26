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

public enum OriginalRoamerPhase: String, Sendable, Equatable, Codable {
    case dormant
    case outbound
    case returning
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
    private var originalPhaseState: OriginalRoamerPhase?
    private var originalSpawnCounterState: Int?
    private var originalMovementBudgetState: Int?
    private var originalSpeedPhaseState: Int?
    private var originalSubstepProgressState: Int?
    private var originalHeadingState: Int?
    private var originalForbiddenHeadingState: Int?
    private var originalProviderHeadingState: Int?
    private var originalInitialDirectionPendingState: Bool?
    private var originalCrossingCountState: Int?
    private var originalDirectionIncrementState: Int?
    private var originalFallbackCounterState: Int?
    private var originalRandomCallCounterState: UInt64?
    private var originalReturnRouteState: [GridPoint]?
    private var originalReturnIndexState: Int?
    private var originalProviderBuildingIDState: Int?

    public var originalPhase: OriginalRoamerPhase { originalPhaseState ?? .outbound }
    public var originalSpawnCounter: Int { originalSpawnCounterState ?? 0 }
    public var originalProviderBuildingID: Int? { originalProviderBuildingIDState }
    public var supportsRecoveredResidentialRoam: Bool {
        figureID == 27 || figureID == 28 || figureID == 30 || figureID == 31 || figureID == 35
    }
    var originalVisitFieldSelector: Int? {
        switch figureID {
        case 27: return 6
        case 28, 30, 31: return 0
        case 35: return 5
        default: return nil
        }
    }

    func requiresOriginalReturnPassability(withinOriginalSteps originalSteps: Int) -> Bool {
        guard supportsRecoveredResidentialRoam, originalPhase != .dormant else { return false }
        if originalPhase == .returning { return originalReturnRouteState == nil }
        let movementCode = figureID == 28 ? 8 : 6
        return (originalMovementBudgetState ?? 0) + max(0, originalSteps) * movementCode
            >= maximumRoadSteps * 0x60
    }

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
        roadNetwork: RoadNetwork,
        barrierPoints: Set<GridPoint> = [],
        startsDormant: Bool = false,
        providerBuildingID: Int? = nil
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
            trip: 0,
            barrierPoints: barrierPoints
        )
        routeIndex = 0
        completedTrips = 0
        originalPhaseState = startsDormant ? .dormant : .outbound
        originalSpawnCounterState = 0
        originalMovementBudgetState = 0
        originalSpeedPhaseState = 0
        originalSubstepProgressState = 20
        originalHeadingState = startsDormant ? nil : 0
        originalForbiddenHeadingState = startsDormant ? nil : 0
        originalProviderHeadingState = 0
        originalInitialDirectionPendingState = !startsDormant
        originalCrossingCountState = 0
        originalDirectionIncrementState = 1
        originalFallbackCounterState = -1
        originalRandomCallCounterState = 0
        originalReturnRouteState = nil
        originalReturnIndexState = nil
        originalProviderBuildingIDState = providerBuildingID
    }

    mutating func originalSpawn(workerPercent: Int) {
        guard supportsRecoveredResidentialRoam, originalPhase == .dormant, workerPercent > 0 else {
            return
        }
        let threshold = originalSpawnThreshold(workerPercent: workerPercent)
        let next = originalSpawnCounter + 1
        originalSpawnCounterState = next
        guard next > threshold else { return }
        originalSpawnCounterState = 0
        originalPhaseState = .outbound
        originalMovementBudgetState = 0
        originalSpeedPhaseState = 0
        originalSubstepProgressState = 20
        // The base building constructor zeroes provider byte `+0x38`.
        // `0x51CF90` creates the figure with that saved heading, then writes
        // its opposite to figure `+0x1A`. The first `0x4E6690` selection
        // therefore begins at the provider heading and forbids that same
        // direction. `0x4E6A70` saves the selected exit back to `+0x38`.
        let providerHeading = originalProviderHeadingState ?? 0
        originalHeadingState = providerHeading
        originalForbiddenHeadingState = providerHeading
        originalInitialDirectionPendingState = true
        originalCrossingCountState = 0
        originalDirectionIncrementState = 1
        originalFallbackCounterState = -1
        originalReturnRouteState = nil
        originalReturnIndexState = nil
        route = [origin]
        routeIndex = 0
    }

    private func originalSpawnThreshold(workerPercent: Int) -> Int {
        if figureID == 35 {
            switch workerPercent {
            case 100...: return 3
            case 75...: return 6
            case 50...: return 12
            case 25...: return 24
            default: return 32
            }
        }
        if figureID == 27 {
            switch workerPercent {
            case 100...: return 1
            case 75...: return 3
            case 50...: return 5
            case 25...: return 10
            default: return 15
            }
        }
        switch workerPercent {
        case 100...: return 1
        case 75...: return 3
        case 50...: return 7
        case 25...: return 15
        default: return 29
        }
    }

    mutating func advanceOriginalFigureStep(
        on roadNetwork: RoadNetwork,
        primaryReturnPassability: [UInt16]?,
        barrierPoints: Set<GridPoint>,
        junctionVisitScores: inout [GridPoint: Int],
        visit: (GridPoint, WalkerServiceKind) -> Void
    ) -> Int {
        guard supportsRecoveredResidentialRoam, originalPhase != .dormant else { return 0 }
        let movementCode = figureID == 28 ? 8 : 6
        // Figure-model selector 15 multiplies the authored behavior range by
        // `3 << 5` before storing figure word `+0x4A` (`0x4C9310`).
        let originalBudgetLimit = maximumRoadSteps * 0x60

        if originalPhase == .returning {
            if originalReturnRouteState == nil {
                guard currentPoint != origin else {
                    originalPhaseState = .dormant
                    completedTrips += 1
                    return 0
                }
                guard let primaryReturnPassability,
                      let returnRoute = OriginalGrandCanalLayoutCatalog
                        .residentialServiceReturnRoute(
                            primaryValues: primaryReturnPassability,
                            width: roadNetwork.width,
                            height: roadNetwork.height,
                            from: currentPoint,
                            to: origin
                        ),
                      returnRoute.points.count > 1 else {
                    // The original always routes through its derived primary
                    // cache. If Native cannot derive that cache, stop here
                    // and retry later instead of substituting a road-only
                    // shortest path or reporting a completed return.
                    return 0
                }
                originalReturnRouteState = returnRoute.points
                originalReturnIndexState = 0
                // Successful `0x4E83E0` route construction primes `+0x41`
                // to 20, so this same figure update advances its first step.
                originalSubstepProgressState = 20
            }
            var moved = 0
            for _ in 0..<originalSubsteps(movementCode: movementCode) {
                moved += advanceOriginalReturnSubstep()
            }
            return moved
        }

        if originalPhase == .outbound,
           (originalMovementBudgetState ?? 0) >= originalBudgetLimit {
            originalPhaseState = .returning
            originalReturnRouteState = nil
            originalReturnIndexState = nil
            if figureID == 28 {
                // `0x4E3A80` destroys the roam route, resets `+0x4C`, and
                // returns. Route construction starts on the next update.
                originalMovementBudgetState = 0
                return 0
            }
            // Generic `0x51D0C0` changes to return state 9 but still executes
            // that update's trailing `0x4E6B70(..., 6)` roaming micro-step.
            originalMovementBudgetState = (originalMovementBudgetState ?? 0) + movementCode
            return advanceOriginalRoamSubstep(
                on: roadNetwork,
                barrierPoints: barrierPoints,
                junctionVisitScores: &junctionVisitScores,
                visit: visit
            )
        }

        if originalPhase == .outbound {
            originalMovementBudgetState = (originalMovementBudgetState ?? 0) + movementCode
        }
        let substeps = originalSubsteps(movementCode: movementCode)
        var moved = 0
        for _ in 0..<substeps {
            if originalPhase == .returning {
                moved += advanceOriginalReturnSubstep()
            } else {
                moved += advanceOriginalRoamSubstep(
                    on: roadNetwork,
                    barrierPoints: barrierPoints,
                    junctionVisitScores: &junctionVisitScores,
                    visit: visit
                )
            }
        }
        return moved
    }

    private mutating func originalSubsteps(movementCode: Int) -> Int {
        // Recovered residential paths call `FUN_004E6B70` with codes 6 or 8.
        // Code 6 executes one `FUN_004E6D80` substep. Code 8 uses `+0x170`
        // to execute the exact repeating 1/1/2 substep cadence.
        if movementCode == 8 {
            let phase = originalSpeedPhaseState ?? 0
            if phase < 2 {
                originalSpeedPhaseState = phase + 1
                return 1
            }
            originalSpeedPhaseState = 0
            return 2
        }
        return 1
    }

    private mutating func advanceOriginalReturnSubstep() -> Int {
        var progress = originalSubstepProgressState ?? 20
        progress += 1
        originalSubstepProgressState = progress
        guard progress >= 20,
              let homeRoute = originalReturnRouteState,
              let index = originalReturnIndexState,
              homeRoute.indices.contains(index + 1) else { return 0 }
        let next = homeRoute[index + 1]
        route.append(next)
        routeIndex = route.count - 1
        originalReturnIndexState = index + 1
        originalSubstepProgressState = 0
        if next == origin {
            originalPhaseState = .dormant
            originalReturnRouteState = nil
            originalReturnIndexState = nil
            completedTrips += 1
        }
        return 1
    }

    private mutating func advanceOriginalRoamSubstep(
        on roadNetwork: RoadNetwork,
        barrierPoints: Set<GridPoint>,
        junctionVisitScores: inout [GridPoint: Int],
        visit: (GridPoint, WalkerServiceKind) -> Void
    ) -> Int {
        var progress = originalSubstepProgressState ?? 20
        if progress >= 20 {
            originalCrossingCountState = (originalCrossingCountState ?? 0) + 1
            visit(currentPoint, service)
            junctionVisitScores[currentPoint] = 7
            let selectedHeading = originalRoamHeading(
                at: currentPoint,
                on: roadNetwork,
                barrierPoints: barrierPoints,
                junctionVisitScores: junctionVisitScores
            )
            if let selectedHeading {
                if originalInitialDirectionPendingState == true {
                    originalProviderHeadingState = selectedHeading
                    originalInitialDirectionPendingState = false
                }
                originalHeadingState = selectedHeading
                originalForbiddenHeadingState = (selectedHeading + 2) & 3
            } else {
                originalHeadingState = nil
            }
            progress = 0
        }
        progress += 1
        originalSubstepProgressState = progress
        guard progress >= 20, let heading = originalHeadingState else { return 0 }
        let next = Self.originalNeighbor(of: currentPoint, heading: heading)
        guard roadNetwork.contains(next), !barrierPoints.contains(next) else {
            originalSubstepProgressState = 20
            return 0
        }
        route.append(next)
        routeIndex = route.count - 1
        originalSubstepProgressState = 20
        return 1
    }

    private mutating func originalRoamHeading(
        at point: GridPoint,
        on roadNetwork: RoadNetwork,
        barrierPoints: Set<GridPoint>,
        junctionVisitScores: [GridPoint: Int]
    ) -> Int? {
        let allCandidates = (0..<4).filter {
            let next = Self.originalNeighbor(of: point, heading: $0)
            return roadNetwork.contains(next) && !barrierPoints.contains(next)
        }
        guard !allCandidates.isEmpty else { return nil }
        var forbidden = originalForbiddenHeadingState
        var candidates = allCandidates
        if originalInitialDirectionPendingState != true, candidates.count > 2,
           let minimum = candidates.map({
                junctionVisitScores[Self.originalNeighbor(of: point, heading: $0), default: 0]
           }).min() {
            candidates = candidates.filter {
                junctionVisitScores[Self.originalNeighbor(of: point, heading: $0), default: 0]
                    == minimum
            }
        }
        if candidates.count == 1 { return candidates[0] }
        if candidates.count == 2, let current = originalHeadingState {
            if originalInitialDirectionPendingState != true,
               (originalFallbackCounterState ?? -1) == -1 {
                _ = chooseOriginalFallbackHeading(
                    at: point,
                    candidates: allCandidates,
                    junctionVisitScores: junctionVisitScores
                )
                forbidden = nil
            }
            var heading = originalHeadingState ?? current
            let increment = originalDirectionIncrementState ?? 1
            for _ in 0..<4 {
                if candidates.contains(heading), heading != forbidden { return heading }
                heading = (heading + increment) & 3
            }
            return nil
        }
        let byte = originalJunctionByte(point)
        var heading = ((Int(byte) + (originalCrossingCountState ?? 0)) & 6) >> 1
        if !candidates.contains(heading) || heading == forbidden {
            let nextCounter = (originalFallbackCounterState ?? -1) - 1
            originalFallbackCounterState = nextCounter
            if nextCounter < 1 {
                heading = chooseOriginalFallbackHeading(
                    at: point,
                    candidates: allCandidates,
                    junctionVisitScores: junctionVisitScores
                ) ?? heading
                forbidden = nil
            }
            let increment = originalDirectionIncrementState ?? 1
            for _ in 0..<4 {
                if candidates.contains(heading), heading != forbidden { return heading }
                heading = (heading + increment) & 3
            }
            return nil
        }
        return heading
    }

    /// Supported residential figures all have a non-negative visit-field
    /// selector, so this is the exact second branch of `FUN_004E71D0`: choose
    /// the least-visited cardinal neighbor, preserve its unusual tie update,
    /// choose clockwise/counterclockwise rotation from the next RNG bit, and
    /// reload fallback counter `+0x51` to five.
    private mutating func chooseOriginalFallbackHeading(
        at point: GridPoint,
        candidates: [Int],
        junctionVisitScores: [GridPoint: Int]
    ) -> Int? {
        var selected: Int?
        var minimum = 8
        var tieCounter = 1
        for heading in 0..<4 where candidates.contains(heading) {
            let score = junctionVisitScores[
                Self.originalNeighbor(of: point, heading: heading),
                default: 0
            ]
            if score < minimum {
                minimum = score
                tieCounter = 2
                selected = heading
            } else if score == minimum {
                tieCounter += 1
                if originalRandomUInt32() % UInt32(tieCounter) != 0 {
                    selected = heading
                }
            }
        }
        guard let selected else { return nil }
        originalHeadingState = selected
        originalDirectionIncrementState = originalRandomUInt32() & 1 == 0 ? 1 : -1
        originalFallbackCounterState = 5
        return selected
    }

    private mutating func originalRandomUInt32() -> UInt32 {
        let counter = originalRandomCallCounterState ?? 0
        originalRandomCallCounterState = counter &+ 1
        var value = replaySeed &+ counter &* 0x9E37_79B9_7F4A_7C15
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return UInt32(truncatingIfNeeded: value)
    }

    private static func originalHeading(from point: GridPoint, to next: GridPoint) -> Int? {
        switch (next.x - point.x, next.y - point.y) {
        case (0, -1): return 0
        case (1, 0): return 1
        case (0, 1): return 2
        case (-1, 0): return 3
        default: return nil
        }
    }

    private static func originalNeighbor(of point: GridPoint, heading: Int) -> GridPoint {
        switch heading & 3 {
        case 0: return GridPoint(x: point.x, y: point.y - 1)
        case 1: return GridPoint(x: point.x + 1, y: point.y)
        case 2: return GridPoint(x: point.x, y: point.y + 1)
        default: return GridPoint(x: point.x - 1, y: point.y)
        }
    }

    /// Deterministic replacement for the original saved 228×228 random-byte
    /// grid. It preserves one byte per cell and uniform low-bit selection.
    private func originalJunctionByte(_ point: GridPoint) -> UInt8 {
        var value = replaySeed
        value ^= UInt64(bitPattern: Int64(point.x)) &* 0x9E37_79B9_7F4A_7C15
        value ^= UInt64(bitPattern: Int64(point.y)) &* 0xBF58_476D_1CE4_E5B9
        value ^= value >> 30
        value &*= 0x94D0_49BB_1331_11EB
        return UInt8(truncatingIfNeeded: value ^ (value >> 31))
    }

    mutating func advanceOneRoadStep(
        on roadNetwork: RoadNetwork,
        barrierPoints: Set<GridPoint> = []
    ) -> Bool {
        guard maximumRoadSteps > 0, roadNetwork.contains(origin) else { return false }
        if route.isEmpty || !route.allSatisfy(roadNetwork.contains) {
            rebuildRoute(on: roadNetwork, barrierPoints: barrierPoints)
        }
        guard route.count > 1 else { return false }

        if barrierPoints.contains(route[routeIndex + 1]) {
            // Confirmed safety boundary: a roamer never enters a roadblock.
            // The original post-collision direction choice remains unknown;
            // retain its position and route rather than inventing a reroute.
            return false
        }

        routeIndex = min(routeIndex + 1, route.count - 1)
        if routeIndex == route.count - 1 {
            completedTrips += 1
            rebuildRoute(on: roadNetwork, barrierPoints: barrierPoints)
        }
        return true
    }

    private mutating func rebuildRoute(on roadNetwork: RoadNetwork, barrierPoints: Set<GridPoint>) {
        route = DeterministicRoadPatrol.route(
            from: origin,
            maximumRoadSteps: maximumRoadSteps,
            roadNetwork: roadNetwork,
            replaySeed: replaySeed,
            trip: completedTrips,
            barrierPoints: barrierPoints
        )
        routeIndex = 0
    }
}

public struct WalkerMovementSummary: Sendable, Equatable, Codable {
    public let requestedRoadSteps: Int
    public let movedRoadSteps: Int
    public let completedTrips: Int
    public let visitedRoadPoints: Set<GridPoint>
    public let visitedRoadPointsByService: [WalkerServiceKind: Set<GridPoint>]
    public let servicedHouseIDs: Set<Int>
    public let servicedHouseIDsByService: [WalkerServiceKind: Set<Int>]

    public init(
        requestedRoadSteps: Int,
        movedRoadSteps: Int,
        completedTrips: Int,
        visitedRoadPoints: Set<GridPoint>,
        visitedRoadPointsByService: [WalkerServiceKind: Set<GridPoint>] = [:],
        servicedHouseIDs: Set<Int>,
        servicedHouseIDsByService: [WalkerServiceKind: Set<Int>] = [:]
    ) {
        self.requestedRoadSteps = requestedRoadSteps
        self.movedRoadSteps = movedRoadSteps
        self.completedTrips = completedTrips
        self.visitedRoadPoints = visitedRoadPoints
        self.visitedRoadPointsByService = visitedRoadPointsByService
        self.servicedHouseIDs = servicedHouseIDs
        self.servicedHouseIDsByService = servicedHouseIDsByService
    }

    private enum CodingKeys: String, CodingKey {
        case requestedRoadSteps, movedRoadSteps, completedTrips
        case visitedRoadPoints, visitedRoadPointsByService
        case servicedHouseIDs, servicedHouseIDsByService
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestedRoadSteps = try container.decode(Int.self, forKey: .requestedRoadSteps)
        movedRoadSteps = try container.decode(Int.self, forKey: .movedRoadSteps)
        completedTrips = try container.decode(Int.self, forKey: .completedTrips)
        visitedRoadPoints = try container.decode(Set<GridPoint>.self, forKey: .visitedRoadPoints)
        visitedRoadPointsByService = try container.decodeIfPresent(
            [WalkerServiceKind: Set<GridPoint>].self,
            forKey: .visitedRoadPointsByService
        ) ?? [:]
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

/// Exact radius-two object scan used by `FUN_00429E10`. The original keeps
/// sixteen angular occlusion sectors. Native exposes the confirmed residential
/// wall/gate objects here; the separate tree/wall-terrain branch remains
/// unavailable until its auxiliary bit-4 object state is represented.
enum OriginalResidentialServiceCoverage {
    private static let wallAndGateBuildingIDs: Set<Int> = [
        89, 90, 91, 104, 105, 106, 231, 232,
    ]

    private static let sectorBoundaryVectors: [((Double, Double), (Double, Double))] = [
        ((-4, -3), (-3, -4)),
        ((-3, -4), (-1, -4)),
        ((-1, -4), (1, -4)),
        ((1, -4), (3, -4)),
        ((3, -4), (4, -3)),
        ((4, -3), (4, -1)),
        ((4, -1), (4, 1)),
        ((4, 1), (4, 3)),
        ((4, 3), (3, 4)),
        ((3, 4), (1, 4)),
        ((1, 4), (-1, 4)),
        ((-1, 4), (-3, 4)),
        ((-3, 4), (-4, 3)),
        ((-4, 3), (-4, 1)),
        ((-4, 1), (-4, -1)),
        ((-4, -1), (-4, -3)),
    ]

    static func blockerPoints(placements: [PlacedBuilding]) -> Set<GridPoint> {
        Set(placements.lazy
            .filter { wallAndGateBuildingIDs.contains($0.buildingID) }
            .flatMap(\.occupiedPoints))
    }

    static func houseIndices(
        servicedFrom origin: GridPoint,
        service: WalkerServiceKind,
        providerBuildingID: Int?,
        houses: [ResidentialUnit],
        blockerPoints: Set<GridPoint>
    ) -> Set<Int> {
        let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        var houseIndexByPoint: [GridPoint: Int] = [:]
        for index in houses.indices {
            guard let location = houses[index].location else { continue }
            for point in footprint.points(at: location) where houseIndexByPoint[point] == nil {
                houseIndexByPoint[point] = index
            }
        }
        let objectPoints = Set(houseIndexByPoint.keys).union(blockerPoints)
        var sectorIsBlocked = [Bool](repeating: false, count: 16)
        var sectorBlockDepth = [Int](repeating: 0, count: 16)
        var serviced: Set<Int> = []

        for radius in 1...2 {
            for y in (origin.y - radius)...(origin.y + radius) {
                for x in (origin.x - radius)...(origin.x + radius) {
                    let point = GridPoint(x: x, y: y)
                    guard objectPoints.contains(point) else { continue }
                    let dx = x - origin.x
                    let dy = y - origin.y
                    let direction = sector(dx: dx, dy: dy)

                    if blockerPoints.contains(point), let direction {
                        if !sectorIsBlocked[direction] || radius < sectorBlockDepth[direction] {
                            sectorBlockDepth[direction] = radius
                        }
                        sectorIsBlocked[direction] = true
                        if radius == 1, direction.isMultiple(of: 2) {
                            closeIntermediateRadiusOneSectors(
                                around: direction,
                                sectorIsBlocked: &sectorIsBlocked,
                                sectorBlockDepth: &sectorBlockDepth
                            )
                        }
                        continue
                    }

                    let distance = abs(dx) + abs(dy)
                    if let direction,
                       sectorIsBlocked[direction],
                       distance > sectorBlockDepth[direction] {
                        continue
                    }
                    guard let houseIndex = houseIndexByPoint[point],
                          isEligible(
                            houses[houseIndex],
                            for: service,
                            providerBuildingID: providerBuildingID
                          ) else { continue }
                    serviced.insert(houseIndex)
                }
            }
        }
        return serviced
    }

    private static func isEligible(
        _ house: ResidentialUnit,
        for service: WalkerServiceKind,
        providerBuildingID: Int?
    ) -> Bool {
        switch service {
        case .tax, .water, .herbalist, .acupuncture:
            return house.residents > 0
        case .ancestor, .daoistOrBuddhist, .confucian:
            let buildingID = house.residents == 0
                ? (house.vacantTypeID ?? house.houseLevelID + 3)
                : house.houseLevelID + 3
            guard (2..<18).contains(buildingID) else { return false }
            let isEliteHouse = (11..<18).contains(buildingID)
            if providerBuildingID == 219 || service == .confucian { return isEliteHouse }
            return house.residents > 0 || isEliteHouse
        case .inspection, .constable, .music, .acrobat, .drama:
            return false
        }
    }

    private static func closeIntermediateRadiusOneSectors(
        around direction: Int,
        sectorIsBlocked: inout [Bool],
        sectorBlockDepth: inout [Int]
    ) {
        let clockwiseEven = (direction + 2) & 15
        if sectorIsBlocked[clockwiseEven], sectorBlockDepth[clockwiseEven] == 1 {
            let intermediate = (direction + 1) & 15
            sectorIsBlocked[intermediate] = true
            sectorBlockDepth[intermediate] = 1
        }
        let counterclockwiseEven = (direction + 14) & 15
        if sectorIsBlocked[counterclockwiseEven], sectorBlockDepth[counterclockwiseEven] == 1 {
            let intermediate = (direction + 15) & 15
            sectorIsBlocked[intermediate] = true
            sectorBlockDepth[intermediate] = 1
        }
    }

    private static func sector(dx: Int, dy: Int) -> Int? {
        guard dx != 0 || dy != 0 else { return nil }
        let angle = atan2(Double(dy), Double(dx))
        for (index, vectors) in sectorBoundaryVectors.enumerated() {
            let first = atan2(vectors.0.1, vectors.0.0)
            let second = atan2(vectors.1.1, vectors.1.0)
            let lower = min(first, second)
            let upper = max(first, second)
            if upper - lower > Double.pi {
                if angle <= lower || upper <= angle { return index }
            } else if lower <= angle, angle <= upper {
                return index
            }
        }
        return nil
    }
}

public struct DeterministicWalkerState: Sendable, Equatable, Codable {
    public private(set) var walkers: [RoadServiceWalker]
    public private(set) var lastMovement: WalkerMovementSummary?
    private var nextWalkerID: Int
    private var originalSchedulerPhaseState: Int?
    private var originalVisitFieldsState: [Int: [GridPoint: Int]]?
    private var originalVisitDecayCounterState: Int?

    public var originalVisitDecayCounter: Int { originalVisitDecayCounterState ?? 0 }

    public init() {
        walkers = []
        lastMovement = nil
        nextWalkerID = 1
        originalSchedulerPhaseState = 0
        originalVisitFieldsState = [:]
        originalVisitDecayCounterState = 0
    }

    func requiresOriginalReturnPassability(withinOriginalSteps originalSteps: Int) -> Bool {
        walkers.contains {
            $0.requiresOriginalReturnPassability(withinOriginalSteps: originalSteps)
        }
    }

    @discardableResult
    public mutating func addWalker(
        figureID: Int,
        service: WalkerServiceKind,
        origin: GridPoint,
        maximumRoadSteps: Int,
        replaySeed: UInt64,
        roadNetwork: RoadNetwork,
        barrierPoints: Set<GridPoint> = [],
        startsDormant: Bool = false,
        providerBuildingID: Int? = nil
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
            roadNetwork: roadNetwork,
            barrierPoints: barrierPoints,
            startsDormant: startsDormant,
            providerBuildingID: providerBuildingID
        ))
        return id
    }

    @discardableResult
    public mutating func advanceRecoveredOriginalSteps(
        _ originalSteps: Int,
        houses: inout [ResidentialUnit],
        roadNetwork: RoadNetwork,
        workerPercentByWalkerID: [Int: Int],
        primaryReturnPassability: [UInt16]? = nil,
        coverageBlockerPoints: Set<GridPoint> = [],
        barrierPoints: Set<GridPoint> = []
    ) -> WalkerMovementSummary {
        var moved = 0
        var completed = 0
        var visited: Set<GridPoint> = []
        var visitedByService: [WalkerServiceKind: Set<GridPoint>] = [:]
        var serviced: Set<Int> = []
        var servicedByService: [WalkerServiceKind: Set<Int>] = [:]

        for _ in 0..<max(0, originalSteps) {
            let phase = originalSchedulerPhaseState ?? 0
            if phase == 0x1f {
                for index in walkers.indices {
                    walkers[index].originalSpawn(
                        workerPercent: workerPercentByWalkerID[walkers[index].id, default: 100]
                    )
                }
            }
            if phase == 0x23 {
                for index in houses.indices { houses[index].advanceOriginalOrdinaryServiceSlice() }
            }
            if phase == 0x2d {
                advanceOriginalVisitFieldDecaySlice()
            }
            if phase == 0x30 {
                for index in houses.indices { houses[index].advanceOriginalTaxServiceSlice() }
            }

            for index in walkers.indices.sorted(by: { walkers[$0].id < walkers[$1].id }) {
                let oldTrips = walkers[index].completedTrips
                var stepVisits: [(GridPoint, WalkerServiceKind)] = []
                let selector = walkers[index].originalVisitFieldSelector
                var visitScores = selector.flatMap { originalVisitFieldsState?[$0] } ?? [:]
                moved += walkers[index].advanceOriginalFigureStep(
                    on: roadNetwork,
                    primaryReturnPassability: primaryReturnPassability,
                    barrierPoints: barrierPoints,
                    junctionVisitScores: &visitScores,
                    visit: { stepVisits.append(($0, $1)) }
                )
                if let selector {
                    var fields = originalVisitFieldsState ?? [:]
                    fields[selector] = visitScores
                    originalVisitFieldsState = fields
                }
                completed += walkers[index].completedTrips - oldTrips
                for (point, service) in stepVisits {
                    visited.insert(point)
                    visitedByService[service, default: []].insert(point)
                    let houseIndices = OriginalResidentialServiceCoverage.houseIndices(
                        servicedFrom: point,
                        service: service,
                        providerBuildingID: walkers[index].originalProviderBuildingID,
                        houses: houses,
                        blockerPoints: coverageBlockerPoints
                    )
                    for houseIndex in houseIndices {
                        houses[houseIndex].applyOriginalServiceVisit(service)
                        serviced.insert(houses[houseIndex].id)
                        servicedByService[service, default: []].insert(houses[houseIndex].id)
                    }
                }
            }
            originalSchedulerPhaseState = (phase + 1) % 0x33
        }

        let result = WalkerMovementSummary(
            requestedRoadSteps: max(0, originalSteps) * walkers.count,
            movedRoadSteps: moved,
            completedTrips: completed,
            visitedRoadPoints: visited,
            visitedRoadPointsByService: visitedByService,
            servicedHouseIDs: serviced,
            servicedHouseIDsByService: servicedByService
        )
        lastMovement = result
        return result
    }

    private mutating func advanceOriginalVisitFieldDecaySlice() {
        let next = (originalVisitDecayCounterState ?? 0) + 1
        guard next > 7 else {
            originalVisitDecayCounterState = next
            return
        }
        originalVisitDecayCounterState = 0
        var fields = originalVisitFieldsState ?? [:]
        for selector in Array(fields.keys) {
            var scores = fields[selector, default: [:]]
            for point in Array(scores.keys) {
                let nextScore = scores[point, default: 0] - 1
                if nextScore > 0 {
                    scores[point] = nextScore
                } else {
                    scores.removeValue(forKey: point)
                }
            }
            fields[selector] = scores
        }
        originalVisitFieldsState = fields
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
        activeWalkerIDs: Set<Int>? = nil,
        barrierPoints: Set<GridPoint> = []
    ) -> WalkerMovementSummary {
        let steps = max(0, roadStepsPerWalker)
        var moved = 0
        var completedTrips = 0
        var visited: Set<GridPoint> = []
        var visitedByService: [WalkerServiceKind: Set<GridPoint>] = [:]
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
                visitedByService: &visitedByService,
                servicedHouseIDs: &servicedHouseIDs,
                servicedByService: &servicedByService
            )
            for _ in 0..<steps {
                if walkers[index].advanceOneRoadStep(on: roadNetwork, barrierPoints: barrierPoints) {
                    moved += 1
                }
                visit(
                    walkers[index].currentPoint,
                    service: walkers[index].service,
                    houses: houses,
                    visited: &visited,
                    visitedByService: &visitedByService,
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
            visitedRoadPointsByService: visitedByService,
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
        activeWalkerIDs: Set<Int>? = nil,
        barrierPoints: Set<GridPoint> = []
    ) -> WalkerMovementSummary {
        var requested = 0
        var moved = 0
        var completedTrips = 0
        var visited: Set<GridPoint> = []
        var visitedByService: [WalkerServiceKind: Set<GridPoint>] = [:]
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
                visitedByService: &visitedByService,
                servicedHouseIDs: &servicedHouseIDs,
                servicedByService: &servicedByService
            )
            for _ in 0..<steps {
                if walkers[index].advanceOneRoadStep(on: roadNetwork, barrierPoints: barrierPoints) {
                    moved += 1
                }
                visit(
                    walkers[index].currentPoint,
                    service: walkers[index].service,
                    houses: houses,
                    visited: &visited,
                    visitedByService: &visitedByService,
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
            visitedRoadPointsByService: visitedByService,
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
        visitedByService: inout [WalkerServiceKind: Set<GridPoint>],
        servicedHouseIDs: inout Set<Int>,
        servicedByService: inout [WalkerServiceKind: Set<Int>]
    ) {
        visited.insert(roadPoint)
        visitedByService[service, default: []].insert(roadPoint)
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
    /// exceeds the original figure model's roaming range. Roadblock tiles are
    /// closed for the patrol: a roaming walker never enters them (it turns away
    /// instead), while path-following/destination movement keeps using the
    /// complete road network.
    public static func route(
        from origin: GridPoint,
        maximumRoadSteps: Int,
        roadNetwork: RoadNetwork,
        replaySeed: UInt64,
        trip: Int,
        barrierPoints: Set<GridPoint> = []
    ) -> [GridPoint] {
        guard maximumRoadSteps > 0,
              roadNetwork.contains(origin),
              !barrierPoints.contains(origin) else { return [] }
        var route = [origin]
        var stack = [origin]
        var visited: Set<GridPoint> = [origin]

        while let current = stack.last {
            let usedSteps = route.count - 1
            let candidates = neighbors(of: current, in: roadNetwork, barrierPoints: barrierPoints)
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

    private static func neighbors(
        of point: GridPoint,
        in roadNetwork: RoadNetwork,
        barrierPoints: Set<GridPoint>
    ) -> [GridPoint] {
        [
            GridPoint(x: point.x, y: point.y - 1),
            GridPoint(x: point.x + 1, y: point.y),
            GridPoint(x: point.x, y: point.y + 1),
            GridPoint(x: point.x - 1, y: point.y)
        ].filter { roadNetwork.contains($0) && !barrierPoints.contains($0) }
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
