import Foundation

/// Runtime event identifiers used by the original Emperor executable.
///
/// Several values were reserved by the game and two pairs have the same
/// user-facing label. Keeping every raw value distinct is important because
/// campaign files store the runtime identifier rather than the editor label.
public enum CampaignEventKind: UInt8, CaseIterable, Sendable, Hashable, Codable {
    case freeEvent = 0
    case request = 1
    case invasion = 2
    case earthquake = 3
    case drought = 4
    case flood = 5
    case unused6 = 6
    case seaTradeProblem = 7
    case landTradeProblem = 8
    case wageIncrease = 9
    case wageDecrease = 10
    case unused11 = 11
    case unused12 = 12
    case unused13 = 13
    case demandIncrease = 14
    case demandDecrease = 15
    case priceIncrease = 16
    case priceDecrease = 17
    case sellerPriceIncrease = 18
    case sellerPriceDecrease = 19
    case favorIncrease = 20
    case favorDecrease = 21
    case cityStatusChange = 22
    case message = 23
    case supplyIncrease = 24
    case supplyDecrease = 25
    case gift = 26
    case unused27 = 27
    case unused28 = 28
    case tributeToPlayer = 29
    case tributeDemand = 30
    case cityMessage = 31
    case requestFulfillment = 32
    case demandRefusal = 33
    case strike = 34
    case unused35 = 35
    case unused36 = 36
    case unused37 = 37
    case unused38 = 38
    case heroArrives = 39
    case emissaryStatus40 = 40
    case spyStatus41 = 41
    case emissaryStatus42 = 42
    case spyStatus43 = 43
    case rivalArmyAway = 44

    public var displayName: String {
        switch self {
        case .freeEvent: "Free Event"
        case .request: "Request"
        case .invasion: "Invasion"
        case .earthquake: "Earthquake"
        case .drought: "Drought"
        case .flood: "Flood"
        case .unused6, .unused11, .unused12, .unused13, .unused27, .unused28,
             .unused35, .unused36, .unused37, .unused38: "Unused"
        case .seaTradeProblem: "Sea trade problem"
        case .landTradeProblem: "Land trade problem"
        case .wageIncrease: "Wage increase"
        case .wageDecrease: "Wage decrease"
        case .demandIncrease: "Demand increase"
        case .demandDecrease: "Demand decrease"
        case .priceIncrease: "Price increase"
        case .priceDecrease: "Price decrease"
        case .sellerPriceIncrease: "Seller price increase"
        case .sellerPriceDecrease: "Seller price decrease"
        case .favorIncrease: "Favor increase"
        case .favorDecrease: "Favor decrease"
        case .cityStatusChange: "City status change"
        case .message: "Message"
        case .supplyIncrease: "Supply increase"
        case .supplyDecrease: "Supply decrease"
        case .gift: "Gift"
        case .tributeToPlayer: "Tribute to Player"
        case .tributeDemand: "Tribute demand"
        case .cityMessage: "City message"
        case .requestFulfillment: "Request fulfillment"
        case .demandRefusal: "Demand refusal"
        case .strike: "Strike"
        case .heroArrives: "Hero arrives"
        case .emissaryStatus40, .emissaryStatus42: "Emissary status"
        case .spyStatus41, .spyStatus43: "Spy status"
        case .rivalArmyAway: "Rival army away"
        }
    }
}

/// The Campaign Creator serialized a four-word choice/range object in many
/// event fields. A non-negative `fixed` value wins; otherwise `lower...upper`
/// contains the randomizable bounds. `current` is the value selected at run time.
public struct CampaignEventRange: Sendable, Hashable, Codable {
    public let current: Int16
    public let fixed: Int16
    public let lower: Int16
    public let upper: Int16

    public var bounds: ClosedRange<Int>? {
        if fixed >= 0 {
            let value = Int(fixed)
            return value...value
        }
        guard lower >= 0, upper >= 0 else { return nil }
        let first = min(Int(lower), Int(upper))
        let last = max(Int(lower), Int(upper))
        return first...last
    }

    public var isFixed: Bool { fixed >= 0 }
}

public struct CampaignEventRecord: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let archiveVersion: UInt16
    public let kindRawValue: UInt8
    /// Zero-based month written by the Campaign Creator (0 = January).
    public let monthIndex: UInt8
    public let product: CampaignEventRange
    public let amount: CampaignEventRange
    public let year: CampaignEventRange
    public let cityFrom: CampaignEventRange
    public let secondarySelection: CampaignEventRange
    public let flags: UInt32
    public let timeAllowed: Int16
    public let statusChangeCode: UInt8
    public let rawMemory: Data

    public var kind: CampaignEventKind? { CampaignEventKind(rawValue: kindRawValue) }
    public var monthNumber: Int { Int(monthIndex) + 1 }
    public var triggerMode: CampaignEventTriggerMode {
        if flags & 0x0002_0000 != 0 { return .missionComplete }
        if flags & 0x0000_0002 != 0 { return .recurring }
        return .oneTime
    }
}

public struct CampaignMissionEventSet: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let events: [CampaignEventRecord]

    public init(id: Int, events: [CampaignEventRecord]) {
        self.id = id
        self.events = events
    }
}

public enum CampaignEventTriggerMode: String, Sendable, Hashable, Codable {
    case oneTime
    case recurring
    case missionComplete
}

/// The fixed event tables embedded in a decoded `.campaign`/`.pak` archive.
/// Original data is only read and expanded into the 268-byte runtime layout.
public struct CampaignEventArchive: Sendable, Hashable {
    public static let missionSlotCount = 10
    public static let recordsPerMission = 150
    public static let runtimeRecordByteCount = 268

    public let sectionOffset: Int
    public let archiveVersion: UInt16
    public let serializedRecordByteCount: Int
    public let missionSlotByteCount: Int
    public let missions: [CampaignMissionEventSet]

    public init(campaignURL: URL, missionCount: Int) throws {
        guard (0...Self.missionSlotCount).contains(missionCount) else {
            throw GameDataError.malformedFile("campaign event mission count \(missionCount)")
        }
        let decoded = try SierraChunkedFile(contentsOf: campaignURL).decodedData
        guard let layout = Self.detectLayout(in: decoded) else {
            throw GameDataError.malformedFile("campaign event tables")
        }

        var parsedMissions: [CampaignMissionEventSet] = []
        parsedMissions.reserveCapacity(missionCount)
        for missionIndex in 0..<missionCount {
            let slotOffset = layout.sectionOffset + missionIndex * layout.missionSlotByteCount
            var records: [CampaignEventRecord] = []
            records.reserveCapacity(Self.recordsPerMission)
            for recordIndex in 0..<Self.recordsPerMission {
                let offset = slotOffset + recordIndex * layout.serializedRecordByteCount
                records.append(try Self.parseRecord(
                    in: decoded,
                    at: offset,
                    expectedVersion: layout.archiveVersion
                ))
            }

            let prefixEnd = (1..<Self.recordsPerMission).first {
                records[$0].id != $0
            } ?? Self.recordsPerMission
            let activeRecords: [CampaignEventRecord]
            if prefixEnd == 1, records[0].kindRawValue == CampaignEventKind.freeEvent.rawValue {
                activeRecords = []
            } else {
                activeRecords = Array(records[..<prefixEnd])
            }
            parsedMissions.append(CampaignMissionEventSet(id: missionIndex, events: activeRecords))
        }

        sectionOffset = layout.sectionOffset
        archiveVersion = layout.archiveVersion
        serializedRecordByteCount = layout.serializedRecordByteCount
        missionSlotByteCount = layout.missionSlotByteCount
        missions = parsedMissions
    }

    private struct Layout {
        let archiveVersion: UInt16
        let serializedRecordByteCount: Int
        let missionSlotByteCount: Int
        let sectionOffset: Int
    }

    private static let layouts = [
        Layout(archiveVersion: 9, serializedRecordByteCount: 263, missionSlotByteCount: 40_935, sectionOffset: 0),
        Layout(archiveVersion: 8, serializedRecordByteCount: 255, missionSlotByteCount: 39_735, sectionOffset: 0)
    ]

    private static func detectLayout(in data: Data) -> Layout? {
        let searchEnd = min(0x10_000, data.count)
        for schema in layouts {
            let finalReadOffset = (missionSlotCount - 1) * schema.missionSlotByteCount
                + (recordsPerMission - 1) * schema.serializedRecordByteCount + 2
            guard finalReadOffset <= data.count else { continue }
            let latestBase = min(searchEnd - 1, data.count - finalReadOffset)
            guard latestBase >= 0 else { continue }

            for base in 0...latestBase {
                guard uint16LE(in: data, at: base) == schema.archiveVersion,
                      uint16LE(in: data, at: base + schema.serializedRecordByteCount) == schema.archiveVersion,
                      uint16LE(in: data, at: base + schema.missionSlotByteCount) == schema.archiveVersion else {
                    continue
                }
                var valid = true
                for missionIndex in 0..<missionSlotCount {
                    let slotOffset = base + missionIndex * schema.missionSlotByteCount
                    for recordIndex in 0..<recordsPerMission where
                        uint16LE(in: data, at: slotOffset + recordIndex * schema.serializedRecordByteCount) != schema.archiveVersion {
                        valid = false
                        break
                    }
                    if !valid { break }
                }
                if valid {
                    return Layout(
                        archiveVersion: schema.archiveVersion,
                        serializedRecordByteCount: schema.serializedRecordByteCount,
                        missionSlotByteCount: schema.missionSlotByteCount,
                        sectionOffset: base
                    )
                }
            }
        }
        return nil
    }

    private static func parseRecord(
        in data: Data,
        at offset: Int,
        expectedVersion: UInt16
    ) throws -> CampaignEventRecord {
        var archiveReader = BinaryReader(data: data, offset: offset)
        let version = try archiveReader.readUInt16LE()
        guard version == expectedVersion else {
            throw GameDataError.malformedFile("campaign event record version \(version)")
        }
        let payloadByteCount = version == 9 ? 261 : 253
        let payload = try archiveReader.readData(count: payloadByteCount)
        let memory = try expandRecordPayload(payload, version: version)

        return CampaignEventRecord(
            id: Int(int16LE(in: memory, at: 0)),
            archiveVersion: version,
            kindRawValue: memory[2],
            monthIndex: memory[3],
            product: eventRange(in: memory, at: 4),
            amount: eventRange(in: memory, at: 12),
            year: eventRange(in: memory, at: 20),
            cityFrom: eventRange(in: memory, at: 28),
            secondarySelection: eventRange(in: memory, at: 88),
            flags: uint32LE(in: memory, at: 40),
            timeAllowed: int16LE(in: memory, at: 44),
            statusChangeCode: memory[96],
            rawMemory: memory
        )
    }

    private static func expandRecordPayload(_ payload: Data, version: UInt16) throws -> Data {
        var segments: [(offset: Int, count: Int)] = [
            (0, 2), (2, 1), (3, 1), (4, 8), (12, 8), (20, 8), (28, 8),
            (36, 2), (38, 2), (40, 4), (44, 2), (46, 2), (48, 2), (50, 1), (51, 1),
            (52, 2), (54, 1), (55, 1)
        ]
        segments.append(contentsOf: stride(from: 56, through: 84, by: 2).map { (offset: $0, count: 2) })
        let commonTail: [(offset: Int, count: Int)] = [
            (86, 1), (87, 1), (88, 8),
            (96, 1), (97, 1), (98, 1), (99, 1), (100, 2), (102, 2), (104, 2),
            (106, 1), (107, 1), (108, 1), (109, 1), (110, 1), (111, 1), (112, 1),
            (114, 2), (116, 1), (117, 1), (118, 1), (119, 1), (120, 1), (121, 1),
            (124, 4), (128, 4), (132, 1), (133, 1), (136, 4), (140, 4), (144, 4),
            (148, 22), (170, 22), (214, 44), (192, 22)
        ]
        segments.append(contentsOf: commonTail)
        if version >= 9 {
            let version9Tail: [(offset: Int, count: Int)] = [(260, 4), (264, 4)]
            segments.append(contentsOf: version9Tail)
        }

        guard segments.reduce(0, { $0 + $1.count }) == payload.count else {
            throw GameDataError.malformedFile("campaign event payload v\(version)")
        }
        var memory = Data(repeating: 0, count: runtimeRecordByteCount)
        var payloadOffset = 0
        for segment in segments {
            memory.replaceSubrange(
                segment.offset..<(segment.offset + segment.count),
                with: payload[payloadOffset..<(payloadOffset + segment.count)]
            )
            payloadOffset += segment.count
        }
        return memory
    }

    private static func eventRange(in data: Data, at offset: Int) -> CampaignEventRange {
        CampaignEventRange(
            current: int16LE(in: data, at: offset),
            fixed: int16LE(in: data, at: offset + 2),
            lower: int16LE(in: data, at: offset + 4),
            upper: int16LE(in: data, at: offset + 6)
        )
    }

    private static func uint16LE(in data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func int16LE(in data: Data, at offset: Int) -> Int16 {
        Int16(bitPattern: uint16LE(in: data, at: offset))
    }

    private static func uint32LE(in data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
