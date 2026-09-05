import CoreGraphics
import Foundation

public struct DecodedSprite: @unchecked Sendable {
    public let width: Int
    public let height: Int
    public let rgba: Data

    public init(width: Int, height: Int, rgba: Data) {
        self.width = width
        self.height = height
        self.rgba = rgba
    }

    public func makeCGImage() -> CGImage? {
        guard width > 0, height > 0, rgba.count == width * height * 4,
              let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Returns the foliage/top layer of an isometric grass sprite. Original
    /// fertile-land frames include an opaque ochre diamond underneath the
    /// blades; the legacy renderer composites the vegetation separately.
    /// Removing only strongly red-over-green soil pixels preserves the source
    /// grass detail without exposing a visible diamond seam on every tile.
    public func greenVegetationOnly() -> DecodedSprite {
        var pixels = [UInt8](rgba)
        for offset in stride(from: 0, to: pixels.count, by: 4)
            where pixels[offset + 3] != 0 {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            if red - green >= 25 {
                pixels[offset + 3] = 0
            }
        }
        return DecodedSprite(width: width, height: height, rgba: Data(pixels))
    }

    /// Figure sheets contain an unresolved RGB555 pure-red marker (0x7C00) in
    /// the projected ground area. The exact original shadow compositor is not
    /// recovered; retaining the marker or converting it to black creates a
    /// visible red/grey block on native terrain. Keep the marker transparent
    /// until the original shadow path is closed instead of inventing a shape.
    public func correctingFigureShadow() -> DecodedSprite {
        var pixels = [UInt8](rgba)
        for offset in stride(from: 0, to: pixels.count, by: 4)
            where pixels[offset] == 255
                && pixels[offset + 1] == 0
                && pixels[offset + 2] == 0
                && pixels[offset + 3] != 0 {
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = 0
        }
        return DecodedSprite(width: width, height: height, rgba: Data(pixels))
    }

    /// SG3 figure archives store opposite walk directions (and some gait frames)
    /// as horizontal mirrors of another image ID. The mirrored record keeps the
    /// adjusted hotspot offsets but leaves `dataLength` at zero.
    public func flippedHorizontally() -> DecodedSprite {
        guard width > 0, height > 0, rgba.count == width * height * 4 else {
            return self
        }
        var pixels = [UInt8](repeating: 0, count: rgba.count)
        rgba.withUnsafeBytes { source in
            guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<height {
                let row = y * width * 4
                for x in 0..<width {
                    let from = row + x * 4
                    let to = row + (width - 1 - x) * 4
                    pixels[to] = base[from]
                    pixels[to + 1] = base[from + 1]
                    pixels[to + 2] = base[from + 2]
                    pixels[to + 3] = base[from + 3]
                }
            }
        }
        return DecodedSprite(width: width, height: height, rgba: Data(pixels))
    }
}

public enum SpriteDecoder {
    private static let isometricType: UInt8 = 30
    private static let tileWidth = 80
    private static let tileHeight = 40
    private static let footprintWidth = 78
    private static let halfTileHeight = 20

    /// Decodes one SG3 image. When `images` is provided, records with a non-zero
    /// `mirrorOffset` resolve to `id + mirrorOffset` and are flipped horizontally,
    /// matching the original Windows renderer.
    public static func decode(
        image: SG3Archive.Image,
        pixelData: Data,
        images: [SG3Archive.Image] = []
    ) throws -> DecodedSprite {
        var current = image
        var flipCount = 0
        var guardCount = 0
        while current.mirrorOffset != 0 {
            guard guardCount < 8 else {
                throw GameDataError.malformedFile(
                    "sprite #\(image.id) mirror chain exceeded 8 hops"
                )
            }
            guard !images.isEmpty else {
                throw GameDataError.malformedFile(
                    "sprite #\(current.id) is mirrored but no archive images were provided"
                )
            }
            let sourceID = current.id + current.mirrorOffset
            guard images.indices.contains(sourceID) else {
                throw GameDataError.malformedFile(
                    "sprite #\(current.id) mirror source #\(sourceID) is out of range"
                )
            }
            current = images[sourceID]
            flipCount += 1
            guardCount += 1
        }

        var sprite = try decodePixelData(image: current, pixelData: pixelData)
        if flipCount % 2 == 1 {
            sprite = sprite.flippedHorizontally()
        }
        return sprite
    }

    private static func decodePixelData(
        image: SG3Archive.Image,
        pixelData: Data
    ) throws -> DecodedSprite {
        guard image.width > 0, image.height > 0 else {
            throw GameDataError.malformedFile("sprite #\(image.id) has empty dimensions")
        }
        guard !image.isExternal else {
            throw GameDataError.unsupported("external SG3 bitmap groups")
        }
        guard image.dataOffset >= 0, image.dataLength >= 0,
              image.dataOffset + image.dataLength <= pixelData.count else {
            throw GameDataError.malformedFile("sprite #\(image.id) pixel range is outside its .555 file")
        }

        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let encoded = pixelData.subdata(in: image.dataOffset..<(image.dataOffset + image.dataLength))

        if image.type == isometricType {
            guard image.uncompressedLength >= 0, image.uncompressedLength <= encoded.count else {
                throw GameDataError.malformedFile("sprite #\(image.id) has an invalid isometric footprint length")
            }
            var footprint = BinaryReader(data: encoded.subdata(in: 0..<image.uncompressedLength))
            try decodeIsometricFootprint(image: image, reader: &footprint, output: &rgba)
            if image.hasIsometricTop, image.dataLength > image.uncompressedLength {
                let top = encoded.subdata(in: image.uncompressedLength..<image.dataLength)
                try decodeRLE(data: top, width: image.width, height: image.height, output: &rgba)
            }
        } else if image.isFullyCompressed {
            try decodeRLE(data: encoded, width: image.width, height: image.height, output: &rgba)
        } else {
            var reader = BinaryReader(data: encoded)
            let count = image.width * image.height
            guard reader.remainingCount >= count * 2 else {
                throw GameDataError.malformedFile("sprite #\(image.id) has truncated RGB555 pixels")
            }
            for pixelIndex in 0..<count {
                write(try reader.readUInt16LE(), at: pixelIndex, output: &rgba)
            }
        }

        return DecodedSprite(width: image.width, height: image.height, rgba: Data(rgba))
    }

    private static func decodeIsometricFootprint(
        image: SG3Archive.Image,
        reader: inout BinaryReader,
        output: inout [UInt8]
    ) throws {
        let tileCount = (image.width + 2) / tileWidth
        guard tileCount > 0, image.width == tileCount * tileWidth - 2 else {
            throw GameDataError.unsupported("isometric sprite width \(image.width)")
        }
        let yOffset = image.height - tileHeight * tileCount
        guard yOffset >= 0 else {
            throw GameDataError.malformedFile("isometric sprite #\(image.id) is shorter than its footprint")
        }

        let xOrigin = (tileCount - 1) * tileHeight
        for row in 0..<tileCount {
            var x = -tileHeight * row + xOrigin
            let y = halfTileHeight * row + yOffset
            for _ in 0...row {
                try decodeFootprintTile(reader: &reader, xOffset: x, yOffset: y, imageWidth: image.width, imageHeight: image.height, output: &output)
                x += footprintWidth + 2
            }
        }
        if tileCount >= 2 {
            for row in stride(from: tileCount - 2, through: 0, by: -1) {
                var x = -tileHeight * row + xOrigin
                let y = halfTileHeight * (tileCount * 2 - row - 2) + yOffset
                for _ in 0...row {
                    try decodeFootprintTile(reader: &reader, xOffset: x, yOffset: y, imageWidth: image.width, imageHeight: image.height, output: &output)
                    x += footprintWidth + 2
                }
            }
        }
    }

    private static func decodeFootprintTile(
        reader: inout BinaryReader,
        xOffset: Int,
        yOffset: Int,
        imageWidth: Int,
        imageHeight: Int,
        output: inout [UInt8]
    ) throws {
        for y in 0..<tileHeight {
            let xStart = max(0, abs(2 * y - (tileHeight - 1)) - 1)
            let xEnd = footprintWidth - xStart
            for x in xStart..<xEnd {
                let targetX = x + xOffset
                let targetY = y + yOffset
                let value = try reader.readUInt16LE()
                guard targetX >= 0, targetX < imageWidth, targetY >= 0, targetY < imageHeight else { continue }
                write(value, at: targetY * imageWidth + targetX, output: &output)
            }
        }
    }

    private static func decodeRLE(data: Data, width: Int, height: Int, output: inout [UInt8]) throws {
        var reader = BinaryReader(data: data)
        var pixelIndex = 0
        let pixelCount = width * height
        while reader.remainingCount > 0, pixelIndex < pixelCount {
            let control = try reader.readUInt8()
            if control == 0xFF {
                guard reader.remainingCount > 0 else {
                    throw GameDataError.malformedFile("truncated transparent RLE run")
                }
                pixelIndex += Int(try reader.readUInt8())
            } else {
                let concreteCount = Int(control)
                guard reader.remainingCount >= concreteCount * 2 else {
                    throw GameDataError.malformedFile("truncated concrete RLE run")
                }
                for _ in 0..<concreteCount {
                    let value = try reader.readUInt16LE()
                    if pixelIndex < pixelCount { write(value, at: pixelIndex, output: &output) }
                    pixelIndex += 1
                }
            }
        }
    }

    private static func write(_ value: UInt16, at pixelIndex: Int, output: inout [UInt8]) {
        let pixel = RGB555.decode(value)
        let target = pixelIndex * 4
        guard target >= 0, target + 3 < output.count else { return }
        output[target] = pixel.red
        output[target + 1] = pixel.green
        output[target + 2] = pixel.blue
        output[target + 3] = pixel.alpha
    }
}
