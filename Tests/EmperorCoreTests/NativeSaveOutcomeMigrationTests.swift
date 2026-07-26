import XCTest
@testable import EmperorCore

final class NativeSaveOutcomeMigrationTests: XCTestCase {
    func testLegacyCompletedRuntimeMigratesToVictory() throws {
        let runtime = CampaignMissionRuntimeState(
            missionID: 3,
            startYear: 100,
            startMonth: 2,
            eventSet: CampaignMissionEventSet(id: 3, events: []),
            replaySeed: 9
        )
        let encoded = try JSONEncoder().encode(runtime)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "outcome")
        object.removeValue(forKey: "consecutiveDebtMonths")
        object.removeValue(forKey: "payrollRemainder")
        object["missionCompleted"] = true
        object["completedAtRelativeYear"] = 2
        object["completedAtMonth"] = 7

        let migrated = try JSONDecoder().decode(
            CampaignMissionRuntimeState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(
            migrated.outcome,
            .victory(CampaignVictoryRecord(settlementYear: 102, month: 7))
        )
        XCTAssertEqual(migrated.consecutiveDebtMonths, 0)
        XCTAssertEqual(migrated.payrollRemainder, 0)
    }

    func testLegacyIncompleteRuntimeMigratesToRunning() throws {
        let runtime = CampaignMissionRuntimeState(
            missionID: 0,
            startYear: 1,
            startMonth: 1,
            eventSet: CampaignMissionEventSet(id: 0, events: []),
            replaySeed: 1
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(runtime)) as? [String: Any]
        )
        object.removeValue(forKey: "outcome")
        let migrated = try JSONDecoder().decode(
            CampaignMissionRuntimeState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(migrated.outcome, .running)
    }
}
