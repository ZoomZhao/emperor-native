import Foundation

/// One `cIndustrialBldg` archive record whose common building type is
/// `BUILD_MAP_INVASION_POINT` (model 173).
///
/// The class name is historical executable data: it does not mean that the
/// record is a production building.  This value is archive evidence only and
/// is not inserted into the live military/object registry.
public struct OriginalMapInvasionPointArchiveState: Sendable, Hashable, Codable {
    public let className: String
    public let sequenceIndex: Int
    public let buildingID: Int
    public let worldOrigin: GridPoint
    public let mapCellIndex: Int
    public let formatVersion: Int

    public init(
        className: String,
        sequenceIndex: Int,
        buildingID: Int,
        worldOrigin: GridPoint,
        mapCellIndex: Int,
        formatVersion: Int
    ) {
        self.className = className
        self.sequenceIndex = sequenceIndex
        self.buildingID = buildingID
        self.worldOrigin = worldOrigin
        self.mapCellIndex = mapCellIndex
        self.formatVersion = formatVersion
    }
}

/// One runtime land-invasion point slot.  The original executable keeps eight
/// active parallel X/Y entries (`DAT_00c5cda4`/`DAT_00c5cdc4`) and uses `-1` as
/// the in-memory empty sentinel.  The backing initialization clears sixteen
/// words in each array; the extra eight words are observable by the random
/// start's first read but are not part of the validity predicate.  This value
/// deliberately remains separate from serialized `cIndustrialBldg/173` archive
/// records and from formation creation.
public struct OriginalMapInvasionPointSlotState: Sendable, Hashable, Codable {
    public let slotIndex: Int
    public let point: GridPoint?

    public init(slotIndex: Int, point: GridPoint?) {
        self.slotIndex = slotIndex
        self.point = point
    }
}

/// Constants and pure helpers for the original eight-slot runtime point
/// arrays.  The random starting choice is exposed as the raw 32-bit
/// normalization performed by `FUN_00522ae0(8, ...)`; selecting a valid slot
/// remains a separate operation even though the executable's first read can
/// observe one of the eight initialized backing words outside the active
/// eight-slot domain when the low nibble is 8…15.
public enum OriginalMapInvasionPointSlotCatalog {
    public static let slotCount = 8
    public static let backingStorageSlotCount = 16
    public static let serializedAbsentCoordinate = UInt16.max
    public static let runtimeAbsentCoordinate = -1

    /// Reproduces the source's special `param_1 == 8` start expression in
    /// `FUN_00522ae0 @ 0x522AE0` after its caller has advanced the shared RNG.
    /// The PE computes `(int)(randomWord & 0x8000000F)` and, only for a
    /// negative result, applies `(value - 1 | 0xFFFFFFF0) + 1`.  The current
    /// RNG publisher writes `DAT_010C7138 = stateA & 0x7FFF`, so canonical
    /// outputs are 0…15 here; the wider `UInt32` input preserves the raw
    /// instruction contract for replay and audit vectors.
    public static func sourceRandomStartIndex(randomWord: UInt32) -> Int32 {
        let masked = randomWord & 0x8000_000F
        let signed = Int32(bitPattern: masked)
        guard signed < 0 else { return signed }
        let normalized = (masked &- 1 | 0xFFFF_FFF0) &+ 1
        return Int32(bitPattern: normalized)
    }

    /// Replays the complete eight-iteration scan in `FUN_00522AE0` for the
    /// canonical initialized X-word storage.  The source checks only the X
    /// word (`-1` means absent), increments the index, and wraps at the active
    /// eight-slot boundary—not at the sixteen-word backing-storage boundary.
    /// Thus a start in 8…15 observes one backing-tail word, then immediately
    /// wraps to slot zero for the remaining checks.
    /// If all eight checks miss, the returned index is the post-loop EAX value,
    /// matching the executable's return register rather than inventing a nil
    /// sentinel.  Non-canonical signed-normalization results are rejected
    /// because their backing-memory address is outside this explicit model.
    public static func sourceRandomScanIndex(
        randomWord: UInt32,
        xCoordinates: [Int]
    ) -> Int? {
        guard xCoordinates.count == backingStorageSlotCount else { return nil }
        let rawStart = sourceRandomStartIndex(randomWord: randomWord)
        guard (0..<backingStorageSlotCount).contains(Int(rawStart)) else {
            return nil
        }

        var index = Int(rawStart)
        for _ in 0..<slotCount {
            if xCoordinates[index] != runtimeAbsentCoordinate {
                return index
            }
            index += 1
            if index >= slotCount { index = 0 }
        }
        return index
    }

    /// Returns the same circular order used after the original caller has
    /// selected a starting slot.  Invalid starts are rejected instead of
    /// being normalized, because the executable's caller contract is not
    /// recovered for arbitrary values.
    public static func circularScanOrder(startingAtZeroBased slot: Int) -> [Int] {
        guard (0..<slotCount).contains(slot) else { return [] }
        return (0..<slotCount).map { (slot + $0) % slotCount }
    }

    /// Converts parallel optional coordinates into stable slot records.  A
    /// slot is occupied only when both coordinates are present, matching
    /// `FUN_0049daf0`'s validity check.
    public static func slotStates(
        xCoordinates: [Int?],
        yCoordinates: [Int?]
    ) -> [OriginalMapInvasionPointSlotState] {
        guard xCoordinates.count == slotCount,
              yCoordinates.count == slotCount else { return [] }
        return (0..<slotCount).map { index in
            let point: GridPoint?
            if let x = xCoordinates[index], let y = yCoordinates[index] {
                point = GridPoint(x: x, y: y)
            } else {
                point = nil
            }
            return .init(slotIndex: index, point: point)
        }
    }
}

/// Read-only parser for the Qin `cIndustrialBldg` map-point run.
///
/// The first common-building ID is 16 bytes after the class-name end.  Later
/// records repeat at the confirmed 313-byte cadence and carry the MFC
/// `[25 80 04 00 03 01 00 00]` object header eighteen bytes before the common
/// building ID.  Coordinates and map-cell words use the common serializer
/// offsets (`buildingID - 8`, `buildingID - 6`, `buildingID - 4`).
/// No military formation, route, or figure state is inferred from these
/// records.
public enum OriginalMapInvasionPointArchiveCatalog {
    public static let className = "cIndustrialBldg"
    public static let buildingID = 173
    public static let formatVersion = 4
    public static let recordStride = 313
    public static let firstBuildingIDAfterClassName = 16
    public static let repeatedRecordHeaderOffsetFromBuildingID = 18
    public static let repeatedRecordHeader: [UInt8] = [
        0x25, 0x80, 0x04, 0x00, 0x03, 0x01, 0x00, 0x00
    ]

    public static func archivedStates(
        in decodedMapData: Data,
        mapWidth: Int,
        mapHeight: Int
    ) -> [OriginalMapInvasionPointArchiveState] {
        guard mapWidth > 0, mapHeight > 0,
              let descriptor = OriginalMapRuntimeDescriptorCatalog.descriptor(
                  width: mapWidth,
                  height: mapHeight
              ),
              decodedMapData.count > EmperorMap.gridCellCount
        else { return [] }

        let archiveEnd = decodedMapData.count - EmperorMap.gridCellCount
        let classBytes = Data(className.utf8)
        guard let classStart = decodedMapData.range(
            of: classBytes,
            options: [],
            in: EmperorMap.buildingArchiveTransitionOffset..<archiveEnd
        )?.lowerBound,
        classStart >= 6,
        decodedMapData[classStart - 6..<classStart]
            == Data([0xFF, 0xFF, 0x00, 0x00,
                     UInt8(classBytes.count & 0xFF), UInt8(classBytes.count >> 8)])
        else { return [] }

        let classEnd = classStart + classBytes.count
        let firstBuildingIDOffset = classEnd + firstBuildingIDAfterClassName
        guard classEnd + firstBuildingIDAfterClassName + 2 <= archiveEnd else {
            return []
        }

        func uint16(at offset: Int) -> UInt16 {
            UInt16(decodedMapData[offset])
                | UInt16(decodedMapData[offset + 1]) << 8
        }

        func uint32(at offset: Int) -> UInt32 {
            UInt32(decodedMapData[offset])
                | UInt32(decodedMapData[offset + 1]) << 8
                | UInt32(decodedMapData[offset + 2]) << 16
                | UInt32(decodedMapData[offset + 3]) << 24
        }

        guard uint16(at: classEnd) == formatVersion,
              uint16(at: firstBuildingIDOffset) == buildingID
        else { return [] }

        var result: [OriginalMapInvasionPointArchiveState] = []
        var sequenceIndex = 0
        var buildingIDOffset = firstBuildingIDOffset
        while buildingIDOffset + 4 <= archiveEnd {
            if sequenceIndex > 0 {
                let headerStart = buildingIDOffset - repeatedRecordHeaderOffsetFromBuildingID
                guard headerStart >= classEnd,
                      headerStart + repeatedRecordHeader.count <= archiveEnd,
                      decodedMapData[headerStart..<headerStart + repeatedRecordHeader.count]
                          == Data(repeatedRecordHeader)
                else { break }
            }

            guard uint16(at: buildingIDOffset) == buildingID,
                  buildingIDOffset >= 8,
                  buildingIDOffset + 313 <= archiveEnd
            else { break }

            let x = Int(uint16(at: buildingIDOffset - 8))
            let y = Int(uint16(at: buildingIDOffset - 6))
            guard x < mapWidth, y < mapHeight,
                  x >= 0, y >= 0 else { break }

            let mapCellIndex = Int(uint32(at: buildingIDOffset - 4))
            let expectedCell = descriptor.baseLinearOffset
                + y * descriptor.effectiveRowStride + x
            guard mapCellIndex == expectedCell else { break }

            result.append(.init(
                className: className,
                sequenceIndex: sequenceIndex,
                buildingID: buildingID,
                worldOrigin: GridPoint(x: x, y: y),
                mapCellIndex: mapCellIndex,
                formatVersion: formatVersion
            ))
            sequenceIndex += 1
            buildingIDOffset += recordStride
        }
        return result
    }
}
