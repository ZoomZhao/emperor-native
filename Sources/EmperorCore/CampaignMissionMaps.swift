import Foundation

public struct CampaignMissionMapAssignment: Identifiable, Sendable, Hashable {
    public let id: Int
    public let sourceMissionIndex: Int
    /// City slot selected by the original Campaign Creator for this mission.
    public let playerCityID: Int
    public let embeddedMap: EmbeddedCampaignMap

    public var isContinuation: Bool { sourceMissionIndex != id }
}

public struct CampaignMissionMapArchive: Sendable, Hashable {
    public static let maximumMissionCount = 10
    public static let mapNameByteCount = 256
    public static let mapSlotByteCount = 260
    public static let sourceTablePadding = 20
    public static let playerCityTableByteCount = 10

    public let mapNameTableOffset: Int?
    public let playerCityTableOffset: Int?
    public let sourceMissionTableOffset: Int?
    public let embeddedMaps: [EmbeddedCampaignMap]
    public let missions: [CampaignMissionMapAssignment]
    /// Multiplayer scenario packages contain empire/event data but no unique
    /// local city map; the original lobby chose one of several MP maps.
    public let isMaplessNetworkScenario: Bool

    public init(
        campaignURL: URL,
        missionCount: Int,
        candidateMapURLs: [URL]
    ) throws {
        let exactEmbeddedMaps = try CampaignEmbeddedMapResolver.resolve(
            campaignURL: campaignURL,
            candidateMapURLs: candidateMapURLs
        )
        guard (1...Self.maximumMissionCount).contains(missionCount) else {
            throw GameDataError.malformedFile("campaign mission map count")
        }

        let container = try SierraChunkedFile(contentsOf: campaignURL)
        let decoded = container.decodedData
        let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
        let sourceDelta = Self.maximumMissionCount * Self.mapSlotByteCount + Self.sourceTablePadding
        let candidateURLsByName = Dictionary(
            grouping: candidateMapURLs,
            by: { $0.deletingPathExtension().lastPathComponent.lowercased() }
        )
        let embeddedByName = Dictionary(
            grouping: exactEmbeddedMaps,
            by: { $0.mapURL.deletingPathExtension().lastPathComponent.lowercased() }
        )
        let lowercaseMetadata = decoded.prefix(metadataEnd).map { byte -> UInt8 in
            (65...90).contains(byte) ? byte + 32 : byte
        }
        let searchableMetadata = Data(lowercaseMetadata)
        var candidateBases = Set<Int>()

        // Campaign Creator always writes the ten fixed map-name slots even
        // when the maps themselves are external. Search installed basenames
        // as anchors, then validate the adjacent source/player-city tables.
        for mapName in candidateURLsByName.keys {
            let pattern = Data(mapName.data(using: .windowsCP1252) ?? Data())
            guard !pattern.isEmpty else { continue }
            var searchStart = 0
            while searchStart < searchableMetadata.count,
                  let match = searchableMetadata.range(
                    of: pattern,
                    in: searchStart..<searchableMetadata.count
                  ) {
                for slot in 0..<Self.maximumMissionCount {
                    let base = match.lowerBound - slot * Self.mapSlotByteCount
                    if base >= 0, base + sourceDelta + missionCount <= metadataEnd {
                        candidateBases.insert(base)
                    }
                }
                searchStart = match.lowerBound + 1
            }
        }

        let reader = BinaryReader(data: decoded)
        let validated = candidateBases.sorted().compactMap {
            base -> (base: Int, sources: [Int], playerCityIDs: [Int], names: [String], score: Int)? in
            let sourceOffset = base + sourceDelta
            let sources = (0..<missionCount).map { Int(decoded[sourceOffset + $0]) }
            guard sources.indices.allSatisfy({ sources[$0] <= $0 }) else { return nil }
            let playerCityOffset = sourceOffset - Self.playerCityTableByteCount
            let playerCityIDs = (0..<missionCount).map { Int(decoded[playerCityOffset + $0]) }
            guard playerCityIDs.allSatisfy({ (0..<CampaignEmpireMap.cityCount).contains($0) }) else {
                return nil
            }

            var names: [String] = []
            names.reserveCapacity(missionCount)
            for missionIndex in 0..<missionCount {
                let nameOffset = base + missionIndex * Self.mapSlotByteCount
                let name = reader.nullTerminatedString(
                    at: nameOffset,
                    maximumLength: Self.mapNameByteCount
                ) ?? ""
                if sources[missionIndex] == missionIndex {
                    guard candidateURLsByName[name.lowercased()] != nil else {
                        return nil
                    }
                } else if !name.isEmpty {
                    return nil
                }
                names.append(name)
            }
            let standardNames = names.enumerated().compactMap { index, name in
                sources[index] == index ? name : nil
            }
            guard !standardNames.isEmpty else { return nil }
            let embeddedMatchCount = standardNames.count {
                embeddedByName[$0.lowercased()] != nil
            }
            // If this package really embeds maps, every exact embedded map
            // must appear in the validated table. This rejects coincidental
            // filename strings elsewhere in the MFC metadata.
            guard exactEmbeddedMaps.isEmpty
                    || embeddedMatchCount == exactEmbeddedMaps.count
            else { return nil }
            return (
                base,
                sources,
                playerCityIDs,
                names,
                embeddedMatchCount * 1_000 + standardNames.count * 10
            )
        }

        guard let layout = validated.max(by: {
            $0.score == $1.score ? $0.base > $1.base : $0.score < $1.score
        }) else {
            if exactEmbeddedMaps.isEmpty,
               container.chunks.count == 29,
               missionCount == 1 {
                embeddedMaps = []
                missions = []
                mapNameTableOffset = nil
                playerCityTableOffset = nil
                sourceMissionTableOffset = nil
                isMaplessNetworkScenario = true
                return
            }
            throw GameDataError.malformedFile("campaign mission map table")
        }
        var assignments: [CampaignMissionMapAssignment] = []
        assignments.reserveCapacity(missionCount)
        var referencedMaps: [EmbeddedCampaignMap] = []
        for missionIndex in 0..<missionCount {
            let source = layout.sources[missionIndex]
            let map: EmbeddedCampaignMap
            if source == missionIndex {
                let name = layout.names[missionIndex].lowercased()
                if let embedded = embeddedByName[name]?.first {
                    map = embedded
                } else if let externalURL = candidateURLsByName[name]?.sorted(by: {
                    $0.path.localizedStandardCompare($1.path) == .orderedAscending
                }).first {
                    map = EmbeddedCampaignMap(
                        mapURL: externalURL,
                        campaignChunkRange: 0..<0
                    )
                } else {
                    throw GameDataError.malformedFile("campaign standard mission map")
                }
                if !referencedMaps.contains(where: { $0.mapURL == map.mapURL }) {
                    referencedMaps.append(map)
                }
            } else {
                guard assignments.indices.contains(source) else {
                    throw GameDataError.malformedFile("campaign continuation mission map")
                }
                map = assignments[source].embeddedMap
            }
            assignments.append(CampaignMissionMapAssignment(
                id: missionIndex,
                sourceMissionIndex: source,
                playerCityID: layout.playerCityIDs[missionIndex],
                embeddedMap: map
            ))
        }

        embeddedMaps = referencedMaps
        mapNameTableOffset = layout.base
        playerCityTableOffset = layout.base
            + Self.maximumMissionCount * Self.mapSlotByteCount
            + Self.playerCityTableByteCount
        sourceMissionTableOffset = layout.base + sourceDelta
        isMaplessNetworkScenario = false
        missions = assignments
    }
}
