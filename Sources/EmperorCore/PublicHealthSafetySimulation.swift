import Foundation

public struct HouseHealthSafetyRecord: Sendable, Hashable, Codable {
    public let houseID: Int
    public var diseaseRisk: Int
    public var crimeRisk: Int

    public init(houseID: Int, diseaseRisk: Int = 0, crimeRisk: Int = 0) {
        self.houseID = houseID
        self.diseaseRisk = max(0, diseaseRisk)
        self.crimeRisk = max(0, crimeRisk)
    }
}

public enum HouseHealthSafetyEventKind: String, Sendable, Hashable, Codable {
    case diseaseOutbreak
    case theft
}

public struct HouseHealthSafetyEvent: Sendable, Hashable, Codable {
    public let houseID: Int
    public let kind: HouseHealthSafetyEventKind
    public let affectedResidents: Int
    public let cashLoss: Int
}

public struct PublicHealthSafetyMonthlySettlement: Sendable, Hashable, Codable {
    public let year: Int
    public let month: Int
    public let events: [HouseHealthSafetyEvent]
    public let diseaseDeaths: Int
    public let stolenCash: Int
    public let medicallyCoveredHouseIDs: Set<Int>
    public let protectedHouseIDs: Set<Int>
}

/// Field-level reproduction of the recovered `cHouseInfo` health aggregate.
/// The executable stores these inputs as bytes at offsets `+0x2A`, `+0x2B`,
/// `+0x2C`, `+0x2D`, `+0x2E`, `+0x32`, `+0x34`, and `+0x36`; no Native
/// provider/object projection is implied by this value type.
public enum OriginalHouseHealthAggregate {
    /// `FUN_00545100` maps the raw food-quality byte to its five contribution
    /// buckets. Values at or below each boundary stay in the lower bucket;
    /// zero contributes no points.
    public static func foodQualityBucket(_ rawQuality: Int) -> Int {
        let byte = Int(UInt8(truncatingIfNeeded: rawQuality))
        if byte > 0x59 { return 5 }
        if byte > 0x45 { return 4 }
        if byte > 0x31 { return 3 }
        if byte > 0x1D { return 2 }
        return byte > 0 ? 1 : 0
    }

    /// Rebuilds `cHouseInfo +0x38` exactly as `FUN_00517330`.
    /// `+0x34` takes precedence over `+0x32`; all remaining contributions are
    /// additive and use non-zero byte tests.
    public static func healthScore(
        field2A: Int,
        field2D: Int,
        field32: Int,
        field34: Int,
        foodQualityRaw: Int
    ) -> Int {
        var score = field34 != 0 ? 15 : (field32 != 0 ? 5 : 0)
        if field2D != 0 { score += 30 }
        if field2A != 0 { score += 15 }
        score += [0, 10, 20, 30, 35, 40][foodQualityBucket(foodQualityRaw)]
        return score
    }

    /// Rebuilds the separate goods byte `cHouseInfo +0x37` as
    /// `FUN_005173E0`: each non-zero service byte contributes 33 points.
    public static func goodsScore(field2B: Int, field2C: Int, field2E: Int) -> Int {
        [field2B, field2C, field2E].reduce(0) { $0 + ($1 != 0 ? 33 : 0) }
    }

    /// Reproduces `FUN_00518D10`'s signed-population scaling and its minimum
    /// positive result. The caller supplies the already-rebuilt score because
    /// the original `+0x1E4` cHouseInfo getter is not mapped to Native.
    public static func populationScaledContribution(
        score: Int,
        population: Int
    ) -> Int {
        let signedPopulation = Int(Int16(truncatingIfNeeded: population))
        let scaled = score * signedPopulation / 100
        if scaled == 0, score > 0, signedPopulation > 0 { return 1 }
        return scaled
    }
}

/// Result of the city-level natural-health aggregate recovered at
/// `FUN_00518490 @ 0x518490`.  The executable receives the already-aggregated
/// signed population and the sum of each eligible house's
/// `+0x214` population-scaled contribution; it then applies a low-population
/// correction and an explicit difficulty/cheat bonus before capping only the
/// upper bound at 100.  The source of the bonus flag and the live cHouseInfo
/// object projection are intentionally not inferred here.
public struct OriginalNaturalHealthAggregateResult: Sendable, Hashable, Codable {
    public let totalPopulation: Int
    public let weightedHealthSum: Int
    public let populationCorrection: Int
    public let bonus: Int
    public let naturalHealth: Int

    public init(
        totalPopulation: Int,
        weightedHealthSum: Int,
        populationCorrection: Int,
        bonus: Int,
        naturalHealth: Int
    ) {
        self.totalPopulation = totalPopulation
        self.weightedHealthSum = weightedHealthSum
        self.populationCorrection = populationCorrection
        self.bonus = bonus
        self.naturalHealth = naturalHealth
    }
}

/// Pure city-level arithmetic from `FUN_00518490 @ 0x518490`.
public enum OriginalNaturalHealthAggregate {
    public static let lowPopulationThreshold = 1_000
    public static let lowPopulationDivisor = 10
    public static let bonusValue = 10
    public static let upperBound = 100

    /// Computes the raw natural-health result from source-width aggregates.
    /// A non-positive population follows the executable's terminal `100`
    /// return.  For positive population the weighted average is integer
    /// division toward zero; the low-population correction and optional bonus
    /// are then added, and only values at or above 100 are clamped.  Inputs
    /// are explicit because the source's cHouseInfo enumeration and
    /// `FUN_005A8420(6)` bonus producer are not mapped to Native.
    public static func aggregate(
        totalPopulation: Int,
        weightedHealthSum: Int,
        bonusEnabled: Bool
    ) -> OriginalNaturalHealthAggregateResult {
        guard totalPopulation > 0 else {
            return .init(
                totalPopulation: totalPopulation,
                weightedHealthSum: weightedHealthSum,
                populationCorrection: 0,
                bonus: 0,
                naturalHealth: upperBound
            )
        }

        let correction = totalPopulation < lowPopulationThreshold
            ? (lowPopulationThreshold - totalPopulation) / lowPopulationDivisor
            : 0
        let bonus = bonusEnabled ? bonusValue : 0
        let average = (weightedHealthSum * 100) / totalPopulation
        let raw = average + correction + bonus
        return .init(
            totalPopulation: totalPopulation,
            weightedHealthSum: weightedHealthSum,
            populationCorrection: correction,
            bonus: bonus,
            naturalHealth: min(raw, upperBound)
        )
    }
}

/// Pure monthly population plan recovered from `FUN_00590E00 @ 0x590E00`.
///
/// `FUN_004AD4A0` calls this branch only after `DAT_01311FA4` has been set by
/// the monthly health refresh. The branch scales the current city population
/// by a health-dependent percentage (`FUN_00408B80`) and then either removes
/// or adds that many residents through the lower-class selector (`param_2=0`)
/// in `FUN_00517E90`/`FUN_004ADFB0`. The Native house-health fields and their
/// live projection are not recovered, so this value type is research-only and
/// is intentionally not consumed by `CitySimulation`.
public struct OriginalNaturalHealthPopulationPlan: Sendable, Hashable, Codable {
    public enum Direction: String, Sendable, Hashable, Codable {
        case none
        case removeLowerClassResidents
        case addLowerClassResidents
    }

    public let naturalHealth: Int
    public let ratePercent: Int
    public let requestedResidents: Int
    public let direction: Direction

    public init(
        naturalHealth: Int,
        ratePercent: Int,
        requestedResidents: Int,
        direction: Direction
    ) {
        self.naturalHealth = naturalHealth
        self.ratePercent = ratePercent
        self.requestedResidents = requestedResidents
        self.direction = direction
    }
}

public enum OriginalNaturalHealthPopulationAdjustment {
    /// Reproduces the health interval table and signed integer population
    /// scaling from `FUN_00590E00`. The caller's `DAT_0130F97C` display value
    /// is clamped to `0…100` by `FUN_00590D40`; this helper preserves the
    /// source branch shape for values outside that range as well.
    public static func plan(
        naturalHealth: Int,
        currentPopulation: Int
    ) -> OriginalNaturalHealthPopulationPlan {
        let rate: Int
        let direction: OriginalNaturalHealthPopulationPlan.Direction
        switch naturalHealth {
        case ..<1:
            rate = 0
            direction = .none
        case 1..<11:
            rate = -5
            direction = .removeLowerClassResidents
        case 11..<21:
            rate = -3
            direction = .removeLowerClassResidents
        case 21..<31:
            rate = -2
            direction = .removeLowerClassResidents
        case 31..<41:
            rate = -1
            direction = .removeLowerClassResidents
        case 41..<51:
            rate = 1
            direction = .addLowerClassResidents
        case 51..<61:
            rate = 2
            direction = .addLowerClassResidents
        case 61..<71:
            rate = 3
            direction = .addLowerClassResidents
        case 71..<81:
            rate = 4
            direction = .addLowerClassResidents
        default:
            rate = 6
            direction = .addLowerClassResidents
        }

        // `FUN_00408B80` is `(population * rate) / 100`; Swift integer
        // division has the same toward-zero behavior as the recovered C.
        let requestedResidents = currentPopulation.multipliedReportingOverflow(by: abs(rate))
        let scaled = requestedResidents.overflow
            ? 0
            : requestedResidents.partialValue / 100
        return OriginalNaturalHealthPopulationPlan(
            naturalHealth: naturalHealth,
            ratePercent: rate,
            requestedResidents: scaled,
            direction: direction
        )
    }
}

/// One already-resolved house input for `FUN_004ADFB0 @ 0x4ADFB0`.
/// `vectorIndex` is the executable's one-based live-object index;
/// `passesGlobalAndHouseGate` combines the global active check and the house
/// vtable `+0xB8` result. `gateWord24` is the positive raw `house+0x24`
/// prerequisite. `availableResidentCapacity` is the caller-supplied result
/// of model column `0x11` minus the current signed resident word; keeping it
/// explicit avoids inventing a Native model/object projection here.
public struct OriginalNaturalHealthPopulationHouse: Sendable, Hashable, Codable {
    public let vectorIndex: Int
    public let passesGlobalAndHouseGate: Bool
    public let classPredicate: Bool
    public let gateWord24: Int
    public let availableResidentCapacity: Int

    public init(
        vectorIndex: Int,
        passesGlobalAndHouseGate: Bool,
        classPredicate: Bool,
        gateWord24: Int,
        availableResidentCapacity: Int
    ) {
        self.vectorIndex = vectorIndex
        self.passesGlobalAndHouseGate = passesGlobalAndHouseGate
        self.classPredicate = classPredicate
        self.gateWord24 = gateWord24
        self.availableResidentCapacity = availableResidentCapacity
    }
}

public struct OriginalNaturalHealthPopulationAssignment: Sendable, Hashable, Codable {
    public let vectorIndex: Int
    public let peopleCount: Int

    public init(vectorIndex: Int, peopleCount: Int) {
        self.vectorIndex = vectorIndex
        self.peopleCount = peopleCount
    }
}

public struct OriginalNaturalHealthPopulationAssignmentPlan: Sendable, Hashable, Codable {
    public let assignments: [OriginalNaturalHealthPopulationAssignment]
    public let appliedResidents: Int
    public let remainingRequest: Int
    public let nextCursor: Int

    public init(
        assignments: [OriginalNaturalHealthPopulationAssignment],
        appliedResidents: Int,
        remainingRequest: Int,
        nextCursor: Int
    ) {
        self.assignments = assignments
        self.appliedResidents = appliedResidents
        self.remainingRequest = remainingRequest
        self.nextCursor = nextCursor
    }
}

/// Pure one-pass reproduction of `FUN_004ADFB0 @ 0x4ADFB0`.
///
/// The source clamps its persistent cursor with `FUN_00445480` to
/// `0…vectorCount−1`, then advances before each lookup, wraps to index `1`,
/// and performs exactly `vectorCount` lookup iterations unless the request is
/// exhausted. (The source's index-0 skip means the final iteration can revisit
/// index `1`; this is preserved.) `classSelectorIsUpper`
/// represents the source's `param_2`: zero selects a false class predicate
/// (the lower-class path used by natural health), while any non-zero value
/// selects a true predicate. The returned cursor changes only after an actual
/// resident write, matching the source's `DAT_01311FA8` update.
public enum OriginalNaturalHealthPopulationDistributor {
    public static func plan(
        request: Int,
        classSelectorIsUpper: Bool,
        startCursor: Int,
        vectorCount: Int,
        houses: [OriginalNaturalHealthPopulationHouse]
    ) -> OriginalNaturalHealthPopulationAssignmentPlan {
        guard request > 0, vectorCount > 1 else {
            let cursor = min(max(startCursor, 0), max(0, vectorCount - 1))
            return .init(
                assignments: [],
                appliedResidents: 0,
                remainingRequest: max(0, request),
                nextCursor: cursor
            )
        }

        let initialCursor = min(max(startCursor, 0), vectorCount - 1)
        var cursor = initialCursor
        var storedCursor = initialCursor
        var remaining = request
        var assignments: [OriginalNaturalHealthPopulationAssignment] = []

        for _ in 0..<vectorCount {
            guard remaining > 0 else { break }
            cursor += 1
            if cursor >= vectorCount {
                cursor = 1
            }

            guard let house = houses.first(where: { $0.vectorIndex == cursor }),
                  house.passesGlobalAndHouseGate,
                  house.gateWord24 > 0,
                  house.classPredicate == classSelectorIsUpper,
                  house.availableResidentCapacity > 0 else {
                continue
            }

            let amount = min(remaining, house.availableResidentCapacity)
            assignments.append(.init(vectorIndex: cursor, peopleCount: amount))
            remaining -= amount
            storedCursor = cursor
        }

        return .init(
            assignments: assignments,
            appliedResidents: request - remaining,
            remainingRequest: remaining,
            nextCursor: storedCursor
        )
    }
}

/// One already-resolved house input for `FUN_00517E90 @ 0x517E90`.
/// The source removes exactly one resident per successful lookup, so
/// `residentCount` is the signed resident word tested at `house+0x20`.
/// `passesGlobalAndHouseGate` and `classPredicate` have the same source
/// meanings as `OriginalNaturalHealthPopulationHouse`.
public struct OriginalNaturalHealthPopulationRemovalHouse: Sendable, Hashable, Codable {
    public let vectorIndex: Int
    public let passesGlobalAndHouseGate: Bool
    public let classPredicate: Bool
    public let residentCount: Int

    public init(
        vectorIndex: Int,
        passesGlobalAndHouseGate: Bool,
        classPredicate: Bool,
        residentCount: Int
    ) {
        self.vectorIndex = vectorIndex
        self.passesGlobalAndHouseGate = passesGlobalAndHouseGate
        self.classPredicate = classPredicate
        self.residentCount = residentCount
    }
}

public struct OriginalNaturalHealthPopulationRemovalAssignment: Sendable, Hashable, Codable {
    public let vectorIndex: Int
    public let peopleCount: Int

    public init(vectorIndex: Int, peopleCount: Int = 1) {
        self.vectorIndex = vectorIndex
        self.peopleCount = peopleCount
    }
}

public struct OriginalNaturalHealthPopulationRemovalPlan: Sendable, Hashable, Codable {
    public let assignments: [OriginalNaturalHealthPopulationRemovalAssignment]
    public let removedResidents: Int
    public let remainingRequest: Int
    public let nextCursor: Int

    public init(
        assignments: [OriginalNaturalHealthPopulationRemovalAssignment],
        removedResidents: Int,
        remainingRequest: Int,
        nextCursor: Int
    ) {
        self.assignments = assignments
        self.removedResidents = removedResidents
        self.remainingRequest = remainingRequest
        self.nextCursor = nextCursor
    }
}

/// Explicit-input reproduction of `FUN_00517E90 @ 0x517E90`.
///
/// The EN PE body has two source scans. The first starts at the clamped
/// persistent cursor and repeats a full vector scan while at least one write
/// succeeds. If that stage leaves work requested, the second stage clamps the
/// cursor again and performs the same scan. `FUN_004F8210` between scans only
/// returns a context field; it does not mutate the candidate inputs represented
/// here, so the second stage is retained for source shape but cannot discover
/// a new candidate without a recovered Native refresh hook. Every successful
/// source write decrements one positive resident word and stores that vector
/// index back to the persistent cursor. `param_2 == 0` selects the false class
/// predicate (the lower-class natural-health path).
public enum OriginalNaturalHealthPopulationRemovalPlanner {
    public static func plan(
        request: Int,
        classSelectorIsUpper: Bool,
        startCursor: Int,
        vectorCount: Int,
        houses: [OriginalNaturalHealthPopulationRemovalHouse]
    ) -> OriginalNaturalHealthPopulationRemovalPlan {
        guard request > 0, vectorCount > 1 else {
            let cursor = min(max(startCursor, 0), max(0, vectorCount - 1))
            return .init(
                assignments: [],
                removedResidents: 0,
                remainingRequest: max(0, request),
                nextCursor: cursor
            )
        }

        let initialCursor = min(max(startCursor, 0), vectorCount - 1)
        var cursor = initialCursor
        var storedCursor = initialCursor
        var remaining = request
        var assignments: [OriginalNaturalHealthPopulationRemovalAssignment] = []
        var residentCounts = Dictionary(uniqueKeysWithValues: houses.map {
            ($0.vectorIndex, $0.residentCount)
        })

        func scan(
            cursor: inout Int,
            storedCursor: inout Int,
            remaining: inout Int,
            assignments: inout [OriginalNaturalHealthPopulationRemovalAssignment],
            residentCounts: inout [Int: Int]
        ) -> Bool {
            var wrote = false
            for _ in 0..<vectorCount {
                guard remaining > 0 else { break }
                cursor += 1
                if cursor >= vectorCount { cursor = 1 }
                guard let house = houses.first(where: { $0.vectorIndex == cursor }),
                      house.passesGlobalAndHouseGate,
                      house.classPredicate == classSelectorIsUpper,
                      (residentCounts[cursor] ?? house.residentCount) > 0 else {
                    continue
                }
                assignments.append(.init(vectorIndex: cursor))
                residentCounts[cursor, default: house.residentCount] -= 1
                remaining -= 1
                storedCursor = cursor
                wrote = true
            }
            return wrote
        }

        while remaining > 0, scan(
            cursor: &cursor,
            storedCursor: &storedCursor,
            remaining: &remaining,
            assignments: &assignments,
            residentCounts: &residentCounts
        ) {}

        if remaining > 0 {
            cursor = min(max(storedCursor, 0), vectorCount - 1)
            while remaining > 0, scan(
                cursor: &cursor,
                storedCursor: &storedCursor,
                remaining: &remaining,
                assignments: &assignments,
                residentCounts: &residentCounts
            ) {}
        }

        return .init(
            assignments: assignments,
            removedResidents: request - remaining,
            remainingRequest: remaining,
            nextCursor: storedCursor
        )
    }
}

/// Compatibility shell for the unresolved residential incident producer.
///
/// The executable corpus currently closes the health aggregate and its
/// service-timer refresh, but not the disease/crime incident selector or its
/// resident, inventory, treasury, and event-message side effects. Until that
/// producer is recovered, the live path is deliberately fail-closed: legacy
/// records remain decodable, while `advanceMonth` emits no synthetic events
/// and mutates no city inputs.
public struct DeterministicPublicHealthSafetyState: Sendable, Hashable, Codable {
    /// The original incident producer is not yet represented in Native.
    public static let supportsRecoveredOriginalIncidents = false

    public private(set) var records: [HouseHealthSafetyRecord]
    public private(set) var lastSettlement: PublicHealthSafetyMonthlySettlement?

    public init() {
        records = []
        lastSettlement = nil
    }

    @discardableResult
    public mutating func advanceMonth(
        calendar: SimulationCalendar,
        houses: inout [ResidentialUnit],
        models: BuildingModelTable
    ) -> PublicHealthSafetyMonthlySettlement {
        let settlement = PublicHealthSafetyMonthlySettlement(
            year: calendar.year,
            month: calendar.month,
            events: [],
            diseaseDeaths: 0,
            stolenCash: 0,
            medicallyCoveredHouseIDs: [],
            protectedHouseIDs: []
        )
        lastSettlement = settlement
        return settlement
    }
}
