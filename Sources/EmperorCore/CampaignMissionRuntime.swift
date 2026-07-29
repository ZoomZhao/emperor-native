import Foundation

public enum CampaignRequestStatus: String, Sendable, Hashable, Codable {
    case pending
    case fulfilled
    case expired
}

extension CampaignMissionRuntimeState {
    private enum CodingKeys: String, CodingKey {
        case missionID, startYear, startMonth, replaySeed, scheduler
        case occurrences, effects, requests, pendingGiftDeliveries
        case menagerieAnimalIDs, menagerieAnimalCountsByProductID, cityStatusMutations
        case normalAnnualWage, outcome, consecutiveDebtMonths, payrollRemainder, empireState
        case missionCompleted, completedAtRelativeYear, completedAtMonth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        missionID = try container.decode(Int.self, forKey: .missionID)
        startYear = try container.decode(Int.self, forKey: .startYear)
        startMonth = try container.decode(Int.self, forKey: .startMonth)
        replaySeed = try container.decode(UInt64.self, forKey: .replaySeed)
        scheduler = try container.decode(CampaignEventScheduler.self, forKey: .scheduler)
        occurrences = try container.decodeIfPresent(
            [CampaignEventOccurrence].self, forKey: .occurrences
        ) ?? []
        effects = try container.decodeIfPresent([CampaignEventEffect].self, forKey: .effects) ?? []
        requests = try container.decodeIfPresent([CampaignRequestState].self, forKey: .requests) ?? []
        pendingGiftDeliveries = try container.decodeIfPresent(
            [CampaignGiftDelivery].self, forKey: .pendingGiftDeliveries
        ) ?? []
        menagerieAnimalIDs = try container.decodeIfPresent(
            Set<Int>.self, forKey: .menagerieAnimalIDs
        ) ?? []
        menagerieAnimalCountsByProductID = try container.decodeIfPresent(
            [Int: Int].self, forKey: .menagerieAnimalCountsByProductID
        ) ?? [:]
        cityStatusMutations = try container.decodeIfPresent(
            [CampaignCityStatusMutation].self, forKey: .cityStatusMutations
        ) ?? []
        normalAnnualWage = try container.decodeIfPresent(
            Int.self, forKey: .normalAnnualWage
        ) ?? Self.originalNormalAnnualWage
        consecutiveDebtMonths = try container.decodeIfPresent(
            Int.self, forKey: .consecutiveDebtMonths
        ) ?? 0
        payrollRemainder = try container.decodeIfPresent(Int.self, forKey: .payrollRemainder) ?? 0
        empireState = try container.decodeIfPresent(
            CampaignEmpireRuntimeState.self, forKey: .empireState
        )

        if let decodedOutcome = try container.decodeIfPresent(
            CampaignMissionOutcome.self, forKey: .outcome
        ) {
            outcome = decodedOutcome
        } else if try container.decodeIfPresent(Bool.self, forKey: .missionCompleted) == true {
            let relativeYear = try container.decodeIfPresent(
                Int.self, forKey: .completedAtRelativeYear
            ) ?? 0
            let month = try container.decodeIfPresent(Int.self, forKey: .completedAtMonth) ?? startMonth
            outcome = .victory(CampaignVictoryRecord(
                settlementYear: startYear + max(0, relativeYear),
                month: month
            ))
        } else {
            outcome = .running
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(missionID, forKey: .missionID)
        try container.encode(startYear, forKey: .startYear)
        try container.encode(startMonth, forKey: .startMonth)
        try container.encode(replaySeed, forKey: .replaySeed)
        try container.encode(scheduler, forKey: .scheduler)
        try container.encode(occurrences, forKey: .occurrences)
        try container.encode(effects, forKey: .effects)
        try container.encode(requests, forKey: .requests)
        try container.encode(pendingGiftDeliveries, forKey: .pendingGiftDeliveries)
        try container.encode(menagerieAnimalIDs, forKey: .menagerieAnimalIDs)
        try container.encode(menagerieAnimalCountsByProductID, forKey: .menagerieAnimalCountsByProductID)
        try container.encode(cityStatusMutations, forKey: .cityStatusMutations)
        try container.encode(normalAnnualWage, forKey: .normalAnnualWage)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(consecutiveDebtMonths, forKey: .consecutiveDebtMonths)
        try container.encode(payrollRemainder, forKey: .payrollRemainder)
        try container.encodeIfPresent(empireState, forKey: .empireState)
        // Retain the old keys for readers predating the outcome state machine.
        try container.encode(missionCompleted, forKey: .missionCompleted)
        try container.encodeIfPresent(completedAtRelativeYear, forKey: .completedAtRelativeYear)
        try container.encodeIfPresent(completedAtMonth, forKey: .completedAtMonth)
    }
}

public struct CampaignRequestState: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let occurrenceID: String
    public let sourceCityID: Int?
    public let productID: Int
    /// Cash is stored directly; physical commodities use internal units.
    public let amount: Int
    public let deadlineAbsoluteMonth: Int
    public private(set) var status: CampaignRequestStatus

    mutating func markFulfilled() { status = .fulfilled }
    mutating func markExpired() { status = .expired }
}

public struct CampaignGiftDelivery: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let occurrenceID: String
    public let sourceCityID: Int?
    public let commodityID: Int
    public let originalAmount: Int
    public private(set) var remainingAmount: Int

    mutating func accept(_ amount: Int) {
        remainingAmount = max(0, remainingAmount - max(0, amount))
    }
}

public struct CampaignCityStatusMutation: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let occurrenceID: String
    public let cityID: Int?
    public let secondaryCityID: Int?
    public let rawStatusChangeCode: UInt8
    public let amount: Int?
}

public enum CampaignEventEffectDisposition: String, Sendable, Hashable, Codable {
    case applied
    case pending
    /// The original action is retained, but its simulation subsystem (for
    /// example combat or terrain damage) is not yet active.
    case recorded
    case noEffect
}

public struct CampaignEventEffect: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let occurrenceID: String
    public let kindRawValue: UInt8
    public let productID: Int?
    public let amount: Int?
    public let cityID: Int?
    public let disposition: CampaignEventEffectDisposition

    public var kind: CampaignEventKind? { CampaignEventKind(rawValue: kindRawValue) }
}

public struct CampaignVictoryRecord: Sendable, Hashable, Codable {
    public let settlementYear: Int
    public let month: Int

    public init(settlementYear: Int, month: Int) {
        self.settlementYear = settlementYear
        self.month = min(max(month, 1), 12)
    }
}

public enum CampaignDefeatReason: Sendable, Hashable, Codable {
    case continuousDebt(months: Int)
}

public struct CampaignDefeatRecord: Sendable, Hashable, Codable {
    public let settlementYear: Int
    public let month: Int
    public let treasury: Int
    public let reason: CampaignDefeatReason

    public init(
        settlementYear: Int,
        month: Int,
        treasury: Int,
        reason: CampaignDefeatReason
    ) {
        self.settlementYear = settlementYear
        self.month = min(max(month, 1), 12)
        self.treasury = treasury
        self.reason = reason
    }
}

public enum CampaignMissionOutcome: Sendable, Hashable, Codable {
    case running
    case victory(CampaignVictoryRecord)
    case defeat(CampaignDefeatRecord)
}

public struct CampaignMissionAdvanceResult: Sendable, Hashable {
    public let occurrences: [CampaignEventOccurrence]
    public let effects: [CampaignEventEffect]
    public let expiredRequestIDs: [String]
    public let outcomeChangedNow: CampaignMissionOutcome?

    public var missionCompletedNow: Bool {
        guard case .victory = outcomeChangedNow else { return false }
        return true
    }

    public static let noChange = Self(
        occurrences: [],
        effects: [],
        expiredRequestIDs: [],
        outcomeChangedNow: nil
    )
}

/// Saveable live state for one original campaign mission.
///
/// This is the bridge between the already-decoded Campaign Creator records
/// and the native city clock. It deliberately applies only semantics verified
/// by the bundled Campaign Creator guide: requests, storage-aware gifts,
/// one-level supply/demand changes, imperial price changes and normal-wage
/// changes. Combat, disasters and raw city-status subtypes remain durable log
/// entries until their corresponding native systems exist.
public struct CampaignMissionRuntimeState: Sendable, Hashable, Codable {
    public static let cashProductID = 29
    public static let firstMenagerieProductID = 30
    public static let internalUnitsPerLoad = 100
    public static let originalNormalAnnualWage = 30

    public let missionID: Int
    public let startYear: Int
    public let startMonth: Int
    public let replaySeed: UInt64
    private var scheduler: CampaignEventScheduler
    public private(set) var occurrences: [CampaignEventOccurrence]
    public private(set) var effects: [CampaignEventEffect]
    public private(set) var requests: [CampaignRequestState]
    public private(set) var pendingGiftDeliveries: [CampaignGiftDelivery]
    public private(set) var menagerieAnimalIDs: Set<Int>
    public private(set) var menagerieAnimalCountsByProductID: [Int: Int]
    public private(set) var cityStatusMutations: [CampaignCityStatusMutation]
    public private(set) var normalAnnualWage: Int
    public private(set) var outcome: CampaignMissionOutcome
    public private(set) var consecutiveDebtMonths: Int
    public private(set) var payrollRemainder: Int
    /// Optional so saves written before the 0.32 empire runtime still decode.
    public private(set) var empireState: CampaignEmpireRuntimeState?

    public init(
        missionID: Int,
        startYear: Int,
        startMonth: Int,
        eventSet: CampaignMissionEventSet,
        replaySeed: UInt64,
        empireMap: CampaignEmpireMap? = nil,
        playerCityID: Int? = nil,
        cityNames: OriginalCityNameCatalog? = nil
    ) {
        self.missionID = missionID
        self.startYear = startYear
        self.startMonth = min(max(startMonth, 1), 12)
        self.replaySeed = replaySeed
        scheduler = CampaignEventScheduler(
            eventSet: eventSet,
            replaySeed: replaySeed,
            initialMonth: startMonth
        )
        occurrences = []
        effects = []
        requests = []
        pendingGiftDeliveries = []
        menagerieAnimalIDs = []
        menagerieAnimalCountsByProductID = [:]
        cityStatusMutations = []
        normalAnnualWage = Self.originalNormalAnnualWage
        outcome = .running
        consecutiveDebtMonths = 0
        payrollRemainder = 0
        if let empireMap, let playerCityID, let cityNames {
            empireState = CampaignEmpireRuntimeState(
                empireMap: empireMap,
                playerCityID: playerCityID,
                cityNames: cityNames
            )
        } else {
            empireState = nil
        }
    }

    public var pendingRequests: [CampaignRequestState] {
        requests.filter { $0.status == .pending }
    }

    public var missionCompleted: Bool {
        guard case .victory = outcome else { return false }
        return true
    }

    public var completedAtRelativeYear: Int? {
        guard case let .victory(record) = outcome else { return nil }
        return max(0, record.settlementYear - startYear)
    }

    public var completedAtMonth: Int? {
        guard case let .victory(record) = outcome else { return nil }
        return record.month
    }

    public var pendingGiftAmount: Int {
        pendingGiftDeliveries.reduce(0) { $0 + $1.remainingAmount }
    }

    @discardableResult
    public mutating func advance(
        settlementYear: Int,
        month: Int,
        city: inout DeterministicCityState,
        rules: EconomyRulesEngine,
        goalSet: CampaignMissionGoalSet?
    ) -> CampaignMissionAdvanceResult {
        guard outcome == .running else { return .noChange }
        let relativeYear = max(0, settlementYear - startYear)
        let absoluteMonth = relativeYear * 12 + min(max(month, 1), 12) - 1

        let workforce = city.workforceSnapshot(models: rules.models.buildings)
        let payrollNumerator = workforce.assignedWorkers * normalAnnualWage + payrollRemainder
        let monthlyPayroll = payrollNumerator / 120
        payrollRemainder = payrollNumerator % 120
        city.chargeOperatingExpense(monthlyPayroll)

        retryPendingGifts(in: &city)
        var expiredIDs: [String] = []
        for index in requests.indices where
            requests[index].status == .pending
                && absoluteMonth > requests[index].deadlineAbsoluteMonth {
            requests[index].markExpired()
            expiredIDs.append(requests[index].id)
        }

        var due = scheduler.advance(toRelativeYear: relativeYear, month: month)
        var applied = due.map { apply($0, to: &city, rules: rules) }

        if var empire = empireState {
            empire.advanceMonth(absoluteMonth: absoluteMonth)
            empireState = empire
        }

        var changedOutcome: CampaignMissionOutcome?
        if city.economy.treasury < 0 {
            consecutiveDebtMonths += 1
        } else {
            consecutiveDebtMonths = 0
        }
        if consecutiveDebtMonths >= 36 {
            let defeated: CampaignMissionOutcome = .defeat(CampaignDefeatRecord(
                settlementYear: settlementYear,
                month: month,
                treasury: city.economy.treasury,
                reason: .continuousDebt(months: 36)
            ))
            outcome = defeated
            changedOutcome = defeated
        } else if let goalSet,
           !goalSet.goals.isEmpty,
           CampaignGoalEvaluator.missionIsComplete(
            goalSet,
            against: city.campaignGoalProgressSnapshot(
                alliedCityCount: empireState?.alliedCityCount ?? 0,
                conqueredCityCount: empireState?.conqueredCityCount ?? 0,
                homageProgress: empireState?.homageProgress ?? 0,
                menagerieSpeciesCount: menagerieAnimalIDs.count
            )
           ) {
            let victory: CampaignMissionOutcome = .victory(CampaignVictoryRecord(
                settlementYear: settlementYear,
                month: month
            ))
            outcome = victory
            changedOutcome = victory
            let completionEvents = scheduler.advance(
                toRelativeYear: relativeYear,
                month: month,
                missionCompleted: true
            )
            due.append(contentsOf: completionEvents)
            applied.append(contentsOf: completionEvents.map {
                apply($0, to: &city, rules: rules)
            })
        }

        occurrences.append(contentsOf: due)
        effects.append(contentsOf: applied)
        return CampaignMissionAdvanceResult(
            occurrences: due,
            effects: applied,
            expiredRequestIDs: expiredIDs,
            outcomeChangedNow: changedOutcome
        )
    }

    @discardableResult
    public mutating func fulfillRequest(
        id: String,
        city: inout DeterministicCityState
    ) -> Bool {
        guard let index = requests.firstIndex(where: { $0.id == id && $0.status == .pending }) else {
            return false
        }
        let productID = requests[index].productID
        let amount = requests[index].amount
        if productID >= Self.firstMenagerieProductID {
            guard let speciesID = Self.canonicalMenagerieProductID(productID) else {
                return false
            }
            let available = menagerieAnimalCountsByProductID[speciesID, default: 0]
            guard available >= amount else { return false }
            let remaining = available - amount
            if remaining == 0 {
                menagerieAnimalCountsByProductID.removeValue(forKey: speciesID)
                menagerieAnimalIDs.remove(speciesID)
            } else {
                menagerieAnimalCountsByProductID[speciesID] = remaining
            }
        } else {
            guard city.fulfillCampaignRequest(commodityID: productID, amount: amount) else {
                return false
            }
        }
        requests[index].markFulfilled()
        return true
    }

    /// Adds animals obtained through scripted gifts or future native systems.
    /// Victory counts distinct species, while requests consume actual headcount.
    public mutating func receiveMenagerieAnimals(productID: Int, amount: Int) {
        guard let speciesID = Self.canonicalMenagerieProductID(productID),
              amount > 0 else { return }
        menagerieAnimalCountsByProductID[speciesID, default: 0] += amount
        menagerieAnimalIDs.insert(speciesID)
    }

    /// Continuation missions keep the physical menagerie inherited with the
    /// city. Script gifts use figure IDs 69...77 while emissary requests use
    /// product IDs 30...38; both are normalized before merging.
    public mutating func inheritMenagerie(
        animalCountsByProductID: [Int: Int]
    ) {
        for (productID, amount) in animalCountsByProductID where amount > 0 {
            receiveMenagerieAnimals(productID: productID, amount: amount)
        }
    }

    @discardableResult
    public mutating func sendEmissary(
        to cityID: Int,
        city: inout DeterministicCityState,
        cost: Int = 50
    ) -> Bool {
        guard var empire = empireState, city.payCampaignCash(cost) else { return false }
        guard empire.sendEmissary(to: cityID) else {
            _ = city.receiveCampaignCash(cost)
            return false
        }
        empireState = empire
        return true
    }

    @discardableResult
    public mutating func sendSpy(
        to cityID: Int,
        city: inout DeterministicCityState,
        cost: Int = 100
    ) -> Bool {
        guard var empire = empireState, city.payCampaignCash(cost) else { return false }
        guard empire.sendSpy(to: cityID) else {
            _ = city.receiveCampaignCash(cost)
            return false
        }
        empireState = empire
        return true
    }

    @discardableResult
    public mutating func requestAlliance(with cityID: Int) -> Bool {
        guard var empire = empireState, empire.requestAlliance(with: cityID) else {
            return false
        }
        empireState = empire
        return true
    }

    @discardableResult
    public mutating func conquerCity(
        _ cityID: Int,
        using city: DeterministicCityState
    ) -> Bool {
        guard var empire = empireState, empire.conquer(
            cityID: cityID,
            playerHasArmy: city.military.units.contains { $0.hitPoints > 0 }
        ) else { return false }
        empireState = empire
        return true
    }

    @discardableResult
    public mutating func prepayHeroHomage(
        heroID: Int,
        city: inout DeterministicCityState,
        months: Int = 1,
        costPerMonth: Int = 100
    ) -> Bool {
        let months = max(1, months)
        let cost = months * max(0, costPerMonth)
        guard var empire = empireState, city.payCampaignCash(cost) else { return false }
        empire.prepayHomage(heroID: heroID, months: months)
        empireState = empire
        return true
    }

    /// Requests one missing animal family through an arrived emissary. The
    /// palace check follows the original menagerie rule; repeated species do
    /// not advance the goal.
    @discardableResult
    public mutating func requestMenagerieAnimal(
        from cityID: Int,
        using city: DeterministicCityState
    ) -> Int? {
        guard city.placedBuildings.contains(where: { $0.buildingID == 110 }),
              let speciesID = (Self.firstMenagerieProductID..<(Self.firstMenagerieProductID + 9))
                .first(where: { !menagerieAnimalIDs.contains($0) }),
              var empire = empireState,
              let source = empire.cities.first(where: {
                  $0.id == cityID && $0.isActive && $0.isVisible
                      && $0.emissaryStatus == .arrived && $0.favor >= 60
              }) else { return nil }
        receiveMenagerieAnimals(productID: speciesID, amount: 1)
        _ = empire.adjustFavor(cityID: source.id, amount: -5)
        empireState = empire
        return speciesID
    }

    public static func canonicalMenagerieProductID(_ productID: Int) -> Int? {
        switch productID {
        case firstMenagerieProductID..<(firstMenagerieProductID + 9):
            productID
        case 69...77:
            firstMenagerieProductID + productID - 69
        default:
            nil
        }
    }

    @discardableResult
    public mutating func fulfillFirstPendingRequest(
        city: inout DeterministicCityState
    ) -> Bool {
        guard let request = pendingRequests.sorted(by: {
            $0.deadlineAbsoluteMonth == $1.deadlineAbsoluteMonth
                ? $0.id < $1.id
                : $0.deadlineAbsoluteMonth < $1.deadlineAbsoluteMonth
        }).first else { return false }
        return fulfillRequest(id: request.id, city: &city)
    }

    private mutating func retryPendingGifts(in city: inout DeterministicCityState) {
        for index in pendingGiftDeliveries.indices where
            pendingGiftDeliveries[index].remainingAmount > 0 {
            let accepted = city.receiveCampaignCommodityGift(
                commodityID: pendingGiftDeliveries[index].commodityID,
                amount: pendingGiftDeliveries[index].remainingAmount
            )
            pendingGiftDeliveries[index].accept(accepted)
        }
        pendingGiftDeliveries.removeAll { $0.remainingAmount == 0 }
    }

    private mutating func apply(
        _ occurrence: CampaignEventOccurrence,
        to city: inout DeterministicCityState,
        rules: EconomyRulesEngine
    ) -> CampaignEventEffect {
        let kind = occurrence.kind
        var disposition = CampaignEventEffectDisposition.recorded

        switch kind {
        case .request:
            if let productID = occurrence.productID, let amount = occurrence.amount {
                let requestedAmount = Self.runtimeAmount(productID: productID, amount: amount)
                requests.append(CampaignRequestState(
                    id: occurrence.id,
                    occurrenceID: occurrence.id,
                    sourceCityID: occurrence.cityFromID,
                    productID: productID,
                    amount: requestedAmount,
                    deadlineAbsoluteMonth: occurrence.relativeYear * 12 + occurrence.month - 1
                        + occurrence.timeAllowed,
                    status: .pending
                ))
                disposition = .pending
            } else {
                disposition = .noEffect
            }

        case .gift:
            if let productID = occurrence.productID, let amount = occurrence.amount {
                if productID == Self.cashProductID {
                    disposition = city.receiveCampaignCash(amount) > 0 ? .applied : .noEffect
                } else if productID < Self.firstMenagerieProductID {
                    let internalAmount = amount * Self.internalUnitsPerLoad
                    let accepted = city.receiveCampaignCommodityGift(
                        commodityID: productID,
                        amount: internalAmount
                    )
                    if accepted < internalAmount {
                        pendingGiftDeliveries.append(CampaignGiftDelivery(
                            id: occurrence.id,
                            occurrenceID: occurrence.id,
                            sourceCityID: occurrence.cityFromID,
                            commodityID: productID,
                            originalAmount: internalAmount,
                            remainingAmount: internalAmount - accepted
                        ))
                        disposition = .pending
                    } else {
                        disposition = .applied
                    }
                } else {
                    receiveMenagerieAnimals(productID: productID, amount: amount)
                    disposition = .applied
                }
            } else {
                disposition = .noEffect
            }

        case .wageIncrease, .wageDecrease:
            if let amount = occurrence.amount {
                normalAnnualWage = max(
                    0,
                    normalAnnualWage + (kind == .wageIncrease ? amount : -amount)
                )
                disposition = .applied
            } else {
                disposition = .noEffect
            }

        case .demandIncrease, .demandDecrease,
             .supplyIncrease, .supplyDecrease,
             .priceIncrease, .priceDecrease:
            if let kind, let productID = occurrence.productID {
                let changed = city.adjustCampaignTrade(
                    kind: kind,
                    partnerID: occurrence.cityFromID,
                    commodityID: productID,
                    amount: occurrence.amount ?? 0,
                    models: rules.models
                )
                disposition = changed > 0 ? .applied : .recorded
            } else {
                disposition = .noEffect
            }

        case .cityStatusChange:
            cityStatusMutations.append(CampaignCityStatusMutation(
                id: occurrence.id,
                occurrenceID: occurrence.id,
                cityID: occurrence.cityFromID,
                secondaryCityID: occurrence.secondarySelectionID,
                rawStatusChangeCode: occurrence.statusChangeCode,
                amount: occurrence.amount
            ))
            let cityChanged = city.applyCampaignCityEvent(occurrence).changedCity
            var empireChanged = false
            if var empire = empireState {
                empireChanged = empire.applyStatus(
                    rawCode: occurrence.statusChangeCode,
                    cityID: occurrence.cityFromID,
                    secondaryCityID: occurrence.secondarySelectionID,
                    amount: occurrence.amount
                )
                if let code = CampaignCityStatusCode(rawValue: occurrence.statusChangeCode),
                   let cityID = occurrence.cityFromID {
                    if code == .tradeSuspended || code == .tradeShutsDown
                        || code == .cityBecomesInactive {
                        city.setCampaignTradeOpen(false, partnerID: cityID)
                    } else if code == .tradeResumed || code == .tradeOpensUp
                        || code == .cityBecomesActive {
                        city.setCampaignTradeOpen(true, partnerID: cityID)
                    }
                }
                empireState = empire
            }
            disposition = (cityChanged || empireChanged) ? .applied : .recorded

        case .invasion, .earthquake, .drought, .flood, .message:
            let application = city.applyCampaignCityEvent(occurrence)
            if kind == .invasion, application.invasionAlertID != nil {
                disposition = .pending
            } else {
                disposition = application.changedCity ? .applied : .recorded
            }

        case .favorIncrease, .favorDecrease:
            if var empire = empireState,
               empire.adjustFavor(
                cityID: occurrence.cityFromID,
                amount: (kind == .favorIncrease ? 1 : -1) * (occurrence.amount ?? 0)
               ) {
                empireState = empire
                disposition = .applied
            } else {
                disposition = .recorded
            }

        case .tributeToPlayer:
            if let amount = occurrence.amount {
                if occurrence.productID == nil || occurrence.productID == Self.cashProductID {
                    disposition = city.receiveCampaignCash(amount) > 0 ? .applied : .noEffect
                } else if let productID = occurrence.productID {
                    let accepted = city.receiveCampaignCommodityGift(
                        commodityID: productID,
                        amount: amount * Self.internalUnitsPerLoad
                    )
                    disposition = accepted > 0 ? .applied : .pending
                }
            }

        case .tributeDemand:
            if let productID = occurrence.productID, let amount = occurrence.amount {
                requests.append(CampaignRequestState(
                    id: occurrence.id,
                    occurrenceID: occurrence.id,
                    sourceCityID: occurrence.cityFromID,
                    productID: productID,
                    amount: Self.runtimeAmount(productID: productID, amount: amount),
                    deadlineAbsoluteMonth: occurrence.relativeYear * 12 + occurrence.month - 1
                        + occurrence.timeAllowed,
                    status: .pending
                ))
                disposition = .pending
            }

        case .heroArrives:
            if var empire = empireState {
                empire.activateHero(
                    occurrence.productID ?? occurrence.secondarySelectionID ?? occurrence.cityFromID ?? 0,
                    prepaidMonths: 1
                )
                empireState = empire
                disposition = .applied
            }

        case .emissaryStatus40, .emissaryStatus42,
             .spyStatus41, .spyStatus43:
            if var empire = empireState,
               empire.markAgentStatus(
                cityID: occurrence.cityFromID,
                emissary: kind == .emissaryStatus40 || kind == .emissaryStatus42,
                exposed: kind == .spyStatus43
               ) {
                empireState = empire
                disposition = .applied
            }

        case .rivalArmyAway:
            if var empire = empireState,
               empire.setRivalArmyAway(cityID: occurrence.cityFromID, true) {
                empireState = empire
                disposition = .applied
            }

        case .none, .freeEvent, .seaTradeProblem, .landTradeProblem,
             .unused6, .unused11, .unused12, .unused13,
             .sellerPriceIncrease, .sellerPriceDecrease,
             .unused27, .unused28,
             .requestFulfillment, .demandRefusal,
             .unused35, .unused36, .unused37, .unused38:
            disposition = .recorded

        case .cityMessage, .strike:
            disposition = city.applyCampaignCityEvent(occurrence).changedCity ? .applied : .recorded
        }

        return CampaignEventEffect(
            id: occurrence.id,
            occurrenceID: occurrence.id,
            kindRawValue: occurrence.kindRawValue,
            productID: occurrence.productID,
            amount: occurrence.amount,
            cityID: occurrence.cityFromID,
            disposition: disposition
        )
    }

    private static func runtimeAmount(productID: Int, amount: Int) -> Int {
        (productID == cashProductID || productID >= firstMenagerieProductID)
            ? amount
            : amount * internalUnitsPerLoad
    }
}
