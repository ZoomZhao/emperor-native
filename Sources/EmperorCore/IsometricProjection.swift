import Foundation

public struct IsometricScreenPoint: Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Screen-edge camera movement shared by the city renderer and tests.
///
/// The original interface scrolls in the direction of the screen edge, not
/// along either map axis. Converting a normalized screen vector through the
/// inverse isometric basis keeps horizontal, vertical, and corner scrolling at
/// the same apparent speed.
public enum IsometricEdgeScrollPolicy {
    public static let triggerWidth = 18.0
    public static let activationDelay: TimeInterval = 0.22
    public static let pointsPerSecond = 240.0

    public static func screenDirection(
        pointerX: Double,
        pointerY: Double,
        viewportWidth: Double,
        viewportHeight: Double,
        edgeWidth: Double = triggerWidth
    ) -> IsometricScreenPoint {
        guard viewportWidth > 0, viewportHeight > 0 else {
            return IsometricScreenPoint(x: 0, y: 0)
        }
        let x: Double = pointerX <= edgeWidth
            ? -1
            : (pointerX >= viewportWidth - edgeWidth ? 1 : 0)
        let y: Double = pointerY <= edgeWidth
            ? -1
            : (pointerY >= viewportHeight - edgeWidth ? 1 : 0)
        return IsometricScreenPoint(x: x, y: y)
    }

    public static func mapDelta(
        for direction: IsometricScreenPoint,
        elapsed: TimeInterval,
        tileWidth: Double,
        tileHeight: Double,
        pointsPerSecond: Double = pointsPerSecond
    ) -> IsometricScreenPoint {
        let length = hypot(direction.x, direction.y)
        guard length > 0, elapsed > 0 else {
            return IsometricScreenPoint(x: 0, y: 0)
        }
        let screenX = direction.x / length * pointsPerSecond * elapsed
        let screenY = direction.y / length * pointsPerSecond * elapsed
        let safeTileWidth = max(0.001, tileWidth)
        let safeTileHeight = max(0.001, tileHeight)
        return IsometricScreenPoint(
            x: screenX / safeTileWidth + screenY / safeTileHeight,
            y: -screenX / safeTileWidth + screenY / safeTileHeight
        )
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
