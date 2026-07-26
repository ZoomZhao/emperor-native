import Foundation

/// Campaign Creator settings that define a mission's original starting state.
///
/// Years before the common era are stored as negative values by the original
/// game. Building permissions use the Campaign Creator's compact menu IDs;
/// resource permissions use the 29 commodity IDs from `Trade.txt`.
public struct CampaignMissionStartSettings: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let startYear: Int
    public let startMonth: Int
    public let initialFunds: Int
    public let allowedBuildingMenuIDs: [Int]
    public let allowedResourceCommodityIDs: [Int]

    public var requiresInheritedTreasury: Bool { initialFunds == 0 }

    public init(
        id: Int,
        startYear: Int,
        startMonth: Int,
        initialFunds: Int,
        allowedBuildingMenuIDs: [Int],
        allowedResourceCommodityIDs: [Int]
    ) {
        self.id = id
        self.startYear = startYear
        self.startMonth = min(max(startMonth, 1), 12)
        self.initialFunds = max(0, initialFunds)
        self.allowedBuildingMenuIDs = allowedBuildingMenuIDs.sorted()
        self.allowedResourceCommodityIDs = allowedResourceCommodityIDs.sorted()
    }

    /// Applies the original Campaign Creator difficulty rule. A continuation
    /// mission with zero authored funds inherits the last treasury for that
    /// city; zero is retained when no prior city state is available.
    public func startingTreasury(
        difficulty: GameDifficulty,
        inheritedTreasury: Int? = nil
    ) -> Int {
        if requiresInheritedTreasury {
            return max(0, inheritedTreasury ?? 0)
        }
        switch difficulty {
        case .veryEasy:
            return initialFunds * 3 / 2
        case .veryHard:
            return initialFunds * 4 / 5
        case .easy, .normal, .hard:
            return initialFunds
        }
    }
}

/// Decodes the ten fixed mission-setting slots written by the original
/// Campaign Creator. Two shipping serializer versions use different record
/// sizes, so the table is detected from its repeated date/funds signature
/// instead of assuming one hard-coded absolute offset.
public struct CampaignMissionSettingsArchive: Sendable, Hashable {
    public static let maximumMissionCount = 10
    public static let allowedBuildingMenuCount = 57
    public static let allowedResourceCommodityCount = 29

    private static let allowedBuildingOffsetFromYear = 0x373
    private static let allowedResourceOffsetFromYear = 0x55D

    public let yearTableOffset: Int
    public let missionRecordStride: Int
    public let missions: [CampaignMissionStartSettings]

    public init(campaignURL: URL, missionCount: Int) throws {
        guard (1...Self.maximumMissionCount).contains(missionCount) else {
            throw GameDataError.malformedFile("campaign mission settings count")
        }
        let container = try SierraChunkedFile(contentsOf: campaignURL)
        let decoded = container.decodedData
        let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
        guard let layout = Self.detectLayout(in: decoded, metadataEnd: metadataEnd, missionCount: missionCount) else {
            throw GameDataError.malformedFile("campaign mission settings table")
        }

        var parsed: [CampaignMissionStartSettings] = []
        parsed.reserveCapacity(missionCount)
        for missionID in 0..<missionCount {
            let yearOffset = layout.yearOffset + missionID * layout.stride
            let startMonth = Int(Self.uint16(in: decoded, at: yearOffset - 2))
            let startYear = Int(Int16(bitPattern: Self.uint16(in: decoded, at: yearOffset)))
            let initialFunds = Int(Self.uint32(in: decoded, at: yearOffset + 16))
            let allowedBuildings = Self.allowedIndexedUInt16Values(
                in: decoded,
                at: yearOffset + Self.allowedBuildingOffsetFromYear,
                count: Self.allowedBuildingMenuCount
            )
            let allowedResources = Self.allowedIndexedUInt8Values(
                in: decoded,
                at: yearOffset + Self.allowedResourceOffsetFromYear,
                count: Self.allowedResourceCommodityCount
            )
            parsed.append(CampaignMissionStartSettings(
                id: missionID,
                startYear: startYear,
                startMonth: startMonth,
                initialFunds: initialFunds,
                allowedBuildingMenuIDs: allowedBuildings,
                allowedResourceCommodityIDs: allowedResources
            ))
        }

        yearTableOffset = layout.yearOffset
        missionRecordStride = layout.stride
        missions = parsed
    }

    private struct RecordCandidate {
        let yearOffset: Int
    }

    private struct LayoutCandidate {
        let yearOffset: Int
        let stride: Int
        let score: Int
    }

    private static func detectLayout(
        in data: Data,
        metadataEnd: Int,
        missionCount: Int
    ) -> LayoutCandidate? {
        let upperBound = min(metadataEnd, data.count)
        guard upperBound > 24 else { return nil }
        var candidateYearOffsets = Set<Int>()
        for eraMarker in [UInt8(3), UInt8(4)] {
            let signature = Data([3, 0, eraMarker, 0])
            var searchStart = 0
            while searchStart + signature.count <= upperBound,
                  let match = data.range(of: signature, in: searchStart..<upperBound) {
                let yearOffset = match.lowerBound - 12
                if isDateAndFundsRecord(in: data, at: yearOffset) {
                    candidateYearOffsets.insert(yearOffset)
                }
                searchStart = match.lowerBound + 1
            }
        }
        let candidates = candidateYearOffsets.sorted().map(RecordCandidate.init(yearOffset:))
        let candidateOffsets = Set(candidates.map(\.yearOffset))
        var layouts: [LayoutCandidate] = []

        for first in candidates where (0x800..<0x4000).contains(first.yearOffset) {
            for second in candidates where second.yearOffset > first.yearOffset {
                let stride = second.yearOffset - first.yearOffset
                guard (30_000...50_000).contains(stride) else { continue }
                guard (0..<Self.maximumMissionCount).allSatisfy({
                    candidateOffsets.contains(first.yearOffset + $0 * stride)
                }) else { continue }
                guard (0..<missionCount).allSatisfy({ missionID in
                    validatePermissionArrays(
                        in: data,
                        at: first.yearOffset + missionID * stride
                    )
                }) else { continue }

                let score = 10_000
                    - abs(first.yearOffset - 0x1250)
                    - abs(stride - 0x9FE7) / 16
                layouts.append(LayoutCandidate(
                    yearOffset: first.yearOffset,
                    stride: stride,
                    score: score
                ))
            }
        }
        return layouts.max { lhs, rhs in
            lhs.score == rhs.score ? lhs.yearOffset > rhs.yearOffset : lhs.score < rhs.score
        }
    }

    private static func isDateAndFundsRecord(in data: Data, at yearOffset: Int) -> Bool {
        guard yearOffset >= 2, yearOffset + 20 <= data.count else { return false }
        let month = Int(uint16(in: data, at: yearOffset - 2))
        let year = Int(Int16(bitPattern: uint16(in: data, at: yearOffset)))
        let schemaMarker = uint16(in: data, at: yearOffset + 12)
        let eraMarker = uint16(in: data, at: yearOffset + 14)
        let funds = uint32(in: data, at: yearOffset + 16)
        return (1...12).contains(month)
            && (-4_000...4_000).contains(year)
            && year != 0
            && schemaMarker == 3
            && (eraMarker == 3 || eraMarker == 4)
            && funds <= 10_000_000
            && funds % 100 == 0
    }

    private static func validatePermissionArrays(in data: Data, at yearOffset: Int) -> Bool {
        let buildingOffset = yearOffset + allowedBuildingOffsetFromYear
        let resourceOffset = yearOffset + allowedResourceOffsetFromYear
        guard buildingOffset + allowedBuildingMenuCount * 2 <= data.count,
              resourceOffset + allowedResourceCommodityCount <= data.count else { return false }
        let buildingsAreIndexed = (0..<allowedBuildingMenuCount).allSatisfy { index in
            let value = Int(uint16(in: data, at: buildingOffset + index * 2))
            return value == 0 || value == index
        }
        let resourcesAreIndexed = (0..<allowedResourceCommodityCount).allSatisfy { index in
            let value = Int(data[resourceOffset + index])
            return value == 0 || value == index
        }
        return buildingsAreIndexed && resourcesAreIndexed
    }

    private static func allowedIndexedUInt16Values(
        in data: Data,
        at offset: Int,
        count: Int
    ) -> [Int] {
        (1..<count).compactMap { index in
            Int(uint16(in: data, at: offset + index * 2)) == index ? index : nil
        }
    }

    private static func allowedIndexedUInt8Values(
        in data: Data,
        at offset: Int,
        count: Int
    ) -> [Int] {
        (1..<count).compactMap { index in
            Int(data[offset + index]) == index ? index : nil
        }
    }

    private static func uint16(in data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func uint32(in data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
