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
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 33)?.imageID, 708)
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 124)?.imageID, 1_618)
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 126)?.imageID, 2_046)
    }

    func testConstructionCatalogUsesRecognizableMarketAndHunterSprites() {
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.constructionCatalogSprite(forBuildingID: 59),
            BuildingSpriteReference(
                archiveBaseName: OriginalBuildingSpriteCatalog.generalArchiveBaseName,
                imageID: OriginalBuildingSpriteCatalog.foodShopImageID
            )
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.constructionCatalogSprite(forBuildingID: 33)?.imageID,
            708
        )
    }

    func testMarketShellUsesActualInstalledShopSprites() {
        let empty = OriginalBuildingSpriteCatalog.buildingComponents(
            forBuildingID: OriginalMarketCatalog.commonMarketBuildingID,
            marketShopBuildingIDs: []
        )
        XCTAssertFalse(empty.contains {
            $0.sprite.imageID == OriginalBuildingSpriteCatalog.foodShopImageID
        })
        XCTAssertEqual(
            empty.filter {
                $0.sprite.imageID == OriginalBuildingSpriteCatalog.marketEntertainmentAreaImageID
            }.count,
            1
        )

        let installed = OriginalBuildingSpriteCatalog.buildingComponents(
            forBuildingID: OriginalMarketCatalog.commonMarketBuildingID,
            marketShopBuildingIDs: [67, 66]
        )
        XCTAssertEqual(
            Set(installed.map(\.sprite.imageID)).intersection([619, 611]),
            Set([619, 611])
        )
        XCTAssertFalse(installed.contains { $0.sprite.imageID == 617 })
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
            42: 2_788,
            43: 2_810,
            46: 2_832,
            237: 840,
            238: 812,
        ]
        for (buildingID, imageID) in expectedImageIDs {
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingSprite(
                    forBuildingID: buildingID
                )?.imageID,
                imageID
            )
        }
        XCTAssertNil(
            OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 239),
            "#777 is an irrigation-pump frame, not a silkworm-shed sprite"
        )
    }

    /// Primary-sprite keys recovered from the executable building table
    /// (DAT_008235a0, docs/exe-research/building-sprite-key-table.md). The
    /// wheat/millet and cabbage/soybean field families were swapped before.
    func testFieldCropsAndFarmsteadsUseExecutableRecoveredSprites() {
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.agriculturalPlotImageID(for: .wheat),
            2_422
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.agriculturalPlotImageID(for: .millet),
            2_410
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.agriculturalPlotImageID(for: .cabbage),
            2_434
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.agriculturalPlotImageID(for: .soybeans),
            2_446
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.agriculturalPlotImageID(for: .hemp),
            2_458
        )
        XCTAssertEqual(
            OriginalBuildingSpriteCatalog.agriculturalPlotImageID(for: .rice),
            2_506
        )
        // Farmstead producers now have sprites and footprints.
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 192)?.imageID, 825)
        XCTAssertEqual(OriginalBuildingSpriteCatalog.buildingSprite(forBuildingID: 193)?.imageID, 793)
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: 192),
            BuildingFootprint(width: 2, height: 2)
        )
        XCTAssertEqual(
            OriginalBuildingFootprintCatalog.footprint(forBuildingID: 193),
            BuildingFootprint(width: 3, height: 3)
        )
    }

    func testAestheticAndWatchtowerBuildingsUseVerifiedOriginalImages() {
        let expectedImageIDs = [
            115: 201,
            116: 209,
            117: 225,
            118: 241,
            119: 250,
            127: 1_680,
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
            233: .init(archiveBaseName: "China_General", imageID: 2_373),
            235: .init(archiveBaseName: "China_General", imageID: 2_331),
            236: .init(archiveBaseName: "China_General", imageID: 2_352),
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

    func testQinFortressesUseVerifiedMilitaryHeadquartersSprite() {
        for buildingID in [220, 221, 223, 224] {
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingSprite(
                    forBuildingID: buildingID
                )?.imageID,
                954
            )
            XCTAssertFalse(
                OriginalBuildingSpriteCatalog.buildingComponents(
                    forBuildingID: buildingID
                ).isEmpty
            )
        }
    }

    func testIrrigationPumpUsesAllFourVerifiedBankSprites() {
        let expected: [QuayWaterEdge: Int] = [
            .north: 761,
            .west: 777,
            .east: 745,
            .south: 729,
        ]
        for (edge, imageID) in expected {
            XCTAssertEqual(
                OriginalBuildingSpriteCatalog.buildingComponents(
                    forBuildingID: 203,
                    quayWaterEdge: edge
                ).first?.sprite.imageID,
                imageID
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
