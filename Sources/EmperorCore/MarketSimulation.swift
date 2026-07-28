import Foundation

public enum OriginalMarketCatalog {
    public static let commonMarketBuildingID = 59
    public static let grandMarketBuildingID = 60
    public static let buyerFigureID = 24
    public static let peddlerFigureID = 23

    public static func shopCapacity(forMarketBuildingID buildingID: Int) -> Int? {
        switch buildingID {
        case commonMarketBuildingID: 4
        case grandMarketBuildingID: 6
        default: nil
        }
    }

    public static func peddlerCapacity(forMarketBuildingID buildingID: Int) -> Int? {
        switch buildingID {
        case commonMarketBuildingID: 2
        // The grand market has six authored shop bays and must be able to
        // dispatch their specialist sellers together; otherwise the elite
        // housing chain deadlocks once food, hemp, ceramics, silk, and luxury
        // wares are required in the same month.
        case grandMarketBuildingID: 6
        default: nil
        }
    }

    public static func commodityID(forShopBuildingID buildingID: Int) -> Int? {
        switch buildingID {
        case 64: 23 // Bronzeware
        case 65: 25 // Ceramics
        case 67: 19 // Hemp
        case 68: 22 // Lacquerware
        case 69: 24 // Silk
        case 70: 13 // Tea
        default: nil // Food shop is handled with the mill/food-quality system.
        }
    }

    public static func supports(shopBuildingID: Int) -> Bool {
        shopBuildingID == OriginalFoodCatalog.foodShopBuildingID
            || commodityID(forShopBuildingID: shopBuildingID) != nil
    }
}

public struct MarketSquare: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let roadAccessPoint: GridPoint
    public let shopBuildingIDs: [Int]
    public var inventoryByCommodityID: [Int: Int]
    public var activeBuyerByCommodityID: [Int: Int]

    public var peddlerCapacity: Int {
        OriginalMarketCatalog.peddlerCapacity(forMarketBuildingID: buildingID) ?? 0
    }

    public init(
        id: Int,
        buildingID: Int,
        roadAccessPoint: GridPoint,
        shopBuildingIDs: [Int],
        inventoryByCommodityID: [Int: Int] = [:],
        activeBuyerByCommodityID: [Int: Int] = [:]
    ) {
        self.id = id
        self.buildingID = buildingID
        self.roadAccessPoint = roadAccessPoint
        self.shopBuildingIDs = shopBuildingIDs
        self.inventoryByCommodityID = inventoryByCommodityID
        self.activeBuyerByCommodityID = activeBuyerByCommodityID
    }

    public var stockedCommodityIDs: [Int] {
        shopBuildingIDs.compactMap(OriginalMarketCatalog.commodityID(forShopBuildingID:))
    }

    public var hasFoodShop: Bool {
        shopBuildingIDs.contains(OriginalFoodCatalog.foodShopBuildingID)
    }
}

public struct MarketBuyer: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let figureID: Int
    public let marketID: Int
    public let warehouseID: Int?
    public let millID: Int?
    public let cargoes: [DeliveryCargo]
    public let route: [GridPoint]
    public let warehouseRouteIndex: Int
    public private(set) var routeIndex: Int
    public private(set) var hasReachedWarehouse: Bool

    public var currentPoint: GridPoint? {
        route.indices.contains(routeIndex) ? route[routeIndex] : nil
    }

    public var hasReturned: Bool {
        hasReachedWarehouse && routeIndex == route.count - 1
    }

    init(
        id: Int,
        marketID: Int,
        warehouseID: Int? = nil,
        millID: Int? = nil,
        cargoes: [DeliveryCargo],
        outboundPath: [GridPoint]
    ) {
        self.id = id
        figureID = OriginalMarketCatalog.buyerFigureID
        self.marketID = marketID
        self.warehouseID = warehouseID
        self.millID = millID
        self.cargoes = cargoes
        warehouseRouteIndex = max(0, outboundPath.count - 1)
        route = outboundPath + Array(outboundPath.dropLast().reversed())
        routeIndex = 0
        hasReachedWarehouse = outboundPath.count == 1
    }

    private enum CodingKeys: String, CodingKey {
        case id, figureID, marketID, warehouseID, millID, cargo, cargoes, route
        case warehouseRouteIndex, routeIndex, hasReachedWarehouse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        figureID = try container.decode(Int.self, forKey: .figureID)
        marketID = try container.decode(Int.self, forKey: .marketID)
        warehouseID = try container.decodeIfPresent(Int.self, forKey: .warehouseID)
        millID = try container.decodeIfPresent(Int.self, forKey: .millID)
        if let decoded = try container.decodeIfPresent([DeliveryCargo].self, forKey: .cargoes) {
            cargoes = decoded
        } else if let legacy = try container.decodeIfPresent(DeliveryCargo.self, forKey: .cargo) {
            cargoes = [legacy]
        } else {
            cargoes = []
        }
        route = try container.decode([GridPoint].self, forKey: .route)
        warehouseRouteIndex = try container.decode(Int.self, forKey: .warehouseRouteIndex)
        routeIndex = try container.decode(Int.self, forKey: .routeIndex)
        hasReachedWarehouse = try container.decode(Bool.self, forKey: .hasReachedWarehouse)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(figureID, forKey: .figureID)
        try container.encode(marketID, forKey: .marketID)
        try container.encodeIfPresent(warehouseID, forKey: .warehouseID)
        try container.encodeIfPresent(millID, forKey: .millID)
        try container.encode(cargoes, forKey: .cargoes)
        try container.encode(route, forKey: .route)
        try container.encode(warehouseRouteIndex, forKey: .warehouseRouteIndex)
        try container.encode(routeIndex, forKey: .routeIndex)
        try container.encode(hasReachedWarehouse, forKey: .hasReachedWarehouse)
    }

    mutating func advanceOneRoadStep() -> Bool {
        guard routeIndex + 1 < route.count else { return false }
        routeIndex += 1
        if routeIndex == warehouseRouteIndex { hasReachedWarehouse = true }
        return true
    }
}

public struct MarketPeddler: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let figureID: Int
    public let marketID: Int
    public let commodityID: Int
    public let route: [GridPoint]
    public let foodQualityRawValue: Int?
    public private(set) var routeIndex: Int
    public private(set) var remainingAmount: Int
    public private(set) var foodCargoes: [DeliveryCargo]?

    public var currentPoint: GridPoint? {
        route.indices.contains(routeIndex) ? route[routeIndex] : nil
    }

    public var hasCompletedRoute: Bool {
        route.isEmpty || routeIndex == route.count - 1
    }

    init(
        id: Int,
        marketID: Int,
        commodityID: Int,
        amount: Int,
        route: [GridPoint],
        foodQuality: FoodQuality? = nil,
        foodCargoes: [DeliveryCargo]? = nil
    ) {
        self.id = id
        figureID = OriginalMarketCatalog.peddlerFigureID
        self.marketID = marketID
        self.commodityID = commodityID
        self.route = route
        foodQualityRawValue = foodQuality?.rawValue
        routeIndex = 0
        remainingAmount = max(0, amount)
        self.foodCargoes = foodCargoes
    }

    mutating func advanceOneRoadStep() -> Bool {
        guard routeIndex + 1 < route.count else { return false }
        routeIndex += 1
        return true
    }

    mutating func deliver(_ amount: Int) -> Int {
        let delivered = min(max(0, amount), remainingAmount)
        remainingAmount -= delivered
        if var cargoes = foodCargoes, delivered > 0 {
            var toConsume = delivered
            for index in cargoes.indices where toConsume > 0 {
                let taken = min(toConsume, cargoes[index].amount)
                cargoes[index] = DeliveryCargo(
                    commodityID: cargoes[index].commodityID,
                    amount: cargoes[index].amount - taken
                )
                toConsume -= taken
            }
            foodCargoes = cargoes.filter { $0.amount > 0 }
        }
        return delivered
    }
}

public struct HouseholdCommodityDelivery: Sendable, Hashable, Codable {
    public let houseID: Int
    public let commodityID: Int
    public let amount: Int

    public init(houseID: Int, commodityID: Int, amount: Int) {
        self.houseID = houseID
        self.commodityID = commodityID
        self.amount = amount
    }
}

public struct HouseholdCommodityConsumption: Sendable, Hashable, Codable {
    public let houseID: Int
    public let commodityID: Int
    public let requestedAmount: Int
    public let consumedAmount: Int

    public init(
        houseID: Int,
        commodityID: Int,
        requestedAmount: Int,
        consumedAmount: Int
    ) {
        self.houseID = houseID
        self.commodityID = commodityID
        self.requestedAmount = requestedAmount
        self.consumedAmount = consumedAmount
    }
}

public struct MarketMonthlySettlement: Sendable, Hashable, Codable {
    public let purchasedLoads: [DeliveryCargo]
    public let householdDeliveries: [HouseholdCommodityDelivery]
    public let householdConsumption: [HouseholdCommodityConsumption]
    public let underSuppliedHouseIDs: [Int]
}

public struct DeterministicMarketState: Sendable, Hashable, Codable {
    public private(set) var markets: [MarketSquare]
    public private(set) var buyers: [MarketBuyer]
    public private(set) var peddlers: [MarketPeddler]
    public private(set) var lastSettlement: MarketMonthlySettlement?
    private var nextMarketID: Int
    private var nextBuyerID: Int
    private var nextPeddlerID: Int
    // Optional so saves written before continuous market movement still decode.
    private var purchasedLoadsThisMonthStorage: [DeliveryCargo]?
    private var householdDeliveriesThisMonthStorage: [HouseholdCommodityDelivery]?

    public init() {
        markets = []
        buyers = []
        peddlers = []
        lastSettlement = nil
        nextMarketID = 1
        nextBuyerID = 1
        nextPeddlerID = 1
        purchasedLoadsThisMonthStorage = []
        householdDeliveriesThisMonthStorage = []
    }

    @discardableResult
    public mutating func addMarket(
        buildingID: Int,
        roadAccessPoint: GridPoint,
        shopBuildingIDs: [Int],
        roadNetwork: RoadNetwork
    ) -> Int? {
        guard roadNetwork.contains(roadAccessPoint),
              let capacity = OriginalMarketCatalog.shopCapacity(forMarketBuildingID: buildingID),
              !shopBuildingIDs.isEmpty,
              shopBuildingIDs.count <= capacity,
              shopBuildingIDs.allSatisfy(OriginalMarketCatalog.supports(shopBuildingID:)) else {
            return nil
        }
        let id = nextMarketID
        nextMarketID += 1
        markets.append(MarketSquare(
            id: id,
            buildingID: buildingID,
            roadAccessPoint: roadAccessPoint,
            shopBuildingIDs: shopBuildingIDs
        ))
        return id
    }

    /// Removes a market and every buyer/peddler owned by it. Their carried
    /// goods disappear with the demolished market.
    @discardableResult
    public mutating func removeMarket(id: Int) -> MarketSquare? {
        guard let index = markets.firstIndex(where: { $0.id == id }) else { return nil }
        buyers.removeAll { $0.marketID == id }
        peddlers.removeAll { $0.marketID == id }
        return markets.remove(at: index)
    }

    @discardableResult
    public mutating func cancelBuyers(targetingWarehouseID warehouseID: Int) -> [Int] {
        cancelBuyers { $0.warehouseID == warehouseID }
    }

    @discardableResult
    public mutating func cancelBuyers(targetingMillID millID: Int) -> [Int] {
        cancelBuyers { $0.millID == millID }
    }

    /// Cancels market travelers whose authored route used a removed road.
    @discardableResult
    public mutating func cancelTravelers(using point: GridPoint) -> [Int] {
        let buyerIDs = cancelBuyers { $0.route.contains(point) }
        let peddlerIDs = peddlers.filter { $0.route.contains(point) }.map(\.id)
        let peddlerIDSet = Set(peddlerIDs)
        peddlers.removeAll { peddlerIDSet.contains($0.id) }
        return (buyerIDs + peddlerIDs).sorted()
    }

    private mutating func cancelBuyers(
        where shouldCancel: (MarketBuyer) -> Bool
    ) -> [Int] {
        let ids = Set(buyers.filter(shouldCancel).map(\.id))
        guard !ids.isEmpty else { return [] }
        buyers.removeAll { ids.contains($0.id) }
        for index in markets.indices {
            markets[index].activeBuyerByCommodityID = markets[index]
                .activeBuyerByCommodityID.filter { !ids.contains($0.value) }
        }
        return ids.sorted()
    }

    @discardableResult
    public mutating func advanceMonth(
        houses: inout [ResidentialUnit],
        logistics: inout DeterministicLogisticsState,
        production: inout DeterministicProductionState,
        roadNetwork: RoadNetwork,
        models: OriginalEconomyModels,
        replaySeed: UInt64
    ) -> MarketMonthlySettlement {
        let buyerRange = max(1, models.figures[figureID: OriginalMarketCatalog.buyerFigureID]?.behaviorRange ?? 50)
        let peddlerRange = max(1, models.figures[figureID: OriginalMarketCatalog.peddlerFigureID]?.behaviorRange ?? 60)
        scheduleBuyers(
            houses: houses,
            logistics: &logistics,
            production: &production,
            roadNetwork: roadNetwork,
            models: models.buildings,
            maximumOneWayRoadSteps: buyerRange
        )
        _ = advanceBuyers(roadStepsPerBuyer: buyerRange)
        schedulePeddlers(
            houses: houses,
            roadNetwork: roadNetwork,
            models: models.buildings,
            maximumRoadSteps: peddlerRange,
            replaySeed: replaySeed
        )
        _ = advancePeddlers(
            roadStepsPerPeddler: peddlerRange,
            houses: &houses,
            models: models.buildings
        )
        return settleMonth(houses: &houses, models: models.buildings)
    }

    /// Consumes household stock and closes the current market accounting month.
    /// Buyer and peddler movement must happen through the explicit step methods.
    @discardableResult
    public mutating func settleMonth(
        houses: inout [ResidentialUnit],
        models: BuildingModelTable
    ) -> MarketMonthlySettlement {
        let consumption = consumeHouseholdCommodities(
            houses: &houses,
            models: models
        )
        let underSupplied = Set(
            consumption.filter { $0.consumedAmount < $0.requestedAmount }.map(\.houseID)
        ).sorted()
        let settlement = MarketMonthlySettlement(
            purchasedLoads: purchasedLoadsThisMonthStorage ?? [],
            householdDeliveries: householdDeliveriesThisMonthStorage ?? [],
            householdConsumption: consumption,
            underSuppliedHouseIDs: underSupplied
        )
        lastSettlement = settlement
        purchasedLoadsThisMonthStorage = []
        householdDeliveriesThisMonthStorage = []
        return settlement
    }

    public mutating func scheduleBuyers(
        houses: [ResidentialUnit],
        logistics: inout DeterministicLogisticsState,
        production: inout DeterministicProductionState,
        roadNetwork: RoadNetwork,
        models: BuildingModelTable,
        maximumOneWayRoadSteps: Int,
        activeMarketIDs: Set<Int>? = nil,
        activeMillIDs: Set<Int>? = nil
    ) {
        for marketIndex in markets.indices.sorted(by: { markets[$0].id < markets[$1].id }) {
            let marketID = markets[marketIndex].id
            guard activeMarketIDs?.contains(marketID) ?? true else { continue }
            let marketRoad = markets[marketIndex].roadAccessPoint
            for commodityID in markets[marketIndex].stockedCommodityIDs.sorted() {
                guard markets[marketIndex].inventoryByCommodityID[commodityID, default: 0] < 100,
                      markets[marketIndex].activeBuyerByCommodityID[commodityID] == nil,
                      houses.contains(where: { Self.house($0, needs: commodityID, models: models) }),
                      let target = nearestWarehouse(
                        commodityID: commodityID,
                        marketRoad: marketRoad,
                        logistics: logistics,
                        roadNetwork: roadNetwork,
                        maximumSteps: maximumOneWayRoadSteps
                      ) else { continue }
                let amount = min(100, target.available)
                let taken = logistics.takeStoredGoods(
                    warehouseID: target.warehouseID,
                    commodityID: commodityID,
                    amount: amount,
                    production: &production
                )
                guard taken > 0 else { continue }
                let buyerID = nextBuyerID
                nextBuyerID += 1
                buyers.append(MarketBuyer(
                    id: buyerID,
                    marketID: marketID,
                    warehouseID: target.warehouseID,
                    cargoes: [DeliveryCargo(commodityID: commodityID, amount: taken)],
                    outboundPath: target.path
                ))
                markets[marketIndex].activeBuyerByCommodityID[commodityID] = buyerID
            }

            let storedFood = markets[marketIndex].inventoryByCommodityID.reduce(0) { partial, entry in
                partial + (OriginalFoodCatalog.isMillCommodity(entry.key) ? entry.value : 0)
            }
            if markets[marketIndex].hasFoodShop,
               storedFood < 100,
               markets[marketIndex].activeBuyerByCommodityID[-1] == nil,
               houses.contains(where: { Self.houseNeedsFood($0, models: models) }),
               let target = nearestMill(
                marketRoad: marketRoad,
                logistics: logistics,
                roadNetwork: roadNetwork,
                maximumSteps: maximumOneWayRoadSteps,
                activeMillIDs: activeMillIDs
               ) {
                let cargoes = logistics.takeFoodBundle(
                    millID: target.millID,
                    maximumAmount: 100,
                    production: &production
                )
                if !cargoes.isEmpty {
                    let buyerID = nextBuyerID
                    nextBuyerID += 1
                    buyers.append(MarketBuyer(
                        id: buyerID,
                        marketID: marketID,
                        millID: target.millID,
                        cargoes: cargoes,
                        outboundPath: target.path
                    ))
                    markets[marketIndex].activeBuyerByCommodityID[-1] = buyerID
                }
            }
        }
    }

    public mutating func advanceBuyers(
        roadStepsPerBuyer: Int,
        activeMarketIDs: Set<Int>? = nil
    ) -> [DeliveryCargo] {
        var purchased: [DeliveryCargo] = []
        var completedIDs: [Int] = []
        for index in buyers.indices.sorted(by: { buyers[$0].id < buyers[$1].id }) {
            guard activeMarketIDs?.contains(buyers[index].marketID) ?? true else { continue }
            for _ in 0..<max(0, roadStepsPerBuyer) {
                _ = buyers[index].advanceOneRoadStep()
                if buyers[index].hasReturned { break }
            }
            guard buyers[index].hasReturned,
                  let marketIndex = markets.firstIndex(where: { $0.id == buyers[index].marketID }) else { continue }
            for cargo in buyers[index].cargoes {
                markets[marketIndex].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
            }
            markets[marketIndex].activeBuyerByCommodityID = markets[marketIndex]
                .activeBuyerByCommodityID.filter { $0.value != buyers[index].id }
            purchased.append(contentsOf: buyers[index].cargoes)
            completedIDs.append(buyers[index].id)
        }
        buyers.removeAll { completedIDs.contains($0.id) }
        purchasedLoadsThisMonthStorage = (purchasedLoadsThisMonthStorage ?? []) + purchased
        return purchased
    }

    public mutating func schedulePeddlers(
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        models: BuildingModelTable,
        maximumRoadSteps: Int,
        replaySeed: UInt64,
        activeMarketIDs: Set<Int>? = nil
    ) {
        for marketIndex in markets.indices.sorted(by: { markets[$0].id < markets[$1].id }) {
            let marketID = markets[marketIndex].id
            guard activeMarketIDs?.contains(marketID) ?? true else { continue }
            var freeSlots = markets[marketIndex].peddlerCapacity
                - peddlers.count(where: { $0.marketID == marketID })
            guard freeSlots > 0 else { continue }
            for commodityID in markets[marketIndex].stockedCommodityIDs.sorted() where freeSlots > 0 {
                let available = markets[marketIndex].inventoryByCommodityID[commodityID, default: 0]
                guard available > 0,
                      !peddlers.contains(where: { $0.marketID == marketID && $0.commodityID == commodityID }),
                      houses.contains(where: { Self.house($0, needs: commodityID, models: models) }) else { continue }
                let amount = min(100, available)
                let route = Self.deliveryRoute(
                    from: markets[marketIndex].roadAccessPoint,
                    commodityID: commodityID,
                    houses: houses,
                    models: models,
                    roadNetwork: roadNetwork,
                    maximumRoadSteps: maximumRoadSteps
                ) ?? DeterministicRoadPatrol.route(
                    from: markets[marketIndex].roadAccessPoint,
                    maximumRoadSteps: maximumRoadSteps,
                    roadNetwork: roadNetwork,
                    replaySeed: replaySeed ^ UInt64(marketID),
                    trip: nextPeddlerID
                )
                guard !route.isEmpty else { continue }
                markets[marketIndex].inventoryByCommodityID[commodityID, default: 0] -= amount
                peddlers.append(MarketPeddler(
                    id: nextPeddlerID,
                    marketID: marketID,
                    commodityID: commodityID,
                    amount: amount,
                    route: route
                ))
                nextPeddlerID += 1
                freeSlots -= 1
            }
            if freeSlots > 0,
               markets[marketIndex].hasFoodShop,
               !peddlers.contains(where: { $0.marketID == marketID && $0.commodityID == -1 }),
               houses.contains(where: { Self.houseNeedsFood($0, models: models) }) {
                let quality = OriginalFoodCatalog.quality(
                    in: markets[marketIndex].inventoryByCommodityID
                )
                let cargoes = takeMarketFoodBundle(at: marketIndex, maximumAmount: 100)
                let amount = cargoes.reduce(0) { $0 + $1.amount }
                let route = DeterministicRoadPatrol.route(
                    from: markets[marketIndex].roadAccessPoint,
                    maximumRoadSteps: maximumRoadSteps,
                    roadNetwork: roadNetwork,
                    replaySeed: replaySeed ^ UInt64(marketID),
                    trip: nextPeddlerID
                )
                if amount > 0, quality != .none, !route.isEmpty {
                    peddlers.append(MarketPeddler(
                        id: nextPeddlerID,
                        marketID: marketID,
                        commodityID: -1,
                        amount: amount,
                        route: route,
                        foodQuality: quality,
                        foodCargoes: cargoes
                    ))
                    nextPeddlerID += 1
                } else {
                    restoreFoodBundle(cargoes, toMarketAt: marketIndex)
                }
            }
        }
    }

    public mutating func advancePeddlers(
        roadStepsPerPeddler: Int,
        houses: inout [ResidentialUnit],
        models: BuildingModelTable,
        activeMarketIDs: Set<Int>? = nil
    ) -> [HouseholdCommodityDelivery] {
        var deliveries: [HouseholdCommodityDelivery] = []
        var completedIDs: [Int] = []
        for index in peddlers.indices.sorted(by: { peddlers[$0].id < peddlers[$1].id }) {
            guard activeMarketIDs?.contains(peddlers[index].marketID) ?? true else { continue }
            distribute(at: index, houses: &houses, models: models, deliveries: &deliveries)
            for _ in 0..<max(0, roadStepsPerPeddler) {
                _ = peddlers[index].advanceOneRoadStep()
                distribute(at: index, houses: &houses, models: models, deliveries: &deliveries)
                if peddlers[index].hasCompletedRoute { break }
            }
            guard peddlers[index].hasCompletedRoute else { continue }
            if peddlers[index].remainingAmount > 0,
               let marketIndex = markets.firstIndex(where: { $0.id == peddlers[index].marketID }) {
                if let foodCargoes = peddlers[index].foodCargoes {
                    restoreFoodBundle(foodCargoes, toMarketAt: marketIndex)
                } else {
                    markets[marketIndex].inventoryByCommodityID[peddlers[index].commodityID, default: 0]
                        += peddlers[index].remainingAmount
                }
            }
            completedIDs.append(peddlers[index].id)
        }
        peddlers.removeAll { completedIDs.contains($0.id) }
        householdDeliveriesThisMonthStorage = (householdDeliveriesThisMonthStorage ?? []) + deliveries
        return deliveries
    }

    private mutating func distribute(
        at peddlerIndex: Int,
        houses: inout [ResidentialUnit],
        models: BuildingModelTable,
        deliveries: inout [HouseholdCommodityDelivery]
    ) {
        guard peddlers[peddlerIndex].remainingAmount > 0,
              let roadPoint = peddlers[peddlerIndex].currentPoint else { return }
        let commodityID = peddlers[peddlerIndex].commodityID
        for houseIndex in houses.indices.sorted(by: { houses[$0].id < houses[$1].id }) {
            guard peddlers[peddlerIndex].remainingAmount > 0,
                  houses[houseIndex].residents > 0,
                  let location = houses[houseIndex].location,
                  Self.roadNeighbors(of: houses[houseIndex], at: location)
                    .contains(roadPoint) else { continue }
            let desiredStock = houses[houseIndex].residents * 2
            let needed: Int
            if commodityID == -1 {
                guard Self.houseNeedsFood(houses[houseIndex], models: models) else { continue }
                needed = max(0, desiredStock - houses[houseIndex].foodSupplyAmount)
            } else {
                guard Self.house(houses[houseIndex], needs: commodityID, models: models) else { continue }
                needed = max(0, desiredStock - houses[houseIndex][commodityID: commodityID])
            }
            let amount = peddlers[peddlerIndex].deliver(needed)
            guard amount > 0 else { continue }
            if commodityID == -1 {
                let quality = peddlers[peddlerIndex].foodQualityRawValue
                    .flatMap(FoodQuality.init(rawValue:)) ?? .bland
                houses[houseIndex].addFoodSupply(amount: amount, quality: quality)
            } else {
                houses[houseIndex].addSupply(commodityID: commodityID, amount: amount)
            }
            deliveries.append(HouseholdCommodityDelivery(
                houseID: houses[houseIndex].id,
                commodityID: commodityID,
                amount: amount
            ))
        }
    }

    private func consumeHouseholdCommodities(
        houses: inout [ResidentialUnit],
        models: BuildingModelTable
    ) -> [HouseholdCommodityConsumption] {
        var result: [HouseholdCommodityConsumption] = []
        for index in houses.indices.sorted(by: { houses[$0].id < houses[$1].id }) {
            guard houses[index].residents > 0,
                  let model = models[houseLevelID: houses[index].houseLevelID] else { continue }
            let evolutionFoodQuality = houses[index].foodSupplyAmount >= houses[index].residents
                ? houses[index].foodQuality
                : .none
            let physicallyStockedCommodityIDs = Set(
                DeterministicHousingEvolution.marketCommodityIDs.filter {
                    houses[index][commodityID: $0] >= houses[index].residents
                }
            )
            let deliveredCommodityIDs = Set(
                (householdDeliveriesThisMonthStorage ?? []).compactMap {
                    $0.houseID == houses[index].id && $0.commodityID >= 0
                        ? $0.commodityID : nil
                }
            )
            houses[index].recordEvolutionSupplies(
                foodQuality: evolutionFoodQuality,
                commodityIDs: physicallyStockedCommodityIDs.union(deliveredCommodityIDs)
            )
            var hasShortage = false
            if model.foodQualityRequired > 0 {
                let requested = houses[index].residents
                let suppliedQuality = houses[index].foodQuality
                let consumed = houses[index].consumeFood(requested)
                let meetsQuality = suppliedQuality.rawValue >= model.foodQualityRequired
                let effectiveConsumption = meetsQuality ? consumed : 0
                result.append(HouseholdCommodityConsumption(
                    houseID: houses[index].id,
                    commodityID: -1,
                    requestedAmount: requested,
                    consumedAmount: effectiveConsumption
                ))
                hasShortage = consumed < requested || !meetsQuality
            }
            for alternatives in Self.requiredCommodityAlternatives(for: model) {
                let commodityID = alternatives.max {
                    houses[index][commodityID: $0] < houses[index][commodityID: $1]
                } ?? alternatives[0]
                let requested = houses[index].residents
                let consumed = houses[index].consumeSupply(
                    commodityID: commodityID,
                    amount: requested
                )
                result.append(HouseholdCommodityConsumption(
                    houseID: houses[index].id,
                    commodityID: commodityID,
                    requestedAmount: requested,
                    consumedAmount: consumed
                ))
                hasShortage = hasShortage || consumed < requested
            }
            houses[index].commodityShortageMonths = hasShortage
                ? houses[index].commodityShortageMonths + 1 : 0
        }
        return result
    }

    private func nearestWarehouse(
        commodityID: Int,
        marketRoad: GridPoint,
        logistics: DeterministicLogisticsState,
        roadNetwork: RoadNetwork,
        maximumSteps: Int
    ) -> (warehouseID: Int, available: Int, path: [GridPoint])? {
        logistics.warehouses.compactMap { warehouse -> (Int, Int, [GridPoint])? in
            let available = warehouse.inventoryByCommodityID[commodityID, default: 0]
            guard available > 0,
                  let path = GridPathfinder.shortestPath(
                    width: roadNetwork.width,
                    height: roadNetwork.height,
                    from: marketRoad,
                    to: warehouse.roadAccessPoint,
                    isPassable: roadNetwork.contains
                  ), path.count - 1 <= maximumSteps else { return nil }
            return (warehouse.id, available, path)
        }.min {
            if $0.2.count != $1.2.count { return $0.2.count < $1.2.count }
            return $0.0 < $1.0
        }
    }

    private func nearestMill(
        marketRoad: GridPoint,
        logistics: DeterministicLogisticsState,
        roadNetwork: RoadNetwork,
        maximumSteps: Int,
        activeMillIDs: Set<Int>? = nil
    ) -> (millID: Int, path: [GridPoint])? {
        logistics.mills.compactMap { mill -> (Int, [GridPoint])? in
            guard activeMillIDs?.contains(mill.id) ?? true,
                  mill.foodQuality != .none,
                  !logistics.hasIncomingFoodDelivery(toMillID: mill.id),
                  let path = GridPathfinder.shortestPath(
                    width: roadNetwork.width,
                    height: roadNetwork.height,
                    from: marketRoad,
                    to: mill.roadAccessPoint,
                    isPassable: roadNetwork.contains
                  ), path.count - 1 <= maximumSteps else { return nil }
            return (mill.id, path)
        }.min {
            if $0.1.count != $1.1.count { return $0.1.count < $1.1.count }
            return $0.0 < $1.0
        }
    }

    private mutating func takeMarketFoodBundle(
        at marketIndex: Int,
        maximumAmount: Int
    ) -> [DeliveryCargo] {
        let stockedIDs = markets[marketIndex].inventoryByCommodityID.keys
            .filter {
                OriginalFoodCatalog.isMillCommodity($0)
                    && markets[marketIndex].inventoryByCommodityID[$0, default: 0] > 0
            }
            .sorted()
        let total = stockedIDs.reduce(0) {
            $0 + markets[marketIndex].inventoryByCommodityID[$1, default: 0]
        }
        var remaining = min(max(0, maximumAmount), total)
        var amounts: [Int: Int] = [:]
        while remaining > 0 {
            let activeIDs = stockedIDs.filter {
                markets[marketIndex].inventoryByCommodityID[$0, default: 0] > 0
            }
            guard !activeIDs.isEmpty else { break }
            let share = max(1, remaining / activeIDs.count)
            var moved = 0
            for commodityID in activeIDs where remaining > 0 {
                let available = markets[marketIndex].inventoryByCommodityID[commodityID, default: 0]
                let taken = min(share, available, remaining)
                markets[marketIndex].inventoryByCommodityID[commodityID] = available - taken
                amounts[commodityID, default: 0] += taken
                remaining -= taken
                moved += taken
            }
            guard moved > 0 else { break }
        }
        return amounts.keys.sorted().map {
            DeliveryCargo(commodityID: $0, amount: amounts[$0, default: 0])
        }
    }

    private mutating func restoreFoodBundle(_ cargoes: [DeliveryCargo], toMarketAt index: Int) {
        for cargo in cargoes {
            markets[index].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
        }
    }

    private static func house(
        _ house: ResidentialUnit,
        needs commodityID: Int,
        models: BuildingModelTable
    ) -> Bool {
        guard house.residents > 0 else { return false }
        let levels = [house.houseLevelID, nextHouseLevel(after: house.houseLevelID)].compactMap { $0 }
        return levels.contains { level in
            guard let model = models[houseLevelID: level] else { return false }
            return requiredCommodityAlternatives(for: model).contains { $0.contains(commodityID) }
        }
    }

    private static func roadNeighbors(
        of house: ResidentialUnit,
        at location: GridPoint
    ) -> Set<GridPoint> {
        let buildingID = house.houseLevelID + 3
        let footprint = OriginalBuildingFootprintCatalog
            .footprint(forBuildingID: buildingID)
            ?? BuildingFootprint(width: 1, height: 1)
        return Set(
            footprint.points(at: location)
                .flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
        ).subtracting(footprint.points(at: location))
    }

    private static func deliveryRoute(
        from marketRoad: GridPoint,
        commodityID: Int,
        houses: [ResidentialUnit],
        models: BuildingModelTable,
        roadNetwork: RoadNetwork,
        maximumRoadSteps: Int
    ) -> [GridPoint]? {
        var remaining = houses
            .filter {
                house($0, needs: commodityID, models: models)
                    && $0[commodityID: commodityID] < $0.residents * 2
            }
            .filter { house in
                guard let location = house.location else { return false }
                return roadNeighbors(of: house, at: location).contains {
                    GridPathfinder.shortestPath(
                        width: roadNetwork.width,
                        height: roadNetwork.height,
                        from: marketRoad,
                        to: $0,
                        isPassable: roadNetwork.contains
                    ).map { $0.count - 1 <= maximumRoadSteps * 2 } ?? false
                }
            }
        guard !remaining.isEmpty else { return nil }

        var route = [marketRoad]
        var current = marketRoad
        while !remaining.isEmpty {
            let candidates = remaining.compactMap {
                house -> (house: ResidentialUnit, path: [GridPoint])? in
                guard let location = house.location else { return nil }
                let path = roadNeighbors(of: house, at: location).compactMap {
                    GridPathfinder.shortestPath(
                        width: roadNetwork.width,
                        height: roadNetwork.height,
                        from: current,
                        to: $0,
                        isPassable: roadNetwork.contains
                    )
                }.min(by: { $0.count < $1.count })
                return path.map { (house, $0) }
            }
            guard let next = candidates.min(by: {
                if $0.house.houseLevelID != $1.house.houseLevelID {
                    return $0.house.houseLevelID > $1.house.houseLevelID
                }
                if $0.path.count != $1.path.count { return $0.path.count < $1.path.count }
                return $0.house.id < $1.house.id
            }) else { break }
            route.append(contentsOf: next.path.dropFirst())
            current = next.path.last ?? current
            remaining.removeAll { $0.id == next.house.id }
        }
        guard route.count > 1,
              let returnPath = GridPathfinder.shortestPath(
                width: roadNetwork.width,
                height: roadNetwork.height,
                from: current,
                to: marketRoad,
                isPassable: roadNetwork.contains
              ) else { return nil }
        route.append(contentsOf: returnPath.dropFirst())
        return route
    }

    private static func houseNeedsFood(
        _ house: ResidentialUnit,
        models: BuildingModelTable
    ) -> Bool {
        guard house.residents > 0 else { return false }
        let levels = [house.houseLevelID, nextHouseLevel(after: house.houseLevelID)].compactMap { $0 }
        return levels.contains { level in
            models[houseLevelID: level]?.foodQualityRequired ?? 0 > 0
        }
    }

    private static func nextHouseLevel(after level: Int) -> Int? {
        switch level {
        case 0..<7: level + 1
        case 8..<14: level + 1
        default: nil
        }
    }

    private static func requiredCommodityAlternatives(for model: HouseModel) -> [[Int]] {
        var result: [[Int]] = []
        if model.hempRequired > 0 { result.append([19]) }
        if model.ceramicsRequired > 0 { result.append([25]) }
        if model.teaRequired > 0 { result.append([13]) }
        if model.silkRequired > 0 { result.append([24]) }
        if model.luxuryWareRequired > 0 { result.append([23, 22]) }
        return result
    }
}
