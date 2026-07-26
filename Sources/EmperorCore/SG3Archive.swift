import Foundation

public struct SG3Archive: Sendable {
    public static let headerByteCount = 80
    public static let groupCount = 300
    public static let bitmapNameCount = 200
    public static let bitmapNameByteCount = 200
    public static let imageTableOffset = 40_680

    public struct Header: Sendable, Hashable {
        public let declaredFileSize: UInt32
        public let version: UInt32
        public let maximumEntries: UInt32
        public let entryCount: Int
        public let bitmapNamesUsed: Int
        public let declaredPixelByteCount: UInt32
    }

    public struct Image: Identifiable, Sendable, Hashable {
        public let id: Int
        public let dataOffset: Int
        public let dataLength: Int
        public let uncompressedLength: Int
        public let mirrorOffset: Int
        public let width: Int
        public let height: Int
        public let groupID: Int
        public let groupIndex: Int
        public let spriteCount: Int
        public let spriteOffsetX: Int
        public let spriteOffsetY: Int
        public let type: UInt8
        public let isFullyCompressed: Bool
        public let isExternal: Bool
        public let hasIsometricTop: Bool
        public let bitmapGroupID: Int
        public let animationSpeedID: UInt8
    }

    /// One of the 200-byte source bitmap records embedded in an SG3 header.
    /// Figure archives keep all pixels in the archive's own `.555` file, so
    /// `Image.bitmapGroupID` is commonly zero.  The authoritative semantic
    /// name for an image therefore comes from this record's start/end range.
    public struct Bitmap: Identifiable, Sendable, Hashable {
        public let id: Int
        public let name: String
        public let comment: String
        public let width: Int
        public let height: Int
        public let imageCount: Int
        public let startImageID: Int
        public let endImageID: Int

        public func contains(imageID: Int) -> Bool {
            imageCount > 0 && startImageID <= imageID && imageID <= endImageID
        }
    }

    public struct BitmapLogicalGroupMapping: Sendable, Hashable {
        public let bitmapID: Int
        public let bitmapName: String
        public let logicalGroups: Range<Int>
        public let imageIDs: Range<Int>
    }

    public let header: Header
    public let groupImageIDs: [UInt16]
    public let bitmaps: [Bitmap]
    public let bitmapNames: [String]
    public let images: [Image]

    public func bitmap(containingImageID imageID: Int) -> Bitmap? {
        bitmaps.prefix(header.bitmapNamesUsed).first { $0.contains(imageID: imageID) }
    }

    /// Produces a best-effort diagnostic partition for archives whose bitmap
    /// count/start/end fields are zero. This is useful when inspecting unknown
    /// packs, but gameplay catalogs must still pin exported, visually verified
    /// logical groups; the per-image `.555` source index is not a semantic ID.
    public func inferredBitmapLogicalGroupMappings() -> [BitmapLogicalGroupMapping] {
        let usedBitmaps = Array(bitmaps.prefix(header.bitmapNamesUsed))
        let groups: [(logicalID: Int, imageID: Int)] = groupImageIDs.enumerated().compactMap {
            $0.element == 0 ? nil : ($0.offset, Int($0.element))
        }
        guard !usedBitmaps.isEmpty, groups.count >= usedBitmaps.count else { return [] }

        var groupMaximums: [(width: Int, height: Int)] = []
        groupMaximums.reserveCapacity(groups.count)
        for groupIndex in groups.indices {
            let first = groups[groupIndex].imageID
            let end = groupIndex + 1 < groups.count ? groups[groupIndex + 1].imageID : images.count
            let slice = images[first..<min(end, images.count)]
            groupMaximums.append((
                slice.map(\.width).max() ?? 0,
                slice.map(\.height).max() ?? 0
            ))
        }

        // Some source canvas records differ from their largest decoded frame
        // by one or two pixels. Use a global minimum-cost partition so every
        // bitmap and logical group is consumed in order, heavily penalizing a
        // decoded frame that would not fit its named source canvas.
        let infinity = Int.max / 4
        var costs = Array(
            repeating: Array(repeating: infinity, count: groups.count + 1),
            count: usedBitmaps.count + 1
        )
        var nextGroup = Array(
            repeating: Array(repeating: -1, count: groups.count + 1),
            count: usedBitmaps.count
        )
        costs[usedBitmaps.count][groups.count] = 0

        if !usedBitmaps.isEmpty {
            for bitmapIndex in stride(from: usedBitmaps.count - 1, through: 0, by: -1) {
                let bitmap = usedBitmaps[bitmapIndex]
                let remainingBitmaps = usedBitmaps.count - bitmapIndex - 1
                guard bitmapIndex <= groups.count - 1 else { continue }
                for groupIndex in 0..<(groups.count - remainingBitmaps) {
                    var maximumWidth = 0
                    var maximumHeight = 0
                    let maximumEnd = groups.count - remainingBitmaps
                    guard groupIndex + 1 <= maximumEnd else { continue }
                    for endGroup in (groupIndex + 1)...maximumEnd {
                        maximumWidth = max(maximumWidth, groupMaximums[endGroup - 1].width)
                        maximumHeight = max(maximumHeight, groupMaximums[endGroup - 1].height)
                        guard costs[bitmapIndex + 1][endGroup] < infinity else { continue }
                        let widthDelta = abs(maximumWidth - bitmap.width)
                        let heightDelta = abs(maximumHeight - bitmap.height)
                        let overflow = max(0, maximumWidth - bitmap.width)
                            + max(0, maximumHeight - bitmap.height)
                        let localCost = widthDelta + heightDelta + overflow * 24
                        let candidate = localCost + costs[bitmapIndex + 1][endGroup]
                        if candidate < costs[bitmapIndex][groupIndex] {
                            costs[bitmapIndex][groupIndex] = candidate
                            nextGroup[bitmapIndex][groupIndex] = endGroup
                        }
                    }
                }
            }
        }

        guard costs[0][0] < infinity else { return [] }
        var mappings: [BitmapLogicalGroupMapping] = []
        var groupIndex = 0
        for bitmapIndex in usedBitmaps.indices {
            let endGroup = nextGroup[bitmapIndex][groupIndex]
            guard endGroup > groupIndex else { return [] }
            let bitmap = usedBitmaps[bitmapIndex]
            let firstImageID = groups[groupIndex].imageID
            let endImageID = endGroup < groups.count ? groups[endGroup].imageID : images.count
            mappings.append(BitmapLogicalGroupMapping(
                bitmapID: bitmap.id,
                bitmapName: bitmap.name,
                logicalGroups: groups[groupIndex].logicalID..<(endGroup < groups.count
                    ? groups[endGroup].logicalID : Self.groupCount),
                imageIDs: firstImageID..<endImageID
            ))
            groupIndex = endGroup
        }
        return groupIndex == groups.count ? mappings : []
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    public init(data: Data) throws {
        guard data.count >= Self.imageTableOffset else {
            throw GameDataError.malformedFile("SG3 file is too short")
        }
        var reader = BinaryReader(data: data)
        let words = try (0..<20).map { _ in try reader.readUInt32LE() }
        let count = Int(words[4]) + 1
        let namesUsed = Int(words[5])
        let version = words[1]
        guard count > 0, count <= Int(words[3]), namesUsed >= 0, namesUsed <= Self.bitmapNameCount else {
            throw GameDataError.malformedFile("invalid SG3 header counts")
        }
        header = Header(
            declaredFileSize: words[0],
            version: version,
            maximumEntries: words[3],
            entryCount: count,
            bitmapNamesUsed: namesUsed,
            declaredPixelByteCount: words[8]
        )

        groupImageIDs = try (0..<Self.groupCount).map { _ in try reader.readUInt16LE() }

        func decodedCString(_ data: Data) -> String {
            let end = data.firstIndex(of: 0) ?? data.endIndex
            return String(data: data[..<end], encoding: .windowsCP1252) ?? ""
        }
        var parsedBitmaps: [Bitmap] = []
        parsedBitmaps.reserveCapacity(Self.bitmapNameCount)
        for id in 0..<Self.bitmapNameCount {
            let name = decodedCString(try reader.readData(count: 65))
            let comment = decodedCString(try reader.readData(count: 51))
            let width = Int(try reader.readUInt32LE())
            let height = Int(try reader.readUInt32LE())
            let imageCount = Int(try reader.readUInt32LE())
            let startImageID = Int(try reader.readUInt32LE())
            let endImageID = Int(try reader.readUInt32LE())
            try reader.skip(64)
            parsedBitmaps.append(Bitmap(
                id: id,
                name: name,
                comment: comment,
                width: width,
                height: height,
                imageCount: imageCount,
                startImageID: startImageID,
                endImageID: endImageID
            ))
        }
        bitmaps = parsedBitmaps
        bitmapNames = parsedBitmaps.map(\.name)

        try reader.seek(to: Self.imageTableOffset)
        let entryByteCount = version >= 214 ? 72 : 64
        guard reader.remainingCount >= count * entryByteCount else {
            throw GameDataError.malformedFile("truncated SG3 image table")
        }

        var parsed: [Image] = []
        parsed.reserveCapacity(count)
        for index in 0..<count {
            let entryStart = reader.offset
            let dataOffset = Int(try reader.readInt32LE())
            let dataLength = Int(try reader.readInt32LE())
            let uncompressedLength = Int(try reader.readInt32LE())
            _ = try reader.readInt32LE()
            let mirrorOffset = Int(try reader.readInt32LE())
            let width = max(0, Int(try reader.readInt16LE()))
            let height = max(0, Int(try reader.readInt16LE()))
            let groupID = Int(try reader.readUInt16LE())
            let groupIndex = Int(try reader.readUInt16LE())
            _ = try reader.readInt16LE()
            let spriteCount = Int(try reader.readUInt16LE())
            _ = try reader.readInt16LE()
            let spriteOffsetX = Int(try reader.readInt16LE())
            let spriteOffsetY = Int(try reader.readInt16LE())
            for _ in 0..<5 { _ = try reader.readInt16LE() }
            _ = try reader.readInt8()
            _ = try reader.readInt8()
            let type = try reader.readUInt8()
            let fullyCompressed = try reader.readUInt8() != 0
            let external = try reader.readUInt8() != 0
            let hasTop = try reader.readUInt8() != 0
            _ = try reader.readInt8()
            _ = try reader.readInt8()
            let bitmapGroup = Int(try reader.readUInt8())
            _ = try reader.readInt8()
            let speed = try reader.readUInt8()
            for _ in 0..<5 { _ = try reader.readInt8() }
            if version >= 214 { try reader.skip(8) }
            try reader.seek(to: entryStart + entryByteCount)

            parsed.append(Image(
                id: index,
                dataOffset: dataOffset,
                dataLength: dataLength,
                uncompressedLength: uncompressedLength,
                mirrorOffset: mirrorOffset,
                width: width,
                height: height,
                groupID: groupID,
                groupIndex: groupIndex,
                spriteCount: spriteCount,
                spriteOffsetX: spriteOffsetX,
                spriteOffsetY: spriteOffsetY,
                type: type,
                isFullyCompressed: fullyCompressed,
                isExternal: external,
                hasIsometricTop: hasTop,
                bitmapGroupID: bitmapGroup,
                animationSpeedID: speed
            ))
        }
        images = parsed
    }
}
