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

/// The type-count and amount selected by the unsplit mill recipe selector
/// (`FUN_00555330 @ 0x555330`, reached through the mill vtable `+0x2E4`).
/// This is a raw recipe primitive: the executable copies the selected type
/// count onto cart `figure+0x13`, and a later market callback turns that byte
/// into its own quality contribution. It is not a `FoodQuality` band.
public struct OriginalMillFoodRecipeSelection: Sendable, Hashable {
    public let typeCount: Int
    public let selectedAvailability: Int
    public let amount: Int

    public init(typeCount: Int, selectedAvailability: Int, amount: Int) {
        self.typeCount = typeCount
        self.selectedAvailability = selectedAvailability
        self.amount = amount
    }
}

public enum OriginalMillFoodRecipeSelector {
    /// Replays the recovered selector at `0x555330`.
    ///
    /// `availabilityByType` is indexed by the mill recipe type count; index
    /// zero is ignored. The source materializes the availability snapshot,
    /// then scans `firstTypeCount…maxTypeCount` in ascending order for the
    /// selection pass. A type replaces the current choice whenever its
    /// availability is strictly greater than `requestedAmount / 3`; if no
    /// type clears that threshold, the first non-zero type remains selected.
    /// The returned amount is clipped to the request, selected availability,
    /// and the original 600-unit cart bound.
    public static func select(
        availabilityByType: [Int],
        firstTypeCount: Int = 1,
        maxTypeCount: Int,
        requestedAmount: Int
    ) -> OriginalMillFoodRecipeSelection? {
        guard maxTypeCount >= firstTypeCount,
              firstTypeCount >= 1,
              availabilityByType.count > maxTypeCount else { return nil }

        let threshold = requestedAmount / 3
        var selectedTypeCount = 0
        var selectedAvailability = 0
        for typeCount in firstTypeCount...maxTypeCount {
            let availability = availabilityByType[typeCount]
            if availability > threshold {
                selectedTypeCount = typeCount
                selectedAvailability = availability
            } else if selectedTypeCount == 0, availability > 0 {
                selectedTypeCount = typeCount
                selectedAvailability = availability
            }
        }

        guard selectedTypeCount != 0 else { return nil }
        return .init(
            typeCount: selectedTypeCount,
            selectedAvailability: selectedAvailability,
            amount: min(requestedAmount, selectedAvailability, 600)
        )
    }
}

/// The six-slot food bundle written by the original mill callback
/// (`FUN_005557D0 @ 0x5557D0`).  Commodity IDs are returned in the exact
/// ascending scan order used by the executable; the remaining output slots
/// stay at `-1/0` in the original caller and are not represented here.
public struct OriginalMillFoodBundleSelection: Sendable, Hashable {
    public let typeCount: Int
    public let perCommodityAmount: Int
    public let commodityIDs: [Int]
    public let amountByCommodityID: [Int: Int]
    public let totalAmount: Int

    public init(
        typeCount: Int,
        perCommodityAmount: Int,
        commodityIDs: [Int],
        amountByCommodityID: [Int: Int],
        totalAmount: Int
    ) {
        self.typeCount = typeCount
        self.perCommodityAmount = perCommodityAmount
        self.commodityIDs = commodityIDs
        self.amountByCommodityID = amountByCommodityID
        self.totalAmount = totalAmount
    }
}

public enum OriginalMillFoodBundleComposer {
    /// Replays the recovered six-slot writer at `0x5557D0`.
    ///
    /// The caller (`FUN_00555410`) supplies a positive requested amount and a
    /// type count from 1 through 5.  The writer rounds down to a 100-unit
    /// multiple per selected commodity, then repeatedly subtracts 100 units
    /// from that amount until the six-slot bundle is no larger than 600.  It
    /// scans commodity IDs 1…9, while `FUN_00555F70` admits exactly 1…7, and
    /// accepts inventory equal to the rounded amount (`<=`, not `<`).
    ///
    /// A nil result is the source's `return 0` when fewer than `typeCount`
    /// eligible commodities exist.  Inventory is deliberately supplied by
    /// the caller: the original virtual `+0x264` quantity and its mapping to
    /// Native storage remain unresolved, so this helper is research-only.
    public static func compose(
        inventoryByCommodityID: [Int: Int],
        typeCount: Int,
        requestedAmount: Int
    ) -> OriginalMillFoodBundleSelection? {
        guard (1...5).contains(typeCount), requestedAmount > 0 else { return nil }

        let rounded = (requestedAmount / typeCount / 100) * 100
        let perCommodityAmount = min(rounded, (600 / typeCount / 100) * 100)
        let selectedIDs = (1...7).filter {
            inventoryByCommodityID[$0, default: 0] >= perCommodityAmount
        }.prefix(typeCount)
        guard selectedIDs.count == typeCount else { return nil }

        let commodityIDs = Array(selectedIDs)
        let amountByCommodityID = Dictionary(
            uniqueKeysWithValues: commodityIDs.map { ($0, perCommodityAmount) }
        )
        return .init(
            typeCount: typeCount,
            perCommodityAmount: perCommodityAmount,
            commodityIDs: commodityIDs,
            amountByCommodityID: amountByCommodityID,
            totalAmount: perCommodityAmount * typeCount
        )
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
        // The original mill opens with every food order set to Accept.  Get
        // is an explicit player order that pulls a commodity from a nearby
        // warehouse; it is not the default state.
        policyByCommodityID[commodityID] ?? .accept
    }

    public func storageLimit(for commodityID: Int) -> Int {
        min(capacity, max(0, storageLimitByCommodityID[commodityID] ?? capacity))
    }

    public func availableCapacity(for commodityID: Int) -> Int {
        guard OriginalFoodCatalog.isMillCommodity(commodityID),
              policy(for: commodityID) != .doNotAccept,
              policy(for: commodityID) != .empty else { return 0 }
        let commoditySpace = max(
            0,
            storageLimit(for: commodityID) - inventoryByCommodityID[commodityID, default: 0]
        )
        return min(availableCapacity, commoditySpace)
    }
}
