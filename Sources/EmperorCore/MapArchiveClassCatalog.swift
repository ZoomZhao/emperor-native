import Foundation

/// The fixed preamble immediately before the variable-size map-object stream.
///
/// `FUN_0042D790` reads a 16-bit archive schema and, for schema `1`, a DWORD
/// object-slot count before asking the runtime-class loader for the first MFC
/// class tag.  This value is archive evidence only: it does not allocate,
/// register, or specialize any object.
public struct OriginalMapArchivePreamble: Sendable, Hashable, Codable {
    public let archiveOffset: Int
    public let archiveSchema: Int
    public let objectSlotCount: Int
    public let firstClassDeclarationOffset: Int?
    public let firstClassName: String?

    public init(
        archiveOffset: Int,
        archiveSchema: Int,
        objectSlotCount: Int,
        firstClassDeclarationOffset: Int? = nil,
        firstClassName: String? = nil
    ) {
        self.archiveOffset = archiveOffset
        self.archiveSchema = archiveSchema
        self.objectSlotCount = objectSlotCount
        self.firstClassDeclarationOffset = firstClassDeclarationOffset
        self.firstClassName = firstClassName
    }
}

/// Runtime-class dispatch used by the original MFC map archive reader.
///
/// `FUN_0042D0E0` supplies the `Building` descriptor as the expected base
/// class, but `FUN_0077FD90` does not force every stream object to use that
/// concrete vtable.  A serialized `0xFFFF` tag is resolved by
/// `FUN_007802FE`, which compares the serialized class name against the
/// registered runtime-class list and returns the selected class object.  The
/// constructor and serializer are then invoked through that runtime-class
/// object.  These constants describe the recovered dispatch boundary only;
/// they do not project archive classes into Native's live object registry.
public enum OriginalMapArchiveRuntimeClassCatalog {
    /// Map loader's expected base descriptor (`PTR_s_Building_00817890`).
    public static let buildingRuntimeClassAddress: UInt32 = 0x00817890
    /// `FUN_0042D0E0` asks MFC to read one object against the Building base.
    public static let readObjectCallerAddress: UInt32 = 0x0042D0E0
    /// MFC archive object reader (`FUN_0077FD90`).
    public static let readObjectAddress: UInt32 = 0x0077FD90
    /// Object-tag/reference decoder called by the reader.
    public static let objectTagReaderAddress: UInt32 = 0x0077FFC8
    /// Serialized-class-name resolver (`FUN_007802FE`).
    public static let classNameResolverAddress: UInt32 = 0x007802FE
    /// `FUN_0077FFC8` enters the resolver for the MFC new-class marker.
    public static let newClassMarker: UInt16 = 0xFFFF
    /// Resolver comparison is the ANSI exact-name `lstrcmpA` operation.
    public static let resolverUsesExactClassNameMatch = true
    /// The selected runtime class invokes its constructor/serializer before
    /// `FUN_0077FD90` returns the object to the map loader.
    public static let invokesSelectedClassConstructorAndSerializer = true
    /// The indexed map loader's direct caller of `FUN_0077FD90`.
    public static let mapLoaderDirectCallerAddresses: [UInt32] = [
        readObjectCallerAddress
    ]

    /// After `FUN_0042D0E0` returns a decoded object, `FUN_0042D790` appends
    /// its pointer at the current object-vector end through
    /// `FUN_0042B590 → FUN_005F01F0 → FUN_005C1670`.  The insertion count is
    /// one and the insertion position is the vector end; this is stream/
    /// vector ordering evidence only, not an assignment to object `+0xB4`.
    public static let archiveObjectVectorInsertAddress: UInt32 = 0x0042B590
    public static let archiveObjectVectorInsertHelperAddress: UInt32 = 0x005F01F0
    public static let archiveObjectVectorArrayInsertAddress: UInt32 = 0x005C1670
    public static let archiveObjectVectorInsertUsesCurrentEnd = true
    public static let archiveObjectVectorInsertCount = 1
    public static let archiveObjectVectorInsertWritesRegistryField = false

    /// MFC's inverse object-reference writer. It assigns an archive reference
    /// token from its own `+0x30` counter and does not inspect a Building's
    /// model (`+0x14`) or provider-slot (`+0xB4`) fields. The object's own
    /// serializer may subsequently write its fields, but that is a separate
    /// archive operation and is not a provider-registry assignment.
    public static let archiveReferenceWriterAddress: UInt32 = 0x0077FD11
    public static let archiveReferenceWriteBridgeAddress: UInt32 = 0x0042DC60
    public static let archiveReferenceTokenCounterOffset = 0x30
    public static let archiveReferenceWriterUsesMFCReferenceTable = true
    public static let archiveReferenceWriterReadsModelField = false
    public static let archiveReferenceWriterReadsProviderRegistryField = false
}

/// Sanitization boundary for the original map object's 16-bit registry grid.
///
/// `FUN_0053D630 @ 0x53D630` walks `DAT_00FC3750` after map setup.  A non-zero
/// signed short is retained only when it is a positive live object-vector
/// index (`id < FUN_00554C00()`), and the resolved object's model word at
/// `+0x14` is non-zero.  Invalid, negative, zero, out-of-range, or model-zero
/// entries are written back as zero.  This is cache hygiene only: the routine
/// never assigns a provider slot (`+0xB4`) or specializes a generic Building.
/// The pure predicate below is research metadata and is not used by the live
/// Qin simulation.
public enum OriginalMapObjectRegistrySanitization {
    public static let sanitizerAddress: UInt32 = 0x0053D630
    public static let mapRegistryGridAddress: UInt32 = 0x00FC3750
    public static let mapRegistryGridEndExclusiveAddress: UInt32 = 0x00FDCD70
    public static let mapRegistryGridEntryWidthBytes = 2
    public static let mapRegistryGridSide = 228
    public static let mapRegistryGridCellCount = mapRegistryGridSide * mapRegistryGridSide
    public static let liveObjectCountAddress: UInt32 = 0x00554C00
    public static let objectLookupAddress: UInt32 = 0x0047F1B0
    public static let modelWordOffset = 0x14
    public static let invalidEntryValue = 0

    /// Mirrors the branch that leaves one `DAT_00FC3750` short untouched.
    /// `modelWord` is `nil` when the live-object lookup is out of range.
    public static func retains(
        registryID: Int,
        liveObjectCount: Int,
        modelWord: Int?
    ) -> Bool {
        registryID > 0 && registryID < liveObjectCount && modelWord.map { $0 != 0 } == true
    }
}

/// Parser for the map-object stream preamble recovered from the canonical
/// executables.  The class tag is decoded only when the exact MFC header and
/// printable name are present; malformed or legacy streams return `nil`
/// rather than inventing a class identity.
public enum OriginalMapArchivePreambleCatalog {
    public static let schemaOffset = 0
    public static let objectSlotCountOffset = 2
    public static let firstClassDeclarationOffset = 6

    public static func parse(
        in decodedMapData: Data,
        archiveOffset: Int
    ) -> OriginalMapArchivePreamble? {
        guard archiveOffset >= 0,
              archiveOffset + firstClassDeclarationOffset <= decodedMapData.count
        else { return nil }

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

        guard archiveOffset + objectSlotCountOffset + 4 <= decodedMapData.count else {
            return nil
        }
        let schema = Int(uint16(at: archiveOffset + schemaOffset))
        let objectSlotCount = Int(uint32(at: archiveOffset + objectSlotCountOffset))

        let declarationOffset = archiveOffset + firstClassDeclarationOffset
        var className: String?
        if declarationOffset + OriginalMapArchiveClassCatalog.declarationHeaderLength
            <= decodedMapData.count,
           Array(decodedMapData[declarationOffset ..< declarationOffset + 4])
                == OriginalMapArchiveClassCatalog.declarationHeader,
           declarationOffset + 6 <= decodedMapData.count {
            let nameLength = Int(uint16(at: declarationOffset + 4))
            let nameStart = declarationOffset + 6
            let nameEnd = nameStart + nameLength
            guard (1...64).contains(nameLength), nameEnd <= decodedMapData.count else {
                return .init(
                    archiveOffset: archiveOffset,
                    archiveSchema: schema,
                    objectSlotCount: objectSlotCount
                )
            }
            let nameBytes = decodedMapData[nameStart..<nameEnd]
            if nameBytes.allSatisfy({ (0x20...0x7E).contains($0) }) {
                className = String(data: Data(nameBytes), encoding: .ascii)
            }
        }

        return .init(
            archiveOffset: archiveOffset,
            archiveSchema: schema,
            objectSlotCount: objectSlotCount,
            firstClassDeclarationOffset: className == nil ? nil : declarationOffset,
            firstClassName: className
        )
    }
}

/// One MFC class declaration embedded in an Emperor map archive.
///
/// The declaration is archive evidence only.  It identifies the class name,
/// the following serializer schema word, and the first base-building type
/// word observed in the first serialized record.  It does not construct an
/// object or imply that the class was registered in the live object vector.
public struct OriginalMapArchiveClassDeclaration: Sendable, Hashable, Codable {
    public let declarationOffset: Int
    public let className: String
    public let schemaOffset: Int
    public let formatVersion: Int
    public let firstTypeWord: UInt16

    public init(
        declarationOffset: Int,
        className: String,
        schemaOffset: Int,
        formatVersion: Int,
        firstTypeWord: UInt16
    ) {
        self.declarationOffset = declarationOffset
        self.className = className
        self.schemaOffset = schemaOffset
        self.formatVersion = formatVersion
        self.firstTypeWord = firstTypeWord
    }
}

/// Scanner for MFC `new class` declarations in the variable map archive.
///
/// The canonical declarations begin with `FF FF 00 00`, followed by a
/// little-endian name length and printable ASCII class name.  The schema word
/// follows the name, and the first base-building type word is 16 bytes after
/// the end of the class name (including the schema and preceding MFC fields).
/// The scan is explicitly bounded by the decoded archive range
/// before the trailing fixed grid; it is not a runtime class registry.
public enum OriginalMapArchiveClassCatalog {
    public static let declarationHeader: [UInt8] = [0xFF, 0xFF, 0x00, 0x00]
    public static let declarationHeaderLength = 6
    public static let firstTypeWordAfterName = 16

    public static func declarations(
        in decodedMapData: Data,
        archiveRange: Range<Int>
    ) -> [OriginalMapArchiveClassDeclaration] {
        guard archiveRange.lowerBound >= 0,
              archiveRange.upperBound <= decodedMapData.count,
              archiveRange.lowerBound < archiveRange.upperBound
        else { return [] }

        func uint16(at offset: Int) -> UInt16 {
            UInt16(decodedMapData[offset])
                | UInt16(decodedMapData[offset + 1]) << 8
        }

        var result: [OriginalMapArchiveClassDeclaration] = []
        var offset = archiveRange.lowerBound
        while offset + declarationHeaderLength <= archiveRange.upperBound {
            guard decodedMapData[offset] == declarationHeader[0],
                  decodedMapData[offset + 1] == declarationHeader[1],
                  decodedMapData[offset + 2] == declarationHeader[2],
                  decodedMapData[offset + 3] == declarationHeader[3]
            else {
                offset += 1
                continue
            }

            let nameLength = Int(uint16(at: offset + 4))
            guard (1...64).contains(nameLength) else {
                offset += 1
                continue
            }
            let nameStart = offset + declarationHeaderLength
            let nameEnd = nameStart + nameLength
            let typeWordOffset = nameEnd + firstTypeWordAfterName
            guard nameEnd <= archiveRange.upperBound,
                  typeWordOffset + 2 <= archiveRange.upperBound
            else {
                offset += 1
                continue
            }
            let nameBytes = decodedMapData[nameStart..<nameEnd]
            guard nameBytes.allSatisfy({ (0x20...0x7E).contains($0) }),
                  let className = String(data: nameBytes, encoding: .ascii)
            else {
                offset += 1
                continue
            }

            let schemaOffset = nameEnd
            result.append(.init(
                declarationOffset: offset,
                className: className,
                schemaOffset: schemaOffset,
                formatVersion: Int(uint16(at: schemaOffset)),
                firstTypeWord: uint16(at: typeWordOffset)
            ))
            offset = typeWordOffset + 2
        }
        return result
    }
}
