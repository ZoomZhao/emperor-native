import Foundation

public struct ResidentialServiceConfiguration: Sendable, Hashable {
    public let buildingID: Int
    public let figureID: Int
    public let service: WalkerServiceKind

    public init(buildingID: Int, figureID: Int, service: WalkerServiceKind) {
        self.buildingID = buildingID
        self.figureID = figureID
        self.service = service
    }
}

/// Original service buildings and the roaming figure that delivers their
/// housing coverage. Multiple religious buildings intentionally share one
/// requirement because the house table accepts either Daoist or Buddhist care.
public enum OriginalResidentialServiceCatalog {
    public static let configurations: [ResidentialServiceConfiguration] = [
        .init(buildingID: 124, figureID: 39, service: .inspection),
        .init(buildingID: 127, figureID: 29, service: .constable),
        .init(buildingID: 125, figureID: 27, service: .tax),
        .init(buildingID: 72, figureID: 28, service: .water),
        .init(buildingID: 207, figureID: 30, service: .herbalist),
        .init(buildingID: 208, figureID: 31, service: .acupuncture),
        .init(buildingID: 211, figureID: 34, service: .music),
        .init(buildingID: 212, figureID: 32, service: .acrobat),
        .init(buildingID: 213, figureID: 33, service: .drama),
        .init(buildingID: 214, figureID: 35, service: .ancestor),
        .init(buildingID: 215, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 216, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 217, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 218, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 219, figureID: 35, service: .confucian),
    ]

    public static func configuration(buildingID: Int) -> ResidentialServiceConfiguration? {
        configurations.first { $0.buildingID == buildingID }
    }
}

public struct ResidentialServiceBuilding: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let service: WalkerServiceKind
    public let figureID: Int
    public let roadAccessPoint: GridPoint
    public let walkerID: Int
}

public enum HouseEvolutionRequirement: Sendable, Hashable, Codable {
    case desirability(current: Int, required: Int)
    case service(WalkerServiceKind)
    case foodQuality(current: Int, required: Int)
    case commodityAlternatives([Int])
}

public enum HouseEvolutionDirection: String, Sendable, Hashable, Codable {
    case evolved
    case devolved
}

public struct HouseEvolutionChange: Identifiable, Sendable, Hashable, Codable {
    public let houseID: Int
    public let fromLevelID: Int
    public let toLevelID: Int
    public let direction: HouseEvolutionDirection
    public let displacedResidents: Int

    public var id: Int { houseID }
}

public struct HouseEvolutionEvaluation: Identifiable, Sendable, Hashable, Codable {
    public let houseID: Int
    public let levelID: Int
    public let desirability: Int
    public let nextLevelID: Int?
    public let missingEvolutionRequirements: [HouseEvolutionRequirement]

    public var id: Int { houseID }
    public var canEvolve: Bool {
        nextLevelID != nil && missingEvolutionRequirements.isEmpty
    }
}

public struct HousingMonthlySettlement: Sendable, Hashable, Codable {
    public let changes: [HouseEvolutionChange]
    public let evaluations: [HouseEvolutionEvaluation]

    public var evolvedCount: Int { changes.count { $0.direction == .evolved } }
    public var devolvedCount: Int { changes.count { $0.direction == .devolved } }
    public var displacedResidents: Int { changes.reduce(0) { $0 + $1.displacedResidents } }
}

public enum DeterministicHousingEvolution {
    public static let marketCommodityIDs: Set<Int> = [13, 19, 22, 23, 24, 25]

    public static func nextLevel(after levelID: Int) -> Int? {
        switch levelID {
        case 0..<7: levelID + 1
        case 8..<14: levelID + 1
        default: nil
        }
    }

    public static func previousLevel(before levelID: Int) -> Int? {
        switch levelID {
        case 1...7: levelID - 1
        case 9...14: levelID - 1
        default: nil
        }
    }

    /// Evaluates the exact live requirements used by the next monthly
    /// settlement. The native UI uses this to explain upgrade blockers on
    /// hover without waiting for a month-end snapshot.
    public static func evaluate(
        house: ResidentialUnit,
        models: BuildingModelTable,
        difficulty: GameDifficulty
    ) -> HouseEvolutionEvaluation? {
        guard house.location != nil,
              let current = models[houseLevelID: house.houseLevelID],
              house.residents > 0
                || (house.houseLevelID == 8 && current.populationCapacity == 0) else {
            return nil
        }
        let next = nextLevel(after: house.houseLevelID)
        var evolutionMissing = requirementsMissing(model: current, house: house)
        let evolveThreshold = threshold(
            current.evolveDesirability,
            fieldIndex: 1,
            models: models,
            difficulty: difficulty
        )
        if next != nil, house.desirability < evolveThreshold {
            evolutionMissing.insert(
                .desirability(current: house.desirability, required: evolveThreshold),
                at: 0
            )
        }
        return HouseEvolutionEvaluation(
            houseID: house.id,
            levelID: house.houseLevelID,
            desirability: house.desirability,
            nextLevelID: next,
            missingEvolutionRequirements: next == nil ? [] : evolutionMissing
        )
    }

    public static func settle(
        houses: inout [ResidentialUnit],
        models: BuildingModelTable,
        difficulty: GameDifficulty
    ) -> HousingMonthlySettlement {
        var changes: [HouseEvolutionChange] = []
        var evaluations: [HouseEvolutionEvaluation] = []

        for index in houses.indices.sorted(by: { houses[$0].id < houses[$1].id }) {
            guard let evaluation = evaluate(
                house: houses[index],
                models: models,
                difficulty: difficulty
            ), let current = models[houseLevelID: houses[index].houseLevelID] else { continue }
            let currentLevel = houses[index].houseLevelID
            let next = evaluation.nextLevelID
            let evolutionMissing = evaluation.missingEvolutionRequirements
            evaluations.append(evaluation)

            if let previousLevel = previousLevel(before: currentLevel),
               let previous = models[houseLevelID: previousLevel] {
                let devolveThreshold = threshold(
                    current.devolveDesirability,
                    fieldIndex: 0,
                    models: models,
                    difficulty: difficulty
                )
                let lostMaintenance = !requirementsMissing(
                    model: previous,
                    house: houses[index]
                ).isEmpty
                if houses[index].desirability < devolveThreshold || lostMaintenance {
                    let oldResidents = houses[index].residents
                    houses[index].houseLevelID = previousLevel
                    let capacity = houses[index].capacity(using: models)
                    houses[index].residents = min(oldResidents, capacity)
                    changes.append(HouseEvolutionChange(
                        houseID: houses[index].id,
                        fromLevelID: currentLevel,
                        toLevelID: previousLevel,
                        direction: .devolved,
                        displacedResidents: oldResidents - houses[index].residents
                    ))
                    continue
                }
            }

            if let next, evolutionMissing.isEmpty {
                houses[index].houseLevelID = next
                changes.append(HouseEvolutionChange(
                    houseID: houses[index].id,
                    fromLevelID: currentLevel,
                    toLevelID: next,
                    direction: .evolved,
                    displacedResidents: 0
                ))
            }
        }

        return HousingMonthlySettlement(changes: changes, evaluations: evaluations)
    }

    public static func requirementsMissing(
        model: HouseModel,
        house: ResidentialUnit
    ) -> [HouseEvolutionRequirement] {
        var missing: [HouseEvolutionRequirement] = []
        let services: [(Int, WalkerServiceKind)] = [
            (model.waterRequired, .water),
            (model.herbalistRequired, .herbalist),
            (model.acupunctureRequired, .acupuncture),
            (model.musicRequired, .music),
            (model.acrobatRequired, .acrobat),
            (model.dramaRequired, .drama),
            (model.ancestorAccessRequired, .ancestor),
            (model.confucianAccessRequired, .confucian),
            (model.daoistOrBuddhistAccessRequired, .daoistOrBuddhist),
        ]
        for (required, service) in services where
            required > 0 && !house.serviceCoverage.contains(service) {
            missing.append(.service(service))
        }

        if model.foodQualityRequired > 0,
           house.lastSuppliedFoodQuality.rawValue < model.foodQualityRequired {
            missing.append(.foodQuality(
                current: house.lastSuppliedFoodQuality.rawValue,
                required: model.foodQualityRequired
            ))
        }
        for alternatives in commodityAlternatives(for: model) where
            house.lastSuppliedCommodityIDs.isDisjoint(with: alternatives) {
            missing.append(.commodityAlternatives(alternatives.sorted()))
        }
        return missing
    }

    public static func commodityAlternatives(for model: HouseModel) -> [Set<Int>] {
        var result: [Set<Int>] = []
        if model.hempRequired > 0 { result.append([19]) }
        if model.ceramicsRequired > 0 { result.append([25]) }
        if model.teaRequired > 0 { result.append([13]) }
        if model.silkRequired > 0 { result.append([24]) }
        if model.luxuryWareRequired > 0 { result.append([23, 22]) }
        return result
    }

    private static func threshold(
        _ base: Int,
        fieldIndex: Int,
        models: BuildingModelTable,
        difficulty: GameDifficulty
    ) -> Int {
        guard models.houseDifficultyModifiers.indices.contains(difficulty.rawValue),
              models.houseDifficultyModifiers[difficulty.rawValue].values.indices.contains(fieldIndex) else {
            return base
        }
        return base + models.houseDifficultyModifiers[difficulty.rawValue].values[fieldIndex]
    }
}

public enum DeterministicDesirability {
    public static func contribution(
        from model: BuildingModel,
        source: GridPoint,
        to target: GridPoint
    ) -> Int {
        guard model.initialDesirability != 0 else { return 0 }
        let distance = abs(source.x - target.x) + abs(source.y - target.y)
        guard distance <= model.maximumDesirabilityRange else { return 0 }
        let steps = model.desirabilityStep > 0 ? distance / model.desirabilityStep : 0
        return model.initialDesirability + steps * model.desirabilityStepSize
    }
}
