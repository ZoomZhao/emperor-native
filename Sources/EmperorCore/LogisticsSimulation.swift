import Foundation

public enum WarehouseCommodityPolicy: String, Sendable, Hashable, Codable {
    case doNotAccept
    case accept
    case empty
    case get
}

public struct StorageWarehouse: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let roadAccessPoint: GridPoint
    public let capacity: Int
    public var inventoryByCommodityID: [Int: Int]
    public var policyByCommodityID: [Int: WarehouseCommodityPolicy]
    public var storageLimitByCommodityID: [Int: Int]
    public var activeDeliveryWalkerID: Int?

    public init(
        id: Int,
        buildingID: Int = 54,
        roadAccessPoint: GridPoint,
        capacity: Int = 3_200,
        inventoryByCommodityID: [Int: Int] = [:],
        policyByCommodityID: [Int: WarehouseCommodityPolicy] = [:],
        storageLimitByCommodityID: [Int: Int] = [:],
        activeDeliveryWalkerID: Int? = nil
    ) {
        self.id = id
        self.buildingID = buildingID
        self.roadAccessPoint = roadAccessPoint
        self.capacity = max(0, capacity)
        self.inventoryByCommodityID = inventoryByCommodityID
        self.policyByCommodityID = policyByCommodityID
        self.storageLimitByCommodityID = storageLimitByCommodityID
        self.activeDeliveryWalkerID = activeDeliveryWalkerID
    }

    public var storedAmount: Int {
        inventoryByCommodityID.values.reduce(0, +)
    }

    public var availableCapacity: Int {
        max(0, capacity - storedAmount)
    }

    public func policy(for commodityID: Int) -> WarehouseCommodityPolicy {
        policyByCommodityID[commodityID] ?? .accept
    }

    public func storageLimit(for commodityID: Int) -> Int {
        min(capacity, max(0, storageLimitByCommodityID[commodityID] ?? capacity))
    }

    public func availableCapacity(for commodityID: Int) -> Int {
        guard policy(for: commodityID) != .doNotAccept else { return 0 }
        let commoditySpace = max(
            0,
            storageLimit(for: commodityID) - inventoryByCommodityID[commodityID, default: 0]
        )
        return min(availableCapacity, commoditySpace)
    }
}

public enum DeliveryEndpoint: Sendable, Hashable, Codable {
    case productionBuilding(Int)
    case warehouse(Int)
    case mill(Int)
    case tradingBuilding(Int)
}

public struct DeliveryCargo: Sendable, Hashable, Codable {
    public let commodityID: Int
    public let amount: Int

    public init(commodityID: Int, amount: Int) {
        self.commodityID = commodityID
        self.amount = max(0, amount)
    }
}

public struct DeliveryWalker: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let figureID: Int
    public let source: DeliveryEndpoint
    public let destination: DeliveryEndpoint
    public let cargo: DeliveryCargo
    public let route: [GridPoint]
    public let destinationRouteIndex: Int
    public private(set) var routeIndex: Int
    public private(set) var hasDelivered: Bool

    public var currentPoint: GridPoint? {
        route.indices.contains(routeIndex) ? route[routeIndex] : nil
    }

    public var hasReturned: Bool {
        hasDelivered && routeIndex == route.count - 1
    }

    init(
        id: Int,
        figureID: Int,
        source: DeliveryEndpoint,
        destination: DeliveryEndpoint,
        cargo: DeliveryCargo,
        outboundPath: [GridPoint]
    ) {
        self.id = id
        self.figureID = figureID
        self.source = source
        self.destination = destination
        self.cargo = cargo
        destinationRouteIndex = max(0, outboundPath.count - 1)
        route = outboundPath + Array(outboundPath.dropLast().reversed())
        routeIndex = 0
        hasDelivered = false
    }

    mutating func advanceOneRoadStep() -> Bool {
        guard routeIndex + 1 < route.count else { return false }
        routeIndex += 1
        return true
    }

    mutating func markDelivered() {
        hasDelivered = true
    }
}

public struct DeliveryMovementSummary: Sendable, Hashable, Codable {
    public let requestedRoadSteps: Int
    public let movedRoadSteps: Int
    public let deliveredLoads: [DeliveryCargo]
    public let completedWalkerIDs: [Int]

    public static let empty = Self(
        requestedRoadSteps: 0,
        movedRoadSteps: 0,
        deliveredLoads: [],
        completedWalkerIDs: []
    )
}

public struct DeterministicLogisticsState: Sendable, Hashable, Codable {
    public static let originalWarehouseCapacity = 3_200
    public static let originalDeliveryLoad = 100

    public private(set) var warehouses: [StorageWarehouse]
    public private(set) var deliveryWalkers: [DeliveryWalker]
    public private(set) var lastMovement: DeliveryMovementSummary?
    private var foodMillStorage: [FoodMill]?
    private var nextWarehouseID: Int
    private var nextDeliveryWalkerID: Int
    private var nextFoodMillID: Int?

    public init() {
        warehouses = []
        deliveryWalkers = []
        lastMovement = nil
        foodMillStorage = []
        nextWarehouseID = 1
        nextDeliveryWalkerID = 1
        nextFoodMillID = 1
    }

    /// Markets wait for the currently approaching food loads so a mill can
    /// offer the combined quality instead of dispatching a buyer for the first
    /// single food type that happens to arrive one tick earlier.
    public func hasIncomingFoodDelivery(toMillID millID: Int) -> Bool {
        deliveryWalkers.contains { walker in
            guard !walker.hasDelivered,
                  walker.destination == .mill(millID) else { return false }
            return OriginalFoodCatalog.isMillCommodity(walker.cargo.commodityID)
        }
    }

    public var mills: [FoodMill] { foodMillStorage ?? [] }

    public subscript(commodityID commodityID: Int) -> Int {
        warehouses.reduce(0) { partial, warehouse in
            partial + warehouse.inventoryByCommodityID[commodityID, default: 0]
        } + mills.reduce(0) { partial, mill in
            partial + mill.inventoryByCommodityID[commodityID, default: 0]
        }
    }

    @discardableResult
    public mutating func addWarehouse(
        buildingID: Int = 54,
        roadAccessPoint: GridPoint,
        roadNetwork: RoadNetwork
    ) -> Int? {
        guard roadNetwork.contains(roadAccessPoint) else { return nil }
        let id = nextWarehouseID
        nextWarehouseID += 1
        warehouses.append(StorageWarehouse(
            id: id,
            buildingID: buildingID,
            roadAccessPoint: roadAccessPoint,
            capacity: Self.originalWarehouseCapacity
        ))
        return id
    }

    @discardableResult
    public mutating func addMill(
        buildingID: Int = OriginalFoodCatalog.millBuildingID,
        roadAccessPoint: GridPoint,
        roadNetwork: RoadNetwork
    ) -> Int? {
        guard roadNetwork.contains(roadAccessPoint) else { return nil }
        let id = nextFoodMillID ?? ((foodMillStorage?.map(\.id).max() ?? 0) + 1)
        nextFoodMillID = id + 1
        var mills = foodMillStorage ?? []
        mills.append(FoodMill(
            id: id,
            buildingID: buildingID,
            roadAccessPoint: roadAccessPoint
        ))
        foodMillStorage = mills
        return id
    }

    @discardableResult
    public mutating func removeWarehouse(id: Int) -> StorageWarehouse? {
        guard let index = warehouses.firstIndex(where: { $0.id == id }) else { return nil }
        return warehouses.remove(at: index)
    }

    @discardableResult
    public mutating func removeMill(id: Int) -> FoodMill? {
        guard var mills = foodMillStorage,
              let index = mills.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = mills.remove(at: index)
        foodMillStorage = mills
        return removed
    }

    /// Cancels deliveries tied to a demolished endpoint and releases any
    /// surviving source building. Cargo already in transit is lost, matching
    /// the original bulldozer's destructive inventory semantics.
    @discardableResult
    public mutating func cancelDeliveries(
        involving endpoint: DeliveryEndpoint,
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState
    ) -> [Int] {
        cancelDeliveries(
            where: { $0.source == endpoint || $0.destination == endpoint },
            production: &production,
            trade: &trade
        )
    }

    /// Invalidates fixed delivery routes that crossed a bulldozed road tile.
    @discardableResult
    public mutating func cancelDeliveries(
        using point: GridPoint,
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState
    ) -> [Int] {
        cancelDeliveries(
            where: { $0.route.contains(point) },
            production: &production,
            trade: &trade
        )
    }

    private mutating func cancelDeliveries(
        where shouldCancel: (DeliveryWalker) -> Bool,
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState
    ) -> [Int] {
        let cancelled = deliveryWalkers.filter(shouldCancel)
        for walker in cancelled {
            releaseTradeSource(for: walker, production: &production, trade: &trade)
        }
        let ids = Set(cancelled.map(\.id))
        deliveryWalkers.removeAll { ids.contains($0.id) }
        return ids.sorted()
    }

    public mutating func setPolicy(
        _ policy: WarehouseCommodityPolicy,
        commodityID: Int,
        warehouseID: Int
    ) {
        guard let index = warehouses.firstIndex(where: { $0.id == warehouseID }) else { return }
        warehouses[index].policyByCommodityID[commodityID] = policy
    }

    public mutating func setStorageLimit(
        _ amount: Int,
        commodityID: Int,
        warehouseID: Int
    ) {
        guard let index = warehouses.firstIndex(where: { $0.id == warehouseID }) else { return }
        // The original UI works in four-load bays. Preserve that granularity.
        let clamped = min(warehouses[index].capacity, max(0, amount))
        warehouses[index].storageLimitByCommodityID[commodityID] = clamped / 400 * 400
    }

    public mutating func setMillPolicy(
        _ policy: WarehouseCommodityPolicy,
        commodityID: Int,
        millID: Int
    ) {
        guard var mills = foodMillStorage,
              let index = mills.firstIndex(where: { $0.id == millID }) else { return }
        mills[index].policyByCommodityID[commodityID] = policy
        foodMillStorage = mills
    }

    public mutating func setMillStorageLimit(
        _ amount: Int,
        commodityID: Int,
        millID: Int
    ) {
        guard var mills = foodMillStorage,
              let index = mills.firstIndex(where: { $0.id == millID }) else { return }
        let clamped = min(mills[index].capacity, max(0, amount))
        // The Windows dialog changes one four-load bay at a time.
        mills[index].storageLimitByCommodityID[commodityID] = clamped / 400 * 400
        foodMillStorage = mills
    }

    /// Accepts as much of a scripted campaign gift as the city's physical
    /// warehouses can hold. The original event waits when storage is missing;
    /// callers retain the unaccepted remainder and retry it on later months.
    @discardableResult
    public mutating func storeCampaignGift(
        commodityID: Int,
        amount: Int,
        production: inout DeterministicProductionState
    ) -> Int {
        guard commodityID >= 0, amount > 0 else { return 0 }
        var remaining = amount
        for index in warehouses.indices.sorted(by: { warehouses[$0].id < warehouses[$1].id }) {
            let accepted = min(
                remaining,
                warehouses[index].availableCapacity(for: commodityID)
            )
            guard accepted > 0 else { continue }
            warehouses[index].inventoryByCommodityID[commodityID, default: 0] += accepted
            remaining -= accepted
            if remaining == 0 { break }
        }
        let stored = amount - remaining
        production.addInventory(commodityID: commodityID, amount: stored)
        return stored
    }

    /// Atomically withdraws request goods from physical warehouses and food
    /// mills. No inventory changes if the full scripted amount is unavailable.
    @discardableResult
    public mutating func takeCampaignRequestGoods(
        commodityID: Int,
        amount: Int,
        production: inout DeterministicProductionState
    ) -> Bool {
        guard commodityID >= 0, amount > 0, self[commodityID: commodityID] >= amount else {
            return false
        }
        var remaining = amount
        for index in warehouses.indices.sorted(by: { warehouses[$0].id < warehouses[$1].id }) {
            let available = warehouses[index].inventoryByCommodityID[commodityID, default: 0]
            let taken = min(remaining, available)
            warehouses[index].inventoryByCommodityID[commodityID] = available - taken
            remaining -= taken
            if remaining == 0 { break }
        }
        if remaining > 0, var mills = foodMillStorage {
            for index in mills.indices.sorted(by: { mills[$0].id < mills[$1].id }) {
                let available = mills[index].inventoryByCommodityID[commodityID, default: 0]
                let taken = min(remaining, available)
                mills[index].inventoryByCommodityID[commodityID] = available - taken
                remaining -= taken
                if remaining == 0 { break }
            }
            foodMillStorage = mills
        }
        production.addInventory(commodityID: commodityID, amount: -amount)
        return true
    }

    @discardableResult
    public mutating func takeStoredGoods(
        warehouseID: Int,
        commodityID: Int,
        amount: Int,
        production: inout DeterministicProductionState
    ) -> Int {
        guard amount > 0,
              let index = warehouses.firstIndex(where: { $0.id == warehouseID }) else { return 0 }
        let available = warehouses[index].inventoryByCommodityID[commodityID, default: 0]
        let taken = min(amount, available)
        warehouses[index].inventoryByCommodityID[commodityID] = available - taken
        production.addInventory(commodityID: commodityID, amount: -taken)
        return taken
    }

    /// Returns phase-two carrier cargo to its exact physical warehouse using
    /// that warehouse's live bay/policy capacity. The aggregate production
    /// inventory mirrors every accepted unit just as ordinary warehouse
    /// delivery does.
    @discardableResult
    public mutating func returnStoredGoods(
        warehouseID: Int,
        commodityID: Int,
        amount: Int,
        production: inout DeterministicProductionState
    ) -> Int {
        guard amount > 0,
              let index = warehouses.firstIndex(where: { $0.id == warehouseID }) else {
            return 0
        }
        let accepted = min(amount, warehouses[index].availableCapacity(for: commodityID))
        guard accepted > 0 else { return 0 }
        warehouses[index].inventoryByCommodityID[commodityID, default: 0] += accepted
        production.addInventory(commodityID: commodityID, amount: accepted)
        return accepted
    }

    @discardableResult
    public mutating func takeFoodBundle(
        millID: Int,
        maximumAmount: Int,
        production: inout DeterministicProductionState
    ) -> [DeliveryCargo] {
        guard maximumAmount > 0,
              var mills = foodMillStorage,
              let index = mills.firstIndex(where: { $0.id == millID }) else { return [] }
        let stockedIDs = mills[index].inventoryByCommodityID.keys
            .filter { OriginalFoodCatalog.isMillCommodity($0) && mills[index].inventoryByCommodityID[$0, default: 0] > 0 }
            .sorted()
        var remaining = min(maximumAmount, mills[index].storedAmount)
        var amounts: [Int: Int] = [:]

        while remaining > 0 {
            let activeIDs = stockedIDs.filter { mills[index].inventoryByCommodityID[$0, default: 0] > 0 }
            guard !activeIDs.isEmpty else { break }
            let share = max(1, remaining / activeIDs.count)
            var movedThisPass = 0
            for commodityID in activeIDs where remaining > 0 {
                let available = mills[index].inventoryByCommodityID[commodityID, default: 0]
                let taken = min(share, available, remaining)
                mills[index].inventoryByCommodityID[commodityID] = available - taken
                amounts[commodityID, default: 0] += taken
                remaining -= taken
                movedThisPass += taken
            }
            guard movedThisPass > 0 else { break }
        }
        foodMillStorage = mills
        let cargoes = amounts.keys.sorted().map {
            DeliveryCargo(commodityID: $0, amount: amounts[$0, default: 0])
        }
        for cargo in cargoes {
            production.addInventory(commodityID: cargo.commodityID, amount: -cargo.amount)
        }
        return cargoes
    }

    @discardableResult
    public mutating func scheduleDeliveries(
        production: inout DeterministicProductionState,
        roadNetwork: RoadNetwork,
        deliveryFigureID: Int = 22,
        maximumOneWayRoadSteps: Int = 24,
        activeProductionBuildingIDs: Set<Int>? = nil,
        activeMillIDs: Set<Int>? = nil
    ) -> Int {
        guard maximumOneWayRoadSteps > 0 else { return 0 }
        var scheduled = 0
        let productionSnapshot = production.buildings.sorted { $0.id < $1.id }

        for source in productionSnapshot {
            guard let sourceRoad = source.roadAccessPoint,
                  source.activeDeliveryWalkerID == nil,
                  activeProductionBuildingIDs?.contains(source.id) ?? true else { continue }
            let commodityID: Int
            if let agriculture = source.agriculture {
                commodityID = agriculture.crop.outputCommodityID
            } else if let recipe = OriginalProductionCatalog.recipe(forBuildingID: source.buildingID) {
                commodityID = recipe.outputCommodityID
            } else {
                continue
            }
            let available = production.localOutputAmount(
                buildingInstanceID: source.id,
                commodityID: commodityID
            )
            guard available > 0 else { continue }

            let sourceEndpoint = DeliveryEndpoint.productionBuilding(source.id)
            if let destination = bestProductionDestination(
                for: commodityID,
                excluding: source.id,
                production: production,
                sourceRoad: sourceRoad,
                roadNetwork: roadNetwork,
                maximumOneWayRoadSteps: maximumOneWayRoadSteps
            ) {
                let amount = min(Self.originalDeliveryLoad, available, destination.demand)
                if createDelivery(
                    source: sourceEndpoint,
                    destination: .productionBuilding(destination.buildingID),
                    commodityID: commodityID,
                    amount: amount,
                    outboundPath: destination.path,
                    figureID: deliveryFigureID,
                    production: &production
                ) {
                    scheduled += 1
                }
                continue
            }

            if OriginalFoodCatalog.isMillCommodity(commodityID),
               let destination = bestMillDestination(
                for: commodityID,
                sourceRoad: sourceRoad,
                roadNetwork: roadNetwork,
                maximumOneWayRoadSteps: maximumOneWayRoadSteps,
                activeMillIDs: activeMillIDs
               ) {
                let amount = min(Self.originalDeliveryLoad, available, destination.capacity)
                if createDelivery(
                    source: sourceEndpoint,
                    destination: .mill(destination.millID),
                    commodityID: commodityID,
                    amount: amount,
                    outboundPath: destination.path,
                    figureID: deliveryFigureID,
                    production: &production
                ) {
                    scheduled += 1
                }
                continue
            }

            if let destination = bestWarehouseDestination(
                for: commodityID,
                sourceRoad: sourceRoad,
                roadNetwork: roadNetwork,
                maximumOneWayRoadSteps: maximumOneWayRoadSteps
            ) {
                let amount = min(Self.originalDeliveryLoad, available, destination.capacity)
                if createDelivery(
                    source: sourceEndpoint,
                    destination: .warehouse(destination.warehouseID),
                    commodityID: commodityID,
                    amount: amount,
                    outboundPath: destination.path,
                    figureID: deliveryFigureID,
                    production: &production
                ) {
                    scheduled += 1
                }
            }
        }

        // Warehouses can send stocked raw materials back to workshops when no
        // direct producer delivery is currently reserved for that destination.
        for warehouseIndex in warehouses.indices.sorted(by: { warehouses[$0].id < warehouses[$1].id }) {
            guard warehouses[warehouseIndex].activeDeliveryWalkerID == nil else { continue }
            let sourceRoad = warehouses[warehouseIndex].roadAccessPoint
            let commodityIDs = warehouses[warehouseIndex].inventoryByCommodityID.keys.sorted()
            for commodityID in commodityIDs {
                let available = warehouses[warehouseIndex].inventoryByCommodityID[commodityID, default: 0]
                guard available > 0 else { continue }
                if let destination = bestProductionDestination(
                        for: commodityID,
                        excluding: nil,
                        production: production,
                        sourceRoad: sourceRoad,
                        roadNetwork: roadNetwork,
                        maximumOneWayRoadSteps: maximumOneWayRoadSteps
                ) {
                    let amount = min(Self.originalDeliveryLoad, available, destination.demand)
                    if createDelivery(
                        source: .warehouse(warehouses[warehouseIndex].id),
                        destination: .productionBuilding(destination.buildingID),
                        commodityID: commodityID,
                        amount: amount,
                        outboundPath: destination.path,
                        figureID: deliveryFigureID,
                        production: &production
                    ) {
                        scheduled += 1
                        break
                    }
                }
                if OriginalFoodCatalog.isMillCommodity(commodityID),
                   let destination = bestMillDestination(
                    for: commodityID,
                    sourceRoad: sourceRoad,
                    roadNetwork: roadNetwork,
                    maximumOneWayRoadSteps: maximumOneWayRoadSteps,
                    activeMillIDs: activeMillIDs
                   ) {
                    let amount = min(Self.originalDeliveryLoad, available, destination.capacity)
                    if createDelivery(
                        source: .warehouse(warehouses[warehouseIndex].id),
                        destination: .mill(destination.millID),
                        commodityID: commodityID,
                        amount: amount,
                        outboundPath: destination.path,
                        figureID: deliveryFigureID,
                        production: &production
                    ) {
                        scheduled += 1
                        break
                    }
                }
            }
        }
        return scheduled
    }

    /// Schedules the trading building's own deliveryman over the same physical
    /// road network used by industry. Imported stock leaves the station first;
    /// otherwise producers/warehouses may stage one export load there.
    @discardableResult
    public mutating func scheduleTradeDeliveries(
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState,
        roadNetwork: RoadNetwork,
        deliveryFigureID: Int = 22,
        maximumOneWayRoadSteps: Int = 24
    ) -> Int {
        guard maximumOneWayRoadSteps > 0 else { return 0 }
        var scheduled = 0

        for source in trade.buildings.sorted(by: { $0.id < $1.id }) {
            guard source.activeDeliveryWalkerID == nil else { continue }
            for commodityID in source.importingCommodityIDs.sorted() {
                let available = trade.localInventory(
                    tradingBuildingID: source.id,
                    commodityID: commodityID
                )
                guard available > 0 else { continue }
                let sourceEndpoint = DeliveryEndpoint.tradingBuilding(source.id)
                if let destination = bestProductionDestination(
                    for: commodityID,
                    excluding: nil,
                    production: production,
                    sourceRoad: source.roadAccessPoint,
                    roadNetwork: roadNetwork,
                    maximumOneWayRoadSteps: maximumOneWayRoadSteps
                ) {
                    let amount = min(Self.originalDeliveryLoad, available, destination.demand)
                    if createTradeDelivery(
                        source: sourceEndpoint,
                        destination: .productionBuilding(destination.buildingID),
                        commodityID: commodityID,
                        amount: amount,
                        outboundPath: destination.path,
                        figureID: deliveryFigureID,
                        production: &production,
                        trade: &trade
                    ) {
                        scheduled += 1
                    }
                    break
                }
                if OriginalFoodCatalog.isMillCommodity(commodityID),
                   let destination = bestMillDestination(
                    for: commodityID,
                    sourceRoad: source.roadAccessPoint,
                    roadNetwork: roadNetwork,
                    maximumOneWayRoadSteps: maximumOneWayRoadSteps
                   ) {
                    let amount = min(Self.originalDeliveryLoad, available, destination.capacity)
                    if createTradeDelivery(
                        source: sourceEndpoint,
                        destination: .mill(destination.millID),
                        commodityID: commodityID,
                        amount: amount,
                        outboundPath: destination.path,
                        figureID: deliveryFigureID,
                        production: &production,
                        trade: &trade
                    ) {
                        scheduled += 1
                    }
                    break
                }
                if let destination = bestWarehouseDestination(
                    for: commodityID,
                    sourceRoad: source.roadAccessPoint,
                    roadNetwork: roadNetwork,
                    maximumOneWayRoadSteps: maximumOneWayRoadSteps
                ) {
                    let amount = min(Self.originalDeliveryLoad, available, destination.capacity)
                    if createTradeDelivery(
                        source: sourceEndpoint,
                        destination: .warehouse(destination.warehouseID),
                        commodityID: commodityID,
                        amount: amount,
                        outboundPath: destination.path,
                        figureID: deliveryFigureID,
                        production: &production,
                        trade: &trade
                    ) {
                        scheduled += 1
                    }
                    break
                }
            }
        }

        // Located producers can stage exports directly when their normal
        // processor/mill/warehouse route did not already claim the deliveryman.
        for source in production.buildings.sorted(by: { $0.id < $1.id }) {
            guard let sourceRoad = source.roadAccessPoint,
                  source.activeDeliveryWalkerID == nil else { continue }
            let commodityID: Int
            if let agriculture = source.agriculture {
                commodityID = agriculture.crop.outputCommodityID
            } else if let recipe = OriginalProductionCatalog.recipe(forBuildingID: source.buildingID) {
                commodityID = recipe.outputCommodityID
            } else {
                continue
            }
            let available = production.localOutputAmount(
                buildingInstanceID: source.id,
                commodityID: commodityID
            )
            guard available > 0,
                  let destination = bestTradingDestination(
                    for: commodityID,
                    trade: trade,
                    sourceRoad: sourceRoad,
                    roadNetwork: roadNetwork,
                    maximumOneWayRoadSteps: maximumOneWayRoadSteps
                  ) else { continue }
            let amount = min(Self.originalDeliveryLoad, available, destination.demand)
            if createTradeDelivery(
                source: .productionBuilding(source.id),
                destination: .tradingBuilding(destination.buildingID),
                commodityID: commodityID,
                amount: amount,
                outboundPath: destination.path,
                figureID: deliveryFigureID,
                production: &production,
                trade: &trade
            ) {
                scheduled += 1
            }
        }

        for warehouseIndex in warehouses.indices.sorted(by: { warehouses[$0].id < warehouses[$1].id }) {
            guard warehouses[warehouseIndex].activeDeliveryWalkerID == nil else { continue }
            let sourceRoad = warehouses[warehouseIndex].roadAccessPoint
            for commodityID in warehouses[warehouseIndex].inventoryByCommodityID.keys.sorted() {
                let available = warehouses[warehouseIndex].inventoryByCommodityID[commodityID, default: 0]
                guard available > 0,
                      let destination = bestTradingDestination(
                        for: commodityID,
                        trade: trade,
                        sourceRoad: sourceRoad,
                        roadNetwork: roadNetwork,
                        maximumOneWayRoadSteps: maximumOneWayRoadSteps
                      ) else { continue }
                let amount = min(Self.originalDeliveryLoad, available, destination.demand)
                if createTradeDelivery(
                    source: .warehouse(warehouses[warehouseIndex].id),
                    destination: .tradingBuilding(destination.buildingID),
                    commodityID: commodityID,
                    amount: amount,
                    outboundPath: destination.path,
                    figureID: deliveryFigureID,
                    production: &production,
                    trade: &trade
                ) {
                    scheduled += 1
                    break
                }
            }
        }
        return scheduled
    }

    @discardableResult
    public mutating func advanceDeliveries(
        roadStepsPerWalker: Int,
        production: inout DeterministicProductionState
    ) -> DeliveryMovementSummary {
        let steps = max(0, roadStepsPerWalker)
        let requested = steps * deliveryWalkers.count
        var moved = 0
        var delivered: [DeliveryCargo] = []
        var completedIDs: [Int] = []

        for index in deliveryWalkers.indices.sorted(by: { deliveryWalkers[$0].id < deliveryWalkers[$1].id }) {
            deliverIfNeeded(at: index, production: &production, delivered: &delivered)
            for _ in 0..<steps {
                if deliveryWalkers[index].advanceOneRoadStep() {
                    moved += 1
                }
                deliverIfNeeded(at: index, production: &production, delivered: &delivered)
                if deliveryWalkers[index].hasReturned { break }
            }
            if deliveryWalkers[index].hasReturned {
                completedIDs.append(deliveryWalkers[index].id)
            }
        }

        for index in deliveryWalkers.indices.reversed()
        where completedIDs.contains(deliveryWalkers[index].id) {
            releaseSource(for: deliveryWalkers[index], production: &production)
            deliveryWalkers.remove(at: index)
        }

        let result = DeliveryMovementSummary(
            requestedRoadSteps: requested,
            movedRoadSteps: moved,
            deliveredLoads: delivered,
            completedWalkerIDs: completedIDs.sorted()
        )
        lastMovement = result
        return result
    }

    @discardableResult
    public mutating func advanceDeliveries(
        roadStepsPerWalker: Int,
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState,
        activeDeliveryWalkerIDs: Set<Int>? = nil
    ) -> DeliveryMovementSummary {
        let steps = max(0, roadStepsPerWalker)
        let requested = steps * deliveryWalkers.count
        var moved = 0
        var delivered: [DeliveryCargo] = []
        var completedIDs: [Int] = []

        for index in deliveryWalkers.indices.sorted(by: { deliveryWalkers[$0].id < deliveryWalkers[$1].id }) {
            guard activeDeliveryWalkerIDs?.contains(deliveryWalkers[index].id) ?? true else { continue }
            deliverTradeIfNeeded(
                at: index,
                production: &production,
                trade: &trade,
                delivered: &delivered
            )
            for _ in 0..<steps {
                if deliveryWalkers[index].advanceOneRoadStep() { moved += 1 }
                deliverTradeIfNeeded(
                    at: index,
                    production: &production,
                    trade: &trade,
                    delivered: &delivered
                )
                if deliveryWalkers[index].hasReturned { break }
            }
            if deliveryWalkers[index].hasReturned {
                completedIDs.append(deliveryWalkers[index].id)
            }
        }
        for index in deliveryWalkers.indices.reversed()
        where completedIDs.contains(deliveryWalkers[index].id) {
            releaseTradeSource(
                for: deliveryWalkers[index],
                production: &production,
                trade: &trade
            )
            deliveryWalkers.remove(at: index)
        }
        let result = DeliveryMovementSummary(
            requestedRoadSteps: requested,
            movedRoadSteps: moved,
            deliveredLoads: delivered,
            completedWalkerIDs: completedIDs.sorted()
        )
        lastMovement = result
        return result
    }

    private mutating func createDelivery(
        source: DeliveryEndpoint,
        destination: DeliveryEndpoint,
        commodityID: Int,
        amount: Int,
        outboundPath: [GridPoint],
        figureID: Int,
        production: inout DeterministicProductionState
    ) -> Bool {
        guard amount > 0, !outboundPath.isEmpty else { return false }
        let id = nextDeliveryWalkerID
        let cargo = DeliveryCargo(commodityID: commodityID, amount: amount)

        switch source {
        case let .productionBuilding(buildingID):
            guard production.takeLocalOutput(
                buildingInstanceID: buildingID,
                commodityID: commodityID,
                amount: amount
            ) == amount else { return false }
            production.setActiveDeliveryWalker(id, buildingInstanceID: buildingID)
        case let .warehouse(warehouseID):
            guard let index = warehouses.firstIndex(where: { $0.id == warehouseID }),
                  warehouses[index].inventoryByCommodityID[commodityID, default: 0] >= amount else { return false }
            warehouses[index].inventoryByCommodityID[commodityID, default: 0] -= amount
            warehouses[index].activeDeliveryWalkerID = id
            production.addInventory(commodityID: commodityID, amount: -amount)
        case .mill:
            return false
        case .tradingBuilding:
            return false
        }

        nextDeliveryWalkerID += 1
        deliveryWalkers.append(DeliveryWalker(
            id: id,
            figureID: figureID,
            source: source,
            destination: destination,
            cargo: cargo,
            outboundPath: outboundPath
        ))
        return true
    }

    private mutating func deliverIfNeeded(
        at index: Int,
        production: inout DeterministicProductionState,
        delivered: inout [DeliveryCargo]
    ) {
        guard !deliveryWalkers[index].hasDelivered,
              deliveryWalkers[index].routeIndex == deliveryWalkers[index].destinationRouteIndex else { return }
        let cargo = deliveryWalkers[index].cargo
        switch deliveryWalkers[index].destination {
        case let .productionBuilding(buildingID):
            production.addLocalInput(
                buildingInstanceID: buildingID,
                commodityID: cargo.commodityID,
                amount: cargo.amount
            )
        case let .warehouse(warehouseID):
            guard let warehouseIndex = warehouses.firstIndex(where: { $0.id == warehouseID }) else { return }
            warehouses[warehouseIndex].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
            production.addInventory(commodityID: cargo.commodityID, amount: cargo.amount)
        case let .mill(millID):
            guard var mills = foodMillStorage,
                  let millIndex = mills.firstIndex(where: { $0.id == millID }) else { return }
            mills[millIndex].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
            foodMillStorage = mills
            production.addInventory(commodityID: cargo.commodityID, amount: cargo.amount)
        case .tradingBuilding:
            return
        }
        deliveryWalkers[index].markDelivered()
        delivered.append(cargo)
    }

    private mutating func releaseSource(
        for walker: DeliveryWalker,
        production: inout DeterministicProductionState
    ) {
        switch walker.source {
        case let .productionBuilding(buildingID):
            production.setActiveDeliveryWalker(nil, buildingInstanceID: buildingID)
        case let .warehouse(warehouseID):
            guard let index = warehouses.firstIndex(where: { $0.id == warehouseID }) else { return }
            warehouses[index].activeDeliveryWalkerID = nil
        case .mill:
            break
        case .tradingBuilding:
            break
        }
    }

    private mutating func createTradeDelivery(
        source: DeliveryEndpoint,
        destination: DeliveryEndpoint,
        commodityID: Int,
        amount: Int,
        outboundPath: [GridPoint],
        figureID: Int,
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState
    ) -> Bool {
        guard amount > 0, !outboundPath.isEmpty else { return false }
        let id = nextDeliveryWalkerID
        switch source {
        case let .productionBuilding(buildingID):
            guard production.takeLocalOutput(
                buildingInstanceID: buildingID,
                commodityID: commodityID,
                amount: amount
            ) == amount else { return false }
            production.setActiveDeliveryWalker(id, buildingInstanceID: buildingID)
        case let .warehouse(warehouseID):
            guard let index = warehouses.firstIndex(where: { $0.id == warehouseID }),
                  warehouses[index].inventoryByCommodityID[commodityID, default: 0] >= amount else { return false }
            warehouses[index].inventoryByCommodityID[commodityID, default: 0] -= amount
            warehouses[index].activeDeliveryWalkerID = id
            production.addInventory(commodityID: commodityID, amount: -amount)
        case let .tradingBuilding(buildingID):
            guard trade.takeLocalInventory(
                tradingBuildingID: buildingID,
                commodityID: commodityID,
                amount: amount
            ) == amount else { return false }
            trade.setActiveDeliveryWalker(id, tradingBuildingID: buildingID)
        case .mill:
            return false
        }
        nextDeliveryWalkerID += 1
        deliveryWalkers.append(DeliveryWalker(
            id: id,
            figureID: figureID,
            source: source,
            destination: destination,
            cargo: DeliveryCargo(commodityID: commodityID, amount: amount),
            outboundPath: outboundPath
        ))
        return true
    }

    private mutating func deliverTradeIfNeeded(
        at index: Int,
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState,
        delivered: inout [DeliveryCargo]
    ) {
        guard !deliveryWalkers[index].hasDelivered,
              deliveryWalkers[index].routeIndex == deliveryWalkers[index].destinationRouteIndex else { return }
        let cargo = deliveryWalkers[index].cargo
        switch deliveryWalkers[index].destination {
        case let .productionBuilding(buildingID):
            production.addLocalInput(
                buildingInstanceID: buildingID,
                commodityID: cargo.commodityID,
                amount: cargo.amount
            )
        case let .warehouse(warehouseID):
            guard let warehouseIndex = warehouses.firstIndex(where: { $0.id == warehouseID }) else { return }
            warehouses[warehouseIndex].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
            production.addInventory(commodityID: cargo.commodityID, amount: cargo.amount)
        case let .mill(millID):
            guard var mills = foodMillStorage,
                  let millIndex = mills.firstIndex(where: { $0.id == millID }) else { return }
            mills[millIndex].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
            foodMillStorage = mills
            production.addInventory(commodityID: cargo.commodityID, amount: cargo.amount)
        case let .tradingBuilding(buildingID):
            trade.addLocalInventory(
                tradingBuildingID: buildingID,
                commodityID: cargo.commodityID,
                amount: cargo.amount
            )
        }
        deliveryWalkers[index].markDelivered()
        delivered.append(cargo)
    }

    private mutating func releaseTradeSource(
        for walker: DeliveryWalker,
        production: inout DeterministicProductionState,
        trade: inout DeterministicTradeState
    ) {
        switch walker.source {
        case let .productionBuilding(buildingID):
            production.setActiveDeliveryWalker(nil, buildingInstanceID: buildingID)
        case let .warehouse(warehouseID):
            guard let index = warehouses.firstIndex(where: { $0.id == warehouseID }) else { return }
            warehouses[index].activeDeliveryWalkerID = nil
        case let .tradingBuilding(buildingID):
            trade.setActiveDeliveryWalker(nil, tradingBuildingID: buildingID)
        case .mill:
            break
        }
    }

    private func bestTradingDestination(
        for commodityID: Int,
        trade: DeterministicTradeState,
        sourceRoad: GridPoint,
        roadNetwork: RoadNetwork,
        maximumOneWayRoadSteps: Int
    ) -> (buildingID: Int, demand: Int, path: [GridPoint])? {
        trade.buildings.compactMap { building -> (Int, Int, [GridPoint])? in
            let destination = DeliveryEndpoint.tradingBuilding(building.id)
            guard !hasIncomingDelivery(destination: destination, commodityID: commodityID),
                  trade.partner(id: building.partnerID)?.isOpen == true,
                  building.exportingCommodityIDs.contains(commodityID),
                  let path = shortestRoadPath(
                    from: sourceRoad,
                    to: building.roadAccessPoint,
                    roadNetwork: roadNetwork,
                    maximumSteps: maximumOneWayRoadSteps
                  ) else { return nil }
            let reserved = deliveryWalkers.reduce(0) { partial, walker in
                guard walker.destination == destination,
                      walker.cargo.commodityID == commodityID else { return partial }
                return partial + walker.cargo.amount
            }
            let demand = min(
                trade.exportStockDemand(tradingBuildingID: building.id, commodityID: commodityID),
                trade.availableCapacity(tradingBuildingID: building.id, commodityID: commodityID)
            ) - reserved
            guard demand > 0 else { return nil }
            return (building.id, demand, path)
        }.min {
            if $0.2.count != $1.2.count { return $0.2.count < $1.2.count }
            return $0.0 < $1.0
        }
    }

    private func bestProductionDestination(
        for commodityID: Int,
        excluding sourceBuildingID: Int?,
        production: DeterministicProductionState,
        sourceRoad: GridPoint,
        roadNetwork: RoadNetwork,
        maximumOneWayRoadSteps: Int
    ) -> (buildingID: Int, demand: Int, path: [GridPoint])? {
        production.buildings.compactMap { building -> (Int, Int, [GridPoint])? in
            guard building.id != sourceBuildingID,
                  building.isEnabled,
                  let destinationRoad = building.roadAccessPoint,
                  !hasIncomingDelivery(
                    destination: .productionBuilding(building.id),
                    commodityID: commodityID
                  ),
                  let demand = inputDemand(
                    commodityID: commodityID,
                    building: building
                  ), demand > 0,
                  let path = shortestRoadPath(
                    from: sourceRoad,
                    to: destinationRoad,
                    roadNetwork: roadNetwork,
                    maximumSteps: maximumOneWayRoadSteps
                  ) else { return nil }
            return (building.id, demand, path)
        }.min {
            if $0.2.count != $1.2.count { return $0.2.count < $1.2.count }
            return $0.0 < $1.0
        }
    }

    private func bestWarehouseDestination(
        for commodityID: Int,
        sourceRoad: GridPoint,
        roadNetwork: RoadNetwork,
        maximumOneWayRoadSteps: Int
    ) -> (warehouseID: Int, capacity: Int, path: [GridPoint])? {
        warehouses.compactMap { warehouse -> (Int, Int, [GridPoint])? in
            let reserved = deliveryWalkers.reduce(0) { partial, walker in
                guard walker.destination == .warehouse(warehouse.id),
                      walker.cargo.commodityID == commodityID else { return partial }
                return partial + walker.cargo.amount
            }
            let capacity = warehouse.availableCapacity(for: commodityID) - reserved
            guard capacity > 0,
                  let path = shortestRoadPath(
                    from: sourceRoad,
                    to: warehouse.roadAccessPoint,
                    roadNetwork: roadNetwork,
                    maximumSteps: maximumOneWayRoadSteps
                  ) else { return nil }
            return (warehouse.id, capacity, path)
        }.min { lhs, rhs in
            let lhsGet = warehouses.first(where: { $0.id == lhs.0 })?.policy(for: commodityID) == .get
            let rhsGet = warehouses.first(where: { $0.id == rhs.0 })?.policy(for: commodityID) == .get
            if lhsGet != rhsGet { return lhsGet }
            if lhs.2.count != rhs.2.count { return lhs.2.count < rhs.2.count }
            return lhs.0 < rhs.0
        }
    }

    private func bestMillDestination(
        for commodityID: Int,
        sourceRoad: GridPoint,
        roadNetwork: RoadNetwork,
        maximumOneWayRoadSteps: Int,
        activeMillIDs: Set<Int>? = nil
    ) -> (millID: Int, capacity: Int, path: [GridPoint])? {
        mills.compactMap { mill -> (Int, Int, [GridPoint])? in
            guard activeMillIDs?.contains(mill.id) ?? true else { return nil }
            let reserved = deliveryWalkers.reduce(0) { partial, walker in
                guard walker.destination == .mill(mill.id),
                      walker.cargo.commodityID == commodityID else { return partial }
                return partial + walker.cargo.amount
            }
            let capacity = mill.availableCapacity(for: commodityID) - reserved
            guard capacity > 0,
                  let path = shortestRoadPath(
                    from: sourceRoad,
                    to: mill.roadAccessPoint,
                    roadNetwork: roadNetwork,
                    maximumSteps: maximumOneWayRoadSteps
                  ) else { return nil }
            return (mill.id, capacity, path)
        }.min {
            if $0.2.count != $1.2.count { return $0.2.count < $1.2.count }
            return $0.0 < $1.0
        }
    }

    private func inputDemand(commodityID: Int, building: ProductionBuilding) -> Int? {
        guard let recipe = OriginalProductionCatalog.recipe(forBuildingID: building.buildingID),
              !recipe.inputOptions.allSatisfy(\.isEmpty) else { return nil }
        if recipe.inputOptions.contains(where: { option in
            option.allSatisfy {
                building.inputInventoryByCommodityID[$0.commodityID, default: 0] >= $0.amount
            }
        }) {
            return nil
        }
        return recipe.inputOptions.compactMap { option in
            option.first(where: { $0.commodityID == commodityID }).map {
                max(0, $0.amount - building.inputInventoryByCommodityID[commodityID, default: 0])
            }
        }.max()
    }

    private func hasIncomingDelivery(destination: DeliveryEndpoint, commodityID: Int) -> Bool {
        deliveryWalkers.contains {
            $0.destination == destination && $0.cargo.commodityID == commodityID && !$0.hasDelivered
        }
    }

    private func shortestRoadPath(
        from start: GridPoint,
        to destination: GridPoint,
        roadNetwork: RoadNetwork,
        maximumSteps: Int
    ) -> [GridPoint]? {
        guard maximumSteps >= 0,
              abs(start.x - destination.x) + abs(start.y - destination.y) <= maximumSteps,
              roadNetwork.contains(start), roadNetwork.contains(destination) else { return nil }
        if start == destination { return [start] }

        // Delivery searches are range-bounded and road networks are sparse.
        // Allocating width*height arrays for every producer/destination pair
        // made a 140×140 map pay for thousands of irrelevant non-road tiles.
        // This bounded BFS visits only reachable road points while preserving
        // GridPathfinder's deterministic north/east/south/west tie-breaking.
        let directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        var queue: [(point: GridPoint, distance: Int)] = [(start, 0)]
        var head = 0
        var visited: Set<GridPoint> = [start]
        var previous: [GridPoint: GridPoint] = [:]

        while head < queue.count {
            let current = queue[head]
            head += 1
            guard current.distance < maximumSteps else { continue }
            for direction in directions {
                let next = GridPoint(
                    x: current.point.x + direction.0,
                    y: current.point.y + direction.1
                )
                guard !visited.contains(next), roadNetwork.contains(next) else { continue }
                visited.insert(next)
                previous[next] = current.point
                if next == destination {
                    var reversed = [destination]
                    var cursor = destination
                    while cursor != start {
                        guard let parent = previous[cursor] else { return nil }
                        reversed.append(parent)
                        cursor = parent
                    }
                    return reversed.reversed()
                }
                queue.append((next, current.distance + 1))
            }
        }
        return nil
    }
}
