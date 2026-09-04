import Foundation

/// One generic `Building` record in the variable-size map archive.
///
/// This is a read-only archive-evidence value.  The original loader creates a
/// generic `Building` object for these records, but the post-load projection
/// into specialized service providers is not recovered; callers must not use
/// this catalog as a live object-registry substitute.
public struct OriginalGenericBuildingArchiveRecord: Sendable, Hashable, Codable {
    public let streamOffset: Int
    public let formatVersion: Int
    public let recordLength: Int
    public let baseTypeWord: UInt16
    public let providerRegistrySlot: Int32
    /// Object `+0x04` as emitted in the packed serializer field stream.
    /// `FUN_0042D790` uses this raw byte as the load-callback eligibility
    /// condition; its semantic name remains unresolved.
    public let serializedLoadEligibilityByte: UInt8
    /// Object `+0x09` as emitted in the packed serializer field stream.
    /// The HouseBldg `+0xB8` population callback reads this byte, but the
    /// generic archive record does not by itself prove that the record is a
    /// HouseBldg or that the byte survives post-load specialization.
    public let serializedHousePopulationEligibilityByte: UInt8
    /// Object `+0x10` as emitted in the packed serializer field stream.
    /// This is retained as a raw DWORD; specialized barrier records use the
    /// corresponding field as a linear map-cell word, but that meaning is not
    /// assumed for generic records.
    public let serializedMapCellWord: UInt32
    /// Object `+0x0A` as emitted in the packed serializer field stream.
    /// This is a raw archive coordinate word; no live object registration is
    /// implied by exposing it.
    public let serializedCoordinateX: Int16
    /// Object `+0x0C` as emitted in the packed serializer field stream.
    public let serializedCoordinateY: Int16
    /// Object `+0xA0` as emitted in the packed serializer field stream.
    /// This is the placement-time value later consumed by the feng-shui
    /// aggregation, not the terrain-element presentation value.
    public let serializedPlacementValue: Int32

    public init(
        streamOffset: Int,
        formatVersion: Int,
        recordLength: Int,
        baseTypeWord: UInt16,
        providerRegistrySlot: Int32,
        serializedLoadEligibilityByte: UInt8,
        serializedHousePopulationEligibilityByte: UInt8,
        serializedMapCellWord: UInt32,
        serializedCoordinateX: Int16,
        serializedCoordinateY: Int16,
        serializedPlacementValue: Int32
    ) {
        self.streamOffset = streamOffset
        self.formatVersion = formatVersion
        self.recordLength = recordLength
        self.baseTypeWord = baseTypeWord
        self.providerRegistrySlot = providerRegistrySlot
        self.serializedLoadEligibilityByte = serializedLoadEligibilityByte
        self.serializedHousePopulationEligibilityByte = serializedHousePopulationEligibilityByte
        self.serializedMapCellWord = serializedMapCellWord
        self.serializedCoordinateX = serializedCoordinateX
        self.serializedCoordinateY = serializedCoordinateY
        self.serializedPlacementValue = serializedPlacementValue
    }
}

/// Forensic scanner for the generic `Building` stream emitted by the
/// original format-v5 map serializer (`FUN_00427430 @ 0x427430`).
///
/// The stream token is `0x8001` (little-endian bytes `01 80`), followed by a
/// schema word (`3` or `4`).  After the four-byte object header, the common
/// serializer emits fields in call order (not at their in-memory offsets):
/// object `+0x14` is the 18th stream byte, `+0x0A/+0x0C` are stream bytes
/// `+0x0A/+0x0C`, and `+0xA0` is stream byte `+0x8F` for schema 3 or `+0x91`
/// for schema 4 (schema 4 inserts a two-byte `+0x92` field before it).  The
/// final 20-byte tail contains object `+0xB4` followed by `+0xB8`.  Schema 3
/// and 4 records occupy 181 and 183 bytes respectively.  These are packed
/// stream offsets, not raw struct offsets; no class specialization, provider
/// registration, collision, or simulation side effect is inferred here.
public enum OriginalGenericBuildingArchiveCatalog {
    public static let serializerAddress: UInt32 = 0x00427430
    public static let streamToken: UInt16 = 0x8001
    public static let baseTypeWordOffset = 18
    public static let loadEligibilityByteOffset = 4
    public static let housePopulationEligibilityByteOffset = 9
    public static let coordinateXOffset = 10
    public static let coordinateYOffset = 12
    public static let mapCellWordOffset = 14
    public static let placementValueOffsetSchema3 = 143
    public static let placementValueOffsetSchema4 = 145
    public static let commonTailLength = 20

    public static func recordLength(formatVersion: Int) -> Int? {
        switch formatVersion {
        case 3: return 181
        case 4: return 183
        default: return nil
        }
    }

    /// Enumerates records whose common serializer base-type word is zero.
    /// `archiveRange` must exclude the trailing fixed auxiliary grid; the
    /// scanner does not infer that boundary from arbitrary bytes.
    public static func records(
        in decodedMapData: Data,
        archiveRange: Range<Int>
    ) -> [OriginalGenericBuildingArchiveRecord] {
        guard archiveRange.lowerBound >= 0,
              archiveRange.upperBound <= decodedMapData.count,
              archiveRange.lowerBound < archiveRange.upperBound
        else { return [] }

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

        var result: [OriginalGenericBuildingArchiveRecord] = []
        var offset = archiveRange.lowerBound
        while offset + 4 <= archiveRange.upperBound {
            guard uint16(at: offset) == streamToken else {
                offset += 1
                continue
            }
            let schema = Int(uint16(at: offset + 2))
            guard let length = recordLength(formatVersion: schema),
                  offset + length <= archiveRange.upperBound,
                  offset + baseTypeWordOffset + 2 <= archiveRange.upperBound
            else {
                offset += 1
                continue
            }
            let baseTypeWord = uint16(at: offset + baseTypeWordOffset)
            guard baseTypeWord == 0 else {
                offset += 1
                continue
            }

            let tailStart = offset + length - commonTailLength
            guard tailStart + 4 <= archiveRange.upperBound else {
                offset += 1
                continue
            }
            let placementOffset = schema == 3
                ? placementValueOffsetSchema3
                : placementValueOffsetSchema4
            guard offset + placementOffset + 4 <= archiveRange.upperBound else {
                offset += 1
                continue
            }
            let coordinateX = Int16(bitPattern: uint16(at: offset + coordinateXOffset))
            let coordinateY = Int16(bitPattern: uint16(at: offset + coordinateYOffset))
            let placementValue = Int32(bitPattern: uint32(at: offset + placementOffset))
            result.append(.init(
                streamOffset: offset,
                formatVersion: schema,
                recordLength: length,
                baseTypeWord: baseTypeWord,
                providerRegistrySlot: Int32(bitPattern: uint32(at: tailStart)),
                serializedLoadEligibilityByte: decodedMapData[offset + loadEligibilityByteOffset],
                serializedHousePopulationEligibilityByte: decodedMapData[
                    offset + housePopulationEligibilityByteOffset
                ],
                serializedMapCellWord: uint32(at: offset + mapCellWordOffset),
                serializedCoordinateX: coordinateX,
                serializedCoordinateY: coordinateY,
                serializedPlacementValue: placementValue
            ))
            offset += length
        }
        return result
    }
}

/// Model IDs that the original post-load rebuild pass (`FUN_0052F030 @
/// 0x52F030`) turns back into runtime objects by calling `Creating(...)`.
///
/// This is intentionally separate from the archive scanner: a generic
/// `Building` record's `baseTypeWord` is the serialized object `+0x14` model
/// field, but the rebuild pass is a whitelist, not a blanket generic-record
/// conversion.  Keeping the predicate explicit prevents map loading from
/// inventing residential/service providers for records the executable leaves
/// as generic objects.
public enum OriginalMapLoaderRehydrationCatalog {
    public static let passAddress: UInt32 = 0x0052F030
    public static let predicateAddress: UInt32 = 0x0052F1D0

    /// Exact `FUN_0052F1D0` cases recovered from the canonical EN/CH builds.
    /// The range `0xFD...0x10C` is inclusive.
    public static let modelIDs: Set<Int> = Set([
        0x53, 0x59, 0x5A, 0x5B,
        0x68, 0x69, 0x6A, 0x7B,
        0x81, 0x82, 0x83, 0xD2,
        0xE7, 0xE8,
    ]).union(Set(0xFD...0x10C))

    public static func rehydrates(modelID: Int) -> Bool {
        modelIDs.contains(modelID)
    }

    /// The map-loader pass sees the common serialized `+0x14` model word.
    public static func rehydrates(
        genericRecord: OriginalGenericBuildingArchiveRecord
    ) -> Bool {
        rehydrates(modelID: Int(genericRecord.baseTypeWord))
    }
}

/// General map-load call chain recovered for the canonical builds. This is
/// separate from the archive scanner and HouseBldg factory: it records where
/// the executable invokes the rehydration whitelist without claiming that
/// generic Qin records are specialized there.
public enum OriginalMapLoadRehydrationChain {
    /// Archive/city load entry (`FUN_0043ABF0`).
    public static let loadEntryAddress: UInt32 = 0x0043ABF0
    /// Generic `Building` object constructor installed by
    /// `FUN_0042D0E0 → FUN_0077FD90("Building")`.
    public static let genericBuildingVTableAddress: UInt32 = 0x007AB59C
    /// `FUN_0042D790` invokes this virtual slot after each generic record is
    /// loaded. The base generic vtable points at `FUN_004271B0`.
    public static let genericBuildingLoadCallbackAddress: UInt32 = 0x004271B0
    public static let genericBuildingLoadCallbackPredicateSlot: UInt32 = 0x150
    /// The base generic vtable's predicate slot points at the always-false
    /// `FUN_00413A00`; consequently the callback does not enter its
    /// `FUN_0042B6B0/FUN_0042B580` tail for a freshly loaded generic row.
    public static let genericBuildingDefaultPredicateAddress: UInt32 = 0x00413A00
    public static let genericBuildingDefaultPredicateReturnsFalse = true
    /// Post-deserialization rebuild sequence (`FUN_0053D100`).
    public static let rebuildSequenceAddress: UInt32 = 0x0053D100
    /// Direct calls in `FUN_0053D100` after the whitelist pass.  The order is
    /// significant: the source rebuilds its object-derived caches only after
    /// `FUN_0052F030` has had a chance to create whitelisted objects, then
    /// refreshes the map presentation.  These are addresses only; no service
    /// provider or market projection is inferred from the cache calls.
    public static let postRehydrationCallSequence: [UInt32] = [
        0x0053D630, // FUN_0053D630
        0x0053CAE0, // FUN_0053CAE0
        0x0053CBD0, // FUN_0053CBD0
        0x005ADDD0, // FUN_005ADDD0
        0x005ADD10, // FUN_005ADD10
        0x005AD8F0, // FUN_005AD8F0
        0x00522810, // thunk_FUN_00522810
        0x005ADD40, // FUN_005ADD40
        0x00468B80, // FUN_00468B80
    ]
    /// Generic-object whitelist pass called by the rebuild sequence.
    public static let rehydrationPassAddress: UInt32 = 0x0052F030
    public static let rehydrationPredicateAddress: UInt32 = 0x0052F1D0

    /// The split corpus contains one direct indexed caller of
    /// `FUN_0052F030`: the map/post-load sequence above.  This is a direct
    /// callsite census only; an indirect/table-driven edge is not ruled out.
    public static let rehydrationPassDirectCallerAddresses: [UInt32] = [
        rebuildSequenceAddress,
    ]

    /// Raw fields read from each active object before the whitelist pass
    /// dispatches the common creation routine.  These are object offsets in
    /// the source layout, not generic-archive offsets.
    public static let rehydrationVectorStartIndex: Int = 1
    public static let rehydrationObjectActiveFieldOffset: Int = 0x04
    public static let rehydrationObjectModelFieldOffset: Int = 0x14
    public static let rehydrationObjectCoordinateXOffset: Int = 0x0A
    public static let rehydrationObjectCoordinateYOffset: Int = 0x0C
    public static let rehydrationCreationAddress: UInt32 = 0x0042D540

    /// Explicit `Creating(...)` writes the selected object-vector slot back
    /// into the new object's `+0xB4` dword immediately after installing the
    /// object pointer in `FUN_00413B40(slot)`.  This is a registration-index
    /// assignment for objects created through that entry point only; it does
    /// not prove that a generic Qin archive row reaches `Creating(...)` or
    /// that the slot is a residential-service provider index.
    public static let creationRegistryFieldOffset: Int = 0xB4
    public static let creationRegistryFieldSourceAddress: UInt32 = 0x00413B40
    public static let creationRegistryFieldStoresVectorSlot = true
}

/// Direct-call metadata for the original primary map-routing cache rebuild.
///
/// `FUN_005AD440 @ 0x5AD440` derives the 16-bit per-cell words consumed by
/// walker routing from the authored terrain grid and live object predicates.
/// The catalog is intentionally metadata only: Native does not synthesize the
/// source's object-vtable predicates or install this cache as a simulation
/// truth source until those projections are recovered.
public enum OriginalPrimaryMapCacheCatalog {
    public static let rebuildAddress: UInt32 = 0x005AD440
    public static let fullMapRebuildAddress: UInt32 = 0x005AD8F0
    public static let cacheBaseAddress: UInt32 = 0x013789C0
    public static let cacheRowStride: UInt32 = 0xE4

    /// Complete direct relative-call sites found in both canonical PE `.text`
    /// sections.  Duplicate caller addresses are intentional when one
    /// function refreshes more than one region or branch.
    public static let directCallSites: [UInt32] = [
        0x00415A9A, 0x00415F2D, 0x0042A940, 0x0042BB81, 0x0042BCBE,
        0x004AD39B, 0x004B170C, 0x004B299F, 0x004BE1F7, 0x004BE36F,
        0x004EC5D3, 0x004EC7E4, 0x005432FA, 0x005AD90A, 0x005E22BC,
    ]

    public static let directCallerAddresses: [UInt32] = [
        0x004158D0, 0x00415E30, 0x0042A5A0, 0x0042BA40, 0x0042BBD0,
        0x004AD260, 0x004B1250, 0x004B2680, 0x004BDF30, 0x004BE270,
        0x004EC4A0, 0x004EC4A0, 0x005431C0, 0x005AD8F0, 0x005E20F0,
    ]
}

/// Model predicate used by the explicit object factory for `HouseBldg`.
/// `FUN_0042D360` dispatches model IDs `2...17` through
/// `FUN_0042D480`/vtable `0x7ABA38`; this is a factory boundary, not proof
/// that a generic Qin archive record will be rehydrated into a house.  The
/// map-loader whitelist above deliberately remains separate because its
/// `FUN_0052F1D0` cases do not include this range.
public enum OriginalHouseBldgFactoryCatalog {
    public static let factoryAddress: UInt32 = 0x0042D360
    public static let predicateAddress: UInt32 = 0x005188B0
    public static let constructorAddress: UInt32 = 0x0042D480
    public static let vtableAddress: UInt32 = 0x007ABA38
    /// Creation-time model/coordinate setter reached through the HouseBldg
    /// vtable's `+0x94` slot.  The setter itself dispatches the eligibility
    /// initializer below through the same vtable's `+0x90` slot.
    public static let creationSetterAddress: UInt32 = 0x00428AA0
    public static let creationSetterVTableSlot: UInt32 = 0x94
    /// `FUN_00518B70` writes HouseBldg byte `+0x09 = 1` after the common
    /// reset.  This is the explicit-creation initialization edge only; it
    /// does not imply that generic Qin archive rows are rehydrated as houses.
    public static let eligibilityInitializerAddress: UInt32 = 0x00518B70
    public static let eligibilityInitializerVTableSlot: UInt32 = 0x90
    public static let modelIDs: Set<Int> = Set(2...17)

    public static func createsHouseBldg(modelID: Int) -> Bool {
        modelIDs.contains(modelID)
    }
}
