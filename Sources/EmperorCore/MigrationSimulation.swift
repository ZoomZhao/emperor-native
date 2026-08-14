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

public struct DeterministicMigrationState: Sendable, Hashable, Codable {
    public private(set) var automaticMigrationAvailability: AutomaticMigrationAvailability
    public private(set) var lastAssessment: MigrationAssessment?
    public private(set) var lastDailyImmigrants: Int
    public private(set) var currentMonthImmigrants: Int
    public private(set) var lastMonthImmigrants: Int

    public init(
        automaticMigrationAvailability: AutomaticMigrationAvailability = .unsupportedOriginalProducer,
        lastAssessment: MigrationAssessment? = nil,
        lastDailyImmigrants: Int = 0,
        currentMonthImmigrants: Int = 0,
        lastMonthImmigrants: Int = 0
    ) {
        self.automaticMigrationAvailability = automaticMigrationAvailability
        self.lastAssessment = lastAssessment
        self.lastDailyImmigrants = max(0, lastDailyImmigrants)
        self.currentMonthImmigrants = max(0, currentMonthImmigrants)
        self.lastMonthImmigrants = max(0, lastMonthImmigrants)
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

    private enum CodingKeys: String, CodingKey {
        case automaticMigrationAvailability
        case lastAssessment
        case lastDailyImmigrants
        case currentMonthImmigrants
        case lastMonthImmigrants
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
    }
}

public enum DeterministicMigration {
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
}
