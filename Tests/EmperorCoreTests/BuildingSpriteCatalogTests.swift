import XCTest
@testable import EmperorCore

final class BuildingSpriteCatalogTests: XCTestCase {
    func testEveryAgriculturalCropHasItsOwnPlotFootprintAndSprite() {
        let imageIDs = Set(AgriculturalCrop.allCases.map {
            OriginalBuildingSpriteCatalog.agriculturalPlotImageID(for: $0)
        })
        XCTAssertEqual(imageIDs.count, AgriculturalCrop.allCases.count)
        for crop in AgriculturalCrop.allCases {
            XCTAssertEqual(
                OriginalBuildingFootprintCatalog.footprint(
                    forBuildingID: crop.plotBuildingID
                ),
                BuildingFootprint(width: 1, height: 1)
            )
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingSprite(
                    forBuildingID: crop.plotBuildingID
                ),
                OriginalBuildingSpriteCatalog.agriculturalPlotSprite(for: crop)
            )
        }
    }

    func testXiaTutorialOneHasOriginalBuildingComponents() {
        let requiredBuildingIDs = [33, 53, 59, 72, 124, 126, 214]
        for buildingID in requiredBuildingIDs {
            let components = OriginalBuildingSpriteCatalog.buildingComponents(forBuildingID: buildingID)
            XCTAssertFalse(components.isEmpty, "missing original components for building #\(buildingID)")
        }
        for levelID in 0...14 {
            XCTAssertNotNil(OriginalBuildingSpriteCatalog.housingSprite(forHouseLevelID: levelID))
        }
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 33)?.imageID, 825)
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 124)?.imageID, 1_704)
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 126)?.imageID, 2_046)
    }

    func testEverySupportedPlacedBuildingHasOriginalComponents() {
        for buildingID in OriginalBuildingSpriteCatalog.supportedPlacedBuildingIDs {
            XCTAssertFalse(
                OriginalBuildingSpriteCatalog.buildingComponents(
                    forBuildingID: buildingID
                ).isEmpty,
                "missing original components for supported building #\(buildingID)"
            )
        }
    }

    func testPreviouslyPlaceholderBuildingsUseVerifiedOriginalImages() {
        let expectedImageIDs = [
            31: 721,
            36: 2_741,
            38: 2_726,
            39: 2_697,
            40: 2_698,
            42: 2_750,
            46: 2_832,
            237: 812,
            238: 840,
            239: 777,
        ]
        for (buildingID, imageID) in expectedImageIDs {
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingSprite(
                    forBuildingID: buildingID
                )?.imageID,
                imageID
            )
        }
    }

    func testAestheticAndWatchtowerBuildingsUseVerifiedOriginalImages() {
        let expectedImageIDs = [
            115: 201,
            116: 209,
            117: 225,
            118: 241,
            119: 250,
            127: 1_618,
        ]
        for (buildingID, imageID) in expectedImageIDs {
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingSprite(
                    forBuildingID: buildingID
                )?.imageID,
                imageID
            )
            XCTAssertFalse(
                OriginalBuildingSpriteCatalog.buildingComponents(
                    forBuildingID: buildingID
                ).isEmpty
            )
        }
    }

    func testQinSupportAndMonumentBuildingsUseVerifiedOriginalImages() {
        let expected: [Int: BuildingSpriteReference] = [
            52: .init(archiveBaseName: "China_General", imageID: 2_310),
            82: .init(archiveBaseName: "China_Mon_Grand_Canal", imageID: 272),
            84: .init(archiveBaseName: "China_Mon_Tumulus", imageID: 376),
            226: .init(archiveBaseName: "China_General", imageID: 918),
        ]
        for (buildingID, reference) in expected {
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingSprite(
                    forBuildingID: buildingID
                ),
                reference
            )
            XCTAssertFalse(
                OriginalBuildingSpriteCatalog.buildingComponents(
                    forBuildingID: buildingID
                ).isEmpty
            )
        }
    }

    func testLocalXiaTutorialOneBuildingSpritesDecode() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_General.sg3")
        )
        let pixels = try Data(
            contentsOf: source.dataDirectory.appendingPathComponent("China_General.555"),
            options: [.mappedIfSafe]
        )
        var references = Set<BuildingSpriteReference>()
        for buildingID in [33, 53, 59, 72, 124, 126, 214] {
            references.formUnion(
                OriginalBuildingSpriteCatalog.buildingComponents(forBuildingID: buildingID).map(\.sprite)
            )
        }
        for levelID in 0...14 {
            references.insert(try XCTUnwrap(
                OriginalBuildingSpriteCatalog.housingSprite(forHouseLevelID: levelID)
            ))
        }
        for reference in references {
            let decoded = try SpriteDecoder.decode(
                image: archive.images[reference.imageID],
                pixelData: pixels
            )
            XCTAssertGreaterThan(decoded.width, 0, "#\(reference.imageID)")
            XCTAssertGreaterThan(decoded.height, 0, "#\(reference.imageID)")
        }
    }

    func testLocalSupportedBuildingAndFireSpritesDecode() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("China_General.sg3")
        )
        let pixels = try Data(
            contentsOf: source.dataDirectory.appendingPathComponent("China_General.555"),
            options: [.mappedIfSafe]
        )
        for imageID in OriginalBuildingSpriteCatalog.requiredImageIDs {
            XCTAssertTrue(archive.images.indices.contains(imageID), "#\(imageID)")
            let decoded = try SpriteDecoder.decode(
                image: archive.images[imageID],
                pixelData: pixels
            )
            XCTAssertGreaterThan(decoded.width, 0, "#\(imageID)")
            XCTAssertGreaterThan(decoded.height, 0, "#\(imageID)")
        }
    }

    func testLocalMultiArchiveBuildingSpritesDecode() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        for (baseName, imageIDs) in OriginalBuildingSpriteCatalog.requiredImageIDsByArchive {
            let archive = try SG3Archive(
                contentsOf: source.dataDirectory.appendingPathComponent("\(baseName).sg3")
            )
            let pixels = try Data(
                contentsOf: source.dataDirectory.appendingPathComponent("\(baseName).555"),
                options: [.mappedIfSafe]
            )
            for imageID in imageIDs {
                XCTAssertTrue(archive.images.indices.contains(imageID), "\(baseName) #\(imageID)")
                let decoded = try SpriteDecoder.decode(
                    image: archive.images[imageID],
                    pixelData: pixels
                )
                XCTAssertGreaterThan(decoded.width, 0, "\(baseName) #\(imageID)")
                XCTAssertGreaterThan(decoded.height, 0, "\(baseName) #\(imageID)")
            }
        }
    }
}
