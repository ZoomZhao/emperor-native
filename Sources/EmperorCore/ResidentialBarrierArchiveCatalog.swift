import Foundation

/// One serialized residential wall/gate object recovered from an authored
/// format-v5 map archive.  The common Building serializer's coordinate and
/// model fields are stable; the remaining object state is intentionally kept
/// raw until its cResWall/cResGate consumers are recovered.
public struct OriginalResidentialBarrierMapState: Sendable, Hashable, Codable {
    public let className: String
    public let sequenceIndex: Int
    public let buildingID: Int
    public let worldOrigin: GridPoint
    public let mapCellIndex: Int
    /// Common-serializer `+0xB4` value. For Xiangjun's specialized
    /// wall/gate records this is a serialized object-registry slot (1...43),
    /// not a service-provider slot. The slot's post-load ownership remains
    /// outside this read-only catalog.
    public let serializedRegistryIndex: Int
    /// Common-serializer byte at object `+0x07`. The original object-grid
    /// writer (`FUN_0042A5A0 @ 0x42A5A0`) uses this byte as the square
    /// footprint side before writing occupancy cells. Xiangjun's specialized
    /// wall/gate records all store `1`; this is geometry evidence only and is
    /// not a live registry/collision registration.
    public let serializedFootprintSide: Int
    /// Common-serializer byte at object `+0x04`.  The map loader tests this
    /// byte before invoking vtable `+0xC0`; Xiangjun's wall/gate records store
    /// `3`, so their specialized load callback is admitted by the original
    /// loader.  This remains archive evidence and does not register a Native
    /// object.
    public let serializedLoadEligibilityByte: UInt8
    /// Common-serializer word immediately after the model ID. Its semantics
    /// are not yet recovered (Xiangjun stores a changing sequence here).
    public let rawWordAfterBuildingID: UInt16

    public init(
        className: String,
        sequenceIndex: Int,
        buildingID: Int,
        worldOrigin: GridPoint,
        mapCellIndex: Int,
        serializedRegistryIndex: Int,
        serializedFootprintSide: Int,
        serializedLoadEligibilityByte: UInt8,
        rawWordAfterBuildingID: UInt16
    ) {
        self.className = className
        self.sequenceIndex = sequenceIndex
        self.buildingID = buildingID
        self.worldOrigin = worldOrigin
        self.mapCellIndex = mapCellIndex
        self.serializedRegistryIndex = serializedRegistryIndex
        self.serializedFootprintSide = serializedFootprintSide
        self.serializedLoadEligibilityByte = serializedLoadEligibilityByte
        self.rawWordAfterBuildingID = rawWordAfterBuildingID
    }
}

/// Specialized wall/gate load-callback targets recovered from the canonical
/// EN/CH vtables.  The callback allocates the shared 0x20-byte auxiliary with
/// the serialized `+0xB4` value; both classes use the same refresh target.
/// These are lifecycle facts only and are not a Native collision or registry
/// projection.
public enum OriginalResidentialBarrierLoadLifecycleCatalog {
    public static let wallVTableAddress: UInt32 = 0x007AAAB8
    public static let gateVTableAddress: UInt32 = 0x007AAFB0
    public static let loadCallbackAddress: UInt32 = 0x0051CB80
    public static let wallAuxiliaryRefreshAddress: UInt32 = 0x0051CC10
    public static let gateAuxiliaryRefreshAddress: UInt32 = 0x0051CC10
    /// Map post-load pass invokes this vtable slot for each eligible object.
    public static let postLoadCallbackAddress: UInt32 = 0x00415AD0
    public static let postLoadCallbackVTableSlot = 0x1C8
    /// `FUN_00415AD0` calls the barrier's connected-sprite/grid callback.
    public static let connectedCallbackAddress: UInt32 = 0x004153B0
    public static let connectedCallbackVTableSlot = 0x270
    public static let connectedCallbackArguments: (UInt8, UInt8) = (0, 0)
    /// Both specialized barrier vtables use the same completion predicate at
    /// `+0x268`; the indexed body `FUN_004E1C40` returns one unconditionally.
    /// The callback then ORs bit `4` into the object-grid state byte indexed by
    /// the object's `+0x10` map-cell field. These are raw state-transition
    /// facts, not a recovered semantic name for that bit.
    public static let connectedCompletionAddress: UInt32 = 0x004E1C40
    public static let connectedCompletionVTableSlot = 0x268
    public static let connectedCompletionReturnsTrue = true
    public static let connectedCompletionStateBitMask: UInt8 = 0x04
    public static let connectedCompletionStateIndexFieldOffset = 0x10
    public static let connectedCompletionStateIndexIsMapCell = true
    public static let connectedGridWriterAddress: UInt32 = 0x004B72B0
    /// `FUN_004153B0` selects these exact terrain-word overlays for the two
    /// model IDs present in Xiangjun's specialized runs.  Other supported
    /// wall/gate model families use the same selector but are not inferred
    /// here without an authored record or an equivalent branch trace.
    public static let wallConnectedOverlayFlags: UInt32 = 0x48
    public static let gateConnectedOverlayFlags: UInt32 = 0x08
    public static let auxiliaryRefreshInitializerAddress: UInt32 = 0x00418E80
    public static let registrySlotAccessorAddress: UInt32 = 0x0047F1B0
    public static let auxiliaryAllocationSize = 0x20
    public static let auxiliaryStoredInputOffset = 0x14
    public static let objectAuxiliaryFieldOffset = 0x14C
    public static let auxiliaryRegistryInputOffset = 0x14
    public static let loadEligibilityFieldOffset = 0x04
    public static let registryInputFieldOffset = 0xB4

    public static func invokesLoadCallback(eligibilityByte: UInt8) -> Bool {
        eligibilityByte != 0
    }

    /// Returns the overlay passed to `FUN_004B72B0` by the connected callback
    /// for the Xiangjun model IDs.  A missing result is deliberate: the
    /// callback has additional model families, but this catalog must not turn
    /// an untraced branch into a Native gameplay rule.
    public static func connectedOverlayFlags(forBuildingID buildingID: Int) -> UInt32? {
        switch buildingID {
        case 90:
            wallConnectedOverlayFlags
        case 105:
            gateConnectedOverlayFlags
        default:
            nil
        }
    }
}

/// Read-only parser for the specialized `cResWall`/`cResGate` object runs
/// emitted by the original MFC archive writer.  This is deliberately not a
/// gameplay loader: provider registration, collision side effects, and the
/// meaning of the derived state words remain unresolved.
public enum OriginalResidentialBarrierArchiveCatalog {
    private static let classNames = ["cResWall", "cResGate"]
    private static let recordStride = 313
    private static let expectedBuildingIDs: Set<Int> = [90, 105]

    /// Returns every validated specialized barrier record in stream order.
    /// The first record in a class run omits the four-byte MFC object token;
    /// later records carry `[01 00 03 80]` nineteen bytes before the common
    /// building-ID field.  These boundaries are confirmed by the repeated
    /// 313-byte EN/CH archive cadence and the inherited `+0x08` serializer
    /// (`0x415AE0`/`0x416490`) in both canonical PEs.
    public static func archivedStates(
        in decodedMapData: Data,
        mapWidth: Int = EmperorMap.gridSide,
        mapHeight: Int = EmperorMap.gridSide
    ) -> [OriginalResidentialBarrierMapState] {
        guard mapWidth > 0, mapHeight > 0,
              decodedMapData.count > EmperorMap.gridCellCount else { return [] }
        // Format-v5 map archives place the variable-size Building stream
        // immediately before the fixed auxiliary grid.  Never search or
        // stride records into that trailing grid: it is not an MFC object
        // stream and its bytes are not evidence of another barrier record.
        let archiveEnd = decodedMapData.count - EmperorMap.gridCellCount

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
        func findClass(_ name: String, after: Int) -> Int? {
            decodedMapData.range(
                of: Data(name.utf8),
                options: [],
                in: max(after, EmperorMap.buildingArchiveTransitionOffset)
                    ..< archiveEnd
            )?.lowerBound
        }
        func isNewClassHeader(at classStart: Int, length: Int) -> Bool {
            classStart >= 6
                && decodedMapData[classStart - 6 ..< classStart]
                    == Data([0xFF, 0xFF, 0x00, 0x00,
                             UInt8(length & 0xFF), UInt8(length >> 8)])
        }

        var result: [OriginalResidentialBarrierMapState] = []
        var searchStart = EmperorMap.buildingArchiveTransitionOffset
        for className in classNames {
            guard let classStart = findClass(className, after: searchStart),
                  isNewClassHeader(at: classStart, length: className.utf8.count)
            else { continue }
            let classEnd = classStart + className.utf8.count
            guard classEnd + 16 + 4 <= archiveEnd,
                  uint16(at: classEnd) == 3 else { continue }

            let firstBuildingIDOffset = classEnd + 16
            var sequenceIndex = 0
            var buildingIDOffset = firstBuildingIDOffset
            while buildingIDOffset + 180 < archiveEnd {
                if sequenceIndex > 0 {
                    let tokenStart = buildingIDOffset - 20
                    guard decodedMapData[tokenStart ..< tokenStart + 4]
                        == Data([0x01, 0x00, 0x03, 0x80]) else { break }
                }

                let buildingID = Int(uint16(at: buildingIDOffset))
                guard expectedBuildingIDs.contains(buildingID),
                      uint16(at: buildingIDOffset + 2) == 0,
                      uint16(at: buildingIDOffset - 16) == 3 else { break }

                let x = Int(uint16(at: buildingIDOffset - 8))
                let y = Int(uint16(at: buildingIDOffset - 6))
                // In schema 3 the common serializer emits +0xB4 143 bytes
                // after the model word. Preserve the authored slot value,
                // but do not treat it as a service-provider mapping.
                let registryIndex = Int(uint32(at: buildingIDOffset + 143))
                guard registryIndex > 0 else { break }
                // The common serializer emits object +0x07 three bytes into
                // the payload, eleven bytes before the model word. The
                // object-grid writer consumes this as the square side count.
                let footprintSide = Int(decodedMapData[buildingIDOffset - 11])
                guard (1...6).contains(footprintSide) else { break }
                guard x < mapWidth, y < mapHeight,
                      x >= 0, y >= 0 else { break }

                result.append(.init(
                    className: className,
                    sequenceIndex: sequenceIndex,
                    buildingID: buildingID,
                    worldOrigin: GridPoint(x: x, y: y),
                    mapCellIndex: Int(uint32(at: buildingIDOffset - 4)),
                    serializedRegistryIndex: registryIndex,
                    serializedFootprintSide: footprintSide,
                    serializedLoadEligibilityByte: decodedMapData[buildingIDOffset - 16],
                    rawWordAfterBuildingID: uint16(at: buildingIDOffset + 4)
                ))
                sequenceIndex += 1
                buildingIDOffset += recordStride
            }
            searchStart = classEnd
        }
        return result
    }
}
