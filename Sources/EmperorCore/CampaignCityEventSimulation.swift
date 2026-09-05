import Foundation

public enum CampaignCityConditionKind: String, Sendable, Hashable, Codable {
    case drought
    case flood
    case strike
}

public struct CampaignCityConditions: Sendable, Hashable, Codable {
    public var remainingMonthsByKind: [CampaignCityConditionKind: Int]

    public init(remainingMonthsByKind: [CampaignCityConditionKind: Int] = [:]) {
        self.remainingMonthsByKind = remainingMonthsByKind
    }

    public var agriculturalYieldPercent: Int {
        var result = 100
        if remainingMonthsByKind[.drought, default: 0] > 0 { result = min(result, 50) }
        if remainingMonthsByKind[.flood, default: 0] > 0 { result = min(result, 75) }
        return result
    }

    public mutating func apply(_ kind: CampaignCityConditionKind, months: Int) {
        remainingMonthsByKind[kind] = max(remainingMonthsByKind[kind, default: 0], max(1, months))
    }

    public mutating func advanceMonth() {
        for kind in Array(remainingMonthsByKind.keys) {
            remainingMonthsByKind[kind] = max(0, remainingMonthsByKind[kind, default: 0] - 1)
            if remainingMonthsByKind[kind] == 0 { remainingMonthsByKind.removeValue(forKey: kind) }
        }
    }
}

public enum CampaignInvasionStatus: String, Sendable, Hashable, Codable {
    case awaitingDefense
    case repelled
    case cityBreached
}

public struct CampaignInvasionAlert: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let occurrenceID: String
    public let sourceCityID: Int?
    public let secondarySelectionID: Int?
    public let strength: Int
    public let entryPoint: GridPoint?
    /// Source-side five-category formation plan when the campaign city
    /// selector and authored enemy table were available at event dispatch.
    /// `nil` preserves hand-authored/legacy callers that lack that context.
    public let sourceFormationPlan: OriginalInvasionFormationPlan?
    public private(set) var status: CampaignInvasionStatus

    public var sourceFigureCount: Int? { sourceFormationPlan?.sourceFigureCount }

    public init(
        id: String,
        occurrenceID: String,
        sourceCityID: Int?,
        secondarySelectionID: Int? = nil,
        strength: Int,
        entryPoint: GridPoint?,
        sourceFormationPlan: OriginalInvasionFormationPlan? = nil,
        status: CampaignInvasionStatus
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.sourceCityID = sourceCityID
        self.secondarySelectionID = secondarySelectionID
        self.strength = strength
        self.entryPoint = entryPoint
        self.sourceFormationPlan = sourceFormationPlan
        self.status = status
    }

    public mutating func resolve(_ status: CampaignInvasionStatus) {
        guard self.status == .awaitingDefense else { return }
        self.status = status
    }
}

public struct CampaignDisasterIncident: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let occurrenceID: String
    public let kind: CampaignEventKind
    public let epicenter: GridPoint?
    public let destroyedBuildingKeys: [OperationalBuildingKey]
}

public struct CampaignCityMessage: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let occurrenceID: String
    public let kindRawValue: UInt8
    public let sourceCityID: Int?
    public let productID: Int?
    public let amount: Int?
}

public struct CampaignCityEventApplication: Sendable, Hashable, Codable {
    public let destroyedBuildingKeys: [OperationalBuildingKey]
    public let invasionAlertID: String?
    public let condition: CampaignCityConditionKind?
    public let cityStatusApplied: Bool
    public let messageRecorded: Bool

    public var changedCity: Bool {
        !destroyedBuildingKeys.isEmpty || invasionAlertID != nil || condition != nil
            || cityStatusApplied || messageRecorded
    }
}

public struct CampaignCityEventState: Sendable, Hashable, Codable {
    public var conditions: CampaignCityConditions
    public private(set) var invasions: [CampaignInvasionAlert]
    public private(set) var disasters: [CampaignDisasterIncident]
    public private(set) var statusChangeCodeByCityID: [Int: UInt8]
    public private(set) var messages: [CampaignCityMessage]

    public init() {
        conditions = CampaignCityConditions()
        invasions = []
        disasters = []
        statusChangeCodeByCityID = [:]
        messages = []
    }

    mutating func appendInvasion(_ invasion: CampaignInvasionAlert) { invasions.append(invasion) }
    mutating func appendDisaster(_ disaster: CampaignDisasterIncident) { disasters.append(disaster) }
    mutating func setStatus(_ code: UInt8, cityID: Int) { statusChangeCodeByCityID[cityID] = code }
    mutating func appendMessage(_ message: CampaignCityMessage) { messages.append(message) }

    @discardableResult
    mutating func resolveInvasion(id: String, as status: CampaignInvasionStatus) -> Bool {
        guard let index = invasions.firstIndex(where: { $0.id == id }) else { return false }
        let before = invasions[index].status
        invasions[index].resolve(status)
        return invasions[index].status != before
    }
}

public extension DeterministicCityState {
    @discardableResult
    mutating func applyCampaignCityEvent(
        _ occurrence: CampaignEventOccurrence,
        sourceFormationPlan: OriginalInvasionFormationPlan? = nil
    ) -> CampaignCityEventApplication {
        var eventState = campaignEventState ?? CampaignCityEventState()
        var destroyed: [OperationalBuildingKey] = []
        var invasionID: String?
        var condition: CampaignCityConditionKind?
        var cityStatusApplied = false
        var messageRecorded = false

        switch occurrence.kind {
        case .invasion:
            let points = terrain?.authoredPoints?.landInvasion ?? []
            let entry = points.isEmpty
                ? terrain?.authoredPoints?.landEntry
                : points[abs(occurrence.eventID) % points.count]
            let alert = CampaignInvasionAlert(
                id: occurrence.id,
                occurrenceID: occurrence.id,
                sourceCityID: occurrence.cityFromID,
                secondarySelectionID: occurrence.secondarySelectionID,
                strength: max(1, occurrence.amount ?? 1),
                entryPoint: entry,
                sourceFormationPlan: sourceFormationPlan,
                status: .awaitingDefense
            )
            eventState.appendInvasion(alert)
            invasionID = alert.id

        case .earthquake, .flood:
            let authoredPoints = terrain?.authoredPoints?.disasters ?? []
            let epicenter = authoredPoints.isEmpty
                ? GridPoint(x: roadNetwork.width / 2, y: roadNetwork.height / 2)
                : authoredPoints[abs(occurrence.eventID) % authoredPoints.count]
            let requested = min(8, max(1, occurrence.amount ?? 1))
            let ordered = buildingFailureCandidatePlacements.filter {
                $0.buildingID != OriginalBuildingSpriteCatalog.ruinBuildingID
            }.sorted { lhs, rhs in
                let left = abs(lhs.markerPoint.x - epicenter.x) + abs(lhs.markerPoint.y - epicenter.y)
                let right = abs(rhs.markerPoint.x - epicenter.x) + abs(rhs.markerPoint.y - epicenter.y)
                if left != right { return left < right }
                return lhs.id < rhs.id
            }
            var failures: [BuildingFailure] = []
            for placement in ordered.prefix(requested) {
                let key = OperationalBuildingKey(
                    category: placement.category,
                    instanceID: placement.instanceID
                )
                let failureKind: BuildingFailureKind
                if occurrence.kind == .earthquake {
                    // The manual confirms that earthquake damage can produce
                    // either collapse or fire. The native replay chooses the
                    // branch from authored event/building coordinates until
                    // the original executable's probability is recovered.
                    let selector = occurrence.eventID
                        &+ placement.instanceID
                        &+ placement.markerPoint.x
                        &+ placement.markerPoint.y
                    failureKind = selector.isMultiple(of: 4) ? .fire : .collapse
                } else {
                    failureKind = .collapse
                }
                failures.append(BuildingFailure(
                    key: key,
                    buildingID: placement.buildingID,
                    location: placement.markerPoint,
                    kind: failureKind,
                    cause: .disaster
                ))
                destroyed.append(key)
            }
            applyExternalBuildingFailures(failures)
            if occurrence.kind == .flood {
                eventState.conditions.apply(.flood, months: Self.eventDuration(occurrence.amount))
                condition = .flood
            }
            eventState.appendDisaster(CampaignDisasterIncident(
                id: occurrence.id,
                occurrenceID: occurrence.id,
                kind: occurrence.kind ?? .earthquake,
                epicenter: epicenter,
                destroyedBuildingKeys: destroyed
            ))

        case .drought:
            eventState.conditions.apply(.drought, months: Self.eventDuration(occurrence.amount))
            condition = .drought

        case .strike:
            eventState.conditions.apply(.strike, months: Self.eventDuration(occurrence.amount))
            condition = .strike

        case .cityStatusChange:
            if let cityID = occurrence.cityFromID {
                eventState.setStatus(occurrence.statusChangeCode, cityID: cityID)
                cityStatusApplied = true
            }

        case .message, .cityMessage:
            eventState.appendMessage(CampaignCityMessage(
                id: occurrence.id,
                occurrenceID: occurrence.id,
                kindRawValue: occurrence.kindRawValue,
                sourceCityID: occurrence.cityFromID,
                productID: occurrence.productID,
                amount: occurrence.amount
            ))
            messageRecorded = true

        default:
            break
        }
        campaignEventState = eventState
        return CampaignCityEventApplication(
            destroyedBuildingKeys: destroyed,
            invasionAlertID: invasionID,
            condition: condition,
            cityStatusApplied: cityStatusApplied,
            messageRecorded: messageRecorded
        )
    }

    private static func eventDuration(_ authoredAmount: Int?) -> Int {
        min(36, max(1, authoredAmount ?? 12))
    }
}
