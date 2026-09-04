import Foundation

/// Address-level contract for the original event-driven map-cell invalidator.
///
/// `FUN_004ED700 @ 0x4ED700` probes the eight surrounding cells and calls
/// `FUN_004ED840 @ 0x4ED840` for each cell whose source predicate admits it.
/// The writer ORs the cell terrain/object word with `0x04000100` and stores
/// `2` in the shared 16-bit routing cache rooted at `DAT_013789C0`.
///
/// This is a read-only research primitive. The event record's type-byte-5
/// lifecycle and the meaning of the source flag are not recovered well enough
/// to apply these writes to Native terrain, objects, figures, or simulation.
public enum OriginalMapCellInvalidation {
    public static let fanoutAddress: UInt32 = 0x004ED700
    public static let writerAddress: UInt32 = 0x004ED840
    public static let routingCacheAddress: UInt32 = 0x013789C0
    public static let routingCacheBlockedValue: UInt16 = 2
    public static let terrainObjectORMask: UInt32 = 0x04000100
    public static let eventByteIncrement: Int = 1
    public static let mapRowStride: Int = 228

    /// Ordered offsets consumed by `FUN_004ED700`, beginning north and then
    /// east/south/west followed by the four diagonals.
    public static let neighboringCellOffsets: [Int] = [
        -mapRowStride, 1, mapRowStride, -1,
        -mapRowStride + 1, mapRowStride + 1,
        mapRowStride - 1, -mapRowStride - 1,
    ]

    public static func neighboringCellIndices(centralIndex: Int) -> [Int] {
        neighboringCellOffsets.map { centralIndex + $0 }
    }

    public static func terrainObjectWord(afterInvalidation before: UInt32) -> UInt32 {
        before | terrainObjectORMask
    }
}
