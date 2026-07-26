import Foundation

public enum FoodQuality: Int, CaseIterable, Sendable, Hashable, Codable {
    case none = 0
    case bland = 20
    case plain = 30
    case appetizing = 50
    case tasty = 70
    case delicious = 90

    public var displayName: String {
        switch self {
        case .none: "None"
        case .bland: "Bland"
        case .plain: "Plain"
        case .appetizing: "Appetizing"
        case .tasty: "Tasty"
        case .delicious: "Delicious"
        }
    }
}

public enum OriginalFoodCatalog {
    public static let millBuildingID = 53
    public static let foodShopBuildingID = 66
    public static let foodCommodityIDs = Set(1...7)
    public static let saltCommodityID = 8
    public static let spicesCommodityID = 9
    public static let millCapacity = 3_200

    public static func isMillCommodity(_ commodityID: Int) -> Bool {
        foodCommodityIDs.contains(commodityID)
            || commodityID == saltCommodityID
            || commodityID == spicesCommodityID
    }

    public static func quality(in inventory: [Int: Int]) -> FoodQuality {
        let foodTypes = foodCommodityIDs.count { inventory[$0, default: 0] > 0 }
        guard foodTypes > 0 else { return .none }
        let hasSalt = inventory[saltCommodityID, default: 0] > 0
        let hasSpices = inventory[spicesCommodityID, default: 0] > 0

        if hasSpices && (foodTypes >= 4 || (hasSalt && foodTypes >= 3)) {
            return .delicious
        }
        if foodTypes >= 4
            || ((hasSalt || hasSpices) && foodTypes >= 3)
            || (hasSalt && hasSpices && foodTypes >= 2) {
            return .tasty
        }
        if foodTypes >= 3
            || ((hasSalt || hasSpices) && foodTypes >= 2)
            || (hasSalt && hasSpices && foodTypes >= 1) {
            return .appetizing
        }
        if foodTypes >= 2 || ((hasSalt || hasSpices) && foodTypes >= 1) {
            return .plain
        }
        return .bland
    }
}

public struct FoodMill: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let roadAccessPoint: GridPoint
    public let capacity: Int
    public var inventoryByCommodityID: [Int: Int]
    public var policyByCommodityID: [Int: WarehouseCommodityPolicy]
    public var storageLimitByCommodityID: [Int: Int]

    public init(
        id: Int,
        buildingID: Int = OriginalFoodCatalog.millBuildingID,
        roadAccessPoint: GridPoint,
        capacity: Int = OriginalFoodCatalog.millCapacity,
        inventoryByCommodityID: [Int: Int] = [:],
        policyByCommodityID: [Int: WarehouseCommodityPolicy] = [:],
        storageLimitByCommodityID: [Int: Int] = [:]
    ) {
        self.id = id
        self.buildingID = buildingID
        self.roadAccessPoint = roadAccessPoint
        self.capacity = max(0, capacity)
        self.inventoryByCommodityID = inventoryByCommodityID
        self.policyByCommodityID = policyByCommodityID
        self.storageLimitByCommodityID = storageLimitByCommodityID
    }

    public var storedAmount: Int { inventoryByCommodityID.values.reduce(0, +) }
    public var availableCapacity: Int { max(0, capacity - storedAmount) }
    public var foodQuality: FoodQuality { OriginalFoodCatalog.quality(in: inventoryByCommodityID) }

    public func policy(for commodityID: Int) -> WarehouseCommodityPolicy {
        policyByCommodityID[commodityID] ?? .get
    }

    public func storageLimit(for commodityID: Int) -> Int {
        min(capacity, max(0, storageLimitByCommodityID[commodityID] ?? capacity))
    }

    public func availableCapacity(for commodityID: Int) -> Int {
        guard OriginalFoodCatalog.isMillCommodity(commodityID),
              policy(for: commodityID) != .doNotAccept else { return 0 }
        let commoditySpace = max(
            0,
            storageLimit(for: commodityID) - inventoryByCommodityID[commodityID, default: 0]
        )
        return min(availableCapacity, commoditySpace)
    }
}
