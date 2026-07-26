import Foundation

public enum RGB555 {
    public static let transparentMarker: UInt16 = 0xF81F

    public struct Pixel: Sendable, Hashable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public let alpha: UInt8
    }

    public static func decode(_ value: UInt16) -> Pixel {
        guard value != transparentMarker else {
            return Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let red = UInt8((UInt32(value >> 10 & 0x1F) * 255 + 15) / 31)
        let green = UInt8((UInt32(value >> 5 & 0x1F) * 255 + 15) / 31)
        let blue = UInt8((UInt32(value & 0x1F) * 255 + 15) / 31)
        return Pixel(red: red, green: green, blue: blue, alpha: 255)
    }
}
