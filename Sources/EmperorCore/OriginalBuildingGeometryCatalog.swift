import Foundation

/// File-backed geometry tables used by the original placement-time feng-shui
/// producer (`FUN_0042B250 @ 0x42B250`).  This is an evidence catalog only:
/// it does not register objects, write occupancy, or apply custom callbacks.
public enum OriginalBuildingGeometryCatalog {
    public static let executableModelCount = 0x10D
    public static let executableRowStride = 228

    /// First DWORD of `DAT_00823598[modelID]`.  Values are geometry-group
    /// indices, not a guessed semantic building category.
    private static let geometryGroups: [Int] = [
        0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4,
        4, 4, 2, 2, 2, 2, 1, 0, 0, 0, 1, 1, 1, 0, 0, 2,
        0, 2, 0, 2, 2, 3, 2, 3, 3, 3, 2, 2, 2, 2, 2, 2,
        3, 3, 0, 2, 2, 5, 3, 0, 4, 2, 4, 1, 1, 1, 2, 0,
        2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 3, 3, 4, 2,
        3, 3, 1, 1, 1, 2, 1, 2, 3, 4, 5, 1, 2, 2, 1, 2,
        4, 1, 1, 2, 0, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        2, 3, 1, 1, 1, 1, 1, 1, 0, 0, 1, 2, 0, 0, 0, 2,
        2, 2, 2, 2, 3, 3, 2, 2, 4, 2, 4, 3, 2, 2, 0, 2,
        2, 2, 2, 0, 0, 0, 0, 1, 1, 4, 0, 2, 2, 2, 2, 2,
        0, 0, 0, 1, 1, 1, 2, 2, 2, 1, 1, 2, 3, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    ]

    /// The first 63 signed entries of `DAT_00822D48`.  Four rotation banks
    /// begin at indices 0, 9, 18, and 27; the largest supported table group
    /// consumes 36 entries, so this prefix is sufficient for every group
    /// selected by `DAT_00823598`.
    private static let relativeLinearOffsets: [Int] = [
        0, 228, 1, 229, 456, 2, 457, 230, 458,
        684, 3, 685, 231, 686, 459, 687, 912, 4,
        913, 232, 914, 460, 915, 688, 916, 1140, 5,
        1141, 233, 1142, 461, 1143, 689, 1144, 917, 1145,
        0, -1, 228, 227, -2, 456, 226, 455, 454, -3,
        684, 225, 683, 453, 682, 681, -4, 912, 224,
        911, 452, 910, 680, 909, 908, -5, 1140
    ]

    /// Models routed through `FUN_0042C930 @ 0x42C930` instead of the
    /// ordinary `DAT_00823598` geometry-offset branch in
    /// `FUN_0042B250 @ 0x42B250`.  The constructor/vtable identities are
    /// executable evidence only; the callback point enumeration and its
    /// category semantics are not recovered, so these entries must remain
    /// outside the generic placement sampler.
    public struct CustomSamplerDescriptor: Sendable, Hashable, Codable {
        public let buildingID: Int
        public let allocationBytes: Int
        public let constructorAddress: Int
        public let vtableAddress: Int
        /// Constructor selector stored by the source for the fort family.
        /// Other families leave this nil or pass zero.
        public let selector: Int?

        public init(
            buildingID: Int,
            allocationBytes: Int,
            constructorAddress: Int,
            vtableAddress: Int,
            selector: Int? = nil
        ) {
            self.buildingID = buildingID
            self.allocationBytes = allocationBytes
            self.constructorAddress = constructorAddress
            self.vtableAddress = vtableAddress
            self.selector = selector
        }
    }

    /// One raw custom-sampler vtable slot. The address identifies the
    /// executable callback only; it is not a semantic label for the slot.
    public struct CustomSamplerCallbackDescriptor: Sendable, Hashable, Codable {
        public let slotOffset: Int
        public let functionAddress: Int

        public init(slotOffset: Int, functionAddress: Int) {
            self.slotOffset = slotOffset
            self.functionAddress = functionAddress
        }
    }

    /// A custom callback's raw point table when its data records have been
    /// recovered. `FUN_0042B820` consumes the first two signed words of each
    /// PE record; `FUN_0042C750` also branches on the remaining raw words.
    public struct CustomGeometryDescriptor: Sendable, Hashable, Codable {
        /// The four dwords stored for one callback point. `flags` and
        /// `auxiliary` remain raw PE values; their player-facing meaning is
        /// not recovered.
        public struct PointRecord: Sendable, Hashable, Codable {
            public let point: GridPoint
            public let flags: UInt32
            public let auxiliary: Int

            public init(point: GridPoint, flags: UInt32, auxiliary: Int) {
                self.point = point
                self.flags = flags
                self.auxiliary = auxiliary
            }
        }

        public struct OrientationBank: Sendable, Hashable, Codable {
            public let width: Int
            public let height: Int

            public init(width: Int, height: Int) {
                self.width = width
                self.height = height
            }

            public var pointCount: Int { width * height }
        }

        public let buildingID: Int
        public let dataAddress: Int
        public let pointsPerBank: Int
        public let banks: [OrientationBank]
        public let pointRecordsByBank: [[PointRecord]]

        public init(
            buildingID: Int,
            dataAddress: Int,
            pointsPerBank: Int,
            banks: [OrientationBank],
            pointRecordsByBank: [[PointRecord]] = []
        ) {
            self.buildingID = buildingID
            self.dataAddress = dataAddress
            self.pointsPerBank = pointsPerBank
            self.banks = banks
            self.pointRecordsByBank = pointRecordsByBank
        }

        /// Returns the raw `(x,y)` point pairs in the source's bank order.
        /// Sign/orientation transforms are applied later by `FUN_0042B820`.
        public func points(forOrientationBank bank: Int) -> [GridPoint]? {
            guard banks.indices.contains(bank),
                  banks[bank].pointCount == pointsPerBank else { return nil }
            if pointRecordsByBank.indices.contains(bank),
               pointRecordsByBank[bank].count == pointsPerBank {
                return pointRecordsByBank[bank].map(\.point)
            }
            let dimensions = banks[bank]
            return (0..<dimensions.height).flatMap { y in
                (0..<dimensions.width).map { x in
                    GridPoint(x: x, y: y)
                }
            }
        }

        /// Returns raw callback records in the executable's stored order.
        /// The transposed market banks are column-major in the PE data; that
        /// order is observable to callbacks and is intentionally preserved.
        public func pointRecords(forOrientationBank bank: Int) -> [PointRecord]? {
            guard banks.indices.contains(bank),
                  banks[bank].pointCount == pointsPerBank,
                  pointRecordsByBank.indices.contains(bank),
                  pointRecordsByBank[bank].count == pointsPerBank else { return nil }
            return pointRecordsByBank[bank]
        }

        /// Applies the exact signed-offset transform from
        /// `FUN_0042B820 @ 0x42B820` to one recovered custom bank.  The
        /// bank selector (`DAT_008C7628`) and map rotation
        /// (`DAT_0101D0D0`) are separate source inputs; callers must provide
        /// the already-resolved bank rather than deriving it from a Native
        /// building orientation.  Values other than the four authored
        /// rotations follow the executable's default `(+x,+y)` branch.
        public func transformedPoints(
            forOrientationBank bank: Int,
            mapRotation: Int
        ) -> [GridPoint]? {
            points(forOrientationBank: bank)?.map { point in
                switch mapRotation {
                case 2:
                    return GridPoint(x: -point.x, y: point.y)
                case 4:
                    return GridPoint(x: -point.x, y: -point.y)
                case 6:
                    return GridPoint(x: point.x, y: -point.y)
                default:
                    return point
                }
            }
        }
    }

    private static func pointRecords(
        width: Int,
        height: Int,
        columnMajor: Bool,
        flagsByRowMajorCoordinate: [UInt32],
        auxiliaryByRowMajorCoordinate: [Int]
    ) -> [CustomGeometryDescriptor.PointRecord] {
        precondition(flagsByRowMajorCoordinate.count == width * height)
        precondition(auxiliaryByRowMajorCoordinate.count == width * height)
        let coordinates: [GridPoint]
        if columnMajor {
            coordinates = (0..<width).flatMap { x in
                (0..<height).map { y in GridPoint(x: x, y: y) }
            }
        } else {
            coordinates = (0..<height).flatMap { y in
                (0..<width).map { x in GridPoint(x: x, y: y) }
            }
        }
        return coordinates.map { point in
            let index = point.y * width + point.x
            return .init(
                point: point,
                flags: flagsByRowMajorCoordinate[index],
                auxiliary: auxiliaryByRowMajorCoordinate[index]
            )
        }
    }

    private static let commonMarketFlags: [UInt32] = [
        2, 2, 2, 2,
        2, 2, 2, 2,
        4, 4, 4, 4,
        1, 1, 1, 1,
        4, 4, 4, 4,
        2, 2, 2, 2,
        2, 2, 2, 2
    ]

    private static let commonMarketAuxiliary: [Int] = [
        1, 0, 1, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        1, 0, 1, 0,
        0, 0, 0, 0
    ]

    private static let grandMarketFlags: [UInt32] = [
        2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2,
        4, 4, 4, 4, 4, 4,
        1, 1, 1, 1, 1, 1,
        4, 4, 4, 4, 4, 4,
        2, 2, 2, 2, 2, 2,
        2, 2, 2, 2, 2, 2
    ]

    private static let grandMarketBank0Auxiliary: [Int] = [
        0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
        112, 113, 130, 131, 114, 115,
        116, 117, 132, 133, 118, 119,
        120, 121, 134, 135, 122, 123,
        0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0
    ]

    private static let grandMarketBank1Auxiliary: [Int] = [
        0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0,
        103, 109, 127, 124, 106, 100, 0,
        104, 110, 128, 125, 107, 101, 0,
        105, 111, 129, 126, 108, 102, 0,
        0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0
    ]

    private static let customGeometry: [Int: CustomGeometryDescriptor] = [
        // FUN_0042CD20 returns 0x008574A8; the two 28-record banks are
        // 4×7 and 7×4.  FUN_0042CD50 masks DAT_008C7628 to these two banks.
        59: .init(
            buildingID: 59,
            dataAddress: 0x8574A8,
            pointsPerBank: 28,
            banks: [.init(width: 4, height: 7), .init(width: 7, height: 4)],
            pointRecordsByBank: [
                pointRecords(
                    width: 4,
                    height: 7,
                    columnMajor: false,
                    flagsByRowMajorCoordinate: commonMarketFlags,
                    auxiliaryByRowMajorCoordinate: commonMarketAuxiliary
                ),
                pointRecords(
                    width: 7,
                    height: 4,
                    columnMajor: true,
                    flagsByRowMajorCoordinate: [
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2
                    ],
                    auxiliaryByRowMajorCoordinate: [
                        1, 0, 0, 0, 0, 1, 0,
                        0, 0, 0, 0, 0, 0, 0,
                        1, 0, 0, 0, 0, 1, 0,
                        0, 0, 0, 0, 0, 0, 0
                    ]
                )
            ]
        ),
        // FUN_0042CDB0 returns 0x00857828; the two 42-record banks are
        // 6×7 and 7×6.  The second bank begins immediately after bank zero.
        60: .init(
            buildingID: 60,
            dataAddress: 0x857828,
            pointsPerBank: 42,
            banks: [.init(width: 6, height: 7), .init(width: 7, height: 6)],
            pointRecordsByBank: [
                pointRecords(
                    width: 6,
                    height: 7,
                    columnMajor: false,
                    flagsByRowMajorCoordinate: grandMarketFlags,
                    auxiliaryByRowMajorCoordinate: grandMarketBank0Auxiliary
                ),
                pointRecords(
                    width: 7,
                    height: 6,
                    columnMajor: true,
                    flagsByRowMajorCoordinate: [
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2,
                        2, 2, 4, 1, 4, 2, 2
                    ],
                    auxiliaryByRowMajorCoordinate: [
                        0, 0, 103, 104, 105, 0, 0,
                        0, 0, 109, 110, 111, 0, 0,
                        0, 0, 127, 128, 129, 0, 0,
                        0, 0, 124, 125, 126, 0, 0,
                        0, 0, 106, 107, 108, 0, 0,
                        0, 0, 100, 101, 102, 0, 0
                    ]
                )
            ]
        )
    ]

    private static let customSamplers: [Int: CustomSamplerDescriptor] = [
        // Unoccupied elite: FUN_0042C930 case 0x0B.
        11: .init(
            buildingID: 11,
            allocationBytes: 0x18,
            constructorAddress: 0x42CDF0,
            vtableAddress: 0x7AB8F0,
            selector: 0
        ),
        // Common/grand market square: cases 0x3B/0x3C.
        59: .init(
            buildingID: 59,
            allocationBytes: 0x14,
            constructorAddress: 0x42CCD0,
            vtableAddress: 0x7AB800
        ),
        60: .init(
            buildingID: 60,
            allocationBytes: 0x14,
            constructorAddress: 0x42CD50,
            vtableAddress: 0x7AB878
        ),
        // Palace and administrative city: cases 0x6E/0xD1.
        110: .init(
            buildingID: 110,
            allocationBytes: 0x18,
            constructorAddress: 0x42CED0,
            vtableAddress: 0x7AB9C0,
            selector: 0
        ),
        209: .init(
            buildingID: 209,
            allocationBytes: 0x18,
            constructorAddress: 0x42CE60,
            vtableAddress: 0x7AB95C,
            selector: 0
        ),
        // City gate and the five fort variants.  The fort constructor is
        // shared; its selector is the exact switch value in FUN_004EF240.
        130: .init(
            buildingID: 130,
            allocationBytes: 0x18,
            constructorAddress: 0x4F8EA0,
            vtableAddress: 0x7B4180,
            selector: -1
        ),
        220: .init(
            buildingID: 220,
            allocationBytes: 0x18,
            constructorAddress: 0x4EF240,
            vtableAddress: 0x7B2BF0,
            selector: 3
        ),
        221: .init(
            buildingID: 221,
            allocationBytes: 0x18,
            constructorAddress: 0x4EF240,
            vtableAddress: 0x7B2BF0,
            selector: 0
        ),
        223: .init(
            buildingID: 223,
            allocationBytes: 0x18,
            constructorAddress: 0x4EF240,
            vtableAddress: 0x7B2BF0,
            selector: 2
        ),
        224: .init(
            buildingID: 224,
            allocationBytes: 0x18,
            constructorAddress: 0x4EF240,
            vtableAddress: 0x7B2BF0,
            selector: 1
        ),
        225: .init(
            buildingID: 225,
            allocationBytes: 0x18,
            constructorAddress: 0x4EF240,
            vtableAddress: 0x7B2BF0,
            selector: 4
        )
    ]

    private static let marketCallbackSlots: [CustomSamplerCallbackDescriptor] = [
        .init(slotOffset: 0x28, functionAddress: 0x416B80),
        .init(slotOffset: 0x30, functionAddress: 0x42A210),
        .init(slotOffset: 0x34, functionAddress: 0x66EFA0),
        .init(slotOffset: 0x38, functionAddress: 0x42CCC0),
        .init(slotOffset: 0x3C, functionAddress: 0x4FA410),
        .init(slotOffset: 0x40, functionAddress: 0x4E1C20),
        .init(slotOffset: 0x48, functionAddress: 0x416A50),
        .init(slotOffset: 0x4C, functionAddress: 0x42C100),
        .init(slotOffset: 0x50, functionAddress: 0x42C750),
        .init(slotOffset: 0x5C, functionAddress: 0x42C710)
    ]

    public static func geometryGroup(forBuildingID buildingID: Int) -> Int? {
        guard geometryGroups.indices.contains(buildingID) else { return nil }
        return geometryGroups[buildingID]
    }

    /// Returns the source custom-sampler dispatch for a model, if one exists.
    /// A non-nil result is a reason for callers to fail closed until the
    /// corresponding callback's point enumeration and map/object effects are
    /// independently recovered.
    public static func customSampler(
        forBuildingID buildingID: Int
    ) -> CustomSamplerDescriptor? {
        customSamplers[buildingID]
    }

    /// Returns the recovered Common/Grand Market callback slots. Both market
    /// vtables share these addresses in the canonical EN and CH PEs.
    public static func customSamplerCallbackSlots(
        forBuildingID buildingID: Int
    ) -> [CustomSamplerCallbackDescriptor]? {
        guard buildingID == 59 || buildingID == 60 else { return nil }
        return marketCallbackSlots
    }

    /// Returns a recovered custom point table for the model, if the PE data
    /// records and both orientation banks have been decoded.  Other custom
    /// models remain unsupported until their callback data are recovered.
    public static func customGeometry(
        forBuildingID buildingID: Int
    ) -> CustomGeometryDescriptor? {
        customGeometry[buildingID]
    }

    public static func footprint(forBuildingID buildingID: Int) -> BuildingFootprint? {
        guard let group = geometryGroup(forBuildingID: buildingID), (1...6).contains(group)
        else { return nil }
        return BuildingFootprint(width: group, height: group)
    }

    /// Returns the exact signed map-relative linear offsets consumed by the
    /// non-custom branch of `FUN_0042B250`.
    public static func relativeLinearOffsets(
        forBuildingID buildingID: Int,
        mapRotation: Int
    ) -> [Int]? {
        guard let group = geometryGroup(forBuildingID: buildingID), (1...6).contains(group)
        else { return nil }
        let rotationBank = ((mapRotation & 7) / 2) * 9
        let count = group * group
        guard rotationBank + count <= relativeLinearOffsets.count else { return nil }
        return Array(relativeLinearOffsets[rotationBank ..< rotationBank + count])
    }

}

/// Bank-order portion of the custom placement search in
/// `FUN_0042C100 @ 0x42C100`.
///
/// The executable chooses an initial bank from the persisted global selector
/// (`DAT_008C7628`) when the placement-mode argument is zero.  Otherwise a
/// separate global gate (`DAT_00C05810`) starts at bank `1 % bankCount`, and
/// the default starts at bank zero.  It then tests each bank exactly once in
/// wrapping order.  The per-bank callback/occupancy predicates are not
/// represented here; callers must supply independently recovered acceptance
/// results rather than treating this helper as a live placement bridge.
public enum OriginalCustomOrientationBankSearch {
    public static let sourceAddress: UInt32 = 0x0042C100

    /// Returns the exact bank visitation order for the recovered pre-search
    /// state. `nil` represents the source's unsupported zero/negative bank
    /// count boundary rather than attempting a modulo-by-zero fallback.
    public static func searchOrder(
        bankCount: Int,
        persistedBank: Int?,
        placementModeIsZero: Bool,
        alternateOrientationEnabled: Bool
    ) -> [Int]? {
        guard bankCount > 0 else { return nil }

        let start: Int
        if placementModeIsZero,
           let persistedBank,
           (0..<bankCount).contains(persistedBank) {
            start = persistedBank
        } else if alternateOrientationEnabled {
            start = 1 % bankCount
        } else {
            start = 0
        }

        return (0..<bankCount).map { (start + $0) % bankCount }
    }

    /// Returns the first accepted bank in the source's visitation order.
    /// Acceptance is intentionally caller-supplied: `FUN_0042C100` delegates
    /// that decision to vtable callbacks and the dynamic occupancy arrays,
    /// whose Native projection remains unresolved.
    public static func firstAcceptedBank(
        bankCount: Int,
        persistedBank: Int?,
        placementModeIsZero: Bool,
        alternateOrientationEnabled: Bool,
        acceptedBanks: [Bool]
    ) -> Int? {
        guard acceptedBanks.count == bankCount,
              let order = searchOrder(
                  bankCount: bankCount,
                  persistedBank: persistedBank,
                  placementModeIsZero: placementModeIsZero,
                  alternateOrientationEnabled: alternateOrientationEnabled
              ) else { return nil }
        return order.first { acceptedBanks[$0] }
    }

    /// Returns the exact fallback point order used after every orientation
    /// bank fails. `FUN_0042C100` scans the outer Y coordinate from
    /// `center.y + 5` down through `center.y - 5`, and scans X in the same
    /// descending order for each Y. The `+0x4C` callback decides whether a
    /// point is accepted and may mutate the source object; this helper only
    /// exposes the deterministic candidate order and therefore does not
    /// enable a live placement path.
    public static func fallbackCandidateOrder(center: GridPoint) -> [GridPoint] {
        var candidates: [GridPoint] = []
        candidates.reserveCapacity(121)
        for y in stride(from: center.y + 5, through: center.y - 5, by: -1) {
            for x in stride(from: center.x + 5, through: center.x - 5, by: -1) {
                candidates.append(GridPoint(x: x, y: y))
            }
        }
        return candidates
    }

    /// Returns the first fallback point accepted by a caller-supplied
    /// callback trace. The array must contain one result per point from
    /// `fallbackCandidateOrder`; a mismatched trace fails closed.
    public static func firstAcceptedFallbackCandidate(
        center: GridPoint,
        acceptedCandidates: [Bool]
    ) -> GridPoint? {
        guard acceptedCandidates.count == 121 else { return nil }
        guard let index = acceptedCandidates.firstIndex(where: { $0 }) else {
            return nil
        }
        return fallbackCandidateOrder(center: center)[index]
    }
}
