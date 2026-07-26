import Foundation

public struct ProductionInput: Sendable, Hashable, Codable {
    public let commodityID: Int
    public let amount: Int

    public init(commodityID: Int, amount: Int) {
        self.commodityID = commodityID
        self.amount = amount
    }
}

public struct ProductionRecipe: Identifiable, Sendable, Hashable {
    public let buildingID: Int
    public let outputCommodityID: Int
    public let outputAmount: Int
    /// Each inner array is one complete input option. The first stocked option
    /// is selected, which supports the original weaponsmith's era-dependent ores.
    public let inputOptions: [[ProductionInput]]

    public var id: Int { buildingID }
}

/// Hard-coded production relationships used by the original executable,
/// expressed with IDs from the original building and trade model files.
public enum OriginalProductionCatalog {
    public static let recipes: [ProductionRecipe] = [
        recipe(31, output: 2),                    // Fishing Quay -> Fish
        recipe(33, output: 4),                    // Hunter's Tent -> Meat
        recipe(35, output: 18, amount: 200),      // Clay Pit -> Clay (feeds about two kilns)
        recipe(36, output: 20),                   // Stoneworks -> Stone
        recipe(37, output: 8),                    // Salt Mine -> Salt
        recipe(38, output: 10),                   // Logging Shed -> Wood
        recipe(39, output: 11),                   // Bronze Smelter -> Bronze
        recipe(40, output: 15),                   // Iron Smelter -> Iron
        recipe(41, output: 16, inputs: [[(10, 100)]]),
        recipe(42, output: 23, inputs: [[(11, 100), (18, 100)]]),
        recipe(43, output: 25, inputs: [[(18, 100)]]),
        recipe(44, output: 22, inputs: [[(14, 100), (10, 100)]]),
        recipe(45, output: 27, inputs: [[(19, 100)]]),
        recipe(46, output: 26, inputs: [[(17, 100)]]),
        recipe(47, output: 24, inputs: [[(12, 100)]]),
        recipe(192, output: 19),                  // Hemp Farm -> Hemp
        recipe(226, output: 21, inputs: [          // Weaponsmith: bronze, iron, or steel
            [(11, 100)], [(15, 100)], [(16, 100)]
        ]),
        recipe(237, output: 13),                  // Tea Curing Shed -> Tea
        recipe(238, output: 14),                  // Lacquer Refinery -> Lacquer
        recipe(239, output: 12)                   // Silkworm Shed -> Raw Silk
    ]

    private static let recipesByBuildingID = Dictionary(
        uniqueKeysWithValues: recipes.map { ($0.buildingID, $0) }
    )

    public static func recipe(forBuildingID buildingID: Int) -> ProductionRecipe? {
        recipesByBuildingID[buildingID]
    }

    private static func recipe(
        _ buildingID: Int,
        output outputCommodityID: Int,
        amount: Int = 100,
        inputs: [[(Int, Int)]] = [[]]
    ) -> ProductionRecipe {
        ProductionRecipe(
            buildingID: buildingID,
            outputCommodityID: outputCommodityID,
            outputAmount: amount,
            inputOptions: inputs.map { option in
                option.map { ProductionInput(commodityID: $0.0, amount: $0.1) }
            }
        )
    }
}

public struct ProductionBuilding: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public var assignedWorkers: Int
    public var isEnabled: Bool
    /// 100 progress points complete one production batch.
    public var progress: Int
    /// A nil access point keeps the original city-wide inventory behavior for
    /// legacy saves and headless rule tests. Located buildings use physical
    /// delivery walkers and their own input/output buffers.
    public var roadAccessPoint: GridPoint?
    public var inputInventoryByCommodityID: [Int: Int]
    public var outputInventoryByCommodityID: [Int: Int]
    public var activeDeliveryWalkerID: Int?
    public var agriculture: AgriculturalConfiguration?

    public init(
        id: Int,
        buildingID: Int,
        assignedWorkers: Int,
        isEnabled: Bool,
        progress: Int,
        roadAccessPoint: GridPoint? = nil,
        inputInventoryByCommodityID: [Int: Int] = [:],
        outputInventoryByCommodityID: [Int: Int] = [:],
        activeDeliveryWalkerID: Int? = nil,
        agriculture: AgriculturalConfiguration? = nil
    ) {
        self.id = id
        self.buildingID = buildingID
        self.assignedWorkers = assignedWorkers
        self.isEnabled = isEnabled
        self.progress = progress
        self.roadAccessPoint = roadAccessPoint
        self.inputInventoryByCommodityID = inputInventoryByCommodityID
        self.outputInventoryByCommodityID = outputInventoryByCommodityID
        self.activeDeliveryWalkerID = activeDeliveryWalkerID
        self.agriculture = agriculture
    }

    private enum CodingKeys: String, CodingKey {
        case id, buildingID, assignedWorkers, isEnabled, progress, roadAccessPoint
        case inputInventoryByCommodityID, outputInventoryByCommodityID, activeDeliveryWalkerID
        case agriculture
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        buildingID = try container.decode(Int.self, forKey: .buildingID)
        assignedWorkers = try container.decode(Int.self, forKey: .assignedWorkers)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        progress = try container.decode(Int.self, forKey: .progress)
        roadAccessPoint = try container.decodeIfPresent(GridPoint.self, forKey: .roadAccessPoint)
        inputInventoryByCommodityID = try container.decodeIfPresent(
            [Int: Int].self,
            forKey: .inputInventoryByCommodityID
        ) ?? [:]
        outputInventoryByCommodityID = try container.decodeIfPresent(
            [Int: Int].self,
            forKey: .outputInventoryByCommodityID
        ) ?? [:]
        activeDeliveryWalkerID = try container.decodeIfPresent(Int.self, forKey: .activeDeliveryWalkerID)
        agriculture = try container.decodeIfPresent(AgriculturalConfiguration.self, forKey: .agriculture)
    }
}

public struct ProductionOperation: Identifiable, Sendable, Hashable, Codable {
    public let buildingInstanceID: Int
    public let buildingID: Int
    public let consumed: [ProductionInput]
    public let outputCommodityID: Int
    public let outputAmount: Int

    public var id: Int { buildingInstanceID }
}

public struct ProductionMonthlySettlement: Sendable, Hashable, Codable {
    public let operations: [ProductionOperation]
    public let staffedWorkers: Int
    public let requiredWorkers: Int
    public let blockedBuildingIDs: [Int]
}

public struct DeterministicProductionState: Sendable, Hashable, Codable {
    public private(set) var buildings: [ProductionBuilding]
    public private(set) var inventoryByCommodityID: [Int: Int]
    public private(set) var lastSettlement: ProductionMonthlySettlement?
    public private(set) var lastAgriculturalSettlement: AgriculturalMonthlySettlement?
    private var nextBuildingInstanceID: Int

    public init(inventoryByCommodityID: [Int: Int] = [:]) {
        buildings = []
        self.inventoryByCommodityID = inventoryByCommodityID
        lastSettlement = nil
        lastAgriculturalSettlement = nil
        nextBuildingInstanceID = 1
    }

    public subscript(commodityID commodityID: Int) -> Int {
        inventoryByCommodityID[commodityID, default: 0]
    }

    @discardableResult
    public mutating func addBuilding(
        buildingID: Int,
        assignedWorkers: Int = 0,
        roadAccessPoint: GridPoint? = nil,
        models: BuildingModelTable
    ) -> Int? {
        guard OriginalProductionCatalog.recipe(forBuildingID: buildingID) != nil,
              let model = models[buildingID: buildingID], model.employees > 0 else { return nil }
        let id = nextBuildingInstanceID
        nextBuildingInstanceID += 1
        buildings.append(ProductionBuilding(
            id: id,
            buildingID: buildingID,
            assignedWorkers: min(max(0, assignedWorkers), model.employees),
            isEnabled: true,
            progress: 0,
            roadAccessPoint: roadAccessPoint
        ))
        return id
    }

    @discardableResult
    public mutating func addAgriculturalBuilding(
        configuration: AgriculturalConfiguration,
        assignedWorkers: Int,
        roadAccessPoint: GridPoint,
        models: BuildingModelTable
    ) -> Int? {
        let buildingID = configuration.crop.producerBuildingID
        guard let model = models[buildingID: buildingID], model.employees > 0 else { return nil }
        let id = nextBuildingInstanceID
        nextBuildingInstanceID += 1
        buildings.append(ProductionBuilding(
            id: id,
            buildingID: buildingID,
            assignedWorkers: min(max(0, assignedWorkers), model.employees),
            isEnabled: true,
            progress: 0,
            roadAccessPoint: roadAccessPoint,
            agriculture: configuration
        ))
        return id
    }

    public mutating func setAssignedWorkers(
        _ count: Int,
        buildingInstanceID: Int,
        models: BuildingModelTable
    ) {
        guard let index = buildings.firstIndex(where: { $0.id == buildingInstanceID }),
              let model = models[buildingID: buildings[index].buildingID] else { return }
        buildings[index].assignedWorkers = min(max(0, count), model.employees)
    }

    public mutating func setEnabled(_ enabled: Bool, buildingInstanceID: Int) {
        guard let index = buildings.firstIndex(where: { $0.id == buildingInstanceID }) else { return }
        buildings[index].isEnabled = enabled
    }

    public mutating func addInventory(commodityID: Int, amount: Int) {
        guard amount != 0 else { return }
        inventoryByCommodityID[commodityID, default: 0] = max(
            0,
            inventoryByCommodityID[commodityID, default: 0] + amount
        )
    }

    public func building(instanceID: Int) -> ProductionBuilding? {
        buildings.first { $0.id == instanceID }
    }

    /// Removes one physical producer and all of its local buffers. Global
    /// inventory is deliberately unchanged: located producers only enter that
    /// ledger after a delivery reaches storage.
    @discardableResult
    public mutating func removeBuilding(instanceID: Int) -> ProductionBuilding? {
        guard let index = buildings.firstIndex(where: { $0.id == instanceID }) else {
            return nil
        }
        return buildings.remove(at: index)
    }

    public func localInputAmount(buildingInstanceID: Int, commodityID: Int) -> Int {
        building(instanceID: buildingInstanceID)?.inputInventoryByCommodityID[commodityID, default: 0] ?? 0
    }

    public func localOutputAmount(buildingInstanceID: Int, commodityID: Int) -> Int {
        building(instanceID: buildingInstanceID)?.outputInventoryByCommodityID[commodityID, default: 0] ?? 0
    }

    @discardableResult
    public mutating func takeLocalOutput(
        buildingInstanceID: Int,
        commodityID: Int,
        amount: Int
    ) -> Int {
        guard amount > 0,
              let index = buildings.firstIndex(where: { $0.id == buildingInstanceID }) else { return 0 }
        let available = buildings[index].outputInventoryByCommodityID[commodityID, default: 0]
        let taken = min(amount, available)
        buildings[index].outputInventoryByCommodityID[commodityID] = available - taken
        return taken
    }

    public mutating func addLocalInput(
        buildingInstanceID: Int,
        commodityID: Int,
        amount: Int
    ) {
        guard amount > 0,
              let index = buildings.firstIndex(where: { $0.id == buildingInstanceID }) else { return }
        buildings[index].inputInventoryByCommodityID[commodityID, default: 0] += amount
    }

    public mutating func setActiveDeliveryWalker(_ walkerID: Int?, buildingInstanceID: Int) {
        guard let index = buildings.firstIndex(where: { $0.id == buildingInstanceID }) else { return }
        buildings[index].activeDeliveryWalkerID = walkerID
    }

    @discardableResult
    public mutating func advanceMonth(models: BuildingModelTable) -> ProductionMonthlySettlement {
        var operations: [ProductionOperation] = []
        var blocked: [Int] = []
        var staffedWorkers = 0
        var requiredWorkers = 0

        // Resource producers run before workshops. Within each tier, stable
        // instance IDs make the result independent of array mutation history.
        let orderedIndices = buildings.indices.sorted { lhs, rhs in
            let lhsRecipe = OriginalProductionCatalog.recipe(forBuildingID: buildings[lhs].buildingID)
            let rhsRecipe = OriginalProductionCatalog.recipe(forBuildingID: buildings[rhs].buildingID)
            let lhsIsRaw = lhsRecipe?.inputOptions.first?.isEmpty == true
            let rhsIsRaw = rhsRecipe?.inputOptions.first?.isEmpty == true
            if lhsIsRaw != rhsIsRaw { return lhsIsRaw }
            return buildings[lhs].id < buildings[rhs].id
        }

        for index in orderedIndices {
            guard buildings[index].agriculture == nil else { continue }
            guard let model = models[buildingID: buildings[index].buildingID],
                  let recipe = OriginalProductionCatalog.recipe(forBuildingID: buildings[index].buildingID) else {
                continue
            }
            requiredWorkers += model.employees
            staffedWorkers += buildings[index].assignedWorkers
            guard buildings[index].isEnabled, buildings[index].assignedWorkers > 0 else { continue }
            let usesPhysicalLogistics = buildings[index].roadAccessPoint != nil
            if usesPhysicalLogistics,
               buildings[index].outputInventoryByCommodityID[recipe.outputCommodityID, default: 0] > 0 {
                // The original industry stops when its deliveryman has not
                // returned before the next product is ready.
                blocked.append(buildings[index].id)
                continue
            }
            buildings[index].progress += buildings[index].assignedWorkers * 100 / model.employees

            while buildings[index].progress >= 100 {
                let inventory = usesPhysicalLogistics
                    ? buildings[index].inputInventoryByCommodityID
                    : inventoryByCommodityID
                guard let inputs = firstStockedInputOption(for: recipe, inventory: inventory) else {
                    blocked.append(buildings[index].id)
                    break
                }
                for input in inputs {
                    if usesPhysicalLogistics {
                        buildings[index].inputInventoryByCommodityID[input.commodityID, default: 0] -= input.amount
                    } else {
                        inventoryByCommodityID[input.commodityID, default: 0] -= input.amount
                    }
                }
                if usesPhysicalLogistics {
                    buildings[index].outputInventoryByCommodityID[recipe.outputCommodityID, default: 0] += recipe.outputAmount
                } else {
                    inventoryByCommodityID[recipe.outputCommodityID, default: 0] += recipe.outputAmount
                }
                buildings[index].progress -= 100
                operations.append(ProductionOperation(
                    buildingInstanceID: buildings[index].id,
                    buildingID: buildings[index].buildingID,
                    consumed: inputs,
                    outputCommodityID: recipe.outputCommodityID,
                    outputAmount: recipe.outputAmount
                ))
            }
        }

        let settlement = ProductionMonthlySettlement(
            operations: operations,
            staffedWorkers: staffedWorkers,
            requiredWorkers: requiredWorkers,
            blockedBuildingIDs: blocked
        )
        lastSettlement = settlement
        return settlement
    }

    @discardableResult
    public mutating func advanceAgriculture(
        calendar: SimulationCalendar,
        models: BuildingModelTable,
        farm: LegacyINI,
        yieldModifierPercent: Int = 100
    ) -> AgriculturalMonthlySettlement {
        let rules = OriginalAgricultureRules(farm: farm)
        var harvests: [AgriculturalHarvestOperation] = []
        var growing: [Int] = []
        var dormant: [Int] = []
        var blocked: [Int] = []

        for index in buildings.indices.sorted(by: { buildings[$0].id < buildings[$1].id }) {
            guard let configuration = buildings[index].agriculture,
                  let model = models[buildingID: buildings[index].buildingID] else { continue }
            if configuration.crop.growingMonths.contains(calendar.month) {
                growing.append(buildings[index].id)
                continue
            }
            guard configuration.crop.harvestMonths.contains(calendar.month) else {
                dormant.append(buildings[index].id)
                continue
            }
            let outputCommodityID = configuration.crop.outputCommodityID
            guard buildings[index].isEnabled,
                  buildings[index].activeDeliveryWalkerID == nil,
                  buildings[index].outputInventoryByCommodityID[outputCommodityID, default: 0] == 0 else {
                blocked.append(buildings[index].id)
                continue
            }
            let result = rules.harvestAmount(
                configuration: configuration,
                assignedWorkers: buildings[index].assignedWorkers,
                requiredWorkers: model.employees
            )
            let adjustedAmount = result.amount * max(0, yieldModifierPercent) / 100
            guard adjustedAmount > 0 else {
                blocked.append(buildings[index].id)
                continue
            }
            buildings[index].outputInventoryByCommodityID[outputCommodityID, default: 0] += adjustedAmount
            harvests.append(AgriculturalHarvestOperation(
                buildingInstanceID: buildings[index].id,
                crop: configuration.crop,
                effectiveFields: result.effectiveFields,
                fertilityPercent: configuration.fertilityPercent,
                regionalModifierPercent: result.regionPercent,
                workerEfficiencyPercent: result.workerPercent,
                outputCommodityID: outputCommodityID,
                outputAmount: adjustedAmount
            ))
        }

        let settlement = AgriculturalMonthlySettlement(
            year: calendar.year,
            month: calendar.month,
            harvests: harvests,
            growingBuildingInstanceIDs: growing,
            dormantBuildingInstanceIDs: dormant,
            blockedBuildingInstanceIDs: blocked
        )
        lastAgriculturalSettlement = settlement
        return settlement
    }

    private func firstStockedInputOption(
        for recipe: ProductionRecipe,
        inventory: [Int: Int]
    ) -> [ProductionInput]? {
        recipe.inputOptions.first { option in
            option.allSatisfy { inventory[$0.commodityID, default: 0] >= $0.amount }
        }
    }
}
