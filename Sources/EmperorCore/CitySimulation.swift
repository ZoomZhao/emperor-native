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
    /// Original house-service countdown bytes. Health/entertainment callbacks
    /// write `0x60`; religion writes `0x28`; the original day-slice walk
    /// decrements them independently.
    public private(set) var serviceCoverageRemainingSlices: [WalkerServiceKind: Int]
    /// Tax officials use the house-building byte at `+0x52`, written as `0x32`.
    public private(set) var taxCoverageRemainingSlices: Int
    public var desirability: Int
    public var lastSuppliedFoodQualityRawValue: Int
    public var lastSuppliedCommodityIDs: Set<Int>
    /// Original `cHouseInfo+0x3C` post-removal settling lock (values `0`/`2`)
    /// with the `house+0x98` countdown (`FUN_004681A0` sets both; the daily
    /// `FUN_005185C0` walk decrements and clears — §10.6). While nonzero, the
    /// immigrant arrival occupancy write is skipped.
    public private(set) var settlingLock: Int
    public private(set) var settlingLockRemainingSteps: Int
    /// Original vacant-house building ID (`2` Vacant House / `11` Unocc Elite)
    /// before the first immigrant arrival converts the house (`+0x230`
    /// contract, §5.10): common stays level 0, elite jumps 8 → 10.
    public private(set) var vacantTypeID: Int?
    /// Signed `house+0x22` spare-room word. It is optional for backwards
    /// compatibility with Native saves created before this source field was
    /// projected; the value is currently populated at the confirmed
    /// immigrant-arrival boundary, while the full capacity-refresh cadence
    /// remains pending.
    public private(set) var originalRemainingCapacity: Int?
    /// `house+0x32` in-flight figure link. The value is the Native immigrant
    /// walker ID for the narrow fixture/arrival bridge; automatic assignment
    /// remains fail-closed until its full figure registry is recovered.
    public private(set) var originalInFlightFigureID: Int?
    /// Optional projection of the signed `house+0x24` access/flood value used
    /// by the original assignment and capacity passes. Nil means that the
    /// map/object candidate has not been proven for this Native house.
    public private(set) var originalHouseAccessValue: Int?
    /// Access cell copied to the source `house+0x2A/+0x2C` words when a
    /// candidate is resolved. Optionality preserves unresolved map-object
    /// projections in older and partially decoded saves.
    public private(set) var originalHouseAccessPoint: GridPoint?
    /// Retry short corresponding to source `house+0x28`. It is optional so a
    /// Native save cannot silently claim a retry history that was never
    /// recovered from the executable's object state.
    public private(set) var originalHouseAccessRetryCount: Int?
    /// Optional projection of source `house+0x26`, the resident high-water
    /// word maintained by the daily capacity refresh.
    public private(set) var originalCapacityHighWater: Int?
    /// Optional projections of the two independent `cHouseInfo` water
    /// countdown bytes (`+0x32` and `+0x34`). They remain optional because the
    /// provider/object bridge that selects the destination byte is not yet
    /// recovered; a missing value therefore means "unprojected", not zero.
    public private(set) var originalWaterPrimaryRemainingSlices: Int?
    public private(set) var originalWaterSecondaryRemainingSlices: Int?
    /// Original `house+0x5C` food-shortage streak byte consumed by the
    /// popularity food walk `FUN_00590F30` (§3): `1→−1, 2→−2, ≥3→−3`.
    public private(set) var foodShortageStreak: Int

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
        serviceCoverageRemainingSlices: [WalkerServiceKind: Int] = [:],
        taxCoverageRemainingSlices: Int = 0,
        desirability: Int = 0,
        lastSuppliedFoodQualityRawValue: Int = FoodQuality.none.rawValue,
        lastSuppliedCommodityIDs: Set<Int> = [],
        settlingLock: Int = 0,
        settlingLockRemainingSteps: Int = 0,
        vacantTypeID: Int? = nil,
        originalRemainingCapacity: Int? = nil,
        originalInFlightFigureID: Int? = nil,
        originalHouseAccessValue: Int? = nil,
        originalHouseAccessPoint: GridPoint? = nil,
        originalHouseAccessRetryCount: Int? = nil,
        originalCapacityHighWater: Int? = nil,
        originalWaterPrimaryRemainingSlices: Int? = nil,
        originalWaterSecondaryRemainingSlices: Int? = nil,
        foodShortageStreak: Int = 0
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
        var recoveredCoverage = serviceCoverageRemainingSlices.mapValues { max(0, $0) }
        for service in serviceCoverage where recoveredCoverage[service] == nil {
            recoveredCoverage[service] = Self.originalCoverageWrite(for: service)
        }
        self.serviceCoverageRemainingSlices = recoveredCoverage
        self.taxCoverageRemainingSlices = max(
            0,
            taxCoverageRemainingSlices > 0 ? taxCoverageRemainingSlices : (hasTaxCoverage ? 0x32 : 0)
        )
        self.desirability = desirability
        self.lastSuppliedFoodQualityRawValue = lastSuppliedFoodQualityRawValue
        self.lastSuppliedCommodityIDs = lastSuppliedCommodityIDs
        self.settlingLock = max(0, settlingLock)
        self.settlingLockRemainingSteps = max(0, settlingLockRemainingSteps)
        self.vacantTypeID = vacantTypeID
        self.originalRemainingCapacity = originalRemainingCapacity.map(Self.clampOriginalHouseWord)
        self.originalInFlightFigureID = originalInFlightFigureID
            .flatMap { $0 > 0 ? $0 : nil }
        self.originalHouseAccessValue = originalHouseAccessValue
            .map(Self.clampOriginalHouseWord)
        self.originalHouseAccessPoint = originalHouseAccessPoint
        self.originalHouseAccessRetryCount = originalHouseAccessRetryCount
            .map(Self.clampOriginalHouseWord)
        self.originalCapacityHighWater = originalCapacityHighWater
            .map(Self.clampOriginalHouseWord)
        self.originalWaterPrimaryRemainingSlices = originalWaterPrimaryRemainingSlices
            .map(Self.clampOriginalWaterByte)
        self.originalWaterSecondaryRemainingSlices = originalWaterSecondaryRemainingSlices
            .map(Self.clampOriginalWaterByte)
        self.foodShortageStreak = min(3, max(0, foodShortageStreak))
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

    public mutating func applyOriginalServiceVisit(_ service: WalkerServiceKind) {
        if service == .tax {
            hasTaxCoverage = true
            taxCoverageRemainingSlices = 0x32
        } else {
            serviceCoverage.insert(service)
            serviceCoverageRemainingSlices[service] = Self.originalCoverageWrite(for: service)
        }
    }

    public mutating func resetOriginalServiceCoverage() {
        serviceCoverage.removeAll()
        serviceCoverageRemainingSlices.removeAll()
    }

    public mutating func clearOriginalTaxCoverage() {
        hasTaxCoverage = false
        taxCoverageRemainingSlices = 0
    }

    public mutating func advanceOriginalOrdinaryServiceSlice() {
        for service in Array(serviceCoverageRemainingSlices.keys) {
            let remaining = max(0, serviceCoverageRemainingSlices[service, default: 0] - 1)
            if remaining == 0 {
                serviceCoverageRemainingSlices.removeValue(forKey: service)
                serviceCoverage.remove(service)
            } else {
                serviceCoverageRemainingSlices[service] = remaining
            }
        }
    }

    public mutating func advanceOriginalTaxServiceSlice() {
        guard taxCoverageRemainingSlices > 0 else { return }
        taxCoverageRemainingSlices -= 1
        if taxCoverageRemainingSlices == 0 { hasTaxCoverage = false }
    }

    private static func originalCoverageWrite(for service: WalkerServiceKind) -> Int {
        switch service {
        case .ancestor, .confucian, .daoistOrBuddhist:
            return 0x28
        default:
            return 0x60
        }
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
        recordEvolutionSupplies(
            foodQualityRawValue: foodQuality.rawValue,
            commodityIDs: commodityIDs
        )
    }

    /// Records the raw quality byte consumed by the original evolution walk.
    /// Unknown intermediate values remain comparable to authored thresholds.
    public mutating func recordEvolutionSupplies(
        foodQualityRawValue: Int,
        commodityIDs: Set<Int>
    ) {
        lastSuppliedFoodQualityRawValue = min(255, max(0, foodQualityRawValue))
        lastSuppliedCommodityIDs = commodityIDs
    }

    public mutating func addFoodSupply(amount: Int, quality: FoodQuality) {
        addFoodSupply(amount: amount, qualityRawValue: quality.rawValue)
    }

    /// Applies a market delivery using the original house-info quality byte.
    ///
    /// The executable stores `cHouseInfo+0x36` as a raw byte.  The authored
    /// player-facing quality bands are only a presentation mapping; market
    /// blending can produce intermediate byte values, so callers that have
    /// recovered a raw writer must not force the value through `FoodQuality`.
    public mutating func addFoodSupply(amount: Int, qualityRawValue: Int) {
        guard amount > 0 else { return }
        let marketQuality = min(255, max(0, qualityRawValue))
        // Elite building models 11…17 (Native house levels 8…14) skip the
        // quality write when the market quality band is below 3
        // (`FUN_005188D0` gate in `FUN_00543B20`/§10.10); the food itself is
        // still added.
        if houseLevelID >= 8, houseLevelID < 15, marketQuality <= 49 {
            foodSupplyAmount += amount
            return
        }
        let currentQuality = foodQualityRawValue
        // The source callback replaces a better market byte and otherwise
        // applies the recovered five-ratio table. Keeping both branches in
        // the source-backed primitive avoids a divergent implementation here.
        if let updatedQuality = OriginalMarketHouseQualityBlend.resolve(
            currentQuality: currentQuality,
            marketQuality: marketQuality,
            existingStock: foodSupplyAmount,
            deliveredAmount: amount
        ) {
            foodQualityRawValue = updatedQuality
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

    /// Original `FUN_004681A0` / `FUN_00468420` resident-removal setter
    /// (`+0x3C = 2`, `house+0x98 = 32`; §10.6). The lock suppresses immigrant
    /// occupancy writes while it runs.
    public mutating func startSettlingLock(steps: Int = 32) {
        settlingLock = 2
        settlingLockRemainingSteps = max(1, steps)
    }

    /// Daily `FUN_005185C0` equivalent: an empty house clears immediately;
    /// otherwise the countdown decrements and the lock clears at zero (§10.6).
    public mutating func advanceSettlingLock() {
        guard settlingLock != 0 else { return }
        if residents == 0 {
            settlingLock = 0
            settlingLockRemainingSteps = 0
            return
        }
        settlingLockRemainingSteps -= 1
        if settlingLockRemainingSteps <= 0 {
            settlingLock = 0
            settlingLockRemainingSteps = 0
        }
    }

    /// Original `FUN_00518DE0` / house vtable `+0x230` type switch on first
    /// occupancy (§5.10): vacant common `2 → 3` (level stays 0), vacant elite
    /// `11 → 13` (Native level 8 → 10). Clears the vacant marker.
    public mutating func activateVacantHouse() {
        guard residents == 0, let vacant = vacantTypeID else { return }
        if vacant == 11 {
            houseLevelID = 10
        }
        vacantTypeID = nil
    }

    /// Original `house+0x5C` streak update in the food walk (§3).
    public mutating func recordFoodQualityScore(_ satisfied: Bool) {
        if satisfied {
            foodShortageStreak = 0
        } else {
            foodShortageStreak = min(3, foodShortageStreak + 1)
        }
    }

    /// `FUN_00590F30` clears `house+0x5C` when the authored food requirement
    /// is zero before skipping that house in the popularity average.
    public mutating func resetFoodQualityStreak() {
        foodShortageStreak = 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, houseLevelID, residents, hasTaxCoverage, footprintMultiplier, location
        case orientation
        case suppliesByCommodityID, commodityShortageMonths
        case foodSupplyAmount, foodQualityRawValue
        case serviceCoverage, serviceCoverageRemainingSlices, taxCoverageRemainingSlices, desirability
        case lastSuppliedFoodQualityRawValue, lastSuppliedCommodityIDs
        case settlingLock, settlingLockRemainingSteps
        case vacantTypeID
        case originalRemainingCapacity, originalInFlightFigureID
        case originalHouseAccessValue, originalHouseAccessPoint
        case originalHouseAccessRetryCount, originalCapacityHighWater
        case originalWaterPrimaryRemainingSlices, originalWaterSecondaryRemainingSlices
        case foodShortageStreak
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
        serviceCoverageRemainingSlices = try container.decodeIfPresent(
            [WalkerServiceKind: Int].self,
            forKey: .serviceCoverageRemainingSlices
        ) ?? Dictionary(
            uniqueKeysWithValues: serviceCoverage.map { ($0, Self.originalCoverageWrite(for: $0)) }
        )
        taxCoverageRemainingSlices = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .taxCoverageRemainingSlices)
                ?? (hasTaxCoverage ? 0x32 : 0)
        )
        desirability = try container.decodeIfPresent(Int.self, forKey: .desirability) ?? 0
        lastSuppliedFoodQualityRawValue = try container.decodeIfPresent(
            Int.self,
            forKey: .lastSuppliedFoodQualityRawValue
        ) ?? FoodQuality.none.rawValue
        lastSuppliedCommodityIDs = try container.decodeIfPresent(
            Set<Int>.self,
            forKey: .lastSuppliedCommodityIDs
        ) ?? []
        settlingLock = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .settlingLock) ?? 0
        )
        settlingLockRemainingSteps = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .settlingLockRemainingSteps) ?? 0
        )
        vacantTypeID = try container.decodeIfPresent(Int.self, forKey: .vacantTypeID)
        originalRemainingCapacity = try container.decodeIfPresent(
            Int.self,
            forKey: .originalRemainingCapacity
        ).map(Self.clampOriginalHouseWord)
        originalInFlightFigureID = try container.decodeIfPresent(
            Int.self,
            forKey: .originalInFlightFigureID
        ).flatMap { $0 > 0 ? $0 : nil }
        originalHouseAccessValue = try container.decodeIfPresent(
            Int.self,
            forKey: .originalHouseAccessValue
        ).map(Self.clampOriginalHouseWord)
        originalHouseAccessPoint = try container.decodeIfPresent(
            GridPoint.self,
            forKey: .originalHouseAccessPoint
        )
        originalHouseAccessRetryCount = try container.decodeIfPresent(
            Int.self,
            forKey: .originalHouseAccessRetryCount
        ).map(Self.clampOriginalHouseWord)
        originalCapacityHighWater = try container.decodeIfPresent(
            Int.self,
            forKey: .originalCapacityHighWater
        ).map(Self.clampOriginalHouseWord)
        originalWaterPrimaryRemainingSlices = try container.decodeIfPresent(
            Int.self,
            forKey: .originalWaterPrimaryRemainingSlices
        ).map(Self.clampOriginalWaterByte)
        originalWaterSecondaryRemainingSlices = try container.decodeIfPresent(
            Int.self,
            forKey: .originalWaterSecondaryRemainingSlices
        ).map(Self.clampOriginalWaterByte)
        foodShortageStreak = min(
            3,
            max(
                0,
                try container.decodeIfPresent(Int.self, forKey: .foodShortageStreak) ?? 0
            )
        )
    }

    private static func clampOriginalHouseWord(_ value: Int) -> Int {
        min(Int(Int16.max), max(Int(Int16.min), value))
    }

    private static func clampOriginalWaterByte(_ value: Int) -> Int {
        min(0xFF, max(0, value))
    }

    /// Stores the source signed spare-room word without widening its 16-bit
    /// save/runtime domain.
    public mutating func setOriginalRemainingCapacity(_ value: Int?) {
        originalRemainingCapacity = value.map(Self.clampOriginalHouseWord)
    }

    /// Stores or clears the source in-flight figure link. Zero is represented
    /// as no link, matching the original house word.
    public mutating func setOriginalInFlightFigureID(_ value: Int?) {
        originalInFlightFigureID = value.flatMap { $0 > 0 ? $0 : nil }
    }

    /// Stores a source-backed positive access refresh and its selected cell.
    /// The caller must have already resolved the candidate and flood depth;
    /// this method performs no Native geometry inference.
    public mutating func setOriginalHouseAccess(
        value: Int?,
        point: GridPoint?,
        retryCount: Int? = nil
    ) {
        originalHouseAccessValue = value.map(Self.clampOriginalHouseWord)
        originalHouseAccessPoint = point
        originalHouseAccessRetryCount = retryCount.map(Self.clampOriginalHouseWord)
    }

    /// Stores the source signed resident high-water word without widening its
    /// serialized 16-bit domain.
    public mutating func setOriginalCapacityHighWater(_ value: Int?) {
        originalCapacityHighWater = value.map(Self.clampOriginalHouseWord)
    }

    /// Writes one explicitly-resolved source water byte. This is deliberately
    /// separate from `applyOriginalServiceVisit(.water)`: the executable's
    /// `0x51BC00` callback chooses `+0x32` versus `+0x34` from provider/global
    /// state that Native has not recovered. Callers must therefore supply the
    /// destination rather than allowing a guessed default.
    public mutating func setOriginalWaterRemainingSlices(
        _ value: Int?,
        destination: OriginalWaterProviderState.HouseInfoWaterByte
    ) {
        let normalized = value.map(Self.clampOriginalWaterByte)
        switch destination {
        case .primary32:
            originalWaterPrimaryRemainingSlices = normalized
        case .secondary34:
            originalWaterSecondaryRemainingSlices = normalized
        }
    }

    /// Applies one source water callback value (`0x60`) after its destination
    /// byte has already been resolved by the caller. The other byte is kept
    /// untouched, preserving the original independent lifetimes.
    public mutating func applyOriginalWaterVisit(
        destination: OriginalWaterProviderState.HouseInfoWaterByte
    ) {
        setOriginalWaterRemainingSlices(0x60, destination: destination)
    }

    /// Advances both projected water bytes by one `FUN_00517280` decay slice.
    /// Unprojected (`nil`) bytes remain nil; a byte reaches zero after the
    /// source's `< 2 → 0, otherwise −1` operation.
    public mutating func advanceOriginalWaterServiceSlice() {
        originalWaterPrimaryRemainingSlices = Self.decayOriginalWaterByte(
            originalWaterPrimaryRemainingSlices
        )
        originalWaterSecondaryRemainingSlices = Self.decayOriginalWaterByte(
            originalWaterSecondaryRemainingSlices
        )
    }

    private static func decayOriginalWaterByte(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return value < 2 ? 0 : value - 1
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
    /// Monument completion at the original month-boundary checkpoint. The
    /// final simulation step's monument scheduler runs after this snapshot.
    public let completedMonumentBuildingIDsAtBoundary: Set<Int>?
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
    /// Optional so saves written before the producer context existed decode.
    private var migrationContextState: CampaignMigrationContext?
    /// Optional campaign-city selector copied from authored city runtime
    /// field `+0x3AAC`; invalid/custom values remain raw and fail closed.
    private var campaignEnemySetIndexState: Int?
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
        migrationContextState = CampaignMigrationContext()
        campaignEnemySetIndexState = nil
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

    public var migrationContext: CampaignMigrationContext {
        migrationContextState ?? CampaignMigrationContext()
    }

    public var campaignEnemySetIndex: Int? { campaignEnemySetIndexState }

    /// Stores the authored city-runtime `+0x3AAC` selector without widening
    /// or clamping it. The source builder performs its own 0...6 validation.
    public mutating func setCampaignEnemySetIndex(_ value: Int?) {
        campaignEnemySetIndexState = value
    }

    /// Runtime sets this at mission start and each monthly advance (wage,
    /// debt months, monument goals).
    public mutating func setMigrationContext(_ context: CampaignMigrationContext) {
        migrationContextState = context
    }

    /// Fixture/verification switch for the recovered producer. Production
    /// stays on `.unsupportedOriginalProducer` until the playthrough gates
    /// pass end-to-end.
    public mutating func setAutomaticMigrationAvailability(
        _ availability: AutomaticMigrationAvailability
    ) {
        var migration = migrationState ?? DeterministicMigrationState()
        migration.setAutomaticMigrationAvailability(availability)
        migrationState = migration
    }

    /// Fixture/verification setter for the recovered popularity seed.
    public mutating func setMigrationPopularity(_ value: Int) {
        var migration = migrationState ?? DeterministicMigrationState()
        migration.setPopularity(value)
        migrationState = migration
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

    /// Projects constructed Laborers' Camps into the exact provider inputs
    /// consumed by the recovered Grand Canal coordinator. Enumeration follows
    /// placement order, matching the original strict-distance tie behavior.
    public func grandCanalPhaseLaborProviders(
        models: BuildingModelTable
    ) -> [OriginalGrandCanalLayoutCatalog.PhaseLaborProviderCandidate] {
        grandCanalPhaseLaborProviders(
            models: models,
            coordinator: aesthetics.grandCanalPhaseLaborCoordinator
        )
    }

    private func grandCanalPhaseLaborProviders(
        models: BuildingModelTable,
        coordinator: OriginalGrandCanalLayoutCatalog.PhaseLaborCoordinatorRuntime
    ) -> [OriginalGrandCanalLayoutCatalog.PhaseLaborProviderCandidate] {
        let assignments = Dictionary(uniqueKeysWithValues:
            workforceSnapshot(models: models).assignments.map { ($0.key, $0) }
        )
        let activeCounts = Dictionary(grouping:
            coordinator.laborers,
            by: \.providerObjectID
        ).mapValues(\.count)
        return placedBuildings.compactMap { placement in
            guard placement.buildingID
                    == OriginalGrandCanalLayoutCatalog.phaseLaborProviderBuildingID
            else { return nil }
            let key = OperationalBuildingKey(
                category: placement.category,
                instanceID: placement.instanceID
            )
            let assignment = assignments[key]
            return OriginalGrandCanalLayoutCatalog.PhaseLaborProviderCandidate(
                objectID: placement.instanceID,
                buildingID: placement.buildingID,
                isActive: true,
                efficiencyPercent: OriginalGrandCanalLayoutCatalog
                    .phaseLaborProviderEfficiencyPercent(
                        requiredWorkers: assignment?.requiredWorkers ?? 0,
                        assignedWorkers: assignment?.assignedWorkers ?? 0
                    ),
                activeMonumentWorkerCount: activeCounts[placement.instanceID] ?? 0,
                origin: placement.origin
            )
        }
    }

    /// Produces the `FUN_00567540`-equivalent initial targets only from a
    /// complete source-derived primary routing cache. Callers that cannot
    /// supply that cache receive no dispatchable accesses.
    public func grandCanalPhaseLaborTargetAccesses(
        routingGrids: OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids
    ) throws -> [OriginalGrandCanalLayoutCatalog.PhaseLaborTargetAccessCandidate] {
        guard let terrain,
              terrain.width == routingGrids.width,
              terrain.height == routingGrids.height else {
            throw OriginalGrandCanalLayoutCatalog.WorkerRoutingCacheDerivationError
                .invalidGridDimensions
        }
        let ranks = try OriginalGrandCanalLayoutCatalog.workerRoadComponentRankByPoint(
            width: terrain.width,
            height: terrain.height,
            terrainRawValues: terrain.terrainRawValues,
            primaryPassability: routingGrids.primaryPassability
        )
        return OriginalGrandCanalLayoutCatalog.phaseLaborTargetAccesses(
            parts: aesthetics.grandCanalMapPartStates,
            roadComponentRankByPoint: ranks
        )
    }

    public func grandCanalPhaseTwoTargetAccesses(
        routingGrids: OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids
    ) throws -> [OriginalGrandCanalLayoutCatalog.PhaseTwoTargetAccessCandidate] {
        try grandCanalPhaseLaborTargetAccesses(routingGrids: routingGrids).map {
            .init(
                subBuildingIndex: $0.subBuildingIndex,
                worldOrigin: $0.worldOrigin,
                roadAccessPoint: $0.roadAccessPoint
            )
        }
    }

    public func greatWallTargetAccesses(
        routingGrids: OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids
    ) throws -> [OriginalGreatWallLayoutCatalog.TargetAccessCandidate] {
        guard let terrain,
              terrain.width == routingGrids.width,
              terrain.height == routingGrids.height else {
            throw OriginalGrandCanalLayoutCatalog.WorkerRoutingCacheDerivationError
                .invalidGridDimensions
        }
        let ranks = try OriginalGrandCanalLayoutCatalog.workerRoadComponentRankByPoint(
            width: terrain.width,
            height: terrain.height,
            terrainRawValues: terrain.terrainRawValues,
            primaryPassability: routingGrids.primaryPassability
        )
        return OriginalGreatWallLayoutCatalog.targetAccesses(
            parts: aesthetics.greatWallMapPartStates,
            roadComponentRankByPoint: ranks
        )
    }

    /// Rebuilds the original worker routing inputs from the Native city's
    /// single sources of truth. This intentionally supports only occupancy
    /// classes whose routing vtables are source-confirmed; encountering any
    /// other live building stops derivation at that coordinate.
    public func grandCanalWorkerRoutingGrids() throws
        -> OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids {
        guard let terrain else {
            throw OriginalGrandCanalLayoutCatalog.WorkerRoutingCacheDerivationError
                .invalidGridDimensions
        }
        typealias Occupancy = OriginalGrandCanalLayoutCatalog.WorkerRoutingCellOccupancy
        var occupancyByPoint: [GridPoint: Occupancy] = [:]

        func insert(_ occupancy: Occupancy, at points: [GridPoint]) throws {
            for point in points {
                guard terrain.contains(point) else {
                    throw OriginalGrandCanalLayoutCatalog
                        .WorkerRoutingCacheDerivationError.invalidGridDimensions
                }
                guard occupancyByPoint.updateValue(occupancy, forKey: point) == nil else {
                    throw OriginalGrandCanalLayoutCatalog
                        .WorkerRoutingCacheDerivationError.duplicateOccupancy(point)
                }
            }
        }

        let houseFootprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        for house in houses {
            guard let origin = house.location else { continue }
            let buildingID = house.houseLevelID + 3
            try insert(
                Occupancy(
                    buildingID: buildingID,
                    genericFootprintPredicate:
                        OriginalGrandCanalLayoutCatalog
                            .BuildingFootprintPredicateCatalog
                            .genericFootprintPredicate(forBuildingID: buildingID)
                ),
                at: houseFootprint.points(at: origin)
            )
        }
        for placement in placedBuildings {
            // Only classes whose vtable `+0xCC` result is directly recovered
            // receive a predicate. Unknown classes stay nil and therefore
            // fail closed in both cache builders; a building being visibly
            // non-walkable is not evidence for this callback's return value.
            let predicate = OriginalGrandCanalLayoutCatalog
                .BuildingFootprintPredicateCatalog
                .genericFootprintPredicate(forBuildingID: placement.buildingID)
            try insert(
                Occupancy(
                    buildingID: placement.buildingID,
                    genericFootprintPredicate: predicate
                ),
                at: placement.occupiedPoints
            )
        }
        let canalFootprint = BuildingFootprint(width: 4, height: 4)
        for part in aesthetics.grandCanalMapPartStates {
            try insert(
                Occupancy(
                    buildingID: part.buildingID,
                    currentMonumentSubBuildingPhase: part.currentSubBuildingPhase,
                    genericFootprintPredicate: false
                ),
                at: canalFootprint.points(at: part.worldOrigin)
            )
        }
        let greatWallRootPhase = aesthetics.greatWallMapPartStates
            .first(where: { $0.subBuildingIndex == 0 })?.currentSubBuildingPhase
        for part in aesthetics.greatWallMapPartStates {
            guard let kind = OriginalGreatWallLayoutCatalog.subBuildingKind(
                buildingID: part.buildingID,
                subBuildingIndex: part.subBuildingIndex
            ) else {
                throw OriginalGrandCanalLayoutCatalog
                    .WorkerRoutingCacheDerivationError.unsupportedGreatWallSubtype(
                        part.worldOrigin,
                        buildingID: part.buildingID
                    )
            }
            let footprint = BuildingFootprint(
                width: kind.footprintSide,
                height: kind.footprintSide
            )
            try insert(
                Occupancy(
                    buildingID: part.buildingID,
                    currentMonumentSubBuildingPhase: part.currentSubBuildingPhase,
                    greatWallRootSubBuildingPhase: greatWallRootPhase,
                    greatWallPartKind: kind,
                    genericFootprintPredicate: false
                ),
                at: footprint.points(at: part.worldOrigin)
            )
        }

        var inputs: [OriginalGrandCanalLayoutCatalog.WorkerRoutingCellInput] = []
        inputs.reserveCapacity(terrain.width * terrain.height)
        for y in 0..<terrain.height {
            for x in 0..<terrain.width {
                let point = GridPoint(x: x, y: y)
                let index = y * terrain.width + x
                var raw = terrain.terrainRawValues[index] & ~UInt32(0x40)
                if roadNetwork.contains(point) { raw |= 0x40 }
                let occupancy = occupancyByPoint[point]
                if occupancy != nil { raw |= 0x8008 }
                inputs.append(.init(
                    point: point,
                    terrainRawValue: raw,
                    occupancy: occupancy,
                    roadWaterAuxiliaryByte: terrain.roadWaterAuxiliary(at: point),
                    primaryElevationClassByte: terrain.primaryElevationClass(at: point),
                    primarySurfaceObjectIsAbsentOrNonblocking: true
                ))
            }
        }
        return try OriginalGrandCanalLayoutCatalog.workerRoutingGrids(
            width: terrain.width,
            height: terrain.height,
            inputs: inputs
        )
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

    /// Road-block tiles (building 126). They stay in the road network and in
    /// every derived routing layer, so destination/path-following movement
    /// crosses them; roaming patrols and roamer coverage treat them as closed.
    public var roadblockPoints: Set<GridPoint> {
        Set(
            placedBuildings
                .filter { $0.buildingID == 126 }
                .flatMap(\.occupiedPoints)
        )
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
        if !map.grandCanalPartStates.isEmpty {
            var aesthetics = aestheticState ?? DeterministicAestheticState()
            aesthetics.restoreGrandCanalMapPartStates(map.grandCanalPartStates)
            aestheticState = aesthetics
        }
        if !map.greatWallPartStates.isEmpty {
            var aesthetics = aestheticState ?? DeterministicAestheticState()
            aesthetics.restoreGreatWallMapPartStates(map.greatWallPartStates)
            aestheticState = aesthetics
        }
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
        guard campaignConstructionRestriction(forBuildingID: buildingID) == nil else {
            return false
        }
        // The authored menu permission is necessary but not sufficient for a
        // player-facing construction action. Keep the unresolved entertainment
        // provider classes disabled in campaign cities; sandbox fixtures may
        // still construct them to exercise isolated catalog/state code.
        guard missionSettingsState != nil else { return true }
        return OriginalResidentialServiceCatalog.isCampaignConstructionSupported(
            buildingID: buildingID
        )
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
            vacantTypeID: constructionBuildingID == 11 ? 11 : 2,
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
            // Terrain guards (0x8/0x400/road-water auxiliary) live in the
            // centralized terrain predicate; map-less procedural cities have
            // no terrain and rely on road-network membership alone.
            && (terrain?.canPlaceRoadBlock(at: point) ?? true)
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
        vacantTypeID: Int? = nil,
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
            orientation: orientation,
            vacantTypeID: vacantTypeID
        ))
        return id
    }

    @discardableResult
    /// Loader/test-fixture primitive. Production simulation must not call this
    /// until the original popularity/factor migration producer is implemented.
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

    /// Original immigrant arrival write at `0x4CA265` (§5.3): skips while the
    /// settling lock is set, converts a vacant house on first occupancy, and
    /// adds the people count clamped to capacity. Population is derived from
    /// house residents, so no separate counter is needed.
    @discardableResult
    public mutating func applyImmigrantArrival(
        _ arrival: ImmigrantArrival,
        models: BuildingModelTable
    ) -> Bool {
        guard let index = houses.firstIndex(where: { $0.id == arrival.houseID }) else {
            return false
        }
        let house = houses[index]
        // The executable's +0x14 is the vacant building ID while a house is
        // empty and otherwise follows the proven +3 building projection for
        // occupied Native housing levels (§10.30 / §10.95).
        let sourceHouseTypeID = house.vacantTypeID ?? (house.houseLevelID + 3)
        // A missing authored row is an unsupported state, not permission to
        // substitute the Native-derived capacity and invent an arrival rule.
        guard let capacitySnapshot = DeterministicMigration
            .originalImmigrantCapacitySnapshot(
                houseTypeID: sourceHouseTypeID,
                houseLevelIndex: house.houseLevelID,
                models: models,
                difficulty: difficulty
            ) else {
            return false
        }
        let outcome = DeterministicMigration.originalImmigrantArrivalWrite(
            .init(
                houseTypeID: sourceHouseTypeID,
                houseResidents: house.residents,
                figurePeopleCount: arrival.peopleCount,
                capacitySnapshot: capacitySnapshot,
                houseInfoSettlingByte: house.settlingLock
            )
        )

        // +0x230 runs before the cHouseInfo+0x3C occupancy gate.  This is
        // observable for a locked vacant house even though no residents are
        // admitted during the settling interval.
        if outcome.vacantConversionArgument != nil {
            houses[index].activateVacantHouse()
        }
        // State-8 clears the source in-flight figure link regardless of the
        // settling gate. The optional Native field mirrors that confirmed
        // write while the walker itself is removed by the caller.
        houses[index].setOriginalInFlightFigureID(nil)
        guard outcome.invokedPopulationWriter, outcome.residentDelta > 0 else {
            return false
        }
        houses[index].residents += outcome.residentDelta
        houses[index].setOriginalRemainingCapacity(outcome.remainingCapacity)
        return true
    }

    /// Arms the original post-removal settling lock on a house
    /// (`FUN_004681A0` contract, §10.6). The production resident-removal path
    /// calls this; the arrival write skips while it is set.
    @discardableResult
    public mutating func startHouseSettlingLock(houseID: Int, steps: Int = 32) -> Bool {
        guard let index = houses.firstIndex(where: { $0.id == houseID }) else { return false }
        houses[index].startSettlingLock(steps: steps)
        return true
    }

    /// Spawns a physical immigrant figure (model 11) from the authored land
    /// entry toward `houseID`. The producer is unsupported, so production
    /// never calls this; fixtures use it to exercise the arrival chain.
    /// `houseWaitOffset` is the recovered `house+0x51` term (semantics not
    /// closed; defaults to 0 and is recorded as an inference).
    @discardableResult
    public mutating func spawnImmigrant(
        houseID: Int,
        peopleCount: Int,
        houseWaitOffset: Int = 0,
        grids: OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids
    ) -> Int? {
        var migration = migrationState ?? DeterministicMigrationState()
        let result = spawnImmigrant(
            houseID: houseID,
            peopleCount: peopleCount,
            houseWaitOffset: houseWaitOffset,
            grids: grids,
            into: &migration
        )
        migrationState = migration
        return result
    }

    @discardableResult
    private mutating func spawnImmigrant(
        houseID: Int,
        peopleCount: Int,
        houseWaitOffset: Int = 0,
        grids: OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids,
        roadComponentRankByPoint: [GridPoint: Int]? = nil,
        into migration: inout DeterministicMigrationState
    ) -> Int? {
        guard let house = houses.first(where: { $0.id == houseID }),
              let location = house.location,
              let entry = terrain?.authoredPoints?.landEntry,
              let destination = {
                  let vacantBuildingID = house.vacantTypeID
                      ?? (house.houseLevelID == 10 ? 11 : 2)
                  if let roadComponentRankByPoint {
                      return DeterministicMigration.recoveredHouseRoadAccessPoint(
                          houseLocation: location,
                          vacantBuildingID: vacantBuildingID,
                          roadComponentRankByPoint: roadComponentRankByPoint
                      )
                  }
                  return DeterministicMigration.houseRoadAccessPoint(
                      houseLocation: location,
                      vacantBuildingID: vacantBuildingID,
                      roadNetwork: roadNetwork
                  )
              }() else {
            return nil
        }
        // `FUN_004AD4A0` decrements the shared stagger once before the
        // assignment walk. `FUN_004ADE10` only reads that word, then its
        // successful spawn increments through the caller's +0x32 update;
        // do not decrement again for each selected house.
        let waitSteps = (houseWaitOffset & 0xFF7F) + migration.immigrantWaitGlobal
        guard let walker = DeterministicMigration.spawnImmigrant(
            id: migration.nextImmigrantWalkerID,
            houseID: houseID,
            peopleCount: peopleCount,
            entryPoint: entry,
            destination: destination,
            waitSteps: waitSteps,
            primaryValues: grids.primaryPassability,
            fallbackValues: grids.fallbackCellClass,
            width: grids.width,
            height: grids.height
        ) else {
            return nil
        }
        let walkerID = walker.id
        migration.registerImmigrantWalker(walker)
        if let index = houses.firstIndex(where: { $0.id == houseID }) {
            // `FUN_004ADE10` links a successfully allocated immigrant figure
            // into house+0x32 before the walker begins its route.
            houses[index].setOriginalInFlightFigureID(walkerID)
        }
        return walkerID
    }

    /// Refreshes the recovered HouseBldg access/flood words before the
    /// assignment pass. The source candidate table is projected only when
    /// every perimeter cell is in-bounds and none carries the unresolved
    /// object flag (`0x8`). Ferry maps and incomplete routing/object inputs
    /// remain untouched, preserving the source-first fail-closed boundary.
    private mutating func refreshOriginalHouseAccessAndCapacity(
        rules: EconomyRulesEngine
    ) {
        guard missionSettingsState != nil,
              let terrain,
              let entry = terrain.authoredPoints?.landEntry,
              !placedBuildings.contains(where: { $0.buildingID == 210 }),
              houses.contains(where: {
                  $0.location != nil && $0.originalHouseAccessValue == nil
              })
        else { return }

        let width = terrain.width
        let height = terrain.height
        let rawTerrain = terrain.terrainRawValues
        guard let grids = try? grandCanalWorkerRoutingGrids(),
              let ranks = try? OriginalGrandCanalLayoutCatalog
                  .workerRoadComponentRankByPoint(
                      width: width,
                      height: height,
                      terrainRawValues: rawTerrain,
                      primaryPassability: grids.primaryPassability
                  ) else { return }
        let flood = DeterministicMigration.landEntryFloodDepths(
            width: width,
            height: height,
            primaryPassability: grids.primaryPassability,
            seed: entry
        )
        var occupiedBuildingIDsByPoint: [GridPoint: Set<Int>] = [:]
        func recordOccupied(_ buildingID: Int, points: [GridPoint]) {
            for point in points {
                occupiedBuildingIDsByPoint[point, default: []].insert(buildingID)
            }
        }
        for house in houses {
            guard let origin = house.location else { continue }
            let buildingID = house.houseLevelID + 3
            let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
                ?? BuildingFootprint(width: 2, height: 2)
            recordOccupied(buildingID, points: footprint.points(at: origin))
        }
        for placement in placedBuildings {
            recordOccupied(placement.buildingID, points: placement.occupiedPoints)
        }

        func inBounds(_ point: GridPoint) -> Bool {
            point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
        }

        for index in houses.indices {
            guard let location = houses[index].location else { continue }
            let vacantBuildingID = houses[index].vacantTypeID
                ?? (houses[index].houseLevelID == 10 ? 11 : 2)
            guard let footprint = OriginalBuildingFootprintCatalog
                .residentialObjectFootprint(forBuildingID: vacantBuildingID),
                  footprint.width == footprint.height else { continue }

            // A perimeter cell with source bit 0x8 enters the object-vtable
            // callback path in FUN_004BA6F0. Only directly catalogued ordinary
            // object classes may continue; unresolved registry/Way adjustment
            // cases remain rejected.
            let perimeter = OriginalMultipartMonumentRoutingCatalog
                .roadAccessOffsets(footprintSide: footprint.width)
            let perimeterIsResolved = perimeter.allSatisfy { offset in
                let point = GridPoint(
                    x: location.x + offset.x,
                    y: location.y + offset.y
                )
                guard inBounds(point) else { return false }
                let raw = rawTerrain[point.y * width + point.x]
                var testedX = point.x
                var testedY = point.y
                if raw & 0x8 != 0 {
                    guard let objectIDs = occupiedBuildingIDsByPoint[point],
                          objectIDs.count == 1,
                          let objectID = objectIDs.first
                    else { return false }
                    if OriginalGrandCanalLayoutCatalog
                        .HouseAccessPerimeterObjectCatalog
                        .wayBuildingIDs.contains(objectID) {
                        if raw & 0x40 == 0 {
                            guard let direction = terrain.roadDirection(at: point) else {
                                return false
                            }
                            if direction & 0x07 != 0 {
                                testedX += direction & 0x07 == 1 ? 1 : -1
                            } else if direction & 0x38 == 0x08 {
                                testedY += 1
                            } else {
                                testedY -= 1
                            }
                            let testedPoint = GridPoint(x: testedX, y: testedY)
                            guard inBounds(testedPoint) else { return false }
                        }
                    } else {
                        guard OriginalGrandCanalLayoutCatalog
                            .HouseAccessPerimeterObjectCatalog
                            .ordinaryObjectPathDecision(forBuildingID: objectID) == true
                        else { return false }
                    }
                }
                let testedRaw = rawTerrain[testedY * width + testedX]
                return testedRaw & 0x40 != 0 && testedRaw & 0x04 == 0
            }
            guard perimeterIsResolved else { continue }

            let accessPoint = DeterministicMigration.recoveredHouseRoadAccessPoint(
                houseLocation: location,
                vacantBuildingID: vacantBuildingID,
                roadComponentRankByPoint: ranks
            )
            let retry = houses[index].originalHouseAccessRetryCount ?? 0
            let accessOutcome: DeterministicMigration.HouseAccessRefreshOutcome
            if let accessPoint {
                let floodIndex = accessPoint.y * width + accessPoint.x
                accessOutcome = DeterministicMigration.refreshHouseAccess(
                    .init(
                        candidateFound: true,
                        selectedAccessPoint: accessPoint,
                        floodDepth: flood.indices.contains(floodIndex)
                            ? flood[floodIndex]
                            : nil,
                        retryCount: retry,
                        houseType: vacantBuildingID,
                        houseField20: houses[index].residents
                    )
                )
            } else {
                accessOutcome = DeterministicMigration.refreshHouseAccess(
                    .init(
                        candidateFound: false,
                        retryCount: retry,
                        houseField20: houses[index].residents
                    )
                )
            }

            houses[index].setOriginalHouseAccess(
                value: accessOutcome.qualityDepth,
                point: accessOutcome.selectedAccessPoint,
                retryCount: accessOutcome.retryCount
            )

            guard let capacity = DeterministicMigration.originalCapacityRefresh(
                .init(
                    houseTypeID: vacantBuildingID,
                    houseLevelIndex: houses[index].houseLevelID,
                    houseResidents: houses[index].residents,
                    houseAccessValue: accessOutcome.qualityDepth,
                    cHouseInfoSettlingByte: houses[index].settlingLock,
                    previousHighWater: houses[index].originalCapacityHighWater ?? 0
                ),
                models: rules.models.buildings
            ) else { continue }
            houses[index].setOriginalRemainingCapacity(
                capacity.included ? capacity.remainingCapacity : 0
            )
            houses[index].setOriginalCapacityHighWater(capacity.highWater)
        }
    }

    private mutating func invalidateOriginalHouseAccessProjection() {
        for index in houses.indices {
            houses[index].setOriginalHouseAccess(value: nil, point: nil, retryCount: nil)
            houses[index].setOriginalRemainingCapacity(nil)
            houses[index].setOriginalCapacityHighWater(nil)
        }
    }

    /// Complete monument roots for the popularity term (§10.8): legacy
    /// projects, phased 77/84, palace 82, canal 83, and Great Wall layout
    /// roots whose sub-index-0 part is at its final phase.
    public var completeMonumentRootBuildingIDs: Set<Int> {
        var roots = aesthetics.completedMonumentBuildingIDs
        for project in aesthetics.phasedMonumentProjects where project.isComplete {
            roots.insert(project.buildingID)
        }
        if let palace = aesthetics.largePalaceProject, palace.isComplete {
            roots.insert(LargePalaceProjectRuntime.buildingID)
        }
        // Executable-confirmed per-kind phase counts: wall 11, tower 12,
        // gate 2, road 3; a root (sub-index 0) is complete at `count - 1`
        // (§10.8 / great-wall-map-state.md).
        let finalPhaseByKind: [OriginalGreatWallLayoutCatalog.SubBuildingKind: Int] = [
            .wall: 10, .tower: 11, .gate: 1, .road: 2,
        ]
        for part in aesthetics.greatWallMapPartStates
        where part.subBuildingIndex == 0 {
            if let kind = OriginalGreatWallLayoutCatalog.subBuildingKind(
                buildingID: part.buildingID,
                subBuildingIndex: 0
            ), let finalPhase = finalPhaseByKind[kind] {
                if part.currentSubBuildingPhase >= finalPhase {
                    roots.insert(part.buildingID)
                }
            }
        }
        return roots
    }

    /// Recovered `FUN_00590F30` food term (§3): mean of per-house scores
    /// (`+2` when raw quality ≥ required, else `−streak`), rounded
    /// away-from-zero only when `abs(remainder) > count/2`; a negative mean
    /// returns 0 while population < 350 and the city never exceeded 349.
    mutating func migrationFoodTerm(
        rules: EconomyRulesEngine,
        neverExceeded349: Bool
    ) -> Int {
        let population = self.population
        var sum = 0
        var count = 0
        // `FUN_00590F30` starts at vector index 1 and advances the live house
        // vector directly; it does not sort by the persisted object ID. Keep
        // the Native array order so the per-house streak mutation follows the
        // recovered traversal order (§10.44).
        for index in houses.indices {
            let house = houses[index]
            guard house.residents > 0,
                  let required = rules.models.buildings[houseLevelID: house.houseLevelID]?
                    .foodQualityRequired else { continue }
            if required == 0 {
                houses[index].resetFoodQualityStreak()
                continue
            }
            let satisfied = house.foodQualityRawValue >= required
            houses[index].recordFoodQualityScore(satisfied)
            if satisfied {
                sum += 2
            } else {
                sum -= max(1, houses[index].foodShortageStreak)
            }
            count += 1
        }
        guard count > 0 else { return 0 }
        let mean = sum / count
        let remainder = abs(sum % count)
        let rounded = remainder * 2 > count ? mean + (sum < 0 ? -1 : 1) : mean
        if rounded < 0, population < 350, !neverExceeded349 {
            return 0
        }
        return rounded
    }

    /// Recovered `FUN_00591200` popularity update (§2–§3). Runs on the two
    /// slice days (1 and 16) of each Native month.
    public mutating func updateMigrationPopularity(rules: EconomyRulesEngine) {
        let population = self.population
        var migration = migrationState ?? DeterministicMigrationState()
        if population > 349 {
            migration.setNeverExceeded349()
        }

        // Tax (coverage <= 10% forces the None row; the original integer
        // percentage must reach 11 before a tax sentiment row is selected).
        let taxedPopulation = houses
            .filter(\.hasTaxCoverage)
            .reduce(0) { $0 + $1.residents }
        let hasMeaningfulCoverage = DeterministicMigration
            .taxCoverageMeetsOriginalThreshold(
                taxedPopulation: taxedPopulation,
                population: population
            )
        var tax = rules.taxSentiment(
            bandID: taxBandID,
            difficulty: difficulty,
            hasMeaningfulCoverage: hasMeaningfulCoverage
        ) ?? 0
        var wage = DeterministicMigration.wageEffect(
            currentWage: migrationContext.normalAnnualWage
        )
        let workforce = workforceSnapshot(models: rules.models.buildings)
        let unemploymentPercent = workforce.availableWorkers > 0
            ? workforce.unemployedWorkers * 100 / workforce.availableWorkers
            : 0
        var employment = DeterministicMigration.employmentEffect(
            unemploymentPercent: unemploymentPercent
        )
        let suppressNegatives = population < 350 && !migration.neverExceeded349
        if suppressNegatives {
            if tax < 0 { tax = 0 }
            if wage < 0 { wage = 0 }
            if employment < 0 { employment = 0 }
        }

        var food = migrationFoodTerm(
            rules: rules,
            neverExceeded349: migration.neverExceeded349
        )
        if food < 0, suppressNegatives { food = 0 }
        let debt = DeterministicMigration.debtEffect(
            debtYears: migrationContext.consecutiveDebtMonths / 12,
            treasuryIsNegative: economy.treasury < 0
        )
        // `FUN_00591670` consumes the original object-vector `+0xA0` counts,
        // `+0x16` state, and a special-model predicate.  Native's
        // `fengShuiSummary` is a separate terrain-element presentation and
        // has no proven mapping to that input, so do not feed an inferred
        // harmony percentage into Qin's migration producer.
        let feng = 0
        let watchtowers = placedBuildings.filter { $0.buildingID == 127 }.count
        let repression = DeterministicMigration.repressionEffect(
            population: population,
            watchtowerCount: watchtowers
        )
        let monument = DeterministicMigration.monumentPopularityTerm(
            goalBuildingIDs: migrationContext.monumentGoalBuildingIDs,
            completeRootBuildingIDs: completeMonumentRootBuildingIDs
        )
        let producer = DeterministicMigration.originalPopularityProducerFactors(
            .init(
                currentPopularity: migration.popularity,
                taxFactor: tax,
                wageFactor: wage,
                employmentFactor: employment,
                foodFactor: food,
                debtFactor: debt,
                // The source doubles FUN_0055AE30's returned monument-pair
                // count inside FUN_00591200; this Native value is already the
                // resulting term from the source-backed catalog.
                monumentPairCount: monument / 2,
                fengShuiFactor: feng,
                repressionFactor: repression,
                // Festival factor 6 is not projected into campaign Native
                // state; keep its unresolved source input explicit as zero.
                factorSixForBlame: 0,
                previousFactorBlame: migration.factorBlame
            )
        )
        migration.setPopularity(producer.popularity)
        migration.setFactorBlame(producer.factorBlame)
        migrationState = migration
    }

    /// Recovered daily `FUN_004AD4A0` pressure/request/assignment pass
    /// (§4–§5). Departure requests are recorded but not yet dispatched
    /// (emigration walkers fail-closed, documented).
    public mutating func dailyMigrationAssignment(rules: EconomyRulesEngine) {
        var migration = migrationState ?? DeterministicMigrationState()
        migration.advanceImmigrantWaitGlobal()
        let population = self.population
        let pressurePass = DeterministicMigration.originalPressurePass(.init(
            popularity: migration.popularity,
            previousPressure: migration.pressure,
            population: population,
            warTroopCount: warCount,
            arrivalCooldown: migration.arrivalCooldown,
            departureCooldown: migration.departureCooldown
        ))
        migration.setPressure(pressurePass.pressure)
        migration.setArrivalRequest(pressurePass.arrivalRequest)
        migration.setDepartureRequest(pressurePass.departureRequest)
        migration.setArrivalCooldown(pressurePass.arrivalCooldown)
        migration.setDepartureCooldown(pressurePass.departureCooldown)

        migration.setAssignedToday(0)
        let batch = DeterministicMigration.originalDailyMigrationBatch(.init(
            arrivalRequest: migration.arrivalRequest,
            departureRequest: migration.departureRequest,
            arrivalPending: migration.pendingArrival,
            departurePending: migration.pendingDeparture
        ))
        if let arrivalAmount = batch.arrivalDispatchAmount {
            _ = assignImmigrantRequests(arrivalAmount, migration: &migration, rules: rules)
        }
        // The source calls `FUN_004ADC90` for this amount. That figure/route
        // writer remains unsupported in Native, but the pending-word result
        // is still source-defined and must not be replaced by accumulation.
        migration.setPendingArrival(batch.arrivalPending)
        migration.setPendingDeparture(batch.departurePending)
        migration.setArrivalRequest(0)
        migration.setDepartureRequest(0)
        migrationState = migration
    }

    /// Recovered `FUN_004ADA10` house walk (§5): spawns immigrant figures for
    /// up to `request` people across flood-reachable houses. Returns the
    /// unassigned remainder and updates the assignment accounting.
    @discardableResult
    mutating func assignImmigrantRequests(
        _ request: Int,
        migration: inout DeterministicMigrationState,
        rules: EconomyRulesEngine
    ) -> Int {
        guard request > 0 else { return 0 }
        guard let terrain, let entry = terrain.authoredPoints?.landEntry else {
            migration.setUnfulfilledArrivalCarry(
                migration.unfulfilledArrivalCarry + request
            )
            return request
        }
        let grids = (try? grandCanalWorkerRoutingGrids()) ?? .init(
            width: terrain.width,
            height: terrain.height,
            primaryPassability: [UInt16](repeating: 0, count: terrain.width * terrain.height),
            fallbackCellClass: [UInt32](repeating: 0, count: terrain.width * terrain.height)
        )
        let flood = DeterministicMigration.landEntryFloodDepths(
            width: grids.width,
            height: grids.height,
            primaryPassability: grids.primaryPassability,
            seed: entry
        )
        // Campaign-backed maps must use the recovered component-ranked
        // perimeter. Synthetic/core fixtures have no authored terrain layer,
        // so retain their explicit compatibility access rule without letting
        // it become a campaign fallback when the source inputs are missing.
        let roadComponentRankByPoint: [GridPoint: Int]?
        if missionSettingsState == nil {
            roadComponentRankByPoint = nil
        } else {
            guard let recovered = try? OriginalGrandCanalLayoutCatalog
                .workerRoadComponentRankByPoint(
                    width: grids.width,
                    height: grids.height,
                    terrainRawValues: terrain.terrainRawValues,
                    primaryPassability: grids.primaryPassability
                ) else {
                migration.setUnfulfilledArrivalCarry(
                    migration.unfulfilledArrivalCarry + request
                )
                return request
            }
            roadComponentRankByPoint = recovered
        }
        var remaining = request

        func remainingCapacity(of house: ResidentialUnit) -> Int {
            if let original = house.originalRemainingCapacity {
                return original
            }
            return DeterministicMigration.assignmentRemainingCapacity(
                houseLevelID: house.houseLevelID,
                vacantTypeID: house.vacantTypeID,
                residents: house.residents,
                footprintMultiplier: house.footprintMultiplier,
                settlingLock: house.settlingLock,
                models: rules.models.buildings
            )
        }

        func floodReachability(of house: ResidentialUnit) -> Bool {
            guard let location = house.location,
                  let access = {
                      let vacantBuildingID = house.vacantTypeID
                          ?? (house.houseLevelID == 10 ? 11 : 2)
                      if let roadComponentRankByPoint {
                          return DeterministicMigration.recoveredHouseRoadAccessPoint(
                              houseLocation: location,
                              vacantBuildingID: vacantBuildingID,
                              roadComponentRankByPoint: roadComponentRankByPoint
                          )
                      }
                      return DeterministicMigration.houseRoadAccessPoint(
                          houseLocation: location,
                          vacantBuildingID: vacantBuildingID,
                          roadNetwork: roadNetwork
                      )
                  }() else { return false }
            let index = access.y * grids.width + access.x
            return flood.indices.contains(index) && flood[index] != nil
        }

        // Pass 1: vacant houses (residents 0, remaining capacity > 0), chunks ≤ 6,
        // skipping houses with a live in-flight immigrant (the original
        // `FUN_004ADA10` links `house+0x32` and skips while the figure is
        // alive).
        for index in houses.indices {
            guard remaining > 0 else { break }
            let house = houses[index]
            let availableCapacity = remainingCapacity(of: house)
            guard floodReachability(of: house), house.residents == 0,
                  availableCapacity != 0,
                  !migration.immigrantWalkers.contains(where: { $0.houseID == house.id })
            else { continue }
            let count = min(remaining, 6)
            _ = spawnImmigrant(
                houseID: house.id,
                peopleCount: count,
                grids: grids,
                roadComponentRankByPoint: roadComponentRankByPoint,
                into: &migration
            )
            remaining -= count
        }
        // Pass 2: remaining capacity > 11 with no in-flight immigrant.
        for index in houses.indices {
            guard remaining > 0 else { break }
            let house = houses[index]
            let availableCapacity = remainingCapacity(of: house)
            guard floodReachability(of: house),
                  availableCapacity > 11,
                  !migration.immigrantWalkers.contains(where: { $0.houseID == house.id })
            else { continue }
            let count = min(remaining, 6)
            _ = spawnImmigrant(
                houseID: house.id,
                peopleCount: count,
                grids: grids,
                roadComponentRankByPoint: roadComponentRankByPoint,
                into: &migration
            )
            remaining -= count
        }
        // Pass 3: any remaining capacity with no in-flight immigrant.
        for index in houses.indices {
            guard remaining > 0 else { break }
            let house = houses[index]
            guard floodReachability(of: house),
                  !migration.immigrantWalkers.contains(where: { $0.houseID == house.id })
            else { continue }
            let availableCapacity = remainingCapacity(of: house)
            guard availableCapacity > 0 else { continue }
            let count = min(remaining, availableCapacity)
            _ = spawnImmigrant(
                houseID: house.id,
                peopleCount: count,
                grids: grids,
                roadComponentRankByPoint: roadComponentRankByPoint,
                into: &migration
            )
            remaining -= count
        }

        let assigned = request - remaining
        migration.setAssignedToday(migration.assignedToday + assigned)
        migration.addAssignedThisMonth(migration.assignedToday)
        if remaining == request, remaining > 0 {
            migration.setUnfulfilledArrivalCarry(
                migration.unfulfilledArrivalCarry + remaining
            )
        }
        return remaining
    }

    /// War count `DAT_01312564` (§10.7). The executable counts individual
    /// enemy figures created with models {58…62, 78}. Native stores one
    /// aggregate `EnemyMilitaryForce` per invasion and has no recovered
    /// figure-multiplicity or creation/death ledger, so a force's
    /// `soldierCount` must not be used as a guessed substitute. Keep the
    /// pressure suppression gate fail-closed until that mapping is recovered.
    public var warCount: Int {
        0
    }

    public mutating func setTaxCoverage(_ covered: Bool, houseID: Int) {
        guard let index = houses.firstIndex(where: { $0.id == houseID }) else { return }
        houses[index].hasTaxCoverage = covered
    }

    public mutating func setHouseLocation(_ location: GridPoint?, houseID: Int) {
        guard let index = houses.firstIndex(where: { $0.id == houseID }) else { return }
        houses[index].location = location
        houses[index].setOriginalHouseAccess(value: nil, point: nil, retryCount: nil)
        houses[index].setOriginalRemainingCapacity(nil)
        houses[index].setOriginalCapacityHighWater(nil)
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

    public func canConstructTradingBuilding(
        partnerID: Int,
        at origin: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> Bool {
        guard let partner = trade.partner(id: partnerID), partner.isOpen,
              !trade.buildings.contains(where: { $0.partnerID == partnerID }),
              isBuildingAvailableInCampaign(partner.routeKind.buildingID) else {
            return false
        }
        switch partner.routeKind {
        case .land:
            return preparedPlacement(
                category: .trading,
                buildingID: partner.routeKind.buildingID,
                at: origin,
                orientation: orientation
            ) != nil
        case .sea:
            return preparedQuayPlacement(
                buildingID: partner.routeKind.buildingID,
                at: origin,
                orientation: orientation
            ) != nil
        }
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
    public mutating func setMillPolicy(
        _ policy: WarehouseCommodityPolicy,
        millID: Int,
        commodityID: Int
    ) -> Bool {
        var logistics = logisticsState ?? DeterministicLogisticsState()
        guard logistics.mills.contains(where: { $0.id == millID }) else { return false }
        logistics.setMillPolicy(policy, commodityID: commodityID, millID: millID)
        logisticsState = logistics
        return true
    }

    @discardableResult
    public mutating func setMillStorageLimit(
        _ amount: Int,
        millID: Int,
        commodityID: Int
    ) -> Bool {
        var logistics = logisticsState ?? DeterministicLogisticsState()
        guard logistics.mills.contains(where: { $0.id == millID }) else { return false }
        logistics.setMillStorageLimit(amount, commodityID: commodityID, millID: millID)
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
        // IDs 83 and 85 use predetermined multipart map geometry. Their
        // worker scheduling and completion control flow remain incomplete;
        // never instantiate either legacy synthetic project for a new game.
        _ = buildingID
        return nil
    }

    public func canAdvanceGrandCanalSegment(at point: GridPoint) -> Bool {
        _ = point
        return false
    }

    @discardableResult
    public mutating func advanceGrandCanalSegment(at point: GridPoint) -> Int? {
        _ = point
        return nil
    }

    /// Advances one recovered original monument-scheduler call. Native daily
    /// ticks use the separately recovered 816-calls-per-month clock adapter;
    /// this operation remains available for exact boundary tests and research.
    @discardableResult
    public mutating func advanceGrandCanalSchedulerCall() throws
        -> OriginalGrandCanalLayoutCatalog.SchedulerCallOutcome {
        var state = aestheticState ?? DeterministicAestheticState()
        let outcome = try state.advanceGrandCanalSchedulerCall()
        aestheticState = state
        return outcome
    }

    private mutating func advanceGrandCanalPhaseTwoSimulationSteps(
        _ count: Int,
        state: inout DeterministicAestheticState,
        routingGrids: OriginalGrandCanalLayoutCatalog.WorkerRoutingGrids,
        targetAccesses: [OriginalGrandCanalLayoutCatalog.PhaseTwoTargetAccessCandidate]
    ) throws {
        typealias Catalog = OriginalGrandCanalLayoutCatalog
        var logistics = logisticsState ?? DeterministicLogisticsState()
        var production = self.production

        for _ in 0..<count {
            var parts = state.grandCanalMapPartStates
            var coordinator = state.grandCanalPhaseTwoCoordinator
            var convoys = state.grandCanalPhaseTwoConvoys
            let existingCarrierIDs = convoys.map(\.carrierFigureID)

            for carrierID in existingCarrierIDs {
                guard let index = convoys.firstIndex(where: {
                    $0.carrierFigureID == carrierID
                }) else { continue }
                switch convoys[index].carrierState {
                case .travelingToMonument, .returningWithCargo,
                        .returningToAlternateSource, .returningEmpty:
                    _ = convoys[index].advanceMovement(routingGrids: routingGrids)
                case .allocatingAtMonument:
                    if let allocation = convoys[index].allocateAtMonument(
                        currentPoint: convoys[index].currentPoint,
                        pendingRequests: &coordinator.carrierBoundRequests
                    ) {
                        for delivery in allocation.deliveries {
                            guard let partIndex = parts.firstIndex(where: {
                                $0.subBuildingIndex == delivery.requestID
                            }) else { continue }
                            _ = parts[partIndex].acceptPhaseTwoStoneCargo(
                                delivery.deliveredUnits
                            )
                        }
                    }
                case .restoringCargoAtSource, .emptyArrivalCleanup:
                    if case let .sourceTransferDue(cargoUnits)? =
                        convoys[index].advanceAtSource() {
                        let accepted = logistics.returnStoredGoods(
                            warehouseID: convoys[index].sourceObjectID,
                            commodityID: convoys[index].commodityID,
                            amount: cargoUnits,
                            production: &production
                        )
                        _ = convoys[index].recordSourceTransfer(
                            acceptedUnits: accepted,
                            nextProvider: nil
                        )
                    }
                case .routeFallback:
                    _ = convoys[index].advanceRouteFallback(nextProvider: nil)
                }
                convoys[index].advanceAnimationAndFollowers()
                convoys[index].updateHelperLiveness()
            }
            convoys.removeAll {
                !$0.isCarrierActive && $0.helpers.allSatisfy { !$0.isActive }
            }
            state.restoreGrandCanalMapPartStatesPreservingRuntime(parts)
            state.restoreGrandCanalPhaseTwoCoordinator(coordinator)
            state.restoreGrandCanalPhaseTwoConvoys(convoys)

            let outcome = try state.advanceGrandCanalSchedulerCall()
            guard case .maintainedPhaseTwoMaterialRequests = outcome else { continue }
            coordinator = state.grandCanalPhaseTwoCoordinator
            guard let first = coordinator.pendingRequests.first(where: {
                $0.remainingUnits > 0
            }) else { continue }
            let sameCommodityUnits = coordinator.pendingRequests.compactMap {
                $0.commodityID == first.commodityID ? $0.remainingUnits : nil
            }
            guard let requestedUnits = Catalog.nextPhaseTwoSourceRequest(
                sameCommodityPendingUnits: sameCommodityUnits
            ) else { continue }

            let warehouseByID = Dictionary(uniqueKeysWithValues:
                logistics.warehouses.map { ($0.id, $0) }
            )
            let warehouses = placedBuildings.compactMap { placement -> StorageWarehouse? in
                guard placement.category == .warehouse,
                      let warehouse = warehouseByID[placement.instanceID],
                      Catalog.isEligiblePhaseTwoMaterialSource(
                        .init(
                            objectID: warehouse.id,
                            buildingID: warehouse.buildingID,
                            isActive: true,
                            availableStoneUnits: warehouse.inventoryByCommodityID[
                                Catalog.phaseTwoStoneCommodityID,
                                default: 0
                            ]
                        ),
                        requestingObjectID: Int.min,
                        requestedUnits: requestedUnits
                      ) else { return nil }
                return warehouse
            }
            guard !warehouses.isEmpty else { continue }

            let orderedTargets = Catalog.orderedPhaseTwoTargetAccesses(
                requestingSubBuildingOrigin: first.targetPoint,
                authoredAccessibleCandidates: targetAccesses
            )
            var selection: (source: StorageWarehouse,
                            target: Catalog.PhaseTwoTargetAccessCandidate,
                            route: Catalog.WorkerRoute)?
            for target in orderedTargets {
                guard let sourceIndex = Catalog.phaseTwoSourceCandidateIndex(
                    primaryValues: routingGrids.primaryPassability,
                    width: routingGrids.width,
                    height: routingGrids.height,
                    from: target.roadAccessPoint,
                    orderedCandidatePoints: warehouses.map(\.roadAccessPoint)
                ) else { continue }
                let source = warehouses[sourceIndex]
                guard let route = Catalog.phaseTwoCarrierRoute(
                    primaryValues: routingGrids.primaryPassability,
                    width: routingGrids.width,
                    height: routingGrids.height,
                    from: source.roadAccessPoint,
                    to: target.roadAccessPoint
                ) else { continue }
                selection = (source, target, route)
                break
            }
            guard let selection else { continue }

            let cargo = logistics.takeStoredGoods(
                warehouseID: selection.source.id,
                commodityID: first.commodityID,
                amount: requestedUnits,
                production: &production
            )
            guard cargo == requestedUnits,
                  let batch = coordinator.dispatchNextBatch(carrierCreated: true)
            else { continue }
            let ids = coordinator.reserveConvoyFigureIDs()
            var convoy = Catalog.PhaseTwoCarrierConvoyRuntime(
                carrierFigureID: ids.0,
                firstHelperFigureID: ids.1,
                secondHelperFigureID: ids.2,
                sourceObjectID: selection.source.id,
                sourceBuildingID: selection.source.buildingID,
                commodityID: batch.commodityID,
                sourceOrigin: selection.source.roadAccessPoint,
                monumentObjectID: selection.target.subBuildingIndex,
                monumentAccessPoint: selection.target.roadAccessPoint,
                cargoUnits: cargo
            )
            convoy.movement = .init(route: selection.route)
            convoys = state.grandCanalPhaseTwoConvoys
            convoys.append(convoy)
            state.restoreGrandCanalPhaseTwoCoordinator(coordinator)
            state.restoreGrandCanalPhaseTwoConvoys(convoys)
        }
        logisticsState = logistics
        self.production = production
    }

    private mutating func advanceRecoveredGrandCanalSchedulerCalls(
        _ count: Int,
        models: BuildingModelTable
    ) {
        guard count > 0, !(aestheticState?.grandCanalMapPartStates.isEmpty ?? true) else {
            return
        }
        var state = aestheticState ?? DeterministicAestheticState()
        do {
            let wholePhases = Set(state.grandCanalMapPartStates.map(\.wholeMonumentPhase))
            if wholePhases == [0] || wholePhases == [1] {
                let routingGrids = try grandCanalWorkerRoutingGrids()
                let targetAccesses = try grandCanalPhaseLaborTargetAccesses(
                    routingGrids: routingGrids
                )
                for _ in 0..<count {
                    let providers = grandCanalPhaseLaborProviders(
                        models: models,
                        coordinator: state.grandCanalPhaseLaborCoordinator
                    )
                    _ = try state.advanceGrandCanalPhaseLaborSimulationStep(
                        providers: providers,
                        targetAccesses: targetAccesses,
                        routingGrids: routingGrids,
                        xiWangMuActive: false
                    )
                }
            } else if wholePhases == [2] {
                let routingGrids = try grandCanalWorkerRoutingGrids()
                let targetAccesses = try grandCanalPhaseTwoTargetAccesses(
                    routingGrids: routingGrids
                )
                try advanceGrandCanalPhaseTwoSimulationSteps(
                    count,
                    state: &state,
                    routingGrids: routingGrids,
                    targetAccesses: targetAccesses
                )
            } else {
                _ = try state.advanceGrandCanalSchedulerCalls(count)
            }
            aestheticState = state
        } catch is OriginalGrandCanalLayoutCatalog.WorkerRoutingCacheDerivationError {
            // A city containing an occupancy branch whose original +0xCC
            // predicate has not yet been recovered is outside the live bridge's
            // supported contract. Leave this batch wholly unchanged instead of
            // inventing a passability class or crashing the surrounding city
            // simulation; the explicit routing API still exposes the error to
            // research callers and tests.
            return
        } catch {
            // Unsupported archive phases remain unchanged. Keeping the mutation
            // atomic prevents a malformed save from partially advancing its
            // monument state while retaining a debug signal for schema errors.
            assertionFailure("Unsupported Grand Canal scheduler state: \(error)")
        }
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
            roadNetwork: roadNetwork,
            barrierPoints: roadblockPoints,
            startsDormant: true,
            providerBuildingID: buildingID
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
            roadNetwork: roadNetwork,
            barrierPoints: roadblockPoints
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
        let inserted = roadNetwork.insert(newPoints)
        if inserted != nil {
            invalidateOriginalHouseAccessProjection()
        }
        return inserted
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
        updated.invalidateOriginalHouseAccessProjection()
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
            maximumRoadSteps: maximumRoadSteps,
            barrierPoints: roadblockPoints
        )
        for index in houses.indices {
            if coveredIDs.contains(houses[index].id) {
                houses[index].applyOriginalServiceVisit(.tax)
            } else {
                houses[index].clearOriginalTaxCoverage()
            }
        }
        return coveredIDs.count
    }

    private mutating func applyServiceCoverage(
        _ movement: WalkerMovementSummary,
        resetExisting: Bool
    ) {
        if resetExisting {
            for index in houses.indices {
                houses[index].clearOriginalTaxCoverage()
                houses[index].resetOriginalServiceCoverage()
            }
        }
        for index in houses.indices {
            let houseID = houses[index].id
            for (service, coveredIDs) in movement.servicedHouseIDsByService where
                coveredIDs.contains(houseID) {
                houses[index].applyOriginalServiceVisit(service)
            }
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

    private func serviceWorkerPercentByWalkerID(
        workforce: WorkforceMonthlySettlement?
    ) -> [Int: Int] {
        guard let workforce else {
            return Dictionary(uniqueKeysWithValues: residentialServiceBuildings.map { ($0.walkerID, 100) })
        }
        let assignments = Dictionary(uniqueKeysWithValues: workforce.assignments.map { ($0.key, $0) })
        return Dictionary(uniqueKeysWithValues: residentialServiceBuildings.map { building in
            let key = OperationalBuildingKey(category: .residentialService, instanceID: building.id)
            guard let assignment = assignments[key], assignment.requiredWorkers > 0 else {
                return (building.walkerID, 0)
            }
            return (
                building.walkerID,
                min(100, max(0, assignment.assignedWorkers * 100 / assignment.requiredWorkers))
            )
        })
    }

    private func marketWorkerPercentByID(
        workforce: WorkforceMonthlySettlement?
    ) -> [Int: Int] {
        guard let workforce else { return [:] }
        let assignments = Dictionary(uniqueKeysWithValues: workforce.assignments.map { ($0.key, $0) })
        return Dictionary(uniqueKeysWithValues: placedBuildings.compactMap { placement in
            guard placement.category == .market else { return nil }
            let key = OperationalBuildingKey(
                category: .market,
                instanceID: placement.instanceID
            )
            guard let assignment = assignments[key], assignment.requiredWorkers > 0 else {
                return (placement.instanceID, 0)
            }
            return (
                placement.instanceID,
                min(100, max(0, assignment.assignedWorkers * 100 / assignment.requiredWorkers))
            )
        })
    }

    private func activeMarketInstanceIDs(
        workforce: WorkforceMonthlySettlement?
    ) -> Set<Int>? {
        guard let workforce else { return nil }
        return Set(workforce.assignments.compactMap {
            guard $0.key.category == .market, $0.assignedWorkers > 0 else { return nil }
            return $0.key.instanceID
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

        // Original daily `FUN_005185C0` settling-lock walk (§10.6): runs in
        // the calendar before the migration/assignment case.
        for index in houses.indices {
            houses[index].advanceSettlingLock()
        }

        // Calendar cases 0x15/0x16 refresh the source flood/access and
        // capacity words before case 0x17 assignment. The Native projection
        // is gated to complete, ferry-free campaign inputs.
        refreshOriginalHouseAccessAndCapacity(rules: rules)

        // Advance live immigrant figures by today's original-step budget and
        // apply arrivals (§5.3). Walkers only exist when the producer is
        // enabled or a fixture explicitly spawns one.
        var migrationBefore = migrationState ?? DeterministicMigrationState()
        let arrivals = migrationBefore.advanceImmigrantWalkers(
            originalStepsInDay: DeterministicMigration.originalStepsInDay(clock.day)
        )
        for arrival in arrivals {
            applyImmigrantArrival(arrival, models: rules.models.buildings)
        }
        if !arrivals.isEmpty {
            migrationBefore.recordArrivals(
                count: arrivals.reduce(0) { $0 + $1.peopleCount }
            )
        }
        let migrated = arrivals.reduce(0) { $0 + $1.peopleCount }
        migrationState = migrationBefore

        let assessment = DeterministicMigration.observeHousing(
            houses: houses,
            roadNetwork: roadNetwork,
            models: rules.models.buildings
        )
        if migrationBefore.automaticMigrationAvailability == .supportedOriginalProducer {
            // Popularity update on the two original slice days (1 and 16) of
            // the Native month (§2), then the daily pressure/request/
            // assignment pass (case 0x17, §4–§5).
            if clock.day == 1 || clock.day == 16 {
                updateMigrationPopularity(rules: rules)
            }
            dailyMigrationAssignment(rules: rules)
        } else {
            var migration = migrationState ?? DeterministicMigrationState()
            migration.recordUnsupportedDay(assessment: assessment)
            migrationState = migration
        }

        let activeWorkforce: WorkforceMonthlySettlement?
        if workforceEnabled {
            let workforce = workforceSnapshot(models: rules.models.buildings)
            applyWorkforce(workforce, models: rules.models.buildings)
            activeWorkforce = workforce
        } else {
            activeWorkforce = nil
        }

        var state = walkerState ?? DeterministicWalkerState()
        let originalWalkerSteps = DeterministicMigration.originalStepsInDay(clock.day)
        let primaryReturnPassability = state.requiresOriginalReturnPassability(
            withinOriginalSteps: originalWalkerSteps
        ) ? (try? grandCanalWorkerRoutingGrids().primaryPassability) : nil
        let walkerMovement = state.advanceRecoveredOriginalSteps(
            originalWalkerSteps,
            houses: &houses,
            roadNetwork: roadNetwork,
            workerPercentByWalkerID: serviceWorkerPercentByWalkerID(
                workforce: activeWorkforce
            ),
            primaryReturnPassability: primaryReturnPassability,
            coverageBlockerPoints: OriginalResidentialServiceCoverage.blockerPoints(
                placements: placedBuildings
            ),
            barrierPoints: roadblockPoints
        )
        accumulatedCoverage.merge(walkerMovement)
        walkerState = state

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
            logisticsMovement = logistics.advanceOriginalDeliveries(
                originalStepsPerWalker: originalWalkerSteps,
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
            let activeMarketIDs = activeMarketInstanceIDs(workforce: activeWorkforce)
            let buyerRange = max(
                1,
                rules.models.figures[figureID: OriginalMarketCatalog.buyerFigureID]?.behaviorRange ?? 50
            )
            let peddlerRange = max(
                1,
                rules.models.figures[figureID: OriginalMarketCatalog.peddlerFigureID]?.behaviorRange ?? 60
            )
            var purchased: [DeliveryCargo] = []
            if missionSettingsState == nil {
                // The original model-24 buyer seam is recovered only through
                // its scheduler/figure boundary. Qin's provider-record,
                // map-object, route, and household settlement projections are
                // still unresolved, so a campaign must not substitute the
                // Native warehouse-targeting buyer path.
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
                purchased = market.advanceOriginalBuyers(
                    // Marketplace buyers use authored speed selector 8. One
                    // Native day contributes the same original figure-update
                    // budget as the recovered service clock; route points are
                    // crossed by the buyer's persisted 1/1/2 substep cadence.
                    originalFigureUpdatesPerBuyer: originalWalkerSteps,
                    activeMarketIDs: activeMarketIDs
                )
            }
            var delivered: [HouseholdCommodityDelivery] = []
            if missionSettingsState == nil {
                // The campaign cMarket/provider record, model-23 route, and
                // household quality/coverage projection remain unresolved.
                // Do not advance or mutate peddler state in a campaign from
                // Native staffing or compatibility routes; sandbox fixtures
                // may still exercise the recovered timing seam explicitly.
                var workerPercentByMarketID = marketWorkerPercentByID(
                    workforce: activeWorkforce
                )
                // Legacy/unscoped fixtures predate the unresolved raw cStall
                // provider input. Preserve their explicit compatibility
                // behavior without making the production scheduler invent a
                // value when called directly.
                for market in market.markets
                where workerPercentByMarketID[market.id] == nil {
                    workerPercentByMarketID[market.id] = 100
                }
                market.advanceOriginalPeddlerSpawnScheduler(
                    originalSteps: originalWalkerSteps,
                    houses: houses,
                    roadNetwork: roadNetwork,
                    models: rules.models.buildings,
                    maximumRoadSteps: peddlerRange,
                    replaySeed: 0x4D41_524B_4554
                        ^ UInt64(bitPattern: Int64(calendar.year * 12 + calendar.month)),
                    activeMarketIDs: activeMarketIDs,
                    workerPercentByMarketID: workerPercentByMarketID,
                    barrierPoints: roadblockPoints,
                    allowCompatibilityRouteFallback: true
                )
                delivered = market.advanceOriginalPeddlers(
                    // Peddler model 23 uses authored selector 8. The Native
                    // day contributes the same original figure-update budget
                    // as the recovered service clock; route points advance
                    // through the persisted 1/1/2 substep cadence.
                    originalFigureUpdatesPerPeddler: originalWalkerSteps,
                    houses: &houses,
                    models: rules.models.buildings,
                    activeMarketIDs: activeMarketIDs,
                    barrierPoints: roadblockPoints,
                    coverageBlockerPoints: OriginalResidentialServiceCoverage.blockerPoints(
                        placements: placedBuildings
                    )
                )
            }
            marketMovement = MarketTickMovementSummary(
                purchasedLoads: purchased,
                householdDeliveries: delivered
            )
            marketState = market
            logisticsState = logistics
        }

        let schedulerCalls = OriginalGrandCanalLayoutCatalog.schedulerCalls(
            forNativeDay: clock.day
        )
        let callsAfterMonthBoundary = clock.day == SimulationClockState.daysPerMonth ? 1 : 0
        advanceRecoveredGrandCanalSchedulerCalls(
            schedulerCalls - callsAfterMonthBoundary,
            models: rules.models.buildings
        )

        let clockAdvance = clock.advanceOneDay()
        simulationClockState = clock
        monthlyServiceCoverageState = accumulatedCoverage
        let settlement = clockAdvance.didEndMonth ? settleMonth(rules: rules) : nil
        // In the original `FUN_005371A0`, the final monthly call reaches
        // `FUN_004AC2B0/0x4AC650` before the same step reaches `0x564B50`.
        // Preserve that ordering so a just-completed monument cannot satisfy
        // the month-boundary goal check one original step too early.
        advanceRecoveredGrandCanalSchedulerCalls(
            callsAfterMonthBoundary,
            models: rules.models.buildings
        )
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
        let hasMeaningfulCoverage = DeterministicMigration
            .taxCoverageMeetsOriginalThreshold(
                taxedPopulation: taxedPopulation,
                population: population
            )
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
        // The recovered market corpus closes only raw cMarket record
        // arithmetic and the month-depletion walk; it does not close the
        // provider-record → Native inventory/quality/coverage mapping.  A
        // campaign-backed Qin city must therefore leave household market
        // settlement untouched.  The legacy branch remains available for
        // unscoped sandbox/fixture cities (missionSettingsState == nil).
        if var market = marketState, missionSettingsState == nil {
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
            endingTreasury: economy.treasury,
            completedMonumentBuildingIDsAtBoundary: aesthetics.completedMonumentBuildingIDs
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
