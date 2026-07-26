import Foundation

public struct CampaignEventOccurrence: Identifiable, Sendable, Hashable, Codable {
    public let eventID: Int
    public let occurrenceIndex: Int
    public let kindRawValue: UInt8
    public let triggerMode: CampaignEventTriggerMode
    public let relativeYear: Int
    public let month: Int
    public let productID: Int?
    public let amount: Int?
    public let cityFromID: Int?
    public let secondarySelectionID: Int?
    public let timeAllowed: Int
    public let statusChangeCode: UInt8

    public var id: String { "\(eventID):\(occurrenceIndex)" }
    public var kind: CampaignEventKind? { CampaignEventKind(rawValue: kindRawValue) }

    public init(
        eventID: Int,
        occurrenceIndex: Int,
        kindRawValue: UInt8,
        triggerMode: CampaignEventTriggerMode,
        relativeYear: Int,
        month: Int,
        productID: Int? = nil,
        amount: Int? = nil,
        cityFromID: Int? = nil,
        secondarySelectionID: Int? = nil,
        timeAllowed: Int = 0,
        statusChangeCode: UInt8 = 0
    ) {
        self.eventID = eventID
        self.occurrenceIndex = occurrenceIndex
        self.kindRawValue = kindRawValue
        self.triggerMode = triggerMode
        self.relativeYear = relativeYear
        self.month = month
        self.productID = productID
        self.amount = amount
        self.cityFromID = cityFromID
        self.secondarySelectionID = secondarySelectionID
        self.timeAllowed = timeAllowed
        self.statusChangeCode = statusChangeCode
    }
}

/// Deterministic monthly event scheduling for an original campaign mission.
///
/// The original archives provide ranges, so the scheduler uses a stable replay
/// seed to select values. One-time events fire once at their selected year and
/// stored month. Recurring events use the selected year range as the interval
/// before their next occurrence. Mission-complete events fire when the caller
/// reports that transition.
public struct CampaignEventScheduler: Sendable, Hashable, Codable {
    public let missionID: Int
    public let replaySeed: UInt64

    private let events: [CampaignEventRecord]
    private var nextRelativeYear: [Int: Int]
    private var occurrenceCounts: [Int: Int]
    private var completedEventIDs: Set<Int>
    private var latestAbsoluteMonth: Int

    public init(
        eventSet: CampaignMissionEventSet,
        replaySeed: UInt64,
        initialMonth: Int = 1
    ) {
        missionID = eventSet.id
        self.replaySeed = replaySeed
        events = eventSet.events.sorted { $0.id < $1.id }
        nextRelativeYear = [:]
        occurrenceCounts = [:]
        completedEventIDs = []
        // Events occur at the end of their authored month. Missions in the
        // shipped campaigns start in June, so January-May events in relative
        // year zero are already in the past rather than firing in a burst on
        // the first native turn.
        latestAbsoluteMonth = min(max(initialMonth, 1), 12) - 2

        for event in events where event.triggerMode != .missionComplete {
            if let year = Self.select(
                from: event.year,
                seed: replaySeed,
                eventID: event.id,
                occurrenceIndex: 0,
                fieldSalt: 0x5945_4152
            ) {
                nextRelativeYear[event.id] = max(0, year)
            }
        }
    }

    /// Advances the event clock. Skipped months are caught up in chronological
    /// order; advancing backwards is ignored. A mission-complete transition may
    /// be reported on a second call for the current month.
    public mutating func advance(
        toRelativeYear relativeYear: Int,
        month: Int,
        missionCompleted: Bool = false
    ) -> [CampaignEventOccurrence] {
        guard relativeYear >= 0, (1...12).contains(month) else { return [] }
        let currentAbsoluteMonth = relativeYear * 12 + month - 1
        guard currentAbsoluteMonth >= latestAbsoluteMonth else { return [] }

        var due: [CampaignEventOccurrence] = []
        for event in events {
            switch event.triggerMode {
            case .missionComplete:
                guard missionCompleted, !completedEventIDs.contains(event.id) else { continue }
                let index = occurrenceCounts[event.id, default: 0]
                due.append(makeOccurrence(
                    event: event,
                    occurrenceIndex: index,
                    relativeYear: relativeYear,
                    month: month
                ))
                occurrenceCounts[event.id] = index + 1
                completedEventIDs.insert(event.id)

            case .oneTime:
                guard !completedEventIDs.contains(event.id),
                      let year = nextRelativeYear[event.id] else { continue }
                let target = year * 12 + Int(event.monthIndex)
                guard target > latestAbsoluteMonth, target <= currentAbsoluteMonth else { continue }
                let index = occurrenceCounts[event.id, default: 0]
                due.append(makeOccurrence(
                    event: event,
                    occurrenceIndex: index,
                    relativeYear: year,
                    month: event.monthNumber
                ))
                occurrenceCounts[event.id] = index + 1
                completedEventIDs.insert(event.id)

            case .recurring:
                guard var year = nextRelativeYear[event.id] else { continue }
                var target = year * 12 + Int(event.monthIndex)
                while target > latestAbsoluteMonth, target <= currentAbsoluteMonth {
                    let index = occurrenceCounts[event.id, default: 0]
                    due.append(makeOccurrence(
                        event: event,
                        occurrenceIndex: index,
                        relativeYear: year,
                        month: event.monthNumber
                    ))
                    occurrenceCounts[event.id] = index + 1
                    let selectedInterval = Self.select(
                        from: event.year,
                        seed: replaySeed,
                        eventID: event.id,
                        occurrenceIndex: index + 1,
                        fieldSalt: 0x494E_5456
                    ) ?? 1
                    year += max(1, selectedInterval)
                    nextRelativeYear[event.id] = year
                    target = year * 12 + Int(event.monthIndex)
                }
            }
        }

        latestAbsoluteMonth = max(latestAbsoluteMonth, currentAbsoluteMonth)
        return due.sorted {
            let lhsDate = $0.relativeYear * 12 + $0.month
            let rhsDate = $1.relativeYear * 12 + $1.month
            return lhsDate == rhsDate ? $0.eventID < $1.eventID : lhsDate < rhsDate
        }
    }

    private func makeOccurrence(
        event: CampaignEventRecord,
        occurrenceIndex: Int,
        relativeYear: Int,
        month: Int
    ) -> CampaignEventOccurrence {
        CampaignEventOccurrence(
            eventID: event.id,
            occurrenceIndex: occurrenceIndex,
            kindRawValue: event.kindRawValue,
            triggerMode: event.triggerMode,
            relativeYear: relativeYear,
            month: month,
            productID: Self.select(
                from: event.product,
                seed: replaySeed,
                eventID: event.id,
                occurrenceIndex: occurrenceIndex,
                fieldSalt: 0x5052_4F44
            ),
            amount: Self.select(
                from: event.amount,
                seed: replaySeed,
                eventID: event.id,
                occurrenceIndex: occurrenceIndex,
                fieldSalt: 0x414D_4F55
            ),
            cityFromID: Self.select(
                from: event.cityFrom,
                seed: replaySeed,
                eventID: event.id,
                occurrenceIndex: occurrenceIndex,
                fieldSalt: 0x4349_5459
            ),
            secondarySelectionID: Self.select(
                from: event.secondarySelection,
                seed: replaySeed,
                eventID: event.id,
                occurrenceIndex: occurrenceIndex,
                fieldSalt: 0x5345_434F
            ),
            timeAllowed: max(0, Int(event.timeAllowed)),
            statusChangeCode: event.statusChangeCode
        )
    }

    private static func select(
        from range: CampaignEventRange,
        seed: UInt64,
        eventID: Int,
        occurrenceIndex: Int,
        fieldSalt: UInt64
    ) -> Int? {
        guard let bounds = range.bounds else { return nil }
        guard bounds.lowerBound != bounds.upperBound else { return bounds.lowerBound }
        let width = UInt64(bounds.upperBound - bounds.lowerBound + 1)
        var value = seed
            ^ UInt64(truncatingIfNeeded: eventID) &* 0x9E37_79B9_7F4A_7C15
            ^ UInt64(truncatingIfNeeded: occurrenceIndex) &* 0xBF58_476D_1CE4_E5B9
            ^ fieldSalt
        value &+= 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return bounds.lowerBound + Int(value % width)
    }
}
