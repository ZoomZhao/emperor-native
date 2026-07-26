import EmperorCore
import XCTest

final class ElevationObjectSpriteTests: XCTestCase {
    func testPackedCliffObjectIDsResolveLikeTheOriginalLoader() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("GameData is not available")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_Elevation.sg3")
        )
        let elevationCount = archive.images.count
        let expectedCounts = [
            "Banpo.map": 492,
            "Zhengzhou.map": 189,
            "Liangzhou.map": 248,
        ]

        for (mapName, expectedCount) in expectedCounts {
            let mapURL = source.citiesDirectory.appendingPathComponent(mapName)
            guard FileManager.default.fileExists(atPath: mapURL.path) else {
                throw XCTSkip("\(mapName) is not available")
            }
            let map = try EmperorMap(url: mapURL)
            var objectMapped = 0
            var mappedLocals = Set<Int>()
            for y in 0..<map.height {
                for x in 0..<map.width {
                    guard let globalID = map.imageID(x: x, y: y),
                          globalID >> 14
                            == EmperorMap.chinaElevationObjectImageFlag >> 14 else {
                        continue
                    }
                    XCTAssertTrue(
                        map.terrain(at: GridPoint(x: x, y: y))?.contains(.elevation) == true
                    )
                    let localID = try XCTUnwrap(
                        map.chinaElevationObjectSpriteID(
                            x: x,
                            y: y,
                            imageCount: elevationCount
                        )
                    )
                    XCTAssertEqual(
                        localID,
                        Int(globalID & 0x3FFF) + EmperorMap.chinaElevationObjectLocalBias
                    )
                    XCTAssertEqual(
                        map.chinaElevationSpriteID(
                            x: x,
                            y: y,
                            imageCount: elevationCount
                        ),
                        EmperorMap.chinaElevationDisplaySpriteID(
                            localID,
                            neighborMask: map.chinaElevationNeighborMask(x: x, y: y)
                        )
                    )
                    objectMapped += 1
                    mappedLocals.insert(localID)
                }
            }

            XCTAssertEqual(objectMapped, expectedCount, mapName)
            if mapName == "Banpo.map" {
                XCTAssertTrue(mappedLocals.contains(207))
                XCTAssertTrue(mappedLocals.contains(228))
                XCTAssertTrue(mappedLocals.contains(231))
            } else if mapName == "Liangzhou.map" {
                XCTAssertTrue(mappedLocals.contains(201))
            }
        }
    }

    func testElevationObjectBiasMatchesStrippedZeusSystemPrefix() {
        XCTAssertEqual(EmperorMap.chinaElevationObjectLocalBias, 200)
        XCTAssertEqual(1 + EmperorMap.chinaElevationObjectLocalBias, 201)
        XCTAssertEqual(7 + EmperorMap.chinaElevationObjectLocalBias, 207)
        XCTAssertEqual(28 + EmperorMap.chinaElevationObjectLocalBias, 228)
        XCTAssertEqual(31 + EmperorMap.chinaElevationObjectLocalBias, 231)
    }

    func testCompositionTemplatesUseNeighborMatchedDisplayArtwork() {
        XCTAssertEqual(EmperorMap.chinaElevationDisplaySpriteID(330), 330)
        XCTAssertEqual(
            EmperorMap.chinaElevationDisplaySpriteID(334, neighborMask: 0x6),
            335
        )
        XCTAssertEqual(
            EmperorMap.chinaElevationDisplaySpriteID(334, neighborMask: 0x5),
            338
        )
        XCTAssertEqual(
            EmperorMap.chinaElevationDisplaySpriteID(348, neighborMask: 0x6),
            350
        )
        XCTAssertEqual(
            EmperorMap.chinaElevationDisplaySpriteID(348, neighborMask: 0x5),
            354
        )
        XCTAssertEqual(EmperorMap.chinaElevationDisplaySpriteID(349), 349)
    }
}
