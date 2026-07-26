import Foundation

public struct CampaignMission: Identifiable, Sendable, Hashable {
    public let id: Int
    public let sequenceNumber: Int
    public let title: String
    public let isEnabled: Bool
    public let primaryWorldObjectID: Int32
    public let prerequisiteMissionIndex: Int32
    public let secondaryWorldObjectID: Int32
}

public struct CampaignArchive: Identifiable, Sendable, Hashable {
    public static let titleOffset = 0x20
    public static let titleByteCount = 64
    public static let descriptionOffset = 0x60
    public static let descriptionByteCount = 1_024
    public static let missionCountOffset = 0x464
    public static let missionTableOffset = 0x468
    public static let missionRecordByteCount = 356
    public static let missionTitleOffset = 93
    public static let missionTitleByteCount = 256

    public let url: URL
    public let title: String
    public let campaignDescription: String
    public let missions: [CampaignMission]
    public let detectedMissionTableOffset: Int
    public let containerChunkCount: Int
    public let decodedByteCount: Int
    public var id: URL { url }

    public init(url: URL) throws {
        let container = try SierraChunkedFile(contentsOf: url)
        let decoded = container.decodedData
        let reader = BinaryReader(data: decoded)
        guard let layout = Self.detectMissionLayout(in: decoded, reader: reader) else {
            throw GameDataError.malformedFile("campaign mission table")
        }
        guard var parsedTitle = Self.longestPrintableRun(
            in: decoded,
            range: 0x18..<Self.descriptionOffset
        ) else {
            throw GameDataError.malformedFile("campaign title")
        }
        let parsedDescription = Self.longestPrintableRun(
            in: decoded,
            range: 0x5c..<layout.countOffset
        ) ?? ""

        var parsedMissions: [CampaignMission] = []
        parsedMissions.reserveCapacity(layout.count)
        for index in 0..<layout.count {
            let offset = layout.tableOffset + index * Self.missionRecordByteCount
            let enabled = try reader.uint32LE(at: offset) != 0
            let primary = Int32(bitPattern: try reader.uint32LE(at: offset + 8))
            let sequence = Int(try reader.uint32LE(at: offset + 12))
            let prerequisite = Int32(bitPattern: try reader.uint32LE(at: offset + 16))
            let secondary = Int32(bitPattern: try reader.uint32LE(at: offset + 20))
            guard let missionTitle = reader.nullTerminatedString(
                at: offset + Self.missionTitleOffset,
                maximumLength: Self.missionTitleByteCount
            ), !missionTitle.isEmpty else {
                throw GameDataError.malformedFile("campaign mission title #\(index)")
            }
            parsedMissions.append(CampaignMission(
                id: index,
                sequenceNumber: sequence,
                title: missionTitle,
                isEnabled: enabled,
                primaryWorldObjectID: primary,
                prerequisiteMissionIndex: prerequisite,
                secondaryWorldObjectID: secondary
            ))
        }

        // Some later Campaign Creator builds left the first title byte just outside
        // the nominal 64-byte field. For single-mission campaigns, the intact mission
        // title is a safe recovery when it contains the truncated campaign title.
        if let missionTitle = parsedMissions.first?.title,
           missionTitle.count > parsedTitle.count,
           missionTitle.hasSuffix(parsedTitle) {
            parsedTitle = missionTitle
        }
        if parsedTitle.hasPrefix("he ") {
            parsedTitle = "T" + parsedTitle
        }

        self.url = url
        title = parsedTitle
        campaignDescription = parsedDescription
        missions = parsedMissions
        detectedMissionTableOffset = layout.tableOffset
        containerChunkCount = container.chunks.count
        decodedByteCount = decoded.count
    }

    private struct MissionLayout {
        let countOffset: Int
        let tableOffset: Int
        let count: Int
        let score: Int
    }

    private static func detectMissionLayout(in data: Data, reader: BinaryReader) -> MissionLayout? {
        let searchRange = 0x440...0x480
        var candidates: [MissionLayout] = []
        for countOffset in searchRange where countOffset + 4 <= data.count {
            guard let rawCount = try? reader.uint32LE(at: countOffset) else { continue }
            let count = Int(rawCount)
            guard (1...32).contains(count) else { continue }
            let tableOffset = countOffset + 4
            guard tableOffset + count * missionRecordByteCount <= data.count else { continue }

            var score = 0
            var isValid = true
            for index in 0..<count {
                let offset = tableOffset + index * missionRecordByteCount
                guard let enabled = try? reader.uint32LE(at: offset), enabled <= 1,
                      let sequence = try? reader.uint32LE(at: offset + 12),
                      (1...UInt32(count)).contains(sequence),
                      let title = reader.nullTerminatedString(
                        at: offset + missionTitleOffset,
                        maximumLength: missionTitleByteCount
                      )?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !title.isEmpty,
                      title.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7f }) else {
                    isValid = false
                    break
                }
                score += enabled == 1 ? 3 : 1
                score += Int(sequence) == index + 1 ? 4 : 1
                score += min(title.count, 40)
            }
            if isValid {
                score -= abs(countOffset - missionCountOffset)
                candidates.append(MissionLayout(
                    countOffset: countOffset,
                    tableOffset: tableOffset,
                    count: count,
                    score: score
                ))
            }
        }
        return candidates.max { lhs, rhs in
            lhs.score == rhs.score
                ? abs(lhs.countOffset - missionCountOffset) > abs(rhs.countOffset - missionCountOffset)
                : lhs.score < rhs.score
        }
    }

    private static func longestPrintableRun(in data: Data, range: Range<Int>) -> String? {
        let lower = max(0, range.lowerBound)
        let upper = min(data.count, range.upperBound)
        guard lower < upper else { return nil }
        var runs: [Range<Int>] = []
        var start: Int?
        for index in lower..<upper {
            let byte = data[index]
            if (0x20...0x7e).contains(byte) {
                start = start ?? index
            } else if let runStart = start {
                runs.append(runStart..<index)
                start = nil
            }
        }
        if let start { runs.append(start..<upper) }
        return runs
            .compactMap { String(data: data[$0], encoding: .windowsCP1252) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
            .max { $0.count < $1.count }
    }
}

public enum CampaignCatalog {
    public static func load(_ source: GameDataSource) throws -> [CampaignArchive] {
        let catalog = try GameDataCatalog.scan(source)
        return try catalog.campaigns.map { try CampaignArchive(url: $0.url) }
            .sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }
}
