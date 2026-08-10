import XCTest
@testable import EmperorCore

final class MillStorageSettingsTests: XCTestCase {
    func testMillOrdersAndStorageLimitsUseOriginalFourLoadGranularity() throws {
        let roads = RoadNetwork(width: 8, height: 8, points: [GridPoint(x: 2, y: 2)])
        var logistics = DeterministicLogisticsState()
        let millID = try XCTUnwrap(logistics.addMill(
            roadAccessPoint: GridPoint(x: 2, y: 2),
            roadNetwork: roads
        ))

        logistics.setMillStorageLimit(
            1_299,
            commodityID: 1,
            millID: millID
        )
        let mill = try XCTUnwrap(logistics.mills.first)
        XCTAssertEqual(mill.storageLimit(for: 1), 1_200)

        logistics.setMillPolicy(.empty, commodityID: 1, millID: millID)
        XCTAssertEqual(logistics.mills.first?.policy(for: 1), .empty)
        XCTAssertEqual(logistics.mills.first?.availableCapacity(for: 1), 0)
    }
}
