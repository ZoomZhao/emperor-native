import Foundation

public struct IsometricScreenPoint: Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Shared projection math for the native renderer and pointer hit testing.
/// Keeping both directions in EmperorCore prevents construction clicks from
/// drifting away from the diamond that was actually drawn.
public struct IsometricViewportProjection: Sendable, Hashable {
    public let startX: Int
    public let startY: Int
    public let tileWidth: Double
    public let tileHeight: Double
    public let originX: Double
    public let originY: Double

    public init(
        startX: Int,
        startY: Int,
        tileWidth: Double,
        tileHeight: Double,
        originX: Double,
        originY: Double
    ) {
        self.startX = startX
        self.startY = startY
        self.tileWidth = max(0.001, tileWidth)
        self.tileHeight = max(0.001, tileHeight)
        self.originX = originX
        self.originY = originY
    }

    public func screenPoint(for mapPoint: GridPoint) -> IsometricScreenPoint {
        let x = mapPoint.x - startX
        let y = mapPoint.y - startY
        return IsometricScreenPoint(
            x: originX + Double(x - y) * tileWidth * 0.5,
            y: originY + Double(x + y) * tileHeight * 0.5
        )
    }

    /// Returns the nearest tile center. Callers still validate viewport bounds
    /// and terrain before mutating the city.
    public func mapPoint(for screenPoint: IsometricScreenPoint) -> GridPoint {
        let difference = (screenPoint.x - originX) / (tileWidth * 0.5)
        let sum = (screenPoint.y - originY) / (tileHeight * 0.5)
        return GridPoint(
            x: startX + Int(((difference + sum) * 0.5).rounded()),
            y: startY + Int(((sum - difference) * 0.5).rounded())
        )
    }
}
