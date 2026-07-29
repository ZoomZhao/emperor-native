import Foundation

public struct OriginalMilitaryFortConfiguration: Sendable, Hashable, Codable {
    public let buildingID: Int
    public let figureID: Int
    public let soldierCount: Int

    public static func configuration(buildingID: Int) -> Self? {
        let figureID: Int
        switch buildingID {
        case 220: figureID = 65 // Crossbow Fort
        case 221: figureID = 64 // Infantry Fort
        case 223: figureID = 68 // Catapult Fort
        case 224: figureID = 66 // Cavalry Fort
        case 225: figureID = 67 // Chariot Fort
        default: return nil
        }
        return Self(buildingID: buildingID, figureID: figureID, soldierCount: 16)
    }
}

public enum MilitaryDefenseKind: String, Sendable, Hashable, Codable {
    case cityWall
    case cityGate
    case tower
}

/// Defensive structures use the original building identifiers and durability
/// values. Gates and towers replace an existing wall tile, matching the
/// original construction flow instead of behaving like ordinary buildings.
public struct OriginalMilitaryDefenseConfiguration: Sendable, Hashable, Codable {
    public let buildingID: Int
    public let kind: MilitaryDefenseKind
    public let maximumIntegrity: Int
    public let sentryFigureIDs: [Int]

    public static func configuration(buildingID: Int) -> Self? {
        switch buildingID {
        case 129:
            Self(buildingID: 129, kind: .cityWall, maximumIntegrity: 500, sentryFigureIDs: [])
        case 130:
            Self(buildingID: 130, kind: .cityGate, maximumIntegrity: 1_500, sentryFigureIDs: [])
        case 131:
            // A staffed tower creates both of the original sentry figures: a
            // wall patrol and a standing bow guard.
            Self(buildingID: 131, kind: .tower, maximumIntegrity: 1_200, sentryFigureIDs: [56, 57])
        default:
            nil
        }
    }
}

public struct MilitaryDefenseStructure: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let kind: MilitaryDefenseKind
    public let point: GridPoint
    public let maximumIntegrity: Int
    public private(set) var integrity: Int

    public var isOperational: Bool { integrity > 0 }

    mutating func applyDamage(_ amount: Int) {
        integrity = max(0, integrity - max(0, amount))
    }

    mutating func restore() {
        integrity = maximumIntegrity
    }
}

public struct MilitarySentry: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let defenseID: Int
    public let figureID: Int
    public let point: GridPoint
}

public struct MilitaryFort: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let figureID: Int
    public let roadAccessPoint: GridPoint
    public let unitID: Int
}

public enum MilitaryUnitStatus: String, Sendable, Hashable, Codable {
    case garrisoned
    case marching
    case victorious
    case destroyed
}

public struct MilitaryUnit: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let fortID: Int
    public let figureID: Int
    public let originalSoldierCount: Int
    public private(set) var hitPoints: Int
    public private(set) var morale: Int
    public private(set) var currentPoint: GridPoint
    public private(set) var route: [GridPoint]
    public private(set) var routeIndex: Int
    public private(set) var assignedInvasionID: String?
    public private(set) var status: MilitaryUnitStatus
    public private(set) var rallyPoint: GridPoint?

    public func survivingSoldiers(model: FigureModel?) -> Int {
        guard hitPoints > 0 else { return 0 }
        return min(originalSoldierCount, (hitPoints + max(1, model?.hitPoints ?? 1) - 1)
            / max(1, model?.hitPoints ?? 1))
    }

    mutating func assign(invasionID: String, route: [GridPoint]) {
        guard hitPoints > 0, !route.isEmpty else { return }
        assignedInvasionID = invasionID
        self.route = route
        routeIndex = 0
        currentPoint = route[0]
        rallyPoint = route.last
        status = .marching
    }

    mutating func assignPlayerOrder(route: [GridPoint]) {
        guard hitPoints > 0, !route.isEmpty else { return }
        assignedInvasionID = nil
        self.route = route
        routeIndex = 0
        currentPoint = route[0]
        rallyPoint = route.last
        status = .marching
    }

    mutating func advance(steps: Int) -> Bool {
        guard status == .marching, !route.isEmpty else { return false }
        routeIndex = min(route.count - 1, routeIndex + max(0, steps))
        currentPoint = route[routeIndex]
        return routeIndex == route.count - 1
    }

    mutating func applyCombat(hitPoints remainingHitPoints: Int, morale: Int, won: Bool) {
        hitPoints = max(0, remainingHitPoints)
        self.morale = min(100, max(0, morale))
        route = []
        routeIndex = 0
        assignedInvasionID = nil
        rallyPoint = nil
        status = hitPoints == 0 ? .destroyed : (won ? .victorious : .garrisoned)
    }

    mutating func completePlayerOrder() {
        route = []
        routeIndex = 0
        rallyPoint = nil
        status = hitPoints == 0 ? .destroyed : .garrisoned
    }
}

public struct MilitaryCombatReport: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let invasionID: String
    public let unitID: Int
    public let friendlyFigureID: Int
    public let friendlySoldiersBefore: Int
    public let friendlySoldiersLost: Int
    public let enemyTypeID: Int
    public let enemySoldiersBefore: Int
    public let enemySoldiersLost: Int
    public let rounds: Int
    public let outcome: CampaignInvasionStatus
    /// Added in native format 0.31. `nil` preserves decoding of 0.30 saves.
    public let participatingUnitIDs: [Int]?
    /// Added in native format 0.75. Larger invasion forces bring one siege
    /// engine per 32 soldiers, which deals additional structural damage.
    public let enemySiegeEngineCount: Int?
}

public struct MilitaryMovementSettlement: Sendable, Hashable, Codable {
    public let movedSteps: Int
    public let reports: [MilitaryCombatReport]
    /// Added in native format 0.75. Optional for decoding earlier saves.
    public let enemyMovedSteps: Int?

    public static let empty = Self(movedSteps: 0, reports: [], enemyMovedSteps: nil)
}

public enum EnemyForceStatus: String, Sendable, Hashable, Codable {
    case maneuvering
    case engaged
    case repelled
    case breached
}

/// A visible, saveable enemy force created from an authored campaign
/// invasion. It advances from the original map entry point toward the nearest
/// operational defense (or the city centre when no defense remains).
public struct EnemyMilitaryForce: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let invasionID: String
    public let enemyTypeID: Int
    public let soldierCount: Int
    public let siegeEngineCount: Int
    public private(set) var currentPoint: GridPoint
    public private(set) var targetPoint: GridPoint
    public private(set) var route: [GridPoint]
    public private(set) var routeIndex: Int
    public private(set) var status: EnemyForceStatus

    mutating func retarget(_ target: GridPoint, route: [GridPoint]) {
        guard status == .maneuvering || status == .engaged else { return }
        targetPoint = target
        self.route = route
        routeIndex = 0
        if let first = route.first { currentPoint = first }
        status = .maneuvering
    }

    mutating func advance(steps: Int) -> Bool {
        guard status == .maneuvering, !route.isEmpty else {
            return currentPoint == targetPoint
        }
        routeIndex = min(route.count - 1, routeIndex + max(0, steps))
        currentPoint = route[routeIndex]
        let arrived = routeIndex == route.count - 1
        if arrived { status = .engaged }
        return arrived
    }

    mutating func resolve(_ outcome: CampaignInvasionStatus) {
        route = []
        routeIndex = 0
        status = outcome == .repelled ? .repelled : .breached
    }
}

public struct DeterministicMilitaryState: Sendable, Hashable, Codable {
    public private(set) var forts: [MilitaryFort]
    public private(set) var units: [MilitaryUnit]
    public private(set) var combatReports: [MilitaryCombatReport]
    public private(set) var lastMovement: MilitaryMovementSettlement?
    // Optional backing fields keep military data written by 0.30 decodable.
    private var defensiveStructuresState: [MilitaryDefenseStructure]?
    private var sentriesState: [MilitarySentry]?
    /// Optional backing keeps pre-0.75 native saves decodable.
    private var enemyForcesState: [EnemyMilitaryForce]?

    public var defensiveStructures: [MilitaryDefenseStructure] {
        defensiveStructuresState ?? []
    }

    public var sentries: [MilitarySentry] { sentriesState ?? [] }
    public var enemyForces: [EnemyMilitaryForce] { enemyForcesState ?? [] }

    public init() {
        forts = []
        units = []
        combatReports = []
        lastMovement = nil
        defensiveStructuresState = []
        sentriesState = []
        enemyForcesState = []
    }

    @discardableResult
    mutating func addFort(
        configuration: OriginalMilitaryFortConfiguration,
        roadAccessPoint: GridPoint,
        models: FigureModelTable
    ) -> Int? {
        guard let figure = models[figureID: configuration.figureID], figure.hitPoints > 0 else {
            return nil
        }
        let fortID = (forts.map(\.id).max() ?? 0) + 1
        let unitID = (units.map(\.id).max() ?? 0) + 1
        forts.append(MilitaryFort(
            id: fortID,
            buildingID: configuration.buildingID,
            figureID: configuration.figureID,
            roadAccessPoint: roadAccessPoint,
            unitID: unitID
        ))
        units.append(MilitaryUnit(
            id: unitID,
            fortID: fortID,
            figureID: configuration.figureID,
            originalSoldierCount: configuration.soldierCount,
            hitPoints: configuration.soldierCount * figure.hitPoints,
            morale: 100,
            currentPoint: roadAccessPoint,
            route: [],
            routeIndex: 0,
            assignedInvasionID: nil,
            status: .garrisoned,
            rallyPoint: nil
        ))
        return fortID
    }

    @discardableResult
    mutating func removeFort(id: Int) -> Bool {
        guard let index = forts.firstIndex(where: { $0.id == id }) else { return false }
        let fort = forts.remove(at: index)
        units.removeAll { $0.id == fort.unitID }
        return true
    }

    @discardableResult
    mutating func addDefense(
        configuration: OriginalMilitaryDefenseConfiguration,
        point: GridPoint,
        models: FigureModelTable
    ) -> Int? {
        guard configuration.sentryFigureIDs.allSatisfy({ models[figureID: $0] != nil }) else {
            return nil
        }
        var defenses = defensiveStructuresState ?? []
        // Keep placement references disjoint from fort IDs while both share
        // the existing `.military` placement category.
        let defenseID = max(1_000_000, (defenses.map(\.id).max() ?? 999_999) + 1)
        defenses.append(MilitaryDefenseStructure(
            id: defenseID,
            buildingID: configuration.buildingID,
            kind: configuration.kind,
            point: point,
            maximumIntegrity: configuration.maximumIntegrity,
            integrity: configuration.maximumIntegrity
        ))
        defensiveStructuresState = defenses
        appendSentries(
            defenseID: defenseID,
            point: point,
            figureIDs: configuration.sentryFigureIDs
        )
        return defenseID
    }

    @discardableResult
    mutating func replaceDefense(
        id: Int,
        configuration: OriginalMilitaryDefenseConfiguration,
        models: FigureModelTable
    ) -> Bool {
        guard configuration.sentryFigureIDs.allSatisfy({ models[figureID: $0] != nil }) else {
            return false
        }
        var defenses = defensiveStructuresState ?? []
        guard let index = defenses.firstIndex(where: { $0.id == id }) else { return false }
        let point = defenses[index].point
        defenses[index] = MilitaryDefenseStructure(
            id: id,
            buildingID: configuration.buildingID,
            kind: configuration.kind,
            point: point,
            maximumIntegrity: configuration.maximumIntegrity,
            integrity: configuration.maximumIntegrity
        )
        defensiveStructuresState = defenses
        var sentries = sentriesState ?? []
        sentries.removeAll { $0.defenseID == id }
        sentriesState = sentries
        appendSentries(
            defenseID: id,
            point: point,
            figureIDs: configuration.sentryFigureIDs
        )
        return true
    }

    @discardableResult
    mutating func removeDefense(id: Int) -> Bool {
        var defenses = defensiveStructuresState ?? []
        guard let index = defenses.firstIndex(where: { $0.id == id }) else { return false }
        defenses.remove(at: index)
        defensiveStructuresState = defenses
        var sentries = sentriesState ?? []
        sentries.removeAll { $0.defenseID == id }
        sentriesState = sentries
        return true
    }

    @discardableResult
    mutating func issueOrder(unitIDs: Set<Int>, routesByUnitID: [Int: [GridPoint]]) -> Int {
        var ordered = 0
        for index in units.indices where unitIDs.contains(units[index].id) {
            guard let route = routesByUnitID[units[index].id], !route.isEmpty,
                  units[index].hitPoints > 0 else { continue }
            units[index].assignPlayerOrder(route: route)
            ordered += 1
        }
        return ordered
    }

    private mutating func appendSentries(
        defenseID: Int,
        point: GridPoint,
        figureIDs: [Int]
    ) {
        var sentries = sentriesState ?? []
        var nextID = (sentries.map(\.id).max() ?? 0) + 1
        for figureID in figureIDs {
            sentries.append(MilitarySentry(
                id: nextID,
                defenseID: defenseID,
                figureID: figureID,
                point: point
            ))
            nextID += 1
        }
        sentriesState = sentries
    }

    public mutating func advance(
        maximumStepsPerUnit: Int? = nil,
        terrain: DeterministicTerrainState?,
        blockedPoints: Set<GridPoint>,
        campaignEvents: inout CampaignCityEventState,
        models: FigureModelTable
    ) -> MilitaryMovementSettlement {
        var movedSteps = 0
        var enemyMovedSteps = 0
        var newReports: [MilitaryCombatReport] = []

        // Player rally orders are advanced before campaign alerts claim idle
        // formations. Units already marching under an explicit order remain
        // unavailable until they reach their destination.
        for index in units.indices where
            units[index].assignedInvasionID == nil && !units[index].route.isEmpty {
            let speed = models[figureID: units[index].figureID]?.speed ?? 1
            let beforeIndex = units[index].routeIndex
            let arrived = units[index].advance(steps: maximumStepsPerUnit ?? max(1, speed))
            movedSteps += max(0, units[index].routeIndex - beforeIndex)
            if arrived { units[index].completePlayerOrder() }
        }

        let pending = campaignEvents.invasions
            .filter { $0.status == .awaitingDefense }
            .sorted { $0.id < $1.id }

        synchronizeEnemyForces(
            with: pending,
            terrain: terrain,
            blockedPoints: blockedPoints,
            models: models
        )

        for alert in pending {
            guard let forceIndex = enemyForcesState?.firstIndex(where: {
                $0.invasionID == alert.id
            }) else { continue }
            let target = enemyTarget(for: alert, terrain: terrain)
            retargetEnemyForce(
                at: forceIndex,
                target: target,
                terrain: terrain,
                blockedPoints: blockedPoints
            )
            let enemySpeed = min(4, max(1, models[enemyTypeID: Self.enemyTypeID(for: alert)]?.speed ?? 1))
            let enemyBeforeIndex = enemyForcesState?[forceIndex].routeIndex ?? 0
            let enemyArrived = enemyForcesState?[forceIndex].advance(
                steps: maximumStepsPerUnit ?? enemySpeed
            ) ?? false
            enemyMovedSteps += max(
                0,
                (enemyForcesState?[forceIndex].routeIndex ?? enemyBeforeIndex) - enemyBeforeIndex
            )
            guard let enemyPoint = enemyForcesState?[forceIndex].currentPoint else { continue }

            var participating = units.indices.filter {
                units[$0].hitPoints > 0 && units[$0].assignedInvasionID == alert.id
            }
            if participating.isEmpty {
                let available = units.indices
                    .filter {
                        units[$0].hitPoints > 0
                            && units[$0].assignedInvasionID == nil
                            && units[$0].route.isEmpty
                    }
                    .sorted { lhs, rhs in
                        let target = alert.entryPoint ?? units[lhs].currentPoint
                        let left = Self.distance(units[lhs].currentPoint, target)
                        let right = Self.distance(units[rhs].currentPoint, target)
                        return left == right ? units[lhs].id < units[rhs].id : left < right
                    }
                for unitIndex in available {
                    let destination = enemyPoint
                    var routeBlocked = blockedPoints
                    routeBlocked.remove(destination)
                    let route = terrain?.shortestLandVisitorPath(
                        from: units[unitIndex].currentPoint,
                        to: destination,
                        blocked: routeBlocked
                    ) ?? GridPathfinder.shortestPath(
                        width: terrain?.width
                            ?? max(destination.x + 1, units[unitIndex].currentPoint.x + 1),
                        height: terrain?.height
                            ?? max(destination.y + 1, units[unitIndex].currentPoint.y + 1),
                        from: units[unitIndex].currentPoint,
                        to: destination,
                        isPassable: { !routeBlocked.contains($0) }
                    )
                    if let route {
                        units[unitIndex].assign(invasionID: alert.id, route: route)
                        participating.append(unitIndex)
                    }
                }
            }

            // Enemy and friendly formations move simultaneously. Recompute a
            // short intercept route each tick so formations pursue a moving
            // force instead of walking to a stale invasion entry point.
            for unitIndex in participating where units[unitIndex].currentPoint != enemyPoint {
                var routeBlocked = blockedPoints
                routeBlocked.remove(enemyPoint)
                routeBlocked.remove(units[unitIndex].currentPoint)
                if let route = terrain?.shortestLandVisitorPath(
                    from: units[unitIndex].currentPoint,
                    to: enemyPoint,
                    blocked: routeBlocked
                ) ?? GridPathfinder.shortestPath(
                    width: terrain?.width ?? max(enemyPoint.x + 1, 1),
                    height: terrain?.height ?? max(enemyPoint.y + 1, 1),
                    from: units[unitIndex].currentPoint,
                    to: enemyPoint,
                    isPassable: { !routeBlocked.contains($0) }
                ) {
                    units[unitIndex].assign(invasionID: alert.id, route: route)
                }
            }

            var allArrived = !participating.isEmpty
            for unitIndex in participating {
                let speed = models[figureID: units[unitIndex].figureID]?.speed ?? 1
                let beforeIndex = units[unitIndex].routeIndex
                let arrived = units[unitIndex].advance(
                    steps: maximumStepsPerUnit ?? max(1, speed)
                )
                movedSteps += max(0, units[unitIndex].routeIndex - beforeIndex)
                allArrived = allArrived && arrived
            }

            let defenseIndex = enemyArrived
                ? nearestOperationalDefenseIndex(to: enemyPoint)
                : nil
            guard allArrived || enemyArrived else { continue }

            let enemyTypeID = Self.enemyTypeID(for: alert)
            guard let enemy = models[enemyTypeID: enemyTypeID]
                ?? models[enemyTypeID: 0]
                ?? participating.first.flatMap({ models[figureID: units[$0].figureID] })
            else { continue }
            let report = resolveCombat(
                alert: alert,
                unitIndices: participating,
                defenseIndex: defenseIndex,
                enemyTypeID: enemyTypeID,
                enemy: enemy,
                siegeEngineCount: enemyForcesState?[forceIndex].siegeEngineCount ?? 0,
                models: models
            )
            _ = campaignEvents.resolveInvasion(id: alert.id, as: report.outcome)
            // `resolveCombat` does not mutate the enemy-force array, so the
            // index remains stable across the settlement.
            if enemyForcesState?.indices.contains(forceIndex) == true {
                enemyForcesState?[forceIndex].resolve(report.outcome)
            }
            combatReports.append(report)
            newReports.append(report)
        }
        let settlement = MilitaryMovementSettlement(
            movedSteps: movedSteps,
            reports: newReports,
            enemyMovedSteps: enemyMovedSteps
        )
        lastMovement = settlement
        return settlement
    }

    private mutating func resolveCombat(
        alert: CampaignInvasionAlert,
        unitIndices: [Int],
        defenseIndex: Int?,
        enemyTypeID: Int,
        enemy: FigureModel,
        siegeEngineCount: Int,
        models: FigureModelTable
    ) -> MilitaryCombatReport {
        let participatingIDs = unitIndices.map { units[$0].id }
        let modelsByUnitIndex = Dictionary(uniqueKeysWithValues: unitIndices.compactMap { index in
            models[figureID: units[index].figureID].map { (index, $0) }
        })
        let hitPointsBefore = Dictionary(uniqueKeysWithValues: unitIndices.map {
            ($0, units[$0].hitPoints)
        })
        var friendlyHitPoints = hitPointsBefore
        let friendlyBefore = unitIndices.reduce(0) { partial, index in
            partial + units[index].survivingSoldiers(model: modelsByUnitIndex[index])
        }
        let enemyBefore = max(1, alert.strength)
        var enemyHP = enemyBefore * max(1, enemy.hitPoints)
        var defenses = defensiveStructuresState ?? []
        let defenseID = defenseIndex.map { defenses[$0].id }
        var defenseHP = defenseIndex.map { defenses[$0].integrity } ?? 0
        let activeSentries = sentries.filter { sentry in
            guard sentry.defenseID == defenseID else { return false }
            let range = models[figureID: sentry.figureID]?.missileRange ?? 0
            return range > 0 && alert.entryPoint.map {
                Self.distance(sentry.point, $0) <= range
            } ?? true
        }
        let maximumRange = max(
            unitIndices.compactMap { modelsByUnitIndex[$0]?.missileRange }.max() ?? 0,
            activeSentries.compactMap { models[figureID: $0.figureID]?.missileRange }.max() ?? 0
        )
        let rangedOpeningRounds = min(2, maximumRange / 6)
        var rounds = 0
        while (friendlyHitPoints.values.contains { $0 > 0 } || defenseHP > 0),
              enemyHP > 0, rounds < 256 {
            let enemyCount = (enemyHP + max(1, enemy.hitPoints) - 1)
                / max(1, enemy.hitPoints)
            let unitDamage = unitIndices.reduce(0) { partial, index in
                guard let model = modelsByUnitIndex[index],
                      let hitPoints = friendlyHitPoints[index], hitPoints > 0 else { return partial }
                let count = (hitPoints + max(1, model.hitPoints) - 1) / max(1, model.hitPoints)
                return partial + count * Self.damage(attacker: model, defender: enemy)
            }
            let sentryDamage = defenseHP > 0 ? activeSentries.reduce(0) { partial, sentry in
                guard let model = models[figureID: sentry.figureID] else { return partial }
                return partial + Self.damage(attacker: model, defender: enemy)
            } : 0
            let friendlyDamage = unitDamage + sentryDamage
            enemyHP = max(0, enemyHP - friendlyDamage)

            if enemyHP > 0, rounds >= rangedOpeningRounds {
                if defenseHP > 0 {
                    let structureDamage = enemyCount * max(1, enemy.attack + enemy.missileAttack)
                        + siegeEngineCount * 120
                    defenseHP = max(0, defenseHP - structureDamage)
                } else if let targetIndex = unitIndices.first(where: {
                    (friendlyHitPoints[$0] ?? 0) > 0 && modelsByUnitIndex[$0] != nil
                }), let defender = modelsByUnitIndex[targetIndex] {
                    let enemyDamage = enemyCount * Self.damage(
                        attacker: enemy,
                        defender: defender
                    )
                    friendlyHitPoints[targetIndex] = max(
                        0,
                        (friendlyHitPoints[targetIndex] ?? 0) - enemyDamage
                    )
                }
            }
            rounds += 1
        }
        let outcome: CampaignInvasionStatus = enemyHP == 0 ? .repelled : .cityBreached
        var friendlyAfter = 0
        for index in unitIndices {
            guard let model = modelsByUnitIndex[index] else { continue }
            let remaining = friendlyHitPoints[index] ?? 0
            let before = units[index].survivingSoldiers(model: model)
            let after = remaining == 0 ? 0
                : (remaining + max(1, model.hitPoints) - 1) / max(1, model.hitPoints)
            friendlyAfter += after
            let moraleLoss = max(0, before - after) * 100 / max(1, before)
            units[index].applyCombat(
                hitPoints: remaining,
                morale: 100 - moraleLoss,
                won: outcome == .repelled
            )
        }
        if let defenseIndex {
            defenses[defenseIndex].applyDamage(defenses[defenseIndex].integrity - defenseHP)
            defensiveStructuresState = defenses
        }
        let enemyAfter = enemyHP == 0 ? 0
            : (enemyHP + max(1, enemy.hitPoints) - 1) / max(1, enemy.hitPoints)
        let leadUnitID = unitIndices.first.map { units[$0].id } ?? 0
        let leadFigureID = unitIndices.first.map { units[$0].figureID }
            ?? activeSentries.first?.figureID
            ?? 57
        return MilitaryCombatReport(
            id: "\(alert.id):\(leadUnitID)",
            invasionID: alert.id,
            unitID: leadUnitID,
            friendlyFigureID: leadFigureID,
            friendlySoldiersBefore: friendlyBefore,
            friendlySoldiersLost: friendlyBefore - friendlyAfter,
            enemyTypeID: enemyTypeID,
            enemySoldiersBefore: enemyBefore,
            enemySoldiersLost: enemyBefore - enemyAfter,
            rounds: rounds,
            outcome: outcome,
            participatingUnitIDs: participatingIDs,
            enemySiegeEngineCount: siegeEngineCount
        )
    }

    private mutating func synchronizeEnemyForces(
        with alerts: [CampaignInvasionAlert],
        terrain: DeterministicTerrainState?,
        blockedPoints: Set<GridPoint>,
        models: FigureModelTable
    ) {
        var forces = enemyForcesState ?? []
        for alert in alerts where !forces.contains(where: { $0.invasionID == alert.id }) {
            let enemyTypeID = Self.enemyTypeID(for: alert)
            let start = alert.entryPoint ?? GridPoint(x: 0, y: (terrain?.height ?? 1) / 2)
            let target = enemyTarget(for: alert, terrain: terrain)
            var routeBlocked = blockedPoints
            routeBlocked.remove(start)
            routeBlocked.remove(target)
            let route = terrain?.shortestLandVisitorPath(
                from: start,
                to: target,
                blocked: routeBlocked
            ) ?? [start]
            forces.append(EnemyMilitaryForce(
                id: alert.id,
                invasionID: alert.id,
                enemyTypeID: enemyTypeID,
                soldierCount: max(1, alert.strength),
                siegeEngineCount: max(0, alert.strength / 32),
                currentPoint: start,
                targetPoint: target,
                route: route,
                routeIndex: 0,
                status: .maneuvering
            ))
            _ = models[enemyTypeID: enemyTypeID]
        }
        enemyForcesState = forces
    }

    private func enemyTarget(
        for alert: CampaignInvasionAlert,
        terrain: DeterministicTerrainState?
    ) -> GridPoint {
        let invasionOrigin = alert.entryPoint
            ?? GridPoint(x: (terrain?.width ?? 1) / 2, y: (terrain?.height ?? 1) / 2)
        if let defense = defensiveStructures.filter(\.isOperational).min(by: {
            let left = Self.distance($0.point, invasionOrigin)
            let right = Self.distance($1.point, invasionOrigin)
            return left == right ? $0.id < $1.id : left < right
        }) {
            return defense.point
        }
        if let unit = units.filter({ $0.hitPoints > 0 }).min(by: {
            let left = Self.distance($0.currentPoint, invasionOrigin)
            let right = Self.distance($1.currentPoint, invasionOrigin)
            return left == right ? $0.id < $1.id : left < right
        }) {
            return unit.currentPoint
        }
        return GridPoint(x: (terrain?.width ?? 1) / 2, y: (terrain?.height ?? 1) / 2)
    }

    private mutating func retargetEnemyForce(
        at index: Int,
        target: GridPoint,
        terrain: DeterministicTerrainState?,
        blockedPoints: Set<GridPoint>
    ) {
        guard enemyForcesState?.indices.contains(index) == true,
              let force = enemyForcesState?[index],
              force.status == .maneuvering || force.status == .engaged,
              force.targetPoint != target || force.route.isEmpty else { return }
        var routeBlocked = blockedPoints
        routeBlocked.remove(force.currentPoint)
        routeBlocked.remove(target)
        let route = terrain?.shortestLandVisitorPath(
            from: force.currentPoint,
            to: target,
            blocked: routeBlocked
        ) ?? GridPathfinder.shortestPath(
            width: terrain?.width ?? max(force.currentPoint.x, target.x) + 1,
            height: terrain?.height ?? max(force.currentPoint.y, target.y) + 1,
            from: force.currentPoint,
            to: target,
            isPassable: { !routeBlocked.contains($0) }
        ) ?? [force.currentPoint]
        enemyForcesState?[index].retarget(target, route: route)
    }

    private func nearestOperationalDefenseIndex(to point: GridPoint?) -> Int? {
        let defenses = defensiveStructuresState ?? []
        guard let point else { return defenses.firstIndex(where: \.isOperational) }
        return defenses.indices
            .filter { defenses[$0].isOperational && Self.distance(defenses[$0].point, point) <= 3 }
            .min { lhs, rhs in
                let left = Self.distance(defenses[lhs].point, point)
                let right = Self.distance(defenses[rhs].point, point)
                return left == right ? defenses[lhs].id < defenses[rhs].id : left < right
            }
    }

    private static func damage(attacker: FigureModel, defender: FigureModel) -> Int {
        let melee = attacker.attack > 0 ? max(1, attacker.attack - defender.armor) : 0
        let missile = attacker.missileAttack > 0
            ? max(1, attacker.missileAttack - defender.missileArmor) : 0
        return max(1, melee + missile)
    }

    private static func enemyTypeID(for alert: CampaignInvasionAlert) -> Int {
        // Empire city 10 is the Nomad Camps in the shipped Qin campaign.
        // Its original enemy table uses Xiongnu Infantry (6); retaining the
        // secondary selector keeps that identity deterministic through combat.
        if alert.secondarySelectionID == 10 { return 6 }
        return 0
    }

    private static func distance(_ lhs: GridPoint, _ rhs: GridPoint) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }
}
