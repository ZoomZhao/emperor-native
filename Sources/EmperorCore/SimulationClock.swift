import Foundation

/// Saveable sub-month clock used by every live city simulation.
///
/// One simulation tick is one game day. Calendar months remain the original
/// fixed twelve months, with thirty deterministic simulation days per month.
public struct SimulationClockState: Sendable, Hashable, Codable {
    public static let daysPerMonth = 30

    public private(set) var day: Int
    public private(set) var tickSequence: UInt64

    public init(day: Int = 1, tickSequence: UInt64 = 0) {
        self.day = min(max(day, 1), Self.daysPerMonth)
        self.tickSequence = tickSequence
    }

    @discardableResult
    public mutating func advanceOneDay() -> SimulationClockAdvance {
        let elapsedDay = day
        tickSequence &+= 1
        let didEndMonth = day == Self.daysPerMonth
        day = didEndMonth ? 1 : day + 1
        return SimulationClockAdvance(
            tickSequence: tickSequence,
            elapsedDay: elapsedDay,
            currentDay: day,
            didEndMonth: didEndMonth
        )
    }
}

public struct SimulationClockAdvance: Sendable, Hashable, Codable {
    public let tickSequence: UInt64
    public let elapsedDay: Int
    public let currentDay: Int
    public let didEndMonth: Bool
}

/// Service visits accumulated since the start of the current simulation month.
/// Optional storage on the city keeps saves written before the day clock valid.
public struct MonthlyServiceCoverageAccumulator: Sendable, Equatable, Codable {
    public private(set) var servicedHouseIDsByService: [WalkerServiceKind: Set<Int>]

    public init(servicedHouseIDsByService: [WalkerServiceKind: Set<Int>] = [:]) {
        self.servicedHouseIDsByService = servicedHouseIDsByService
    }

    public var isEmpty: Bool { servicedHouseIDsByService.values.allSatisfy(\.isEmpty) }

    public mutating func merge(_ movement: WalkerMovementSummary) {
        for (service, houseIDs) in movement.servicedHouseIDsByService {
            servicedHouseIDsByService[service, default: []].formUnion(houseIDs)
        }
    }
}

public struct MarketTickMovementSummary: Sendable, Equatable, Codable {
    public let purchasedLoads: [DeliveryCargo]
    public let householdDeliveries: [HouseholdCommodityDelivery]

    public static let empty = Self(purchasedLoads: [], householdDeliveries: [])
}

public struct CityMovementSummary: Sendable, Equatable, Codable {
    public let walkers: WalkerMovementSummary
    public let logistics: DeliveryMovementSummary
    public let market: MarketTickMovementSummary

    public static let empty = Self(
        walkers: .empty,
        logistics: .empty,
        market: .empty
    )
}

public struct CityTickResult: Sendable, Equatable, Codable {
    public let tickSequence: UInt64
    public let day: Int
    public let movement: CityMovementSummary
    public let migratedResidents: Int
    public let migrationAssessment: MigrationAssessment
    public let monthlySettlement: MonthlySettlement?
}
