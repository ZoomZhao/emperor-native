import Foundation

/// Source-backed geometry emitted by the original map-object writer
/// `FUN_004B72B0 @ 0x4B72B0`.
///
/// The executable stores objects in a linear 228-cell row-stride grid and
/// looks up each footprint cell through the shared six-by-six
/// `DAT_0081FF18` table.  The canonical table values are included below from
/// the matched EN/CH data slice; callers may still supply a different table
/// when working with a non-canonical executable build.
/// This type is a research primitive only and is not used by live simulation.
public enum OriginalMapObjectGridProjection {
    public static let mapRowStride = 0xE4
    public static let offsetTableSide = 6
    public static let terrainPreservationMask: UInt32 = 0x9387_2790

    /// Canonical EN/CH `DAT_0081FF18` values.  The first dword follows the
    /// `0xE4` row stride; the paired byte values are retained even though the
    /// current writer callers do not assign semantic meaning to that field.
    public static let canonicalOffsetTable: [OffsetEntry] = (0..<offsetTableSide).flatMap {
        row in
        (0..<offsetTableSide).map { column in
            OffsetEntry(
                linearOffset: row * mapRowStride + column,
                directionByte: UInt8(row * 8 + column)
            )
        }
    }

    /// One pair from `DAT_0081FF18`: the first dword is added to the base
    /// linear map offset and the second byte is copied to `DAT_00FDCD70`.
    public struct OffsetEntry: Sendable, Hashable, Codable {
        public let linearOffset: Int
        public let directionByte: UInt8

        public init(linearOffset: Int, directionByte: UInt8) {
            self.linearOffset = linearOffset
            self.directionByte = directionByte
        }
    }

    /// Values written for one projected cell.  `terrainWord` is deliberately
    /// retained separately from `overlayFlags`: the PE performs
    /// `(before & 0x93872790) | param_7`, so callers must provide the prior
    /// word rather than treating the overlay as a complete terrain value.
    public struct CellWrite: Sendable, Hashable, Codable {
        public let tableIndex: Int
        public let linearOffset: Int
        public let terrainWord: UInt32
        public let overlayFlags: UInt32
        public let registryID: Int
        public let auxiliaryValue: Int
        public let directionByte: UInt8
        /// Low three bits written to `DAT_00F9D620` are `width - 1` for
        /// widths 2…6 and zero for a one-cell footprint.
        public let footprintCode: UInt8
        /// `DAT_00FDCD70` receives bit `0x40` on the direction-selected
        /// corner of the footprint.
        public let edgeMarked: Bool

        public init(
            tableIndex: Int,
            linearOffset: Int,
            terrainWord: UInt32,
            overlayFlags: UInt32,
            registryID: Int,
            auxiliaryValue: Int,
            directionByte: UInt8,
            footprintCode: UInt8,
            edgeMarked: Bool
        ) {
            self.tableIndex = tableIndex
            self.linearOffset = linearOffset
            self.terrainWord = terrainWord
            self.overlayFlags = overlayFlags
            self.registryID = registryID
            self.auxiliaryValue = auxiliaryValue
            self.directionByte = directionByte
            self.footprintCode = footprintCode
            self.edgeMarked = edgeMarked
        }
    }

    /// Applies the exact terrain-word merge used by `FUN_004B72B0`.
    public static func mergedTerrainWord(
        before: UInt32,
        overlayFlags: UInt32
    ) -> UInt32 {
        before & terrainPreservationMask | overlayFlags
    }

    /// Projects one rectangular writer call into ordered cell writes.
    ///
    /// `baseLinearOffset` is the executable's `DAT_0101D0C8` map base.  The
    /// caller supplies it explicitly because the Native mission rectangle is
    /// not proven to share the PE backing-grid origin.  `direction` is the
    /// original render-direction value (`0`, `2`, `4`, or `6`), not a Native
    /// building orientation.  The table must contain all 36 entries; only the
    /// first `width × height` row-major entries are consumed.
    public static func project(
        origin: GridPoint,
        width: Int,
        height: Int,
        direction: Int,
        baseLinearOffset: Int,
        registryID: Int,
        auxiliaryValue: Int,
        overlayFlags: UInt32,
        priorTerrainWords: [Int: UInt32],
        offsetTable: [OffsetEntry]
    ) -> [CellWrite]? {
        guard (1...offsetTableSide).contains(width),
              (1...offsetTableSide).contains(height),
              offsetTable.count == offsetTableSide * offsetTableSide,
              [0, 2, 4, 6].contains(direction) else {
            return nil
        }

        let base = baseLinearOffset + origin.y * mapRowStride + origin.x
        let edgeColumn: Int
        let edgeRow: Int
        switch direction {
        case 0:
            edgeColumn = 0
            edgeRow = height - 1
        case 2:
            edgeColumn = 0
            edgeRow = 0
        case 4:
            edgeColumn = width - 1
            edgeRow = 0
        default: // 6
            edgeColumn = width - 1
            edgeRow = height - 1
        }

        let footprintCode = UInt8(width - 1)
        var writes: [CellWrite] = []
        writes.reserveCapacity(width * height)
        for row in 0..<height {
            for column in 0..<width {
                let tableIndex = row * offsetTableSide + column
                let entry = offsetTable[tableIndex]
                let linearOffset = base + entry.linearOffset
                let before = priorTerrainWords[linearOffset] ?? 0
                writes.append(CellWrite(
                    tableIndex: tableIndex,
                    linearOffset: linearOffset,
                    terrainWord: mergedTerrainWord(before: before, overlayFlags: overlayFlags),
                    overlayFlags: overlayFlags,
                    registryID: registryID,
                    auxiliaryValue: auxiliaryValue,
                    directionByte: entry.directionByte,
                    footprintCode: footprintCode,
                    edgeMarked: column == edgeColumn && row == edgeRow
                ))
            }
        }
        return writes
    }
}
