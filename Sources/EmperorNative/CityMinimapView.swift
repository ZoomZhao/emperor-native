import EmperorCore
import SwiftUI

// MARK: - Minimap

/// Quantized colors matched to the original `China_Radar.BMP` family. The
/// authored radar stores tiny 2×1 terrain bars rather than a complete map
/// image, so the native renderer uses the same compact palette and footprint.
private enum MinimapColors {
    static let terrain = Color(red: 0.45, green: 0.55, blue: 0.12)
    static let shallowWater = Color(red: 0.03, green: 0.62, blue: 0.67)
    static let deepWater = Color(red: 0.01, green: 0.35, blue: 0.41)
    static let shoreline = Color(red: 0.67, green: 0.57, blue: 0.21)
    static let offMap = Color(red: 0.13, green: 0.09, blue: 0.04)
    static let rock = Color(red: 0.48, green: 0.30, blue: 0.18)
    static let road = Color(red: 0.82, green: 0.70, blue: 0.35)
    static let house = Color(red: 0.95, green: 0.66, blue: 0.10)
    static let plannedMonument = Color(red: 0.68, green: 0.16, blue: 0.73)
    static let activeMonument = Color(red: 0.93, green: 0.45, blue: 0.12)

    static func category(_ category: PlacedBuildingCategory) -> Color {
        switch category {
        case .production: Color(red: 0.55, green: 0.22, blue: 0.10)
        case .warehouse: Color(red: 0.24, green: 0.18, blue: 0.53)
        case .mill: Color(red: 0.91, green: 0.76, blue: 0.18)
        case .market: Color(red: 0.16, green: 0.62, blue: 0.19)
        case .trading: Color(red: 0.03, green: 0.55, blue: 0.50)
        case .residentialService: Color(red: 0.78, green: 0.29, blue: 0.43)
        case .military: Color(red: 0.78, green: 0.10, blue: 0.08)
        case .aesthetic: Color(red: 0.56, green: 0.18, blue: 0.65)
        }
    }
}
/// Bottom-right radar. The authored `China_Radar` sprites are tiny palette
/// bars, not a complete minimap image, so active map tiles are quantized and
/// expanded to fill the radar panel. Mission monument paths are rendered over
/// the terrain and the current viewport is outlined in white/red.
struct MinimapView: View {
    let city: DeterministicCityState
    let mapWidth: Int
    let mapHeight: Int
    let viewportStartX: Int
    let viewportStartY: Int
    let viewportColumns: Int
    let viewportRows: Int
    let onJump: (GridPoint) -> Void
    let minimapSize: CGSize

    init(
        city: DeterministicCityState,
        mapWidth: Int,
        mapHeight: Int,
        viewportStartX: Int,
        viewportStartY: Int,
        viewportColumns: Int,
        viewportRows: Int,
        minimapSize: CGSize = CGSize(width: 160, height: 120),
        onJump: @escaping (GridPoint) -> Void
    ) {
        self.city = city
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.viewportStartX = viewportStartX
        self.viewportStartY = viewportStartY
        self.viewportColumns = viewportColumns
        self.viewportRows = viewportRows
        self.onJump = onJump
        self.minimapSize = minimapSize
    }

    var body: some View {
        Canvas { context, size in
            guard mapWidth > 0, mapHeight > 0 else { return }

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(MinimapColors.offMap)
            )

            let bounds = activeMapBounds
            let buildingColors = buildingColorByPoint()
            for y in bounds.minY...bounds.maxY {
                for x in bounds.minX...bounds.maxX {
                    let mapPoint = GridPoint(x: x, y: y)
                    let rect = radarTileRect(for: mapPoint, bounds: bounds, in: size)
                    context.fill(
                        Path(rect),
                        with: .color(tileColor(mapPoint, buildingColors: buildingColors))
                    )
                }
            }

            drawMonumentMarkers(context: &context, bounds: bounds, size: size)

            let viewportPath = radarViewportPath(bounds: bounds, in: size)
            context.fill(viewportPath, with: .color(Color.white.opacity(0.10)))
            context.stroke(
                viewportPath,
                with: .color(Color(red: 0.82, green: 0.13, blue: 0.08)),
                lineWidth: 3.2
            )
            context.stroke(viewportPath, with: .color(.white), lineWidth: 1)
        }
        .frame(width: minimapSize.width, height: minimapSize.height)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .strokeBorder(EmperorTheme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { jump(to: $0.location) }
                .onEnded { jump(to: $0.location) }
        )
        .help("小地图：点击或拖动以移动视野")
        .accessibilityLabel("小地图，点击或拖动以移动视野")
        .accessibilityIdentifier("city-minimap")
        .accessibilityValue("mapWidth=\(mapWidth);mapHeight=\(mapHeight)")
        .accessibilityHint("mapWidth=\(mapWidth);mapHeight=\(mapHeight)")
    }

    private func jump(to location: CGPoint) {
        guard mapWidth > 0, mapHeight > 0 else { return }
        let bounds = activeMapBounds
        let mapX = min(
            max(
                bounds.minX,
                bounds.minX + Int(
                    (location.x / minimapSize.width * CGFloat(bounds.width)).rounded()
                )
            ),
            bounds.maxX
        )
        let mapY = min(
            max(
                bounds.minY,
                bounds.minY + Int(
                    (location.y / minimapSize.height * CGFloat(bounds.height)).rounded()
                )
            ),
            bounds.maxY
        )
        onJump(GridPoint(x: mapX, y: mapY))
    }

    private func radarPoint(
        for point: GridPoint,
        bounds: RadarBounds,
        in size: CGSize
    ) -> CGPoint {
        return CGPoint(
            x: CGFloat(point.x - bounds.minX) / CGFloat(bounds.width) * size.width,
            y: CGFloat(point.y - bounds.minY) / CGFloat(bounds.height) * size.height
        )
    }

    private func radarTileRect(
        for point: GridPoint,
        bounds: RadarBounds,
        in size: CGSize
    ) -> CGRect {
        let start = radarPoint(for: point, bounds: bounds, in: size)
        let end = radarPoint(
            for: GridPoint(x: point.x + 1, y: point.y + 1),
            bounds: bounds,
            in: size
        )
        return CGRect(
            x: floor(start.x),
            y: floor(start.y),
            width: max(1, ceil(end.x) - floor(start.x)),
            height: max(1, ceil(end.y) - floor(start.y))
        )
    }

    private func radarViewportPath(bounds: RadarBounds, in size: CGSize) -> Path {
        let origin = radarPoint(
            for: GridPoint(x: viewportStartX, y: viewportStartY),
            bounds: bounds,
            in: size
        )
        let maximum = radarPoint(
            for: GridPoint(
                x: viewportStartX + viewportColumns,
                y: viewportStartY + viewportRows
            ),
            bounds: bounds,
            in: size
        )
        return Path(
            CGRect(
                x: min(origin.x, maximum.x),
                y: min(origin.y, maximum.y),
                width: abs(maximum.x - origin.x),
                height: abs(maximum.y - origin.y)
            )
        )
    }

    private func drawMonumentMarkers(
        context: inout GraphicsContext,
        bounds: RadarBounds,
        size: CGSize
    ) {
        if let canal = city.aesthetics.grandCanalProject {
            for segment in canal.segments {
                guard let origin = canal.worldOrigin(forSegment: segment.index) else {
                    continue
                }
                drawMonumentMarker(
                    at: origin,
                    color: segment.stage > 0
                        ? MinimapColors.activeMonument
                        : MinimapColors.plannedMonument,
                    context: &context,
                    bounds: bounds,
                    size: size
                )
            }
        }
        if let wall = city.aesthetics.earthenGreatWallProject {
            for segment in wall.segments {
                guard let origin = wall.worldOrigin(forSegment: segment.index) else {
                    continue
                }
                drawMonumentMarker(
                    at: origin,
                    color: segment.stage > 0
                        ? MinimapColors.activeMonument
                        : MinimapColors.plannedMonument,
                    context: &context,
                    bounds: bounds,
                    size: size
                )
            }
        }
    }

    private func drawMonumentMarker(
        at point: GridPoint,
        color: Color,
        context: inout GraphicsContext,
        bounds: RadarBounds,
        size: CGSize
    ) {
        let radarPoint = radarPoint(for: point, bounds: bounds, in: size)
        context.fill(
            Path(
                CGRect(
                    x: radarPoint.x - 2.5,
                    y: radarPoint.y - 1,
                    width: 5,
                    height: 3
                )
            ),
            with: .color(color)
        )
    }

    private struct RadarBounds {
        let minX: Int
        let minY: Int
        let maxX: Int
        let maxY: Int

        var width: Int { max(1, maxX - minX + 1) }
        var height: Int { max(1, maxY - minY + 1) }
    }

    private var activeMapBounds: RadarBounds {
        var minimumX = mapWidth
        var minimumY = mapHeight
        var maximumX = -1
        var maximumY = -1
        for y in 0..<mapHeight {
            for x in 0..<mapWidth {
                let flags = city.terrain?.terrain(at: GridPoint(x: x, y: y))
                guard flags?.contains(.offMap) != true else { continue }
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }
        guard maximumX >= minimumX, maximumY >= minimumY else {
            return RadarBounds(
                minX: 0,
                minY: 0,
                maxX: max(0, mapWidth - 1),
                maxY: max(0, mapHeight - 1)
            )
        }
        return RadarBounds(
            minX: minimumX,
            minY: minimumY,
            maxX: maximumX,
            maxY: maximumY
        )
    }

    private func buildingColorByPoint() -> [GridPoint: Color] {
        var colors: [GridPoint: Color] = [:]
        for placement in city.placedBuildings {
            let color = MinimapColors.category(placement.category)
            for point in placement.occupiedPoints {
                colors[point] = color
            }
        }
        for house in city.houses {
            if let location = house.location {
                colors[location] = MinimapColors.house
            }
        }
        return colors
    }

    private func tileColor(_ point: GridPoint, buildingColors: [GridPoint: Color]) -> Color {
        let flags = city.terrain?.terrain(at: point)
        if flags?.contains(.offMap) == true {
            return MinimapColors.offMap
        }
        if let buildingColor = buildingColors[point] {
            return buildingColor
        }
        if city.roadNetwork.contains(point) {
            return MinimapColors.road
        }
        if flags?.contains(.beach) == true {
            return MinimapColors.shoreline
        }
        if flags?.contains(.deepWater) == true {
            return MinimapColors.deepWater
        }
        if flags?.contains(.water) == true {
            return MinimapColors.shallowWater
        }
        if flags?.contains(.rock) == true {
            return MinimapColors.rock
        }
        return MinimapColors.terrain
    }
}
