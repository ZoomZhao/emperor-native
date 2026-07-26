import Foundation

/// One completed original accounting year. Emperor measures production and
/// profit from the beginning of February through the end of the following
/// January, rather than by the civil calendar year.
public struct AnnualCityAccountingRecord: Sendable, Hashable, Codable {
    public let startYear: Int
    public let endYear: Int
    public let productionUnitsByCommodityID: [Int: Int]
    public let income: Int
    public let expenses: Int

    public var profit: Int { income - expenses }
}

/// Replay-stable production/profit accounting shared by city simulation and
/// campaign goal evaluation. Production uses the original internal units: one
/// displayed load is 100 units.
public struct DeterministicProductionAccounting: Sendable, Hashable, Codable {
    public private(set) var currentCycleStartYear: Int?
    public private(set) var currentProductionUnitsByCommodityID: [Int: Int]
    public private(set) var currentIncome: Int
    public private(set) var currentExpenses: Int
    public private(set) var bestYearlyProductionUnitsByCommodityID: [Int: Int]
    public private(set) var bestYearlyProfit: Int
    public private(set) var completedCycleCount: Int
    public private(set) var lastCompletedCycle: AnnualCityAccountingRecord?
    public private(set) var lastRecordedYear: Int?
    public private(set) var lastRecordedMonth: Int?
    private var observedLifetimeIncome: Int
    private var observedLifetimeExpenses: Int

    public init() {
        currentCycleStartYear = nil
        currentProductionUnitsByCommodityID = [:]
        currentIncome = 0
        currentExpenses = 0
        bestYearlyProductionUnitsByCommodityID = [:]
        bestYearlyProfit = 0
        completedCycleCount = 0
        lastCompletedCycle = nil
        lastRecordedYear = nil
        lastRecordedMonth = nil
        observedLifetimeIncome = 0
        observedLifetimeExpenses = 0
    }

    /// Records exactly one city month. Returns the annual record only when the
    /// month closes an accounting cycle (January). Duplicate/out-of-order calls
    /// are ignored so UI refreshes cannot alter a replay.
    @discardableResult
    public mutating func recordMonth(
        year: Int,
        month: Int,
        producedUnitsByCommodityID: [Int: Int],
        lifetimeIncome: Int,
        lifetimeExpenses: Int
    ) -> AnnualCityAccountingRecord? {
        guard (1...12).contains(month) else { return nil }
        let sequence = year * 12 + month
        if let lastRecordedYear, let lastRecordedMonth,
           sequence <= lastRecordedYear * 12 + lastRecordedMonth {
            return nil
        }

        if currentCycleStartYear == nil {
            currentCycleStartYear = month == 1 ? year - 1 : year
        }
        for (commodityID, amount) in producedUnitsByCommodityID where amount > 0 {
            currentProductionUnitsByCommodityID[commodityID, default: 0] += amount
        }
        currentIncome += max(0, lifetimeIncome - observedLifetimeIncome)
        currentExpenses += max(0, lifetimeExpenses - observedLifetimeExpenses)
        observedLifetimeIncome = max(observedLifetimeIncome, lifetimeIncome)
        observedLifetimeExpenses = max(observedLifetimeExpenses, lifetimeExpenses)
        lastRecordedYear = year
        lastRecordedMonth = month

        guard month == 1 else { return nil }
        let record = AnnualCityAccountingRecord(
            startYear: currentCycleStartYear ?? year - 1,
            endYear: year,
            productionUnitsByCommodityID: currentProductionUnitsByCommodityID,
            income: currentIncome,
            expenses: currentExpenses
        )
        for (commodityID, amount) in record.productionUnitsByCommodityID {
            bestYearlyProductionUnitsByCommodityID[commodityID] = max(
                bestYearlyProductionUnitsByCommodityID[commodityID, default: 0],
                amount
            )
        }
        bestYearlyProfit = max(bestYearlyProfit, record.profit)
        completedCycleCount += 1
        lastCompletedCycle = record
        currentCycleStartYear = year
        currentProductionUnitsByCommodityID = [:]
        currentIncome = 0
        currentExpenses = 0
        return record
    }
}
