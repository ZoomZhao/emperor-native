import Foundation

public enum CampaignGoalRequirement: Sendable, Hashable {
    case alliedCities(Int)
    case conqueredCities(Int)
    case homage(Int)
    case housing(minimumLevelCode: Int, residents: Int)
    case menagerieSpecies(Int)
    case monument(buildingID: Int)
    case population(Int)
    case tradingPartners(Int)
    case treasury(Int)
    case yearlyProduction(commodityID: Int, internalUnits: Int)
    case yearlyProfit(Int)
}

public extension CampaignMissionGoal {
    var requirement: CampaignGoalRequirement {
        switch kind {
        case .alliedCities:
            .alliedCities(value(at: 1))
        case .conquer:
            .conqueredCities(value(at: 1))
        case .homage:
            .homage(value(at: 1))
        case .housing:
            .housing(minimumLevelCode: value(at: 0), residents: value(at: 1))
        case .menagerie:
            .menagerieSpecies(value(at: 1))
        case .monument:
            .monument(buildingID: value(at: 0))
        case .population:
            .population(value(at: 0))
        case .tradingPartners:
            .tradingPartners(value(at: 0))
        case .treasury:
            .treasury(value(at: 0))
        case .yearlyProduction:
            .yearlyProduction(commodityID: value(at: 0), internalUnits: value(at: 1))
        case .yearlyProfit:
            .yearlyProfit(value(at: 0))
        }
    }

    private func value(at index: Int) -> Int {
        guard values.indices.contains(index) else { return 0 }
        return Int(values[index])
    }
}

public struct CampaignGoalProgressSnapshot: Sendable, Hashable {
    public var alliedCityCount: Int
    public var conqueredCityCount: Int
    public var homageProgress: Int
    public var housingPopulationByLevelCode: [Int: Int]
    public var menagerieSpeciesCount: Int
    public var completedMonumentBuildingIDs: Set<Int>
    public var population: Int
    public var tradingPartnerCount: Int
    public var treasury: Int
    /// Highest production achieved in any completed February-to-January year,
    /// expressed in the original game's units (100 units per displayed crate).
    public var bestYearlyProductionUnitsByCommodityID: [Int: Int]
    /// Highest profit achieved in any completed February-to-January year.
    public var bestYearlyProfit: Int

    public init(
        alliedCityCount: Int = 0,
        conqueredCityCount: Int = 0,
        homageProgress: Int = 0,
        housingPopulationByLevelCode: [Int: Int] = [:],
        menagerieSpeciesCount: Int = 0,
        completedMonumentBuildingIDs: Set<Int> = [],
        population: Int = 0,
        tradingPartnerCount: Int = 0,
        treasury: Int = 0,
        bestYearlyProductionUnitsByCommodityID: [Int: Int] = [:],
        bestYearlyProfit: Int = 0
    ) {
        self.alliedCityCount = alliedCityCount
        self.conqueredCityCount = conqueredCityCount
        self.homageProgress = homageProgress
        self.housingPopulationByLevelCode = housingPopulationByLevelCode
        self.menagerieSpeciesCount = menagerieSpeciesCount
        self.completedMonumentBuildingIDs = completedMonumentBuildingIDs
        self.population = population
        self.tradingPartnerCount = tradingPartnerCount
        self.treasury = treasury
        self.bestYearlyProductionUnitsByCommodityID = bestYearlyProductionUnitsByCommodityID
        self.bestYearlyProfit = bestYearlyProfit
    }
}

public struct CampaignGoalProgress: Sendable, Hashable {
    public let currentValue: Int
    public let requiredValue: Int
    public let isSatisfied: Bool

    public init(currentValue: Int, requiredValue: Int, isSatisfied: Bool) {
        self.currentValue = currentValue
        self.requiredValue = requiredValue
        self.isSatisfied = isSatisfied
    }
}

public enum CampaignGoalEvaluator {
    public static func evaluate(
        _ goal: CampaignMissionGoal,
        against snapshot: CampaignGoalProgressSnapshot
    ) -> CampaignGoalProgress {
        let values: (current: Int, required: Int)
        switch goal.requirement {
        case let .alliedCities(required):
            values = (snapshot.alliedCityCount, required)
        case let .conqueredCities(required):
            values = (snapshot.conqueredCityCount, required)
        case let .homage(required):
            values = (snapshot.homageProgress, required)
        case let .housing(minimumLevelCode, residents):
            let current = snapshot.housingPopulationByLevelCode.reduce(0) {
                $1.key >= minimumLevelCode ? $0 + $1.value : $0
            }
            values = (current, residents)
        case let .menagerieSpecies(required):
            values = (snapshot.menagerieSpeciesCount, required)
        case let .monument(buildingID):
            values = (snapshot.completedMonumentBuildingIDs.contains(buildingID) ? 1 : 0, 1)
        case let .population(required):
            values = (snapshot.population, required)
        case let .tradingPartners(required):
            values = (snapshot.tradingPartnerCount, required)
        case let .treasury(required):
            values = (snapshot.treasury, required)
        case let .yearlyProduction(commodityID, internalUnits):
            values = (snapshot.bestYearlyProductionUnitsByCommodityID[commodityID, default: 0], internalUnits)
        case let .yearlyProfit(required):
            values = (snapshot.bestYearlyProfit, required)
        }
        return CampaignGoalProgress(
            currentValue: values.current,
            requiredValue: values.required,
            isSatisfied: values.current >= values.required
        )
    }

    public static func missionIsComplete(
        _ mission: CampaignMissionGoalSet,
        against snapshot: CampaignGoalProgressSnapshot
    ) -> Bool {
        !mission.goals.isEmpty && mission.goals.allSatisfy { evaluate($0, against: snapshot).isSatisfied }
    }
}
