import Foundation

public struct HouseHealthSafetyRecord: Sendable, Hashable, Codable {
    public let houseID: Int
    public var diseaseRisk: Int
    public var crimeRisk: Int

    public init(houseID: Int, diseaseRisk: Int = 0, crimeRisk: Int = 0) {
        self.houseID = houseID
        self.diseaseRisk = max(0, diseaseRisk)
        self.crimeRisk = max(0, crimeRisk)
    }
}

public enum HouseHealthSafetyEventKind: String, Sendable, Hashable, Codable {
    case diseaseOutbreak
    case theft
}

public struct HouseHealthSafetyEvent: Sendable, Hashable, Codable {
    public let houseID: Int
    public let kind: HouseHealthSafetyEventKind
    public let affectedResidents: Int
    public let cashLoss: Int
}

public struct PublicHealthSafetyMonthlySettlement: Sendable, Hashable, Codable {
    public let year: Int
    public let month: Int
    public let events: [HouseHealthSafetyEvent]
    public let diseaseDeaths: Int
    public let stolenCash: Int
    public let medicallyCoveredHouseIDs: Set<Int>
    public let protectedHouseIDs: Set<Int>
}

/// Residential disease and crime simulation using the original house table's
/// risk increments and bases. Road-delivered services reduce risk before the
/// deterministic 100-point incident threshold is evaluated.
public struct DeterministicPublicHealthSafetyState: Sendable, Hashable, Codable {
    public private(set) var records: [HouseHealthSafetyRecord]
    public private(set) var lastSettlement: PublicHealthSafetyMonthlySettlement?

    public init() {
        records = []
        lastSettlement = nil
    }

    @discardableResult
    public mutating func advanceMonth(
        calendar: SimulationCalendar,
        houses: inout [ResidentialUnit],
        models: BuildingModelTable
    ) -> PublicHealthSafetyMonthlySettlement {
        let houseIDs = Set(houses.map(\.id))
        records.removeAll { !houseIDs.contains($0.houseID) }
        for house in houses where !records.contains(where: { $0.houseID == house.id }) {
            records.append(HouseHealthSafetyRecord(
                houseID: house.id,
                crimeRisk: max(0, models[houseLevelID: house.houseLevelID]?.crimeRiskBase ?? 0)
            ))
        }

        var events: [HouseHealthSafetyEvent] = []
        var deaths = 0
        var stolenCash = 0
        var medicalCoverage: Set<Int> = []
        var protection: Set<Int> = []
        for recordIndex in records.indices.sorted(by: { records[$0].houseID < records[$1].houseID }) {
            guard let houseIndex = houses.firstIndex(where: { $0.id == records[recordIndex].houseID }),
                  houses[houseIndex].residents > 0,
                  let model = models[houseLevelID: houses[houseIndex].houseLevelID] else { continue }

            let services = houses[houseIndex].serviceCoverage
            let medicallyCovered = services.contains(.water)
                || services.contains(.herbalist)
                || services.contains(.acupuncture)
            if medicallyCovered { medicalCoverage.insert(houses[houseIndex].id) }
            if services.contains(.constable) { protection.insert(houses[houseIndex].id) }

            var diseaseIncrement = max(0, model.diseaseRiskIncrement)
            if houses[houseIndex].foodSupplyAmount == 0 { diseaseIncrement += 5 }
            if services.contains(.water) { diseaseIncrement -= 8 }
            if services.contains(.herbalist) { diseaseIncrement -= 20 }
            if services.contains(.acupuncture) { diseaseIncrement -= 25 }
            records[recordIndex].diseaseRisk = max(
                0,
                records[recordIndex].diseaseRisk + diseaseIncrement
            )

            var crimeIncrement = max(0, model.crimeRiskIncrement)
            if !houses[houseIndex].hasTaxCoverage { crimeIncrement += max(0, model.crimeRiskBase) }
            if services.contains(.constable) { crimeIncrement -= 50 }
            records[recordIndex].crimeRisk = max(0, records[recordIndex].crimeRisk + crimeIncrement)

            if records[recordIndex].diseaseRisk >= 100 {
                let affected = min(
                    houses[houseIndex].residents,
                    max(1, houses[houseIndex].residents / 10)
                )
                houses[houseIndex].residents -= affected
                houses[houseIndex].desirability -= 10
                deaths += affected
                events.append(HouseHealthSafetyEvent(
                    houseID: houses[houseIndex].id,
                    kind: .diseaseOutbreak,
                    affectedResidents: affected,
                    cashLoss: 0
                ))
                records[recordIndex].diseaseRisk = 25
            }

            if records[recordIndex].crimeRisk >= 100 {
                let loss = max(1, houses[houseIndex].residents * 2)
                stolenCash += loss
                houses[houseIndex].desirability -= 8
                if let commodityID = houses[houseIndex].suppliesByCommodityID
                    .filter({ $0.value > 0 })
                    .map(\.key)
                    .sorted()
                    .first {
                    _ = houses[houseIndex].consumeSupply(commodityID: commodityID, amount: 100)
                }
                events.append(HouseHealthSafetyEvent(
                    houseID: houses[houseIndex].id,
                    kind: .theft,
                    affectedResidents: 0,
                    cashLoss: loss
                ))
                records[recordIndex].crimeRisk = 25
            }
        }
        let settlement = PublicHealthSafetyMonthlySettlement(
            year: calendar.year,
            month: calendar.month,
            events: events,
            diseaseDeaths: deaths,
            stolenCash: stolenCash,
            medicallyCoveredHouseIDs: medicalCoverage,
            protectedHouseIDs: protection
        )
        lastSettlement = settlement
        return settlement
    }
}
