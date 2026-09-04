import Foundation

/// Scenario points authored with the original Campaign Creator. Coordinates
/// are relative to the playable map rectangle, matching native simulation.
public struct EmperorMapAuthoredPoints: Sendable, Hashable, Codable {
    public let landEntry: GridPoint?
    public let landExit: GridPoint?
    public let seaEntry: GridPoint?
    public let seaExit: GridPoint?
    public let landInvasion: [GridPoint]
    public let seaInvasion: [GridPoint]
    public let disasters: [GridPoint]
    public let fishing: [GridPoint]

    public init(
        landEntry: GridPoint? = nil,
        landExit: GridPoint? = nil,
        seaEntry: GridPoint? = nil,
        seaExit: GridPoint? = nil,
        landInvasion: [GridPoint] = [],
        seaInvasion: [GridPoint] = [],
        disasters: [GridPoint] = [],
        fishing: [GridPoint] = []
    ) {
        self.landEntry = landEntry
        self.landExit = landExit
        self.seaEntry = seaEntry
        self.seaExit = seaExit
        self.landInvasion = landInvasion
        self.seaInvasion = seaInvasion
        self.disasters = disasters
        self.fishing = fishing
    }
}

/// One row from the original runtime map-descriptor table at
/// `DAT_00856C64`. The executable stores `(width, height, base,
/// rowAdvance)` in 16-byte rows; the last two fields describe the canonical
/// 228-cell backing grid rather than a compact Native rectangle.
public struct OriginalMapRuntimeDescriptor: Sendable, Hashable, Codable {
    public let width: Int
    public let height: Int
    public let baseLinearOffset: Int
    public let rowAdvance: Int

    public init(
        width: Int,
        height: Int,
        baseLinearOffset: Int,
        rowAdvance: Int
    ) {
        self.width = width
        self.height = height
        self.baseLinearOffset = baseLinearOffset
        self.rowAdvance = rowAdvance
    }

    /// Effective row stride used by the original full-map loops.
    public var effectiveRowStride: Int { width + rowAdvance }
}

/// Source-backed rows recovered from the canonical EN/CH executables. The
/// selector table is keyed by the map width/height pair; Native must not
/// synthesize rows for dimensions outside this set.
public enum OriginalMapRuntimeDescriptorCatalog {
    public static let rows: [OriginalMapRuntimeDescriptor] = [
        .init(width: 56, height: 56, baseLinearOffset: 19_694, rowAdvance: 172),
        .init(width: 84, height: 84, baseLinearOffset: 16_488, rowAdvance: 144),
        .init(width: 112, height: 112, baseLinearOffset: 13_282, rowAdvance: 116),
        .init(width: 140, height: 140, baseLinearOffset: 10_076, rowAdvance: 88),
        .init(width: 170, height: 170, baseLinearOffset: 6_641, rowAdvance: 58),
        .init(width: 226, height: 226, baseLinearOffset: 229, rowAdvance: 2),
    ]

    public static func descriptor(width: Int, height: Int)
        -> OriginalMapRuntimeDescriptor? {
        rows.first { $0.width == width && $0.height == height }
    }
}

public struct EmperorMap: Sendable {
    public static let gridSide = 228
    public static let gridCellCount = gridSide * gridSide
    // Map grids begin immediately after the 1,535-byte scenario header.
    // The former 1,587 value shifted every UInt32 layer by 13 cells and every
    // byte layer by 52 cells, so terrain, roads and camera focus were all read
    // from the wrong physical map coordinates.
    public static let headerByteCount = 1_535
    public static let imageGridOffset = headerByteCount
    public static let edgeGridOffset = imageGridOffset + gridCellCount * 4
    public static let terrainGridOffset = edgeGridOffset + gridCellCount
    /// `DAT_00F37DA0` in the original runtime. This is a serialized
    /// UInt32-per-cell auxiliary grid immediately after terrain. Its bit 0x04
    /// participates in negative desirability propagation; keep the original
    /// words instead of relying on the anonymous byte-grid compatibility view.
    public static let appealFlagsGridOffset = terrainGridOffset + gridCellCount * 4
    /// Compatibility base for the legacy apparent byte-grid view. It is the
    /// same physical offset as `appealFlagsGridOffset` (the serialized
    /// `DAT_00F37DA0` UInt32 layer); `legacyByteGrids` intentionally exposes
    /// the historical byte slices from this boundary for older callers.
    public static let firstByteGridOffset = terrainGridOffset + gridCellCount * 4
    /// `DAT_00F1E780` in the original runtime. The serializer writes one
    /// intervening UInt32 grid (four byte-grid widths) and then
    /// `DAT_00F9D620` before this byte grid, so it is the sixth apparent
    /// byte-sized slice after terrain. `SB_CANAL` uses only its low bit when
    /// selecting two of the phase-1/2 body variants.
    public static let terrainVisualVariationGridOffset = firstByteGridOffset
        + gridCellCount * 5
    /// `DAT_00E92DD0` in the original serializer. The apparent byte-grid
    /// sequence after terrain contains an intervening UInt32 grid and two
    /// scalar UInt32 values, so this offset must not be inferred from
    /// `legacyByteGrids` indices.
    public static let primaryElevationClassGridOffset = firstByteGridOffset
        + gridCellCount * 8 + 8
    /// Fixed-layer/archive-transition expression for canonical format-v5
    /// maps. The value is the start of the variable-size `FUN_0042D790`
    /// Building archive, not the later `DAT_00F2B290` auxiliary grid.
    public static let buildingArchiveTransitionOffset = firstByteGridOffset
        + gridCellCount * 12 + 408

    /// Legacy name retained for source compatibility. Parsing
    /// `DAT_00F2B290` must use the decoded-length boundary returned by
    /// `roadWaterAuxiliaryGridOffset(decodedByteCount:)`.
    @available(*, deprecated, message: "Use roadWaterAuxiliaryGridOffset(decodedByteCount:) for format-v5 maps")
    public static let roadWaterAuxiliaryGridOffset = buildingArchiveTransitionOffset

    /// Decoded start of format-v5 `DAT_00F2B290`.
    ///
    /// `FUN_0052E7C0 @ 0x52E7C0` writes this grid immediately after the
    /// variable-size Building archive and performs no later writes. The final
    /// 228×228 decoded bytes are therefore the stable auxiliary-grid boundary.
    public static func roadWaterAuxiliaryGridOffset(decodedByteCount: Int) -> Int? {
        guard decodedByteCount >= gridCellCount else { return nil }
        return decodedByteCount - gridCellCount
    }
    // Original Campaign Creator scenario-point fields in the decoded header.
    // The invasion and disaster collections are stored as parallel X/Y arrays;
    // entry/exit fields are stored as consecutive coordinate pairs.
    private static let fishingXOffset = 0x2C8
    private static let fishingYOffset = 0x2D8
    private static let landInvasionXOffset = 0x2FC
    private static let seaInvasionXOffset = 0x30C
    private static let landInvasionYOffset = 0x31C
    private static let seaInvasionYOffset = 0x32C
    private static let landEntryOffset = 0x352
    private static let disasterXOffset = 0x35A
    private static let disasterYOffset = 0x36A
    private static let seaEntryOffset = 0x37A
    // Original global China_Terrain image-table base. With this offset,
    // Banpo's road IDs resolve to local #782... and its tree IDs to #928...,
    // matching the archive's contiguous road and tree families. Fertile land
    // keeps a bare ground record here; the original renderer adds its tall
    // grass from the fertility layer, which the native renderer mirrors.
    public static let chinaTerrainGlobalImageBase: UInt32 = 48_921
    // China_Elevation begins at 33,219 in the original global image table.
    // Zhengzhou's IDs 33,420 and 33,444...33,458 therefore resolve to the
    // visually matching local cliff entries 201 and 225...239.
    public static let chinaElevationGlobalImageBase: UInt32 = 33_219
    // Banpo, Zhengzhou, Liangzhou and several other maps store cliff/slope
    // faces as `0x40000 | objectIndex`. Pack 16 is China_Elevation. Its SG3
    // starts with 200 Zeus_system records that the Windows loader removes, so
    // runtime local N corresponds to the raw SG3 record N + 200.
    public static let chinaElevationObjectImageFlag: UInt32 = 0x4_0000
    public static let chinaElevationObjectLocalBias = 200
    // Additional map-authored layers verified by matching their global IDs
    // to local SG3 entries and visually decoding the source sprites.
    public static let chinaElevationDirtGlobalImageBase: UInt32 = 34_203
    public static let chinaGreatWall1GlobalImageBase: UInt32 = 82_032
    public static let chinaGrandCanalGlobalImageBase: UInt32 = 98_117
    public static let chinaEarthenGreatWall1GlobalImageBase: UInt32 = 130_874

    public let url: URL
    public let formatVersion: UInt16
    public let width: Int
    public let height: Int
    public let startOffset: Int
    public let borderSize: Int
    public let description: String?
    public let imageIDs: [UInt32]
    public let edgeValues: [UInt8]
    public let terrainFlags: [UInt32]
    /// Exact map words for the serialized `DAT_00F37DA0` layer. This is
    /// intentionally data-only: the runtime's dynamic `+0x268` writer and
    /// callback lifecycle remain unresolved and are not inferred here.
    public let appealFlags: [UInt32]
    public let terrainVisualVariationValues: [UInt8]
    public let primaryElevationClassValues: [UInt8]
    public let roadWaterAuxiliaryValues: [UInt8]?
    public let authoredPoints: EmperorMapAuthoredPoints
    public let grandCanalPartStates: [GrandCanalMapPartState]
    public let greatWallPartStates: [GreatWallMapPartState]
    /// Specialized residential wall/gate records are exposed as read-only
    /// archive evidence. They are not inserted into the live object registry
    /// until the original post-load registration path is recovered.
    public let residentialBarrierStates: [OriginalResidentialBarrierMapState]
    /// Generic `Building` records from the variable-size map archive. These
    /// are retained as read-only source evidence so a future Qin object
    /// projection can consume the exact serialized rows without reparsing the
    /// map file. They are intentionally not inserted into the live Native
    /// city state: the executable's provider specialization/registry bridge
    /// remains unresolved.
    public let genericBuildingArchiveRecords: [OriginalGenericBuildingArchiveRecord]
    /// MFC class declarations recovered from the same variable-size archive.
    /// This is archive evidence only: a declaration identifies the serializer
    /// schema and first raw type word, but does not construct or register a
    /// live object.
    public let archiveClassDeclarations: [OriginalMapArchiveClassDeclaration]
    /// Fixed schema/slot-count preamble immediately before the variable-size
    /// object stream. This is archive evidence only and never constructs or
    /// registers the declared objects.
    public let archivePreamble: OriginalMapArchivePreamble?
    /// `cIndustrialBldg` records whose authored model is
    /// `BUILD_MAP_INVASION_POINT` (173). These are retained as archive
    /// evidence only; event/formation creation and runtime object-registry
    /// ownership remain unresolved and are not inferred here.
    public let archivedMapInvasionPointStates: [OriginalMapInvasionPointArchiveState]
    /// Header coordinates retained in the original eight runtime slot order.
    /// This is data-only evidence; it is not projected into live formations or
    /// the object registry.
    public let authoredLandInvasionPointSlots: [OriginalMapInvasionPointSlotState]
    /// Byte grids that immediately follow the terrain flags. Their stable
    /// positions are preserved while individual semantics are being verified.
    public let legacyByteGrids: [[UInt8]]

    /// The exact descriptor row selected by the original map loader for this
    /// authored rectangle. Parsing validates the same centered origin and
    /// therefore returns a descriptor for every supported GameData map.
    public var originalRuntimeDescriptor: OriginalMapRuntimeDescriptor? {
        OriginalMapRuntimeDescriptorCatalog.descriptor(width: width, height: height)
    }

    public init(url: URL) throws {
        let decoded = try SierraChunkedFile(contentsOf: url).decodedData
        var reader = BinaryReader(data: decoded)
        let signature = try reader.readUInt32LE()
        guard signature & 0xFFFF0000 == 0xCAFE0000 else {
            throw GameDataError.malformedFile("Emperor map signature")
        }

        let parsedWidth = Int(try reader.uint32LE(at: 0x54))
        let parsedHeight = Int(try reader.uint32LE(at: 0x58))
        let parsedStart = Int(try reader.uint32LE(at: 0x5C))
        let parsedBorder = Int(try reader.uint32LE(at: 0x60))
        guard (1...Self.gridSide).contains(parsedWidth),
              (1...Self.gridSide).contains(parsedHeight),
              parsedStart >= 0, parsedStart < Self.gridCellCount,
              parsedBorder == Self.gridSide - parsedWidth else {
            throw GameDataError.malformedFile("Emperor map dimensions")
        }
        let expectedStart = (Self.gridSide - parsedHeight) / 2 * Self.gridSide
            + (Self.gridSide - parsedWidth) / 2
        guard parsedStart == expectedStart else {
            throw GameDataError.malformedFile("Emperor map grid origin")
        }

        try reader.seek(to: Self.imageGridOffset)
        guard reader.remainingCount >= Self.gridCellCount * 9 else {
            throw GameDataError.malformedFile("truncated Emperor map grids")
        }
        var parsedImages: [UInt32] = []
        parsedImages.reserveCapacity(Self.gridCellCount)
        for _ in 0..<Self.gridCellCount {
            parsedImages.append(try reader.readUInt32LE())
        }
        let parsedEdges = Array(try reader.readData(count: Self.gridCellCount))
        var parsedTerrain: [UInt32] = []
        parsedTerrain.reserveCapacity(Self.gridCellCount)
        for _ in 0..<Self.gridCellCount {
            parsedTerrain.append(try reader.readUInt32LE())
        }
        guard decoded.count >= Self.appealFlagsGridOffset + Self.gridCellCount * 4 else {
            throw GameDataError.malformedFile("truncated Emperor appeal-flags grid")
        }
        var parsedAppealFlags: [UInt32] = []
        parsedAppealFlags.reserveCapacity(Self.gridCellCount)
        try reader.seek(to: Self.appealFlagsGridOffset)
        for _ in 0..<Self.gridCellCount {
            parsedAppealFlags.append(try reader.readUInt32LE())
        }
        try reader.seek(to: Self.firstByteGridOffset)
        var parsedByteGrids: [[UInt8]] = []
        for _ in 0..<13 where reader.remainingCount >= Self.gridCellCount {
            parsedByteGrids.append(Array(try reader.readData(count: Self.gridCellCount)))
        }
        guard decoded.count >= Self.primaryElevationClassGridOffset + Self.gridCellCount else {
            throw GameDataError.malformedFile("truncated Emperor elevation-class grid")
        }
        guard decoded.count >= Self.terrainVisualVariationGridOffset + Self.gridCellCount else {
            throw GameDataError.malformedFile("truncated Emperor terrain-variation grid")
        }
        let parsedTerrainVisualVariations = Array(decoded[
            Self.terrainVisualVariationGridOffset
                ..< Self.terrainVisualVariationGridOffset + Self.gridCellCount
        ])
        let parsedElevationClasses = Array(decoded[
            Self.primaryElevationClassGridOffset
                ..< Self.primaryElevationClassGridOffset + Self.gridCellCount
        ])
        let parsedRoadWaterAuxiliary: [UInt8]?
        if UInt16(signature & 0xFFFF) > 4,
           let auxiliaryOffset = Self.roadWaterAuxiliaryGridOffset(
               decodedByteCount: decoded.count
           ),
           decoded.count >= auxiliaryOffset + Self.gridCellCount {
            parsedRoadWaterAuxiliary = Array(decoded[
                auxiliaryOffset
                    ..< auxiliaryOffset + Self.gridCellCount
            ])
        } else {
            parsedRoadWaterAuxiliary = nil
        }

        func decodedUInt16(at offset: Int) -> Int {
            Int(decoded[offset]) | (Int(decoded[offset + 1]) << 8)
        }
        func point(xOffset: Int, yOffset: Int) -> GridPoint? {
            let x = decodedUInt16(at: xOffset)
            let y = decodedUInt16(at: yOffset)
            guard x != Int(UInt16.max), y != Int(UInt16.max),
                  x >= 0, x < parsedWidth, y >= 0, y < parsedHeight else { return nil }
            return GridPoint(x: x, y: y)
        }
        func pointArray(xOffset: Int, yOffset: Int, count: Int) -> [GridPoint] {
            (0..<count).compactMap { index in
                point(xOffset: xOffset + index * 2, yOffset: yOffset + index * 2)
            }
        }
        let parsedLandInvasionXCoordinates = (0..<OriginalMapInvasionPointSlotCatalog.slotCount).map {
            point(xOffset: Self.landInvasionXOffset + $0 * 2,
                  yOffset: Self.landInvasionYOffset + $0 * 2)
                .map(\.x)
        }
        let parsedLandInvasionYCoordinates = (0..<OriginalMapInvasionPointSlotCatalog.slotCount).map {
            point(xOffset: Self.landInvasionXOffset + $0 * 2,
                  yOffset: Self.landInvasionYOffset + $0 * 2)
                .map(\.y)
        }
        let parsedAuthoredPoints = EmperorMapAuthoredPoints(
            landEntry: point(xOffset: Self.landEntryOffset, yOffset: Self.landEntryOffset + 2),
            landExit: point(xOffset: Self.landEntryOffset + 4, yOffset: Self.landEntryOffset + 6),
            seaEntry: point(xOffset: Self.seaEntryOffset, yOffset: Self.seaEntryOffset + 2),
            seaExit: point(xOffset: Self.seaEntryOffset + 4, yOffset: Self.seaEntryOffset + 6),
            landInvasion: pointArray(
                xOffset: Self.landInvasionXOffset,
                yOffset: Self.landInvasionYOffset,
                count: 8
            ),
            seaInvasion: pointArray(
                xOffset: Self.seaInvasionXOffset,
                yOffset: Self.seaInvasionYOffset,
                count: 8
            ),
            disasters: pointArray(
                xOffset: Self.disasterXOffset,
                yOffset: Self.disasterYOffset,
                count: 8
            ),
            fishing: pointArray(
                xOffset: Self.fishingXOffset,
                yOffset: Self.fishingYOffset,
                count: 8
            )
        )

        let parsedArchiveClassDeclarations: [OriginalMapArchiveClassDeclaration]
        let parsedGenericBuildingArchiveRecords: [OriginalGenericBuildingArchiveRecord]
        let parsedArchivePreamble: OriginalMapArchivePreamble?
        if UInt16(signature & 0xFFFF) > 3,
           let archiveEnd = Self.roadWaterAuxiliaryGridOffset(decodedByteCount: decoded.count),
           archiveEnd > Self.buildingArchiveTransitionOffset {
            let archiveRange = Self.buildingArchiveTransitionOffset..<archiveEnd
            parsedArchivePreamble = OriginalMapArchivePreambleCatalog.parse(
                in: decoded,
                archiveOffset: archiveRange.lowerBound
            )
            parsedArchiveClassDeclarations = OriginalMapArchiveClassCatalog.declarations(
                in: decoded,
                archiveRange: archiveRange
            )
            parsedGenericBuildingArchiveRecords = OriginalGenericBuildingArchiveCatalog.records(
                in: decoded,
                archiveRange: archiveRange
            )
        } else {
            parsedArchivePreamble = nil
            parsedArchiveClassDeclarations = []
            parsedGenericBuildingArchiveRecords = []
        }

        self.url = url
        formatVersion = UInt16(signature & 0xFFFF)
        width = parsedWidth
        height = parsedHeight
        startOffset = parsedStart
        borderSize = parsedBorder
        description = reader.nullTerminatedString(at: 0x64, maximumLength: 256)
        imageIDs = parsedImages
        edgeValues = parsedEdges
        terrainFlags = parsedTerrain
        appealFlags = parsedAppealFlags
        terrainVisualVariationValues = parsedTerrainVisualVariations
        primaryElevationClassValues = parsedElevationClasses
        roadWaterAuxiliaryValues = parsedRoadWaterAuxiliary
        legacyByteGrids = parsedByteGrids
        authoredPoints = parsedAuthoredPoints
        grandCanalPartStates = try OriginalGrandCanalLayoutCatalog.archivedPartStates(
            in: decoded
        )
        greatWallPartStates = try OriginalGreatWallLayoutCatalog.archivedPartStates(
            in: decoded
        )
        archivePreamble = parsedArchivePreamble
        archiveClassDeclarations = parsedArchiveClassDeclarations
        genericBuildingArchiveRecords = parsedGenericBuildingArchiveRecords
        residentialBarrierStates = OriginalResidentialBarrierArchiveCatalog.archivedStates(
            in: decoded,
            mapWidth: parsedWidth,
            mapHeight: parsedHeight
        )
        archivedMapInvasionPointStates = OriginalMapInvasionPointArchiveCatalog.archivedStates(
            in: decoded,
            mapWidth: parsedWidth,
            mapHeight: parsedHeight
        )
        authoredLandInvasionPointSlots = OriginalMapInvasionPointSlotCatalog.slotStates(
            xCoordinates: parsedLandInvasionXCoordinates,
            yCoordinates: parsedLandInvasionYCoordinates
        )
    }

    public func imageID(x: Int, y: Int) -> UInt32? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return imageIDs[startOffset + y * Self.gridSide + x]
    }

    public func chinaTerrainSpriteID(x: Int, y: Int, imageCount: Int) -> Int? {
        localSpriteID(
            x: x,
            y: y,
            globalImageBase: Self.chinaTerrainGlobalImageBase,
            imageCount: imageCount
        )
    }

    public func chinaElevationSpriteID(x: Int, y: Int, imageCount: Int) -> Int? {
        // Transition cells around a raised area (stairs, outer cliff faces and
        // two-cell slopes) live in this archive even when their own terrain
        // word does not set elevation bit 9 (0x200). The global image interval
        // is authoritative for rendering; 0x200 remains the high-ground marker.
        if let direct = localSpriteID(
            x: x,
            y: y,
            globalImageBase: Self.chinaElevationGlobalImageBase,
            imageCount: imageCount
        ) {
            return direct
        }
        return chinaElevationObjectSpriteID(
            x: x,
            y: y,
            imageCount: imageCount
        ).map {
            Self.chinaElevationDisplaySpriteID(
                $0,
                neighborMask: chinaElevationNeighborMask(x: x, y: y)
            )
        }
    }

    /// Packed cliff encoding: pack 16 marks a China_Elevation runtime-local
    /// image index. The native archive retains the 200 stripped SG3 records,
    /// so add that loader prefix to address the corresponding raw record.
    public func chinaElevationObjectSpriteID(x: Int, y: Int, imageCount: Int) -> Int? {
        guard let globalID = imageID(x: x, y: y),
              globalID >> 14 == Self.chinaElevationObjectImageFlag >> 14 else {
            return nil
        }
        let localID = Int(globalID & 0x3FFF)
            + Self.chinaElevationObjectLocalBias
        return (0..<imageCount).contains(localID) ? localID : nil
    }

    /// A few elevation records are color-coded composition templates rather
    /// than finished player-facing artwork. Their four template IDs are not
    /// four fixed rotations: the finished tall and low cliff families each
    /// contain six connection shapes. Resolve them from the authored raised
    /// terrain around the cell so straight sections and corners stay joined.
    public static func chinaElevationDisplaySpriteID(
        _ decodedLocalID: Int,
        neighborMask: Int? = nil
    ) -> Int {
        guard let neighborMask else {
            // Stable fallbacks for callers that only inspect a raw record.
            return switch decodedLocalID {
            case 331...334: 335
            case 345...348: 354
            default: decodedLocalID
            }
        }
        let normalizedMask = neighborMask & 0xF
        if (331...334).contains(decodedLocalID) {
            // Tall cliff family: corner ES, corner NW, corner SW, straight NS,
            // straight EW and corner NE.
            return switch normalizedMask {
            case 0x6: 335
            case 0x9: 336
            case 0xC: 337
            case 0x5, 0x1, 0x4: 338
            case 0xA, 0x2, 0x8: 355
            case 0x3: 356
            case 0x7: 356
            case 0xB: 336
            case 0xD: 337
            case 0xE: 335
            default: 338
            }
        }
        if (345...348).contains(decodedLocalID) {
            // Low cliff family follows the same six authored connection
            // shapes in #349...#354.
            return switch normalizedMask {
            case 0xA, 0x2, 0x8: 349
            case 0x6: 350
            case 0xC: 351
            case 0x9: 352
            case 0x3: 353
            case 0x5, 0x1, 0x4: 354
            case 0x7: 353
            case 0xB: 352
            case 0xD: 351
            case 0xE: 350
            default: 354
            }
        }
        return decodedLocalID
    }

    public func chinaElevationNeighborMask(x: Int, y: Int) -> Int {
        func isRaised(_ x: Int, _ y: Int) -> Bool {
            terrainFlags(x: x, y: y).map {
                TerrainFlags(rawValue: $0).contains(.elevation)
            } ?? false
        }
        var mask = 0
        if isRaised(x, y - 1) { mask |= 1 }
        if isRaised(x + 1, y) { mask |= 2 }
        if isRaised(x, y + 1) { mask |= 4 }
        if isRaised(x - 1, y) { mask |= 8 }
        return mask
    }

    public func chinaElevationDirtSpriteID(x: Int, y: Int, imageCount: Int) -> Int? {
        localSpriteID(
            x: x,
            y: y,
            globalImageBase: Self.chinaElevationDirtGlobalImageBase,
            imageCount: imageCount
        )
    }

    public func chinaGreatWall1SpriteID(x: Int, y: Int, imageCount: Int) -> Int? {
        localSpriteID(
            x: x,
            y: y,
            globalImageBase: Self.chinaGreatWall1GlobalImageBase,
            imageCount: imageCount
        )
    }

    public func chinaGrandCanalSpriteID(x: Int, y: Int, imageCount: Int) -> Int? {
        localSpriteID(
            x: x,
            y: y,
            globalImageBase: Self.chinaGrandCanalGlobalImageBase,
            imageCount: imageCount
        )
    }

    public func chinaEarthenGreatWall1SpriteID(x: Int, y: Int, imageCount: Int) -> Int? {
        localSpriteID(
            x: x,
            y: y,
            globalImageBase: Self.chinaEarthenGreatWall1GlobalImageBase,
            imageCount: imageCount
        )
    }

    public func localSpriteID(
        x: Int,
        y: Int,
        globalImageBase: UInt32,
        imageCount: Int
    ) -> Int? {
        guard let globalID = imageID(x: x, y: y),
              globalID >= globalImageBase else { return nil }
        let localID = Int(globalID - globalImageBase)
        return (0..<imageCount).contains(localID) ? localID : nil
    }

    public func terrainFlags(x: Int, y: Int) -> UInt32? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return terrainFlags[startOffset + y * Self.gridSide + x]
    }

    public func edgeValue(x: Int, y: Int) -> UInt8? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return edgeValues[startOffset + y * Self.gridSide + x]
    }

    public func legacyByteValue(grid: Int, x: Int, y: Int) -> UInt8? {
        guard legacyByteGrids.indices.contains(grid), x >= 0, x < width, y >= 0, y < height else { return nil }
        return legacyByteGrids[grid][startOffset + y * Self.gridSide + x]
    }

    public func terrainVisualVariationValue(x: Int, y: Int) -> UInt8? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return terrainVisualVariationValues[startOffset + y * Self.gridSide + x]
    }

    public func appealFlagsValue(x: Int, y: Int) -> UInt32? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return appealFlags[startOffset + y * Self.gridSide + x]
    }

    public func primaryElevationClassValue(x: Int, y: Int) -> Int8? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return Int8(bitPattern: primaryElevationClassValues[startOffset + y * Self.gridSide + x])
    }

    public func roadWaterAuxiliaryValue(x: Int, y: Int) -> UInt8? {
        guard let roadWaterAuxiliaryValues,
              x >= 0, x < width, y >= 0, y < height else { return nil }
        return roadWaterAuxiliaryValues[startOffset + y * Self.gridSide + x]
    }
}
