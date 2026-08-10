import Foundation

public struct SimulationCalendar: Sendable, Equatable, Codable {
    public private(set) var year: Int
    public private(set) var month: Int

    public init(year: Int, month: Int = 1) {
        self.year = year
        self.month = min(max(month, 1), 12)
    }

    public mutating func advanceMonth() {
        if month == 12 {
            month = 1
            year += 1
        } else {
            month += 1
        }
    }
}

public struct ResidentialUnit: Identifiable, Sendable, Equatable, Codable {
    public let id: Int
    public var houseLevelID: Int
    public var residents: Int
    public var hasTaxCoverage: Bool
    public var footprintMultiplier: Int
    public var location: GridPoint?
    public var orientation: IsometricBuildingOrientation
    public var suppliesByCommodityID: [Int: Int]
    public var commodityShortageMonths: Int
    public var foodSupplyAmount: Int
    public var foodQualityRawValue: Int
    public var serviceCoverage: Set<WalkerServiceKind>
    public var desirability: Int
    public var lastSuppliedFoodQualityRawValue: Int
    public var lastSuppliedCommodityIDs: Set<Int>

    public init(
        id: Int,
        houseLevelID: Int,
        residents: Int = 0,
        hasTaxCoverage: Bool = false,
        footprintMultiplier: Int = 1,
        location: GridPoint? = nil,
        orientation: IsometricBuildingOrientation = .northSouth,
        suppliesByCommodityID: [Int: Int] = [:],
        commodityShortageMonths: Int = 0,
        foodSupplyAmount: Int = 0,
        foodQualityRawValue: Int = FoodQuality.none.rawValue,
        serviceCoverage: Set<WalkerServiceKind> = [],
        desirability: Int = 0,
        lastSuppliedFoodQualityRawValue: Int = FoodQuality.none.rawValue,
        lastSuppliedCommodityIDs: Set<Int> = []
    ) {
        self.id = id
        self.houseLevelID = houseLevelID
        self.residents = max(0, residents)
        self.hasTaxCoverage = hasTaxCoverage
        self.footprintMultiplier = max(1, footprintMultiplier)
        self.location = location
        self.orientation = orientation
        self.suppliesByCommodityID = suppliesByCommodityID
        self.commodityShortageMonths = max(0, commodityShortageMonths)
        self.foodSupplyAmount = max(0, foodSupplyAmount)
        self.foodQualityRawValue = foodQualityRawValue
        self.serviceCoverage = serviceCoverage
        self.desirability = desirability
        self.lastSuppliedFoodQualityRawValue = lastSuppliedFoodQualityRawValue
        self.lastSuppliedCommodityIDs = lastSuppliedCommodityIDs
    }

    public func capacity(using models: BuildingModelTable) -> Int {
        (models[houseLevelID: houseLevelID]?.populationCapacity ?? 0) * footprintMultiplier
    }

    public subscript(commodityID commodityID: Int) -> Int {
        suppliesByCommodityID[commodityID, default: 0]
    }

    public mutating func addSupply(commodityID: Int, amount: Int) {
        guard amount > 0 else { return }
        suppliesByCommodityID[commodityID, default: 0] += amount
    }

    public var foodQuality: FoodQuality {
        FoodQuality(rawValue: foodQualityRawValue) ?? .none
    }

    public var lastSuppliedFoodQuality: FoodQuality {
        FoodQuality(rawValue: lastSuppliedFoodQualityRawValue) ?? .none
    }

    public mutating func recordEvolutionSupplies(
        foodQuality: FoodQuality,
        commodityIDs: Set<Int>
    ) {
        lastSuppliedFoodQualityRawValue = foodQuality.rawValue
        lastSuppliedCommodityIDs = commodityIDs
    }

    public mutating func addFoodSupply(amount: Int, quality: FoodQuality) {
        guard amount > 0 else { return }
        if foodSupplyAmount == 0 {
            foodQualityRawValue = quality.rawValue
        } else {
            // Mixing a new delivery cannot make the existing food better than
            // its weakest component, matching the market's minimum-quality rule.
            foodQualityRawValue = min(foodQualityRawValue, quality.rawValue)
        }
        foodSupplyAmount += amount
    }

    @discardableResult
    public mutating func consumeFood(_ amount: Int) -> Int {
        let consumed = min(max(0, amount), foodSupplyAmount)
        foodSupplyAmount -= consumed
        if foodSupplyAmount == 0 { foodQualityRawValue = FoodQuality.none.rawValue }
        return consumed
    }

    @discardableResult
    public mutating func consumeSupply(commodityID: Int, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let available = suppliesByCommodityID[commodityID, default: 0]
        let consumed = min(amount, available)
        suppliesByCommodityID[commodityID] = available - consumed
        return consumed
    }

    private enum CodingKeys: String, CodingKey {
        case id, houseLevelID, residents, hasTaxCoverage, footprintMultiplier, location
        case orientation
        case suppliesByCommodityID, commodityShortageMonths
        case foodSupplyAmount, foodQualityRawValue
        case serviceCoverage, desirability
        case lastSuppliedFoodQualityRawValue, lastSuppliedCommodityIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        houseLevelID = try container.decode(Int.self, forKey: .houseLevelID)
        residents = try container.decode(Int.self, forKey: .residents)
        hasTaxCoverage = try container.decode(Bool.self, forKey: .hasTaxCoverage)
        footprintMultiplier = try container.decode(Int.self, forKey: .footprintMultiplier)
        location = try container.decodeIfPresent(GridPoint.self, forKey: .location)
        orientation = try container.decodeIfPresent(
            IsometricBuildingOrientation.self,
            forKey: .orientation
        ) ?? .northSouth
        suppliesByCommodityID = try container.decodeIfPresent(
            [Int: Int].self,
            forKey: .suppliesByCommodityID
        ) ?? [:]
        commodityShortageMonths = try container.decodeIfPresent(
            Int.self,
            forKey: .commodityShortageMonths
        ) ?? 0
        foodSupplyAmount = try container.decodeIfPresent(Int.self, forKey: .foodSupplyAmount) ?? 0
        foodQualityRawValue = try container.decodeIfPresent(Int.self, forKey: .foodQualityRawValue)
            ?? FoodQuality.none.rawValue
        serviceCoverage = try container.decodeIfPresent(
            Set<WalkerServiceKind>.self,
            forKey: .serviceCoverage
        ) ?? []
        desirability = try container.decodeIfPresent(Int.self, forKey: .desirability) ?? 0
        lastSuppliedFoodQualityRawValue = try container.decodeIfPresent(
            Int.self,
            forKey: .lastSuppliedFoodQualityRawValue
        ) ?? FoodQuality.none.rawValue
        lastSuppliedCommodityIDs = try container.decodeIfPresent(
            Set<Int>.self,
            forKey: .lastSuppliedCommodityIDs
        ) ?? []
    }
}

public struct MonthlySettlement: Sendable, Equatable, Codable {
    public let year: Int
    public let month: Int
    public let population: Int
    public let taxedPopulation: Int
    public let untaxedPopulation: Int
    public let collectedTaxes: Int
    public let uncollectedTaxes: Int
    public let taxSentiment: Int
    public let startingTreasury: Int
    public let endingTreasury: Int
}

/// Result of a demolish/bulldoze action, used by the native UI to surface a
/// confirmation message and to know whether anything was actually removed.
public enum DemolishOutcome: Sendable, Equatable {
    /// A placed simulation building was removed.
    case building(buildingID: Int, refund: Int)
    /// A residential house tile was cleared.
    case house(refund: Int)
    /// A single road tile was bulldozed.
    case road(refund: Int)
    /// The targeted tile held nothing demolishable.
    case nothing

    public var removedSomething: Bool {
        if case .nothing = self { return false }
        return true
    }

    public var refund: Int {
        switch self {
        case let .building(_, refund): refund
        case let .house(refund): refund
        case let .road(refund): refund
        case .nothing: 0
        }
    }
}

public struct DeterministicCityState: Sendable, Equatable, Codable {
    public private(set) var calendar: SimulationCalendar
    public private(set) var economy: DeterministicEconomyState
    public private(set) var houses: [ResidentialUnit]
    public private(set) var roadNetwork: RoadNetwork
    public private(set) var production: DeterministicProductionState
    // Optional storage preserves decoding compatibility with native format-v1
    // saves written before road walkers were introduced.
    private var walkerState: DeterministicWalkerState?
    // Optional for the same reason: saves created before physical warehouses
    // decode into an empty logistics network rather than failing.
    private var logisticsState: DeterministicLogisticsState?
    private var marketState: DeterministicMarketState?
    private var productionAccountingState: DeterministicProductionAccounting?
    private var tradeState: DeterministicTradeState?
    // Optional so native saves written before original terrain was attached
    // continue to decode as free-form sandbox cities.
    private var terrainState: DeterministicTerrainState?
    // Optional so format-v1 saves written before campaign start settings were
    // decoded continue to load without migration.
    private var missionSettingsState: CampaignMissionStartSettings?
    // Optional additions preserve all earlier format-v1 native saves.
    private var residentialServiceBuildingState: [ResidentialServiceBuilding]?
    private var lastHousingSettlementState: HousingMonthlySettlement?
    private var housingEvolutionEnabledState: Bool?
    // Optional geometry keeps every earlier format-v1 save decodable. Legacy
    // buildings without geometry remain attached to their old road access point.
    private var buildingPlacementState: [PlacedBuilding]?
    // Optional operations fields preserve every earlier native format-v1 save.
    private var operationsState: DeterministicCityOperationsState?
    private var workforceEnabledState: Bool?
    private var publicHealthSafetyState: DeterministicPublicHealthSafetyState?
    private var publicSafetyEnabledState: Bool?
    // Optional so every save from before native military simulation decodes.
    private var militaryState: DeterministicMilitaryState?
    private var aestheticState: DeterministicAestheticState?
    // Optional continuous-time state preserves every earlier format-v1 save.
    private var simulationClockState: SimulationClockState?
    private var monthlyServiceCoverageState: MonthlyServiceCoverageAccumulator?
    private var migrationState: DeterministicMigrationState?
    // Internal so the campaign-event extension can mutate it while the public
    // API remains read-only and save compatible.
    var campaignEventState: CampaignCityEventState?
    public var taxBandID: Int
    public var difficulty: GameDifficulty
    private var nextHouseID: Int

    public init(
        year: Int,
        month: Int = 1,
        treasury: Int,
        taxBandID: Int = 2,
        difficulty: GameDifficulty = .normal,
        mapWidth: Int = 12,
        mapHeight: Int = 9
    ) {
        calendar = SimulationCalendar(year: year, month: month)
        economy = DeterministicEconomyState(treasury: treasury)
        houses = []
        roadNetwork = RoadNetwork(width: mapWidth, height: mapHeight)
        production = DeterministicProductionState()
        walkerState = DeterministicWalkerState()
        logisticsState = DeterministicLogisticsState()
        marketState = DeterministicMarketState()
        productionAccountingState = DeterministicProductionAccounting()
        tradeState = DeterministicTradeState()
        terrainState = nil
        missionSettingsState = nil
        residentialServiceBuildingState = []
        lastHousingSettlementState = nil
        housingEvolutionEnabledState = true
        buildingPlacementState = []
        operationsState = DeterministicCityOperationsState()
        workforceEnabledState = false
        publicHealthSafetyState = DeterministicPublicHealthSafetyState()
        publicSafetyEnabledState = false
        militaryState = DeterministicMilitaryState()
        aestheticState = DeterministicAestheticState()
        simulationClockState = SimulationClockState()
        monthlyServiceCoverageState = MonthlyServiceCoverageAccumulator()
        migrationState = DeterministicMigrationState()
        campaignEventState = CampaignCityEventState()
        self.taxBandID = taxBandID
        self.difficulty = difficulty
        nextHouseID = 1
    }

    public var population: Int { houses.reduce(0) { $0 + $1.residents } }
    public var walkers: DeterministicWalkerState { walkerState ?? DeterministicWalkerState() }
    public var logistics: DeterministicLogisticsState { logisticsState ?? DeterministicLogisticsState() }
    public var markets: DeterministicMarketState { marketState ?? DeterministicMarketState() }
    public var productionAccounting: DeterministicProductionAccounting {
        productionAccountingState ?? DeterministicProductionAccounting()
    }
    public var trade: DeterministicTradeState { tradeState ?? DeterministicTradeState() }
    public var terrain: DeterministicTerrainState? { terrainState }
    public var missionSettings: CampaignMissionStartSettings? { missionSettingsState }
    public var residentialServiceBuildings: [ResidentialServiceBuilding] {
        residentialServiceBuildingState ?? []
    }
    public var lastHousingSettlement: HousingMonthlySettlement? {
        lastHousingSettlementState
    }
    public var housingEvolutionEnabled: Bool {
        get { housingEvolutionEnabledState ?? true }
        set { housingEvolutionEnabledState = newValue }
    }
    public var placedBuildings: [PlacedBuilding] { buildingPlacementState ?? [] }
    public var operations: DeterministicCityOperationsState {
        operationsState ?? DeterministicCityOperationsState()
    }
    public var workforceEnabled: Bool {
        get { workforceEnabledState ?? false }
        set { workforceEnabledState = newValue }
    }
    public var publicHealthSafety: DeterministicPublicHealthSafetyState {
        publicHealthSafetyState ?? DeterministicPublicHealthSafetyState()
    }
    public var publicSafetyEnabled: Bool {
        get { publicSafetyEnabledState ?? false }
        set { publicSafetyEnabledState = newValue }
    }
    public var campaignEvents: CampaignCityEventState {
        campaignEventState ?? CampaignCityEventState()
    }
    public var military: DeterministicMilitaryState {
        militaryState ?? DeterministicMilitaryState()
    }
    public var aesthetics: DeterministicAestheticState {
        aestheticState ?? DeterministicAestheticState()
    }
    public var simulationClock: SimulationClockState {
        simulationClockState ?? SimulationClockState()
    }
    public var migration: DeterministicMigrationState {
        migrationState ?? DeterministicMigrationState()
    }

    /// The single labor snapshot used by production, storage, markets and
    /// residential services during a simulation tick. Market squares have no
    /// employees in the original table; their installed shops own the labor
    /// requirement, so the square's operational key carries the sum of those
    /// authored shop requirements.
    public func workforceSnapshot(models: BuildingModelTable) -> WorkforceMonthlySettlement {
        operations.workforce(
            population: population,
            placements: placedBuildings,
            models: models,
            requiredWorkersByKey: operationalWorkerRequirements(models: models)
        )
    }

    public mutating func chargeOperatingExpense(_ amount: Int) {
        economy.chargeOperatingExpense(amount)
    }

    public func workforceAssignment(
        for placement: PlacedBuilding,
        models: BuildingModelTable
    ) -> WorkforceAssignment? {
        let key = OperationalBuildingKey(
            category: placement.category,
            instanceID: placement.instanceID
        )
        return workforceSnapshot(models: models).assignments.first { $0.key == key }
    }

    private func operationalWorkerRequirements(
        models: BuildingModelTable
    ) -> [OperationalBuildingKey: Int] {
        var result: [OperationalBuildingKey: Int] = [:]
        for building in production.buildings {
            let key = OperationalBuildingKey(
                category: .production,
                instanceID: building.id
            )
            result[key] = building.isEnabled
                ? max(0, models[buildingID: building.buildingID]?.employees ?? 0)
                : 0
        }
        for market in markets.markets {
            let key = OperationalBuildingKey(category: .market, instanceID: market.id)
            result[key] = market.shopBuildingIDs.reduce(0) {
                $0 + max(0, models[buildingID: $1]?.employees ?? 0)
            }
        }
        return result
    }

    public var occupiedBuildingPoints: Set<GridPoint> {
        let houseFootprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        var points = Set(houses.compactMap(\.location).flatMap(houseFootprint.points(at:)))
        for placement in placedBuildings {
            points.formUnion(placement.occupiedPoints)
        }
        return points
    }

    /// Houses live outside `buildingPlacementState`, but the original model
    /// table gives every visible residential tier normal fire, damage, and
    /// structural-integrity values. Project them into placement geometry for
    /// inspection and maintenance without duplicating housing state.
    var buildingFailureCandidatePlacements: [PlacedBuilding] {
        let houseFootprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        let residential = houses.compactMap { house -> PlacedBuilding? in
            guard let origin = house.location else { return nil }
            let occupied = Set(houseFootprint.points(at: origin))
            let roadAccess = occupied
                .flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
                .filter { roadNetwork.contains($0) }
                .sorted {
                    if $0.y != $1.y { return $0.y < $1.y }
                    return $0.x < $1.x
                }
                .first ?? origin
            return PlacedBuilding(
                category: .residential,
                instanceID: house.id,
                buildingID: house.houseLevelID + 3,
                origin: origin,
                orientation: house.orientation,
                footprint: houseFootprint,
                roadAccessPoint: roadAccess
            )
        }
        return placedBuildings + residential
    }

    /// Military movement treats intact walls and towers as obstacles while an
    /// intact gate remains passable. Ruined defenses stay visible and
    /// demolishable, but no longer block movement.
    public var militaryBlockedPoints: Set<GridPoint> {
        var points = occupiedBuildingPoints
        for defense in military.defensiveStructures {
            let occupied = placement(
                category: .military,
                instanceID: defense.id
            )?.occupiedPoints ?? [defense.point]
            if !defense.isOperational || defense.kind == .cityGate {
                points.subtract(occupied)
            }
        }
        return points
    }

    public init(
        year: Int,
        month: Int = 1,
        treasury: Int,
        taxBandID: Int = 2,
        difficulty: GameDifficulty = .normal,
        map: EmperorMap
    ) {
        let terrain = DeterministicTerrainState(map: map)
        self.init(
            year: year,
            month: month,
            treasury: treasury,
            taxBandID: taxBandID,
            difficulty: difficulty,
            mapWidth: terrain.width,
            mapHeight: terrain.height
        )
        terrainState = terrain
        roadNetwork = RoadNetwork(
            width: terrain.width,
            height: terrain.height,
            points: terrain.roadPoints
        )
        workforceEnabledState = true
        publicSafetyEnabledState = true
    }

    public init(
        year: Int,
        month: Int = 1,
        treasury: Int,
        taxBandID: Int = 2,
        difficulty: GameDifficulty = .normal,
        terrain: DeterministicTerrainState
    ) {
        self.init(
            year: year,
            month: month,
            treasury: treasury,
            taxBandID: taxBandID,
            difficulty: difficulty,
            mapWidth: terrain.width,
            mapHeight: terrain.height
        )
        terrainState = terrain
        roadNetwork = RoadNetwork(
            width: terrain.width,
            height: terrain.height,
            points: terrain.roadPoints
        )
    }

    /// Starts a city from the Campaign Creator's authored date, treasury and
    /// permission lists while retaining the original terrain and road network.
    public init(
        missionSettings: CampaignMissionStartSettings,
        difficulty: GameDifficulty = .normal,
        inheritedTreasury: Int? = nil,
        taxBandID: Int = 3,
        map: EmperorMap
    ) {
        self.init(
            year: missionSettings.startYear,
            month: missionSettings.startMonth,
            treasury: missionSettings.startingTreasury(
                difficulty: difficulty,
                inheritedTreasury: inheritedTreasury
            ),
            taxBandID: taxBandID,
            difficulty: difficulty,
            map: map
        )
        missionSettingsState = missionSettings
    }

    /// Advances an existing city into a continuation mission on the same
    /// authored map. Buildings, population, inventories, roads and military
    /// survive; the Campaign Creator's funds rule and all mission-local clocks,
    /// event effects and yearly goal accounting restart for the new mission.
    public mutating func continueCampaignMission(
        with missionSettings: CampaignMissionStartSettings
    ) {
        economy = DeterministicEconomyState(
            treasury: missionSettings.startingTreasury(
                difficulty: difficulty,
                inheritedTreasury: economy.treasury
            ),
            inventory: economy.inventory
        )
        calendar = SimulationCalendar(
            year: missionSettings.startYear,
            month: missionSettings.startMonth
        )
        missionSettingsState = missionSettings
        campaignEventState = CampaignCityEventState()
        productionAccountingState = DeterministicProductionAccounting()
        lastHousingSettlementState = nil
        simulationClockState = SimulationClockState()
        monthlyServiceCoverageState = MonthlyServiceCoverageAccumulator()
        migrationState = DeterministicMigrationState()
    }

    /// Headless counterpart of the original-map mission initializer. This is
    /// useful for deterministic rules tests and tools that do not need terrain.
    public init(
        missionSettings: CampaignMissionStartSettings,
        difficulty: GameDifficulty = .normal,
        inheritedTreasury: Int? = nil,
        taxBandID: Int = 3,
        mapWidth: Int = 12,
        mapHeight: Int = 9
    ) {
        self.init(
            year: missionSettings.startYear,
            month: missionSettings.startMonth,
            treasury: missionSettings.startingTreasury(
                difficulty: difficulty,
                inheritedTreasury: inheritedTreasury
            ),
            taxBandID: taxBandID,
            difficulty: difficulty,
            mapWidth: mapWidth,
            mapHeight: mapHeight
        )
        missionSettingsState = missionSettings
    }

    public func campaignConstructionRestriction(
        forBuildingID buildingID: Int
    ) -> CampaignConstructionRestriction? {
        missionSettingsState?.constructionRestriction(
            forBuildingID: buildingID,
            openTradePartners: trade.partners
        )
    }

    public func isBuildingAvailableInCampaign(_ buildingID: Int) -> Bool {
        campaignConstructionRestriction(forBuildingID: buildingID) == nil
    }

    /// Chooses a deterministic clear tile beside an existing road, avoiding
    /// occupied house tiles. This is the first native placement policy backed
    /// by the original mission terrain rather than the old 12×9 demo grid.
    public func nextHouseConstructionLocation() -> GridPoint? {
        let roads = roadNetwork.points.sorted {
            $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
        }
        let occupiedPoints = occupiedBuildingPoints
        for road in roads {
            for point in RoadServiceCoverage.orthogonalNeighbors(of: road) {
                if canConstructHouse(at: point, occupiedPoints: occupiedPoints) { return point }
            }
        }
        return nil
    }

    /// Chooses the first deterministic origin whose complete authored
    /// footprint is clear and touches a road. Repeated calls naturally move
    /// on after prior placements become occupied, so campaign trade controls
    /// can install one physical station per partner without a hidden geometry
    /// path.
    public func nextBuildingConstructionLocation(
        buildingID: Int,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> GridPoint? {
        guard isBuildingAvailableInCampaign(buildingID),
              !roadNetwork.points.isEmpty,
              let footprint = OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: buildingID,
            orientation: orientation
        ), footprint.width <= roadNetwork.width,
           footprint.height <= roadNetwork.height else { return nil }
        let occupiedPoints = occupiedBuildingPoints
        for y in 0...(roadNetwork.height - footprint.height) {
            for x in 0...(roadNetwork.width - footprint.width) {
                let point = GridPoint(x: x, y: y)
                if buildingID == 203 {
                    if canConstructIrrigationPump(at: point, orientation: orientation) {
                        return point
                    }
                    continue
                }
                if constructionFootprint(
                    buildingID: buildingID,
                    at: point,
                    orientation: orientation,
                    occupiedPoints: occupiedPoints
                ) != nil {
                    return point
                }
            }
        }
        return nil
    }

    /// Route-aware counterpart used by the campaign trade controls. Land
    /// stations use ordinary clear terrain; sea quays scan for a complete
    /// straight shoreline edge and adjacent road access.
    public func nextTradingBuildingConstructionLocation(
        partnerID: Int,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> GridPoint? {
        guard let partner = trade.partner(id: partnerID), partner.isOpen,
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: partner.routeKind.buildingID,
                orientation: orientation
              ), footprint.width <= roadNetwork.width,
                 footprint.height <= roadNetwork.height else { return nil }
        for y in 0...(roadNetwork.height - footprint.height) {
            for x in 0...(roadNetwork.width - footprint.width) {
                let origin = GridPoint(x: x, y: y)
                switch partner.routeKind {
                case .land:
                    if canConstructBuilding(
                        buildingID: partner.routeKind.buildingID,
                        at: origin,
                        orientation: orientation
                    ) { return origin }
                case .sea:
                    if preparedQuayPlacement(
                        buildingID: partner.routeKind.buildingID,
                        at: origin,
                        orientation: orientation
                    ) != nil { return origin }
                }
            }
        }
        return nil
    }

    public func quayWaterEdge(for placement: PlacedBuilding) -> QuayWaterEdge? {
        guard placement.buildingID == TradeRouteKind.sea.buildingID
                || placement.buildingID == 203,
              let terrainState else { return nil }
        return terrainState.quayWaterEdge(
            footprintPoints: placement.occupiedPoints,
            footprintWidth: placement.footprint.width,
            footprintHeight: placement.footprint.height,
            origin: placement.origin
        )
    }

    public func quayWaterAccessPoint(for placement: PlacedBuilding) -> GridPoint? {
        guard let terrainState,
              let edge = quayWaterEdge(for: placement) else { return nil }
        let points = terrainState.quayWaterPoints(
            edge: edge,
            footprintWidth: placement.footprint.width,
            footprintHeight: placement.footprint.height,
            origin: placement.origin
        )
        guard !points.isEmpty, points.allSatisfy(terrainState.isWater) else { return nil }
        return points[points.count / 2]
    }

    /// Resolves every established route against the original map entry/exit
    /// points and current building geometry. Missing or obstructed paths are
    /// intentionally omitted so monthly trade marks that facility inactive.
    public func tradeVisitorRoutes() -> [Int: TradeVisitorRoute] {
        guard let terrainState, let authored = terrainState.authoredPoints else { return [:] }
        var result: [Int: TradeVisitorRoute] = [:]
        let occupied = occupiedBuildingPoints
        for building in trade.buildings {
            guard let partner = trade.partner(id: building.partnerID) else { continue }
            let inbound: [GridPoint]?
            let outbound: [GridPoint]?
            switch partner.routeKind {
            case .land:
                guard let entry = authored.landEntry, let exit = authored.landExit else { continue }
                inbound = terrainState.shortestLandVisitorPath(
                    from: entry,
                    to: building.roadAccessPoint,
                    blocked: occupied
                )
                outbound = terrainState.shortestLandVisitorPath(
                    from: exit,
                    to: building.roadAccessPoint,
                    blocked: occupied
                ).map { Array($0.reversed()) }
            case .sea:
                guard let entry = authored.seaEntry,
                      let exit = authored.seaExit,
                      let placement = placement(category: .trading, instanceID: building.id),
                      let waterAccess = quayWaterAccessPoint(for: placement) else { continue }
                inbound = terrainState.shortestWaterPath(from: entry, to: waterAccess)
                outbound = terrainState.shortestWaterPath(from: waterAccess, to: exit)
            }
            guard let inbound, let outbound else { continue }
            let points = inbound + outbound.dropFirst()
            if let route = TradeVisitorRoute(
                points: points,
                facilityPointIndex: inbound.count - 1
            ) {
                result[building.id] = route
            }
        }
        return result
    }

    public func canConstructHouse(at point: GridPoint) -> Bool {
        canConstructHouse(at: point, occupiedPoints: occupiedBuildingPoints)
    }

    private func canConstructHouse(
        at point: GridPoint,
        occupiedPoints: Set<GridPoint>
    ) -> Bool {
        let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        let points = footprint.points(at: point)
        return points.allSatisfy(roadNetwork.isInside)
            && points.allSatisfy { !roadNetwork.contains($0) }
            && points.allSatisfy { !occupiedPoints.contains($0) }
            && points.allSatisfy { terrainState?.isClearLand($0) ?? true }
            && adjacentRoadPoints(to: points).first != nil
    }

    public func canClearVegetation(at point: GridPoint) -> Bool {
        roadNetwork.isInside(point)
            && !occupiedBuildingPoints.contains(point)
            && !roadNetwork.contains(point)
            && (terrainState?.canClearVegetation(at: point) ?? false)
    }

    @discardableResult
    public mutating func clearVegetation(at point: GridPoint) -> Bool {
        guard canClearVegetation(at: point), var terrainState else { return false }
        guard terrainState.clearVegetation(at: point) else { return false }
        self.terrainState = terrainState
        return true
    }

    public func canConstructRoad(at point: GridPoint) -> Bool {
        roadNetwork.isInside(point)
            && !roadNetwork.contains(point)
            && !occupiedBuildingPoints.contains(point)
            && (terrainState?.isClearLand(point) ?? true)
    }

    public func placement(
        category: PlacedBuildingCategory,
        instanceID: Int
    ) -> PlacedBuilding? {
        placedBuildings.first { $0.category == category && $0.instanceID == instanceID }
    }

    public func constructionFootprint(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> BuildingFootprint? {
        constructionFootprint(
            buildingID: buildingID,
            at: origin,
            orientation: orientation,
            occupiedPoints: occupiedBuildingPoints
        )
    }

    private func constructionFootprint(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation,
        occupiedPoints: Set<GridPoint>
    ) -> BuildingFootprint? {
        if OriginalMilitaryDefenseConfiguration.configuration(buildingID: buildingID) != nil {
            guard canConstructMilitaryDefense(
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            ) else {
                return nil
            }
            return OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: orientation
            )
        }
        guard isBuildingAvailableInCampaign(buildingID),
              let footprint = OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: buildingID,
            orientation: orientation
        ) else { return nil }
        let points = footprint.points(at: origin)
        guard points.allSatisfy(roadNetwork.isInside),
              points.allSatisfy({ !roadNetwork.contains($0) }),
              points.allSatisfy({ !occupiedPoints.contains($0) }),
              points.allSatisfy({ terrainAllowsConstruction(buildingID: buildingID, at: $0) }),
              adjacentRoadPoints(to: points).first != nil else { return nil }
        return footprint
    }

    public func canConstructBuilding(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> Bool {
        constructionFootprint(
            buildingID: buildingID,
            at: origin,
            orientation: orientation
        ) != nil
    }

    private func adjacentRoadPoints(to occupiedPoints: [GridPoint]) -> [GridPoint] {
        let occupied = Set(occupiedPoints)
        return Set(occupiedPoints.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)))
            .subtracting(occupied)
            .filter(roadNetwork.contains)
            .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
    }

    private func terrainAllowsConstruction(buildingID: Int, at point: GridPoint) -> Bool {
        guard let terrainState else { return true }
        guard terrainState.isClearLand(point) else { return false }
        // The original manual requires wells to sit over the water table.
        if buildingID == 72 {
            return terrainState.terrain(at: point)?.contains(.groundwater) == true
        }
        return true
    }

    private func preparedPlacement(
        category: PlacedBuildingCategory,
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation
    ) -> PlacedBuilding? {
        guard let footprint = constructionFootprint(
            buildingID: buildingID,
            at: origin,
            orientation: orientation
        ), let roadAccessPoint = adjacentRoadPoints(
            to: footprint.points(at: origin)
        ).first else { return nil }
        return PlacedBuilding(
            category: category,
            instanceID: 0,
            buildingID: buildingID,
            origin: origin,
            orientation: orientation,
            footprint: footprint,
            roadAccessPoint: roadAccessPoint
        )
    }

    public func canConstructMilitaryDefense(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> Bool {
        guard isBuildingAvailableInCampaign(buildingID),
              let configuration = OriginalMilitaryDefenseConfiguration.configuration(
                buildingID: buildingID
              ), let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: orientation
              ) else { return false }
        let points = footprint.points(at: origin)
        guard points.allSatisfy(roadNetwork.isInside),
              points.allSatisfy({ terrainState?.isClearLand($0) ?? true }),
              !houses.contains(where: { house in
                  house.location.map(Set(points).contains) ?? false
              }) else { return false }
        let intersectingPlacements = placedBuildings.filter { placement in
            !Set(placement.occupiedPoints).isDisjoint(with: points)
        }
        if configuration.kind == .cityWall {
            if let existingPlacement = intersectingPlacements.first {
                guard intersectingPlacements.count == 1 else { return false }
                return existingPlacement.buildingID == buildingID
                    && military.defensiveStructures.first(where: {
                        $0.id == existingPlacement.instanceID
                    })?.isOperational == false
            }
            return true
        }
        guard intersectingPlacements.allSatisfy({ $0.buildingID == 129 }) else { return false }

        let requiredWallPoints: [GridPoint]
        if configuration.kind == .tower {
            requiredWallPoints = points
        } else if footprint.width > footprint.height {
            requiredWallPoints = (0..<footprint.width).map {
                GridPoint(x: origin.x + $0, y: origin.y + footprint.height / 2)
            }
        } else {
            requiredWallPoints = (0..<footprint.height).map {
                GridPoint(x: origin.x + footprint.width / 2, y: origin.y + $0)
            }
        }
        guard requiredWallPoints.allSatisfy({ wallPoint in
            intersectingPlacements.contains {
                $0.buildingID == 129 && $0.occupiedPoints.contains(wallPoint)
            }
        }) else { return false }
        guard configuration.kind == .cityGate else { return true }

        // A gate replaces a straight wall segment crossed perpendicularly by
        // a continuous road through the full reserved rectangle.
        let requiredRoadPoints: [GridPoint]
        if footprint.width > footprint.height {
            requiredRoadPoints = (0..<footprint.height).map {
                GridPoint(x: origin.x + footprint.width / 2, y: origin.y + $0)
            }
        } else {
            requiredRoadPoints = (0..<footprint.width).map {
                GridPoint(x: origin.x + $0, y: origin.y + footprint.height / 2)
            }
        }
        return requiredRoadPoints.allSatisfy(roadNetwork.contains)
    }

    private func preparedQuayPlacement(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation
    ) -> PlacedBuilding? {
        guard isBuildingAvailableInCampaign(buildingID),
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: orientation
              ),
              let terrainState else { return nil }
        let points = footprint.points(at: origin)
        let occupiedPoints = occupiedBuildingPoints
        guard points.allSatisfy(roadNetwork.isInside),
              points.allSatisfy({ !roadNetwork.contains($0) }),
              points.allSatisfy({ !occupiedPoints.contains($0) }),
              terrainState.isValidQuaySite(
                footprintPoints: points,
                footprintWidth: footprint.width,
                footprintHeight: footprint.height,
                origin: origin
              ),
              let roadAccessPoint = adjacentRoadPoints(to: points).first
        else { return nil }
        return PlacedBuilding(
            category: .trading,
            instanceID: 0,
            buildingID: buildingID,
            origin: origin,
            orientation: orientation,
            footprint: footprint,
            roadAccessPoint: roadAccessPoint
        )
    }

    private mutating func recordPlacement(_ placement: PlacedBuilding, instanceID: Int) {
        var placements = buildingPlacementState ?? []
        placements.append(PlacedBuilding(
            category: placement.category,
            instanceID: instanceID,
            buildingID: placement.buildingID,
            origin: placement.origin,
            orientation: placement.orientation,
            footprint: placement.footprint,
            roadAccessPoint: placement.roadAccessPoint
        ))
        buildingPlacementState = placements
    }

    public func campaignGoalProgressSnapshot(
        alliedCityCount: Int = 0,
        conqueredCityCount: Int = 0,
        homageProgress: Int = 0,
        menagerieSpeciesCount: Int = 0,
        completedMonumentBuildingIDs: Set<Int>? = nil,
        tradingPartnerCount: Int? = nil
    ) -> CampaignGoalProgressSnapshot {
        let housingByLevel = houses.reduce(into: [Int: Int]()) {
            // Campaign archives encode the first house goal level as 3 while
            // the building model table numbers house levels from zero.
            $0[$1.houseLevelID + 3, default: 0] += $1.residents
        }
        let accounting = productionAccounting
        return CampaignGoalProgressSnapshot(
            alliedCityCount: alliedCityCount,
            conqueredCityCount: conqueredCityCount,
            homageProgress: homageProgress,
            housingPopulationByLevelCode: housingByLevel,
            menagerieSpeciesCount: menagerieSpeciesCount,
            completedMonumentBuildingIDs: completedMonumentBuildingIDs
                ?? aesthetics.completedMonumentBuildingIDs,
            population: population,
            tradingPartnerCount: tradingPartnerCount ?? trade.establishedPartnerCount,
            treasury: economy.treasury,
            bestYearlyProductionUnitsByCommodityID: accounting.bestYearlyProductionUnitsByCommodityID,
            bestYearlyProfit: accounting.bestYearlyProfit
        )
    }

    public func storedCampaignCommodityAmount(commodityID: Int) -> Int {
        logisticsState?[commodityID: commodityID] ?? 0
    }

    @discardableResult
    public mutating func receiveCampaignCash(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        economy.credit(amount)
        return amount
    }

    @discardableResult
    public mutating func payCampaignCash(_ amount: Int) -> Bool {
        guard amount >= 0 else { return false }
        return economy.debit(amount)
    }

    public mutating func setCampaignTradeOpen(_ open: Bool, partnerID: Int) {
        var state = tradeState ?? DeterministicTradeState()
        state.setPartnerOpen(open, partnerID: partnerID)
        tradeState = state
    }

    /// Goods gifts use displayed loads in campaign data (100 internal units
    /// each) and must fit in physical storage, just as the original event text
    /// describes. The runtime retains and retries any remainder.
    @discardableResult
    public mutating func receiveCampaignCommodityGift(
        commodityID: Int,
        amount: Int
    ) -> Int {
        guard var logistics = logisticsState, amount > 0 else { return 0 }
        let stored = logistics.storeCampaignGift(
            commodityID: commodityID,
            amount: amount,
            production: &production
        )
        logisticsState = logistics
        return stored
    }

    @discardableResult
    public mutating func fulfillCampaignRequest(
        commodityID: Int,
        amount: Int
    ) -> Bool {
        guard amount > 0 else { return false }
        if commodityID == CampaignMissionRuntimeState.cashProductID {
            return economy.debit(amount)
        }
        guard var logistics = logisticsState else { return false }
        let fulfilled = logistics.takeCampaignRequestGoods(
            commodityID: commodityID,
            amount: amount,
            production: &production
        )
        logisticsState = logistics
        return fulfilled
    }

    @discardableResult
    public mutating func adjustCampaignTrade(
        kind: CampaignEventKind,
        partnerID: Int?,
        commodityID: Int,
        amount: Int,
        models: OriginalEconomyModels
    ) -> Int {
        var trade = tradeState ?? DeterministicTradeState()
        let changed: Int
        switch kind {
        case .demandIncrease, .demandDecrease:
            guard let partnerID else { return 0 }
            changed = trade.adjustDemand(
                partnerID: partnerID,
                commodityID: commodityID,
                delta: kind == .demandIncrease ? 1 : -1,
                tradeRules: models.trade
            ) ? 1 : 0
        case .supplyIncrease, .supplyDecrease:
            guard let partnerID else { return 0 }
            changed = trade.adjustSupply(
                partnerID: partnerID,
                commodityID: commodityID,
                delta: kind == .supplyIncrease ? 1 : -1,
                tradeRules: models.trade
            ) ? 1 : 0
        case .priceIncrease, .priceDecrease:
            let defaultPrice = models.trade[commodityID: commodityID]?.price ?? 0
            changed = trade.adjustPrice(
                commodityID: commodityID,
                delta: kind == .priceIncrease ? amount : -amount,
                defaultPrice: defaultPrice
            )
        default:
            return 0
        }
        tradeState = trade
        return changed
    }

    public func housingCapacity(using models: BuildingModelTable) -> Int {
        houses.reduce(0) { $0 + $1.capacity(using: models) }
    }

    @discardableResult
    public mutating func constructHouse(
        levelID: Int = 0,
        constructionBuildingID: Int = 2,
        hasTaxCoverage: Bool = false,
        footprintMultiplier: Int = 1,
        location: GridPoint? = nil,
        orientation: IsometricBuildingOrientation = .northSouth,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard isBuildingAvailableInCampaign(constructionBuildingID),
              rules.models.buildings[houseLevelID: levelID] != nil,
              location.map(canConstructHouse(at:)) ?? true,
              economy.spendOnConstruction(
                buildingID: constructionBuildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        return addHouse(
            levelID: levelID,
            hasTaxCoverage: hasTaxCoverage,
            footprintMultiplier: footprintMultiplier,
            location: location,
            orientation: orientation,
            models: rules.models.buildings
        )
    }

    /// Places the original one-tile road block on an existing road. It is a
    /// construction object rather than a second road tile, so bulldozing it
    /// leaves the authored road underneath intact.
    public func canConstructRoadBlock(
        at point: GridPoint,
        buildingID: Int = 126
    ) -> Bool {
        isBuildingAvailableInCampaign(buildingID)
            && roadNetwork.contains(point)
            && !occupiedBuildingPoints.contains(point)
    }

    @discardableResult
    public mutating func constructRoadBlock(
        at point: GridPoint,
        buildingID: Int = 126,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard canConstructRoadBlock(at: point, buildingID: buildingID),
              economy.spendOnConstruction(
                buildingID: buildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        let instanceID = 1_000_000 + placedBuildings.count {
            $0.buildingID == buildingID
        } + 1
        var placements = buildingPlacementState ?? []
        placements.append(PlacedBuilding(
            category: .aesthetic,
            instanceID: instanceID,
            buildingID: buildingID,
            origin: point,
            orientation: .northSouth,
            footprint: BuildingFootprint(width: 1, height: 1),
            roadAccessPoint: point
        ))
        buildingPlacementState = placements
        return instanceID
    }

    @discardableResult
    public mutating func addHouse(
        levelID: Int,
        residents: Int = 0,
        hasTaxCoverage: Bool = false,
        footprintMultiplier: Int = 1,
        location: GridPoint? = nil,
        orientation: IsometricBuildingOrientation = .northSouth,
        models: BuildingModelTable
    ) -> Int? {
        guard let model = models[houseLevelID: levelID],
              location.map(roadNetwork.isInside) ?? true else { return nil }
        let multiplier = max(1, footprintMultiplier)
        let id = nextHouseID
        nextHouseID += 1
        houses.append(ResidentialUnit(
            id: id,
            houseLevelID: levelID,
            residents: min(max(0, residents), model.populationCapacity * multiplier),
            hasTaxCoverage: hasTaxCoverage,
            footprintMultiplier: multiplier,
            location: location,
            orientation: orientation
        ))
        return id
    }

    @discardableResult
    public mutating func admitResidents(_ requested: Int, models: BuildingModelTable) -> Int {
        guard requested > 0 else { return 0 }
        var remaining = requested
        for index in houses.indices.sorted(by: { houses[$0].id < houses[$1].id }) where remaining > 0 {
            let vacancy = max(0, houses[index].capacity(using: models) - houses[index].residents)
            let admitted = min(vacancy, remaining)
            houses[index].residents += admitted
            remaining -= admitted
        }
        return requested - remaining
    }

    private mutating func admitResidents(
        _ requested: Int,
        eligibleHouseIDs: Set<Int>,
        models: BuildingModelTable
    ) -> Int {
        guard requested > 0, !eligibleHouseIDs.isEmpty else { return 0 }
        var remaining = requested
        // Elite compounds attract their own migrant class in the original
        // game. Prefer the highest authored housing tier, while retaining
        // stable ID order within a tier, so a large common-housing reserve
        // cannot permanently starve vacant elite compounds.
        let admissionOrder = houses.indices.sorted {
            if houses[$0].houseLevelID != houses[$1].houseLevelID {
                return houses[$0].houseLevelID > houses[$1].houseLevelID
            }
            return houses[$0].id < houses[$1].id
        }
        for index in admissionOrder where
            remaining > 0 && eligibleHouseIDs.contains(houses[index].id) {
            let vacancy = max(0, houses[index].capacity(using: models) - houses[index].residents)
            let admitted = min(vacancy, remaining)
            houses[index].residents += admitted
            remaining -= admitted
        }
        return requested - remaining
    }

    public mutating func setTaxCoverage(_ covered: Bool, houseID: Int) {
        guard let index = houses.firstIndex(where: { $0.id == houseID }) else { return }
        houses[index].hasTaxCoverage = covered
    }

    public mutating func setHouseLocation(_ location: GridPoint?, houseID: Int) {
        guard let index = houses.firstIndex(where: { $0.id == houseID }) else { return }
        houses[index].location = location
    }

    @discardableResult
    public mutating func constructProductionBuilding(
        buildingID: Int,
        assignedWorkers: Int = 0,
        serviceRoadStart: GridPoint? = nil,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard isBuildingAvailableInCampaign(buildingID),
              OriginalProductionCatalog.recipe(forBuildingID: buildingID) != nil,
              let model = rules.models.buildings[buildingID: buildingID], model.employees > 0,
              serviceRoadStart.map(roadNetwork.contains) ?? true,
              economy.spendOnConstruction(
                buildingID: buildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        return production.addBuilding(
            buildingID: buildingID,
            assignedWorkers: assignedWorkers,
            roadAccessPoint: serviceRoadStart,
            models: rules.models.buildings
        )
    }

    /// Constructs an original production building on its complete authored
    /// footprint and binds the simulation instance to the nearest adjacent road.
    @discardableResult
    public mutating func constructProductionBuilding(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        assignedWorkers: Int = 0,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedPlacement(
            category: .production,
            buildingID: buildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard let id = updated.constructProductionBuilding(
            buildingID: buildingID,
            assignedWorkers: assignedWorkers,
            serviceRoadStart: placement.roadAccessPoint,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    /// Constructs one original seasonal farm/orchard unit and, for legacy
    /// headless callers, an optional initial number of tended plots as a single
    /// transaction. Map-facing play places the producer first with zero fields,
    /// then adds visible plots through `constructAgriculturalPlot`.
    @discardableResult
    public mutating func constructAgriculturalProducer(
        crop: AgriculturalCrop,
        fieldCount: Int,
        fertilityPercent: Int,
        climate: AgriculturalClimate,
        serviceRoadStart: GridPoint,
        assignedWorkers: Int? = nil,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard fieldCount >= 0,
              missionSettingsState?.allowedResourceCommodityIDs.contains(
                crop.outputCommodityID
              ) ?? true,
              roadNetwork.contains(serviceRoadStart),
              let producerModel = rules.models.buildings[buildingID: crop.producerBuildingID],
              producerModel.employees > 0,
              rules.models.buildings[buildingID: crop.plotBuildingID] != nil else { return nil }

        var updatedEconomy = economy
        guard updatedEconomy.spendOnConstruction(
            buildingID: crop.producerBuildingID,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        if fieldCount > 0,
           !updatedEconomy.spendOnConstruction(
            buildingID: crop.plotBuildingID,
            quantity: fieldCount,
            rules: rules,
            difficulty: difficulty
           ) {
            return nil
        }

        let configuration = AgriculturalConfiguration(
            crop: crop,
            fieldCount: fieldCount,
            fertilityPercent: fertilityPercent,
            climate: climate
        )
        var updatedProduction = production
        guard let id = updatedProduction.addAgriculturalBuilding(
            configuration: configuration,
            assignedWorkers: assignedWorkers ?? producerModel.employees,
            roadAccessPoint: serviceRoadStart,
            models: rules.models.buildings
        ) else { return nil }
        economy = updatedEconomy
        production = updatedProduction
        return id
    }

    public func canConstructAgriculturalProducer(
        crop: AgriculturalCrop,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> Bool {
        isAgriculturalCropAvailable(crop)
            && constructionFootprint(
                buildingID: crop.producerBuildingID,
                at: origin,
                orientation: orientation
            ) != nil
    }

    /// Places the physical farm/orchard before any fields are assigned to it.
    /// This is the two-stage interaction shown by the original application.
    @discardableResult
    public mutating func constructAgriculturalProducer(
        crop: AgriculturalCrop,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        fertilityPercent: Int = 100,
        climate: AgriculturalClimate = .temperate,
        assignedWorkers: Int? = nil,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedPlacement(
            category: .production,
            buildingID: crop.producerBuildingID,
            at: origin,
            orientation: orientation
        ), isAgriculturalCropAvailable(crop) else { return nil }
        var updated = self
        guard let id = updated.constructAgriculturalProducer(
            crop: crop,
            fieldCount: 0,
            fertilityPercent: fertilityPercent,
            climate: climate,
            serviceRoadStart: placement.roadAccessPoint,
            assignedWorkers: assignedWorkers,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    /// Whether a crop is offered by the active mission's resource rules.
    public func isAgriculturalCropAvailable(_ crop: AgriculturalCrop) -> Bool {
        missionSettingsState?.allowedResourceCommodityIDs.contains(
            crop.outputCommodityID
        ) ?? true
    }

    /// Validates one visible plot against a matching farm/orchard's authored
    /// tending range and capacity. Fields do not need direct road access; the
    /// producer building does.
    public func canConstructAgriculturalPlot(
        crop: AgriculturalCrop,
        at origin: GridPoint,
        rules: EconomyRulesEngine? = nil
    ) -> Bool {
        guard isAgriculturalCropAvailable(crop),
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: crop.plotBuildingID
              ) else { return false }
        let points = footprint.points(at: origin)
        return points.allSatisfy(roadNetwork.isInside)
            && points.allSatisfy { !roadNetwork.contains($0) }
            && points.allSatisfy { !occupiedBuildingPoints.contains($0) }
            && points.allSatisfy {
                terrainAllowsConstruction(buildingID: crop.plotBuildingID, at: $0)
            }
            && agriculturalProducerCandidate(
                crop: crop,
                plotOrigin: origin,
                rules: rules
            ) != nil
    }

    /// Constructs a crop-specific plot and binds its original artwork to the
    /// corresponding agricultural simulation instance.
    @discardableResult
    public mutating func constructAgriculturalPlot(
        crop: AgriculturalCrop,
        at origin: GridPoint,
        fertilityPercent: Int = 100,
        climate: AgriculturalClimate = .temperate,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard canConstructAgriculturalPlot(crop: crop, at: origin, rules: rules),
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: crop.plotBuildingID
              ), let producer = agriculturalProducerCandidate(
                crop: crop,
                plotOrigin: origin,
                rules: rules
              ) else { return nil }
        var updated = self
        guard updated.economy.spendOnConstruction(
            buildingID: crop.plotBuildingID,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        updated.production.setAgriculturalFieldCount(
            producer.configuration.fieldCount + 1,
            buildingInstanceID: producer.id
        )
        updated.recordPlacement(
            PlacedBuilding(
                category: .agriculturalPlot,
                instanceID: producer.id,
                buildingID: crop.plotBuildingID,
                origin: origin,
                orientation: .northSouth,
                footprint: footprint,
                roadAccessPoint: producer.roadAccessPoint
            ), instanceID: producer.id
        )
        self = updated
        return producer.id
    }

    private func agriculturalProducerCandidate(
        crop: AgriculturalCrop,
        plotOrigin: GridPoint,
        rules: EconomyRulesEngine?
    ) -> (id: Int, roadAccessPoint: GridPoint, configuration: AgriculturalConfiguration)? {
        let agricultureRules = rules.map { OriginalAgricultureRules(farm: $0.models.farm) }
        let tendingRange = agricultureRules?.tendingRange(for: crop.category) ?? 3
        let maximumFields = agricultureRules?.maximumTendedFields(for: crop.category) ?? 9
        let candidates: [(
            id: Int,
            roadAccessPoint: GridPoint,
            configuration: AgriculturalConfiguration,
            distance: Int
        )] = production.buildings.compactMap { building in
            guard let configuration = building.agriculture,
                  configuration.crop == crop,
                  configuration.fieldCount < maximumFields,
                  let roadAccessPoint = building.roadAccessPoint else { return nil }
            let producerPlacement = placement(category: .production, instanceID: building.id)
            let distance: Int
            if let producerPlacement {
                distance = producerPlacement.occupiedPoints.map {
                    abs($0.x - plotOrigin.x) + abs($0.y - plotOrigin.y)
                }.min() ?? .max
            } else {
                // Save compatibility for older headless cities whose farm has
                // a road endpoint but no authored map placement.
                distance = abs(roadAccessPoint.x - plotOrigin.x)
                    + abs(roadAccessPoint.y - plotOrigin.y)
            }
            guard distance <= tendingRange else { return nil }
            return (building.id, roadAccessPoint, configuration, distance)
        }
        return candidates.sorted {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            // When two farms are equally close, prefer the one the player most
            // recently placed. This makes the natural "place farm, then add
            // its fields" flow deterministic even in a dense same-crop row.
            return $0.id > $1.id
        }.first.map { ($0.id, $0.roadAccessPoint, $0.configuration) }
    }

    @discardableResult
    public mutating func constructWarehouse(
        serviceRoadStart: GridPoint,
        warehouseBuildingID: Int = 54,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard isBuildingAvailableInCampaign(warehouseBuildingID),
              roadNetwork.contains(serviceRoadStart),
              rules.models.buildings[buildingID: warehouseBuildingID] != nil,
              economy.spendOnConstruction(
                buildingID: warehouseBuildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        var state = logisticsState ?? DeterministicLogisticsState()
        let id = state.addWarehouse(
            buildingID: warehouseBuildingID,
            roadAccessPoint: serviceRoadStart,
            roadNetwork: roadNetwork
        )
        logisticsState = state
        return id
    }

    @discardableResult
    public mutating func constructWarehouse(
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        warehouseBuildingID: Int = 54,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedPlacement(
            category: .warehouse,
            buildingID: warehouseBuildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard let id = updated.constructWarehouse(
            serviceRoadStart: placement.roadAccessPoint,
            warehouseBuildingID: warehouseBuildingID,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    @discardableResult
    public mutating func constructMill(
        serviceRoadStart: GridPoint,
        millBuildingID: Int = OriginalFoodCatalog.millBuildingID,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard isBuildingAvailableInCampaign(millBuildingID),
              roadNetwork.contains(serviceRoadStart),
              rules.models.buildings[buildingID: millBuildingID] != nil,
              economy.spendOnConstruction(
                buildingID: millBuildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        var state = logisticsState ?? DeterministicLogisticsState()
        let id = state.addMill(
            buildingID: millBuildingID,
            roadAccessPoint: serviceRoadStart,
            roadNetwork: roadNetwork
        )
        logisticsState = state
        return id
    }

    @discardableResult
    public mutating func constructMill(
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        millBuildingID: Int = OriginalFoodCatalog.millBuildingID,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedPlacement(
            category: .mill,
            buildingID: millBuildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard let id = updated.constructMill(
            serviceRoadStart: placement.roadAccessPoint,
            millBuildingID: millBuildingID,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    @discardableResult
    public mutating func constructMarket(
        serviceRoadStart: GridPoint,
        marketBuildingID: Int = OriginalMarketCatalog.commonMarketBuildingID,
        shopBuildingIDs: [Int],
        rules: EconomyRulesEngine
    ) -> Int? {
        guard isBuildingAvailableInCampaign(marketBuildingID),
              roadNetwork.contains(serviceRoadStart),
              let capacity = OriginalMarketCatalog.shopCapacity(forMarketBuildingID: marketBuildingID),
              shopBuildingIDs.count <= capacity,
              rules.models.buildings[buildingID: marketBuildingID] != nil,
              shopBuildingIDs.allSatisfy({ shopID in
                  OriginalMarketCatalog.supports(shopBuildingID: shopID)
                    && rules.models.buildings[buildingID: shopID] != nil
              }) else { return nil }

        // Spend against a copy so market + shops are one atomic transaction.
        var updatedEconomy = economy
        guard updatedEconomy.spendOnConstruction(
            buildingID: marketBuildingID,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        for shopID in shopBuildingIDs {
            guard updatedEconomy.spendOnConstruction(
                buildingID: shopID,
                rules: rules,
                difficulty: difficulty
            ) else { return nil }
        }

        var state = marketState ?? DeterministicMarketState()
        guard let id = state.addMarket(
            buildingID: marketBuildingID,
            roadAccessPoint: serviceRoadStart,
            shopBuildingIDs: shopBuildingIDs,
            roadNetwork: roadNetwork
        ) else { return nil }
        economy = updatedEconomy
        marketState = state
        return id
    }

    public func canConstructMarketShop(shopBuildingID: Int, at point: GridPoint) -> Bool {
        guard OriginalMarketCatalog.supports(shopBuildingID: shopBuildingID),
              let placement = placedBuildings.first(where: {
                  $0.category == .market && $0.occupiedPoints.contains(point)
              }),
              let market = markets.markets.first(where: { $0.id == placement.instanceID }) else {
            return false
        }
        return market.remainingShopCapacity > 0
    }

    /// Builds a shop into the market square occupying `point`. The shop cost
    /// and market mutation are committed atomically, matching whole-building
    /// construction and preventing a charged-but-missing shop.
    @discardableResult
    public mutating func constructMarketShop(
        shopBuildingID: Int,
        at point: GridPoint,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard canConstructMarketShop(shopBuildingID: shopBuildingID, at: point),
              rules.models.buildings[buildingID: shopBuildingID] != nil,
              let placement = placedBuildings.first(where: {
                  $0.category == .market && $0.occupiedPoints.contains(point)
              }) else {
            return nil
        }
        var updatedEconomy = economy
        guard updatedEconomy.spendOnConstruction(
            buildingID: shopBuildingID,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        var state = marketState ?? DeterministicMarketState()
        guard state.addShop(
            marketID: placement.instanceID,
            shopBuildingID: shopBuildingID
        ) else { return nil }
        economy = updatedEconomy
        marketState = state
        return placement.instanceID
    }

    @discardableResult
    public mutating func constructMarket(
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        marketBuildingID: Int = OriginalMarketCatalog.commonMarketBuildingID,
        shopBuildingIDs: [Int],
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedPlacement(
            category: .market,
            buildingID: marketBuildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard let id = updated.constructMarket(
            serviceRoadStart: placement.roadAccessPoint,
            marketBuildingID: marketBuildingID,
            shopBuildingIDs: shopBuildingIDs,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    @discardableResult
    public mutating func addTradePartner(
        _ partner: TradePartner,
        rules: EconomyRulesEngine
    ) -> Bool {
        var state = tradeState ?? DeterministicTradeState()
        guard state.addPartner(partner, tradeRules: rules.models.trade) else { return false }
        tradeState = state
        return true
    }

    @discardableResult
    public mutating func constructTradingBuilding(
        partnerID: Int,
        serviceRoadStart: GridPoint,
        assignedWorkers: Int? = nil,
        rules: EconomyRulesEngine
    ) -> Int? {
        let state = tradeState ?? DeterministicTradeState()
        guard let partner = state.partner(id: partnerID), partner.isOpen,
              isBuildingAvailableInCampaign(partner.routeKind.buildingID),
              roadNetwork.contains(serviceRoadStart),
              let model = rules.models.buildings[buildingID: partner.routeKind.buildingID],
              model.employees > 0 else { return nil }
        var updatedEconomy = economy
        guard updatedEconomy.spendOnConstruction(
            buildingID: partner.routeKind.buildingID,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        var updatedTrade = state
        guard let id = updatedTrade.addTradingBuilding(
            partnerID: partnerID,
            roadAccessPoint: serviceRoadStart,
            assignedWorkers: assignedWorkers ?? model.employees,
            models: rules.models.buildings,
            roadNetwork: roadNetwork
        ) else { return nil }
        economy = updatedEconomy
        tradeState = updatedTrade
        return id
    }

    @discardableResult
    public mutating func constructTradingBuilding(
        partnerID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        assignedWorkers: Int? = nil,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let partner = trade.partner(id: partnerID) else { return nil }
        let buildingID = partner.routeKind.buildingID
        let placement: PlacedBuilding?
        switch partner.routeKind {
        case .land:
            placement = preparedPlacement(
                category: .trading,
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            )
        case .sea:
            placement = preparedQuayPlacement(
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            )
        }
        guard let validPlacement = placement else { return nil }
        var updated = self
        guard let id = updated.constructTradingBuilding(
            partnerID: partnerID,
            serviceRoadStart: validPlacement.roadAccessPoint,
            assignedWorkers: assignedWorkers,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(validPlacement, instanceID: id)
        self = updated
        return id
    }

    public mutating func setTradeImporting(
        _ enabled: Bool,
        commodityID: Int,
        tradingBuildingID: Int
    ) {
        var state = tradeState ?? DeterministicTradeState()
        state.setImporting(enabled, commodityID: commodityID, tradingBuildingID: tradingBuildingID)
        tradeState = state
    }

    public mutating func setTradeExporting(
        _ enabled: Bool,
        commodityID: Int,
        tradingBuildingID: Int
    ) {
        var state = tradeState ?? DeterministicTradeState()
        state.setExporting(enabled, commodityID: commodityID, tradingBuildingID: tradingBuildingID)
        tradeState = state
    }

    public mutating func setProductionWorkers(
        _ count: Int,
        buildingInstanceID: Int,
        models: BuildingModelTable
    ) {
        production.setAssignedWorkers(count, buildingInstanceID: buildingInstanceID, models: models)
    }

    @discardableResult
    public mutating func setProductionEnabled(
        _ enabled: Bool,
        buildingInstanceID: Int
    ) -> Bool {
        guard production.buildings.contains(where: { $0.id == buildingInstanceID }) else {
            return false
        }
        production.setEnabled(enabled, buildingInstanceID: buildingInstanceID)
        return true
    }

    @discardableResult
    public mutating func setWarehousePolicy(
        _ policy: WarehouseCommodityPolicy,
        warehouseID: Int,
        commodityIDs: [Int]
    ) -> Bool {
        var logistics = logisticsState ?? DeterministicLogisticsState()
        guard logistics.warehouses.contains(where: { $0.id == warehouseID }) else {
            return false
        }
        for commodityID in commodityIDs {
            logistics.setPolicy(policy, commodityID: commodityID, warehouseID: warehouseID)
        }
        logisticsState = logistics
        return true
    }

    @discardableResult
    public mutating func setTradeEnabled(
        _ enabled: Bool,
        tradingBuildingID: Int
    ) -> Bool {
        var trade = tradeState ?? DeterministicTradeState()
        guard let building = trade.building(id: tradingBuildingID),
              let partner = trade.partner(id: building.partnerID) else { return false }
        for commodityID in partner.supplyByCommodityID.keys {
            trade.setImporting(
                enabled,
                commodityID: commodityID,
                tradingBuildingID: tradingBuildingID
            )
        }
        for commodityID in partner.demandByCommodityID.keys {
            trade.setExporting(
                enabled,
                commodityID: commodityID,
                tradingBuildingID: tradingBuildingID
            )
        }
        tradeState = trade
        return true
    }

    @discardableResult
    public mutating func constructTaxOffice(
        serviceRoadStart: GridPoint,
        replaySeed: UInt64,
        taxOfficeBuildingID: Int = 125,
        taxOfficialFigureID: Int = 27,
        rules: EconomyRulesEngine
    ) -> Int? {
        constructServiceBuilding(
            buildingID: taxOfficeBuildingID,
            figureID: taxOfficialFigureID,
            service: .tax,
            serviceRoadStart: serviceRoadStart,
            replaySeed: replaySeed,
            rules: rules
        )
    }

    @discardableResult
    public mutating func constructTaxOffice(
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        replaySeed: UInt64,
        taxOfficeBuildingID: Int = 125,
        taxOfficialFigureID: Int = 27,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedPlacement(
            category: .residentialService,
            buildingID: taxOfficeBuildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard let id = updated.constructTaxOffice(
            serviceRoadStart: placement.roadAccessPoint,
            replaySeed: replaySeed,
            taxOfficeBuildingID: taxOfficeBuildingID,
            taxOfficialFigureID: taxOfficialFigureID,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    @discardableResult
    public mutating func constructResidentialServiceBuilding(
        buildingID: Int,
        serviceRoadStart: GridPoint,
        replaySeed: UInt64,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let configuration = OriginalResidentialServiceCatalog.configuration(
            buildingID: buildingID
        ), configuration.service != .tax else { return nil }
        return constructServiceBuilding(
            buildingID: configuration.buildingID,
            figureID: configuration.figureID,
            service: configuration.service,
            serviceRoadStart: serviceRoadStart,
            replaySeed: replaySeed,
            rules: rules
        )
    }

    @discardableResult
    public mutating func constructResidentialServiceBuilding(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        replaySeed: UInt64,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedPlacement(
            category: .residentialService,
            buildingID: buildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard let id = updated.constructResidentialServiceBuilding(
            buildingID: buildingID,
            serviceRoadStart: placement.roadAccessPoint,
            replaySeed: replaySeed,
            rules: rules
        ) else { return nil }
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    @discardableResult
    public mutating func constructMilitaryFort(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let configuration = OriginalMilitaryFortConfiguration.configuration(
            buildingID: buildingID
        ), let placement = preparedPlacement(
            category: .military,
            buildingID: buildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard updated.isBuildingAvailableInCampaign(buildingID),
              updated.economy.spendOnConstruction(
                buildingID: buildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        var state = updated.militaryState ?? DeterministicMilitaryState()
        guard let fortID = state.addFort(
            configuration: configuration,
            roadAccessPoint: placement.roadAccessPoint,
            models: rules.models.figures
        ) else { return nil }
        updated.militaryState = state
        updated.recordPlacement(placement, instanceID: fortID)
        self = updated
        return fortID
    }

    /// Builds a wall tile or replaces the required authored wall span with a
    /// 5x3 gatehouse / 2x2 tower. Walls may cross roads so a perpendicular
    /// gate road can subsequently pass through the wall line.
    @discardableResult
    public mutating func constructMilitaryDefense(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let configuration = OriginalMilitaryDefenseConfiguration.configuration(
            buildingID: buildingID
        ), let footprint = OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: buildingID,
            orientation: orientation
        ), canConstructMilitaryDefense(
            buildingID: buildingID,
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard updated.economy.spendOnConstruction(
            buildingID: buildingID,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        var state = updated.militaryState ?? DeterministicMilitaryState()
        var placements = updated.buildingPlacementState ?? []
        let points = footprint.points(at: origin)
        let replacedDefenseIDs = Set(placements.compactMap { placement -> Int? in
            guard placement.category == .military,
                  OriginalMilitaryDefenseConfiguration.configuration(
                    buildingID: placement.buildingID
                  ) != nil,
                  !Set(placement.occupiedPoints).isDisjoint(with: points)
            else { return nil }
            return placement.instanceID
        })
        for defenseID in replacedDefenseIDs {
            _ = state.removeDefense(id: defenseID)
        }
        placements.removeAll { replacedDefenseIDs.contains($0.instanceID) }
        guard let defenseID = state.addDefense(
            configuration: configuration,
            point: origin,
            models: rules.models.figures
        ) else { return nil }
        let center = GridPoint(
            x: origin.x + footprint.width / 2,
            y: origin.y + footprint.height / 2
        )
        let access = roadNetwork.contains(center)
            ? center
            : adjacentRoadPoints(to: points).first ?? center
        placements.append(PlacedBuilding(
            category: .military,
            instanceID: defenseID,
            buildingID: buildingID,
            origin: origin,
            orientation: orientation,
            footprint: footprint,
            roadAccessPoint: access
        ))
        updated.militaryState = state
        updated.buildingPlacementState = placements
        self = updated
        return defenseID
    }

    @discardableResult
    public mutating func constructAestheticBuilding(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let kind = Self.aestheticConstructionKind(buildingID: buildingID) else {
            return nil
        }
        let placement: PlacedBuilding?
        if buildingID == 110 || buildingID == 209 {
            placement = preparedGovernmentPlacement(
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            )
        } else if kind == .scenery {
            placement = preparedAestheticPlacement(
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            )
        } else {
            placement = preparedPlacement(
                category: .aesthetic,
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            )
        }
        guard let placement else { return nil }
        var updated = self
        guard updated.isBuildingAvailableInCampaign(buildingID),
              updated.economy.spendOnConstruction(
                buildingID: buildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        var state = updated.aestheticState ?? DeterministicAestheticState()
        let id = state.addConstruction(
            buildingID: buildingID,
            kind: kind,
            location: placement.markerPoint,
            origin: placement.origin,
            orientation: placement.orientation
        )
        updated.aestheticState = state
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    public func canConstructIrrigationPump(
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> Bool {
        preparedIrrigationPumpPlacement(
            at: origin,
            orientation: orientation
        ) != nil
    }

    /// Places the original one-tile water lift on clear bank land. The
    /// selected bank edge determines which of its four authored sprites is
    /// rendered; a road on another adjacent edge supplies its workforce.
    @discardableResult
    public mutating func constructIrrigationPump(
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let placement = preparedIrrigationPumpPlacement(
            at: origin,
            orientation: orientation
        ) else { return nil }
        var updated = self
        guard updated.economy.spendOnConstruction(
            buildingID: 203,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        var state = updated.aestheticState ?? DeterministicAestheticState()
        let id = state.addConstruction(
            buildingID: 203,
            kind: .irrigationPump,
            location: placement.markerPoint
        )
        updated.aestheticState = state
        updated.recordPlacement(placement, instanceID: id)
        self = updated
        return id
    }

    /// Starts a project whose geometry is authored directly into the mission
    /// map rather than represented by a normal rectangular placement.
    @discardableResult
    public mutating func beginMapMonument(buildingID: Int) -> Int? {
        guard buildingID == 83 || buildingID == 85,
              isBuildingAvailableInCampaign(buildingID) else { return nil }
        var state = aestheticState ?? DeterministicAestheticState()
        guard let id = state.addMapMonument(buildingID: buildingID) else { return nil }
        aestheticState = state
        return id
    }

    public func canAdvanceGrandCanalSegment(at point: GridPoint) -> Bool {
        guard let canal = aesthetics.grandCanalProject,
              let segmentIndex = canal.segmentIndex(containing: point),
              let project = aesthetics.monuments.first(where: { $0.id == canal.projectID }) else {
            return false
        }
        var preview = canal
        return preview.advanceSegment(index: segmentIndex, project: project)
    }

    @discardableResult
    public mutating func advanceGrandCanalSegment(at point: GridPoint) -> Int? {
        var state = aestheticState ?? DeterministicAestheticState()
        guard let segment = state.advanceGrandCanalSegment(at: point) else { return nil }
        aestheticState = state
        return segment
    }

    public func canAdvanceEarthenGreatWallSegment(index: Int) -> Bool {
        guard let wall = aesthetics.earthenGreatWallProject,
              let project = aesthetics.monuments.first(where: { $0.id == wall.projectID }) else {
            return false
        }
        var preview = wall
        return preview.advanceSegment(index: index, project: project)
    }

    public func canAdvanceEarthenGreatWallSegment(at point: GridPoint) -> Bool {
        guard let index = aesthetics.earthenGreatWallProject?.segmentIndex(containing: point) else {
            return false
        }
        return canAdvanceEarthenGreatWallSegment(index: index)
    }

    @discardableResult
    public mutating func advanceEarthenGreatWallSegment(index: Int) -> Int? {
        var state = aestheticState ?? DeterministicAestheticState()
        guard let segment = state.advanceEarthenGreatWallSegment(index: index) else {
            return nil
        }
        aestheticState = state
        return segment
    }

    @discardableResult
    public mutating func advanceEarthenGreatWallSegment(at point: GridPoint) -> Int? {
        guard let index = aesthetics.earthenGreatWallProject?.segmentIndex(containing: point) else {
            return nil
        }
        return advanceEarthenGreatWallSegment(index: index)
    }

    public func canAdvanceLargePalacePhase(at point: GridPoint) -> Bool {
        guard let palace = aesthetics.largePalaceProject,
              palace.contains(point),
              let project = aesthetics.monuments.first(where: { $0.id == palace.projectID }) else {
            return false
        }
        var preview = palace
        return preview.advance(project: project)
    }

    @discardableResult
    public mutating func advanceLargePalacePhase(at point: GridPoint) -> Int? {
        var state = aestheticState ?? DeterministicAestheticState()
        guard let phase = state.advanceLargePalacePhase(at: point) else { return nil }
        aestheticState = state
        return phase
    }

    public func canAdvancePhasedMonument(at point: GridPoint) -> Bool {
        guard let runtime = aesthetics.phasedMonumentProjects.first(where: {
            !$0.isComplete && $0.contains(point)
        }),
        let project = aesthetics.monuments.first(where: {
            $0.id == runtime.projectID
        }) else { return false }
        var preview = runtime
        return preview.advance(project: project)
    }

    @discardableResult
    public mutating func advancePhasedMonument(at point: GridPoint) -> Int? {
        var state = aestheticState ?? DeterministicAestheticState()
        guard let phase = state.advancePhasedMonument(at: point) else {
            return nil
        }
        aestheticState = state
        return phase
    }

    public func canConstructAestheticBuilding(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> Bool {
        guard let kind = Self.aestheticConstructionKind(buildingID: buildingID) else {
            return false
        }
        if buildingID == 110 || buildingID == 209 {
            return preparedGovernmentPlacement(
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            ) != nil
        }
        if kind == .scenery {
            return preparedAestheticPlacement(
                buildingID: buildingID,
                at: origin,
                orientation: orientation
            ) != nil
        }
        return canConstructBuilding(
            buildingID: buildingID,
            at: origin,
            orientation: orientation
        )
    }

    private func preparedAestheticPlacement(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation
    ) -> PlacedBuilding? {
        guard isBuildingAvailableInCampaign(buildingID),
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: orientation
              ) else { return nil }
        let points = footprint.points(at: origin)
        let occupiedPoints = occupiedBuildingPoints
        guard points.allSatisfy(roadNetwork.isInside),
              points.allSatisfy({ !occupiedPoints.contains($0) }),
              points.allSatisfy({ terrainState?.isClearLand($0) ?? true }) else { return nil }
        return PlacedBuilding(
            category: .aesthetic,
            instanceID: 0,
            buildingID: buildingID,
            origin: origin,
            orientation: orientation,
            footprint: footprint,
            roadAccessPoint: adjacentRoadPoints(to: points).first ?? origin
        )
    }

    private func preparedIrrigationPumpPlacement(
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation
    ) -> PlacedBuilding? {
        guard isBuildingAvailableInCampaign(203),
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: 203,
                orientation: orientation
              ),
              let terrainState else { return nil }
        let points = footprint.points(at: origin)
        guard points.allSatisfy(roadNetwork.isInside),
              points.allSatisfy({ !roadNetwork.contains($0) }),
              points.allSatisfy({ !occupiedBuildingPoints.contains($0) }),
              terrainState.quayWaterEdge(
                footprintPoints: points,
                footprintWidth: footprint.width,
                footprintHeight: footprint.height,
                origin: origin
              ) != nil,
              let roadAccessPoint = adjacentRoadPoints(to: points).first
        else { return nil }
        return PlacedBuilding(
            category: .aesthetic,
            instanceID: 0,
            buildingID: 203,
            origin: origin,
            orientation: orientation,
            footprint: footprint,
            roadAccessPoint: roadAccessPoint
        )
    }

    private func preparedGovernmentPlacement(
        buildingID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation
    ) -> PlacedBuilding? {
        guard isBuildingAvailableInCampaign(buildingID),
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: orientation
              ) else { return nil }
        let points = footprint.points(at: origin)
        let occupiedPoints = occupiedBuildingPoints
        guard points.allSatisfy(roadNetwork.isInside),
              points.allSatisfy({ !roadNetwork.contains($0) }),
              points.allSatisfy({ !occupiedPoints.contains($0) }),
              points.allSatisfy({ terrainState?.isClearLand($0) ?? true }),
              let roadAccess = adjacentRoadPoints(to: points).first else { return nil }
        // The original palace needs at least one tile over the water table.
        if buildingID == 110, let terrainState,
           !points.contains(where: {
               terrainState.terrain(at: $0)?.contains(.groundwater) == true
           }) {
            return nil
        }
        return PlacedBuilding(
            category: .aesthetic,
            instanceID: 0,
            buildingID: buildingID,
            origin: origin,
            orientation: orientation,
            footprint: footprint,
            roadAccessPoint: roadAccess
        )
    }

    private static func aestheticConstructionKind(
        buildingID: Int
    ) -> AestheticConstructionKind? {
        if OriginalMonumentConfiguration.configuration(buildingID: buildingID) != nil {
            return .monument
        }
        switch buildingID {
        case 110, 115...122, 209, 243...252: return .scenery
        case 233: return .laborersCamp
        case 52: return .carpentersGuild
        case 235: return .masonsGuild
        case 236: return .ceramistsGuild
        default: return nil
        }
    }

    @discardableResult
    public mutating func advanceMilitary(
        maximumStepsPerUnit: Int? = nil,
        models: FigureModelTable
    ) -> MilitaryMovementSettlement {
        guard var state = militaryState,
              var events = campaignEventState,
              !state.units.isEmpty
                || !state.defensiveStructures.isEmpty
                || events.invasions.contains(where: { $0.status == .awaitingDefense })
        else { return .empty }
        let movement = state.advance(
            maximumStepsPerUnit: maximumStepsPerUnit,
            terrain: terrainState,
            blockedPoints: militaryBlockedPoints,
            campaignEvents: &events,
            models: models
        )
        militaryState = state
        campaignEventState = events
        return movement
    }

    public func canIssueMilitaryOrder(to destination: GridPoint) -> Bool {
        roadNetwork.isInside(destination)
            && (terrainState?.isClearLand(destination) ?? true)
            && !militaryBlockedPoints.contains(destination)
            && military.units.contains { $0.hitPoints > 0 }
    }

    /// Issues a deterministic rally order to any subset of live formations.
    /// Passing an empty set orders every surviving formation.
    @discardableResult
    public mutating func issueMilitaryOrder(
        unitIDs: Set<Int> = [],
        to destination: GridPoint,
        models: FigureModelTable
    ) -> Int {
        guard canIssueMilitaryOrder(to: destination) else { return 0 }
        var state = militaryState ?? DeterministicMilitaryState()
        let selected = unitIDs.isEmpty
            ? Set(state.units.filter { $0.hitPoints > 0 }.map(\.id))
            : unitIDs
        var routes: [Int: [GridPoint]] = [:]
        var blocked = militaryBlockedPoints
        blocked.remove(destination)
        for unit in state.units where selected.contains(unit.id) && unit.hitPoints > 0 {
            let route = terrainState?.shortestLandVisitorPath(
                from: unit.currentPoint,
                to: destination,
                blocked: blocked
            ) ?? GridPathfinder.shortestPath(
                width: roadNetwork.width,
                height: roadNetwork.height,
                from: unit.currentPoint,
                to: destination,
                isPassable: { !blocked.contains($0) }
            )
            if let route { routes[unit.id] = route }
        }
        let count = state.issueOrder(unitIDs: selected, routesByUnitID: routes)
        militaryState = state
        return count
    }

    @discardableResult
    public mutating func advanceMonuments() -> MonumentMonthlySettlement {
        guard var aesthetics = aestheticState, !aesthetics.monuments.isEmpty else {
            return .empty
        }
        var logistics = logisticsState ?? DeterministicLogisticsState()
        let settlement = aesthetics.advanceMonuments(
            logistics: &logistics,
            production: &production
        )
        aestheticState = aesthetics
        logisticsState = logistics
        return settlement
    }

    private mutating func constructServiceBuilding(
        buildingID: Int,
        figureID: Int,
        service: WalkerServiceKind,
        serviceRoadStart: GridPoint,
        replaySeed: UInt64,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard isBuildingAvailableInCampaign(buildingID),
              roadNetwork.contains(serviceRoadStart),
              rules.models.buildings[buildingID: buildingID] != nil,
              let figure = rules.models.figures[figureID: figureID],
              figure.behaviorRange > 0,
              economy.spendOnConstruction(
                buildingID: buildingID,
                rules: rules,
                difficulty: difficulty
              ) else { return nil }
        var state = walkerState ?? DeterministicWalkerState()
        guard let walkerID = state.addWalker(
            figureID: figureID,
            service: service,
            origin: serviceRoadStart,
            maximumRoadSteps: figure.behaviorRange,
            replaySeed: replaySeed,
            roadNetwork: roadNetwork
        ) else { return nil }
        var buildings = residentialServiceBuildingState ?? []
        // Ruins deliberately keep their placement after the operational
        // service building is removed. Include those retained placement IDs
        // when allocating a replacement so workforce keys never collide.
        let retainedPlacementID = (buildingPlacementState ?? [])
            .filter { $0.category == .residentialService }
            .map(\.instanceID)
            .max() ?? 0
        let id = max(buildings.map(\.id).max() ?? 0, retainedPlacementID) + 1
        buildings.append(ResidentialServiceBuilding(
            id: id,
            buildingID: buildingID,
            service: service,
            figureID: figureID,
            roadAccessPoint: serviceRoadStart,
            walkerID: walkerID
        ))
        residentialServiceBuildingState = buildings
        walkerState = state
        return id
    }

    @discardableResult
    public mutating func advanceServiceWalkers(roadStepsPerWalker: Int) -> WalkerMovementSummary {
        guard var state = walkerState, !state.walkers.isEmpty else { return .empty }
        let movement = state.advance(
            roadStepsPerWalker: roadStepsPerWalker,
            houses: houses,
            roadNetwork: roadNetwork
        )
        applyServiceCoverage(movement, resetExisting: false)
        walkerState = state
        return movement
    }

    @discardableResult
    public mutating func advanceDeliveryWalkers(roadStepsPerWalker: Int) -> DeliveryMovementSummary {
        guard var state = logisticsState, !state.deliveryWalkers.isEmpty else { return .empty }
        var trade = tradeState ?? DeterministicTradeState()
        let movement = state.advanceDeliveries(
            roadStepsPerWalker: roadStepsPerWalker,
            production: &production,
            trade: &trade
        )
        logisticsState = state
        tradeState = trade
        return movement
    }

    @discardableResult
    public mutating func advanceTradeVisitors(stepsPerVisitor: Int) -> Int {
        guard var state = tradeState, !state.visitors.isEmpty else { return 0 }
        let movement = state.advanceVisitors(stepsPerVisitor: stepsPerVisitor)
        tradeState = state
        return movement
    }

    @discardableResult
    public mutating func buildRoad(
        _ points: [GridPoint],
        constructionBuildingID: Int = 22,
        rules: EconomyRulesEngine
    ) -> Int? {
        guard let newPoints = roadNetwork.newPoints(in: points) else { return nil }
        guard !newPoints.isEmpty else { return 0 }
        guard newPoints.allSatisfy(canConstructRoad(at:)) else { return nil }
        guard economy.spendOnConstruction(
            buildingID: constructionBuildingID,
            quantity: newPoints.count,
            rules: rules,
            difficulty: difficulty
        ) else { return nil }
        return roadNetwork.insert(newPoints)
    }

    /// Whether the tile at `point` holds anything the demolish tool can remove:
    /// a placed building footprint, a house, or a road tile.
    public func canDemolish(at point: GridPoint) -> Bool {
        placedBuildings.contains { $0.occupiedPoints.contains(point) }
            || houses.contains {
                guard let location = $0.location else { return false }
                let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
                    ?? BuildingFootprint(width: 2, height: 2)
                return footprint.points(at: location).contains(point)
            }
            || roadNetwork.contains(point)
    }

    /// Demolishes whatever sits on `point`, prioritising placed buildings, then
    /// houses, then a single road tile. Refunds half of the original construction
    /// cost back to the treasury, mirroring the original bulldoze behaviour.
    @discardableResult
    public mutating func demolish(at point: GridPoint, rules: EconomyRulesEngine) -> DemolishOutcome {
        if let outcome = demolishBuilding(at: point, rules: rules) {
            return outcome
        }
        if let outcome = demolishHouse(at: point, rules: rules) {
            return outcome
        }
        if let outcome = demolishRoad(at: point, rules: rules) {
            return outcome
        }
        return .nothing
    }

    /// Removes the placed building whose footprint covers `point` and refunds
    /// 50% of its construction cost. Returns `nil` when no building is hit so
    /// callers can fall through to houses and roads.
    @discardableResult
    public mutating func demolishBuilding(
        at point: GridPoint,
        rules: EconomyRulesEngine
    ) -> DemolishOutcome? {
        guard var placements = buildingPlacementState,
              let placement = placements.first(where: { $0.occupiedPoints.contains(point) })
        else { return nil }
        let refund = buildingDemolitionRefund(placement: placement, rules: rules)

        // Apply every linked-state mutation to a copy. A placed building is
        // therefore never removed visually while its producer, warehouse,
        // market, trade, service, or walker state survives invisibly.
        var updated = self
        updated.removeSimulationInstance(for: placement)
        let removesLinkedFields = placement.category == .production
            && updated.production.building(instanceID: placement.instanceID) == nil
            && production.building(instanceID: placement.instanceID)?.agriculture != nil
        placements.removeAll {
            $0.id == placement.id
                || (removesLinkedFields
                    && $0.category == .agriculturalPlot
                    && $0.instanceID == placement.instanceID)
        }
        updated.buildingPlacementState = placements
        updated.economy.credit(refund)
        self = updated
        return .building(buildingID: placement.buildingID, refund: refund)
    }

    private mutating func removeSimulationInstance(for placement: PlacedBuilding) {
        var logistics = logisticsState ?? DeterministicLogisticsState()
        var markets = marketState ?? DeterministicMarketState()
        var trade = tradeState ?? DeterministicTradeState()

        switch placement.category {
        case .residential:
            // Residential ruins have already been removed from `houses`.
            break

        case .production:
            _ = logistics.cancelDeliveries(
                involving: .productionBuilding(placement.instanceID),
                production: &production,
                trade: &trade
            )
            _ = production.removeBuilding(instanceID: placement.instanceID)

        case .agriculturalPlot:
            if let producer = production.building(instanceID: placement.instanceID),
               let configuration = producer.agriculture {
                production.setAgriculturalFieldCount(
                    configuration.fieldCount - 1,
                    buildingInstanceID: placement.instanceID
                )
            }

        case .warehouse:
            _ = logistics.cancelDeliveries(
                involving: .warehouse(placement.instanceID),
                production: &production,
                trade: &trade
            )
            _ = markets.cancelBuyers(targetingWarehouseID: placement.instanceID)
            if let removed = logistics.removeWarehouse(id: placement.instanceID) {
                for (commodityID, amount) in removed.inventoryByCommodityID {
                    production.addInventory(commodityID: commodityID, amount: -amount)
                }
            }

        case .mill:
            _ = logistics.cancelDeliveries(
                involving: .mill(placement.instanceID),
                production: &production,
                trade: &trade
            )
            _ = markets.cancelBuyers(targetingMillID: placement.instanceID)
            if let removed = logistics.removeMill(id: placement.instanceID) {
                for (commodityID, amount) in removed.inventoryByCommodityID {
                    production.addInventory(commodityID: commodityID, amount: -amount)
                }
            }

        case .market:
            _ = markets.removeMarket(id: placement.instanceID)

        case .trading:
            _ = logistics.cancelDeliveries(
                involving: .tradingBuilding(placement.instanceID),
                production: &production,
                trade: &trade
            )
            _ = trade.removeTradingBuilding(id: placement.instanceID)

        case .residentialService:
            var buildings = residentialServiceBuildingState ?? []
            if let index = buildings.firstIndex(where: { $0.id == placement.instanceID }) {
                let removed = buildings.remove(at: index)
                var walkers = walkerState ?? DeterministicWalkerState()
                _ = walkers.removeWalker(id: removed.walkerID)
                walkerState = walkers
            }
            residentialServiceBuildingState = buildings

        case .military:
            var military = militaryState ?? DeterministicMilitaryState()
            if OriginalMilitaryDefenseConfiguration.configuration(
                buildingID: placement.buildingID
            ) != nil {
                _ = military.removeDefense(id: placement.instanceID)
            } else {
                _ = military.removeFort(id: placement.instanceID)
            }
            militaryState = military

        case .aesthetic:
            var aesthetics = aestheticState ?? DeterministicAestheticState()
            _ = aesthetics.removeConstruction(id: placement.instanceID)
            aestheticState = aesthetics
        }

        logisticsState = logistics
        marketState = markets
        tradeState = trade
    }

    /// Removes a house occupying `point` and refunds 50% of its construction
    /// cost. Returns `nil` when there is no house on the tile.
    @discardableResult
    public mutating func demolishHouse(
        at point: GridPoint,
        rules: EconomyRulesEngine
    ) -> DemolishOutcome? {
        let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        guard let index = houses.firstIndex(where: {
            $0.location.map { footprint.points(at: $0).contains(point) } ?? false
        }) else { return nil }
        let house = houses[index]
        houses.remove(at: index)
        let refund = demolitionRefund(buildingID: house.houseLevelID, quantity: 1, rules: rules)
        economy.credit(refund)
        return .house(refund: refund)
    }

    /// Bulldozes a single road tile at `point` and refunds 50% of the road
    /// construction cost. Returns `nil` when the tile is not road.
    @discardableResult
    public mutating func demolishRoad(
        at point: GridPoint,
        rules: EconomyRulesEngine,
        constructionBuildingID: Int = 22
    ) -> DemolishOutcome? {
        var updated = self
        guard updated.roadNetwork.remove(point) else { return nil }
        var logistics = updated.logisticsState ?? DeterministicLogisticsState()
        var trade = updated.tradeState ?? DeterministicTradeState()
        _ = logistics.cancelDeliveries(
            using: point,
            production: &updated.production,
            trade: &trade
        )
        var markets = updated.marketState ?? DeterministicMarketState()
        _ = markets.cancelTravelers(using: point)
        updated.logisticsState = logistics
        updated.tradeState = trade
        updated.marketState = markets
        let refund = demolitionRefund(
            buildingID: constructionBuildingID,
            quantity: 1,
            rules: rules
        )
        updated.economy.credit(refund)
        self = updated
        return .road(refund: refund)
    }

    private func buildingDemolitionRefund(
        placement: PlacedBuilding,
        rules: EconomyRulesEngine
    ) -> Int {
        var buildingIDs = [placement.buildingID]
        if placement.category == .market,
           let market = markets.markets.first(where: { $0.id == placement.instanceID }) {
            buildingIDs.append(contentsOf: market.shopBuildingIDs)
        }
        let total = buildingIDs.reduce(0) { partial, buildingID in
            partial + (rules.constructionCost(
                buildingID: buildingID,
                difficulty: difficulty
            ) ?? 0)
        }
        return total / 2
    }

    /// Half of the original construction cost for a building, used as the
    /// demolish refund. Unknown building IDs (or houses whose level has no
    /// model cost) simply refund nothing.
    private func demolitionRefund(
        buildingID: Int,
        quantity: Int,
        rules: EconomyRulesEngine
    ) -> Int {
        guard quantity > 0,
              let cost = rules.constructionCost(buildingID: buildingID, difficulty: difficulty)
        else { return 0 }
        return cost * quantity / 2
    }

    @discardableResult
    public mutating func applyTaxCoverage(
        from serviceRoadStart: GridPoint,
        maximumRoadSteps: Int
    ) -> Int {
        let coveredIDs = RoadServiceCoverage.coveredHouseIDs(
            houses: houses,
            roadNetwork: roadNetwork,
            serviceRoadStart: serviceRoadStart,
            maximumRoadSteps: maximumRoadSteps
        )
        for index in houses.indices {
            houses[index].hasTaxCoverage = coveredIDs.contains(houses[index].id)
        }
        return coveredIDs.count
    }

    private mutating func applyServiceCoverage(
        _ movement: WalkerMovementSummary,
        resetExisting: Bool
    ) {
        if resetExisting {
            for index in houses.indices {
                houses[index].hasTaxCoverage = false
                houses[index].serviceCoverage.removeAll()
            }
        }
        for index in houses.indices {
            let houseID = houses[index].id
            for (service, coveredIDs) in movement.servicedHouseIDsByService where
                coveredIDs.contains(houseID) {
                if service == .tax {
                    houses[index].hasTaxCoverage = true
                } else {
                    houses[index].serviceCoverage.insert(service)
                }
            }
        }
    }

    private mutating func updateResidentialDesirability(models: BuildingModelTable) {
        var sources: [(buildingID: Int, point: GridPoint)] = []
        sources.append(contentsOf: production.buildings.compactMap { building in
            building.roadAccessPoint.map { (building.buildingID, $0) }
        })
        sources.append(contentsOf: logistics.warehouses.map { ($0.buildingID, $0.roadAccessPoint) })
        sources.append(contentsOf: logistics.mills.map { ($0.buildingID, $0.roadAccessPoint) })
        sources.append(contentsOf: markets.markets.map { ($0.buildingID, $0.roadAccessPoint) })
        sources.append(contentsOf: trade.buildings.map { ($0.buildingID, $0.roadAccessPoint) })
        sources.append(contentsOf: residentialServiceBuildings.map { ($0.buildingID, $0.roadAccessPoint) })
        sources.append(contentsOf: military.forts.map { ($0.buildingID, $0.roadAccessPoint) })
        sources.append(contentsOf: aesthetics.constructions.map { ($0.buildingID, $0.location) })

        for index in houses.indices {
            guard let target = houses[index].location else {
                houses[index].desirability = 0
                continue
            }
            var total = sources.reduce(0) { partial, source in
                guard let model = models[buildingID: source.buildingID] else { return partial }
                return partial + DeterministicDesirability.contribution(
                    from: model,
                    source: source.point,
                    to: target
                )
            }
            for otherIndex in houses.indices where otherIndex != index {
                guard let source = houses[otherIndex].location,
                      let buildingID = OriginalBuildingSpriteCatalog.housingBuildingID(
                        forHouseLevelID: houses[otherIndex].houseLevelID
                      ),
                      let model = models[buildingID: buildingID] else { continue }
                total += DeterministicDesirability.contribution(
                    from: model,
                    source: source,
                    to: target
                )
            }
            houses[index].desirability = total
        }
    }

    private mutating func applyWorkforce(
        _ workforce: WorkforceMonthlySettlement,
        models: BuildingModelTable
    ) {
        var trade = tradeState ?? DeterministicTradeState()
        for assignment in workforce.assignments {
            switch assignment.key.category {
            case .production:
                production.setAssignedWorkers(
                    assignment.isFullyStaffed ? assignment.assignedWorkers : 0,
                    buildingInstanceID: assignment.key.instanceID,
                    models: models
                )
            case .trading:
                trade.setAssignedWorkers(
                    assignment.assignedWorkers,
                    tradingBuildingID: assignment.key.instanceID,
                    models: models
                )
            case .residential, .agriculturalPlot, .warehouse, .mill, .market,
                 .residentialService, .military, .aesthetic:
                break
            }
        }
        tradeState = trade
    }

    private func inspectionCoverage(
        placements: [PlacedBuilding],
        visitedPatrolPoints: Set<GridPoint>,
        models: BuildingModelTable
    ) -> (keys: Set<OperationalBuildingKey>, reduction: Int) {
        guard !visitedPatrolPoints.isEmpty else { return ([], 0) }
        let covered = Set(placements.compactMap { placement -> OperationalBuildingKey? in
            let touchesPatrol = visitedPatrolPoints.contains(placement.roadAccessPoint)
                || placement.occupiedPoints.contains { point in
                    RoadServiceCoverage.orthogonalNeighbors(of: point).contains(
                        where: visitedPatrolPoints.contains
                    )
                }
            return touchesPatrol
                ? OperationalBuildingKey(category: placement.category, instanceID: placement.instanceID)
                : nil
        })
        return (covered, max(0, models[buildingID: 124]?.riskReducer ?? 0))
    }

    private func activeServiceWalkerIDs(
        workforce: WorkforceMonthlySettlement?
    ) -> Set<Int>? {
        guard let workforce else { return nil }
        let staffedKeys = Set(workforce.assignments.compactMap {
            $0.key.category == .residentialService && $0.isFullyStaffed ? $0.key : nil
        })
        return Set(residentialServiceBuildings.compactMap { building in
            staffedKeys.contains(OperationalBuildingKey(
                category: .residentialService,
                instanceID: building.id
            )) ? building.walkerID : nil
        })
    }

    private func fullyStaffedInstanceIDs(
        category: PlacedBuildingCategory,
        workforce: WorkforceMonthlySettlement?
    ) -> Set<Int>? {
        guard let workforce else { return nil }
        return Set(workforce.assignments.compactMap {
            $0.key.category == category && $0.isFullyStaffed ? $0.key.instanceID : nil
        })
    }

    private func activeDeliveryWalkerIDs(
        workforce: WorkforceMonthlySettlement?
    ) -> Set<Int>? {
        guard let workforce else { return nil }
        let activeByCategory = Dictionary(grouping: workforce.assignments.filter(\.isFullyStaffed)) {
            $0.key.category
        }.mapValues { Set($0.map(\.key.instanceID)) }
        func endpointIsActive(_ endpoint: DeliveryEndpoint) -> Bool {
            switch endpoint {
            case let .productionBuilding(id):
                activeByCategory[.production]?.contains(id) == true
            case let .warehouse(id):
                activeByCategory[.warehouse]?.contains(id) == true
            case let .mill(id):
                activeByCategory[.mill]?.contains(id) == true
            case let .tradingBuilding(id):
                activeByCategory[.trading]?.contains(id) == true
            }
        }
        return Set(logistics.deliveryWalkers.compactMap {
            endpointIsActive($0.source) && endpointIsActive($0.destination) ? $0.id : nil
        })
    }

    private mutating func applyOperationsFailures(_ failures: [BuildingFailure]) {
        var placements = buildingPlacementState ?? []
        for failure in failures {
            let failedPlacement: PlacedBuilding
            if failure.key.category == .residential {
                guard let houseIndex = houses.firstIndex(where: {
                    $0.id == failure.key.instanceID
                }), let origin = houses[houseIndex].location else { continue }
                let house = houses.remove(at: houseIndex)
                let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
                    ?? BuildingFootprint(width: 2, height: 2)
                failedPlacement = PlacedBuilding(
                    category: .residential,
                    instanceID: house.id,
                    buildingID: house.houseLevelID + 3,
                    origin: origin,
                    orientation: house.orientation,
                    footprint: footprint,
                    roadAccessPoint: failure.location
                )
            } else {
                guard let index = placements.firstIndex(where: {
                    $0.category == failure.key.category
                        && $0.instanceID == failure.key.instanceID
                        && $0.buildingID != OriginalBuildingSpriteCatalog.ruinBuildingID
                }) else { continue }
                failedPlacement = placements.remove(at: index)
                removeSimulationInstance(for: failedPlacement)
            }
            // Both failures leave a blocking, manually clearable ruin. A fire
            // remains visibly overlaid for the current settlement.
            placements.append(PlacedBuilding(
                category: failedPlacement.category,
                instanceID: failedPlacement.instanceID,
                buildingID: OriginalBuildingSpriteCatalog.ruinBuildingID,
                origin: failedPlacement.origin,
                orientation: failedPlacement.orientation,
                footprint: failedPlacement.footprint,
                roadAccessPoint: failedPlacement.roadAccessPoint
            ))
        }
        buildingPlacementState = placements
    }

    /// Converts a concrete external hit into the same persistent ruin state as
    /// routine maintenance failures while retaining its authored cause.
    mutating func applyExternalBuildingFailures(_ failures: [BuildingFailure]) {
        guard !failures.isEmpty else { return }
        var operations = operationsState ?? DeterministicCityOperationsState()
        operations.recordExternalFailures(calendar: calendar, failures: failures)
        operationsState = operations
        applyOperationsFailures(failures)
    }

    /// Advances one deterministic game day. Movement and migration happen on
    /// every tick; economic, housing and risk systems settle only on day 30.
    @discardableResult
    public mutating func advanceTick(rules: EconomyRulesEngine) -> CityTickResult {
        var clock = simulationClockState ?? SimulationClockState()
        var accumulatedCoverage = monthlyServiceCoverageState
            ?? MonthlyServiceCoverageAccumulator()

        if clock.day == 1, accumulatedCoverage.isEmpty {
            for index in houses.indices {
                houses[index].serviceCoverage.removeAll()
            }
            if walkers.walkers.contains(where: { $0.service == .tax }) {
                for index in houses.indices { houses[index].hasTaxCoverage = false }
            }
        }

        let workforceBeforeMigration: WorkforceMonthlySettlement?
        if workforceEnabled {
            workforceBeforeMigration = workforceSnapshot(models: rules.models.buildings)
        } else {
            workforceBeforeMigration = nil
        }
        let assessment = DeterministicMigration.assess(
            houses: houses,
            population: population,
            treasury: economy.treasury,
            roadNetwork: roadNetwork,
            workforce: workforceBeforeMigration,
            models: rules.models.buildings
        )
        let migrated = admitResidents(
            assessment.plannedImmigrants,
            eligibleHouseIDs: Set(assessment.eligibleHouseIDs),
            models: rules.models.buildings
        )
        var migration = migrationState ?? DeterministicMigrationState()
        migration.recordDay(assessment: assessment, admitted: migrated)
        migrationState = migration

        let activeWorkforce: WorkforceMonthlySettlement?
        if workforceEnabled {
            let workforce = workforceSnapshot(models: rules.models.buildings)
            applyWorkforce(workforce, models: rules.models.buildings)
            activeWorkforce = workforce
        } else {
            activeWorkforce = nil
        }

        var walkerMovement = WalkerMovementSummary.empty
        if var state = walkerState, !state.walkers.isEmpty {
            walkerMovement = state.advance(
                roadStepsPerWalker: 1,
                houses: houses,
                roadNetwork: roadNetwork,
                activeWalkerIDs: activeServiceWalkerIDs(workforce: activeWorkforce)
            )
            accumulatedCoverage.merge(walkerMovement)
            applyServiceCoverage(walkerMovement, resetExisting: false)
            walkerState = state
        }

        var logisticsMovement = DeliveryMovementSummary.empty
        if var logistics = logisticsState {
            var trade = tradeState ?? DeterministicTradeState()
            let deliveryRange = max(1, rules.models.figures[figureID: 22]?.behaviorRange ?? 24)
            _ = logistics.scheduleDeliveries(
                production: &production,
                roadNetwork: roadNetwork,
                deliveryFigureID: 22,
                maximumOneWayRoadSteps: deliveryRange,
                activeProductionBuildingIDs: fullyStaffedInstanceIDs(
                    category: .production,
                    workforce: activeWorkforce
                ),
                activeMillIDs: fullyStaffedInstanceIDs(
                    category: .mill,
                    workforce: activeWorkforce
                )
            )
            logisticsMovement = logistics.advanceDeliveries(
                roadStepsPerWalker: 1,
                production: &production,
                trade: &trade,
                activeDeliveryWalkerIDs: activeDeliveryWalkerIDs(
                    workforce: activeWorkforce
                )
            )
            logisticsState = logistics
            tradeState = trade
        }

        if var trade = tradeState {
            _ = trade.advanceVisitors(stepsPerVisitor: 1)
            tradeState = trade
        }

        var marketMovement = MarketTickMovementSummary.empty
        if var market = marketState {
            var logistics = logisticsState ?? DeterministicLogisticsState()
            let activeMarketIDs = fullyStaffedInstanceIDs(
                category: .market,
                workforce: activeWorkforce
            )
            let buyerRange = max(
                1,
                rules.models.figures[figureID: OriginalMarketCatalog.buyerFigureID]?.behaviorRange ?? 50
            )
            let peddlerRange = max(
                1,
                rules.models.figures[figureID: OriginalMarketCatalog.peddlerFigureID]?.behaviorRange ?? 60
            )
            market.scheduleBuyers(
                houses: houses,
                logistics: &logistics,
                production: &production,
                roadNetwork: roadNetwork,
                models: rules.models.buildings,
                maximumOneWayRoadSteps: buyerRange,
                activeMarketIDs: activeMarketIDs,
                activeMillIDs: fullyStaffedInstanceIDs(
                    category: .mill,
                    workforce: activeWorkforce
                )
            )
            let purchased = market.advanceBuyers(
                roadStepsPerBuyer: 10,
                activeMarketIDs: activeMarketIDs
            )
            market.schedulePeddlers(
                houses: houses,
                roadNetwork: roadNetwork,
                models: rules.models.buildings,
                maximumRoadSteps: peddlerRange,
                replaySeed: 0x4D41_524B_4554
                    ^ UInt64(bitPattern: Int64(calendar.year * 12 + calendar.month)),
                activeMarketIDs: activeMarketIDs
            )
            let delivered = market.advancePeddlers(
                // A market walker patrols a substantial portion of its
                // authored 60-tile service range during one game month.
                // Ten road tiles per daily simulation tick preserves that
                // cadence on the native day-based clock.
                roadStepsPerPeddler: 10,
                houses: &houses,
                models: rules.models.buildings,
                activeMarketIDs: activeMarketIDs
            )
            marketMovement = MarketTickMovementSummary(
                purchasedLoads: purchased,
                householdDeliveries: delivered
            )
            marketState = market
            logisticsState = logistics
        }

        let clockAdvance = clock.advanceOneDay()
        simulationClockState = clock
        monthlyServiceCoverageState = accumulatedCoverage
        let settlement = clockAdvance.didEndMonth ? settleMonth(rules: rules) : nil
        return CityTickResult(
            tickSequence: clockAdvance.tickSequence,
            day: clockAdvance.currentDay,
            movement: CityMovementSummary(
                walkers: walkerMovement,
                logistics: logisticsMovement,
                market: marketMovement
            ),
            migratedResidents: migrated,
            migrationAssessment: assessment,
            monthlySettlement: settlement
        )
    }

    private mutating func settleMonth(rules: EconomyRulesEngine) -> MonthlySettlement {
        let settlementYear = calendar.year
        let settlementMonth = calendar.month
        let settlementPopulation = population
        let startingTreasury = economy.treasury
        let taxRate = rules.taxRatePercent(bandID: taxBandID) ?? 0
        var taxedPopulation = 0
        var untaxedPopulation = 0
        var coveredTaxUnits = 0
        var uncoveredTaxUnits = 0
        let operationsWorkforce: WorkforceMonthlySettlement?
        if workforceEnabled {
            let workforce = workforceSnapshot(models: rules.models.buildings)
            applyWorkforce(workforce, models: rules.models.buildings)
            operationsWorkforce = workforce
        } else {
            operationsWorkforce = nil
        }

        updateResidentialDesirability(models: rules.models.buildings)

        for house in houses {
            let multiplier = rules.models.buildings[houseLevelID: house.houseLevelID]?.taxRateMultiplier ?? 0
            let units = house.residents * multiplier
            if house.hasTaxCoverage {
                taxedPopulation += house.residents
                coveredTaxUnits += units
            } else {
                untaxedPopulation += house.residents
                uncoveredTaxUnits += units
            }
        }

        // The original engine family converts house tax units to monthly currency
        // by halving first and then applying the selected percentage. Keeping the
        // integer truncation order makes replays bit-for-bit deterministic.
        let collected = (coveredTaxUnits / 2) * taxRate / 100
        let uncollected = (uncoveredTaxUnits / 2) * taxRate / 100
        economy.credit(collected)
        let hasMeaningfulCoverage = population > 0 && taxedPopulation * 10 >= population
        let sentiment = rules.taxSentiment(
            bandID: taxBandID,
            difficulty: difficulty,
            hasMeaningfulCoverage: hasMeaningfulCoverage
        ) ?? 0
        let agriculturalSettlement = production.advanceAgriculture(
            calendar: calendar,
            models: rules.models.buildings,
            farm: rules.models.farm,
            yieldModifierPercent: campaignEvents.conditions.agriculturalYieldPercent
        )
        let industrialSettlement = production.advanceMonth(models: rules.models.buildings)
        if var state = logisticsState {
            var trade = tradeState ?? DeterministicTradeState()
            let deliveryRange = max(1, rules.models.figures[figureID: 22]?.behaviorRange ?? 24)
            _ = state.scheduleTradeDeliveries(
                production: &production,
                trade: &trade,
                roadNetwork: roadNetwork,
                deliveryFigureID: 22,
                maximumOneWayRoadSteps: deliveryRange
            )
            logisticsState = state
            tradeState = trade
        }
        var trade = tradeState ?? DeterministicTradeState()
        let visitorRoutes = terrainState == nil ? nil : tradeVisitorRoutes()
        trade.advanceMonth(
            calendar: calendar,
            economy: &economy,
            models: rules.models,
            visitorRoutesByBuildingID: visitorRoutes
        )
        tradeState = trade
        // Newly imported goods only exist after the trade settlement. Stage
        // their physical delivery now so they can start moving on day one of
        // the next month rather than waiting an additional month to be noticed.
        if var logistics = logisticsState {
            let deliveryRange = max(1, rules.models.figures[figureID: 22]?.behaviorRange ?? 24)
            _ = logistics.scheduleTradeDeliveries(
                production: &production,
                trade: &trade,
                roadNetwork: roadNetwork,
                deliveryFigureID: 22,
                maximumOneWayRoadSteps: deliveryRange
            )
            logisticsState = logistics
            tradeState = trade
        }
        if var market = marketState {
            _ = market.settleMonth(
                houses: &houses,
                models: rules.models.buildings
            )
            marketState = market
        }
        if publicSafetyEnabled {
            var healthSafety = publicHealthSafetyState ?? DeterministicPublicHealthSafetyState()
            let healthSafetySettlement = healthSafety.advanceMonth(
                calendar: calendar,
                houses: &houses,
                models: rules.models.buildings
            )
            _ = economy.debit(min(economy.treasury, healthSafetySettlement.stolenCash))
            publicHealthSafetyState = healthSafety
        }
        if housingEvolutionEnabled {
            lastHousingSettlementState = DeterministicHousingEvolution.settle(
                houses: &houses,
                models: rules.models.buildings,
                difficulty: difficulty
            )
        } else {
            lastHousingSettlementState = nil
        }
        var producedUnits: [Int: Int] = [:]
        for operation in industrialSettlement.operations {
            producedUnits[operation.outputCommodityID, default: 0] += operation.outputAmount
        }
        for harvest in agriculturalSettlement.harvests {
            producedUnits[harvest.outputCommodityID, default: 0] += harvest.outputAmount
        }
        var accounting = productionAccountingState ?? DeterministicProductionAccounting()
        accounting.recordMonth(
            year: settlementYear,
            month: settlementMonth,
            producedUnitsByCommodityID: producedUnits,
            lifetimeIncome: economy.lifetimeIncome,
            lifetimeExpenses: economy.lifetimeExpenses
        )
        productionAccountingState = accounting
        if let operationsWorkforce {
            let riskPlacements = buildingFailureCandidatePlacements
            let coverage = inspectionCoverage(
                placements: riskPlacements,
                visitedPatrolPoints: monthlyServiceCoverageState?
                    .visitedRoadPointsByService[.inspection] ?? [],
                models: rules.models.buildings
            )
            var operations = operationsState ?? DeterministicCityOperationsState()
            let operationsSettlement = operations.advanceMonth(
                calendar: calendar,
                workforce: operationsWorkforce,
                placements: riskPlacements,
                inspectedBuildingKeys: coverage.keys,
                maintenanceRiskReduction: coverage.reduction,
                models: rules.models.buildings,
                difficulty: difficulty,
                hazardRules: OriginalBuildingHazardRules(
                    configuration: rules.models.generalBuilding
                )
            )
            operationsState = operations
            applyOperationsFailures(operationsSettlement.failures)
        }
        _ = advanceMonuments()
        _ = advanceMilitary(models: rules.models.figures)
        if campaignEventState != nil {
            campaignEventState?.conditions.advanceMonth()
        }
        calendar.advanceMonth()
        var migration = migrationState ?? DeterministicMigrationState()
        migration.finishMonth()
        migrationState = migration
        monthlyServiceCoverageState = MonthlyServiceCoverageAccumulator()

        return MonthlySettlement(
            year: settlementYear,
            month: settlementMonth,
            population: settlementPopulation,
            taxedPopulation: taxedPopulation,
            untaxedPopulation: untaxedPopulation,
            collectedTaxes: collected,
            uncollectedTaxes: uncollected,
            taxSentiment: sentiment,
            startingTreasury: startingTreasury,
            endingTreasury: economy.treasury
        )
    }

    /// Compatibility API for rules tests and tools. It no longer owns a second
    /// monthly simulation path; it simply runs deterministic ticks to the next
    /// settlement boundary.
    @discardableResult
    public mutating func advanceMonth(rules: EconomyRulesEngine) -> MonthlySettlement {
        while true {
            if let settlement = advanceTick(rules: rules).monthlySettlement {
                // Compatibility callers historically observed a staged (but
                // unmoved) delivery immediately after `advanceMonth`. The live
                // timer reaches the same state on the following daily tick,
                // preserving the visible producer-stock boundary there.
                var logistics = logisticsState ?? DeterministicLogisticsState()
                let workforce = workforceEnabled
                    ? workforceSnapshot(models: rules.models.buildings)
                    : nil
                _ = logistics.scheduleDeliveries(
                    production: &production,
                    roadNetwork: roadNetwork,
                    deliveryFigureID: 22,
                    maximumOneWayRoadSteps: max(
                        1,
                        rules.models.figures[figureID: 22]?.behaviorRange ?? 24
                    ),
                    activeProductionBuildingIDs: fullyStaffedInstanceIDs(
                        category: .production,
                        workforce: workforce
                    ),
                    activeMillIDs: fullyStaffedInstanceIDs(
                        category: .mill,
                        workforce: workforce
                    )
                )
                logisticsState = logistics
                return settlement
            }
        }
    }
}
