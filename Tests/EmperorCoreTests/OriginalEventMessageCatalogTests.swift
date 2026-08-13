import XCTest
@testable import EmperorCore

final class OriginalEventMessageCatalogTests: XCTestCase {
    func testOriginalChineseFireAndCollapsePhrasesAreExact() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let catalog = try OriginalEventMessageCatalog(
            contentsOf: source.modelDirectory.appendingPathComponent("EmperorEventmsg.txt")
        )

        XCTAssertEqual(catalog.phrase("PHRASE_fire_title"), "城中发生火灾!")
        XCTAssertEqual(
            catalog.phrase("PHRASE_fire_initial_announcement"),
            "坏运气降临到我们头上了, [player_name]! 城中发生了火灾! 希望我们的巡视员 能够在火势蔓延开以前扑灭大火."
        )
        XCTAssertEqual(catalog.phrase("PHRASE_collapsed_building_title"), "建筑物倒塌!")
        XCTAssertEqual(
            catalog.phrase("PHRASE_collapsed_building_initial_announcement"),
            "尊贵的 [player_name], 一栋建筑物倒塌, 变成了废墟. 您应该在那个地区 建造更多的巡视员塔楼, 避免将来再次发生不幸."
        )
        XCTAssertNil(catalog.phrase("PHRASE_not_authored"))
    }

    func testFailurePresentationSubstitutesOnlyKnownPlayerName() throws {
        let catalog = OriginalEventMessageCatalog(text: """
        PHRASE_fire_title "城中发生火灾!"
        PHRASE_fire_initial_announcement "坏运气降临到我们头上了, [player_name]!"
        """)

        XCTAssertEqual(
            catalog.buildingFailureMessage(for: .fire, playerName: "嬴政")?.body,
            "坏运气降临到我们头上了, 嬴政!"
        )
        XCTAssertEqual(
            catalog.buildingFailureMessage(for: .fire, playerName: nil)?.body,
            "坏运气降临到我们头上了, [player_name]!"
        )
        XCTAssertNil(catalog.buildingFailureMessage(for: .collapse, playerName: "嬴政"))
    }
}
