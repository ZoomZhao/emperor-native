import Foundation

public enum TradeRouteKind: String, Sendable, Hashable, Codable {
    case land
    case sea

    public var buildingID: Int {
        switch self {
        case .land: 58 // Trading Station
        case .sea: 56  // Trading Quay
        }
    }

    public var traderFigureID: Int {
        switch self {
        case .land: 45 // Traders
        case .sea: 46  // Trading Junk
        }
    }
}

public enum TradeVolumeLevel: Int, CaseIterable, Sendable, Hashable, Codable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    /// Campaign Creator and the original manual define these as 12, 24 and
    /// 36 displayed loads per February-to-January accounting year.
    public var annualLoads: Int { rawValue * 12 }
}

public struct TradePartner: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public var name: String
    public var routeKind: TradeRouteKind
    public var isOpen: Bool
    /// Goods the partner buys from the player's city.
    public var demandByCommodityID: [Int: TradeVolumeLevel]
    /// Goods the partner sells to the player's city.
    public var supplyByCommodityID: [Int: TradeVolumeLevel]
    public var priceByCommodityID: [Int: Int]

    public init(
        id: Int,
        name: String,
        routeKind: TradeRouteKind,
        isOpen: Bool = true,
        demandByCommodityID: [Int: TradeVolumeLevel] = [:],
        supplyByCommodityID: [Int: TradeVolumeLevel] = [:],
        priceByCommodityID: [Int: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.routeKind = routeKind
        self.isOpen = isOpen
        self.demandByCommodityID = demandByCommodityID
        self.supplyByCommodityID = supplyByCommodityID
        self.priceByCommodityID = priceByCommodityID
    }
}

public struct TradingBuilding: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let partnerID: Int
    public let roadAccessPoint: GridPoint
    public var assignedWorkers: Int
    public let capacity: Int
    public var inventoryByCommodityID: [Int: Int]
    public var importingCommodityIDs: Set<Int>
    public var exportingCommodityIDs: Set<Int>
    public var storageLimitByCommodityID: [Int: Int]
    public var exportPriceByCommodityID: [Int: Int]
    public var activeDeliveryWalkerID: Int?
    public var accountingCycleStartYear: Int?
    public var importedUnitsThisCycleByCommodityID: [Int: Int]
    public var exportedUnitsThisCycleByCommodityID: [Int: Int]

    public init(
        id: Int,
        buildingID: Int,
        partnerID: Int,
        roadAccessPoint: GridPoint,
        assignedWorkers: Int,
        capacity: Int = 6_000
    ) {
        self.id = id
        self.buildingID = buildingID
        self.partnerID = partnerID
        self.roadAccessPoint = roadAccessPoint
        self.assignedWorkers = max(0, assignedWorkers)
        self.capacity = max(0, capacity)
        inventoryByCommodityID = [:]
        importingCommodityIDs = []
        exportingCommodityIDs = []
        storageLimitByCommodityID = [:]
        exportPriceByCommodityID = [:]
        activeDeliveryWalkerID = nil
        accountingCycleStartYear = nil
        importedUnitsThisCycleByCommodityID = [:]
        exportedUnitsThisCycleByCommodityID = [:]
    }

    public var storedAmount: Int { inventoryByCommodityID.values.reduce(0, +) }
    public var availableCapacity: Int { max(0, capacity - storedAmount) }

    public func storageLimit(for commodityID: Int) -> Int {
        min(capacity, max(0, storageLimitByCommodityID[commodityID] ?? capacity))
    }

    public func availableCapacity(for commodityID: Int) -> Int {
        min(
            availableCapacity,
            max(0, storageLimit(for: commodityID) - inventoryByCommodityID[commodityID, default: 0])
        )
    }
}

public enum TradeDirection: String, Sendable, Hashable, Codable {
    case imported
    case exported
}

public struct TradeTransaction: Sendable, Hashable, Codable {
    public let partnerID: Int
    public let tradingBuildingID: Int
    public let routeKind: TradeRouteKind
    public let direction: TradeDirection
    public let commodityID: Int
    public let amount: Int
    /// Price per displayed 100-unit load.
    public let loadPrice: Int
    public let cashAmount: Int

    public init(
        partnerID: Int,
        tradingBuildingID: Int,
        routeKind: TradeRouteKind,
        direction: TradeDirection,
        commodityID: Int,
        amount: Int,
        loadPrice: Int,
        cashAmount: Int
    ) {
        self.partnerID = partnerID
        self.tradingBuildingID = tradingBuildingID
        self.routeKind = routeKind
        self.direction = direction
        self.commodityID = commodityID
        self.amount = amount
        self.loadPrice = loadPrice
        self.cashAmount = cashAmount
    }
}

/// A complete authored-map visit from the route entry, through the player's
/// trading building, to the matching exit point.
public struct TradeVisitorRoute: Sendable, Hashable, Codable {
    public let points: [GridPoint]
    public let facilityPointIndex: Int

    public init?(points: [GridPoint], facilityPointIndex: Int) {
        guard points.count >= 3, points.indices.contains(facilityPointIndex) else { return nil }
        self.points = points
        self.facilityPointIndex = facilityPointIndex
    }
}

public struct ExternalTradeVisitor: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let partnerID: Int
    public let tradingBuildingID: Int
    public let routeKind: TradeRouteKind
    public let figureID: Int
    public let route: TradeVisitorRoute
    public var routeIndex: Int

    public var currentPoint: GridPoint { route.points[routeIndex] }
    public var hasReachedFacility: Bool { routeIndex >= route.facilityPointIndex }

    public init(
        id: Int,
        partnerID: Int,
        tradingBuildingID: Int,
        routeKind: TradeRouteKind,
        figureID: Int,
        route: TradeVisitorRoute,
        routeIndex: Int = 0
    ) {
        self.id = id
        self.partnerID = partnerID
        self.tradingBuildingID = tradingBuildingID
        self.routeKind = routeKind
        self.figureID = figureID
        self.route = route
        self.routeIndex = min(max(0, routeIndex), route.points.count - 1)
    }
}

public struct TradeMonthlySettlement: Sendable, Hashable, Codable {
    public let year: Int
    public let month: Int
    public let visitingPartnerIDs: [Int]
    public let transactions: [TradeTransaction]
    public let inactiveTradingBuildingIDs: [Int]

    public var importSpending: Int {
        transactions.filter { $0.direction == .imported }.reduce(0) { $0 + $1.cashAmount }
    }

    public var exportIncome: Int {
        transactions.filter { $0.direction == .exported }.reduce(0) { $0 + $1.cashAmount }
    }
}

public struct DeterministicTradeState: Sendable, Hashable, Codable {
    /// The user manual specifies 15 bays × four loads for either building.
    public static let originalTradingBuildingCapacity = 6_000

    public private(set) var partners: [TradePartner]
    public private(set) var buildings: [TradingBuilding]
    public private(set) var lastSettlement: TradeMonthlySettlement?
    private var nextBuildingID: Int
    // Optional fields keep native saves from releases before map-traversing
    // caravans and junks backwards compatible.
    private var visitorState: [ExternalTradeVisitor]?
    private var nextVisitorIDState: Int?

    public init() {
        partners = []
        buildings = []
        lastSettlement = nil
        nextBuildingID = 1
        visitorState = []
        nextVisitorIDState = 1
    }

    public var visitors: [ExternalTradeVisitor] { visitorState ?? [] }

    public var activePartnerCount: Int { partners.count(where: \.isOpen) }
    /// Open partners for which the player has actually built a station or quay.
    public var establishedPartnerCount: Int {
        let openIDs = Set(partners.filter(\.isOpen).map(\.id))
        return Set(buildings.lazy.map(\.partnerID).filter(openIDs.contains)).count
    }

    @discardableResult
    public mutating func addPartner(_ partner: TradePartner, tradeRules: TradeRules) -> Bool {
        let demand = partner.demandByCommodityID.filter { $0.value != .none }
        let supply = partner.supplyByCommodityID.filter { $0.value != .none }
        guard !partners.contains(where: { $0.id == partner.id }),
              demand.count <= 4,
              supply.count <= 4,
              demand.count + supply.count <= 8,
              Set(demand.keys).isDisjoint(with: Set(supply.keys)),
              demand.keys.allSatisfy({ tradeRules[commodityID: $0] != nil }),
              supply.keys.allSatisfy({ tradeRules[commodityID: $0] != nil }) else { return false }
        partners.append(partner)
        partners.sort { $0.id < $1.id }
        return true
    }

    public mutating func setPartnerOpen(_ open: Bool, partnerID: Int) {
        guard let index = partners.firstIndex(where: { $0.id == partnerID }) else { return }
        partners[index].isOpen = open
    }

    /// Trade-change events move demand/supply exactly one authored level:
    /// none, low (12 loads), medium (24), high (36).
    @discardableResult
    public mutating func adjustDemand(
        partnerID: Int,
        commodityID: Int,
        delta: Int,
        tradeRules: TradeRules
    ) -> Bool {
        guard delta != 0,
              tradeRules[commodityID: commodityID] != nil,
              let index = partners.firstIndex(where: { $0.id == partnerID }) else { return false }
        let old = partners[index].demandByCommodityID[commodityID, default: .none]
        let raw = min(TradeVolumeLevel.high.rawValue, max(0, old.rawValue + delta.signum()))
        guard let next = TradeVolumeLevel(rawValue: raw), next != old else { return false }
        if next == .none {
            partners[index].demandByCommodityID.removeValue(forKey: commodityID)
        } else {
            // A city cannot buy and sell the same commodity.
            partners[index].supplyByCommodityID.removeValue(forKey: commodityID)
            partners[index].demandByCommodityID[commodityID] = next
        }
        return true
    }

    @discardableResult
    public mutating func adjustSupply(
        partnerID: Int,
        commodityID: Int,
        delta: Int,
        tradeRules: TradeRules
    ) -> Bool {
        guard delta != 0,
              tradeRules[commodityID: commodityID] != nil,
              let index = partners.firstIndex(where: { $0.id == partnerID }) else { return false }
        let old = partners[index].supplyByCommodityID[commodityID, default: .none]
        let raw = min(TradeVolumeLevel.high.rawValue, max(0, old.rawValue + delta.signum()))
        guard let next = TradeVolumeLevel(rawValue: raw), next != old else { return false }
        if next == .none {
            partners[index].supplyByCommodityID.removeValue(forKey: commodityID)
        } else {
            partners[index].demandByCommodityID.removeValue(forKey: commodityID)
            partners[index].supplyByCommodityID[commodityID] = next
        }
        return true
    }

    /// Price events are imperial rather than city-specific. Apply the change
    /// to every installed partner that trades the selected commodity.
    @discardableResult
    public mutating func adjustPrice(
        commodityID: Int,
        delta: Int,
        defaultPrice: Int
    ) -> Int {
        guard delta != 0, defaultPrice > 0 else { return 0 }
        var changed = 0
        for index in partners.indices where
            partners[index].demandByCommodityID[commodityID] != nil
                || partners[index].supplyByCommodityID[commodityID] != nil {
            let current = partners[index].priceByCommodityID[commodityID] ?? defaultPrice
            partners[index].priceByCommodityID[commodityID] = max(1, current + delta)
            changed += 1
        }
        return changed
    }

    @discardableResult
    public mutating func addTradingBuilding(
        partnerID: Int,
        roadAccessPoint: GridPoint,
        assignedWorkers: Int,
        models: BuildingModelTable,
        roadNetwork: RoadNetwork
    ) -> Int? {
        guard let partner = partners.first(where: { $0.id == partnerID && $0.isOpen }),
              !buildings.contains(where: { $0.partnerID == partnerID }),
              roadNetwork.contains(roadAccessPoint),
              let model = models[buildingID: partner.routeKind.buildingID],
              model.employees > 0 else { return nil }
        let id = nextBuildingID
        nextBuildingID += 1
        buildings.append(TradingBuilding(
            id: id,
            buildingID: partner.routeKind.buildingID,
            partnerID: partnerID,
            roadAccessPoint: roadAccessPoint,
            assignedWorkers: min(max(0, assignedWorkers), model.employees),
            capacity: Self.originalTradingBuildingCapacity
        ))
        return id
    }

    public mutating func setImporting(
        _ enabled: Bool,
        commodityID: Int,
        tradingBuildingID: Int
    ) {
        guard let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }),
              let partner = partners.first(where: { $0.id == buildings[index].partnerID }),
              partner.supplyByCommodityID[commodityID, default: .none] != .none else { return }
        if enabled {
            buildings[index].importingCommodityIDs.insert(commodityID)
        } else {
            buildings[index].importingCommodityIDs.remove(commodityID)
        }
    }

    public mutating func setExporting(
        _ enabled: Bool,
        commodityID: Int,
        tradingBuildingID: Int
    ) {
        guard let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }),
              let partner = partners.first(where: { $0.id == buildings[index].partnerID }),
              partner.demandByCommodityID[commodityID, default: .none] != .none else { return }
        if enabled {
            buildings[index].exportingCommodityIDs.insert(commodityID)
        } else {
            buildings[index].exportingCommodityIDs.remove(commodityID)
        }
    }

    public mutating func setStorageLimit(
        _ amount: Int,
        commodityID: Int,
        tradingBuildingID: Int
    ) {
        guard let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }) else { return }
        // Original UI limits are whole displayed loads.
        buildings[index].storageLimitByCommodityID[commodityID] = min(
            buildings[index].capacity,
            max(0, amount) / 100 * 100
        )
    }

    public mutating func setExportPrice(
        _ loadPrice: Int,
        commodityID: Int,
        tradingBuildingID: Int
    ) {
        guard let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }), loadPrice > 0 else { return }
        buildings[index].exportPriceByCommodityID[commodityID] = loadPrice
    }

    public mutating func setAssignedWorkers(
        _ count: Int,
        tradingBuildingID: Int,
        models: BuildingModelTable
    ) {
        guard let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }),
              let model = models[buildingID: buildings[index].buildingID] else { return }
        buildings[index].assignedWorkers = min(max(0, count), model.employees)
    }

    public func partner(id: Int) -> TradePartner? { partners.first { $0.id == id } }
    public func building(id: Int) -> TradingBuilding? { buildings.first { $0.id == id } }

    /// Removes a station or quay while leaving its world-map route open. The
    /// player may therefore rebuild the facility for that same partner later.
    @discardableResult
    public mutating func removeTradingBuilding(id: Int) -> TradingBuilding? {
        guard let index = buildings.firstIndex(where: { $0.id == id }) else { return nil }
        var activeVisitors = visitorState ?? []
        activeVisitors.removeAll { $0.tradingBuildingID == id }
        visitorState = activeVisitors
        return buildings.remove(at: index)
    }

    /// Moves every physical caravan/junk along its complete authored route and
    /// removes visitors only after they reach the matching map exit.
    @discardableResult
    public mutating func advanceVisitors(stepsPerVisitor: Int) -> Int {
        guard stepsPerVisitor > 0 else { return 0 }
        var active = visitorState ?? []
        var moved = 0
        for index in active.indices {
            let old = active[index].routeIndex
            active[index].routeIndex = min(
                active[index].route.points.count - 1,
                old + stepsPerVisitor
            )
            moved += active[index].routeIndex - old
        }
        active.removeAll { $0.routeIndex == $0.route.points.count - 1 }
        visitorState = active
        return moved
    }

    public func localInventory(tradingBuildingID: Int, commodityID: Int) -> Int {
        building(id: tradingBuildingID)?.inventoryByCommodityID[commodityID, default: 0] ?? 0
    }

    public func availableCapacity(tradingBuildingID: Int, commodityID: Int) -> Int {
        building(id: tradingBuildingID)?.availableCapacity(for: commodityID) ?? 0
    }

    public func exportStockDemand(tradingBuildingID: Int, commodityID: Int) -> Int {
        guard let building = building(id: tradingBuildingID),
              building.exportingCommodityIDs.contains(commodityID) else { return 0 }
        return max(
            0,
            building.storageLimit(for: commodityID)
                - building.inventoryByCommodityID[commodityID, default: 0]
        )
    }

    @discardableResult
    public mutating func takeLocalInventory(
        tradingBuildingID: Int,
        commodityID: Int,
        amount: Int
    ) -> Int {
        guard amount > 0,
              let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }) else { return 0 }
        let available = buildings[index].inventoryByCommodityID[commodityID, default: 0]
        let taken = min(amount, available)
        buildings[index].inventoryByCommodityID[commodityID] = available - taken
        return taken
    }

    public mutating func addLocalInventory(
        tradingBuildingID: Int,
        commodityID: Int,
        amount: Int
    ) {
        guard amount > 0,
              let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }) else { return }
        let accepted = min(amount, buildings[index].availableCapacity(for: commodityID))
        buildings[index].inventoryByCommodityID[commodityID, default: 0] += accepted
    }

    public mutating func setActiveDeliveryWalker(_ walkerID: Int?, tradingBuildingID: Int) {
        guard let index = buildings.firstIndex(where: { $0.id == tradingBuildingID }) else { return }
        buildings[index].activeDeliveryWalkerID = walkerID
    }

    @discardableResult
    public mutating func advanceMonth(
        calendar: SimulationCalendar,
        economy: inout DeterministicEconomyState,
        models: OriginalEconomyModels,
        visitorRoutesByBuildingID: [Int: TradeVisitorRoute]? = nil
    ) -> TradeMonthlySettlement {
        let cycleStartYear = calendar.month == 1 ? calendar.year - 1 : calendar.year
        let elapsedMonths = calendar.month == 1 ? 12 : calendar.month - 1
        var transactions: [TradeTransaction] = []
        var visitors: [Int] = []
        var inactive: [Int] = []

        for index in buildings.indices.sorted(by: { buildings[$0].id < buildings[$1].id }) {
            guard let partner = partners.first(where: { $0.id == buildings[index].partnerID }),
                  let model = models.buildings[buildingID: buildings[index].buildingID],
                  partner.isOpen,
                  buildings[index].assignedWorkers >= model.employees else {
                inactive.append(buildings[index].id)
                continue
            }
            let visitorRoute = visitorRoutesByBuildingID?[buildings[index].id]
            if visitorRoutesByBuildingID != nil, visitorRoute == nil {
                inactive.append(buildings[index].id)
                continue
            }
            if buildings[index].accountingCycleStartYear != cycleStartYear {
                buildings[index].accountingCycleStartYear = cycleStartYear
                buildings[index].importedUnitsThisCycleByCommodityID = [:]
                buildings[index].exportedUnitsThisCycleByCommodityID = [:]
            }
            visitors.append(partner.id)
            if let visitorRoute,
               !(visitorState ?? []).contains(where: { $0.tradingBuildingID == buildings[index].id }) {
                var active = visitorState ?? []
                let visitorID = nextVisitorIDState ?? ((active.map(\.id).max() ?? 0) + 1)
                active.append(ExternalTradeVisitor(
                    id: visitorID,
                    partnerID: partner.id,
                    tradingBuildingID: buildings[index].id,
                    routeKind: partner.routeKind,
                    figureID: partner.routeKind.traderFigureID,
                    route: visitorRoute
                ))
                visitorState = active
                nextVisitorIDState = visitorID + 1
            }
            let routeCapacity = partner.routeKind == .land
                ? models.trade.landCapacity
                : models.trade.seaCapacity

            // A caravan/junk may buy and sell up to its capacity independently.
            var exportCapacity = routeCapacity
            for commodityID in buildings[index].exportingCommodityIDs.sorted() where exportCapacity >= 100 {
                let level = partner.demandByCommodityID[commodityID, default: .none]
                let allowedToDate = level.annualLoads * elapsedMonths * 100 / 12
                let remainingQuota = max(
                    0,
                    allowedToDate - buildings[index].exportedUnitsThisCycleByCommodityID[commodityID, default: 0]
                )
                let available = buildings[index].inventoryByCommodityID[commodityID, default: 0]
                let amount = min(remainingQuota, available, exportCapacity) / 100 * 100
                guard amount > 0 else { continue }
                let defaultPrice = partner.priceByCommodityID[commodityID]
                    ?? models.trade[commodityID: commodityID]?.price
                    ?? 0
                let price = buildings[index].exportPriceByCommodityID[commodityID] ?? defaultPrice
                let cash = amount / 100 * max(0, price)
                buildings[index].inventoryByCommodityID[commodityID, default: 0] -= amount
                buildings[index].exportedUnitsThisCycleByCommodityID[commodityID, default: 0] += amount
                exportCapacity -= amount
                economy.credit(cash)
                transactions.append(TradeTransaction(
                    partnerID: partner.id,
                    tradingBuildingID: buildings[index].id,
                    routeKind: partner.routeKind,
                    direction: .exported,
                    commodityID: commodityID,
                    amount: amount,
                    loadPrice: price,
                    cashAmount: cash
                ))
            }

            var importCapacity = routeCapacity
            for commodityID in buildings[index].importingCommodityIDs.sorted() where importCapacity >= 100 {
                let level = partner.supplyByCommodityID[commodityID, default: .none]
                let allowedToDate = level.annualLoads * elapsedMonths * 100 / 12
                let remainingQuota = max(
                    0,
                    allowedToDate - buildings[index].importedUnitsThisCycleByCommodityID[commodityID, default: 0]
                )
                let storage = buildings[index].availableCapacity(for: commodityID)
                let price = partner.priceByCommodityID[commodityID]
                    ?? models.trade[commodityID: commodityID]?.price
                    ?? 0
                let affordable = price > 0 ? economy.treasury / price * 100 : remainingQuota
                let amount = min(remainingQuota, storage, importCapacity, affordable) / 100 * 100
                guard amount > 0 else { continue }
                let cash = amount / 100 * max(0, price)
                guard price == 0 || economy.debit(cash) else { continue }
                buildings[index].inventoryByCommodityID[commodityID, default: 0] += amount
                buildings[index].importedUnitsThisCycleByCommodityID[commodityID, default: 0] += amount
                importCapacity -= amount
                transactions.append(TradeTransaction(
                    partnerID: partner.id,
                    tradingBuildingID: buildings[index].id,
                    routeKind: partner.routeKind,
                    direction: .imported,
                    commodityID: commodityID,
                    amount: amount,
                    loadPrice: price,
                    cashAmount: cash
                ))
            }
        }

        let settlement = TradeMonthlySettlement(
            year: calendar.year,
            month: calendar.month,
            visitingPartnerIDs: visitors,
            transactions: transactions,
            inactiveTradingBuildingIDs: inactive
        )
        lastSettlement = settlement
        return settlement
    }
}
