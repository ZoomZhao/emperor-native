import Foundation

public struct EconomyRulesEngine: Sendable {
    public let models: OriginalEconomyModels

    public init(models: OriginalEconomyModels) {
        self.models = models
    }

    public func constructionCost(buildingID: Int, difficulty: GameDifficulty) -> Int? {
        guard let building = models.buildings[buildingID: buildingID],
              let modifier = models.buildings.difficultyModifiers.first(where: { $0.id == difficulty.rawValue }),
              let percentage = modifier.values.first else { return nil }
        return building.cost * percentage / 100
    }

    public func commodityPrice(named name: String) -> Int? {
        models.trade.prices.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value
    }

    public func taxSentiment(
        bandID: Int,
        difficulty: GameDifficulty,
        hasMeaningfulCoverage: Bool = true
    ) -> Int? {
        let effectiveBand = hasMeaningfulCoverage ? bandID : 0
        guard let band = models.taxSentiment.bands.first(where: { $0.id == effectiveBand }) else { return nil }
        return band.sentiment(at: difficulty)
    }

    public func taxRatePercent(bandID: Int) -> Int? {
        models.taxSentiment.bands.first(where: { $0.id == bandID })?.taxRatePercent
    }
}

public struct DeterministicEconomyState: Sendable, Equatable, Codable {
    public private(set) var treasury: Int
    public private(set) var inventory: [String: Int]
    public private(set) var transactionSequence: UInt64
    // Optional backing preserves native format-v1 saves. Old saves begin their
    // annual accounting counters at zero when first advanced by the new engine.
    private var lifetimeIncomeStorage: Int?
    private var lifetimeExpensesStorage: Int?

    public init(treasury: Int, inventory: [String: Int] = [:]) {
        self.treasury = treasury
        self.inventory = inventory
        transactionSequence = 0
        lifetimeIncomeStorage = 0
        lifetimeExpensesStorage = 0
    }

    public var lifetimeIncome: Int { lifetimeIncomeStorage ?? 0 }
    public var lifetimeExpenses: Int { lifetimeExpensesStorage ?? 0 }

    @discardableResult
    public mutating func spendOnConstruction(
        buildingID: Int,
        quantity: Int = 1,
        rules: EconomyRulesEngine,
        difficulty: GameDifficulty
    ) -> Bool {
        guard let cost = rules.constructionCost(buildingID: buildingID, difficulty: difficulty),
              cost >= 0, quantity > 0 else { return false }
        let total = cost.multipliedReportingOverflow(by: quantity)
        guard !total.overflow, treasury >= total.partialValue else { return false }
        treasury -= total.partialValue
        lifetimeExpensesStorage = lifetimeExpenses + total.partialValue
        transactionSequence &+= 1
        return true
    }

    public mutating func add(resource: String, amount: Int) {
        guard amount != 0 else { return }
        inventory[resource, default: 0] += amount
        transactionSequence &+= 1
    }

    public mutating func credit(_ amount: Int) {
        guard amount > 0 else { return }
        treasury += amount
        lifetimeIncomeStorage = lifetimeIncome + amount
        transactionSequence &+= 1
    }

    @discardableResult
    public mutating func debit(_ amount: Int) -> Bool {
        guard amount > 0, treasury >= amount else { return false }
        treasury -= amount
        lifetimeExpensesStorage = lifetimeExpenses + amount
        transactionSequence &+= 1
        return true
    }

    /// Charges a simulation-owned recurring expense. Unlike player spending,
    /// payroll is allowed to take the treasury below zero so the original
    /// continuous-debt defeat rule can be represented honestly.
    public mutating func chargeOperatingExpense(_ amount: Int) {
        guard amount > 0 else { return }
        treasury -= amount
        lifetimeExpensesStorage = lifetimeExpenses + amount
        transactionSequence &+= 1
    }
}
