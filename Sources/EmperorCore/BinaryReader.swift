import Foundation

public struct BinaryReader: Sendable {
    public let data: Data
    public private(set) var offset: Int

    public init(data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    public var remainingCount: Int { data.count - offset }

    public mutating func seek(to newOffset: Int) throws {
        guard newOffset >= 0, newOffset <= data.count else {
            throw BinaryReaderError.outOfBounds(offset: newOffset, length: 0, available: data.count)
        }
        offset = newOffset
    }

    public mutating func skip(_ count: Int) throws {
        try seek(to: offset + count)
    }

    public mutating func readUInt8() throws -> UInt8 {
        try require(1)
        defer { offset += 1 }
        return data[offset]
    }

    public mutating func readInt8() throws -> Int8 {
        Int8(bitPattern: try readUInt8())
    }

    public mutating func readUInt16LE() throws -> UInt16 {
        try require(2)
        defer { offset += 2 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    public mutating func readInt16LE() throws -> Int16 {
        Int16(bitPattern: try readUInt16LE())
    }

    public mutating func readUInt32LE() throws -> UInt32 {
        try require(4)
        defer { offset += 4 }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    public mutating func readInt32LE() throws -> Int32 {
        Int32(bitPattern: try readUInt32LE())
    }

    public mutating func readData(count: Int) throws -> Data {
        try require(count)
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    public func uint32LE(at index: Int) throws -> UInt32 {
        var copy = BinaryReader(data: data, offset: index)
        return try copy.readUInt32LE()
    }

    public func nullTerminatedString(at index: Int, maximumLength: Int, encoding: String.Encoding = .windowsCP1252) -> String? {
        guard index >= 0, index < data.count, maximumLength > 0 else { return nil }
        let upper = min(data.count, index + maximumLength)
        let bytes = data[index..<upper]
        let end = bytes.firstIndex(of: 0) ?? upper
        guard end > index else { return nil }
        return String(data: data[index..<end], encoding: encoding)
    }

    private func require(_ count: Int) throws {
        guard count >= 0, offset >= 0, offset + count <= data.count else {
            throw BinaryReaderError.outOfBounds(offset: offset, length: count, available: data.count)
        }
    }
}

public enum BinaryReaderError: Error, LocalizedError, Equatable {
    case outOfBounds(offset: Int, length: Int, available: Int)

    public var errorDescription: String? {
        switch self {
        case let .outOfBounds(offset, length, available):
            return "Binary read outside data: offset \(offset), length \(length), available \(available)."
        }
    }
}
