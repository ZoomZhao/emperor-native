import EmperorCore
import XCTest
@testable import EmperorGameplay

final class QinCampaignBaselineTests: XCTestCase {
    func testQinMissionOneStartsFromOriginalWorldData() throws {
        let controller = try startedQinMissionOne()
        let city = try XCTUnwrap(controller.city)
        XCTAssertEqual(city.calendar.year, -260)
        XCTAssertEqual(city.calendar.month, 6)
        XCTAssertEqual(city.economy.treasury, 15_000)
        XCTAssertEqual(
            controller.activeWorld?.mapAssignment.embeddedMap.mapURL.lastPathComponent,
            "Haunxian.map"
        )

        let goalSet = try qinMissionOneGoals(controller: controller)
        XCTAssertEqual(goalSet.goals.count, 2)
        XCTAssertTrue(goalSet.goals.contains {
            if case .monument(buildingID: 83) = $0.requirement { return true }
            return false
        })
        XCTAssertTrue(goalSet.goals.contains {
            if case .yearlyProduction(commodityID: 15, internalUnits: 1_800)
                = $0.requirement { return true }
            return false
        })

        let placement = try XCTUnwrap(city.terrain?.grandCanalPlacement)
        XCTAssertEqual(placement.origin, GridPoint(x: 4, y: 68))
        XCTAssertEqual(placement.quarterTurnsClockwise, 0)
        XCTAssertEqual(
            Set(
                OriginalGrandCanalLayoutCatalog
                    .placedSubBuildings(for: placement)
                    .flatMap(\.footprintCells)
            ).count,
            528
        )

        XCTAssertFalse(
            controller.perform(.beginMapMonument(buildingID: 83)).wasApplied
        )
        XCTAssertFalse(
            controller.perform(.selectConstruction(.grandCanalSegment)).wasApplied
        )
        XCTAssertNil(OriginalMonumentConfiguration.configuration(buildingID: 83))
    }

    func testQinMissionOnePreservesArchivedGrandCanalCompletion() throws {
        let controller = try startedQinMissionOne()
        var city = try XCTUnwrap(controller.city)
        XCTAssertTrue(city.aesthetics.completedMonumentBuildingIDs.contains(83))
        XCTAssertNil(city.aesthetics.grandCanalProject)
        XCTAssertNil(city.advanceGrandCanalSegment(at: GridPoint(x: 4, y: 68)))

        var snapshot = city.campaignGoalProgressSnapshot()
        snapshot.bestYearlyProductionUnitsByCommodityID[15] = 1_800
        XCTAssertTrue(
            CampaignGoalEvaluator.missionIsComplete(
                try qinMissionOneGoals(controller: controller),
                against: snapshot
            )
        )
    }

    func testQinMissionOneDoesNotPromoteGenericMapRowsIntoLiveObjects() throws {
        let controller = try startedQinMissionOne()
        let city = try XCTUnwrap(controller.city)
        let mapURL = try XCTUnwrap(
            controller.activeWorld?.mapAssignment.embeddedMap.mapURL
        )
        let map = try EmperorMap(url: mapURL)

        // The canonical Haunxian archive contains a large generic Building
        // stream, but every scanned row has base model 0 and is outside the
        // recovered FUN_0052F030 whitelist. Keep the Native startup boundary
        // explicit: archive evidence is retained by EmperorMap, while no
        // house, service provider, or placed-building state is synthesized.
        XCTAssertFalse(map.genericBuildingArchiveRecords.isEmpty)
        XCTAssertTrue(
            map.genericBuildingArchiveRecords.allSatisfy {
                $0.baseTypeWord == 0
                    && !OriginalMapLoaderRehydrationCatalog.rehydrates(
                        genericRecord: $0
                    )
            }
        )
        XCTAssertTrue(city.houses.isEmpty)
        XCTAssertTrue(city.placedBuildings.isEmpty)
        XCTAssertTrue(city.residentialServiceBuildings.isEmpty)
    }

    func testEarthenGreatWallDoesNotUseTheLegacyGuessedProgressConfiguration() {
        XCTAssertNil(OriginalMonumentConfiguration.configuration(buildingID: 85))
    }

    func testQinMissionOneCanPlaceVerifiedIrrigationPumpOnAuthoredBank() throws {
        let controller = try startedQinMissionOne()
        let city = try XCTUnwrap(controller.city)
        let point = try XCTUnwrap(
            city.nextBuildingConstructionLocation(buildingID: 203),
            "Haunxian needs a clear riverbank tile beside the authored road"
        )
        XCTAssertTrue(controller.perform(.selectConstruction(.irrigationPump)).wasApplied)
        let preview = controller.constructionPreview(at: point)
        XCTAssertTrue(preview.isValid, preview.reason ?? "invalid irrigation pump")
        let result = controller.perform(
            .placeSelectedConstruction(at: point, orientation: .northSouth)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        let placement = try XCTUnwrap(
            controller.city?.placedBuildings.first(where: { $0.buildingID == 203 })
        )
        XCTAssertNotNil(controller.city?.quayWaterEdge(for: placement))
    }

    private func startedQinMissionOne() throws -> GameSessionController {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let controller = try GameSessionController()
        let campaignID = try XCTUnwrap(
            controller.campaignID(fileName: "4 Qin Dynasty.pak")
        )
        let result = controller.perform(
            .startCampaignMission(campaignID: campaignID, missionID: 0)
        )
        XCTAssertTrue(result.wasApplied, result.message)
        return controller
    }

    private func qinMissionOneGoals(
        controller: GameSessionController
    ) throws -> CampaignMissionGoalSet {
        let campaignID = try XCTUnwrap(controller.selectedCampaignID)
        let campaign = controller.campaigns[campaignID]
        let archive = try CampaignGoalArchive(
            campaignURL: campaign.url,
            missionCount: campaign.missions.count
        )
        return archive.missions[0]
    }
}
