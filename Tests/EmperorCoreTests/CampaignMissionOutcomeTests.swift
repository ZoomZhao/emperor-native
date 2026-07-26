import XCTest
@testable import EmperorCore

final class CampaignMissionOutcomeTests: XCTestCase {
    func testOperatingExpenseCanCreateDebtButOrdinaryDebitCannot() {
        var economy = DeterministicEconomyState(treasury: 5)
        XCTAssertFalse(economy.debit(6))
        XCTAssertEqual(economy.treasury, 5)
        economy.chargeOperatingExpense(6)
        XCTAssertEqual(economy.treasury, -1)
        XCTAssertEqual(economy.lifetimeExpenses, 6)
    }

    func testPayrollUsesActualWorkforceAndCarriesIntegerRemainder() throws {
        let models = try originalModels()
        let rules = EconomyRulesEngine(models: models)
        var city = DeterministicCityState(
            year: 1600, treasury: 20_000, mapWidth: 20, mapHeight: 10
        )
        city.workforceEnabled = true
        _ = city.buildRoad((0..<20).map { GridPoint(x: $0, y: 6) }, rules: rules)
        XCTAssertNotNil(city.constructHouse(
            footprintMultiplier: 4,
            location: GridPoint(x: 1, y: 7),
            rules: rules
        ))
        XCTAssertEqual(city.admitResidents(15, models: models.buildings), 15)
        XCTAssertNotNil(city.constructProductionBuilding(
            buildingID: 33,
            at: GridPoint(x: 2, y: 4),
            rules: rules
        ))
        XCTAssertEqual(city.workforceSnapshot(models: models.buildings).assignedWorkers, 15)

        var runtime = emptyRuntime()
        let treasuryBeforePayroll = city.economy.treasury
        for offset in 0..<12 {
            _ = runtime.advance(
                settlementYear: 1600 + offset / 12,
                month: offset % 12 + 1,
                city: &city,
                rules: rules,
                goalSet: nil
            )
        }
        XCTAssertEqual(treasuryBeforePayroll - city.economy.treasury, 45)
        XCTAssertEqual(runtime.payrollRemainder, 0)
    }

    func testContinuousDebtFailsAtThirtySixAndTerminalAdvanceIsIdempotent() throws {
        let rules = EconomyRulesEngine(models: try originalModels())
        var city = DeterministicCityState(year: 1600, treasury: 1)
        city.chargeOperatingExpense(2)
        var runtime = emptyRuntime()

        for index in 0..<35 {
            let result = runtime.advance(
                settlementYear: 1600 + index / 12,
                month: index % 12 + 1,
                city: &city,
                rules: rules,
                goalSet: nil
            )
            XCTAssertNil(result.outcomeChangedNow)
        }
        XCTAssertEqual(runtime.consecutiveDebtMonths, 35)
        XCTAssertEqual(runtime.outcome, .running)

        let boundary = runtime.advance(
            settlementYear: 1602,
            month: 12,
            city: &city,
            rules: rules,
            goalSet: nil
        )
        guard case let .defeat(record)? = boundary.outcomeChangedNow else {
            return XCTFail("expected debt defeat")
        }
        XCTAssertEqual(record.treasury, -1)
        XCTAssertEqual(record.reason, .continuousDebt(months: 36))

        let frozenRuntime = runtime
        let frozenCity = city
        for _ in 0..<100 {
            XCTAssertEqual(runtime.advance(
                settlementYear: 1700,
                month: 1,
                city: &city,
                rules: rules,
                goalSet: nil
            ), .noChange)
        }
        XCTAssertEqual(runtime, frozenRuntime)
        XCTAssertEqual(city, frozenCity)
    }

    func testNonNegativeMonthResetsDebtAndSameMonthConflictPrefersDefeat() throws {
        let models = try originalModels()
        let rules = EconomyRulesEngine(models: models)
        var city = DeterministicCityState(year: 1600, treasury: 1)
        city.chargeOperatingExpense(2)
        var runtime = emptyRuntime()
        for index in 0..<20 {
            _ = runtime.advance(
                settlementYear: 1600 + index / 12,
                month: index % 12 + 1,
                city: &city,
                rules: rules,
                goalSet: nil
            )
        }
        _ = city.receiveCampaignCash(1)
        _ = runtime.advance(
            settlementYear: 1601, month: 9, city: &city, rules: rules, goalSet: nil
        )
        XCTAssertEqual(runtime.consecutiveDebtMonths, 0)

        city.chargeOperatingExpense(1)
        for index in 0..<35 {
            _ = runtime.advance(
                settlementYear: 1601 + (index + 9) / 12,
                month: (index + 9) % 12 + 1,
                city: &city,
                rules: rules,
                goalSet: nil
            )
        }
        XCTAssertNotNil(city.addHouse(
            levelID: 0,
            residents: 1,
            models: models.buildings
        ))
        let populationGoal = CampaignMissionGoalSet(id: 0, goals: [
            CampaignMissionGoal(id: 0, kind: .population, values: [1])
        ])
        let result = runtime.advance(
            settlementYear: 1605,
            month: 9,
            city: &city,
            rules: rules,
            goalSet: populationGoal
        )
        guard case .defeat? = result.outcomeChangedNow else {
            return XCTFail("debt must win the same-month conflict")
        }
        XCTAssertFalse(runtime.missionCompleted)
    }

    func testVictoryAndAllOutcomeStatesRoundTrip() throws {
        let rules = EconomyRulesEngine(models: try originalModels())
        var city = DeterministicCityState(year: 1600, treasury: 100)
        var victory = emptyRuntime()
        let goal = CampaignMissionGoalSet(id: 0, goals: [
            CampaignMissionGoal(id: 0, kind: .treasury, values: [100])
        ])
        let result = victory.advance(
            settlementYear: 1600, month: 1, city: &city, rules: rules, goalSet: goal
        )
        XCTAssertTrue(result.missionCompletedNow)
        XCTAssertTrue(victory.missionCompleted)

        for runtime in [emptyRuntime(), victory] {
            XCTAssertEqual(
                try JSONDecoder().decode(
                    CampaignMissionRuntimeState.self,
                    from: JSONEncoder().encode(runtime)
                ),
                runtime
            )
        }
    }

    private func emptyRuntime() -> CampaignMissionRuntimeState {
        CampaignMissionRuntimeState(
            missionID: 0,
            startYear: 1600,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: 0, events: []),
            replaySeed: 0x4F55_5443_4F4D_45
        )
    }

    private func originalModels() throws -> OriginalEconomyModels {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        return try OriginalEconomyModels(source: .openDefault())
    }
}
