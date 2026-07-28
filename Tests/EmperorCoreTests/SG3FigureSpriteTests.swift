import XCTest
@testable import EmperorCore

final class SG3FigureSpriteTests: XCTestCase {
    func testBitmapRecordParserReadsTheWholeTwoHundredByteRecord() throws {
        var data = Data(repeating: 0, count: SG3Archive.imageTableOffset + 64)
        func putUInt32(_ value: UInt32, at offset: Int) {
            for byte in 0..<4 {
                data[offset + byte] = UInt8(truncatingIfNeeded: value >> UInt32(byte * 8))
            }
        }
        func putUInt16(_ value: UInt16, at offset: Int) {
            data[offset] = UInt8(truncatingIfNeeded: value)
            data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        }
        func putASCII(_ value: String, at offset: Int) {
            for (index, byte) in value.utf8.enumerated() { data[offset + index] = byte }
        }

        putUInt32(213, at: 4)
        putUInt32(1, at: 12)
        putUInt32(0, at: 16) // serialized image count excludes sentinel image zero
        putUInt32(1, at: 20)
        let bitmapOffset = SG3Archive.headerByteCount + SG3Archive.groupCount * 2
        putASCII("Fixture.bmp", at: bitmapOffset)
        putASCII("semantic figure record", at: bitmapOffset + 65)
        putUInt32(77, at: bitmapOffset + 116)
        putUInt32(69, at: bitmapOffset + 120)
        putUInt32(1, at: bitmapOffset + 124)
        putUInt32(0, at: bitmapOffset + 128)
        putUInt32(0, at: bitmapOffset + 132)
        putUInt16(16, at: SG3Archive.imageTableOffset + 20)
        putUInt16(12, at: SG3Archive.imageTableOffset + 22)

        let archive = try SG3Archive(data: data)
        XCTAssertEqual(archive.bitmaps[0].name, "Fixture.bmp")
        XCTAssertEqual(archive.bitmaps[0].comment, "semantic figure record")
        XCTAssertEqual(archive.bitmaps[0].width, 77)
        XCTAssertEqual(archive.bitmaps[0].height, 69)
        XCTAssertTrue(archive.bitmaps[0].contains(imageID: 0))
        XCTAssertEqual(archive.images[0].width, 16)
        XCTAssertEqual(archive.images[0].height, 12)
    }

    func testTutorialFigureCatalogIsDeterministicAndEightDirectional() throws {
        XCTAssertEqual(Set(OriginalFigureSpriteCatalog.animations.map(\.role)), Set(TutorialFigureRole.allCases))
        XCTAssertEqual(
            Set(OriginalFigureSpriteCatalog.animations.map(\.figureID)),
            [11, 22, 23, 24, 27, 28, 30, 31, 32, 33, 34, 35, 39]
        )
        for animation in OriginalFigureSpriteCatalog.animations {
            XCTAssertEqual(animation.framesByDirection.count, 8, animation.role.rawValue)
            XCTAssertTrue(animation.framesByDirection.allSatisfy { !$0.isEmpty })
            let first = animation.reference(
                direction: .east,
                tickSequence: 42,
                stableFigureID: 7
            )
            let replay = animation.reference(
                direction: .east,
                tickSequence: 42,
                stableFigureID: 7
            )
            XCTAssertEqual(first, replay)
        }
    }

    func testGeneratedServiceWalkersUseOriginalEightDirectionGroups() throws {
        let expected: [Int: (logicalGroup: Int, firstImageID: Int)] = [
            27: (64, 4_425),
            30: (29, 1_813),
            31: (2, 109),
            32: (147, 8_541),
            33: (106, 7_205),
            34: (102, 7_076),
        ]
        for (figureID, group) in expected {
            let animation = try XCTUnwrap(
                OriginalFigureSpriteCatalog.animation(forFigureID: figureID)
            )
            XCTAssertEqual(animation.logicalGroupID, group.logicalGroup)
            XCTAssertEqual(animation.framesByDirection.first?.first, group.firstImageID)
            XCTAssertEqual(animation.framesByDirection.count, 8)
            XCTAssertTrue(animation.framesByDirection.allSatisfy { $0.count == 12 })
        }
    }

    func testMeatDeliveryUsesTheVerifiedMeatCartFamily() throws {
        let animation = try XCTUnwrap(
            OriginalFigureSpriteCatalog.deliveryAnimation(forCommodityID: 4)
        )
        XCTAssertEqual(animation.logicalGroupID, 130)
        XCTAssertEqual(animation.imageIDs, Set(7_908..<7_924))
        XCTAssertTrue(
            OriginalFigureSpriteCatalog.requiredImageIDsByArchive[
                OriginalFigureSpriteCatalog.mainArchiveBaseName,
                default: []
            ].isSuperset(of: animation.imageIDs)
        )

        let generic = try XCTUnwrap(
            OriginalFigureSpriteCatalog.deliveryAnimation(forCommodityID: 18)
        )
        XCTAssertEqual(generic.logicalGroupID, 127)
        XCTAssertEqual(generic.imageIDs, Set(7_860..<7_876))
    }

    func testLocalTutorialFigureSequencesMatchLogicalGroupsAndDecode() throws {
        guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
            throw XCTSkip("Original Emperor assets are not installed")
        }
        let source = try GameDataSource.openDefault()
        let archive = try SG3Archive(
            contentsOf: source.dataDirectory.appendingPathComponent("SprMain.sg3")
        )
        let pixels = try Data(
            contentsOf: source.dataDirectory.appendingPathComponent("SprMain.555"),
            options: [.mappedIfSafe]
        )
        let requiredDistinctNames: Set<String> = ["Peddler", "Immigrant", "Inspector", "WaterBearer"]
        XCTAssertTrue(requiredDistinctNames.isSubset(of: Set(archive.bitmapNames)))

        for animation in OriginalFigureSpriteCatalog.animations {
            let firstImageID = try XCTUnwrap(animation.framesByDirection.first?.first)
            XCTAssertEqual(Int(archive.groupImageIDs[animation.logicalGroupID]), firstImageID)
            XCTAssertEqual(archive.images[firstImageID].spriteCount, animation.framesByDirection[0].count)
            XCTAssertTrue(archive.bitmapNames.contains(animation.sourceBitmapName))
            for imageID in animation.imageIDs.sorted() {
                XCTAssertTrue(archive.images.indices.contains(imageID), "\(animation.role) #\(imageID)")
                let decoded = try SpriteDecoder.decode(image: archive.images[imageID], pixelData: pixels)
                XCTAssertGreaterThan(decoded.width, 0)
                XCTAssertGreaterThan(decoded.height, 0)
                XCTAssertNotNil(decoded.makeCGImage())
            }
        }
    }
}
