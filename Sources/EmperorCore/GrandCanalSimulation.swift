import Foundation

public struct GrandCanalSubBuilding: Sendable, Hashable, Codable {
    public let index: Int
    public let localOrigin: GridPoint
    public let isRoadCrossing: Bool

    public init(index: Int, localOrigin: GridPoint, isRoadCrossing: Bool) {
        self.index = index
        self.localOrigin = localOrigin
        self.isRoadCrossing = isRoadCrossing
    }

    public var footprint: BuildingFootprint {
        BuildingFootprint(width: 4, height: 4)
    }

    public func worldOrigin(from monumentOrigin: GridPoint) -> GridPoint {
        GridPoint(
            x: monumentOrigin.x + localOrigin.x,
            y: monumentOrigin.y + localOrigin.y
        )
    }
}

public struct GrandCanalPhaseRule: Sendable, Hashable, Codable {
    public let monumentPhase: Int
    public let firstSegmentIndex: Int
    public let lastSegmentIndex: Int
    public let firstSubBuildingPhase: Int
    public let lastSubBuildingPhase: Int
}

public struct GrandCanalLayout: Sendable, Hashable, Codable {
    public let segments: [GrandCanalSubBuilding]
    public let phaseRules: [GrandCanalPhaseRule]

    public static let haunxianOrigin = GridPoint(x: 4, y: 68)

    public static let original = GrandCanalLayout(
        segments: (0..<33).map { index in
            GrandCanalSubBuilding(
                index: index,
                localOrigin: GridPoint(x: index * 4, y: 0),
                isRoadCrossing: [10, 16, 22].contains(index)
            )
        },
        phaseRules: (0..<5).map { phase in
            GrandCanalPhaseRule(
                monumentPhase: phase,
                firstSegmentIndex: 0,
                lastSegmentIndex: 32,
                firstSubBuildingPhase: phase,
                lastSubBuildingPhase: phase + 1
            )
        }
    )

    public static func parse(subBuildingText: String) -> GrandCanalLayout? {
        let segmentExpression = try? NSRegularExpression(
            pattern: #"/\*\s*(\d+)\*/\s*\{\s*(\d+),\s*(\d+),\s*SB_CANAL,\s*\d+,\s*NORTH,\s*(\d+),"#
        )
        let phaseExpression = try? NSRegularExpression(
            pattern: #"<\s*(\d+),\s*(\d+),\s*\d+,\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),"#
        )
        guard let segmentExpression, let phaseExpression else { return nil }
        let range = NSRange(subBuildingText.startIndex..., in: subBuildingText)
        let segments = segmentExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> GrandCanalSubBuilding? in
            guard let index = match.integer(at: 1, in: subBuildingText),
                  let x = match.integer(at: 2, in: subBuildingText),
                  let y = match.integer(at: 3, in: subBuildingText),
                  let entry = match.integer(at: 4, in: subBuildingText) else { return nil }
            return GrandCanalSubBuilding(
                index: index,
                localOrigin: GridPoint(x: x, y: y),
                isRoadCrossing: entry == 1
            )
        }
        let phases = phaseExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> GrandCanalPhaseRule? in
            guard let monumentPhase = match.integer(at: 1, in: subBuildingText),
                  match.integer(at: 2, in: subBuildingText) == 0,
                  let firstSegment = match.integer(at: 3, in: subBuildingText),
                  let lastSegment = match.integer(at: 4, in: subBuildingText),
                  let firstPhase = match.integer(at: 5, in: subBuildingText),
                  let lastPhase = match.integer(at: 6, in: subBuildingText) else { return nil }
            return GrandCanalPhaseRule(
                monumentPhase: monumentPhase,
                firstSegmentIndex: firstSegment,
                lastSegmentIndex: lastSegment,
                firstSubBuildingPhase: firstPhase,
                lastSubBuildingPhase: lastPhase
            )
        }
        guard segments.count == 33, phases.count == 5 else { return nil }
        return GrandCanalLayout(
            segments: segments.sorted { $0.index < $1.index },
            phaseRules: phases.sorted { $0.monumentPhase < $1.monumentPhase }
        )
    }
}

/// Grand Canal state recovered from one original `cMonumentBldg` archive
/// record. The original maps persist one record per sub-building; retaining
/// that granularity is required for both construction and save compatibility.
public struct GrandCanalMapPartState: Sendable, Hashable, Codable {
    public let worldOrigin: GridPoint
    public let mapCellIndex: Int
    public let buildingID: Int
    public let subBuildingIndex: Int
    public let baseBuildingSchema: Int
    public let monumentWrapperSchema: Int
    public let monumentStateSchema: Int
    public private(set) var currentSubBuildingPhase: Int
    public private(set) var wholeMonumentPhase: Int
    /// Original internal stone units already delivered to this sub-building.
    /// `SB_CANAL` phase 2 requests `400 - deliveredStoneUnits`.
    public private(set) var deliveredStoneUnits: Int
    /// Number of on-site laborer figure updates accumulated for the current
    /// phase-0/1 internal-work task. The original stores this in `cMonInfo`
    /// and compares it with the sum of the current `SB_CANAL.txt` animation
    /// ticks; it is distinct from the vtable requirement amount, which is 0.
    public private(set) var onSiteLaborerWorkUpdates: Int

    public init(
        worldOrigin: GridPoint,
        mapCellIndex: Int,
        buildingID: Int,
        subBuildingIndex: Int,
        baseBuildingSchema: Int,
        monumentWrapperSchema: Int,
        monumentStateSchema: Int,
        currentSubBuildingPhase: Int,
        wholeMonumentPhase: Int,
        deliveredStoneUnits: Int = 0,
        onSiteLaborerWorkUpdates: Int = 0
    ) {
        self.worldOrigin = worldOrigin
        self.mapCellIndex = mapCellIndex
        self.buildingID = buildingID
        self.subBuildingIndex = subBuildingIndex
        self.baseBuildingSchema = baseBuildingSchema
        self.monumentWrapperSchema = monumentWrapperSchema
        self.monumentStateSchema = monumentStateSchema
        self.currentSubBuildingPhase = currentSubBuildingPhase
        self.wholeMonumentPhase = wholeMonumentPhase
        self.deliveredStoneUnits = deliveredStoneUnits
        self.onSiteLaborerWorkUpdates = onSiteLaborerWorkUpdates
    }

    private enum CodingKeys: String, CodingKey {
        case worldOrigin
        case mapCellIndex
        case buildingID
        case subBuildingIndex
        case baseBuildingSchema
        case monumentWrapperSchema
        case monumentStateSchema
        case currentSubBuildingPhase
        case wholeMonumentPhase
        case deliveredStoneUnits
        case onSiteLaborerWorkUpdates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        worldOrigin = try container.decode(GridPoint.self, forKey: .worldOrigin)
        mapCellIndex = try container.decode(Int.self, forKey: .mapCellIndex)
        buildingID = try container.decode(Int.self, forKey: .buildingID)
        subBuildingIndex = try container.decode(Int.self, forKey: .subBuildingIndex)
        baseBuildingSchema = try container.decode(Int.self, forKey: .baseBuildingSchema)
        monumentWrapperSchema = try container.decode(Int.self, forKey: .monumentWrapperSchema)
        monumentStateSchema = try container.decode(Int.self, forKey: .monumentStateSchema)
        currentSubBuildingPhase = try container.decode(
            Int.self,
            forKey: .currentSubBuildingPhase
        )
        wholeMonumentPhase = try container.decode(Int.self, forKey: .wholeMonumentPhase)
        deliveredStoneUnits = try container.decodeIfPresent(
            Int.self,
            forKey: .deliveredStoneUnits
        ) ?? 0
        onSiteLaborerWorkUpdates = try container.decodeIfPresent(
            Int.self,
            forKey: .onSiteLaborerWorkUpdates
        ) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(worldOrigin, forKey: .worldOrigin)
        try container.encode(mapCellIndex, forKey: .mapCellIndex)
        try container.encode(buildingID, forKey: .buildingID)
        try container.encode(subBuildingIndex, forKey: .subBuildingIndex)
        try container.encode(baseBuildingSchema, forKey: .baseBuildingSchema)
        try container.encode(monumentWrapperSchema, forKey: .monumentWrapperSchema)
        try container.encode(monumentStateSchema, forKey: .monumentStateSchema)
        try container.encode(currentSubBuildingPhase, forKey: .currentSubBuildingPhase)
        try container.encode(wholeMonumentPhase, forKey: .wholeMonumentPhase)
        try container.encode(deliveredStoneUnits, forKey: .deliveredStoneUnits)
        try container.encode(onSiteLaborerWorkUpdates, forKey: .onSiteLaborerWorkUpdates)
    }

    /// Applies one original commodity-20 cargo at the monument target.
    /// `FUN_00571DA0` fills only the phase-2 remainder and leaves any excess
    /// on the carrier; phase advancement remains the coordinator's job.
    @discardableResult
    public mutating func acceptPhaseTwoStoneCargo(_ cargoUnits: Int) -> Int {
        guard currentSubBuildingPhase == 2, cargoUnits > 0 else {
            return max(0, cargoUnits)
        }
        let accepted = min(cargoUnits, max(0, 400 - deliveredStoneUnits))
        deliveredStoneUnits += accepted
        return cargoUnits - accepted
    }

    public var remainingPhaseTwoStoneUnits: Int {
        max(0, 400 - deliveredStoneUnits)
    }

    /// Applies one state-14 laborer update from `FUN_004D5F60 →
    /// FUN_00564E00 → FUN_00570670`. Reaching the target only enters this
    /// state; completion occurs on the update that reaches the authored tick
    /// sum. Xi Wang Mu halves each individual animation-record tick count,
    /// matching `FUN_00448AC0`, and may therefore change the live threshold.
    @discardableResult
    public mutating func recordOnSiteLaborerWorkUpdate(
        xiWangMuActive: Bool
    ) -> Bool {
        guard let requiredUpdates = OriginalGrandCanalLayoutCatalog
            .onSiteLaborerWorkUpdates(
                forPhase: currentSubBuildingPhase,
                xiWangMuActive: xiWangMuActive
            ) else { return false }
        onSiteLaborerWorkUpdates += 1
        guard onSiteLaborerWorkUpdates >= requiredUpdates else { return false }
        currentSubBuildingPhase += 1
        onSiteLaborerWorkUpdates = 0
        return true
    }

    mutating func setConstructionPhases(
        currentSubBuildingPhase: Int,
        wholeMonumentPhase: Int
    ) {
        self.currentSubBuildingPhase = currentSubBuildingPhase
        self.wholeMonumentPhase = wholeMonumentPhase
    }
}

/// Save-compatible state for the original monument scheduler's own call
/// counter. One call is the `FUN_005371A0 → FUN_00564B50` cadence, not a
/// Native calendar day; the clock bridge intentionally remains separate.
public struct GrandCanalSchedulerState: Sendable, Hashable, Codable {
    public private(set) var callCounter: Int
    public private(set) var triggerThreshold: Int

    public init(
        callCounter: Int = 0,
        triggerThreshold: Int =
            OriginalGrandCanalLayoutCatalog.schedulerTicksWithoutActiveWorkQueues
    ) {
        self.callCounter = callCounter
        self.triggerThreshold = triggerThreshold
    }

    mutating func recordCall() -> Bool {
        callCounter += 1
        guard triggerThreshold < callCounter else { return false }
        callCounter = 0
        return true
    }

    mutating func recordSchedulerPass(hasActiveWorkQueues: Bool) {
        triggerThreshold = hasActiveWorkQueues
            ? OriginalGrandCanalLayoutCatalog.schedulerTicksWithActiveWorkQueues
            : OriginalGrandCanalLayoutCatalog.schedulerTicksWithoutActiveWorkQueues
    }
}

/// Source-verified contract for the original Grand Canal. The exact Haunxian
/// five-phase schedule (valid indices 0...4), terminal-state guard, recovered
/// routing-cache branches, phase-0/1 on-site work, and phase-2 stone convoys
/// are implemented with their live laborer/carrier integrations. See
/// `docs/exe-research/grand-canal-map-state.md`.
public enum OriginalGrandCanalLayoutCatalog {
    public enum RequirementKind: Sendable, Hashable, Codable {
        case commodity(id: Int)
        case internalWorkTask(id: Int)
    }

    public struct PhaseRequirement: Sendable, Hashable, Codable {
        public let phase: Int
        public let kind: RequirementKind
        public let amountPerSubBuilding: Int
        public let workerFigureID: Int
    }

    public enum PhaseCompletion: Sendable, Hashable, Codable {
        case workerCompletesAuthoredOnSiteWork
        case commodityAmountDelivered
        case automaticAfterOtherQueuesDrain
    }

    public struct PhaseBehavior: Sendable, Hashable, Codable {
        public let phase: Int
        public let requirement: PhaseRequirement?
        public let completion: PhaseCompletion
    }

    public struct WorkerProvider: Sendable, Hashable, Codable {
        public let figureID: Int
        public let buildingID: Int
    }

    public struct DispatchLimits: Sendable, Hashable, Codable {
        public let maximumArtisanWorkers: Int
        public let maximumLaborerWorkers: Int
        public let tasksPerLaborer: Int
        public let tasksPerFigure80: Int
        public let tasksPerFigure81: Int
        public let tasksPerFigure82: Int
    }

    public struct ProviderCapacityRule: Sendable, Hashable, Codable {
        public let figureID: Int
        public let baseCapacity: Int
    }

    /// One task-102 item held in coordinator queue `+0x50`. The original
    /// runtime keys duplicate suppression by the target object and current
    /// phase; Native uses the authored sub-building index plus phase as its
    /// stable save/replay identity.
    public struct PhaseLaborWorkRequest: Sendable, Hashable, Codable {
        public let requestID: Int
        public let phase: Int
        public let taskID: Int
        public let workerFigureID: Int
        public let targetPoint: GridPoint

        public init(
            requestID: Int,
            phase: Int,
            taskID: Int,
            workerFigureID: Int,
            targetPoint: GridPoint
        ) {
            self.requestID = requestID
            self.phase = phase
            self.taskID = taskID
            self.workerFigureID = workerFigureID
            self.targetPoint = targetPoint
        }
    }

    /// Separates the pending task object's authored origin from the road
    /// access selected by `FUN_00567540`. The former participates in the
    /// state-12 nearest-task comparison; the latter is only the initial
    /// movement target created by `FUN_0056D690`.
    public struct PhaseLaborTargetAccessCandidate: Sendable, Hashable, Codable {
        public let subBuildingIndex: Int
        public let worldOrigin: GridPoint
        public let roadAccessPoint: GridPoint

        public init(
            subBuildingIndex: Int,
            worldOrigin: GridPoint,
            roadAccessPoint: GridPoint
        ) {
            self.subBuildingIndex = subBuildingIndex
            self.worldOrigin = worldOrigin
            self.roadAccessPoint = roadAccessPoint
        }
    }

    /// Live Laborers' Camp candidate consumed by `FUN_0056D4D0`. Efficiency
    /// and active-worker count stay explicit because both affect the original
    /// capacity gate before distance arbitration.
    public struct PhaseLaborProviderCandidate: Sendable, Hashable, Codable {
        public let objectID: Int
        public let buildingID: Int
        public let isActive: Bool
        public let efficiencyPercent: Int
        public let activeMonumentWorkerCount: Int
        public let origin: GridPoint

        public init(
            objectID: Int,
            buildingID: Int,
            isActive: Bool,
            efficiencyPercent: Int,
            activeMonumentWorkerCount: Int,
            origin: GridPoint
        ) {
            self.objectID = objectID
            self.buildingID = buildingID
            self.isActive = isActive
            self.efficiencyPercent = efficiencyPercent
            self.activeMonumentWorkerCount = activeMonumentWorkerCount
            self.origin = origin
        }
    }

    public enum PhaseLaborerState: Int, Sendable, Hashable, Codable {
        case initialTravelToMonument = 12
        case travelingToAssignedTask = 13
        case workingOnSite = 14
        case completedOnSiteWork = 15
        case returningToProvider = 16
    }

    public struct PhaseLaborMovementRuntime: Sendable, Hashable, Codable {
        public let route: WorkerRoute
        public var routeIndex: Int
        public var speedCycleIndex: Int
        public var substepProgress: Int

        public init(
            route: WorkerRoute,
            routeIndex: Int = 0,
            speedCycleIndex: Int = 0,
            substepProgress: Int = 20
        ) {
            self.route = route
            self.routeIndex = max(0, routeIndex)
            self.speedCycleIndex = max(0, speedCycleIndex)
            self.substepProgress = max(0, substepProgress)
        }
    }

    /// Save-safe projection of one figure-10 worker and the `+0x60` dispatch
    /// record that follows it. Movement buffers belong to the city routing
    /// layer; this type preserves the exact raw state and target boundaries.
    public struct PhaseLaborerRuntime: Sendable, Hashable, Codable {
        public let figureID: Int
        public let providerObjectID: Int
        public let providerOrigin: GridPoint
        public var currentPoint: GridPoint
        public var targetPoint: GridPoint
        public var state: PhaseLaborerState
        public var assignedRequest: PhaseLaborWorkRequest?
        /// Original route-buffer projection and movement cadence. Optional
        /// preserves saves written before live monument-worker movement.
        public var movement: PhaseLaborMovementRuntime?
        /// Target object copied into coordinator queue `+0x60`. It suppresses
        /// another initial dispatch for that object until state-12 arrival.
        /// Optional preserves saves written before the two coordinates were
        /// represented independently.
        public var initialRequestID: Int?
        /// Optional fields preserve saves written before exact figure-10
        /// animation and interpolation state were represented.
        private var previousPointState: GridPoint?
        private var animationFrameState: Int?

        public var previousPoint: GridPoint? { previousPointState }
        public var animationFrame: Int { animationFrameState ?? 0 }

        public init(
            figureID: Int,
            providerObjectID: Int,
            providerOrigin: GridPoint,
            targetPoint: GridPoint,
            initialRequestID: Int? = nil
        ) {
            self.figureID = figureID
            self.providerObjectID = providerObjectID
            self.providerOrigin = providerOrigin
            currentPoint = providerOrigin
            self.targetPoint = targetPoint
            state = .initialTravelToMonument
            assignedRequest = nil
            movement = nil
            self.initialRequestID = initialRequestID
            previousPointState = nil
            animationFrameState = 0
        }

        mutating func recordMove(from point: GridPoint) {
            previousPointState = point
        }

        mutating func advanceAnimationFrame() {
            let frameCount = state == .workingOnSite ? 19 : 12
            animationFrameState = (animationFrame + 1) % frameCount
        }
    }

    public enum PhaseLaborArrival: Sendable, Hashable, Codable {
        case assigned(requestID: Int)
        case beganOnSiteWork(requestID: Int)
        case returningToProvider
        case returnedToProvider(providerObjectID: Int)
    }

    public enum PhaseLaborWorkAdvance: Sendable, Hashable, Codable {
        case working(requestID: Int, completedUpdates: Int)
        case completedAndReturning(completedRequestID: Int)
    }

    /// Coordinator queues `+0x50` (pending task-102 items), `+0x60` (initial
    /// dispatch records), and `+0x70` (bound active assignments). A successful
    /// initial dispatch leaves the pending item in place; state-12 arrival
    /// removes the dispatch record, selects the nearest matching pending item,
    /// and adds the bound assignment record.
    public struct PhaseLaborCoordinatorRuntime: Sendable, Hashable, Codable {
        public var pendingRequests: [PhaseLaborWorkRequest]
        public var laborers: [PhaseLaborerRuntime]
        private var nextFigureIDState: Int?

        public var nextFigureID: Int { nextFigureIDState ?? 1 }

        public init(
            pendingRequests: [PhaseLaborWorkRequest] = [],
            laborers: [PhaseLaborerRuntime] = [],
            nextFigureID: Int = 1
        ) {
            self.pendingRequests = pendingRequests
            self.laborers = laborers
            nextFigureIDState = max(1, nextFigureID)
        }

        public mutating func enqueueMissingRequests(
            from parts: [GrandCanalMapPartState]
        ) {
            let represented = Set(pendingRequests.map(Self.requestKey))
                .union(laborers.compactMap { $0.assignedRequest }.map(Self.requestKey))
            var known = represented
            for part in parts.sorted(by: { $0.subBuildingIndex < $1.subBuildingIndex }) {
                guard part.currentSubBuildingPhase == part.wholeMonumentPhase,
                      part.currentSubBuildingPhase == 0
                        || part.currentSubBuildingPhase == 1 else { continue }
                let key = Self.requestKey(
                    requestID: part.subBuildingIndex,
                    phase: part.currentSubBuildingPhase
                )
                guard known.insert(key).inserted else { continue }
                pendingRequests.append(PhaseLaborWorkRequest(
                    requestID: part.subBuildingIndex,
                    phase: part.currentSubBuildingPhase,
                    taskID: OriginalGrandCanalLayoutCatalog.phaseLaborTaskID,
                    workerFigureID: OriginalGrandCanalLayoutCatalog.phaseLaborFigureID,
                    targetPoint: part.worldOrigin
                ))
            }
        }

        /// `FUN_0056D170` visits pending queue order and dispatches at most one
        /// worker per scheduler pass. The pending request is deliberately not
        /// removed until state-12 arrival binds a concrete on-site task.
        public mutating func dispatchOneLaborer(
            providers: [PhaseLaborProviderCandidate],
            targetAccesses: [PhaseLaborTargetAccessCandidate],
            xiWangMuActive: Bool
        ) -> PhaseLaborerRuntime? {
            let limits = xiWangMuActive
                ? OriginalGrandCanalLayoutCatalog.xiWangMuDispatchLimits
                : OriginalGrandCanalLayoutCatalog.normalDispatchLimits
            let activeQueueLaborers = laborers.filter {
                $0.state != .returningToProvider
            }
            let initiallyDispatchedRequestIDs = Set<Int>(laborers.compactMap { laborer -> Int? in
                guard laborer.state == .initialTravelToMonument else { return nil }
                if let initialRequestID = laborer.initialRequestID {
                    return initialRequestID
                }
                return pendingRequests.first(where: {
                    selectedTargetAccess(for: $0, among: targetAccesses)?.roadAccessPoint
                        == laborer.targetPoint
                })?.requestID
            })
            guard activeQueueLaborers.count < limits.maximumLaborerWorkers,
                  let request = pendingRequests.first(where: {
                      !initiallyDispatchedRequestIDs.contains($0.requestID)
                          && selectedTargetAccess(for: $0, among: targetAccesses) != nil
                  }),
                  let targetAccess = selectedTargetAccess(
                      for: request,
                      among: targetAccesses
                  ),
                  let provider = OriginalGrandCanalLayoutCatalog.selectPhaseLaborProvider(
                for: targetAccess.roadAccessPoint,
                candidates: providers
            ) else { return nil }
            let laborer = PhaseLaborerRuntime(
                figureID: nextFigureID,
                providerObjectID: provider.objectID,
                providerOrigin: provider.origin,
                targetPoint: targetAccess.roadAccessPoint,
                initialRequestID: request.requestID
            )
            nextFigureIDState = nextFigureID + 1
            laborers.append(laborer)
            return laborer
        }

        private func selectedTargetAccess(
            for request: PhaseLaborWorkRequest,
            among targetAccesses: [PhaseLaborTargetAccessCandidate]
        ) -> PhaseLaborTargetAccessCandidate? {
            targetAccesses.sorted {
                $0.subBuildingIndex < $1.subBuildingIndex
            }.min { lhs, rhs in
                let lhsDistance = abs(lhs.worldOrigin.x - request.targetPoint.x)
                    + abs(lhs.worldOrigin.y - request.targetPoint.y)
                let rhsDistance = abs(rhs.worldOrigin.x - request.targetPoint.x)
                    + abs(rhs.worldOrigin.y - request.targetPoint.y)
                return lhsDistance < rhsDistance
            }
        }

        public mutating func recordArrival(
            figureID: Int,
            at point: GridPoint
        ) -> PhaseLaborArrival? {
            guard let index = laborers.firstIndex(where: { $0.figureID == figureID }),
                  laborers[index].targetPoint == point else { return nil }
            laborers[index].currentPoint = point
            laborers[index].movement = nil
            switch laborers[index].state {
            case .initialTravelToMonument:
                laborers[index].initialRequestID = nil
                guard let request = takeNearestPendingRequest(
                    workerFigureID: OriginalGrandCanalLayoutCatalog.phaseLaborFigureID,
                    taskID: OriginalGrandCanalLayoutCatalog.phaseLaborTaskID,
                    from: point
                ) else {
                    laborers[index].state = .returningToProvider
                    laborers[index].targetPoint = laborers[index].providerOrigin
                    return .returningToProvider
                }
                laborers[index].assignedRequest = request
                laborers[index].targetPoint = request.targetPoint
                laborers[index].state = .travelingToAssignedTask
                return .assigned(requestID: request.requestID)
            case .travelingToAssignedTask:
                guard let request = laborers[index].assignedRequest else { return nil }
                laborers[index].state = .workingOnSite
                return .beganOnSiteWork(requestID: request.requestID)
            case .returningToProvider:
                let providerObjectID = laborers[index].providerObjectID
                laborers.remove(at: index)
                return .returnedToProvider(providerObjectID: providerObjectID)
            case .workingOnSite, .completedOnSiteWork:
                return nil
            }
        }

        public mutating func recordOnSiteWorkUpdate(
            figureID: Int,
            parts: inout [GrandCanalMapPartState],
            xiWangMuActive: Bool
        ) -> PhaseLaborWorkAdvance? {
            guard let laborerIndex = laborers.firstIndex(where: { $0.figureID == figureID }),
                  laborers[laborerIndex].state == .workingOnSite,
                  let request = laborers[laborerIndex].assignedRequest,
                  let partIndex = parts.firstIndex(where: {
                      $0.subBuildingIndex == request.requestID
                          && $0.currentSubBuildingPhase == request.phase
                  }) else { return nil }
            guard parts[partIndex].recordOnSiteLaborerWorkUpdate(
                xiWangMuActive: xiWangMuActive
            ) else {
                return .working(
                    requestID: request.requestID,
                    completedUpdates: parts[partIndex].onSiteLaborerWorkUpdates
                )
            }

            laborers[laborerIndex].state = .completedOnSiteWork
            laborers[laborerIndex].assignedRequest = nil
            // `FUN_0056D8A0` permits post-completion reassignment from the
            // bound queue only for subtype 101. Grand Canal labor is subtype
            // 102, so it always returns to its provider after one part.
            laborers[laborerIndex].targetPoint = laborers[laborerIndex].providerOrigin
            laborers[laborerIndex].state = .returningToProvider
            laborers[laborerIndex].movement = nil
            return .completedAndReturning(completedRequestID: request.requestID)
        }

        /// Advances each currently-live figure 10 exactly once, matching the
        /// figure-update pass that precedes one original monument-scheduler
        /// call. Newly dispatched laborers are absent from the captured ID
        /// list and therefore cannot move in their creation step.
        @discardableResult
        public mutating func advanceFigureUpdates(
            parts: inout [GrandCanalMapPartState],
            routingGrids: WorkerRoutingGrids,
            xiWangMuActive: Bool
        ) -> Int {
            let figureIDs = laborers.map(\.figureID)
            var movedRouteSteps = 0
            let movementRule = OriginalGrandCanalLayoutCatalog.workerMovementRules.first {
                $0.figureID == OriginalGrandCanalLayoutCatalog.phaseLaborFigureID
            }
            guard let movementRule else { return 0 }

            for figureID in figureIDs {
                guard let laborerIndex = laborers.firstIndex(where: {
                    $0.figureID == figureID
                }) else { continue }
                if laborers[laborerIndex].state == .workingOnSite {
                    _ = recordOnSiteWorkUpdate(
                        figureID: figureID,
                        parts: &parts,
                        xiWangMuActive: xiWangMuActive
                    )
                    if let updatedIndex = laborers.firstIndex(where: {
                        $0.figureID == figureID
                    }) {
                        laborers[updatedIndex].advanceAnimationFrame()
                    }
                    continue
                }
                if laborers[laborerIndex].currentPoint
                    == laborers[laborerIndex].targetPoint {
                    _ = recordArrival(
                        figureID: figureID,
                        at: laborers[laborerIndex].currentPoint
                    )
                    if let updatedIndex = laborers.firstIndex(where: {
                        $0.figureID == figureID
                    }) {
                        laborers[updatedIndex].advanceAnimationFrame()
                    }
                    continue
                }

                let current = laborers[laborerIndex].currentPoint
                let target = laborers[laborerIndex].targetPoint
                var movement = laborers[laborerIndex].movement
                if movement.map({ runtime in
                    !runtime.route.points.indices.contains(runtime.routeIndex)
                        || runtime.route.points[runtime.routeIndex] != current
                }) ?? true
                    || movement?.route.points.last != target {
                    guard let route = OriginalGrandCanalLayoutCatalog.workerRoute(
                        primaryValues: routingGrids.primaryPassability,
                        fallbackValues: routingGrids.fallbackCellClass,
                        width: routingGrids.width,
                        height: routingGrids.height,
                        from: current,
                        to: target
                    ) else {
                        laborers[laborerIndex].movement = nil
                        continue
                    }
                    movement = PhaseLaborMovementRuntime(
                        route: route,
                        substepProgress: movementRule.initialSubstepProgress
                    )
                }
                guard var movement else { continue }
                let cycle = movementRule.substepsPerFigureUpdateCycle
                let cycleIndex = movement.speedCycleIndex % cycle.count
                movement.substepProgress += cycle[cycleIndex]
                movement.speedCycleIndex = (cycleIndex + 1) % cycle.count
                if movement.substepProgress >= movementRule.substepsPerRouteStep,
                   movement.routeIndex + 1 < movement.route.points.count {
                    movement.routeIndex += 1
                    movement.substepProgress = 0
                    laborers[laborerIndex].recordMove(from: current)
                    laborers[laborerIndex].currentPoint = movement.route.points[
                        movement.routeIndex
                    ]
                    movedRouteSteps += 1
                }
                laborers[laborerIndex].movement = movement
                if laborers[laborerIndex].currentPoint == target {
                    _ = recordArrival(figureID: figureID, at: target)
                }
                if let updatedIndex = laborers.firstIndex(where: {
                    $0.figureID == figureID
                }) {
                    laborers[updatedIndex].advanceAnimationFrame()
                }
            }
            return movedRouteSteps
        }

        private mutating func takeNearestPendingRequest(
            workerFigureID: Int,
            taskID: Int,
            from point: GridPoint
        ) -> PhaseLaborWorkRequest? {
            var selectedIndex: Int?
            var selectedSquaredDistance: Int?
            for index in pendingRequests.indices where
                pendingRequests[index].workerFigureID == workerFigureID
                    && pendingRequests[index].taskID == taskID {
                let dx = pendingRequests[index].targetPoint.x - point.x
                let dy = pendingRequests[index].targetPoint.y - point.y
                let squared = dx * dx + dy * dy
                if selectedSquaredDistance.map({ squared < $0 }) ?? true {
                    selectedIndex = index
                    selectedSquaredDistance = squared
                }
            }
            guard let selectedIndex else { return nil }
            return pendingRequests.remove(at: selectedIndex)
        }

        private static func requestKey(_ request: PhaseLaborWorkRequest) -> String {
            requestKey(requestID: request.requestID, phase: request.phase)
        }

        private static func requestKey(requestID: Int, phase: Int) -> String {
            "\(requestID):\(phase)"
        }
    }

    /// One live inventory building considered by the original phase-2 source
    /// search. `commodityTradeState` is the byte at the trade-building-only
    /// `building-list record + 200 + commodityID`; warehouse 54 has no such
    /// rejection gate in this path.
    public struct PhaseTwoMaterialSourceCandidate: Sendable, Hashable, Codable {
        public let objectID: Int
        public let buildingID: Int
        public let isActive: Bool
        public let availableStoneUnits: Int
        public let commodityTradeState: Int?

        public init(
            objectID: Int,
            buildingID: Int,
            isActive: Bool,
            availableStoneUnits: Int,
            commodityTradeState: Int? = nil
        ) {
            self.objectID = objectID
            self.buildingID = buildingID
            self.isActive = isActive
            self.availableStoneUnits = availableStoneUnits
            self.commodityTradeState = commodityTradeState
        }
    }

    /// Result semantics of source-building vtable slot `+0x298`: the return
    /// value is the part of the request that could not be removed. A carrier
    /// exists only when at least one unit was removed.
    public struct PhaseTwoInventoryWithdrawal: Sendable, Hashable, Codable {
        public let requestedUnits: Int
        public let unfulfilledUnits: Int

        public var cargoUnits: Int {
            max(0, requestedUnits - min(requestedUnits, max(0, unfulfilledUnits)))
        }

        public var createsCarrier: Bool { cargoUnits > 0 }

        public init(requestedUnits: Int, unfulfilledUnits: Int) {
            self.requestedUnits = max(0, requestedUnits)
            self.unfulfilledUnits = max(0, unfulfilledUnits)
        }
    }

    /// One multipart target point produced by `FUN_00567540` for source
    /// search. The original ranks by sub-building origin, but starts the BFS
    /// at the separately recovered road-access point.
    public struct PhaseTwoTargetAccessCandidate: Sendable, Hashable, Codable {
        public let subBuildingIndex: Int
        public let worldOrigin: GridPoint
        public let roadAccessPoint: GridPoint

        public init(
            subBuildingIndex: Int,
            worldOrigin: GridPoint,
            roadAccessPoint: GridPoint
        ) {
            self.subBuildingIndex = subBuildingIndex
            self.worldOrigin = worldOrigin
            self.roadAccessPoint = roadAccessPoint
        }
    }

    /// One coordinator request considered by `FUN_0056ED10` after a phase-2
    /// material carrier reaches the monument. Equal-distance requests retain
    /// this array's authored/coordinator enumeration order.
    public struct PhaseTwoPendingMaterialRequest: Sendable, Hashable, Codable {
        public let requestID: Int
        public let commodityID: Int
        public let targetPoint: GridPoint
        public var remainingUnits: Int

        public init(
            requestID: Int,
            commodityID: Int,
            targetPoint: GridPoint,
            remainingUnits: Int
        ) {
            self.requestID = requestID
            self.commodityID = commodityID
            self.targetPoint = targetPoint
            self.remainingUnits = max(0, remainingUnits)
        }
    }

    public struct PhaseTwoCarrierDelivery: Sendable, Hashable, Codable {
        public let requestID: Int
        public let deliveredUnits: Int

        public init(requestID: Int, deliveredUnits: Int) {
            self.requestID = requestID
            self.deliveredUnits = deliveredUnits
        }
    }

    public struct PhaseTwoCarrierAllocation: Sendable, Hashable, Codable {
        public let deliveries: [PhaseTwoCarrierDelivery]
        public let remainingCargoUnits: Int

        public init(
            deliveries: [PhaseTwoCarrierDelivery],
            remainingCargoUnits: Int
        ) {
            self.deliveries = deliveries
            self.remainingCargoUnits = max(0, remainingCargoUnits)
        }
    }

    public struct PhaseTwoDispatchBatch: Sendable, Hashable, Codable {
        public let commodityID: Int
        public let requestedUnits: Int
        public let assignedRequests: [PhaseTwoPendingMaterialRequest]

        public init(
            commodityID: Int,
            requestedUnits: Int,
            assignedRequests: [PhaseTwoPendingMaterialRequest]
        ) {
            self.commodityID = commodityID
            self.requestedUnits = max(0, requestedUnits)
            self.assignedRequests = assignedRequests
        }
    }

    /// Save-safe projection of the coordinator's unbound and carrier-bound
    /// material containers. `requestID` is the Native-stable Grand Canal
    /// sub-building index; the original runtime object IDs are allocator
    /// identities and are not serialized by the decoded archive subset.
    public struct PhaseTwoCoordinatorRuntime: Sendable, Hashable, Codable {
        public var pendingRequests: [PhaseTwoPendingMaterialRequest]
        public var carrierBoundRequests: [PhaseTwoPendingMaterialRequest]
        private var nextFigureIDState: Int?

        public var nextFigureID: Int { nextFigureIDState ?? 1 }

        public init(
            pendingRequests: [PhaseTwoPendingMaterialRequest] = [],
            carrierBoundRequests: [PhaseTwoPendingMaterialRequest] = [],
            nextFigureID: Int = 1
        ) {
            self.pendingRequests = pendingRequests
            self.carrierBoundRequests = carrierBoundRequests
            nextFigureIDState = max(1, nextFigureID)
        }

        /// `FUN_0056EA60` allocates the carrier followed by its two helpers.
        /// Native keeps this allocator inside the save-safe coordinator so a
        /// mid-route save/reload cannot reuse convoy identities.
        public mutating func reserveConvoyFigureIDs() -> (Int, Int, Int) {
            let carrier = nextFigureID
            nextFigureIDState = carrier + 3
            return (carrier, carrier + 1, carrier + 2)
        }

        /// Mirrors the authored-part scan for the stone phase. Existing
        /// records in either container suppress duplicates; phase and amount
        /// come directly from each decoded `cMonInfo` state.
        public mutating func enqueueMissingRequests(
            from parts: [GrandCanalMapPartState]
        ) {
            var represented = Set(
                pendingRequests.map(\.requestID)
                    + carrierBoundRequests.map(\.requestID)
            )
            for part in parts.sorted(by: { $0.subBuildingIndex < $1.subBuildingIndex }) {
                guard part.currentSubBuildingPhase == 2,
                      part.remainingPhaseTwoStoneUnits > 0,
                      represented.insert(part.subBuildingIndex).inserted else { continue }
                pendingRequests.append(
                    PhaseTwoPendingMaterialRequest(
                        requestID: part.subBuildingIndex,
                        commodityID: OriginalGrandCanalLayoutCatalog
                            .phaseTwoStoneCommodityID,
                        targetPoint: part.worldOrigin,
                        remainingUnits: part.remainingPhaseTwoStoneUnits
                    )
                )
            }
        }

        public mutating func dispatchNextBatch(
            carrierCreated: Bool
        ) -> PhaseTwoDispatchBatch? {
            let batch = OriginalGrandCanalLayoutCatalog.dispatchPhaseTwoMaterialBatch(
                pendingRequests: &pendingRequests,
                carrierCreated: carrierCreated
            )
            if carrierCreated, let batch {
                carrierBoundRequests.append(contentsOf: batch.assignedRequests)
            }
            return batch
        }

        public mutating func allocateCarrierCargo(
            cargoUnits: Int,
            commodityID: Int,
            currentPoint: GridPoint,
            parts: inout [GrandCanalMapPartState]
        ) -> PhaseTwoCarrierAllocation {
            let allocation = OriginalGrandCanalLayoutCatalog.allocatePhaseTwoCarrierCargo(
                cargoUnits: cargoUnits,
                commodityID: commodityID,
                currentPoint: currentPoint,
                pendingRequests: &carrierBoundRequests
            )
            for delivery in allocation.deliveries {
                guard let index = parts.firstIndex(where: {
                    $0.subBuildingIndex == delivery.requestID
                }) else { continue }
                _ = parts[index].acceptPhaseTwoStoneCargo(delivery.deliveredUnits)
            }
            return allocation
        }
    }

    public struct PhaseTwoReturnProvider: Sendable, Hashable, Codable {
        public let objectID: Int
        public let buildingID: Int
        public let roadAccessPoint: GridPoint

        public init(objectID: Int, buildingID: Int, roadAccessPoint: GridPoint) {
            self.objectID = objectID
            self.buildingID = buildingID
            self.roadAccessPoint = roadAccessPoint
        }
    }

    /// Raw carrier states dispatched by the original figure-type-19 primary
    /// update at `FUN_004CBEC0`. These names cover only the source-confirmed
    /// Grand Canal phase-2 path; other cart branches remain outside this type.
    public enum PhaseTwoCarrierState: Int, Sendable, Hashable, Codable {
        case routeFallback = 6
        case returningWithCargo = 7
        case returningToAlternateSource = 9
        case restoringCargoAtSource = 10
        case emptyArrivalCleanup = 12
        case returningEmpty = 13
        case travelingToMonument = 19
        case allocatingAtMonument = 20
    }

    public struct PhaseTwoConvoyHelper: Sendable, Hashable, Codable {
        public let figureID: Int
        public let state: Int
        public var isActive: Bool
        /// Optional fields preserve Native saves written before linked
        /// type-20 follower movement was connected.
        private var currentPointState: GridPoint?
        private var previousPointState: GridPoint?
        private var movementPhaseState: Int?
        private var animationFrameState: Int?

        public var currentPoint: GridPoint? { currentPointState }
        public var previousPoint: GridPoint? { previousPointState }
        public var movementPhase: Int { movementPhaseState ?? 0 }
        public var animationFrame: Int { animationFrameState ?? 0 }

        public init(
            figureID: Int,
            state: Int,
            isActive: Bool = true,
            currentPoint: GridPoint? = nil
        ) {
            self.figureID = figureID
            self.state = state
            self.isActive = isActive
            currentPointState = currentPoint
            previousPointState = nil
            movementPhaseState = 0
            animationFrameState = 0
        }

        mutating func follow(
            predecessorPoint: GridPoint,
            predecessorPhase: Int,
            predecessorAnimationFrame: Int,
            lag: Int,
            fallbackPoint: GridPoint
        ) {
            let oldPoint = currentPointState ?? fallbackPoint
            let phase = ((predecessorPhase - lag) % 20 + 20) % 20
            movementPhaseState = phase
            animationFrameState = predecessorAnimationFrame
            if (phase == 10 || phase == 11), oldPoint != predecessorPoint {
                previousPointState = oldPoint
                currentPointState = predecessorPoint
            }
        }
    }

    public enum PhaseTwoSourceAdvance: Sendable, Hashable, Codable {
        case waiting
        case sourceTransferDue(cargoUnits: Int)
        case destroyedEmpty
    }

    public enum PhaseTwoSourceTransferOutcome: Sendable, Hashable, Codable {
        case fullyAccepted(units: Int)
        case partiallyAcceptedAndRerouted(units: Int, providerObjectID: Int)
        case partiallyAcceptedAwaitingProvider(units: Int)
    }

    public enum PhaseTwoFallbackAdvance: Sendable, Hashable, Codable {
        case waiting
        case rerouted(providerObjectID: Int)
        case noProvider
    }

    /// Save-safe semantic projection of the type-19 carrier and its two
    /// type-20 followers created by `FUN_0056EA60`. Figure movement and route
    /// buffers remain owned by the city figure system; this model preserves
    /// the recovered state transitions and inventory consequences.
    public struct PhaseTwoCarrierConvoyRuntime: Sendable, Hashable, Codable {
        public let carrierFigureID: Int
        public let sourceObjectID: Int
        public let sourceBuildingID: Int
        public let commodityID: Int
        public let sourceOrigin: GridPoint
        public let monumentAccessPoint: GridPoint
        public var currentTargetObjectID: Int
        public var currentTargetBuildingID: Int
        public var currentTargetPoint: GridPoint
        public var cargoUnits: Int
        public var carrierState: PhaseTwoCarrierState
        public var stateCounter: Int
        public var isCarrierActive: Bool
        public var sourceRequestFlagRestored: Bool
        public var helpers: [PhaseTwoConvoyHelper]
        /// Optional backing preserves Native saves written before live
        /// phase-two movement was connected. Such saves resume at the source.
        private var currentPointState: GridPoint?
        private var previousPointState: GridPoint?
        private var animationFrameState: Int?
        /// Uses the same serialized route-buffer projection as phase labor;
        /// the route itself is nevertheless built by the distinct mode-7
        /// passability contract.
        public var movement: PhaseLaborMovementRuntime?

        public var currentPoint: GridPoint {
            get { currentPointState ?? sourceOrigin }
            set { currentPointState = newValue }
        }
        public var previousPoint: GridPoint? { previousPointState }
        public var animationFrame: Int { animationFrameState ?? 0 }
        public var movementPhase: Int { movement?.substepProgress ?? 0 }

        public init(
            carrierFigureID: Int,
            firstHelperFigureID: Int,
            secondHelperFigureID: Int,
            sourceObjectID: Int,
            sourceBuildingID: Int,
            commodityID: Int,
            sourceOrigin: GridPoint,
            monumentObjectID: Int = 0,
            monumentAccessPoint: GridPoint,
            cargoUnits: Int
        ) {
            self.carrierFigureID = carrierFigureID
            self.sourceObjectID = sourceObjectID
            self.sourceBuildingID = sourceBuildingID
            self.commodityID = commodityID
            self.sourceOrigin = sourceOrigin
            self.monumentAccessPoint = monumentAccessPoint
            currentTargetObjectID = monumentObjectID
            currentTargetBuildingID = OriginalGrandCanalLayoutCatalog.buildingID
            currentTargetPoint = monumentAccessPoint
            self.cargoUnits = max(0, cargoUnits)
            carrierState = .travelingToMonument
            stateCounter = OriginalGrandCanalLayoutCatalog
                .phaseTwoCarrierInitialStateCounter
            isCarrierActive = cargoUnits > 0
            sourceRequestFlagRestored = false
            currentPointState = sourceOrigin
            previousPointState = nil
            animationFrameState = 0
            movement = nil
            helpers = [
                PhaseTwoConvoyHelper(
                    figureID: firstHelperFigureID,
                    state: OriginalGrandCanalLayoutCatalog.phaseTwoStoneFirstHelperState,
                    isActive: cargoUnits > 0,
                    currentPoint: sourceOrigin
                ),
                PhaseTwoConvoyHelper(
                    figureID: secondHelperFigureID,
                    state: OriginalGrandCanalLayoutCatalog.phaseTwoStoneSecondHelperState,
                    isActive: cargoUnits > 0,
                    currentPoint: sourceOrigin
                ),
            ]
        }

        /// Runs after the type-19 update and in linked figure-ID order,
        /// matching carrier → follower 1 → follower 2 in the original pass.
        public mutating func advanceAnimationAndFollowers() {
            guard isCarrierActive else { return }
            animationFrameState = (animationFrame + 1) % 12
            guard helpers.count >= 2 else { return }
            helpers[0].follow(
                predecessorPoint: currentPoint,
                predecessorPhase: movementPhase,
                predecessorAnimationFrame: animationFrame,
                lag: OriginalGrandCanalLayoutCatalog.phaseTwoFirstFollowerLag,
                fallbackPoint: sourceOrigin
            )
            helpers[1].follow(
                predecessorPoint: helpers[0].currentPoint ?? sourceOrigin,
                predecessorPhase: helpers[0].movementPhase,
                predecessorAnimationFrame: helpers[0].animationFrame,
                lag: OriginalGrandCanalLayoutCatalog.phaseTwoSecondFollowerLag,
                fallbackPoint: sourceOrigin
            )
        }

        /// Direction 8 in the original movement result. Arrival at the
        /// monument and arrival back at the source are deliberately separate
        /// ticks, matching the raw state dispatcher.
        public mutating func recordMovementArrival() {
            guard isCarrierActive else { return }
            switch carrierState {
            case .travelingToMonument:
                carrierState = .allocatingAtMonument
            case .returningWithCargo, .returningToAlternateSource:
                guard OriginalGrandCanalLayoutCatalog.phaseTwoMaterialSourceBuildingIDs
                    .contains(currentTargetBuildingID) else {
                    return
                }
                carrierState = .restoringCargoAtSource
            case .returningEmpty:
                carrierState = .emptyArrivalCleanup
            case .routeFallback, .allocatingAtMonument,
                    .restoringCargoAtSource, .emptyArrivalCleanup:
                return
            }
            stateCounter = 0
            movement = nil
        }

        /// Advances one type-19 figure update. Existing routes are retained
        /// across updates, while a changed target rebuilds through movement
        /// mode 7. A missing route leaves the convoy unchanged: dispatch
        /// validates the complete route before inventory mutation, and the
        /// dynamic route-loss consequence remains a separate recovered state
        /// transition rather than an invented retry policy here.
        @discardableResult
        public mutating func advanceMovement(
            routingGrids: WorkerRoutingGrids
        ) -> Bool {
            guard isCarrierActive,
                  carrierState == .travelingToMonument
                    || carrierState == .returningWithCargo
                    || carrierState == .returningToAlternateSource
                    || carrierState == .returningEmpty else { return false }
            if currentPoint == currentTargetPoint {
                recordMovementArrival()
                return false
            }
            guard let movementRule = OriginalGrandCanalLayoutCatalog
                .workerMovementRules.first(where: {
                    $0.figureID == OriginalGrandCanalLayoutCatalog
                        .phaseTwoCarrierFigureType
                }) else { return false }
            var runtime = movement
            if runtime.map({ movement in
                !movement.route.points.indices.contains(movement.routeIndex)
                    || movement.route.points[movement.routeIndex] != currentPoint
            }) ?? true || runtime?.route.points.last != currentTargetPoint {
                guard let route = OriginalGrandCanalLayoutCatalog.phaseTwoCarrierRoute(
                    primaryValues: routingGrids.primaryPassability,
                    width: routingGrids.width,
                    height: routingGrids.height,
                    from: currentPoint,
                    to: currentTargetPoint
                ) else {
                    movement = nil
                    return false
                }
                runtime = PhaseLaborMovementRuntime(
                    route: route,
                    substepProgress: movementRule.initialSubstepProgress
                )
            }
            guard var runtime else { return false }
            let cycle = movementRule.substepsPerFigureUpdateCycle
            let cycleIndex = runtime.speedCycleIndex % cycle.count
            runtime.substepProgress += cycle[cycleIndex]
            runtime.speedCycleIndex = (cycleIndex + 1) % cycle.count
            var moved = false
            if runtime.substepProgress >= movementRule.substepsPerRouteStep,
               runtime.routeIndex + 1 < runtime.route.points.count {
                runtime.routeIndex += 1
                runtime.substepProgress = 0
                previousPointState = currentPoint
                currentPoint = runtime.route.points[runtime.routeIndex]
                moved = true
            }
            movement = runtime
            if currentPoint == currentTargetPoint {
                recordMovementArrival()
            }
            return moved
        }

        public mutating func allocateAtMonument(
            currentPoint: GridPoint,
            pendingRequests: inout [PhaseTwoPendingMaterialRequest]
        ) -> PhaseTwoCarrierAllocation? {
            guard isCarrierActive, carrierState == .allocatingAtMonument else {
                return nil
            }
            let allocation = OriginalGrandCanalLayoutCatalog.allocatePhaseTwoCarrierCargo(
                cargoUnits: cargoUnits,
                commodityID: commodityID,
                currentPoint: currentPoint,
                pendingRequests: &pendingRequests
            )
            cargoUnits = allocation.remainingCargoUnits
            carrierState = cargoUnits > 0 ? .returningWithCargo : .returningEmpty
            stateCounter = 0
            currentTargetObjectID = sourceObjectID
            currentTargetBuildingID = sourceBuildingID
            currentTargetPoint = sourceOrigin
            movement = nil
            return allocation
        }

        /// Advances states 10 and 12. State 10 waits through counter 10 and
        /// asks the source inventory how much it can accept on the update that
        /// raises the counter to 11. The caller must then record the inventory
        /// result; state 12 kills an empty carrier on its next update.
        public mutating func advanceAtSource() -> PhaseTwoSourceAdvance? {
            guard isCarrierActive else { return nil }
            switch carrierState {
            case .restoringCargoAtSource:
                stateCounter += 1
                guard stateCounter > OriginalGrandCanalLayoutCatalog
                    .phaseTwoSourceReturnDelay else {
                    return .waiting
                }
                return .sourceTransferDue(cargoUnits: cargoUnits)
            case .emptyArrivalCleanup where cargoUnits == 0:
                isCarrierActive = false
                return .destroyedEmpty
            case .routeFallback, .travelingToMonument, .allocatingAtMonument,
                    .returningWithCargo, .returningToAlternateSource,
                    .returningEmpty, .emptyArrivalCleanup:
                return nil
            }
        }

        /// Records source vtable `+0x154`'s accepted amount. Full acceptance
        /// clears cargo and selects raw state 13. Partial acceptance subtracts
        /// only that amount and follows the provider returned by
        /// `FUN_004E2960`, or enters state 6 when no provider exists.
        public mutating func recordSourceTransfer(
            acceptedUnits: Int,
            nextProvider: PhaseTwoReturnProvider?
        ) -> PhaseTwoSourceTransferOutcome? {
            guard isCarrierActive,
                  carrierState == .restoringCargoAtSource,
                  stateCounter > OriginalGrandCanalLayoutCatalog.phaseTwoSourceReturnDelay,
                  cargoUnits > 0 else { return nil }
            let accepted = min(cargoUnits, max(0, acceptedUnits))
            cargoUnits -= accepted
            stateCounter = 0
            if cargoUnits == 0 {
                carrierState = .returningEmpty
                currentTargetObjectID = sourceObjectID
                currentTargetBuildingID = sourceBuildingID
                currentTargetPoint = sourceOrigin
                movement = nil
                return .fullyAccepted(units: accepted)
            }
            guard let nextProvider,
                  OriginalGrandCanalLayoutCatalog.phaseTwoMaterialSourceBuildingIDs
                    .contains(nextProvider.buildingID) else {
                carrierState = .routeFallback
                return .partiallyAcceptedAwaitingProvider(units: accepted)
            }
            currentTargetObjectID = nextProvider.objectID
            currentTargetBuildingID = nextProvider.buildingID
            currentTargetPoint = nextProvider.roadAccessPoint
            movement = nil
            carrierState = nextProvider.buildingID == 54
                ? .returningWithCargo
                : .returningToAlternateSource
            return .partiallyAcceptedAndRerouted(
                units: accepted,
                providerObjectID: nextProvider.objectID
            )
        }

        /// State 6 retries destination selection on the update that raises its
        /// counter from 30 to 31. Provider discovery order remains a caller
        /// input until `FUN_004E2960`'s complete stone-specific search chain is
        /// recovered and connected to live city inventories.
        public mutating func advanceRouteFallback(
            nextProvider: PhaseTwoReturnProvider?
        ) -> PhaseTwoFallbackAdvance? {
            guard isCarrierActive, carrierState == .routeFallback else { return nil }
            stateCounter += 1
            guard stateCounter > OriginalGrandCanalLayoutCatalog
                .phaseTwoFallbackProviderSearchDelay else {
                return .waiting
            }
            stateCounter = 0
            guard let nextProvider,
                  OriginalGrandCanalLayoutCatalog.phaseTwoMaterialSourceBuildingIDs
                    .contains(nextProvider.buildingID) else {
                return .noProvider
            }
            currentTargetObjectID = nextProvider.objectID
            currentTargetBuildingID = nextProvider.buildingID
            currentTargetPoint = nextProvider.roadAccessPoint
            movement = nil
            // State 6 uses `FUN_005D36E0`, which classifies 54/56/58 alike
            // after the separate mill-53 branch.
            carrierState = .returningWithCargo
            return .rerouted(providerObjectID: nextProvider.objectID)
        }

        /// Direction 9 releases the current route. In raw states 19 and 7,
        /// the original then falls to state 6 unless the current primary-grid
        /// value contains bit `0x8`; state 13 keeps its state. The recovered
        /// primary-grid writers never produce `0x8`, but the input remains
        /// explicit so this reducer mirrors the machine predicate.
        public mutating func recordRouteBlocked(currentPrimaryGridValue: UInt16) {
            guard isCarrierActive else { return }
            switch carrierState {
            case .travelingToMonument, .returningWithCargo,
                    .returningToAlternateSource:
                if currentPrimaryGridValue
                    & OriginalGrandCanalLayoutCatalog.phaseTwoBlockedRouteRetentionMask == 0 {
                    carrierState = .routeFallback
                }
                stateCounter = 0
            case .returningEmpty:
                return
            case .routeFallback, .allocatingAtMonument,
                    .restoringCargoAtSource, .emptyArrivalCleanup:
                return
            }
        }

        /// Direction 10 destroys this carrier. Only the outbound state calls
        /// `FUN_005688F0(..., 1)` first, restoring the source request flag.
        public mutating func recordRouteUnavailable() {
            guard isCarrierActive else { return }
            switch carrierState {
            case .travelingToMonument:
                sourceRequestFlagRestored = true
                isCarrierActive = false
            case .returningWithCargo, .returningToAlternateSource, .returningEmpty:
                isCarrierActive = false
            case .routeFallback, .allocatingAtMonument,
                    .restoringCargoAtSource, .emptyArrivalCleanup:
                return
            }
        }

        /// Type-20 followers discover the dead lead through their link chain
        /// on their own update rather than in the carrier's destruction call.
        public mutating func updateHelperLiveness() {
            guard !isCarrierActive else { return }
            for index in helpers.indices {
                helpers[index].isActive = false
            }
        }
    }

    public struct EfficiencyCapacityPenalty: Sendable, Hashable, Codable {
        public let efficiencyBelow: Int
        public let capacityPenalty: Int
    }

    public struct WorkerMovementRule: Sendable, Hashable, Codable {
        public let figureID: Int
        public let figureModelSpeedValue: Int
        public let relativeSpeedNumerator: Int
        public let relativeSpeedDenominator: Int
        public let substepsPerFigureUpdateCycle: [Int]
        public let substepsPerRouteStep: Int
        public let initialSubstepProgress: Int
    }

    public struct WorkerPathfindingRule: Sendable, Hashable, Codable {
        public let primaryMovementMode: Int
        public let primaryPassabilityMask: Int
        public let primaryAdmitsNonzeroMaskIntersection: Bool
        public let fallbackMovementMode: Int
        public let fallbackRuntimeCellMask: Int
        public let fallbackAdmitsNonzeroMaskIntersection: Bool
        public let fallbackMaximumExpansions: Int
        public let cardinalBreadthFirstSearch: Bool
        public let maximumStoredDirections: Int
        public let firstPathBufferSlot: Int
        public let lastPathBufferSlot: Int
        public let blockedDirection: Int
        public let unreachableDirection: Int
        public let retainsRouteWhileBlocked: Bool
        public let retriesUnreachableRouteOnNextUpdate: Bool
        public let usesFigureCollisionLinking: Bool
    }

    public enum WorkerRoutingGrid: String, Sendable, Hashable, Codable {
        case primaryPassability
        case fallbackCellClass
    }

    /// Read-only serialization and cache-invalidation boundary recovered from
    /// the original executable. This intentionally records how the routing
    /// inputs are sourced without pretending that a terrain word itself is a
    /// worker passability value.
    public struct WorkerRoutingGridRule: Sendable, Hashable, Codable {
        public let gridSide: Int
        public let serializedTerrainCellByteCount: Int
        public let primaryCellByteCount: Int
        public let fallbackCellByteCount: Int
        public let primaryResetValue: UInt16
        public let fallbackResetValue: UInt32
        public let serializedTerrainLoadsDirectlyIntoRuntimeLayer: Bool
        public let derivedGridsAreSerialized: Bool
        public let liveBuildingOccupancyParticipates: Bool
        public let fullRebuildOrder: [WorkerRoutingGrid]
        public let localRebuildOrder: [WorkerRoutingGrid]
    }

    /// Confirmed primary-grid classes that affect monument-worker routing.
    /// This is evidence only; it is not a complete port of `FUN_005AD440`.
    public struct PrimaryRoutingClassRule: Sendable, Hashable, Codable {
        public let baseProducedValues: [UInt16]
        public let postprocessedProducedMasks: [UInt16]
        public let admittedProducedValues: [UInt16]
        public let admittedMaskBitsWithoutRecoveredProducer: [UInt16]
        public let bareLandValue: UInt16
        public let roadValue: UInt16
        public let blockedValue: UInt16
        public let roadOnTerrainBit0x400Value: UInt16
        public let ferryBuildingID: Int
        public let ferryFootprintSide: Int
        public let ferryFootprintMask: UInt16
        public let ferryConnectorMask: UInt16
        public let ferryConnectorDirectionCodes: [Int]
        public let ferryPostprocessingRunsAfterBaseDerivation: Bool
    }

    /// Exact output domain and authored building-ID branches recovered from
    /// `FUN_005223B0`. Names remain structural where the original vtable
    /// predicate has not yet been given a player-facing semantic meaning.
    public struct FallbackRoutingClassRule: Sendable, Hashable, Codable {
        public let producedValues: [UInt32]
        public let admittedProducedValues: [UInt32]
        public let rejectedProducedValues: [UInt32]
        public let ordinaryTerrainValue: UInt32
        public let waterValue: UInt32
        public let unavailableValue: UInt32
        public let roadWaterAuxiliaryValue: UInt32
        public let terrainBit0x400Value: UInt32
        public let wallValue: UInt32
        public let fixedValue2BuildingIDs: [Int]
        public let fixedValue4BuildingIDs: [Int]
        public let roadConditionalValue4BuildingIDs: [Int]
        public let grandCanalBuildingID: Int
        public let grandCanalInactiveValue: UInt32
        public let grandCanalActiveWithoutRoadValue: UInt32
        public let grandCanalActiveWithRoadValue: UInt32
        public let monumentStateBuildingOffset: Int
        public let monumentStateAccessorVtableOffset: Int
        public let monumentSubBuildingPhaseOffset: Int
        public let grandCanalActivePhaseLowerBound: Int
        public let cityGateBuildingID: Int
        public let cityGateValue: UInt32
        public let towerBuildingID: Int
        public let towerValue: UInt32
        public let greatWallBuildingIDs: ClosedRange<Int>
        public let greatWallCandidateValues: [UInt32]
    }

    public struct WorkerRoute: Sendable, Hashable, Codable {
        public let grid: WorkerRoutingGrid
        public let points: [GridPoint]
        public let directionCodes: [Int]
    }

    /// Live object information consumed by the two original routing-cache
    /// builders. The map terrain word only says that a cell is occupied; the
    /// object grid supplies the building ID and monument state separately.
    public struct WorkerRoutingCellOccupancy: Sendable, Hashable {
        public let buildingID: Int
        public let currentMonumentSubBuildingPhase: Int?
        public let greatWallRootSubBuildingPhase: Int?
        public let greatWallPartKind: OriginalGreatWallLayoutCatalog.SubBuildingKind?
        /// Result of the building vtable predicate at slot `+0xCC`. It is only
        /// consulted for building IDs without an explicit recovered branch.
        public let genericFootprintPredicate: Bool?

        public init(
            buildingID: Int,
            currentMonumentSubBuildingPhase: Int? = nil,
            greatWallRootSubBuildingPhase: Int? = nil,
            greatWallPartKind: OriginalGreatWallLayoutCatalog.SubBuildingKind? = nil,
            genericFootprintPredicate: Bool? = nil
        ) {
            self.buildingID = buildingID
            self.currentMonumentSubBuildingPhase = currentMonumentSubBuildingPhase
            self.greatWallRootSubBuildingPhase = greatWallRootSubBuildingPhase
            self.greatWallPartKind = greatWallPartKind
            self.genericFootprintPredicate = genericFootprintPredicate
        }
    }

    /// Exact source layers needed by `FUN_005AD440` and `FUN_005223B0` for a
    /// single cell. Optional values stay nil until their independent runtime
    /// layer has been recovered; derivation only fails when a taken branch
    /// actually reads that value.
    public struct WorkerRoutingCellInput: Sendable, Hashable {
        public let point: GridPoint
        public let terrainRawValue: UInt32
        public let occupancy: WorkerRoutingCellOccupancy?
        public let roadWaterAuxiliaryByte: UInt8?
        public let primaryElevationClassByte: Int8?
        public let primarySurfaceObjectIsAbsentOrNonblocking: Bool?

        public init(
            point: GridPoint,
            terrainRawValue: UInt32,
            occupancy: WorkerRoutingCellOccupancy? = nil,
            roadWaterAuxiliaryByte: UInt8? = nil,
            primaryElevationClassByte: Int8? = nil,
            primarySurfaceObjectIsAbsentOrNonblocking: Bool? = nil
        ) {
            self.point = point
            self.terrainRawValue = terrainRawValue
            self.occupancy = occupancy
            self.roadWaterAuxiliaryByte = roadWaterAuxiliaryByte
            self.primaryElevationClassByte = primaryElevationClassByte
            self.primarySurfaceObjectIsAbsentOrNonblocking =
                primarySurfaceObjectIsAbsentOrNonblocking
        }
    }

    public struct WorkerRoutingCellValues: Sendable, Hashable {
        public let primaryPassability: UInt16
        public let fallbackCellClass: UInt32
    }

    public struct WorkerRoutingGrids: Sendable, Hashable {
        public let width: Int
        public let height: Int
        public let primaryPassability: [UInt16]
        public let fallbackCellClass: [UInt32]
    }

    public enum WorkerRoutingCacheDerivationError: Error, Sendable, Hashable {
        case invalidGridDimensions
        case duplicateOccupancy(GridPoint)
        case missingRoadWaterAuxiliary(GridPoint)
        case missingPrimaryElevationClass(GridPoint)
        case missingPrimarySurfaceObjectState(GridPoint)
        case missingBuildingOccupancy(GridPoint)
        case missingMonumentPhase(GridPoint, buildingID: Int)
        case missingGenericFootprintPredicate(GridPoint, buildingID: Int)
        case unsupportedPrimaryBuilding(GridPoint, buildingID: Int)
        case unsupportedGreatWallSubtype(GridPoint, buildingID: Int)
    }

    public enum SchedulerCallOutcome: Sendable, Hashable {
        case waiting
        case maintainedPhaseLabor(
            pendingCount: Int,
            activeLaborerCount: Int,
            dispatchedFigureID: Int?
        )
        case maintainedPhaseTwoMaterialRequests(
            pendingCount: Int,
            carrierBoundCount: Int
        )
        case automaticallyAdvancedSubBuildings(indices: [Int])
        case advancedWholeMonumentPhase(from: Int, to: Int)
        case alreadyComplete
    }

    public enum SchedulerError: Error, Sendable, Hashable {
        case malformedPartCollection
        case unsupportedConstructionPhase(Int)
    }

    public struct MapPlacement: Sendable, Hashable, Codable {
        public let origin: GridPoint
        public let quarterTurnsClockwise: Int

        public init(origin: GridPoint, quarterTurnsClockwise: Int) {
            self.origin = origin
            self.quarterTurnsClockwise = quarterTurnsClockwise
        }
    }

    public struct PlacedSubBuilding: Sendable, Hashable, Codable {
        public let index: Int
        public let worldOrigin: GridPoint
        public let isRoadCrossing: Bool

        public var footprintCells: Set<GridPoint> {
            Set(BuildingFootprint(width: 4, height: 4).points(at: worldOrigin))
        }
    }

    public static let buildingID = 83
    public static let monumentPhaseCount = 5
    /// `FUN_005786E0` returns five and the shared completion predicate
    /// `FUN_00570C50` tests `currentPhase >= phaseCount - 1`. Valid part
    /// phases are therefore 0...4; 5 is the authored range endpoint, not a
    /// state that the vtable setter can write.
    public static let finalCompletedPhaseIndex = monumentPhaseCount - 1
    public static let mapImageBase = EmperorMap.chinaGrandCanalGlobalImageBase
    public static let plannedMapImageID = 201
    public static let archivedRecordStride = 323
    public static let archivedBaseBuildingSchema = 4
    public static let archivedMonumentWrapperSchema = 1
    public static let archivedMonumentStateSchema = 9
    public static let archivedOnSiteLaborerWorkUpdatesOffsetFromBuildingID = 193
    public static let archivedDeliveredStoneUnitsOffsetFromBuildingID = 219
    public static let archivedInitialSubBuildingPhase = 4
    public static let archivedInitialWholeMonumentPhase = 4
    public static let phaseLaborTaskID = 102
    public static let phaseLaborFigureID = 10
    public static let phaseLaborProviderBuildingID = 233
    public static let phaseTwoStoneCommodityID = 20
    public static let phaseTwoMaximumSourceRequestUnits = 400
    public static let phaseTwoCarrierFigureType = 19
    public static let phaseTwoHelperFigureType = 20
    public static let phaseTwoCarrierInitialStateCounter = 30
    public static let phaseTwoStoneFirstHelperState = 6
    public static let phaseTwoStoneSecondHelperState = 8
    public static let phaseTwoFirstFollowerLag = 18
    public static let phaseTwoSecondFollowerLag = 13
    public static let phaseTwoSourceReturnDelay = 10
    public static let phaseTwoFallbackProviderSearchDelay = 30
    public static let phaseTwoBlockedRouteRetentionMask: UInt16 = 0x8
    /// `FUN_005DB4C0` accepts only commodities 1...9, so its special mill-53
    /// branch cannot supply Grand Canal stone (commodity 20).
    public static let phaseTwoExcludedMillBuildingID = 53
    /// `FUN_005D61C0` is exactly the set 54, 56, 58. The authored names are
    /// Warehouse, Trading Quay, and Trading Station respectively.
    public static let phaseTwoMaterialSourceBuildingIDs = [54, 56, 58]
    public static let phaseTwoTradeSourceBuildingIDs = [56, 58]
    public static let phaseTwoRejectedTradeCommodityStates = [7, 9]
    /// `SB_CANAL.txt` phase 0/1 animation-record `ticks` columns. The model
    /// loader `FUN_004484C0` stores this column at record `+0x44`; the on-site
    /// handler sums it through `FUN_00448AC0`.
    public static let onSiteLaborerWorkTicksByPhase: [Int: [Int]] = [
        0: [80, 40, 50, 40],
        1: [50, 40, 80, 10],
    ]
    /// `FUN_00570CD0` returns 50, but `FUN_00570670` uses that counter only
    /// when the current phase has no authored model records. Completion uses
    /// a strict `> 50`, hence 51 updates in that fallback branch.
    public static let missingPhaseModelFallbackWorkUpdates = 51
    public static let sourceInventoryLookupVtableOffset = 0x264
    public static let sourceInventoryWithdrawalVtableOffset = 0x298
    /// `FUN_005B04A0 → FUN_005B0360` enqueues four neighbours in this exact
    /// order. Candidate order remains the active-building enumeration order.
    public static let phaseTwoSourceSearchNeighborOffsets = [
        GridPoint(x: 0, y: -1),
        GridPoint(x: 1, y: 0),
        GridPoint(x: 0, y: 1),
        GridPoint(x: -1, y: 0),
    ]
    /// Nonzero entries from the size-4 row at `0x820038 + 4 * 0x60`, converted
    /// from 228-wide linear offsets to local points. The remaining eight slots
    /// in the original 24-entry row are zero-terminated.
    public static let phaseTwoFourByFourRoadAccessOffsets =
        OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(footprintSide: 4)
    public static let roadAccessOffsetTableSlotCount =
        OriginalMultipartMonumentRoutingCatalog.offsetTableSlotCount
    public static let roadAccessComponentRankLimit =
        OriginalMultipartMonumentRoutingCatalog.componentRankLimit
    public static let phaseRequirements = [
        PhaseRequirement(
            phase: 0,
            kind: .internalWorkTask(id: 102),
            amountPerSubBuilding: 0,
            workerFigureID: 10
        ),
        PhaseRequirement(
            phase: 1,
            kind: .internalWorkTask(id: 102),
            amountPerSubBuilding: 0,
            workerFigureID: 10
        ),
        PhaseRequirement(
            phase: 2,
            kind: .commodity(id: 20),
            amountPerSubBuilding: 400,
            workerFigureID: 82
        ),
    ]

    /// Returns the exact state-14 update threshold for the two laborer phases.
    /// Xi Wang Mu's effect is integer division per record, not a fabricated
    /// global speed multiplier.
    public static func onSiteLaborerWorkUpdates(
        forPhase phase: Int,
        xiWangMuActive: Bool
    ) -> Int? {
        guard let ticks = onSiteLaborerWorkTicksByPhase[phase] else { return nil }
        return ticks.reduce(0) { partial, value in
            partial + (xiWangMuActive ? value / 2 : value)
        }
    }

    /// Parses the original sub-building model format sufficiently to recover
    /// each phase's animation-record tick column. This remains separate from
    /// the construction requirement parser because a zero task-102 amount and
    /// a nonzero on-site animation duration are both original facts.
    public static func parseOnSiteWorkTicks(
        subBuildingModelText: String
    ) -> [Int: [Int]] {
        var currentPhase: Int?
        var result: [Int: [Int]] = [:]
        subBuildingModelText.enumerateLines { rawLine, _ in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("; Phase "),
               let phase = Int(line.dropFirst("; Phase ".count)) {
                currentPhase = phase
                result[phase] = []
                return
            }
            guard let phase = currentPhase,
                  line.hasPrefix("{"), line.hasSuffix("}"), line.contains(",") else {
                return
            }
            let values = line.dropFirst().dropLast().split(separator: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
            guard values.count == 22 else { return }
            result[phase, default: []].append(values[17])
        }
        return result
    }

    /// Returns the one request `FUN_0056E600` may issue from a same-commodity
    /// pending queue during this pass. It merges smaller entries and splits a
    /// larger entry at the original double constant 400; failure to find a
    /// source leaves the pending records in place.
    public static func nextPhaseTwoSourceRequest(
        sameCommodityPendingUnits: [Int]
    ) -> Int? {
        var requested = 0
        for units in sameCommodityPendingUnits where units > 0 {
            requested += min(units, phaseTwoMaximumSourceRequestUnits - requested)
            if requested == phaseTwoMaximumSourceRequestUnits { break }
        }
        return requested > 0 ? requested : nil
    }

    /// Projects `FUN_0056E600`'s pending→carrier-bound queue move. The first
    /// positive record selects the commodity; later records of that commodity
    /// are gathered in enumeration order up to 400. A failed source/carrier
    /// creation leaves the queue byte-for-byte unchanged. Success splits only
    /// the boundary record when necessary and moves the selected prefixes to
    /// the carrier-bound queue returned here.
    public static func dispatchPhaseTwoMaterialBatch(
        pendingRequests: inout [PhaseTwoPendingMaterialRequest],
        carrierCreated: Bool
    ) -> PhaseTwoDispatchBatch? {
        guard let first = pendingRequests.first(where: { $0.remainingUnits > 0 }) else {
            return nil
        }
        let commodityID = first.commodityID
        var remainingCapacity = phaseTwoMaximumSourceRequestUnits
        var assigned: [PhaseTwoPendingMaterialRequest] = []
        var updated: [PhaseTwoPendingMaterialRequest] = []
        updated.reserveCapacity(pendingRequests.count)

        for request in pendingRequests {
            guard request.commodityID == commodityID,
                  request.remainingUnits > 0,
                  remainingCapacity > 0 else {
                updated.append(request)
                continue
            }
            let selectedUnits = min(remainingCapacity, request.remainingUnits)
            assigned.append(
                PhaseTwoPendingMaterialRequest(
                    requestID: request.requestID,
                    commodityID: request.commodityID,
                    targetPoint: request.targetPoint,
                    remainingUnits: selectedUnits
                )
            )
            remainingCapacity -= selectedUnits
            if request.remainingUnits > selectedUnits {
                updated.append(
                    PhaseTwoPendingMaterialRequest(
                        requestID: request.requestID,
                        commodityID: request.commodityID,
                        targetPoint: request.targetPoint,
                        remainingUnits: request.remainingUnits - selectedUnits
                    )
                )
            }
        }

        let requestedUnits = assigned.reduce(0) { $0 + $1.remainingUnits }
        guard requestedUnits > 0 else { return nil }
        guard carrierCreated else {
            return PhaseTwoDispatchBatch(
                commodityID: commodityID,
                requestedUnits: requestedUnits,
                assignedRequests: []
            )
        }
        pendingRequests = updated
        return PhaseTwoDispatchBatch(
            commodityID: commodityID,
            requestedUnits: requestedUnits,
            assignedRequests: assigned
        )
    }

    /// Exact non-path predicates used by `FUN_005D3A40` for the strict
    /// monument-material call from `FUN_0056EA60`. The ultimate provider is
    /// still chosen through the original route selector, so this predicate is
    /// deliberately not an automatic source-selection implementation.
    public static func isEligiblePhaseTwoMaterialSource(
        _ candidate: PhaseTwoMaterialSourceCandidate,
        requestingObjectID: Int,
        requestedUnits: Int
    ) -> Bool {
        guard requestedUnits > 0,
              candidate.isActive,
              candidate.objectID != requestingObjectID,
              phaseTwoMaterialSourceBuildingIDs.contains(candidate.buildingID),
              candidate.availableStoneUnits >= requestedUnits else {
            return false
        }
        if phaseTwoTradeSourceBuildingIDs.contains(candidate.buildingID) {
            guard let state = candidate.commodityTradeState,
                  !phaseTwoRejectedTradeCommodityStates.contains(state) else {
                return false
            }
        }
        return true
    }

    /// Exact `FUN_005B04A0(..., useMask0x0B0C: 1)` arbitration after
    /// `FUN_005D3A40` has built its ordered candidate-cell array. The start
    /// cell is tested before expansion; cells at equal BFS depth resolve by
    /// the original up/right/down/left queue order, then by candidate array
    /// order when multiple objects share a cell. The caller must supply the
    /// target point selected by the multipart-target branch of `FUN_005D3730`.
    public static func phaseTwoSourceCandidateIndex(
        primaryValues: [UInt16],
        width: Int,
        height: Int,
        from start: GridPoint,
        orderedCandidatePoints: [GridPoint]
    ) -> Int? {
        guard width > 0, height > 0,
              primaryValues.count == width * height,
              start.x >= 0, start.x < width,
              start.y >= 0, start.y < height,
              !orderedCandidatePoints.isEmpty else {
            return nil
        }

        var candidateIndicesByPoint: [GridPoint: [Int]] = [:]
        for (index, point) in orderedCandidatePoints.enumerated() {
            guard point.x >= 0, point.x < width,
                  point.y >= 0, point.y < height else { continue }
            candidateIndicesByPoint[point, default: []].append(index)
        }

        var visited = [Bool](repeating: false, count: primaryValues.count)
        var queue = [start]
        visited[start.y * width + start.x] = true
        var readIndex = 0
        while readIndex < queue.count {
            let point = queue[readIndex]
            readIndex += 1
            if let candidateIndex = candidateIndicesByPoint[point]?.first {
                return candidateIndex
            }
            for offset in phaseTwoSourceSearchNeighborOffsets {
                let next = GridPoint(x: point.x + offset.x, y: point.y + offset.y)
                guard next.x >= 0, next.x < width,
                      next.y >= 0, next.y < height else { continue }
                let index = next.y * width + next.x
                guard !visited[index],
                      primaryValues[index]
                        & UInt16(workerPathfindingRule.primaryPassabilityMask) != 0 else {
                    continue
                }
                visited[index] = true
                queue.append(next)
            }
        }
        return nil
    }

    /// Reproduces the repeated `FUN_00567540` ordering used for a multipart
    /// source request. `FUN_00567130` compares each accessible sub-building's
    /// authored origin with the requesting child object's origin by Manhattan
    /// distance, accepting only a strict improvement; repeated calls exclude
    /// the last result, which is equivalent to this stable ascending order.
    public static func orderedPhaseTwoTargetAccesses(
        requestingSubBuildingOrigin: GridPoint,
        authoredAccessibleCandidates: [PhaseTwoTargetAccessCandidate]
    ) -> [PhaseTwoTargetAccessCandidate] {
        authoredAccessibleCandidates.enumerated().sorted { lhs, rhs in
            let lhsDistance = manhattanDistance(
                lhs.element.worldOrigin,
                requestingSubBuildingOrigin
            )
            let rhsDistance = manhattanDistance(
                rhs.element.worldOrigin,
                requestingSubBuildingOrigin
            )
            return lhsDistance == rhsDistance
                ? lhs.offset < rhs.offset
                : lhsDistance < rhsDistance
        }.map(\.element)
    }

    /// Exact size-4 access arbitration from `FUN_004BA6F0`. The input maps
    /// eligible road cells to the rank of their connected road component:
    /// rank zero is the largest component, and equal-sized components retain
    /// the full-map component-discovery order established by `FUN_004AF350`.
    /// Only the original top ten ranked components participate.
    public static func grandCanalRoadAccessPoint(
        subBuildingOrigin: GridPoint,
        roadComponentRankByPoint: [GridPoint: Int]
    ) -> GridPoint? {
        OriginalMultipartMonumentRoutingCatalog.roadAccessPoint(
            subBuildingOrigin: subBuildingOrigin,
            footprintSide: 4,
            roadComponentRankByPoint: roadComponentRankByPoint
        )
    }

    public static func phaseTwoRoadAccessPoint(
        subBuildingOrigin: GridPoint,
        roadComponentRankByPoint: [GridPoint: Int]
    ) -> GridPoint? {
        grandCanalRoadAccessPoint(
            subBuildingOrigin: subBuildingOrigin,
            roadComponentRankByPoint: roadComponentRankByPoint
        )
    }

    /// Exact request arbitration from `FUN_0056ED10`: repeatedly choose the
    /// nearest positive request for this commodity using Euclidean distance.
    /// The machine comparison is strict, so equal-distance requests keep the
    /// coordinator enumeration order supplied by the caller. Squared distance
    /// preserves that ordering without introducing floating-point rounding.
    public static func allocatePhaseTwoCarrierCargo(
        cargoUnits: Int,
        commodityID: Int,
        currentPoint: GridPoint,
        pendingRequests: inout [PhaseTwoPendingMaterialRequest]
    ) -> PhaseTwoCarrierAllocation {
        var remainingCargo = max(0, cargoUnits)
        var deliveries: [PhaseTwoCarrierDelivery] = []

        while remainingCargo > 0 {
            var selectedIndex: Int?
            var selectedSquaredDistance = Int64.max
            for index in pendingRequests.indices {
                let request = pendingRequests[index]
                guard request.commodityID == commodityID,
                      request.remainingUnits > 0 else { continue }
                let dx = Int64(request.targetPoint.x - currentPoint.x)
                let dy = Int64(request.targetPoint.y - currentPoint.y)
                let squaredDistance = dx * dx + dy * dy
                if squaredDistance < selectedSquaredDistance {
                    selectedIndex = index
                    selectedSquaredDistance = squaredDistance
                }
            }

            guard let selectedIndex else { break }
            let deliveredUnits = min(
                remainingCargo,
                pendingRequests[selectedIndex].remainingUnits
            )
            pendingRequests[selectedIndex].remainingUnits -= deliveredUnits
            remainingCargo -= deliveredUnits
            deliveries.append(
                PhaseTwoCarrierDelivery(
                    requestID: pendingRequests[selectedIndex].requestID,
                    deliveredUnits: deliveredUnits
                )
            )
            if pendingRequests[selectedIndex].remainingUnits == 0 {
                pendingRequests.remove(at: selectedIndex)
            }
        }

        return PhaseTwoCarrierAllocation(
            deliveries: deliveries,
            remainingCargoUnits: remainingCargo
        )
    }

    private static func manhattanDistance(_ lhs: GridPoint, _ rhs: GridPoint) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }

    /// Effective monument-worker slots from `FUN_0056D4D0`. A provider below
    /// 50 efficiency loses all three Laborers' Camp slots; the comparisons are
    /// strict, so efficiencies 50/70/80 enter the next bracket exactly.
    public static func phaseLaborProviderCapacity(efficiencyPercent: Int) -> Int {
        let base = providerCapacityRules.first(where: {
            $0.figureID == phaseLaborFigureID
        })?.baseCapacity ?? 0
        let penalty = efficiencyCapacityPenalties.first(where: {
            efficiencyPercent < $0.efficiencyBelow
        })?.capacityPenalty ?? 0
        return base - penalty
    }

    /// Building 233 installs `FUN_00428ED0` at vtable slot `+0x1B4`:
    /// `(+0x1B8 * 100) / +0x1B0`, returning zero when the required-worker
    /// slot is non-positive. Native workforce assignments supply those two
    /// source-backed values directly.
    public static func phaseLaborProviderEfficiencyPercent(
        requiredWorkers: Int,
        assignedWorkers: Int
    ) -> Int {
        guard requiredWorkers > 0 else { return 0 }
        return max(0, assignedWorkers) * 100 / requiredWorkers
    }

    /// Original isometric distance from `FUN_0056D4D0`:
    /// `max(abs(dx),abs(dy))/2 + min(abs(dx),abs(dy))`.
    public static func phaseLaborProviderDistance(
        from provider: GridPoint,
        to target: GridPoint
    ) -> Int {
        let dx = abs(target.x - provider.x)
        let dy = abs(target.y - provider.y)
        return max(dx, dy) / 2 + min(dx, dy)
    }

    public static func selectPhaseLaborProvider(
        for target: GridPoint,
        candidates: [PhaseLaborProviderCandidate]
    ) -> PhaseLaborProviderCandidate? {
        var selected: PhaseLaborProviderCandidate?
        var selectedDistance = Int.max
        for candidate in candidates where
            candidate.buildingID == phaseLaborProviderBuildingID
                && candidate.isActive
                && candidate.activeMonumentWorkerCount
                    < phaseLaborProviderCapacity(
                        efficiencyPercent: candidate.efficiencyPercent
                    ) {
            let distance = phaseLaborProviderDistance(
                from: candidate.origin,
                to: target
            )
            if distance < selectedDistance {
                selected = candidate
                selectedDistance = distance
            }
        }
        return selected
    }

    public static let phaseBehaviors = [
        PhaseBehavior(
            phase: 0,
            requirement: phaseRequirements[0],
            completion: .workerCompletesAuthoredOnSiteWork
        ),
        PhaseBehavior(
            phase: 1,
            requirement: phaseRequirements[1],
            completion: .workerCompletesAuthoredOnSiteWork
        ),
        PhaseBehavior(
            phase: 2,
            requirement: phaseRequirements[2],
            completion: .commodityAmountDelivered
        ),
        PhaseBehavior(
            phase: 3,
            requirement: nil,
            completion: .automaticAfterOtherQueuesDrain
        ),
        PhaseBehavior(
            phase: 4,
            requirement: nil,
            completion: .automaticAfterOtherQueuesDrain
        ),
    ]
    public static let workerProviders = [
        WorkerProvider(figureID: 10, buildingID: 233),
        WorkerProvider(figureID: 82, buildingID: 235),
    ]
    /// `FUN_0056A910` supplies the normal coordinator limits. Figure IDs
    /// 80...82 share the artisan-worker total while retaining the per-figure
    /// task limits below.
    public static let normalDispatchLimits = DispatchLimits(
        maximumArtisanWorkers: 3,
        maximumLaborerWorkers: 8,
        tasksPerLaborer: 7,
        tasksPerFigure80: 5,
        tasksPerFigure81: 3,
        tasksPerFigure82: 3
    )
    /// `FUN_0056A940` replaces every normal limit with exactly twice its value
    /// while hero effect 3 is active. `EmperorFigureModels.txt` identifies hero
    /// 3 as Xi Wang Mu, and the shipping manual says that her active-city
    /// benefit reduces monument construction time.
    public static let xiWangMuHeroEffectID = 3
    public static let xiWangMuDispatchLimits = DispatchLimits(
        maximumArtisanWorkers: 6,
        maximumLaborerWorkers: 16,
        tasksPerLaborer: 14,
        tasksPerFigure80: 10,
        tasksPerFigure81: 6,
        tasksPerFigure82: 6
    )
    public static let providerCapacityRules = [
        ProviderCapacityRule(figureID: 10, baseCapacity: 3),
        ProviderCapacityRule(figureID: 80, baseCapacity: 1),
        ProviderCapacityRule(figureID: 81, baseCapacity: 1),
        ProviderCapacityRule(figureID: 82, baseCapacity: 1),
    ]
    public static let efficiencyCapacityPenalties = [
        EfficiencyCapacityPenalty(efficiencyBelow: 50, capacityPenalty: 3),
        EfficiencyCapacityPenalty(efficiencyBelow: 70, capacityPenalty: 2),
        EfficiencyCapacityPenalty(efficiencyBelow: 80, capacityPenalty: 1),
    ]
    /// Both Grand Canal worker types use speed value 8 in
    /// `EmperorFigureModels.txt`, whose authored speed table defines it as
    /// 1 1/3. `FUN_004E47A0` realizes that value as a repeating 1, 1, 2
    /// substep sequence. `FUN_004E7EB0` advances a route step after 20
    /// substeps; a newly built route starts at progress 20 so its first
    /// supplied substep advances immediately.
    public static let workerMovementRules = [
        WorkerMovementRule(
            figureID: 10,
            figureModelSpeedValue: 8,
            relativeSpeedNumerator: 4,
            relativeSpeedDenominator: 3,
            substepsPerFigureUpdateCycle: [1, 1, 2],
            substepsPerRouteStep: 20,
            initialSubstepProgress: 20
        ),
        WorkerMovementRule(
            figureID: 82,
            figureModelSpeedValue: 8,
            relativeSpeedNumerator: 4,
            relativeSpeedDenominator: 3,
            substepsPerFigureUpdateCycle: [1, 1, 2],
            substepsPerRouteStep: 20,
            initialSubstepProgress: 20
        ),
        WorkerMovementRule(
            figureID: 19,
            figureModelSpeedValue: 8,
            relativeSpeedNumerator: 4,
            relativeSpeedDenominator: 3,
            substepsPerFigureUpdateCycle: [1, 1, 2],
            substepsPerRouteStep: 20,
            initialSubstepProgress: 20
        ),
    ]
    /// `FUN_0056D690` first assigns common figure movement mode 1. Its route
    /// builder uses cardinal BFS and admits a cell when its derived UInt16
    /// value has a nonzero intersection with `0x0B0C`; when no
    /// path is produced it retries in mode 19 through `MonMap_txt`, whose raw
    /// predicate over the separate runtime cell-class grid is
    /// `cellClass & 0x4C001CCE != 0`. Both paths use the
    /// shared 500-direction figure buffers, allocated from slots 1...999.
    public static let workerPathfindingRule = WorkerPathfindingRule(
        primaryMovementMode: 1,
        primaryPassabilityMask: 0x0B0C,
        primaryAdmitsNonzeroMaskIntersection: true,
        fallbackMovementMode: 19,
        fallbackRuntimeCellMask: 0x4C001CCE,
        fallbackAdmitsNonzeroMaskIntersection: true,
        fallbackMaximumExpansions: 100_000,
        cardinalBreadthFirstSearch: true,
        maximumStoredDirections: 500,
        firstPathBufferSlot: 1,
        lastPathBufferSlot: 999,
        blockedDirection: 9,
        unreachableDirection: 10,
        retainsRouteWhileBlocked: true,
        retriesUnreachableRouteOnNextUpdate: true,
        usesFigureCollisionLinking: false
    )
    /// `FUN_0052E7C0` serializes the 228x228 UInt32 terrain layer directly to
    /// and from the runtime terrain words. The two routing grids are derived
    /// caches: `FUN_005AD8F0` clears and rebuilds the UInt16 primary grid,
    /// followed by `FUN_00522810` clearing and rebuilding the UInt32 fallback
    /// classes. Region invalidation repeats the same order through
    /// `FUN_005AD440` then `FUN_005AD940` after live occupancy changes.
    public static let workerRoutingGridRule = WorkerRoutingGridRule(
        gridSide: EmperorMap.gridSide,
        serializedTerrainCellByteCount: MemoryLayout<UInt32>.size,
        primaryCellByteCount: MemoryLayout<UInt16>.size,
        fallbackCellByteCount: MemoryLayout<UInt32>.size,
        primaryResetValue: 0,
        fallbackResetValue: 0x80000001,
        serializedTerrainLoadsDirectlyIntoRuntimeLayer: true,
        derivedGridsAreSerialized: false,
        liveBuildingOccupancyParticipates: true,
        fullRebuildOrder: [.primaryPassability, .fallbackCellClass],
        localRebuildOrder: [.primaryPassability, .fallbackCellClass]
    )
    /// `FUN_005AD440` produces the base domain recorded below. Its active
    /// Ferry (`building 210`) post-pass calls `FUN_004C6D30`, which ORs `0x800`
    /// over the Ferry's 6x6 footprint and `0x200` along its stored cardinal
    /// connector chain. Both masks are admitted by movement mode 1.
    public static let primaryRoutingClassRule = PrimaryRoutingClassRule(
        baseProducedValues: [
            0x1, 0x2, 0x4, 0x10, 0x20, 0x80,
            0x100, 0x400, 0x1000, 0x4000,
        ],
        postprocessedProducedMasks: [0x200, 0x800],
        admittedProducedValues: [0x4, 0x100, 0x200, 0x800],
        admittedMaskBitsWithoutRecoveredProducer: [0x8],
        bareLandValue: 0x10,
        roadValue: 0x4,
        blockedValue: 0x2,
        roadOnTerrainBit0x400Value: 0x100,
        ferryBuildingID: 210,
        ferryFootprintSide: 6,
        ferryFootprintMask: 0x800,
        ferryConnectorMask: 0x200,
        ferryConnectorDirectionCodes: [0, 2, 4, 6],
        ferryPostprocessingRunsAfterBaseDerivation: true
    )
    public static let fallbackRoutingClassRule = FallbackRoutingClassRule(
        producedValues: [
            0x2, 0x4, 0x8, 0x40,
            0x10000200, 0x20000100, 0x40000010, 0x40000020,
            0x48000400, 0x4C000800, 0x4C001000, 0x80000001,
        ],
        admittedProducedValues: [
            0x2, 0x4, 0x8, 0x40,
            0x40000010, 0x40000020, 0x48000400, 0x4C000800, 0x4C001000,
        ],
        rejectedProducedValues: [0x10000200, 0x20000100, 0x80000001],
        ordinaryTerrainValue: 0x2,
        waterValue: 0x10000200,
        unavailableValue: 0x80000001,
        roadWaterAuxiliaryValue: 0x40,
        terrainBit0x400Value: 0x8,
        wallValue: 0x40000010,
        fixedValue2BuildingIDs: [
            26, 27, 28, 111, 113, 126, 161, 194, 195, 196, 197, 198, 199, 202,
        ],
        fixedValue4BuildingIDs: [54, 56, 58],
        roadConditionalValue4BuildingIDs: [59, 60, 71],
        grandCanalBuildingID: buildingID,
        grandCanalInactiveValue: 0x2,
        grandCanalActiveWithoutRoadValue: 0x4C001000,
        grandCanalActiveWithRoadValue: 0x40,
        monumentStateBuildingOffset: 0xC8,
        monumentStateAccessorVtableOffset: 0x1EC,
        monumentSubBuildingPhaseOffset: 0x08,
        grandCanalActivePhaseLowerBound: 1,
        cityGateBuildingID: 130,
        cityGateValue: 0x20000100,
        towerBuildingID: 131,
        towerValue: 0x40000020,
        greatWallBuildingIDs: 253...268,
        greatWallCandidateValues: [0x2, 0x48000400, 0x4C000800]
    )

    public static func fallbackRouteAdmits(runtimeCellClass: UInt32) -> Bool {
        runtimeCellClass & UInt32(workerPathfindingRule.fallbackRuntimeCellMask) != 0
    }

    /// Derives both original cache values for one cell in the same order as
    /// the full rebuild (`FUN_005AD440` followed by `FUN_005223B0`).
    public static func workerRoutingCellValues(
        from input: WorkerRoutingCellInput
    ) throws -> WorkerRoutingCellValues {
        let primary = try primaryRoutingValue(from: input)
        let fallback = try fallbackRoutingValue(
            point: input.point,
            terrainRawValue: primary.terrainForFallback,
            occupancy: input.occupancy,
            roadWaterAuxiliaryByte: input.roadWaterAuxiliaryByte
        )
        return WorkerRoutingCellValues(
            primaryPassability: primary.value,
            fallbackCellClass: fallback
        )
    }

    public static func workerRoutingGrids(
        width: Int,
        height: Int,
        inputs: [WorkerRoutingCellInput]
    ) throws -> WorkerRoutingGrids {
        guard width > 0, height > 0, inputs.count == width * height else {
            throw WorkerRoutingCacheDerivationError.invalidGridDimensions
        }
        var ordered = [WorkerRoutingCellInput?](repeating: nil, count: inputs.count)
        for input in inputs {
            guard input.point.x >= 0, input.point.x < width,
                  input.point.y >= 0, input.point.y < height else {
                throw WorkerRoutingCacheDerivationError.invalidGridDimensions
            }
            let index = input.point.y * width + input.point.x
            guard ordered[index] == nil else {
                throw WorkerRoutingCacheDerivationError.duplicateOccupancy(input.point)
            }
            ordered[index] = input
        }
        guard ordered.allSatisfy({ $0 != nil }) else {
            throw WorkerRoutingCacheDerivationError.invalidGridDimensions
        }

        var primary: [UInt16] = []
        var fallback: [UInt32] = []
        primary.reserveCapacity(inputs.count)
        fallback.reserveCapacity(inputs.count)
        for input in ordered.compactMap({ $0 }) {
            let values = try workerRoutingCellValues(from: input)
            primary.append(values.primaryPassability)
            fallback.append(values.fallbackCellClass)
        }
        return WorkerRoutingGrids(
            width: width,
            height: height,
            primaryPassability: primary,
            fallbackCellClass: fallback
        )
    }

    /// Reproduces the road-component labels and top-ten size ranking consumed
    /// by `FUN_004BA6F0`. Discovery scans rows then columns; equal-sized
    /// components keep that discovery order because insertion uses a strict
    /// size improvement. A component must begin on an ordinary road terrain
    /// cell, but its flood can include every admitted primary-grid connector
    /// (including Ferry masks `0x200/0x800`).
    public static func workerRoadComponentRankByPoint(
        width: Int,
        height: Int,
        terrainRawValues: [UInt32],
        primaryPassability: [UInt16]
    ) throws -> [GridPoint: Int] {
        guard width > 0,
              height > 0,
              terrainRawValues.count == width * height,
              primaryPassability.count == width * height else {
            throw WorkerRoutingCacheDerivationError.invalidGridDimensions
        }
        var componentByIndex = [Int](repeating: -1, count: primaryPassability.count)
        var componentSizes: [Int] = []
        let directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]

        for y in 0..<height {
            for x in 0..<width {
                let startIndex = y * width + x
                let terrain = terrainRawValues[startIndex]
                guard terrain & 0x40 != 0,
                      terrain & 0x04 == 0,
                      componentByIndex[startIndex] == -1 else { continue }
                let componentID = componentSizes.count
                var queue = [startIndex]
                var head = 0
                componentByIndex[startIndex] = componentID
                while head < queue.count {
                    let index = queue[head]
                    head += 1
                    let point = GridPoint(x: index % width, y: index / width)
                    for direction in directions {
                        let next = GridPoint(
                            x: point.x + direction.0,
                            y: point.y + direction.1
                        )
                        guard next.x >= 0, next.x < width,
                              next.y >= 0, next.y < height else { continue }
                        let nextIndex = next.y * width + next.x
                        let primary = primaryPassability[nextIndex]
                        guard componentByIndex[nextIndex] == -1,
                              primary & 0x0B0C != 0,
                              primary & 0x08 == 0
                                || terrainRawValues[nextIndex] & 0x400 != 0
                        else { continue }
                        componentByIndex[nextIndex] = componentID
                        queue.append(nextIndex)
                    }
                }
                componentSizes.append(queue.count)
            }
        }

        let rankedComponentIDs = componentSizes.indices.sorted { lhs, rhs in
            let lhsSize = componentSizes[lhs]
            let rhsSize = componentSizes[rhs]
            return lhsSize == rhsSize ? lhs < rhs : lhsSize > rhsSize
        }.prefix(roadAccessComponentRankLimit)
        let rankByComponentID = Dictionary(uniqueKeysWithValues:
            rankedComponentIDs.enumerated().map { ($0.element, $0.offset) }
        )
        var result: [GridPoint: Int] = [:]
        for index in componentByIndex.indices {
            let terrain = terrainRawValues[index]
            guard terrain & 0x40 != 0,
                  terrain & 0x04 == 0,
                  let rank = rankByComponentID[componentByIndex[index]] else { continue }
            result[GridPoint(x: index % width, y: index / width)] = rank
        }
        return result
    }

    public static func phaseLaborTargetAccesses(
        parts: [GrandCanalMapPartState],
        roadComponentRankByPoint: [GridPoint: Int]
    ) -> [PhaseLaborTargetAccessCandidate] {
        parts.sorted(by: { $0.subBuildingIndex < $1.subBuildingIndex }).compactMap { part in
            guard let access = grandCanalRoadAccessPoint(
                subBuildingOrigin: part.worldOrigin,
                roadComponentRankByPoint: roadComponentRankByPoint
            ) else { return nil }
            return PhaseLaborTargetAccessCandidate(
                subBuildingIndex: part.subBuildingIndex,
                worldOrigin: part.worldOrigin,
                roadAccessPoint: access
            )
        }
    }

    private static func primaryRoutingValue(
        from input: WorkerRoutingCellInput
    ) throws -> (value: UInt16, terrainForFallback: UInt32) {
        let terrain = input.terrainRawValue
        if terrain & 0x100 != 0 { return (0x2, terrain) }
        if terrain & 0x800 != 0 {
            return (terrain & 0x40 == 0 ? 0x4000 : 0x4, terrain)
        }
        if terrain & 0x80000 != 0 || terrain & 0x10004 == 0x10004 {
            return (0x2, terrain)
        }
        if terrain & 0x400 != 0,
           terrain & 0x40 != 0,
           terrain & 0x800000 == 0 {
            return (0x100, terrain)
        }
        if terrain & 0x40 != 0 { return (0x4, terrain) }
        if terrain & 0x400 != 0 { return (0x10, terrain) }
        if terrain & 0x20 != 0 { return (0x10, terrain) }
        if terrain & 0x800000 != 0,
           terrain & 0x200 != 0,
           terrain & 0x400000 == 0 {
            return (0x400, terrain)
        }
        if terrain & 0x200 != 0 {
            return (terrain & 0x400000 == 0 ? 0x1000 : 0x2, terrain)
        }
        if terrain & 0x20000 != 0 {
            guard let elevationClass = input.primaryElevationClassByte else {
                throw WorkerRoutingCacheDerivationError
                    .missingPrimaryElevationClass(input.point)
            }
            if elevationClass != -1 { return (0x80, terrain) }
        }
        if terrain & 0x10000000 != 0 { return (0x20, terrain) }
        if terrain & 0x8008 != 0 {
            // A stale occupied terrain cell with no live object is repaired by
            // the primary builder before the fallback builder runs.
            guard let occupancy = input.occupancy else {
                return (0, terrain & ~UInt32(0x8))
            }
            guard let footprintPredicate = occupancy.genericFootprintPredicate else {
                throw WorkerRoutingCacheDerivationError
                    .missingGenericFootprintPredicate(
                        input.point,
                        buildingID: occupancy.buildingID
                    )
            }
            // This is the exact `+0xCC == false` branch. A true predicate also
            // consults the still-unclassified `FUN_004EFF30` family test and
            // remains unsupported rather than collapsing two outcomes.
            guard !footprintPredicate else {
                throw WorkerRoutingCacheDerivationError.unsupportedPrimaryBuilding(
                    input.point,
                    buildingID: occupancy.buildingID
                )
            }
            if occupancy.buildingID == 126 || occupancy.buildingID == 156 {
                return (0x4, terrain)
            }
            if [26, 27, 28, 111, 113, 194, 195, 196, 197, 198, 199]
                .contains(occupancy.buildingID) {
                return (0x10, terrain)
            }
            if monumentBuildingIDs.contains(occupancy.buildingID) {
                if (253...268).contains(occupancy.buildingID) {
                    guard let phase = occupancy.currentMonumentSubBuildingPhase else {
                        throw WorkerRoutingCacheDerivationError.missingMonumentPhase(
                            input.point,
                            buildingID: occupancy.buildingID
                        )
                    }
                    // All four Great Wall part vtables inherit the common
                    // phase-zero predicate reached by `FUN_00568A50`.
                    return (phase == 0 ? 0x20 : 0x2, terrain)
                }
                // Non-wall monuments (tumulus/temple/palace/canal task 83)
                // block movement like any other building in the primary
                // cache; the canal's own cells are already handled by their
                // terrain branches on Haunxian, and the wall layouts are
                // handled above. Do not throw the whole grid for them.
                return (terrain & 0x1000 != 0 ? 0x4000 : 0x2, terrain)
            }
            return (terrain & 0x1000 != 0 ? 0x4000 : 0x2, terrain)
        }
        guard let surfaceIsNonblocking = input.primarySurfaceObjectIsAbsentOrNonblocking else {
            throw WorkerRoutingCacheDerivationError
                .missingPrimarySurfaceObjectState(input.point)
        }
        if !surfaceIsNonblocking {
            // The remaining image-family discrimination reads another live
            // object record whose semantic catalog is not yet recovered.
            throw WorkerRoutingCacheDerivationError
                .missingPrimarySurfaceObjectState(input.point)
        }
        if terrain & 0x10000 != 0 { return (0x10, terrain) }
        if terrain & 0x80061001 != 0 {
            if terrain & 0x4000 != 0, terrain & 0x1000 == 0 {
                return (0x2, terrain)
            }
            return (0x10, terrain)
        }
        return (terrain & 0xAFF_FDE6F == 0 ? 0x10 : 0x2, terrain)
    }

    private static func fallbackRoutingValue(
        point: GridPoint,
        terrainRawValue terrain: UInt32,
        occupancy: WorkerRoutingCellOccupancy?,
        roadWaterAuxiliaryByte: UInt8?
    ) throws -> UInt32 {
        if terrain & 0x80000 != 0 || terrain & 0x10004 == 0x10004 {
            return 0x80000001
        }
        if terrain & 0x44 == 0x44 {
            guard let auxiliary = roadWaterAuxiliaryByte else {
                throw WorkerRoutingCacheDerivationError.missingRoadWaterAuxiliary(point)
            }
            if auxiliary != 0 { return 0x40 }
        }
        if terrain & 0x800 != 0 { return 0x2 }
        if terrain & 0x4 != 0 { return 0x10000200 }
        let hasRoad = terrain & 0x40 != 0
        if hasRoad, terrain & 0x8 == 0 { return 0x2 }
        if terrain & 0x400 != 0 { return 0x8 }
        if terrain & 0x8008 == 0 {
            if terrain & 0x200 != 0 {
                return terrain & 0x800400 == 0 ? 0x80000001 : 0x2
            }
            return terrain & 0x4000 != 0 ? 0x40000010 : 0x2
        }
        guard let occupancy else {
            return terrain & 0x8000 != 0 ? 0x40000020 : 0x2
        }
        let buildingID = occupancy.buildingID
        if [54, 56, 58].contains(buildingID) { return 0x4 }
        if [59, 60, 71].contains(buildingID) { return hasRoad ? 0x2 : 0x4 }
        if [26, 27, 28, 194, 195, 196, 197, 198, 199].contains(buildingID) {
            return 0x2
        }
        if [111, 113, 126, 161, 202].contains(buildingID) { return 0x2 }
        if buildingID == buildingIDForGrandCanal {
            guard let phase = occupancy.currentMonumentSubBuildingPhase else {
                throw WorkerRoutingCacheDerivationError
                    .missingMonumentPhase(point, buildingID: buildingID)
            }
            guard phase > 0 else { return 0x2 }
            return hasRoad ? 0x40 : 0x4C001000
        }
        if buildingID == 130 { return 0x20000100 }
        if buildingID == 131 { return 0x40000020 }
        if (253...268).contains(buildingID) {
            guard let rootPhase = occupancy.greatWallRootSubBuildingPhase,
                  let partKind = occupancy.greatWallPartKind else {
                throw WorkerRoutingCacheDerivationError
                    .unsupportedGreatWallSubtype(point, buildingID: buildingID)
            }
            guard rootPhase > 0 else { return 0x2 }
            switch partKind {
            case .gate:
                return 0x48000400
            case .wall, .tower:
                return 0x4C000800
            case .road:
                return 0x2
            }
        }
        // Non-canal, non-wall monuments (tumulus/temple/palace tasks
        // 76…82, 84…86, 92, 93) block movement in the fallback cache; only
        // the Grand Canal's per-part phase states and the wall layouts have
        // passable states.
        if monumentBuildingIDs.contains(buildingID),
           buildingID != buildingIDForGrandCanal {
            return 0x2
        }
        if monumentBuildingIDs.contains(buildingID) {
            guard let phase = occupancy.currentMonumentSubBuildingPhase else {
                throw WorkerRoutingCacheDerivationError
                    .missingMonumentPhase(point, buildingID: buildingID)
            }
            guard phase > 0 else { return 0x2 }
            return hasRoad ? 0x40 : 0x4C001000
        }
        guard let footprintPredicate = occupancy.genericFootprintPredicate else {
            throw WorkerRoutingCacheDerivationError
                .missingGenericFootprintPredicate(point, buildingID: buildingID)
        }
        return footprintPredicate ? 0x2 : 0x4
    }

    private static let buildingIDForGrandCanal = 83
    private static let monumentBuildingIDs: Set<Int> =
        Set(76...86).union([92, 93]).union(253...268)

    /// Phase-0/1 scheduler pass. `FUN_0056BB40` maintains task-102 pending
    /// records in `+0x50`; `FUN_0056D170` may create at most one figure-10
    /// initial dispatch and reports the active queue, selecting threshold 50.
    /// When all parts finish and both labor queues drain, the next triggered
    /// pass advances the shared whole phase.
    public static func advancePhaseLaborSchedulerCall(
        parts: inout [GrandCanalMapPartState],
        scheduler: inout GrandCanalSchedulerState,
        coordinator: inout PhaseLaborCoordinatorRuntime,
        providers: [PhaseLaborProviderCandidate],
        targetAccesses: [PhaseLaborTargetAccessCandidate],
        xiWangMuActive: Bool
    ) throws -> SchedulerCallOutcome {
        guard parts.count == GrandCanalLayout.original.segments.count,
              parts.map(\.subBuildingIndex).sorted() == Array(0..<33),
              Set(parts.map(\.buildingID)) == [buildingID],
              Set(parts.map(\.wholeMonumentPhase)).count == 1,
              let wholePhase = parts.first?.wholeMonumentPhase,
              wholePhase == 0 || wholePhase == 1 else {
            throw SchedulerError.malformedPartCollection
        }
        guard scheduler.recordCall() else { return .waiting }
        coordinator.enqueueMissingRequests(from: parts)

        if !coordinator.pendingRequests.isEmpty || !coordinator.laborers.isEmpty {
            let dispatched = coordinator.dispatchOneLaborer(
                providers: providers,
                targetAccesses: targetAccesses,
                xiWangMuActive: xiWangMuActive
            )
            scheduler.recordSchedulerPass(hasActiveWorkQueues: true)
            return .maintainedPhaseLabor(
                pendingCount: coordinator.pendingRequests.count,
                activeLaborerCount: coordinator.laborers.count,
                dispatchedFigureID: dispatched?.figureID
            )
        }

        guard parts.allSatisfy({ $0.currentSubBuildingPhase >= wholePhase + 1 }) else {
            throw SchedulerError.malformedPartCollection
        }
        for index in parts.indices {
            parts[index].setConstructionPhases(
                currentSubBuildingPhase: parts[index].currentSubBuildingPhase,
                wholeMonumentPhase: wholePhase + 1
            )
        }
        scheduler.recordSchedulerPass(hasActiveWorkQueues: false)
        return .advancedWholeMonumentPhase(from: wholePhase, to: wholePhase + 1)
    }

    /// Advances one original monument-scheduler call. This API deliberately
    /// does not claim that a call equals one Native day. For the authored
    /// phase-4 Haunxian state, all parts and the whole monument are already at
    /// the terminal completed phase. Completed state bypasses the coordinator
    /// and does not consume scheduler calls.
    public static func advanceSchedulerCall(
        parts: inout [GrandCanalMapPartState],
        scheduler: inout GrandCanalSchedulerState
    ) throws -> SchedulerCallOutcome {
        guard parts.count == GrandCanalLayout.original.segments.count,
              parts.map(\.subBuildingIndex).sorted() == Array(0..<33),
              Set(parts.map(\.buildingID)) == [buildingID] else {
            throw SchedulerError.malformedPartCollection
        }
        let wholePhases = Set(parts.map(\.wholeMonumentPhase))
        guard wholePhases.count == 1, let wholePhase = wholePhases.first else {
            throw SchedulerError.malformedPartCollection
        }
        if wholePhase >= finalCompletedPhaseIndex {
            guard parts.allSatisfy({
                $0.currentSubBuildingPhase >= finalCompletedPhaseIndex
            }) else {
                throw SchedulerError.malformedPartCollection
            }
            return .alreadyComplete
        }
        guard scheduler.recordCall() else { return .waiting }
        guard phaseBehaviors.indices.contains(wholePhase) else {
            throw SchedulerError.unsupportedConstructionPhase(wholePhase)
        }

        let pendingIndices = parts.indices.filter {
            parts[$0].currentSubBuildingPhase == wholePhase
        }
        if !pendingIndices.isEmpty {
            guard phaseBehaviors[wholePhase].completion
                    == .automaticAfterOtherQueuesDrain else {
                throw SchedulerError.unsupportedConstructionPhase(wholePhase)
            }
            let subBuildingIndices = pendingIndices.map { parts[$0].subBuildingIndex }
            for index in pendingIndices {
                parts[index].setConstructionPhases(
                    currentSubBuildingPhase: wholePhase + 1,
                    wholeMonumentPhase: wholePhase
                )
            }
            // `FUN_0056D170` consumes the automatic queue at coordinator
            // `+0x80`, then returns false because only the `+0x30`/`+0x50`
            // active-work queues control the 50-call threshold.
            scheduler.recordSchedulerPass(hasActiveWorkQueues: false)
            return .automaticallyAdvancedSubBuildings(
                indices: subBuildingIndices.sorted()
            )
        }

        guard parts.allSatisfy({ $0.currentSubBuildingPhase >= wholePhase + 1 }) else {
            throw SchedulerError.malformedPartCollection
        }
        for index in parts.indices {
            parts[index].setConstructionPhases(
                currentSubBuildingPhase: parts[index].currentSubBuildingPhase,
                wholeMonumentPhase: wholePhase + 1
            )
        }
        scheduler.recordSchedulerPass(hasActiveWorkQueues: false)
        return .advancedWholeMonumentPhase(from: wholePhase, to: wholePhase + 1)
    }

    /// Phase-2 counterpart to `advanceSchedulerCall`. At each triggered pass
    /// the original coordinator creates missing material records and reports
    /// an active work queue, selecting the 50-call threshold. Once every part
    /// has received 400 units and both material containers are empty, the
    /// zero-amount branch creates coordinator `+0x80` automatic records;
    /// `FUN_0056D170` consumes them in that pass and advances each part 2→3.
    public static func advancePhaseTwoSchedulerCall(
        parts: inout [GrandCanalMapPartState],
        scheduler: inout GrandCanalSchedulerState,
        coordinator: inout PhaseTwoCoordinatorRuntime
    ) throws -> SchedulerCallOutcome {
        guard parts.count == GrandCanalLayout.original.segments.count,
              parts.map(\.subBuildingIndex).sorted() == Array(0..<33),
              Set(parts.map(\.buildingID)) == [buildingID],
              Set(parts.map(\.wholeMonumentPhase)) == [2] else {
            throw SchedulerError.malformedPartCollection
        }
        guard scheduler.recordCall() else { return .waiting }
        coordinator.enqueueMissingRequests(from: parts)
        let hasActiveMaterialQueue = !coordinator.pendingRequests.isEmpty
            || !coordinator.carrierBoundRequests.isEmpty
        if hasActiveMaterialQueue {
            scheduler.recordSchedulerPass(hasActiveWorkQueues: true)
            return .maintainedPhaseTwoMaterialRequests(
                pendingCount: coordinator.pendingRequests.count,
                carrierBoundCount: coordinator.carrierBoundRequests.count
            )
        }

        let pendingIndices = parts.indices.filter {
            parts[$0].currentSubBuildingPhase == 2
                && parts[$0].remainingPhaseTwoStoneUnits == 0
        }
        if !pendingIndices.isEmpty {
            guard parts.allSatisfy({
                $0.currentSubBuildingPhase == 2
                    && $0.remainingPhaseTwoStoneUnits == 0
            }) else {
                throw SchedulerError.malformedPartCollection
            }
            let subBuildingIndices = pendingIndices.map { parts[$0].subBuildingIndex }
            for index in pendingIndices {
                parts[index].setConstructionPhases(
                    currentSubBuildingPhase: 3,
                    wholeMonumentPhase: 2
                )
            }
            scheduler.recordSchedulerPass(hasActiveWorkQueues: false)
            return .automaticallyAdvancedSubBuildings(
                indices: subBuildingIndices.sorted()
            )
        }

        guard parts.allSatisfy({ $0.currentSubBuildingPhase >= 3 }) else {
            throw SchedulerError.malformedPartCollection
        }
        for index in parts.indices {
            parts[index].setConstructionPhases(
                currentSubBuildingPhase: parts[index].currentSubBuildingPhase,
                wholeMonumentPhase: 3
            )
        }
        scheduler.recordSchedulerPass(hasActiveWorkQueues: false)
        return .advancedWholeMonumentPhase(from: 2, to: 3)
    }

    /// Reproduces the recovered worker-route arbitration after both derived
    /// runtime grids have been built. Primary mode uses a cardinal BFS and
    /// cardinal route steps; mode 19 performs the same cardinal flood over the
    /// fallback classes, then may compact the distance gradient into eight-way
    /// direction steps exactly as `FUN_005B18B0(..., 8, ...)` does.
    public static func workerRoute(
        primaryValues: [UInt16],
        fallbackValues: [UInt32],
        width: Int,
        height: Int,
        from start: GridPoint,
        to destination: GridPoint
    ) -> WorkerRoute? {
        guard width > 0, height > 0,
              primaryValues.count == width * height,
              fallbackValues.count == width * height else { return nil }

        let primaryRoute = route(
            width: width,
            height: height,
            from: start,
            to: destination,
            reconstructionDirections: [0, 2, 4, 6],
            maximumExpansions: nil,
            isPassable: {
                primaryValues[$0.y * width + $0.x]
                    & UInt16(workerPathfindingRule.primaryPassabilityMask) != 0
            }
        ) ?? route(
            width: width,
            height: height,
            from: start,
            to: destination,
            reconstructionDirections: Array(0..<8),
            maximumExpansions: nil,
            isPassable: {
                primaryValues[$0.y * width + $0.x]
                    & UInt16(workerPathfindingRule.primaryPassabilityMask) != 0
            }
        )
        if let route = primaryRoute {
            return WorkerRoute(
                grid: .primaryPassability,
                points: route.points,
                directionCodes: route.directionCodes
            )
        }
        guard let route = route(
            width: width,
            height: height,
            from: start,
            to: destination,
            reconstructionDirections: Array(0..<8),
            maximumExpansions: workerPathfindingRule.fallbackMaximumExpansions,
            isPassable: {
                fallbackRouteAdmits(runtimeCellClass: fallbackValues[$0.y * width + $0.x])
            }
        ) else { return nil }
        return WorkerRoute(
            grid: .fallbackCellClass,
            points: route.points,
            directionCodes: route.directionCodes
        )
    }

    /// Type-19 carrier movement mode 7 from `FUN_005AFB00`: cardinal flood
    /// over the primary cache with mask `0x12C`, cardinal reconstruction
    /// first, and eight-direction compression only when that reconstruction
    /// cannot be represented. Unlike phase labor, this route has no mode-19
    /// fallback grid.
    public static func phaseTwoCarrierRoute(
        primaryValues: [UInt16],
        width: Int,
        height: Int,
        from start: GridPoint,
        to destination: GridPoint
    ) -> WorkerRoute? {
        guard width > 0, height > 0,
              primaryValues.count == width * height else { return nil }
        let passable: (GridPoint) -> Bool = {
            primaryValues[$0.y * width + $0.x] & 0x12C != 0
        }
        let result = route(
            width: width,
            height: height,
            from: start,
            to: destination,
            reconstructionDirections: [0, 2, 4, 6],
            maximumExpansions: nil,
            isPassable: passable
        ) ?? route(
            width: width,
            height: height,
            from: start,
            to: destination,
            reconstructionDirections: Array(0..<8),
            maximumExpansions: nil,
            isPassable: passable
        )
        guard let result else { return nil }
        return WorkerRoute(
            grid: .primaryPassability,
            points: result.points,
            directionCodes: result.directionCodes
        )
    }

    private static let directionDeltas = [
        GridPoint(x: 0, y: -1),
        GridPoint(x: 1, y: -1),
        GridPoint(x: 1, y: 0),
        GridPoint(x: 1, y: 1),
        GridPoint(x: 0, y: 1),
        GridPoint(x: -1, y: 1),
        GridPoint(x: -1, y: 0),
        GridPoint(x: -1, y: -1),
    ]

    private static func route(
        width: Int,
        height: Int,
        from start: GridPoint,
        to destination: GridPoint,
        reconstructionDirections: [Int],
        maximumExpansions: Int?,
        isPassable: (GridPoint) -> Bool
    ) -> (points: [GridPoint], directionCodes: [Int])? {
        func contains(_ point: GridPoint) -> Bool {
            point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
        }
        guard contains(start), contains(destination), start != destination else { return nil }

        let startIndex = start.y * width + start.x
        let destinationIndex = destination.y * width + destination.x
        var distances = [Int](repeating: 0, count: width * height)
        distances[startIndex] = 1
        var queue = [Int](repeating: 0, count: width * height)
        queue[0] = startIndex
        var head = 0
        var tail = 1
        var expansions = 0
        let floodDirections = [0, 2, 4, 6]

        while head < tail, distances[destinationIndex] == 0 {
            let currentIndex = queue[head]
            head += 1
            expansions += 1
            let current = GridPoint(x: currentIndex % width, y: currentIndex / width)
            for direction in floodDirections {
                let delta = directionDeltas[direction]
                let next = GridPoint(x: current.x + delta.x, y: current.y + delta.y)
                guard contains(next) else { continue }
                let nextIndex = next.y * width + next.x
                guard distances[nextIndex] == 0, isPassable(next) else { continue }
                distances[nextIndex] = distances[currentIndex] + 1
                queue[tail] = nextIndex
                tail += 1
            }
            // MonMap increments its counter after expanding a cell, then
            // stops only when `limit < count`; parameter 100000 therefore
            // permits the queue item numbered 100001 to be processed.
            if let maximumExpansions, expansions > maximumExpansions { break }
        }
        guard distances[destinationIndex] > 0 else { return nil }

        var reverseDirections: [Int] = []
        var current = destination
        var forbiddenDirection: Int?
        while current != start {
            let directDirection = directionCode(from: current, toward: start)
            var best: (direction: Int, distance: Int)?
            for direction in reconstructionDirections where direction != forbiddenDirection {
                let delta = directionDeltas[direction]
                let candidate = GridPoint(x: current.x + delta.x, y: current.y + delta.y)
                guard contains(candidate) else { continue }
                let distance = distances[candidate.y * width + candidate.x]
                let currentDistance = distances[current.y * width + current.x]
                guard distance > 0, distance <= currentDistance else { continue }
                if best.map({ distance < $0.distance
                    || (distance == $0.distance && direction == directDirection)
                }) ?? true {
                    best = (direction, distance)
                }
            }
            // The original scratch buffer has 500 bytes, but reaching index
            // 500 returns failure before the bytes are copied to the path
            // slot; successful routes therefore contain at most 499 steps.
            guard let best,
                  reverseDirections.count + 1 < workerPathfindingRule.maximumStoredDirections
            else { return nil }
            current = GridPoint(
                x: current.x + directionDeltas[best.direction].x,
                y: current.y + directionDeltas[best.direction].y
            )
            let forwardDirection = (best.direction + 4) % 8
            reverseDirections.append(forwardDirection)
            forbiddenDirection = forwardDirection
        }

        let directionCodes = reverseDirections.reversed()
        var points = [start]
        var point = start
        for direction in directionCodes {
            let delta = directionDeltas[direction]
            point = GridPoint(x: point.x + delta.x, y: point.y + delta.y)
            points.append(point)
        }
        guard point == destination else { return nil }
        return (points, Array(directionCodes))
    }

    private static func directionCode(from point: GridPoint, toward destination: GridPoint) -> Int {
        let horizontal = destination.x == point.x ? 0 : (destination.x > point.x ? 1 : -1)
        let vertical = destination.y == point.y ? 0 : (destination.y > point.y ? 1 : -1)
        return directionDeltas.firstIndex {
            $0.x == horizontal && $0.y == vertical
        } ?? 8
    }
    public static let schedulerTicksWithoutActiveWorkQueues = 30
    public static let schedulerTicksWithActiveWorkQueues = 50
    /// `FUN_004AC2B0` advances its inner counter through 0...50 before
    /// `FUN_004AC650` advances one of 16 sub-month slices. Both new-city and
    /// map-load paths reset the counters, so this product is constant.
    public static let originalSimulationStepsPerCalendarSlice = 51
    public static let originalCalendarSlicesPerMonth = 16
    public static let originalSimulationStepsPerMonth =
        originalSimulationStepsPerCalendarSlice * originalCalendarSlicesPerMonth

    /// Distributes the original 816 monthly simulation steps over the Native
    /// compatibility clock's 30 save/replay days by cumulative ratio. This is
    /// a clock adapter, not a claim that the original engine had 30-day months.
    public static func schedulerCalls(forNativeDay day: Int) -> Int {
        guard (1...SimulationClockState.daysPerMonth).contains(day) else { return 0 }
        let callsThroughDay = day * originalSimulationStepsPerMonth
            / SimulationClockState.daysPerMonth
        let callsBeforeDay = (day - 1) * originalSimulationStepsPerMonth
            / SimulationClockState.daysPerMonth
        return callsThroughDay - callsBeforeDay
    }
    /// The predetermined root enters the ordinary scheduler as soon as its map
    /// objects are loaded. Haunxian restores phase four directly; there is no
    /// separate begin-project player action.
    public static let isAutomaticallyScheduledFromPredeterminedMapObject = true
    public static let campaignGoalCompletionPercent = 100
    /// The single-player goal collector runs from the ordinary month rollover,
    /// evaluates every authored goal through its goal-class completion slot,
    /// and enters the common victory path only when all results are true.
    public static let campaignGoalsEvaluatedAtMonthlySettlement = true
    public static let campaignVictoryRequiresAllGoals = true
    public static let usesGenericCampaignVictoryTransition = true
    /// The common phase-completion switch has special post-phase cleanup only
    /// for building IDs 78...82. Building 83 has no canal-specific branch;
    /// goal/victory handling remains in the separate common campaign system.
    public static let hasCanalSpecificPostPhaseCompletionBranch = false
    public static let requiresWood = false
    public static let totalStoneUnits = 33 * 400

    /// Decodes the exact schema-4 `cMonumentBldg` sequence used by the two
    /// authored Grand Canal maps. A map without that sequence returns an empty
    /// array; a present but truncated/inconsistent sequence is malformed.
    public static func archivedPartStates(
        in decodedMapData: Data
    ) throws -> [GrandCanalMapPartState] {
        let className = Data("cMonumentBldg".utf8)
        guard let classRange = decodedMapData.range(of: className) else { return [] }

        let firstBuildingIDOffset = classRange.upperBound + 16
        let finalRequiredOffset = firstBuildingIDOffset
            + (GrandCanalLayout.original.segments.count - 1) * archivedRecordStride
            + archivedDeliveredStoneUnitsOffsetFromBuildingID + 3
        guard firstBuildingIDOffset >= 18,
              finalRequiredOffset < decodedMapData.count else {
            throw GameDataError.malformedFile("truncated Grand Canal monument archive")
        }

        func uint16(at offset: Int) -> UInt16 {
            UInt16(decodedMapData[offset])
                | UInt16(decodedMapData[offset + 1]) << 8
        }
        func uint32(at offset: Int) -> UInt32 {
            UInt32(decodedMapData[offset])
                | UInt32(decodedMapData[offset + 1]) << 8
                | UInt32(decodedMapData[offset + 2]) << 16
                | UInt32(decodedMapData[offset + 3]) << 24
        }

        guard Int(uint16(at: firstBuildingIDOffset)) == buildingID else { return [] }
        // Field offsets below are recovered for base schema 4, monument
        // wrapper schema 1 and cMonInfo schema 9. Other shipping maps use
        // base schemas 3/5 or cMonInfo schema 10; do not apply this layout to
        // those objects until their serializer branches are recovered.
        guard Int(uint16(at: firstBuildingIDOffset - 16))
                == archivedBaseBuildingSchema,
              Int(uint16(at: firstBuildingIDOffset + 165))
                == archivedMonumentWrapperSchema,
              Int(uint16(at: firstBuildingIDOffset + 167))
                == archivedMonumentStateSchema else { return [] }
        var states: [GrandCanalMapPartState] = []
        states.reserveCapacity(GrandCanalLayout.original.segments.count)
        for index in GrandCanalLayout.original.segments.indices {
            let offset = firstBuildingIDOffset + index * archivedRecordStride
            if index > 0, uint16(at: offset - 18) != 0x8003 {
                throw GameDataError.malformedFile("Grand Canal MFC object tag")
            }
            let state = GrandCanalMapPartState(
                worldOrigin: GridPoint(
                    x: Int(uint16(at: offset - 8)),
                    y: Int(uint16(at: offset - 6))
                ),
                mapCellIndex: Int(uint32(at: offset - 4)),
                buildingID: Int(uint16(at: offset)),
                subBuildingIndex: Int(uint16(at: offset + 2)),
                baseBuildingSchema: Int(uint16(at: offset - 16)),
                monumentWrapperSchema: Int(uint16(at: offset + 165)),
                monumentStateSchema: Int(uint16(at: offset + 167)),
                currentSubBuildingPhase: Int(uint32(at: offset + 173)),
                wholeMonumentPhase: Int(uint32(at: offset + 177)),
                deliveredStoneUnits: Int(uint32(
                    at: offset + archivedDeliveredStoneUnitsOffsetFromBuildingID
                )),
                onSiteLaborerWorkUpdates: Int(uint32(
                    at: offset + archivedOnSiteLaborerWorkUpdatesOffsetFromBuildingID
                ))
            )
            guard state.buildingID == buildingID,
                  state.subBuildingIndex == index,
                  state.baseBuildingSchema == archivedBaseBuildingSchema,
                  state.monumentWrapperSchema == archivedMonumentWrapperSchema,
                  state.monumentStateSchema == archivedMonumentStateSchema,
                  state.onSiteLaborerWorkUpdates >= 0,
                  (0...400).contains(state.deliveredStoneUnits) else {
                throw GameDataError.malformedFile("Grand Canal monument record \(index)")
            }
            states.append(state)
        }
        let matchesAuthoredGeometry = (0..<4).contains { turns in
            let firstRelative = rotate(
                GrandCanalLayout.original.segments[0].localOrigin,
                quarterTurnsClockwise: turns
            )
            let origin = GridPoint(
                x: states[0].worldOrigin.x - firstRelative.x,
                y: states[0].worldOrigin.y - firstRelative.y
            )
            return zip(states, GrandCanalLayout.original.segments).allSatisfy {
                state, segment in
                let relative = rotate(
                    segment.localOrigin,
                    quarterTurnsClockwise: turns
                )
                return state.worldOrigin == GridPoint(
                    x: origin.x + relative.x,
                    y: origin.y + relative.y
                )
            }
        }
        guard matchesAuthoredGeometry else {
            throw GameDataError.malformedFile("Grand Canal archived geometry")
        }
        return states
    }

    public static func campaignPlacement(in map: EmperorMap) -> MapPlacement? {
        let plannedImage = mapImageBase + UInt32(plannedMapImageID)
        let authoredCells = Set((0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x -> GridPoint? in
                map.imageID(x: x, y: y) == plannedImage
                    ? GridPoint(x: x, y: y)
                    : nil
            }
        })
        guard !authoredCells.isEmpty else { return nil }

        for turns in 0..<4 {
            let relativeCells = footprintCells(quarterTurnsClockwise: turns)
            guard relativeCells.count == authoredCells.count,
                  let firstRelative = relativeCells.min(by: pointOrder),
                  let firstAuthored = authoredCells.min(by: pointOrder) else { continue }
            let origin = GridPoint(
                x: firstAuthored.x - firstRelative.x,
                y: firstAuthored.y - firstRelative.y
            )
            let translated = Set(relativeCells.map {
                GridPoint(x: origin.x + $0.x, y: origin.y + $0.y)
            })
            if translated == authoredCells {
                return MapPlacement(origin: origin, quarterTurnsClockwise: turns)
            }
        }
        return nil
    }

    public static func placedSubBuildings(
        for placement: MapPlacement
    ) -> [PlacedSubBuilding] {
        GrandCanalLayout.original.segments.map { segment in
            let relativeOrigin = rotate(
                segment.localOrigin,
                quarterTurnsClockwise: placement.quarterTurnsClockwise
            )
            return PlacedSubBuilding(
                index: segment.index,
                worldOrigin: GridPoint(
                    x: placement.origin.x + relativeOrigin.x,
                    y: placement.origin.y + relativeOrigin.y
                ),
                isRoadCrossing: segment.isRoadCrossing
            )
        }
    }

    public static func footprintCells(
        quarterTurnsClockwise: Int
    ) -> Set<GridPoint> {
        Set(GrandCanalLayout.original.segments.flatMap { segment in
            let origin = rotate(
                segment.localOrigin,
                quarterTurnsClockwise: quarterTurnsClockwise
            )
            return segment.footprint.points(at: origin)
        })
    }

    private static func rotate(
        _ point: GridPoint,
        quarterTurnsClockwise: Int
    ) -> GridPoint {
        let side = 4
        switch (quarterTurnsClockwise % 4 + 4) % 4 {
        case 0:
            return point
        case 1:
            return GridPoint(x: point.y, y: 1 - point.x - side)
        case 2:
            return GridPoint(x: 1 - point.x - side, y: 1 - point.y - side)
        default:
            return GridPoint(x: 1 - point.y - side, y: point.x)
        }
    }

    private static func pointOrder(_ lhs: GridPoint, _ rhs: GridPoint) -> Bool {
        lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
    }
}

/// Legacy Native save compatibility only. The four-stage, equally divided
/// segment model is not an original Grand Canal construction rule and no new
/// player command may create or advance it.
public struct GrandCanalSegmentRuntime: Sendable, Hashable, Codable {
    public let index: Int
    public private(set) var stage: Int
    public private(set) var deliveredWood: Int
    public private(set) var deliveredStone: Int
    public private(set) var completedWork: Int

    public var isFinal: Bool { stage == GrandCanalProjectRuntime.finalStage }

    fileprivate mutating func advance(
        deliveredWood: Int,
        deliveredStone: Int,
        completedWork: Int
    ) {
        stage = min(GrandCanalProjectRuntime.finalStage, stage + 1)
        self.deliveredWood = deliveredWood
        self.deliveredStone = deliveredStone
        self.completedWork = completedWork
    }
}

public struct GrandCanalProjectRuntime: Sendable, Hashable, Codable {
    public static let buildingID = 83
    public static let finalStage = 4

    public let projectID: Int
    public let origin: GridPoint
    public let rotation: Int
    public private(set) var segments: [GrandCanalSegmentRuntime]

    public init(
        projectID: Int,
        origin: GridPoint = GrandCanalLayout.haunxianOrigin,
        rotation: Int = 0
    ) {
        self.projectID = projectID
        self.origin = origin
        self.rotation = rotation
        segments = GrandCanalLayout.original.segments.map {
            GrandCanalSegmentRuntime(
                index: $0.index,
                stage: 0,
                deliveredWood: 0,
                deliveredStone: 0,
                completedWork: 0
            )
        }
    }

    public var isComplete: Bool {
        segments.allSatisfy(\.isFinal)
    }

    public var completionPercent: Int {
        let progress = segments.reduce(0) { $0 + $1.stage }
        return progress * 100 / max(1, segments.count * Self.finalStage)
    }

    public func segmentIndex(containing point: GridPoint) -> Int? {
        GrandCanalLayout.original.segments.first {
            $0.footprint.points(at: $0.worldOrigin(from: origin)).contains(point)
        }?.index
    }

    public func worldOrigin(forSegment index: Int) -> GridPoint? {
        GrandCanalLayout.original.segments.first(where: { $0.index == index })?
            .worldOrigin(from: origin)
    }

    public func isRoadCrossing(segment index: Int) -> Bool {
        GrandCanalLayout.original.segments.first(where: { $0.index == index })?
            .isRoadCrossing ?? false
    }

    mutating func advanceSegment(
        index: Int,
        project: MonumentProject
    ) -> Bool {
        guard let position = segments.firstIndex(where: { $0.index == index }),
              segments[position].stage < Self.finalStage else { return false }
        let nextStage = segments[position].stage + 1
        let wood = Self.segmentShare(total: project.requiredCommodityUnits[10, default: 0], index: index)
        let stone = Self.segmentShare(total: project.requiredCommodityUnits[20, default: 0], index: index)
        let work = Self.segmentShare(total: project.requiredWork, index: index)
        let nextWood = Self.cumulativeShare(wood, stage: nextStage)
        let nextStone = Self.cumulativeShare(stone, stage: nextStage)
        let nextWork = Self.cumulativeShare(work, stage: nextStage)

        let assignedWood = segments.reduce(0) { $0 + $1.deliveredWood }
            - segments[position].deliveredWood + nextWood
        let assignedStone = segments.reduce(0) { $0 + $1.deliveredStone }
            - segments[position].deliveredStone + nextStone
        let assignedWork = segments.reduce(0) { $0 + $1.completedWork }
            - segments[position].completedWork + nextWork
        guard project.deliveredCommodityUnits[10, default: 0] >= assignedWood,
              project.deliveredCommodityUnits[20, default: 0] >= assignedStone,
              project.completedWork >= assignedWork else { return false }
        segments[position].advance(
            deliveredWood: nextWood,
            deliveredStone: nextStone,
            completedWork: nextWork
        )
        return true
    }

    private static func segmentShare(total: Int, index: Int) -> Int {
        let quotient = total / 33
        return quotient + (index < total % 33 ? 1 : 0)
    }

    private static func cumulativeShare(_ total: Int, stage: Int) -> Int {
        (total * min(max(stage, 0), finalStage) + finalStage - 1) / finalStage
    }
}

private extension NSTextCheckingResult {
    func integer(at index: Int, in source: String) -> Int? {
        guard let range = Range(range(at: index), in: source) else { return nil }
        return Int(source[range])
    }
}
