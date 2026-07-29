import Foundation

public enum AgriculturalClimate: String, CaseIterable, Sendable, Hashable, Codable {
    case arid
    case temperate
    case humid

    var modelPrefix: String {
        switch self {
        case .arid: "Arid"
        case .temperate: "Normal"
        case .humid: "Humid"
        }
    }
}

/// Climate assignments verified against the original campaign maps.
///
/// Campaign Creator mission settings do not serialize a climate field beside
/// their resource permissions, so the original map identity is the durable
/// source available to the native runtime.
public enum OriginalAgriculturalClimateCatalog {
    public static func climate(forMapFileName fileName: String) -> AgriculturalClimate {
        switch fileName.lowercased() {
        case "xiangjun.map":
            return .humid
        default:
            return .temperate
        }
    }
}

public enum AgriculturalCategory: String, Sendable, Hashable, Codable {
    case field
    case hemp
    case orchard

    var farmConfigKey: String {
        switch self {
        case .field: "Field"
        case .hemp: "Hemp"
        case .orchard: "Orchard"
        }
    }

    var tendingRangeKey: String {
        switch self {
        case .field: "FieldCrop"
        case .hemp: "Hemp"
        case .orchard: "Orchard"
        }
    }
}

public enum AgriculturalCrop: String, CaseIterable, Sendable, Hashable, Codable {
    case soybeans
    case cabbage
    case millet
    case rice
    case wheat
    case hemp
    case tea
    case mulberry
    case lacquer

    public var outputCommodityID: Int {
        switch self {
        case .soybeans: 1
        case .cabbage: 3
        case .millet: 5
        case .rice: 6
        case .wheat: 7
        case .hemp: 19
        case .tea: 13
        case .mulberry: 12
        case .lacquer: 14
        }
    }

    public var producerBuildingID: Int {
        switch self {
        case .soybeans, .cabbage, .millet, .rice, .wheat: 193
        case .hemp: 192
        case .tea: 237
        case .lacquer: 238
        case .mulberry: 239
        }
    }

    public var plotBuildingID: Int {
        switch self {
        case .hemp: 194
        case .wheat: 195
        case .millet: 196
        case .rice: 197
        case .cabbage: 198
        case .soybeans: 199
        case .tea: 26
        case .lacquer: 27
        case .mulberry: 28
        }
    }

    public var category: AgriculturalCategory {
        switch self {
        case .hemp: .hemp
        case .tea, .mulberry, .lacquer: .orchard
        default: .field
        }
    }

    public var regionalModelKey: String {
        switch self {
        case .soybeans: "BeanCurd"
        case .cabbage: "Cabbage"
        case .millet: "Millet"
        case .rice: "Rice"
        case .wheat: "Wheat"
        case .hemp: "Hemp"
        case .tea: "Tea"
        case .mulberry: "Mulberry"
        case .lacquer: "Lacquer"
        }
    }

    public var growingMonths: Set<Int> {
        switch self {
        case .soybeans: [5, 6, 7, 8]
        case .cabbage: [8, 9, 10, 11]
        case .millet: [7, 8, 9, 10]
        case .rice: [6, 7, 8, 9]
        case .wheat: [3, 4, 5, 6]
        case .hemp: [4, 5, 6, 7, 8]
        case .tea: [3, 4, 6, 7, 9, 10]
        case .mulberry: [4, 5, 7, 8]
        case .lacquer: [2, 3, 4, 5, 6]
        }
    }

    public var harvestMonths: Set<Int> {
        switch self {
        case .soybeans, .hemp: [9]
        case .cabbage: [12]
        case .millet: [11]
        case .rice: [10]
        case .wheat: [7]
        case .tea: [5, 8, 11]
        case .mulberry: [6, 9]
        case .lacquer: [7, 8]
        }
    }
}

public struct AgriculturalConfiguration: Sendable, Hashable, Codable {
    public let crop: AgriculturalCrop
    public let fieldCount: Int
    public let fertilityPercent: Int
    public let climate: AgriculturalClimate

    public init(
        crop: AgriculturalCrop,
        fieldCount: Int,
        fertilityPercent: Int,
        climate: AgriculturalClimate
    ) {
        self.crop = crop
        self.fieldCount = max(1, fieldCount)
        self.fertilityPercent = min(100, max(0, fertilityPercent))
        self.climate = climate
    }
}

public struct AgriculturalHarvestOperation: Sendable, Hashable, Codable {
    public let buildingInstanceID: Int
    public let crop: AgriculturalCrop
    public let effectiveFields: Int
    public let fertilityPercent: Int
    public let regionalModifierPercent: Int
    public let workerEfficiencyPercent: Int
    public let outputCommodityID: Int
    public let outputAmount: Int
}

public struct AgriculturalMonthlySettlement: Sendable, Hashable, Codable {
    public let year: Int
    public let month: Int
    public let harvests: [AgriculturalHarvestOperation]
    public let growingBuildingInstanceIDs: [Int]
    public let dormantBuildingInstanceIDs: [Int]
    public let blockedBuildingInstanceIDs: [Int]
}

public struct OriginalAgricultureRules: Sendable {
    public let farm: LegacyINI

    public init(farm: LegacyINI) {
        self.farm = farm
    }

    public var minimumFertility: Int {
        farm.integer(section: "Production", key: "MinFertility") ?? 10
    }

    public func tendingRange(for category: AgriculturalCategory) -> Int {
        farm.integer(section: "Tending Range", key: category.tendingRangeKey) ?? 3
    }

    public func maximumTendedFields(for category: AgriculturalCategory) -> Int {
        farm.integer(section: "TendingFields", key: category.farmConfigKey) ?? 0
    }

    public func harvesterCount(for category: AgriculturalCategory) -> Int {
        farm.integer(section: "Harvesters", key: category.farmConfigKey) ?? 0
    }

    public func harvestingFieldsPerHarvester(for category: AgriculturalCategory) -> Int {
        farm.integer(section: "HarvestingFields", key: category.farmConfigKey) ?? 0
    }

    public func regionalModifierPercent(
        crop: AgriculturalCrop,
        climate: AgriculturalClimate
    ) -> Int {
        let key = climate.modelPrefix + crop.regionalModelKey
        return Int(((farm.decimal(section: "Regional Mod", key: key) ?? 1) * 100).rounded())
    }

    public func harvestAmount(
        configuration: AgriculturalConfiguration,
        assignedWorkers: Int,
        requiredWorkers: Int
    ) -> (amount: Int, effectiveFields: Int, regionPercent: Int, workerPercent: Int) {
        guard configuration.fertilityPercent >= minimumFertility,
              requiredWorkers > 0,
              assignedWorkers > 0 else { return (0, 0, 0, 0) }
        let category = configuration.crop.category
        let tendingLimit = maximumTendedFields(for: category)
        let harvestingLimit = harvesterCount(for: category)
            * harvestingFieldsPerHarvester(for: category)
        let effectiveFields = min(configuration.fieldCount, tendingLimit, harvestingLimit)
        let regionPercent = regionalModifierPercent(
            crop: configuration.crop,
            climate: configuration.climate
        )
        let workerPercent = min(100, assignedWorkers * 100 / requiredWorkers)
        // One fully fertile, fully staffed plot yields one original 100-unit
        // load before the model's regional modifier is applied.
        let numerator = effectiveFields * 100
            * configuration.fertilityPercent * regionPercent * workerPercent
        let amount = numerator / 1_000_000
        return (amount, effectiveFields, regionPercent, workerPercent)
    }
}
