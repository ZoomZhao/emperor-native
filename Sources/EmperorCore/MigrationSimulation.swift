import Foundation

public enum MigrationBlockReason: Sendable, Hashable, Codable {
    case noEligibleHousing
    case negativeTreasury
    case highUnemployment(percent: Int)
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

public struct DeterministicMigrationState: Sendable, Hashable, Codable {
    public private(set) var lastAssessment: MigrationAssessment?
    public private(set) var lastDailyImmigrants: Int
    public private(set) var currentMonthImmigrants: Int
    public private(set) var lastMonthImmigrants: Int

    public init(
        lastAssessment: MigrationAssessment? = nil,
        lastDailyImmigrants: Int = 0,
        currentMonthImmigrants: Int = 0,
        lastMonthImmigrants: Int = 0
    ) {
        self.lastAssessment = lastAssessment
        self.lastDailyImmigrants = max(0, lastDailyImmigrants)
        self.currentMonthImmigrants = max(0, currentMonthImmigrants)
        self.lastMonthImmigrants = max(0, lastMonthImmigrants)
    }

    public mutating func recordDay(assessment: MigrationAssessment, admitted: Int) {
        lastAssessment = assessment
        lastDailyImmigrants = max(0, admitted)
        currentMonthImmigrants += max(0, admitted)
    }

    public mutating func finishMonth() {
        lastMonthImmigrants = currentMonthImmigrants
        currentMonthImmigrants = 0
    }
}

public enum DeterministicMigration {
    public static let frontierPopulationLimit = 150
    public static let maximumDailyImmigrants = 5

    public static func assess(
        houses: [ResidentialUnit],
        population: Int,
        treasury: Int,
        roadNetwork: RoadNetwork,
        workforce: WorkforceMonthlySettlement?,
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
        guard availableCapacity > 0 else { return .noHousing }

        let unemploymentPercent: Int
        if let workforce, workforce.availableWorkers > 0 {
            unemploymentPercent = workforce.unemployedWorkers * 100 / workforce.availableWorkers
        } else {
            unemploymentPercent = 0
        }

        let blockReason: MigrationBlockReason?
        if population >= frontierPopulationLimit, treasury < 0 {
            blockReason = .negativeTreasury
        } else if population >= frontierPopulationLimit, unemploymentPercent > 10 {
            blockReason = .highUnemployment(percent: unemploymentPercent)
        } else {
            blockReason = nil
        }
        return MigrationAssessment(
            eligibleHouseIDs: eligible.map(\.id),
            availableCapacity: availableCapacity,
            unemploymentPercent: unemploymentPercent,
            plannedImmigrants: blockReason == nil
                ? min(maximumDailyImmigrants, availableCapacity)
                : 0,
            blockReason: blockReason
        )
    }
}
