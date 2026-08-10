import EmperorCore
import AppKit
import SwiftUI

extension CityCanvas {
    func drawCity(
        context: inout GraphicsContext,
        size: CGSize,
        movementProgress: CGFloat
    ) {
        if originalMap != nil {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(red: 0.055, green: 0.060, blue: 0.045))
            )
        }
        let metrics = renderMetrics(for: size)
        let viewport = metrics.viewport
        let tileWidth = metrics.tileWidth
        let tileHeight = metrics.tileHeight
        let origin = metrics.origin
        drawGround(
            context: &context,
            viewport: viewport,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin
        )
        drawResourceOverlays(
            context: &context,
            viewport: viewport,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin
        )
        drawServiceCoverageOverlays(
            context: &context,
            viewport: viewport,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin
        )
        drawPlacedBuildingFootprints(
            context: &context,
            metrics: metrics
        )
        drawRenderableBuildings(
            context: &context,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport,
            movementProgress: movementProgress
        )
        drawPlacementHighlight(
            context: &context,
            metrics: metrics
        )
        drawIndustry(
            context: &context,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport
        )
        drawWalkers(
            context: &context,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport,
            movementProgress: movementProgress
        )
        drawWalkerHighlights(
            context: &context,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport
        )
        drawOperationsFailures(
            context: &context,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport
        )
    }

    func movementProgress(at date: Date) -> CGFloat {
        guard gameSpeed > 0 else { return 1 }
        let tickInterval: TimeInterval
        switch gameSpeed {
        case 1: tickInterval = 0.25
        case 2: tickInterval = 0.125
        default: tickInterval = 0.0625
        }
        return min(
            1,
            max(0, CGFloat(date.timeIntervalSince(lastTickPresentationDate) / tickInterval))
        )
    }

    func renderMetrics(for size: CGSize) -> RenderMetrics {
        let viewport = viewport
        let tileWidth: CGFloat
        let origin: CGPoint
        if originalMap != nil {
            // The original game renders its terrain at the native 80×40
            // isometric scale and clips the larger map at the viewport edges.
            // Fitting the complete 32×32 diamond made the city look like a
            // distant board floating in a black void.
            tileWidth = min(
                80,
                max(52, min(size.width / 10, size.height / 7))
            )
            let tileHeight = tileWidth * 0.5
            let focusColumn = CGFloat(
                Double(baseFocus.x) + effectiveCameraOffsetX
                    - Double(viewport.startX)
            )
            let focusRow = CGFloat(
                Double(baseFocus.y) + effectiveCameraOffsetY
                    - Double(viewport.startY)
            )
            origin = CGPoint(
                x: size.width * 0.5 - (focusColumn - focusRow) * tileWidth * 0.5,
                y: size.height * 0.5 - (focusColumn + focusRow) * tileHeight * 0.5
            )
        } else {
            let availableWidth = size.width - CGFloat(36)
            let fittedWidth = availableWidth * CGFloat(2)
                / CGFloat(viewport.columns + viewport.rows)
            tileWidth = min(CGFloat(52), max(CGFloat(8), fittedWidth))
            let focusColumn = CGFloat(
                Double(baseFocus.x) + effectiveCameraOffsetX
                    - Double(viewport.startX)
            )
            let focusRow = CGFloat(
                Double(baseFocus.y) + effectiveCameraOffsetY
                    - Double(viewport.startY)
            )
            let residualX = focusColumn - CGFloat(viewport.columns / 2)
            let residualY = focusRow - CGFloat(viewport.rows / 2)
            origin = CGPoint(
                x: size.width * 0.5 - (residualX - residualY) * tileWidth * 0.5,
                y: 82 - (residualX + residualY) * tileWidth * 0.25
            )
        }
        return RenderMetrics(
            viewport: viewport,
            tileWidth: tileWidth,
            tileHeight: tileWidth * CGFloat(0.5),
            origin: origin
        )
    }

    func mapPoint(at location: CGPoint, size: CGSize) -> GridPoint? {
        let metrics = renderMetrics(for: size)
        let point = metrics.projection.mapPoint(
            for: IsometricScreenPoint(x: Double(location.x), y: Double(location.y))
        )
        guard metrics.viewport.contains(point),
              city.roadNetwork.isInside(point),
              city.terrain?.terrain(at: point)?.contains(.offMap) != true else {
            return nil
        }
        return point
    }

    /// Resolve the building or house occupying a tapped tile in inspect mode.
    func inspectedTarget(at point: GridPoint) -> InspectedTarget? {
        if let placement = city.placedBuildings.first(where: { $0.occupiedPoints.contains(point) }) {
            return .placed(placement)
        }
        let houseFootprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        if let house = city.houses.first(where: {
            $0.location.map { houseFootprint.points(at: $0).contains(point) } ?? false
        }) {
            return .house(house)
        }
        return nil
    }

    func demolitionHighlightPoints(at point: GridPoint) -> [GridPoint] {
        if let placement = city.placedBuildings.first(where: {
            $0.occupiedPoints.contains(point)
        }) {
            return placement.occupiedPoints
        }
        let houseFootprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)
        if let location = city.houses.lazy.compactMap(\.location).first(where: {
            houseFootprint.points(at: $0).contains(point)
        }) {
            return houseFootprint.points(at: location)
        }
        return [point]
    }

    func areaPlacementPoints(from start: GridPoint, to end: GridPoint) -> [GridPoint] {
        switch constructionTool {
        case .road, .cityWall:
            return ConstructionDragPlanner.orthogonalSegment(from: start, to: end)
        case .house, .eliteHouse:
            let footprint = activeConstructionBuildingID.flatMap {
                OriginalBuildingFootprintCatalog.footprint(
                    forBuildingID: $0,
                    orientation: constructionOrientation
                )
            } ?? BuildingFootprint(width: 2, height: 2)
            return ConstructionDragPlanner.tiledOrigins(
                from: start,
                to: end,
                footprint: footprint
            )
        case .farmland, .demolish, .clearLand:
            return ConstructionDragPlanner.rectangularPoints(from: start, to: end)
        default:
            return [start]
        }
    }

    func drawPlacementHighlight(
        context: inout GraphicsContext,
        metrics: RenderMetrics
    ) {
        guard constructionTool != .inspect else { return }
        let origins: [GridPoint]
        if !draggedPlacementPoints.isEmpty {
            origins = draggedPlacementPoints
        } else if let hoveredMapPoint, metrics.viewport.contains(hoveredMapPoint) {
            origins = [hoveredMapPoint]
        } else {
            return
        }
        for origin in origins {
            let isValid = placementIsValid(at: origin)
            let color = isValid ? EmperorTheme.success : EmperorTheme.error
            let highlightedPoints: [GridPoint]
            if constructionTool == .demolish {
                highlightedPoints = demolitionHighlightPoints(at: origin)
            } else if constructionTool.marketShopBuildingID != nil,
                      let marketPlacement = city.placedBuildings.first(where: {
                          $0.category == .market && $0.occupiedPoints.contains(origin)
                      }) {
                highlightedPoints = marketPlacement.occupiedPoints
            } else if let buildingID = activeConstructionBuildingID,
               let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: constructionOrientation
               ) {
                highlightedPoints = footprint.points(at: origin)
            } else {
                highlightedPoints = [origin]
            }
            let hasSpritePreview = constructionPreviewComponents(at: origin).contains {
                buildingSprites[$0.sprite] != nil
            }
            for highlightedPoint in highlightedPoints where metrics.viewport.contains(highlightedPoint) {
                let center = point(
                    at: highlightedPoint,
                    tileWidth: metrics.tileWidth,
                    tileHeight: metrics.tileHeight,
                    origin: metrics.origin,
                    viewport: metrics.viewport
                )
                let diamond = tileDiamond(
                    center: center,
                    tileWidth: metrics.tileWidth,
                    tileHeight: metrics.tileHeight
                )
                context.fill(
                    diamond,
                    with: .color(color.opacity(hasSpritePreview ? 0.12 : 0.30))
                )
                context.stroke(diamond, with: .color(color), lineWidth: 1.5)
            }
            drawConstructionPreview(
                at: origin,
                isValid: isValid,
                context: &context,
                metrics: metrics
            )
        }
    }

    func constructionPreviewComponents(
        at origin: GridPoint
    ) -> [BuildingSpriteComponent] {
        guard let buildingID = activeConstructionBuildingID else { return [] }
        if constructionTool == .house,
           let footprint = OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: buildingID,
            orientation: constructionOrientation
           ),
           let sprite = OriginalBuildingSpriteCatalog.housingSprite(
            forHouseLevelID: 0,
            orientation: constructionOrientation
           ) {
            return [BuildingSpriteComponent(
                sprite: sprite,
                tileOffsetX: 0,
                tileOffsetY: 0,
                footprint: footprint
            )]
        }
        return OriginalBuildingSpriteCatalog.buildingComponents(
            forBuildingID: buildingID,
            orientation: constructionOrientation
        )
    }

    func drawConstructionPreview(
        at buildingOrigin: GridPoint,
        isValid: Bool,
        context: inout GraphicsContext,
        metrics: RenderMetrics
    ) {
        let components = constructionPreviewComponents(at: buildingOrigin).sorted { lhs, rhs in
            let lhsOrigin = lhs.origin(relativeTo: buildingOrigin)
            let rhsOrigin = rhs.origin(relativeTo: buildingOrigin)
            let lhsDepth = lhsOrigin.x + lhsOrigin.y + lhs.footprint.width + lhs.footprint.height
            let rhsDepth = rhsOrigin.x + rhsOrigin.y + rhs.footprint.width + rhs.footprint.height
            return lhsDepth < rhsDepth
        }
        guard !components.isEmpty else { return }
        var previewContext = context
        previewContext.opacity = isValid ? 0.72 : 0.48
        previewContext.addFilter(
            .colorMultiply(
                isValid
                    ? Color(red: 0.64, green: 1.0, blue: 0.70)
                    : Color(red: 1.0, green: 0.54, blue: 0.48)
            )
        )
        for component in components {
            guard let sprite = buildingSprites[component.sprite] else { continue }
            let componentOrigin = component.origin(relativeTo: buildingOrigin)
            let center = point(
                at: componentOrigin,
                tileWidth: metrics.tileWidth,
                tileHeight: metrics.tileHeight,
                origin: metrics.origin,
                viewport: metrics.viewport
            )
            let scale = metrics.tileWidth / 80
            let drawWidth = CGFloat(sprite.width) * scale
            let drawHeight = CGFloat(sprite.height) * scale
            let imageCenterX = center.x
                + CGFloat(component.footprint.width - component.footprint.height)
                * metrics.tileWidth * 0.25
            let imageBottomY = center.y
                + CGFloat(component.footprint.width + component.footprint.height - 1)
                * metrics.tileHeight * 0.5
            previewContext.draw(
                Image(decorative: sprite.image, scale: 1),
                in: CGRect(
                    x: imageCenterX - drawWidth * 0.5,
                    y: imageBottomY - drawHeight,
                    width: drawWidth,
                    height: drawHeight
                )
            )
        }
    }

    func placementIsValid(at point: GridPoint) -> Bool {
        switch constructionTool {
        case .inspect: false
        case .demolish: city.canDemolish(at: point)
        case .clearLand: city.canClearVegetation(at: point)
        case .road: city.canConstructRoad(at: point)
        case .roadblock: city.canConstructRoadBlock(at: point)
        case .rally: city.canIssueMilitaryOrder(to: point)
        case .grandCanalSegment: city.canAdvanceGrandCanalSegment(at: point)
        case .earthenGreatWallSegment: city.canAdvanceEarthenGreatWallSegment(at: point)
        case .largePalacePhase: city.canAdvanceLargePalacePhase(at: point)
        case .phasedMonumentPhase: city.canAdvancePhasedMonument(at: point)
        case .house: city.canConstructHouse(at: point)
        case .eliteHouse: city.canConstructHouse(at: point)
        case .farmland:
            city.canConstructAgriculturalPlot(crop: agriculturalCrop, at: point)
        case .foodShop, .hempShop, .ceramicsShop, .teaShop, .silkShop,
             .lacquerwareShop, .bronzewareShop:
            constructionTool.marketShopBuildingID.map {
                city.canConstructMarketShop(shopBuildingID: $0, at: point)
            } ?? false
        case .garden, .decorativeSculpture, .ornateSculpture, .floweringTree,
             .waysidePavilion, .pond, .taiChiPark, .privateGarden,
             .laborersCamp, .carpentersGuild, .masonsGuild, .ceramistsGuild,
             .tumulus, .grandTumulus, .undergroundVault, .greatTemple,
             .splendidTemple, .grandPagoda, .largePalace:
            constructionTool.buildingID.map {
                city.canConstructAestheticBuilding(
                    buildingID: $0,
                    at: point,
                    orientation: constructionOrientation
                )
            } ?? false
        default:
            constructionTool.buildingID.map {
                city.canConstructBuilding(
                    buildingID: $0,
                    at: point,
                    orientation: constructionOrientation
                )
            } ?? false
        }
    }

    func drawPlacedBuildingFootprints(
        context: inout GraphicsContext,
        metrics: RenderMetrics
    ) {
        for placement in city.placedBuildings where !hasRenderableComponents(placement) {
            if placement.buildingID == OriginalBuildingSpriteCatalog.ruinBuildingID {
                drawRuinFootprint(placement, context: &context, metrics: metrics)
                continue
            }
            let color: Color = switch placement.category {
            case .production: .brown
            case .warehouse: .indigo
            case .mill: .yellow
            case .market: .green
            case .trading: .teal
            case .residentialService: .pink
            case .military: .red
            case .aesthetic: .purple
            }
            for occupiedPoint in placement.occupiedPoints where metrics.viewport.contains(occupiedPoint) {
                let center = point(
                    at: occupiedPoint,
                    tileWidth: metrics.tileWidth,
                    tileHeight: metrics.tileHeight,
                    origin: metrics.origin,
                    viewport: metrics.viewport
                )
                let diamond = tileDiamond(
                    center: center,
                    tileWidth: metrics.tileWidth,
                    tileHeight: metrics.tileHeight
                )
                context.fill(diamond, with: .color(color.opacity(0.46)))
                context.stroke(diamond, with: .color(color.opacity(0.9)), lineWidth: 0.8)
            }
        }
    }

    /// Draws a neutral rubble bed while the shipped Ruin (#161) artwork is
    /// still being identified. The persisted footprint is intentionally
    /// visible and blocks construction until it is demolished.
    func drawRuinFootprint(
        _ placement: PlacedBuilding,
        context: inout GraphicsContext,
        metrics: RenderMetrics
    ) {
        for (index, occupiedPoint) in placement.occupiedPoints.enumerated()
            where metrics.viewport.contains(occupiedPoint) {
            let center = point(
                at: occupiedPoint,
                tileWidth: metrics.tileWidth,
                tileHeight: metrics.tileHeight,
                origin: metrics.origin,
                viewport: metrics.viewport
            )
            let diamond = tileDiamond(
                center: center,
                tileWidth: metrics.tileWidth,
                tileHeight: metrics.tileHeight
            )
            context.fill(diamond, with: .color(Color.gray.opacity(0.58)))
            context.stroke(diamond, with: .color(Color.black.opacity(0.72)), lineWidth: 1)

            let stoneWidth = metrics.tileWidth * 0.19
            let stoneHeight = metrics.tileHeight * 0.27
            let xOffset = index.isMultiple(of: 2) ? -stoneWidth * 0.55 : stoneWidth * 0.35
            let stone = CGRect(
                x: center.x + xOffset - stoneWidth * 0.5,
                y: center.y - stoneHeight * 0.55,
                width: stoneWidth,
                height: stoneHeight
            )
            context.fill(
                Path(roundedRect: stone, cornerRadius: 1),
                with: .color(Color(white: 0.28))
            )
        }
    }

    func tileDiamond(center: CGPoint, tileWidth: CGFloat, tileHeight: CGFloat) -> Path {
        var diamond = Path()
        diamond.move(to: CGPoint(x: center.x, y: center.y - tileHeight * 0.5))
        diamond.addLine(to: CGPoint(x: center.x + tileWidth * 0.5, y: center.y))
        diamond.addLine(to: CGPoint(x: center.x, y: center.y + tileHeight * 0.5))
        diamond.addLine(to: CGPoint(x: center.x - tileWidth * 0.5, y: center.y))
        diamond.closeSubpath()
        return diamond
    }

    /// The un-offset map point the camera centres on. Extracted so the minimap
    /// can convert a clicked map tile into the matching `cameraOffset`.
    var baseFocus: GridPoint {
        let mapCenter = GridPoint(
            x: city.roadNetwork.width / 2,
            y: city.roadNetwork.height / 2
        )
        return city.roadNetwork.points.min { lhs, rhs in
                let lhsDistance = distanceSquared(lhs, mapCenter)
                let rhsDistance = distanceSquared(rhs, mapCenter)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                if lhs.y != rhs.y { return lhs.y < rhs.y }
                return lhs.x < rhs.x
            }
            ?? city.houses.compactMap(\.location).first
            ?? city.trade.buildings.first?.roadAccessPoint
            ?? mapCenter
    }

    var viewport: Viewport {
        let columns = min(city.roadNetwork.width, originalMap == nil ? 12 : 32)
        let rows = min(city.roadNetwork.height, originalMap == nil ? 9 : 32)
        let focusX = Double(baseFocus.x) + effectiveCameraOffsetX
        let focusY = Double(baseFocus.y) + effectiveCameraOffsetY
        let startX = min(
            max(0, Int(floor(focusX - Double(columns) * 0.5))),
            max(0, city.roadNetwork.width - columns)
        )
        let startY = min(
            max(0, Int(floor(focusY - Double(rows) * 0.5))),
            max(0, city.roadNetwork.height - rows)
        )
        return Viewport(startX: startX, startY: startY, columns: columns, rows: rows)
    }

    /// Recentre the main viewport on a map tile chosen from the minimap by
    /// deriving the camera offset that makes `baseFocus + offset == target`.
    func jumpCamera(to target: GridPoint) {
        let playableTarget = nearestPlayablePoint(to: target)
        setCameraPosition(
            x: Double(playableTarget.x - baseFocus.x),
            y: Double(playableTarget.y - baseFocus.y)
        )
    }

    /// Map archives mark their inaccessible storage border with water-like
    /// flags. A minimap click there should snap to the nearest real terrain
    /// cell instead of centring the camera on the hidden border.
    func nearestPlayablePoint(to target: GridPoint) -> GridPoint {
        guard let terrain = city.terrain,
              terrain.terrain(at: target)?.contains(.offMap) == true else {
            return target
        }
        var nearest: GridPoint?
        var nearestDistance = Int.max
        for y in 0..<terrain.height {
            for x in 0..<terrain.width {
                let candidate = GridPoint(x: x, y: y)
                guard terrain.terrain(at: candidate)?.contains(.offMap) != true else {
                    continue
                }
                let candidateDistance = distanceSquared(candidate, target)
                if candidateDistance < nearestDistance {
                    nearest = candidate
                    nearestDistance = candidateDistance
                }
            }
        }
        return nearest ?? baseFocus
    }

    /// Small (160×120pt) overlay in the bottom-right corner showing the whole
    /// map as coloured dots plus the current viewport rectangle. Clicking or
    /// dragging recentres the main camera on the chosen map region.
    var minimap: some View {
        let current = viewport
        return MinimapView(
            city: city,
            mapWidth: city.roadNetwork.width,
            mapHeight: city.roadNetwork.height,
            viewportStartX: current.startX,
            viewportStartY: current.startY,
            viewportColumns: current.columns,
            viewportRows: current.rows,
            onJump: jumpCamera(to:)
        )
    }

    func distanceSquared(_ lhs: GridPoint, _ rhs: GridPoint) -> Int {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

}
