import Foundation

public struct OperationalBuildingKey: Sendable, Hashable, Codable {
    public let category: PlacedBuildingCategory
    public let instanceID: Int

    public init(category: PlacedBuildingCategory, instanceID: Int) {
        self.category = category
        self.instanceID = instanceID
    }
}

public struct WorkforceAssignment: Sendable, Hashable, Codable {
    public let key: OperationalBuildingKey
    public let buildingID: Int
    public let requiredWorkers: Int
    public let assignedWorkers: Int

    public var isFullyStaffed: Bool { assignedWorkers >= requiredWorkers }
}

public struct WorkforceMonthlySettlement: Sendable, Hashable, Codable {
    public let availableWorkers: Int
    public let requiredWorkers: Int
    public let assignedWorkers: Int
    public let assignments: [WorkforceAssignment]

    public var unemployedWorkers: Int { max(0, availableWorkers - assignedWorkers) }
    public var workerShortage: Int { max(0, requiredWorkers - assignedWorkers) }
}

public struct BuildingRiskRecord: Sendable, Hashable, Codable {
    public let key: OperationalBuildingKey
    public let buildingID: Int
    public let location: GridPoint
    public var fireRisk: Int
    public var damageRisk: Int
    public var lastInspectedYear: Int?
    public var lastInspectedMonth: Int?
}

public enum BuildingFailureKind: String, Sendable, Hashable, Codable {
    case fire
    case collapse
}

public enum BuildingFailureCause: String, Sendable, Hashable, Codable {
    case maintenance
    case disaster
    /// Save compatibility for the removed breach-level batch-fire prototype.
    /// New combat code must create failures from a concrete unit attack.
    case invasion
}

public struct BuildingFailure: Sendable, Hashable, Codable {
    public let key: OperationalBuildingKey
    public let buildingID: Int
    public let location: GridPoint
    public let kind: BuildingFailureKind
    /// Optional so saves written before failure causes were recorded continue
    /// to decode; `nil` is interpreted as ordinary maintenance failure.
    public let cause: BuildingFailureCause?

    public init(
        key: OperationalBuildingKey,
        buildingID: Int,
        location: GridPoint,
        kind: BuildingFailureKind,
        cause: BuildingFailureCause? = .maintenance
    ) {
        self.key = key
        self.buildingID = buildingID
        self.location = location
        self.kind = kind
        self.cause = cause
    }
}

public struct CityOperationsMonthlySettlement: Sendable, Hashable, Codable {
    public let year: Int
    public let month: Int
    public let workforce: WorkforceMonthlySettlement
    public let inspectedBuildingKeys: Set<OperationalBuildingKey>
    public let repairedRiskByBuildingKey: [OperationalBuildingKey: Int]
    public let failures: [BuildingFailure]
}

/// Building-hazard constants read from the shipping
/// `Model/GeneralBuildingConfig.txt` file.
///
/// The original model separates routine risk from structural integrity:
/// `BurnLimit` and `DamageLimit` trigger maintenance failures, while a
/// building's structural-integrity field is reserved for physical damage.
public struct OriginalBuildingHazardRules: Sendable, Hashable {
    public let fireRiskMultiplier: Int
    public let fireCheckFrequency: Int
    public let fireRiskLimit: Int
    public let burnDamage: Int
    public let fireDamageMultiplier: Int
    public let collapseRiskLimit: Int

    public init(configuration: LegacyINI) {
        fireRiskMultiplier = max(
            1,
            configuration.integer(section: "Fire", key: "Multiplier") ?? 5
        )
        fireCheckFrequency = max(
            1,
            configuration.integer(section: "Fire", key: "Frequency") ?? 4
        )
        fireRiskLimit = max(
            1,
            configuration.integer(section: "Fire", key: "BurnLimit") ?? 1_000
        )
        burnDamage = max(
            1,
            configuration.integer(section: "Fire", key: "BurnDamage") ?? 100
        )
        fireDamageMultiplier = max(
            1,
            configuration.integer(section: "Fire", key: "FireDamageMult") ?? 10
        )
        collapseRiskLimit = max(
            1,
            configuration.integer(section: "Damage", key: "DamageLimit") ?? 1_000
        )
    }
}

/// Deterministic labor and building-maintenance state backed by the original
/// model table's employee, risk, reducer, and structural-integrity fields.
public struct DeterministicCityOperationsState: Sendable, Hashable, Codable {
    public private(set) var risks: [BuildingRiskRecord]
    public private(set) var lastSettlement: CityOperationsMonthlySettlement?

    public init() {
        risks = []
        lastSettlement = nil
    }

    public func workforce(
        population: Int,
        placements: [PlacedBuilding],
        models: BuildingModelTable,
        requiredWorkersByKey: [OperationalBuildingKey: Int] = [:]
    ) -> WorkforceMonthlySettlement {
        var remaining = max(0, population)
        var assignments: [WorkforceAssignment] = []
        let ordered = placements.filter {
            $0.category != .agriculturalPlot
                && $0.category != .residential
                && $0.buildingID != OriginalBuildingSpriteCatalog.ruinBuildingID
        }.sorted {
            let lhsRank = Self.workforcePriority($0.category)
            let rhsRank = Self.workforcePriority($1.category)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if $0.buildingID != $1.buildingID { return $0.buildingID < $1.buildingID }
            return $0.instanceID < $1.instanceID
        }
        for placement in ordered {
            let key = OperationalBuildingKey(
                category: placement.category,
                instanceID: placement.instanceID
            )
            let required = max(
                0,
                requiredWorkersByKey[key]
                    ?? models[buildingID: placement.buildingID]?.employees
                    ?? 0
            )
            let assigned = min(required, remaining)
            remaining -= assigned
            assignments.append(WorkforceAssignment(
                key: key,
                buildingID: placement.buildingID,
                requiredWorkers: required,
                assignedWorkers: assigned
            ))
        }
        return WorkforceMonthlySettlement(
            availableWorkers: max(0, population),
            requiredWorkers: assignments.reduce(0) { $0 + $1.requiredWorkers },
            assignedWorkers: assignments.reduce(0) { $0 + $1.assignedWorkers },
            assignments: assignments
        )
    }

    @discardableResult
    public mutating func advanceMonth(
        calendar: SimulationCalendar,
        workforce: WorkforceMonthlySettlement,
        placements: [PlacedBuilding],
        inspectedBuildingKeys: Set<OperationalBuildingKey>,
        maintenanceRiskReduction: Int,
        models: BuildingModelTable,
        difficulty: GameDifficulty,
        hazardRules: OriginalBuildingHazardRules
    ) -> CityOperationsMonthlySettlement {
        let operationalPlacements = placements.filter { placement in
            guard placement.category != .agriculturalPlot,
                  placement.buildingID != OriginalBuildingSpriteCatalog.ruinBuildingID,
                  let model = models[buildingID: placement.buildingID]
            else { return false }
            // The original manual lists whole ministries as inspection-proof.
            // Their shipping model rows carry zero fire and damage increments;
            // the Fishing Quay and Weaponsmith are the documented exceptions
            // and both have non-zero increments.
            return model.fireRiskIncrement > 0 || model.damageRiskIncrement > 0
        }
        let placementKeys = Set(operationalPlacements.map {
            OperationalBuildingKey(category: $0.category, instanceID: $0.instanceID)
        })
        risks.removeAll { !placementKeys.contains($0.key) }
        for placement in operationalPlacements where !risks.contains(where: {
            $0.key == OperationalBuildingKey(category: placement.category, instanceID: placement.instanceID)
        }) {
            risks.append(BuildingRiskRecord(
                key: OperationalBuildingKey(category: placement.category, instanceID: placement.instanceID),
                buildingID: placement.buildingID,
                location: placement.markerPoint,
                fireRisk: 0,
                damageRisk: 0
            ))
        }

        var repairs: [OperationalBuildingKey: Int] = [:]
        var failures: [BuildingFailure] = []
        for index in risks.indices.sorted(by: { lhs, rhs in
            let left = risks[lhs].key, right = risks[rhs].key
            if left.category.rawValue != right.category.rawValue {
                return left.category.rawValue < right.category.rawValue
            }
            return left.instanceID < right.instanceID
        }) {
            guard let model = models[buildingID: risks[index].buildingID] else { continue }
            let fireDelta = Self.difficultyAdjustedRisk(
                max(0, model.fireRiskIncrement),
                fieldIndex: 6,
                difficulty: difficulty,
                models: models
            )
            let collapseDelta = Self.difficultyAdjustedRisk(
                max(0, model.damageRiskIncrement),
                fieldIndex: 7,
                difficulty: difficulty,
                models: models
            )
            // Emperor[EN].exe (0x42d9a0/0x42a3f9) first chooses one global
            // slot modulo Frequency. A building is updated only when its stable
            // map/instance slot matches, then adds a random factor in 1...Multiplier.
            // Native uses a replay-stable mixer instead of the original global
            // C RNG so save replays remain deterministic.
            if fireDelta == 0 {
                risks[index].fireRisk = 0
            } else if Self.fireCheckSlot(
                for: risks[index],
                frequency: hazardRules.fireCheckFrequency
            ) == Self.selectedFireCheckSlot(
                calendar: calendar,
                frequency: hazardRules.fireCheckFrequency
            ) {
                let multiplier = Self.fireRiskMultiplier(
                    for: risks[index],
                    calendar: calendar,
                    upperBound: hazardRules.fireRiskMultiplier
                )
                risks[index].fireRisk += fireDelta * multiplier
            }
            risks[index].damageRisk += collapseDelta

            if inspectedBuildingKeys.contains(risks[index].key) {
                let before = risks[index].fireRisk + risks[index].damageRisk
                risks[index].fireRisk = max(0, risks[index].fireRisk - max(0, maintenanceRiskReduction))
                risks[index].damageRisk = max(0, risks[index].damageRisk - max(0, maintenanceRiskReduction))
                repairs[risks[index].key] = before - risks[index].fireRisk - risks[index].damageRisk
                risks[index].lastInspectedYear = calendar.year
                risks[index].lastInspectedMonth = calendar.month
            }

            let failureKind: BuildingFailureKind?
            // The executable checks structural damage first and branches when
            // risk is no longer below the configured limit (that is, >=).
            if risks[index].damageRisk >= hazardRules.collapseRiskLimit {
                failureKind = .collapse
            } else if risks[index].fireRisk >= hazardRules.fireRiskLimit {
                failureKind = .fire
            } else {
                failureKind = nil
            }
            if let failureKind {
                failures.append(BuildingFailure(
                    key: risks[index].key,
                    buildingID: risks[index].buildingID,
                    location: risks[index].location,
                    kind: failureKind
                ))
            }
        }
        let failedKeys = Set(failures.map(\.key))
        risks.removeAll { failedKeys.contains($0.key) }
        let settlement = CityOperationsMonthlySettlement(
            year: calendar.year,
            month: calendar.month,
            workforce: workforce,
            inspectedBuildingKeys: inspectedBuildingKeys,
            repairedRiskByBuildingKey: repairs,
            failures: failures
        )
        lastSettlement = settlement
        return settlement
    }

    private static func difficultyAdjustedRisk(
        _ risk: Int,
        fieldIndex: Int,
        difficulty: GameDifficulty,
        models: BuildingModelTable
    ) -> Int {
        let modifier = models.difficultyModifiers.first {
            $0.id == difficulty.rawValue
        }
        let percentage = modifier.map {
            $0.values.indices.contains(fieldIndex) ? $0.values[fieldIndex] : 100
        } ?? 100
        return risk * percentage / 100
    }

    private static func fireCheckSlot(
        for record: BuildingRiskRecord,
        frequency: Int
    ) -> Int {
        guard frequency > 1 else { return 0 }
        var seed = UInt64(bitPattern: Int64(record.buildingID))
        seed ^= UInt64(bitPattern: Int64(record.key.instanceID)) &* 0x9E37_79B9_7F4A_7C15
        seed ^= UInt64(bitPattern: Int64(record.location.x)) &* 0xBF58_476D_1CE4_E5B9
        seed ^= UInt64(bitPattern: Int64(record.location.y)) &* 0x94D0_49BB_1331_11EB
        return Int(mix(seed) % UInt64(frequency))
    }

    private static func selectedFireCheckSlot(
        calendar: SimulationCalendar,
        frequency: Int
    ) -> Int {
        guard frequency > 1 else { return 0 }
        var seed = UInt64(bitPattern: Int64(calendar.year))
        seed ^= UInt64(bitPattern: Int64(calendar.month)) &* 0xD6E8_FEB8_6659_FD93
        return Int(mix(seed ^ 0xA076_1D64_78BD_642F) % UInt64(frequency))
    }

    private static func fireRiskMultiplier(
        for record: BuildingRiskRecord,
        calendar: SimulationCalendar,
        upperBound: Int
    ) -> Int {
        guard upperBound > 1 else { return 1 }
        var seed = UInt64(bitPattern: Int64(record.key.instanceID))
        seed ^= UInt64(bitPattern: Int64(record.buildingID)) &* 0xE703_7ED1_A0B4_28DB
        seed ^= UInt64(bitPattern: Int64(calendar.year)) &* 0x8EBC_6AF0_9C88_C6E3
        seed ^= UInt64(bitPattern: Int64(calendar.month)) &* 0x5899_65CC_7537_4CC3
        return Int(mix(seed ^ 0x1D8E_4E27_C47D_124F) % UInt64(upperBound)) + 1
    }

    private static func mix(_ input: UInt64) -> UInt64 {
        var value = input
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    private static func workforcePriority(_ category: PlacedBuildingCategory) -> Int {
        switch category {
        case .residential, .residentialService: 0
        // Distribution buildings must remain staffed during a shortage or
        // every producer can be full while no food or goods ever reach homes.
        // Producers support partial staffing; storage, markets and trade do
        // not, so give the authored distribution chain first claim.
        case .warehouse: 1
        case .mill: 2
        case .market: 3
        case .trading: 4
        case .production: 5
        case .military: 6
        case .aesthetic: 7
        case .agriculturalPlot: 8
        }
    }

    /// Records a failure produced by a concrete external system (for example,
    /// a future per-unit building attack or an authored natural disaster).
    public mutating func recordExternalFailures(
        calendar: SimulationCalendar,
        failures newFailures: [BuildingFailure]
    ) {
        guard !newFailures.isEmpty else { return }
        let failedKeys = Set(newFailures.map(\.key))
        risks.removeAll { failedKeys.contains($0.key) }

        let existing = lastSettlement
        let workforce = existing?.workforce ?? WorkforceMonthlySettlement(
            availableWorkers: 0,
            requiredWorkers: 0,
            assignedWorkers: 0,
            assignments: []
        )
        var failures = existing?.failures ?? []
        for failure in newFailures where !failures.contains(where: {
            $0.key == failure.key && $0.kind == failure.kind
        }) {
            failures.append(failure)
        }
        lastSettlement = CityOperationsMonthlySettlement(
            year: calendar.year,
            month: calendar.month,
            workforce: workforce,
            inspectedBuildingKeys: existing?.inspectedBuildingKeys ?? [],
            repairedRiskByBuildingKey: existing?.repairedRiskByBuildingKey ?? [:],
            failures: failures
        )
    }
}
