import Foundation

/// Exact runtime status identifiers from original text group 35. Keeping the
/// unused slots preserves the values written by original and custom campaigns.
public enum CampaignCityStatusCode: UInt8, Sendable, Hashable, Codable {
    case tradeSuspended = 0
    case tradeResumed = 1
    case tradeShutsDown = 2
    case tradeOpensUp = 3
    case tributeSuspended = 4
    case tributeResumed = 5
    case rebellion = 6
    case rebellionQuelled = 7
    case unused8 = 8
    case rivalBecomesAlly = 9
    case cityBecomesRival = 10
    case cityBecomesVassal = 11
    case vassalBecomesRival = 12
    case unused13 = 13
    case militaryBuildup = 14
    case militaryDecline = 15
    case economicProsperity = 16
    case economicDecline = 17
    case cityBecomesActive = 18
    case cityBecomesInactive = 19
    case cityAppears = 20
    case cityDisappears = 21
    case unused22 = 22
    case rebellionOver = 23
    case cityConquered = 24
    case tradeRequested = 25
    case allianceRequested = 26
    case emissaryArrives = 27
    case addFavor = 28
    case setFavor = 29
    case subtractFavor = 30
}

public enum CampaignDiplomaticRelationship: String, Sendable, Hashable, Codable {
    case rival
    case ally
    case vassal
}

public enum CampaignAgentStatus: String, Sendable, Hashable, Codable {
    case idle
    case arrived
    case exposed
}

public struct CampaignEmpireCityLiveState: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let name: String
    public private(set) var isActive: Bool
    public private(set) var isVisible: Bool
    public private(set) var relationship: CampaignDiplomaticRelationship
    public private(set) var favor: Int
    public private(set) var militaryStrength: Int
    public private(set) var economicStrength: Int
    public private(set) var tradeIsOpen: Bool
    public private(set) var tributeIsEnabled: Bool
    public private(set) var isRebelling: Bool
    public private(set) var emissaryStatus: CampaignAgentStatus
    public private(set) var spyStatus: CampaignAgentStatus
    public private(set) var rivalArmyIsAway: Bool

    init(city: CampaignEmpireCity, name: String, isPlayerCity: Bool) {
        id = city.id
        self.name = name
        isActive = city.isActive
        isVisible = city.isActive
        relationship = isPlayerCity ? .ally : .rival
        favor = min(100, max(0, city.initialFavor))
        militaryStrength = isPlayerCity ? 0 : 3
        economicStrength = isPlayerCity ? 0 : 3
        tradeIsOpen = city.tradeVisitInterval == 34 || city.tradeVisitInterval == 4
        tributeIsEnabled = false
        isRebelling = false
        emissaryStatus = .idle
        spyStatus = .idle
        rivalArmyIsAway = false
    }

    mutating func setFavor(_ value: Int) {
        favor = min(100, max(0, value))
    }

    mutating func adjustFavor(_ amount: Int) { setFavor(favor + amount) }
    mutating func setRelationship(_ value: CampaignDiplomaticRelationship) {
        relationship = value
        tributeIsEnabled = value == .vassal
        if value != .vassal { isRebelling = false }
    }

    mutating func applyStatus(_ code: CampaignCityStatusCode, amount: Int) {
        switch code {
        case .tradeSuspended, .tradeShutsDown:
            tradeIsOpen = false
        case .tradeResumed, .tradeOpensUp:
            tradeIsOpen = true
        case .tributeSuspended:
            tributeIsEnabled = false
        case .tributeResumed:
            tributeIsEnabled = relationship == .vassal
        case .rebellion:
            if relationship == .vassal { isRebelling = true }
        case .rebellionQuelled, .rebellionOver:
            isRebelling = false
        case .rivalBecomesAlly:
            setRelationship(.ally)
        case .cityBecomesRival, .vassalBecomesRival:
            setRelationship(.rival)
        case .cityBecomesVassal, .cityConquered:
            setRelationship(.vassal)
        case .militaryBuildup:
            militaryStrength = min(6, militaryStrength + max(1, amount))
        case .militaryDecline:
            militaryStrength = max(0, militaryStrength - max(1, amount))
        case .economicProsperity:
            economicStrength = min(5, economicStrength + max(1, amount))
        case .economicDecline:
            economicStrength = max(0, economicStrength - max(1, amount))
        case .cityBecomesActive:
            isActive = true
        case .cityBecomesInactive:
            isActive = false
        case .cityAppears:
            isVisible = true
        case .cityDisappears:
            isVisible = false
        case .emissaryArrives:
            emissaryStatus = .arrived
        case .addFavor:
            adjustFavor(max(0, amount))
        case .setFavor:
            setFavor(amount)
        case .subtractFavor:
            adjustFavor(-max(0, amount))
        case .tradeRequested, .allianceRequested, .unused8, .unused13, .unused22:
            break
        }
    }

    mutating func receiveEmissary() {
        emissaryStatus = .arrived
        adjustFavor(10)
    }

    mutating func receiveSpy() { spyStatus = .arrived }
    mutating func exposeSpy() { spyStatus = .exposed }
    mutating func setRivalArmyAway(_ value: Bool) { rivalArmyIsAway = value }
}

/// Save-compatible live empire state. It is initialized from the embedded
/// empire map, then mutated by original campaign events and player diplomacy.
public struct CampaignEmpireRuntimeState: Sendable, Hashable, Codable {
    public let playerCityID: Int
    public private(set) var cities: [CampaignEmpireCityLiveState]
    public private(set) var activeHeroIDs: Set<Int>
    public private(set) var homageProgress: Int
    public private(set) var prepaidHomageMonths: Int
    private var lastAdvancedAbsoluteMonth: Int?

    public init(
        empireMap: CampaignEmpireMap,
        playerCityID: Int,
        cityNames: OriginalCityNameCatalog
    ) {
        self.playerCityID = playerCityID
        cities = empireMap.cities.map { city in
            CampaignEmpireCityLiveState(
                city: city,
                name: cityNames[nameID: city.nameID] ?? "City #\(city.id)",
                isPlayerCity: city.id == playerCityID
            )
        }
        activeHeroIDs = []
        homageProgress = 0
        prepaidHomageMonths = 0
        lastAdvancedAbsoluteMonth = nil
    }

    public var alliedCityCount: Int {
        cities.count { $0.id != playerCityID && $0.relationship == .ally && !$0.isRebelling }
    }

    public var conqueredCityCount: Int {
        cities.count { $0.id != playerCityID && $0.relationship == .vassal && !$0.isRebelling }
    }

    public var visibleForeignCities: [CampaignEmpireCityLiveState] {
        cities.filter { $0.id != playerCityID && $0.isVisible }
    }

    @discardableResult
    public mutating func applyStatus(
        rawCode: UInt8,
        cityID: Int?,
        secondaryCityID: Int?,
        amount: Int?
    ) -> Bool {
        guard let code = CampaignCityStatusCode(rawValue: rawCode),
              let cityID, let index = cities.firstIndex(where: { $0.id == cityID }) else {
            return false
        }
        if code == .cityConquered, secondaryCityID != nil, secondaryCityID != playerCityID {
            // A foreign conquest changes allegiance based on the attacker.
            if let attacker = cities.first(where: { $0.id == secondaryCityID }),
               attacker.relationship == .rival {
                cities[index].setRelationship(.rival)
                return true
            }
        }
        cities[index].applyStatus(code, amount: amount ?? 0)
        return true
    }

    @discardableResult
    public mutating func adjustFavor(cityID: Int?, amount: Int) -> Bool {
        guard let cityID, let index = cities.firstIndex(where: { $0.id == cityID }) else {
            return false
        }
        cities[index].adjustFavor(amount)
        return true
    }

    @discardableResult
    public mutating func sendEmissary(to cityID: Int) -> Bool {
        guard let index = cities.firstIndex(where: {
            $0.id == cityID && $0.id != playerCityID && $0.isActive && $0.isVisible
        }) else { return false }
        cities[index].receiveEmissary()
        return true
    }

    @discardableResult
    public mutating func sendSpy(to cityID: Int) -> Bool {
        guard let index = cities.firstIndex(where: {
            $0.id == cityID && $0.id != playerCityID && $0.isActive && $0.isVisible
        }) else { return false }
        cities[index].receiveSpy()
        return true
    }

    @discardableResult
    public mutating func requestAlliance(with cityID: Int) -> Bool {
        guard let index = cities.firstIndex(where: {
            $0.id == cityID && $0.id != playerCityID && $0.isActive && $0.isVisible
                && $0.relationship == .rival && $0.emissaryStatus == .arrived && $0.favor >= 60
        }) else { return false }
        cities[index].setRelationship(.ally)
        return true
    }

    @discardableResult
    public mutating func conquer(cityID: Int, playerHasArmy: Bool) -> Bool {
        guard playerHasArmy, let index = cities.firstIndex(where: {
            $0.id == cityID && $0.id != playerCityID && $0.isActive && $0.isVisible
                && $0.relationship == .rival && ($0.militaryStrength < 6 || $0.rivalArmyIsAway)
        }) else { return false }
        cities[index].setRelationship(.vassal)
        cities[index].setRivalArmyAway(false)
        return true
    }

    public mutating func markAgentStatus(
        cityID: Int?,
        emissary: Bool,
        exposed: Bool
    ) -> Bool {
        guard let cityID, let index = cities.firstIndex(where: { $0.id == cityID }) else {
            return false
        }
        if emissary {
            cities[index].receiveEmissary()
        } else if exposed {
            cities[index].exposeSpy()
        } else {
            cities[index].receiveSpy()
        }
        return true
    }

    public mutating func setRivalArmyAway(cityID: Int?, _ value: Bool) -> Bool {
        guard let cityID, let index = cities.firstIndex(where: { $0.id == cityID }) else {
            return false
        }
        cities[index].setRivalArmyAway(value)
        return true
    }

    public mutating func activateHero(_ heroID: Int, prepaidMonths: Int = 0) {
        guard heroID >= 0 else { return }
        activeHeroIDs.insert(heroID)
        prepaidHomageMonths += max(0, prepaidMonths)
    }

    public mutating func prepayHomage(heroID: Int, months: Int) {
        guard months > 0 else { return }
        activeHeroIDs.insert(heroID)
        prepaidHomageMonths += months
    }

    public mutating func advanceMonth(absoluteMonth: Int) {
        guard lastAdvancedAbsoluteMonth != absoluteMonth else { return }
        lastAdvancedAbsoluteMonth = absoluteMonth
        if !activeHeroIDs.isEmpty, prepaidHomageMonths > 0 {
            homageProgress += 1
            prepaidHomageMonths -= 1
        }
    }
}
