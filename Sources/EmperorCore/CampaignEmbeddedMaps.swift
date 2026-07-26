import Foundation

public struct SierraChunkDescriptor: Sendable, Equatable, Hashable {
    public let index: Int
    public let compressedSize: Int
    public let uncompressedSize: Int
    public let fileOffset: Int
}

public struct SierraChunkIndex: Sendable, Equatable {
    public let chunks: [SierraChunkDescriptor]

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    public init(data: Data) throws {
        var reader = BinaryReader(data: data)
        guard try reader.readUInt32LE() == SierraChunkedFile.fileMagic else {
            throw GameDataError.malformedFile("chunk index magic")
        }
        var descriptors: [SierraChunkDescriptor] = []
        while reader.remainingCount >= 12 {
            let headerOffset = reader.offset
            let marker = try reader.readUInt32LE()
            guard marker == SierraChunkedFile.chunkMagic else { break }
            let compressedSize = Int(try reader.readUInt32LE())
            let uncompressedSize = Int(try reader.readUInt32LE())
            guard compressedSize > 0, uncompressedSize > 0, compressedSize <= reader.remainingCount else {
                throw GameDataError.malformedFile("invalid indexed chunk at offset \(headerOffset)")
            }
            descriptors.append(SierraChunkDescriptor(
                index: descriptors.count,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                fileOffset: headerOffset
            ))
            try reader.skip(compressedSize)
        }
        guard !descriptors.isEmpty else {
            throw GameDataError.malformedFile("chunk index is empty")
        }
        chunks = descriptors
    }
}

public struct EmbeddedCampaignMap: Identifiable, Sendable, Hashable {
    public let mapURL: URL
    /// Empty when a Campaign Creator package references an installed external
    /// `.map` by name instead of embedding its Sierra chunks in the `.pak`.
    public let campaignChunkRange: Range<Int>
    public var id: String { "\(mapURL.path)#\(campaignChunkRange.lowerBound)" }
    public var isEmbedded: Bool { !campaignChunkRange.isEmpty }
}

public enum CampaignEmbeddedMapResolver {
    public static func resolve(
        campaignURL: URL,
        candidateMapURLs: [URL]
    ) throws -> [EmbeddedCampaignMap] {
        let campaignIndex = try SierraChunkIndex(contentsOf: campaignURL)
        var descriptorMatches: [(url: URL, start: Int)] = []

        for mapURL in candidateMapURLs {
            let mapIndex = try SierraChunkIndex(contentsOf: mapURL)
            guard campaignIndex.chunks.count >= mapIndex.chunks.count else { continue }
            let lastStart = campaignIndex.chunks.count - mapIndex.chunks.count
            for start in 0...lastStart {
                var matches = true
                for index in mapIndex.chunks.indices {
                    let campaignChunk = campaignIndex.chunks[start + index]
                    let mapChunk = mapIndex.chunks[index]
                    if campaignChunk.compressedSize != mapChunk.compressedSize
                        || campaignChunk.uncompressedSize != mapChunk.uncompressedSize {
                        matches = false
                        break
                    }
                }
                if matches { descriptorMatches.append((mapURL, start)) }
            }
        }

        guard !descriptorMatches.isEmpty else { return [] }
        let campaign = try SierraChunkedFile(contentsOf: campaignURL)
        var resolved: [EmbeddedCampaignMap] = []
        for candidate in descriptorMatches {
            let map = try SierraChunkedFile(contentsOf: candidate.url)
            let isExact = map.chunks.indices.allSatisfy {
                campaign.chunks[candidate.start + $0].data == map.chunks[$0].data
            }
            if isExact {
                resolved.append(EmbeddedCampaignMap(
                    mapURL: candidate.url,
                    campaignChunkRange: candidate.start..<(candidate.start + map.chunks.count)
                ))
            }
        }
        return resolved.sorted {
            if $0.campaignChunkRange.lowerBound != $1.campaignChunkRange.lowerBound {
                return $0.campaignChunkRange.lowerBound < $1.campaignChunkRange.lowerBound
            }
            return $0.mapURL.lastPathComponent.localizedStandardCompare($1.mapURL.lastPathComponent) == .orderedAscending
        }
    }
}
