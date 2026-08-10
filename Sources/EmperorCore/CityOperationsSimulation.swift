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
        models: BuildingModelTable
    ) -> CityOperationsMonthlySettlement {
        let operationalPlacements = placements.filter {
            $0.category != .agriculturalPlot
                && $0.buildingID != OriginalBuildingSpriteCatalog.ruinBuildingID
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

        let assignmentByKey = Dictionary(uniqueKeysWithValues: workforce.assignments.map { ($0.key, $0) })
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
            let assignment = assignmentByKey[risks[index].key]
            let understaffed = (assignment?.requiredWorkers ?? 0) > (assignment?.assignedWorkers ?? 0)
            let staffingMultiplier = understaffed ? 2 : 1
            risks[index].fireRisk += max(0, model.fireRiskIncrement) * staffingMultiplier
            risks[index].damageRisk += max(0, model.damageRiskIncrement) * staffingMultiplier

            if inspectedBuildingKeys.contains(risks[index].key) {
                let before = risks[index].fireRisk + risks[index].damageRisk
                risks[index].fireRisk = max(0, risks[index].fireRisk - max(0, maintenanceRiskReduction))
                risks[index].damageRisk = max(0, risks[index].damageRisk - max(0, maintenanceRiskReduction))
                repairs[risks[index].key] = before - risks[index].fireRisk - risks[index].damageRisk
                risks[index].lastInspectedYear = calendar.year
                risks[index].lastInspectedMonth = calendar.month
            }

            let fireThreshold = Self.fireThreshold(
                model: model,
                category: risks[index].key.category
            )
            let collapseThreshold = Self.collapseThreshold(
                model: model,
                category: risks[index].key.category
            )
            let failureKind: BuildingFailureKind?
            if risks[index].fireRisk >= fireThreshold {
                failureKind = .fire
            } else if risks[index].damageRisk >= collapseThreshold {
                failureKind = .collapse
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

    /// Residential failure is a long-horizon city-planning consequence in the
    /// reference playthrough rather than an early tutorial tax. Its lower
    /// damage threshold also lets long-neglected homes collapse before their
    /// ordinary fire counter wins; invasion fire bypasses both thresholds.
    public static func fireThreshold(
        model: BuildingModel,
        category: PlacedBuildingCategory
    ) -> Int {
        category == .residential
            ? max(100, model.structuralIntegrity * 15)
            : max(100, model.structuralIntegrity / 2)
    }

    public static func collapseThreshold(
        model: BuildingModel,
        category: PlacedBuildingCategory
    ) -> Int {
        category == .residential
            ? max(100, model.structuralIntegrity * 8)
            : max(100, model.structuralIntegrity)
    }

    /// Adds failures caused outside the monthly maintenance loop, such as a
    /// breached invasion force setting buildings alight.
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
