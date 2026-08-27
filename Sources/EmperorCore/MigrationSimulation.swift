import Foundation

public enum MigrationBlockReason: Sendable, Hashable, Codable {
    case noEligibleHousing
    case negativeTreasury
    case highUnemployment(percent: Int)
}

/// Automatic migration remains disabled until the recovered original
/// popularity/factor producer, figure-#11 arrival write chain, and unmapped
/// factor inputs are represented in Native state.
public enum AutomaticMigrationAvailability: String, Sendable, Hashable, Codable {
    /// Enabled after the recovered producer is implemented and verified.
    case supportedOriginalProducer
    /// Fail-closed default: the popularity/factor producer is not run.
    case unsupportedOriginalProducer
}

public struct MigrationAssessment: Sendable, Hashable, Codable {
    public let eligibleHouseIDs: [Int]
    public let availableCapacity: Int
    public let unemploymentPercent: Int
    public let plannedImmigrants: Int
    public let blockReason: MigrationBlockReason?

    public static let noHousing = Self(
        eligibleHouseIDs: [],
        availableCapacity: 0,
        unemploymentPercent: 0,
        plannedImmigrants: 0,
        blockReason: .noEligibleHousing
    )
}

/// A physical immigrant figure (model 11) walking from the authored land
/// entry to a house. Implements the recovered `FUN_004C9FD0` state machine
/// (`6` wait → `7` walk → `8` arrive) mapped onto the Native 30-day clock
/// bridge: each Native day runs `floor(day×816/30) − floor((day−1)×816/30)`
/// original figure updates, and movement follows the recovered 1/1/2
/// substep cadence with a 20-substep route step (initial progress 20 so the
/// first substep advances immediately, §5.2–§5.3).
public struct ImmigrantWalker: Identifiable, Sendable, Hashable, Codable {
    public static let figureID = 11
    public static let originalStepsPerMonth = 816
    public static let nativeDaysPerMonth = 30

    public enum State: Int, Sendable, Hashable, Codable {
        case waiting = 6
        case walking = 7
        case arriving = 8
    }

    public let id: Int
    public let houseID: Int
    public let peopleCount: Int
    public let entryPoint: GridPoint
    public private(set) var route: [GridPoint]
    public private(set) var routeIndex: Int
    public private(set) var state: State
    /// Original `figure+0x3e` wait word, in original simulation steps.
    public private(set) var waitStepsRemaining: Int
    /// 1/1/2 substep pattern index (0…2) and progress (initial 20).
    public private(set) var substepPatternIndex: Int
    public private(set) var substepProgress: Int

    public var currentPoint: GridPoint {
        route.indices.contains(routeIndex) ? route[routeIndex] : entryPoint
    }

    public init(
        id: Int,
        houseID: Int,
        peopleCount: Int,
        entryPoint: GridPoint,
        route: [GridPoint],
        waitSteps: Int
    ) {
        self.id = id
        self.houseID = houseID
        self.peopleCount = max(1, peopleCount)
        self.entryPoint = entryPoint
        self.route = route
        routeIndex = 0
        state = waitSteps > 0 ? .waiting : .walking
        waitStepsRemaining = max(0, waitSteps)
        substepPatternIndex = 0
        substepProgress = 20
    }

    /// Consumes one original figure update. Returns `true` when the arrival
    /// write becomes due (the update after the walker reaches the house).
    public mutating func advanceOneUpdate() -> Bool {
        switch state {
        case .waiting:
            waitStepsRemaining -= 1
            if waitStepsRemaining <= 0 {
                state = .walking
            }
            return false
        case .walking:
            substepProgress += [1, 1, 2][substepPatternIndex]
            substepPatternIndex = (substepPatternIndex + 1) % 3
            while substepProgress >= 20, routeIndex < route.count - 1 {
                substepProgress -= 20
                routeIndex += 1
            }
            if routeIndex == route.count - 1 {
                state = .arriving
            }
            return false
        case .arriving:
            return true
        }
    }
}

/// Result of an immigrant reaching its house (the `0x4CA265` occupancy write
/// is applied by the city, not by the walker).
public struct ImmigrantArrival: Sendable, Hashable, Codable {
    public let houseID: Int
    public let peopleCount: Int

    public init(houseID: Int, peopleCount: Int) {
        self.houseID = houseID
        self.peopleCount = peopleCount
    }
}

/// Campaign-level inputs the daily migration producer needs (set by the
/// runtime at mission start and each monthly advance).
public struct CampaignMigrationContext: Sendable, Hashable, Codable {
    /// Live type-2 monument goal building IDs (`kind == .monument`,
    /// `values[0]`), including 85/86 for the Great Wall special arm.
    public var monumentGoalBuildingIDs: [Int]
    /// `DAT_01312214` current normal annual wage (baseline 30).
    public var normalAnnualWage: Int
    /// `DAT_01312630` consecutive debt **months** (factor uses /12 years).
    public var consecutiveDebtMonths: Int

    public init(
        monumentGoalBuildingIDs: [Int] = [],
        normalAnnualWage: Int = 30,
        consecutiveDebtMonths: Int = 0
    ) {
        self.monumentGoalBuildingIDs = monumentGoalBuildingIDs
        self.normalAnnualWage = max(0, normalAnnualWage)
        self.consecutiveDebtMonths = max(0, consecutiveDebtMonths)
    }
}

public struct DeterministicMigrationState: Sendable, Hashable, Codable {
    public private(set) var automaticMigrationAvailability: AutomaticMigrationAvailability
    public private(set) var lastAssessment: MigrationAssessment?
    public private(set) var lastDailyImmigrants: Int
    public private(set) var currentMonthImmigrants: Int
    public private(set) var lastMonthImmigrants: Int
    /// Live immigrant figures (model 11) en route to their houses. Empty while
    /// the producer is unsupported; persisted for save/replay.
    public private(set) var immigrantWalkers: [ImmigrantWalker]
    public private(set) var nextImmigrantWalkerID: Int
    /// Original `DAT_00D62418` wait-stagger word (§5.2): `+0x32` per spawn,
    /// `−0x33` (clamped) before each assignment day.
    public private(set) var immigrantWaitGlobal: Int
    /// Recovered popularity producer state (§2–§5).
    public private(set) var popularity: Int
    public private(set) var pressure: Int
    public private(set) var arrivalCooldown: Int
    public private(set) var departureCooldown: Int
    public private(set) var arrivalRequest: Int
    public private(set) var departureRequest: Int
    public private(set) var pendingArrival: Int
    public private(set) var pendingDeparture: Int
    public private(set) var unfulfilledArrivalCarry: Int
    public private(set) var assignedToday: Int
    public private(set) var assignedThisMonth: Int
    public private(set) var neverExceeded349: Bool
    /// `DAT_01312514` worst-factor blame index (1 food … 8 repression), for
    /// advisor reasons; 0 = none.
    public private(set) var factorBlame: Int

    public init(
        automaticMigrationAvailability: AutomaticMigrationAvailability = .unsupportedOriginalProducer,
        lastAssessment: MigrationAssessment? = nil,
        lastDailyImmigrants: Int = 0,
        currentMonthImmigrants: Int = 0,
        lastMonthImmigrants: Int = 0,
        immigrantWalkers: [ImmigrantWalker] = [],
        nextImmigrantWalkerID: Int = 1,
        immigrantWaitGlobal: Int = 0,
        popularity: Int = 60,
        pressure: Int = 0,
        arrivalCooldown: Int = 0,
        departureCooldown: Int = 0,
        arrivalRequest: Int = 0,
        departureRequest: Int = 0,
        pendingArrival: Int = 0,
        pendingDeparture: Int = 0,
        unfulfilledArrivalCarry: Int = 0,
        assignedToday: Int = 0,
        assignedThisMonth: Int = 0,
        neverExceeded349: Bool = false,
        factorBlame: Int = 0
    ) {
        self.automaticMigrationAvailability = automaticMigrationAvailability
        self.lastAssessment = lastAssessment
        self.lastDailyImmigrants = max(0, lastDailyImmigrants)
        self.currentMonthImmigrants = max(0, currentMonthImmigrants)
        self.lastMonthImmigrants = max(0, lastMonthImmigrants)
        self.immigrantWalkers = immigrantWalkers
        self.nextImmigrantWalkerID = max(1, nextImmigrantWalkerID)
        self.immigrantWaitGlobal = max(0, immigrantWaitGlobal)
        self.popularity = min(100, max(0, popularity))
        self.pressure = pressure
        self.arrivalCooldown = max(0, arrivalCooldown)
        self.departureCooldown = max(0, departureCooldown)
        self.arrivalRequest = max(0, arrivalRequest)
        self.departureRequest = max(0, departureRequest)
        self.pendingArrival = max(0, pendingArrival)
        self.pendingDeparture = max(0, pendingDeparture)
        self.unfulfilledArrivalCarry = max(0, unfulfilledArrivalCarry)
        self.assignedToday = max(0, assignedToday)
        self.assignedThisMonth = max(0, assignedThisMonth)
        self.neverExceeded349 = neverExceeded349
        self.factorBlame = max(0, factorBlame)
    }

    public mutating func recordUnsupportedDay(assessment: MigrationAssessment) {
        automaticMigrationAvailability = .unsupportedOriginalProducer
        lastAssessment = assessment
        lastDailyImmigrants = 0
        currentMonthImmigrants = 0
        lastMonthImmigrants = 0
    }

    public mutating func finishMonth() {
        lastDailyImmigrants = 0
        currentMonthImmigrants = 0
        lastMonthImmigrants = 0
    }

    /// Original `FUN_004AD4A0` pre-assignment stagger decrement
    /// (`DAT_00D62418 -= 0x33`, clamped at 0; §5.2).
    public mutating func advanceImmigrantWaitGlobal() {
        immigrantWaitGlobal = max(0, immigrantWaitGlobal - 0x33)
    }

    /// Advances live immigrants by one Native day's original-step budget and
    /// returns the arrivals the city must apply.
    public mutating func advanceImmigrantWalkers(
        originalStepsInDay: Int
    ) -> [ImmigrantArrival] {
        DeterministicMigration.advanceImmigrants(
            walkers: &immigrantWalkers,
            originalStepsInDay: originalStepsInDay
        )
    }

    /// Appends a spawned immigrant and applies the original
    /// `DAT_00D62418 += 0x32` stagger increment (§5.2).
    public mutating func registerImmigrantWalker(_ walker: ImmigrantWalker) {
        immigrantWalkers.append(walker)
        nextImmigrantWalkerID = max(nextImmigrantWalkerID, walker.id + 1)
        immigrantWaitGlobal += 0x32
    }

    // MARK: - Producer state mutators

    public mutating func setNeverExceeded349() {
        neverExceeded349 = true
    }

    public mutating func setPopularity(_ value: Int) {
        popularity = min(100, max(0, value))
    }

    public mutating func setPressure(_ value: Int) {
        pressure = value
    }

    public mutating func setArrivalCooldown(_ value: Int) {
        arrivalCooldown = max(0, value)
    }

    public mutating func setDepartureCooldown(_ value: Int) {
        departureCooldown = max(0, value)
    }

    public mutating func setArrivalRequest(_ value: Int) {
        arrivalRequest = max(0, value)
    }

    public mutating func setDepartureRequest(_ value: Int) {
        departureRequest = max(0, value)
    }

    public mutating func setPendingArrival(_ value: Int) {
        pendingArrival = max(0, value)
    }

    public mutating func setPendingDeparture(_ value: Int) {
        pendingDeparture = max(0, value)
    }

    public mutating func setUnfulfilledArrivalCarry(_ value: Int) {
        unfulfilledArrivalCarry = max(0, value)
    }

    public mutating func setAssignedToday(_ value: Int) {
        assignedToday = max(0, value)
    }

    public mutating func addAssignedThisMonth(_ value: Int) {
        assignedThisMonth = max(0, assignedThisMonth + value)
    }

    public mutating func recordArrivals(count: Int) {
        guard count > 0 else { return }
        lastDailyImmigrants += count
        currentMonthImmigrants += count
    }

    public mutating func setFactorBlame(_ value: Int) {
        factorBlame = max(0, value)
    }

    public mutating func setAutomaticMigrationAvailability(
        _ availability: AutomaticMigrationAvailability
    ) {
        automaticMigrationAvailability = availability
    }

    private enum CodingKeys: String, CodingKey {
        case automaticMigrationAvailability
        case lastAssessment
        case lastDailyImmigrants
        case currentMonthImmigrants
        case lastMonthImmigrants
        case immigrantWalkers
        case nextImmigrantWalkerID
        case immigrantWaitGlobal
        case popularity, pressure, arrivalCooldown, departureCooldown
        case arrivalRequest, departureRequest, pendingArrival, pendingDeparture
        case unfulfilledArrivalCarry, assignedToday, assignedThisMonth
        case neverExceeded349, factorBlame
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        automaticMigrationAvailability = try container.decodeIfPresent(
            AutomaticMigrationAvailability.self,
            forKey: .automaticMigrationAvailability
        ) ?? .unsupportedOriginalProducer
        lastAssessment = try container.decodeIfPresent(
            MigrationAssessment.self,
            forKey: .lastAssessment
        )
        lastDailyImmigrants = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .lastDailyImmigrants) ?? 0
        )
        currentMonthImmigrants = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .currentMonthImmigrants) ?? 0
        )
        lastMonthImmigrants = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .lastMonthImmigrants) ?? 0
        )
        immigrantWalkers = try container.decodeIfPresent(
            [ImmigrantWalker].self,
            forKey: .immigrantWalkers
        ) ?? []
        nextImmigrantWalkerID = max(
            1,
            try container.decodeIfPresent(Int.self, forKey: .nextImmigrantWalkerID) ?? 1
        )
        immigrantWaitGlobal = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .immigrantWaitGlobal) ?? 0
        )
        popularity = min(
            100,
            max(0, try container.decodeIfPresent(Int.self, forKey: .popularity) ?? 60)
        )
        pressure = try container.decodeIfPresent(Int.self, forKey: .pressure) ?? 0
        arrivalCooldown = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .arrivalCooldown) ?? 0
        )
        departureCooldown = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .departureCooldown) ?? 0
        )
        arrivalRequest = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .arrivalRequest) ?? 0
        )
        departureRequest = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .departureRequest) ?? 0
        )
        pendingArrival = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .pendingArrival) ?? 0
        )
        pendingDeparture = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .pendingDeparture) ?? 0
        )
        unfulfilledArrivalCarry = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .unfulfilledArrivalCarry) ?? 0
        )
        assignedToday = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .assignedToday) ?? 0
        )
        assignedThisMonth = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .assignedThisMonth) ?? 0
        )
        neverExceeded349 = try container.decodeIfPresent(
            Bool.self,
            forKey: .neverExceeded349
        ) ?? false
        factorBlame = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .factorBlame) ?? 0
        )
    }
}

public enum DeterministicMigration {
    /// Recovered land-entry flood pass mask (`FUN_005AE240`, §10.4):
    /// `0x4 | 0x8 | 0x10 | 0x20 | 0x40 | 0x100 | 0x200 | 0x800`. Against the
    /// recovered primary-cache write domain, the effectively produced pass
    /// bits are road `0x4`, bare/elevation land `0x10`/`0x20`, road-on-
    /// elevation `0x100`, and ferry links `0x200`/`0x800` (`0x8`/`0x40` have
    /// no producer in the canonical build).
    public static let landEntryFloodPassMask: UInt16 = 0xB7C

    /// Observes Native road-adjacent vacant housing without inventing
    /// arrivals, departures, popularity, or restriction reasons. This filter
    /// is not a recovered mapping of original `house+0x24`.
    public static func observeHousing(
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        models: BuildingModelTable
    ) -> MigrationAssessment {
        let eligible = houses
            .filter { house in
                guard let location = house.location,
                      house.residents < house.capacity(using: models) else { return false }
                let buildingID = house.houseLevelID + 3
                let footprint = OriginalBuildingFootprintCatalog
                    .footprint(forBuildingID: buildingID)
                    ?? BuildingFootprint(width: 1, height: 1)
                let occupied = Set(footprint.points(at: location))
                return footprint.points(at: location)
                    .flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
                    .contains {
                        !occupied.contains($0) && roadNetwork.contains($0)
                    }
            }
            .sorted { $0.id < $1.id }
        let availableCapacity = eligible.reduce(0) {
            $0 + max(0, $1.capacity(using: models) - $1.residents)
        }
        return MigrationAssessment(
            eligibleHouseIDs: eligible.map(\.id),
            availableCapacity: availableCapacity,
            unemploymentPercent: 0,
            plannedImmigrants: 0,
            blockReason: nil
        )
    }

    /// Original land-entry flood (`FUN_005AE140` → `FUN_005AE240`, §10.4):
    /// 4-neighbour expansion in N/E/S/W order from the authored land entry;
    /// a neighbour passes iff its **own** main derived cache word has a
    /// nonzero intersection with `landEntryFloodPassMask`; depths are
    /// `n+1`; unreached cells stay `nil`. This is the recovered source of
    /// original `house+0x24` (reachability from the immigrant entry road),
    /// not a road-adjacency test.
    public static func landEntryFloodDepths(
        width: Int,
        height: Int,
        primaryPassability: [UInt16],
        seed: GridPoint
    ) -> [Int?] {
        guard width > 0, height > 0,
              primaryPassability.count == width * height,
              seed.x >= 0, seed.x < width,
              seed.y >= 0, seed.y < height else {
            return []
        }
        var depths = [Int?](repeating: nil, count: width * height)
        var queue: [GridPoint] = [seed]
        var head = 0
        depths[seed.y * width + seed.x] = 1
        let directions: [(dx: Int, dy: Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        while head < queue.count {
            let point = queue[head]
            head += 1
            let nextDepth = (depths[point.y * width + point.x] ?? 0) + 1
            for direction in directions {
                let next = GridPoint(
                    x: point.x + direction.dx,
                    y: point.y + direction.dy
                )
                guard next.x >= 0, next.x < width,
                      next.y >= 0, next.y < height else {
                    continue
                }
                let index = next.y * width + next.x
                guard depths[index] == nil,
                      primaryPassability[index] & Self.landEntryFloodPassMask != 0 else {
                    continue
                }
                depths[index] = nextDepth
                queue.append(next)
            }
        }
        return depths
    }

    /// Native-day bridge: the original month is 816 simulation steps split
    /// across the 30-day compatibility clock as
    /// `floor(day×816/30) − floor((day−1)×816/30)` (27/28 alternating).
    public static func originalStepsInDay(_ day: Int) -> Int {
        let clamped = max(1, day)
        return clamped * ImmigrantWalker.originalStepsPerMonth
            / ImmigrantWalker.nativeDaysPerMonth
            - (clamped - 1) * ImmigrantWalker.originalStepsPerMonth
                / ImmigrantWalker.nativeDaysPerMonth
    }

    /// Deterministic road access point for a house footprint, mirroring the
    /// placement rule (`adjacentRoadPoints` row-major first).
    public static func houseRoadAccessPoint(
        houseLocation: GridPoint,
        vacantBuildingID: Int,
        roadNetwork: RoadNetwork
    ) -> GridPoint? {
        let footprint = OriginalBuildingFootprintCatalog
            .footprint(forBuildingID: vacantBuildingID)
            ?? BuildingFootprint(width: 2, height: 2)
        let occupied = footprint.points(at: houseLocation)
        return Set(occupied.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)))
            .subtracting(occupied)
            .filter(roadNetwork.contains)
            .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            .first
    }

    /// Creates a physical immigrant figure en route to `destination` (the
    /// house road access point). Route uses the recovered mode-1 + mode-19
    /// worker pathfinding; nil means no route exists (fail-closed).
    public static func spawnImmigrant(
        id: Int,
        houseID: Int,
        peopleCount: Int,
        entryPoint: GridPoint,
        destination: GridPoint,
        waitSteps: Int,
        primaryValues: [UInt16],
        fallbackValues: [UInt32],
        width: Int,
        height: Int
    ) -> ImmigrantWalker? {
        guard let route = OriginalGrandCanalLayoutCatalog.workerRoute(
            primaryValues: primaryValues,
            fallbackValues: fallbackValues,
            width: width,
            height: height,
            from: entryPoint,
            to: destination
        ) else {
            return nil
        }
        guard route.points.count > 0 else { return nil }
        return ImmigrantWalker(
            id: id,
            houseID: houseID,
            peopleCount: peopleCount,
            entryPoint: entryPoint,
            route: route.points,
            waitSteps: waitSteps
        )
    }

    /// Advances every live immigrant by one Native day's original-step budget,
    /// returning the arrivals that must be applied by the city. Walkers that
    /// have not arrived yet survive.
    public static func advanceImmigrants(
        walkers: inout [ImmigrantWalker],
        originalStepsInDay: Int
    ) -> [ImmigrantArrival] {
        var arrivals: [ImmigrantArrival] = []
        var remaining: [ImmigrantWalker] = []
        for var walker in walkers {
            var arrived = false
            for _ in 0..<max(0, originalStepsInDay) {
                if walker.advanceOneUpdate() {
                    arrivals.append(ImmigrantArrival(
                        houseID: walker.houseID,
                        peopleCount: walker.peopleCount
                    ))
                    arrived = true
                    break
                }
            }
            if !arrived {
                remaining.append(walker)
            }
        }
        walkers = remaining
        return arrivals
    }

    // MARK: - Popularity / pressure / request factors (§2–§4)

    /// Recovered wage-effect table (§3): nearest threshold, ties keep the
    /// first index; baseline wage 30 → effect 0.
    public static func wageEffect(currentWage: Int) -> Int {
        let thresholds = [0, 20, 26, 30, 34, 40]
        let effects = [-10, -5, -2, 0, 2, 4]
        var bestIndex = 0
        var bestDistance = Int.max
        for (index, threshold) in thresholds.enumerated() {
            let distance = abs(currentWage - threshold)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return effects[bestIndex]
    }

    /// Recovered employment bands (§3): `unemployed × 100 / workforce`.
    public static func employmentEffect(unemploymentPercent: Int) -> Int {
        if unemploymentPercent < 5 { return 1 }
        if unemploymentPercent <= 10 { return 0 }
        if unemploymentPercent <= 17 { return -1 }
        if unemploymentPercent <= 25 { return -2 }
        return -3
    }

    /// Recovered debt factor (§3): consecutive debt years plus `−2` when the
    /// treasury is negative.
    public static func debtEffect(debtYears: Int, treasuryIsNegative: Bool) -> Int {
        (treasuryIsNegative ? -2 : 0) + debtYears
    }

    /// Recovered feng-shui bands (§3): population below 351 contributes 0;
    /// otherwise harmony percent bands.
    public static func fengShuiEffect(population: Int, harmonyPercent: Int) -> Int {
        guard population >= 351 else { return 0 }
        if harmonyPercent >= 100 { return 2 }
        if harmonyPercent >= 90 { return 1 }
        if harmonyPercent >= 80 { return 0 }
        if harmonyPercent >= 70 { return -1 }
        if harmonyPercent >= 60 { return -2 }
        if harmonyPercent >= 50 { return -3 }
        if harmonyPercent >= 40 { return -4 }
        return -5
    }

    /// Recovered repression factor (§3): Watchtower (#127) count; active only
    /// when population > 350 and `population <= count×500`.
    public static func repressionEffect(population: Int, watchtowerCount: Int) -> Int {
        guard population > 350, watchtowerCount > 0,
              population <= watchtowerCount * 500 else { return 0 }
        return -min(4, (watchtowerCount * 500) / population)
    }

    /// Recovered pressure bands (§4).
    public static func pressureBand(popularity: Int) -> Int {
        let clamped = min(100, max(0, popularity))
        if clamped < 16 { return -25 }
        if clamped <= 25 { return -17 }
        if clamped <= 35 { return -8 }
        if clamped <= 49 { return 0 }
        if clamped <= 60 { return 50 }
        if clamped <= 70 { return 75 }
        return 100
    }

    /// `ceil(12 × |pressure| / 100)` (§4).
    public static func requestSize(forAbsolutePressure pressure: Int) -> Int {
        (12 * max(0, pressure) + 99) / 100
    }

    /// Recovered popularity damping and apply branches (§2).
    public static func dampedPopularityDelta(current: Int, factorSum: Int) -> Int {
        let bias: Int
        if current < 0x0B { bias = 4 }
        else if current < 0x15 { bias = 3 }
        else if current < 0x1F { bias = 2 }
        else if current < 0x29 { bias = 1 }
        else if current < 0x3D { bias = 0 }
        else if current < 0x47 { bias = -1 }
        else if current < 0x51 { bias = -2 }
        else { bias = current < 0x5B ? -3 : -4 }
        if current < 0x29 {
            if factorSum >= 0 { return factorSum }
            let biased = bias + factorSum
            return biased > 0 ? 0 : biased
        }
        if current < 0x3D || factorSum < 0 { return factorSum }
        let biased = bias + factorSum
        return biased < 0 ? 0 : biased
    }

    /// Monument factor term (§10.8): `2 ×` matching (complete root, type-2
    /// goal) pairs. `goalBuildingIDs` are the live `kind == .monument` goal
    /// values; `completeRootBuildingIDs` are Native's completed monument
    /// roots (legacy, phased 77/84, palace 82, canal 83, wall layouts
    /// 253…268).
    public static func monumentPopularityTerm(
        goalBuildingIDs: [Int],
        completeRootBuildingIDs: Set<Int>
    ) -> Int {
        var pairs = 0
        for goalID in goalBuildingIDs {
            if goalID == 85 || goalID == 86 {
                pairs += completeRootBuildingIDs.intersection(253...268).count
            } else if completeRootBuildingIDs.contains(goalID) {
                pairs += 1
            }
        }
        return pairs * 2
    }
}
