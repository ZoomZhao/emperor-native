import CZlib
import Foundation

public struct SierraChunkedFile: Sendable {
    public static let fileMagic: UInt32 = 0xFEDCBAAA
    public static let chunkMagic: UInt32 = 0xABCDEFFF

    public struct Chunk: Sendable, Equatable {
        public let index: Int
        public let compressedSize: Int
        public let uncompressedSize: Int
        public let fileOffset: Int
        public let data: Data
    }

    public let chunks: [Chunk]
    public let trailingData: Data

    public var decodedData: Data {
        var result = Data(capacity: chunks.reduce(0) { $0 + $1.data.count })
        for chunk in chunks { result.append(chunk.data) }
        return result
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    public init(data: Data) throws {
        var reader = BinaryReader(data: data)
        let magic = try reader.readUInt32LE()
        guard magic == Self.fileMagic else {
            throw GameDataError.malformedFile(String(format: "chunked file magic 0x%08X", magic))
        }

        var decodedChunks: [Chunk] = []
        while reader.remainingCount >= 12 {
            let headerOffset = reader.offset
            let marker = try reader.readUInt32LE()
            guard marker == Self.chunkMagic else {
                try reader.seek(to: headerOffset)
                break
            }

            let compressedSize = Int(try reader.readUInt32LE())
            let uncompressedSize = Int(try reader.readUInt32LE())
            guard compressedSize > 0, uncompressedSize > 0, compressedSize <= reader.remainingCount else {
                throw GameDataError.malformedFile("invalid chunk sizes at offset \(headerOffset)")
            }
            let compressed = try reader.readData(count: compressedSize)
            let output = try Self.inflate(compressed, expectedSize: uncompressedSize)
            decodedChunks.append(Chunk(
                index: decodedChunks.count,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                fileOffset: headerOffset,
                data: output
            ))
        }

        guard !decodedChunks.isEmpty else {
            throw GameDataError.malformedFile("file contains no Sierra chunks")
        }
        chunks = decodedChunks
        trailingData = reader.remainingCount > 0 ? try reader.readData(count: reader.remainingCount) : Data()
    }

    private static func inflate(_ compressed: Data, expectedSize: Int) throws -> Data {
        var output = [UInt8](repeating: 0, count: expectedSize)
        var outputLength = uLongf(expectedSize)
        let status: Int32 = compressed.withUnsafeBytes { sourceBuffer in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return Z_DATA_ERROR }
            return uncompress(&output, &outputLength, source, uLong(compressed.count))
        }
        guard status == Z_OK, outputLength == expectedSize else {
            throw GameDataError.malformedFile("zlib status \(status), expected \(expectedSize), decoded \(outputLength)")
        }
        return Data(output)
    }
}

public struct MapProbe: Identifiable, Sendable, Hashable {
    public let url: URL
    public let chunkCount: Int
    public let decodedByteCount: Int
    public let formatVersion: UInt16?
    public let width: Int?
    public let height: Int?
    public let description: String?
    public var id: URL { url }

    public init(url: URL) throws {
        let container = try SierraChunkedFile(contentsOf: url)
        let decoded = container.decodedData
        let reader = BinaryReader(data: decoded)
        let signature = try? reader.uint32LE(at: 0)
        if let signature, signature & 0xFFFF0000 == 0xCAFE0000 {
            formatVersion = UInt16(signature & 0xFFFF)
        } else {
            formatVersion = nil
        }

        let candidateWidth = (try? reader.uint32LE(at: 0x54)).map(Int.init)
        let candidateHeight = (try? reader.uint32LE(at: 0x58)).map(Int.init)
        width = candidateWidth.flatMap { (1...512).contains($0) ? $0 : nil }
        height = candidateHeight.flatMap { (1...512).contains($0) ? $0 : nil }
        description = reader.nullTerminatedString(at: 0x64, maximumLength: 64)
        self.url = url
        chunkCount = container.chunks.count
        decodedByteCount = decoded.count
    }
}
