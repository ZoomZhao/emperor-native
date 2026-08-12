import EmperorCore
import AppKit
import SwiftUI

extension CityCanvas {
    func drawFengShuiBuildingOverlay(
        context: inout GraphicsContext,
        metrics: RenderMetrics
    ) {
        guard activeResourceOverlays.contains(.fengShui) else { return }
        let evaluations = Dictionary(uniqueKeysWithValues: city.fengShuiSummary(
            models: models.buildings
        ).evaluations.filter {
            $0.buildingKey.category != .agriculturalPlot
        }.map { ($0.buildingKey, $0.quality) })

        for placement in city.placedBuildings where placement.category != .agriculturalPlot {
            let key = OperationalBuildingKey(
                category: placement.category,
                instanceID: placement.instanceID
            )
            guard let quality = evaluations[key] else { continue }
            let tint: Color = switch quality {
            case .harmonious: Color(red: 0.42, green: 1.0, blue: 0.38)
            case .inauspicious: Color(red: 1.0, green: 0.08, blue: 0.08)
            case .neutral: Color(red: 1.0, green: 0.77, blue: 0.18)
            }
            let renderOrientation = placement.buildingID == 129
                ? connectedWallOrientation(for: placement)
                : placement.orientation
            let components = OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: placement.buildingID,
                orientation: renderOrientation,
                quayWaterEdge: city.quayWaterEdge(for: placement),
                marketShopBuildingIDs: placement.category == .market
                    ? city.markets.markets.first(where: { $0.id == placement.instanceID })?.shopBuildingIDs
                    : nil
            )
            var overlayContext = context
            overlayContext.opacity = 0.82
            overlayContext.addFilter(.colorMultiply(tint))
            for component in components {
                guard let sprite = buildingSprites[component.sprite] else { continue }
                let componentOrigin = component.origin(relativeTo: placement.origin)
                guard component.footprint.points(at: componentOrigin).contains(where: metrics.viewport.contains) else {
                    continue
                }
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
                overlayContext.draw(
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
    }

    func drawRenderableBuildings(
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport,
        movementProgress: CGFloat,
        buildingAnimationFrame: Int
    ) {
        var renderItems: [BuildingRenderItem] = []
        for (index, house) in city.houses.enumerated() {
            let fallback = GridPoint(x: 1 + (index % 4) * 3, y: 1 + (index / 4) * 3)
            let location = house.location ?? fallback
            guard let reference = OriginalBuildingSpriteCatalog.housingSprite(
                forHouseLevelID: house.houseLevelID,
                orientation: house.orientation
            ), buildingSprites[reference] != nil else { continue }
            renderItems.append(BuildingRenderItem(
                buildingReference: reference,
                figureReference: nil,
                mapOrigin: location,
                previousMapOrigin: nil,
                footprint: OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
                    ?? BuildingFootprint(width: 2, height: 2),
                usesLegacyHouseAnchor: false,
                isFigure: false,
                stableOrder: index
            ))
        }
        for (placementIndex, placement) in city.placedBuildings.enumerated() {
            let renderOrientation = placement.buildingID == 129
                ? connectedWallOrientation(for: placement)
                : placement.orientation
            let components = OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: placement.buildingID,
                orientation: renderOrientation,
                quayWaterEdge: city.quayWaterEdge(for: placement),
                marketShopBuildingIDs: placement.category == .market
                    ? city.markets.markets.first(where: { $0.id == placement.instanceID })?.shopBuildingIDs
                    : nil
            )
            for (componentIndex, component) in components.enumerated()
                where buildingSprites[component.sprite] != nil {
                let componentOrigin = component.origin(relativeTo: placement.origin)
                guard component.footprint.points(at: componentOrigin).contains(where: viewport.contains) else {
                    continue
                }
                renderItems.append(BuildingRenderItem(
                    buildingReference: component.sprite,
                    figureReference: nil,
                    mapOrigin: componentOrigin,
                    previousMapOrigin: nil,
                    footprint: component.footprint,
                    usesLegacyHouseAnchor: false,
                    isFigure: false,
                    stableOrder: 10_000 + placementIndex * 100 + componentIndex
                ))
            }
            if placement.buildingID == OriginalFoodCatalog.millBuildingID,
               let mill = city.logistics.mills.first(where: { $0.id == placement.instanceID }),
               mill.storedAmount > 0,
               let animationImageID = OriginalBuildingSpriteCatalog
                    .millAnimationImageIDs
                    .dropFirst(buildingAnimationFrame)
                    .first {
                renderItems.append(BuildingRenderItem(
                    buildingReference: BuildingSpriteReference(
                        archiveBaseName: OriginalBuildingSpriteCatalog.generalArchiveBaseName,
                        imageID: animationImageID
                    ),
                    figureReference: nil,
                    mapOrigin: placement.origin,
                    previousMapOrigin: nil,
                    footprint: placement.footprint,
                    usesLegacyHouseAnchor: false,
                    isFigure: false,
                    isMillAnimationOverlay: true,
                    stableOrder: 10_000 + placementIndex * 100 + components.count + 1
                ))
            }
        }
        if let canal = city.aesthetics.grandCanalProject {
            for segment in canal.segments where segment.stage > 0 {
                guard let reference = OriginalBuildingSpriteCatalog.grandCanalSprite(
                    stage: segment.stage,
                    isRoadCrossing: canal.isRoadCrossing(segment: segment.index)
                ), buildingSprites[reference] != nil,
                let segmentOrigin = canal.worldOrigin(forSegment: segment.index) else {
                    continue
                }
                let footprint = BuildingFootprint(width: 4, height: 4)
                guard footprint.points(at: segmentOrigin).contains(where: viewport.contains) else {
                    continue
                }
                renderItems.append(BuildingRenderItem(
                    buildingReference: reference,
                    figureReference: nil,
                    mapOrigin: segmentOrigin,
                    previousMapOrigin: nil,
                    footprint: footprint,
                    usesLegacyHouseAnchor: false,
                    isFigure: false,
                    stableOrder: 9_000 + segment.index
                ))
            }
        }
        if let wall = city.aesthetics.earthenGreatWallProject {
            for segment in wall.segments where segment.stage > 0 {
                guard let segmentOrigin = wall.worldOrigin(forSegment: segment.index),
                      let modeImageID = wall.modeImageID(forSegment: segment.index),
                      let cutVariant = wall.cutVariant(forSegment: segment.index) else {
                    continue
                }
                let footprint = BuildingFootprint(width: 4, height: 4)
                guard footprint.points(at: segmentOrigin).contains(where: viewport.contains) else {
                    continue
                }
                let references = OriginalBuildingSpriteCatalog.earthenGreatWallSprites(
                    stage: segment.stage,
                    modeImageID: modeImageID,
                    cutVariant: cutVariant
                )
                for (layer, reference) in references.enumerated()
                    where buildingSprites[reference] != nil {
                    renderItems.append(BuildingRenderItem(
                        buildingReference: reference,
                        figureReference: nil,
                        mapOrigin: segmentOrigin,
                        previousMapOrigin: nil,
                        footprint: footprint,
                        usesLegacyHouseAnchor: false,
                        isFigure: false,
                        stableOrder: 8_000 + segment.index * 10 + layer
                    ))
                }
            }
        }
        renderItems.append(contentsOf: tutorialFigureRenderItems(in: viewport))

        renderItems.sort { lhs, rhs in
            if lhs.farDepth != rhs.farDepth { return lhs.farDepth < rhs.farDepth }
            let lhsLateral = lhs.mapOrigin.x - lhs.mapOrigin.y
            let rhsLateral = rhs.mapOrigin.x - rhs.mapOrigin.y
            if lhsLateral != rhsLateral { return lhsLateral < rhsLateral }
            return lhs.stableOrder < rhs.stableOrder
        }
        for item in renderItems {
            let sprite: RenderedTerrainSprite?
            if let reference = item.buildingReference {
                sprite = buildingSprites[reference]
            } else if let reference = item.figureReference {
                sprite = figureSprites[reference]
            } else {
                sprite = nil
            }
            guard let sprite else {
                if item.isFigure {
                    drawMarker(
                        "?",
                        at: item.mapOrigin,
                        color: .red,
                        context: &context,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        origin: origin,
                        viewport: viewport
                    )
                }
                continue
            }
            let center = interpolatedScreenPoint(
                current: item.mapOrigin,
                previous: item.previousMapOrigin,
                progress: item.isFigure ? movementProgress : 1,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
            let scale = tileWidth / CGFloat(80)
            let drawWidth = CGFloat(sprite.width) * scale
            let drawHeight = CGFloat(sprite.height) * scale
            let imageCenterX: CGFloat
            let imageBottomY: CGFloat
            if item.isFigure {
                imageCenterX = center.x
                    + (CGFloat(sprite.width) * 0.5 - CGFloat(sprite.offsetX)) * scale
                imageBottomY = center.y + tileHeight * 0.5
                    + (CGFloat(sprite.height) - CGFloat(sprite.offsetY)) * scale
            } else if item.isMillAnimationOverlay {
                // #647 is a 398×289 base frame whose 24 authored animation
                // frames are 121×84 overlays at (160,115). The offsets are
                // present in the SG3 metadata and must be applied relative to
                // the base frame instead of being centered as a new building.
                let baseWidth = CGFloat(398) * scale
                let baseHeight = CGFloat(289) * scale
                let baseCenterX = center.x
                    + CGFloat(item.footprint.width - item.footprint.height)
                    * tileWidth * 0.25
                let baseBottomY = center.y
                    + CGFloat(item.footprint.width + item.footprint.height - 1)
                    * tileHeight * 0.5
                imageCenterX = baseCenterX - baseWidth * 0.5
                    + CGFloat(160 + 121 / 2) * scale
                imageBottomY = baseBottomY - baseHeight
                    + CGFloat(115 + 84) * scale
            } else if item.usesLegacyHouseAnchor {
                imageCenterX = center.x
                imageBottomY = center.y + tileHeight * 0.5
            } else {
                imageCenterX = center.x
                    + CGFloat(item.footprint.width - item.footprint.height) * tileWidth * 0.25
                imageBottomY = center.y
                    + CGFloat(item.footprint.width + item.footprint.height - 1) * tileHeight * 0.5
            }
            let rectangle = CGRect(
                x: imageCenterX - drawWidth * 0.5,
                y: imageBottomY - drawHeight,
                width: drawWidth,
                height: drawHeight
            )
            context.draw(Image(decorative: sprite.image, scale: 1), in: rectangle)
        }
    }

    func tutorialFigureRenderItems(in viewport: Viewport) -> [BuildingRenderItem] {
        var items: [BuildingRenderItem] = []
        let tickSequence = Int(truncatingIfNeeded: city.simulationClock.tickSequence)
        func append(
            figureID: Int,
            stableID: Int,
            point: GridPoint,
            previous: GridPoint?,
            animation animationOverride: FigureSpriteAnimation? = nil,
            interpolatesMovement: Bool = true
        ) {
            guard viewport.contains(point),
                  let animation = animationOverride
                    ?? OriginalFigureSpriteCatalog.animation(forFigureID: figureID)
            else { return }
            let direction = FigureMovementDirection.direction(from: previous, to: point)
            let reference = animation.reference(
                direction: direction,
                tickSequence: tickSequence,
                stableFigureID: stableID
            )
            items.append(BuildingRenderItem(
                buildingReference: nil,
                figureReference: reference,
                mapOrigin: point,
                previousMapOrigin: interpolatesMovement ? previous : nil,
                footprint: BuildingFootprint(width: 1, height: 1),
                usesLegacyHouseAnchor: false,
                isFigure: true,
                stableOrder: 1_000_000 + stableID
            ))
        }

        for walker in city.walkers.walkers {
            let previous = walker.route.indices.contains(walker.routeIndex - 1)
                ? walker.route[walker.routeIndex - 1] : nil
            append(
                figureID: walker.figureID,
                stableID: 100_000 + walker.id,
                point: walker.currentPoint,
                previous: previous
            )
        }
        for walker in city.logistics.deliveryWalkers {
            guard let point = walker.currentPoint else { continue }
            let previous = walker.route.indices.contains(walker.routeIndex - 1)
                ? walker.route[walker.routeIndex - 1] : nil
            append(
                figureID: walker.figureID,
                stableID: 200_000 + walker.id,
                point: point,
                previous: previous,
                animation: OriginalFigureSpriteCatalog.deliveryAnimation(
                    forCommodityID: walker.cargo.commodityID
                )
            )
        }
        for buyer in city.markets.buyers {
            guard let point = buyer.currentPoint else { continue }
            let previous = buyer.route.indices.contains(buyer.routeIndex - 1)
                ? buyer.route[buyer.routeIndex - 1] : nil
            append(
                figureID: buyer.figureID,
                stableID: 300_000 + buyer.id,
                point: point,
                previous: previous
            )
        }
        for peddler in city.markets.peddlers {
            guard let point = peddler.currentPoint else { continue }
            let previous = peddler.route.indices.contains(peddler.routeIndex - 1)
                ? peddler.route[peddler.routeIndex - 1] : nil
            append(
                figureID: peddler.figureID,
                stableID: 400_000 + peddler.id,
                point: point,
                previous: previous
            )
        }
        for unit in city.military.units where unit.status != .destroyed {
            let previous = unit.route.indices.contains(unit.routeIndex - 1)
                ? unit.route[unit.routeIndex - 1] : nil
            append(
                figureID: unit.figureID,
                stableID: 600_000 + unit.id,
                point: unit.currentPoint,
                previous: previous
            )
        }
        for (index, force) in city.military.enemyForces.enumerated()
            where force.status == .maneuvering || force.status == .engaged {
            let previous = force.route.indices.contains(force.routeIndex - 1)
                ? force.route[force.routeIndex - 1] : nil
            append(
                figureID: force.enemyTypeID,
                stableID: 700_000 + index,
                point: force.currentPoint,
                previous: previous,
                animation: OriginalFigureSpriteCatalog.animation(
                    forEnemyTypeID: force.enemyTypeID
                )
            )
        }
        if city.migration.lastDailyImmigrants > 0,
           let houseID = city.migration.lastAssessment?.eligibleHouseIDs.first,
           let house = city.houses.first(where: { $0.id == houseID }),
           let location = house.location,
           let roadPoint = RoadServiceCoverage.orthogonalNeighbors(of: location)
            .filter(city.roadNetwork.contains)
            .sorted(by: { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }).first {
            append(
                figureID: 11,
                stableID: 500_000 + houseID,
                point: roadPoint,
                previous: location,
                interpolatesMovement: false
            )
        }

        // The original map model reserves BUILD_MAP_PREY_POINT for ambient
        // animals. The native city state does not yet persist those editor
        // points, so use deterministic clear-land loops until that map layer
        // is decoded. This keeps the visible behavior data-driven (terrain,
        // roads and occupied footprints) instead of placing birds over roads
        // or buildings at arbitrary screen coordinates.
        for (index, route) in ambientPheasantRoutes().enumerated() {
            guard !route.isEmpty else { continue }
            let routeLength = UInt64(route.count)
            let animationStep = UInt64(tickSequence / 3)
            let routeOffset = UInt64(index * 5)
            let phase = (animationStep + routeOffset) % routeLength
            let currentIndex = Int(phase)
            let previousIndex = (currentIndex + route.count - 1) % route.count
            append(
                figureID: OriginalFigureSpriteCatalog.pheasantAnimation.figureID,
                stableID: 800_000 + index,
                point: route[currentIndex],
                previous: route[previousIndex],
                animation: OriginalFigureSpriteCatalog.pheasantAnimation
            )
        }
        return items
    }

    private func ambientPheasantRoutes() -> [[GridPoint]] {
        guard let terrain = city.terrain else { return [] }
        var blocked = Set(city.roadNetwork.points)
        blocked.formUnion(city.houses.compactMap(\.location))
        blocked.formUnion(city.placedBuildings.flatMap(\.occupiedPoints))

        let offsets = [
            GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0),
            GridPoint(x: 1, y: 1), GridPoint(x: 0, y: 1),
            GridPoint(x: -1, y: 1), GridPoint(x: -1, y: 0),
            GridPoint(x: -1, y: -1), GridPoint(x: 0, y: -1)
        ]
        func isAvailable(_ point: GridPoint) -> Bool {
            terrain.isClearLand(point) && !blocked.contains(point)
        }
        func score(_ point: GridPoint) -> Int {
            let value = point.x &* 73_856_093
                &+ point.y &* 19_349_663
                &+ terrain.width &* 834_927
            return value & 0x7FFF_FFFF
        }

        let maximumBirds = terrain.width * terrain.height >= 300 ? 3 : 1
        let centerX = terrain.width / 2
        let centerY = terrain.height / 2
        var candidates: [(distance: Int, score: Int, route: [GridPoint])] = []
        for y in stride(from: 2, to: terrain.height - 2, by: 2) {
            for x in stride(from: 2, to: terrain.width - 2, by: 2) {
                let start = GridPoint(x: x, y: y)
                let route = offsets.map {
                    GridPoint(x: start.x + $0.x, y: start.y + $0.y)
                }
                guard route.allSatisfy(isAvailable), score(start) % 17 == 0 else {
                    continue
                }
                let distance = abs(start.x - centerX) + abs(start.y - centerY)
                candidates.append((distance: distance, score: score(start), route: route))
            }
        }
        return candidates
            .sorted {
                if $0.distance != $1.distance { return $0.distance < $1.distance }
                return $0.score < $1.score
            }
            .prefix(maximumBirds)
            .map(\.route)
    }

    /// Straight wall pieces automatically follow their live neighbours. This
    /// keeps joins coherent after demolition or after a span is replaced by a
    /// gate/tower, without changing the save's authored construction facing.
    func connectedWallOrientation(
        for placement: PlacedBuilding
    ) -> IsometricBuildingOrientation {
        let point = placement.origin
        let connectedPoints = Set(city.military.defensiveStructures
            .filter(\.isOperational)
            .flatMap { defense in
                city.placement(category: .military, instanceID: defense.id)?.occupiedPoints
                    ?? [defense.point]
            })
        let horizontalConnections = [
            GridPoint(x: point.x - 1, y: point.y),
            GridPoint(x: point.x + 1, y: point.y),
        ].count { connectedPoints.contains($0) }
        let verticalConnections = [
            GridPoint(x: point.x, y: point.y - 1),
            GridPoint(x: point.x, y: point.y + 1),
        ].count { connectedPoints.contains($0) }
        guard horizontalConnections != verticalConnections else {
            return placement.orientation
        }
        return horizontalConnections > verticalConnections ? .northSouth : .eastWest
    }

    func hasRenderableComponents(_ placement: PlacedBuilding) -> Bool {
        let components = OriginalBuildingSpriteCatalog.buildingComponents(
            forBuildingID: placement.buildingID,
            orientation: placement.orientation,
            quayWaterEdge: city.quayWaterEdge(for: placement)
        )
        return !components.isEmpty
            && components.allSatisfy { buildingSprites[$0.sprite] != nil }
    }

    func drawWalkers(
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport,
        movementProgress: CGFloat
    ) {
        for walker in city.walkers.walkers {
            if OriginalFigureSpriteCatalog.animation(forFigureID: walker.figureID) != nil { continue }
            guard viewport.contains(walker.currentPoint) else { continue }
            let previous = walker.route.indices.contains(walker.routeIndex - 1)
                ? walker.route[walker.routeIndex - 1] : nil
            drawMarker(
                walker.service.marker,
                at: walker.currentPoint,
                previous: previous,
                movementProgress: movementProgress,
                color: walker.service == .tax ? .orange : .pink,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for walker in city.logistics.deliveryWalkers {
            if OriginalFigureSpriteCatalog.animation(forFigureID: walker.figureID) != nil { continue }
            guard let currentPoint = walker.currentPoint else { continue }
            let previous = walker.route.indices.contains(walker.routeIndex - 1)
                ? walker.route[walker.routeIndex - 1] : nil
            drawMarker(
                "运",
                at: currentPoint,
                previous: previous,
                movementProgress: movementProgress,
                color: .cyan,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for visitor in city.trade.visitors {
            guard viewport.contains(visitor.currentPoint) else { continue }
            let previous = visitor.route.points.indices.contains(visitor.routeIndex - 1)
                ? visitor.route.points[visitor.routeIndex - 1] : nil
            drawMarker(
                visitor.routeKind == .sea ? "舶" : "商",
                at: visitor.currentPoint,
                previous: previous,
                movementProgress: movementProgress,
                color: .teal,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for unit in city.military.units where unit.status != .destroyed {
            guard viewport.contains(unit.currentPoint) else { continue }
            let isSelected = selectedMilitaryUnitIDs.contains(unit.id)
            let previous = unit.route.indices.contains(unit.routeIndex - 1)
                ? unit.route[unit.routeIndex - 1] : nil
            drawMarker(
                isSelected ? "选" : "军",
                at: unit.currentPoint,
                previous: previous,
                movementProgress: movementProgress,
                color: isSelected ? .yellow : .red,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for force in city.military.enemyForces
            where force.status == .maneuvering || force.status == .engaged {
            if OriginalFigureSpriteCatalog.animation(forEnemyTypeID: force.enemyTypeID) != nil {
                continue
            }
            guard viewport.contains(force.currentPoint) else { continue }
            let previous = force.route.indices.contains(force.routeIndex - 1)
                ? force.route[force.routeIndex - 1] : nil
            drawMarker(
                force.siegeEngineCount > 0 ? "攻" : "敌",
                at: force.currentPoint,
                previous: previous,
                movementProgress: movementProgress,
                color: force.siegeEngineCount > 0 ? .purple : .black,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        let sentryPoints = Set(city.military.sentries.compactMap { sentry -> GridPoint? in
            city.military.defensiveStructures.first {
                $0.id == sentry.defenseID && $0.isOperational
            } != nil ? sentry.point : nil
        })
        for sentryPoint in sentryPoints where viewport.contains(sentryPoint) {
            drawMarker(
                "哨",
                at: sentryPoint,
                color: .orange,
                verticalOffset: -tileHeight * 0.9,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for buyer in city.markets.buyers {
            if OriginalFigureSpriteCatalog.animation(forFigureID: buyer.figureID) != nil { continue }
            guard let currentPoint = buyer.currentPoint else { continue }
            let previous = buyer.route.indices.contains(buyer.routeIndex - 1)
                ? buyer.route[buyer.routeIndex - 1] : nil
            drawMarker(
                "买",
                at: currentPoint,
                previous: previous,
                movementProgress: movementProgress,
                color: .green,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for peddler in city.markets.peddlers {
            if OriginalFigureSpriteCatalog.animation(forFigureID: peddler.figureID) != nil { continue }
            guard let currentPoint = peddler.currentPoint else { continue }
            let previous = peddler.route.indices.contains(peddler.routeIndex - 1)
                ? peddler.route[peddler.routeIndex - 1] : nil
            drawMarker(
                "货",
                at: currentPoint,
                previous: previous,
                movementProgress: movementProgress,
                color: .purple,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
    }

    func drawWalkerHighlights(
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport
    ) {
        guard activeResourceOverlays.contains(.walkers) else { return }
        let points = city.walkers.walkers.map(\.currentPoint)
            + city.logistics.deliveryWalkers.compactMap(\.currentPoint)
            + city.markets.buyers.compactMap(\.currentPoint)
            + city.markets.peddlers.compactMap(\.currentPoint)
            + city.trade.visitors.map(\.currentPoint)
        for mapPoint in points where viewport.contains(mapPoint) {
            let center = point(
                at: mapPoint,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
            let diameter = max(10, tileHeight * 0.58)
            let ring = Path(
                ellipseIn: CGRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter * 0.72,
                    width: diameter,
                    height: diameter
                )
            )
            context.fill(ring, with: .color(ResourceOverlayKind.walkers.color.opacity(0.22)))
            context.stroke(
                ring,
                with: .color(ResourceOverlayKind.walkers.color.opacity(0.95)),
                lineWidth: 1.4
            )
        }
    }

    func drawOperationsFailures(
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport,
        animationFrame: Int
    ) {
        for failure in city.operations.lastSettlement?.failures ?? [] {
            if failure.kind == .fire {
                guard let ruin = city.placedBuildings.first(where: {
                    $0.category == failure.key.category
                        && $0.instanceID == failure.key.instanceID
                        && $0.buildingID == OriginalBuildingSpriteCatalog.ruinBuildingID
                }) else { continue }
                let flamePoints = ruin.occupiedPoints
                for flamePoint in flamePoints where viewport.contains(flamePoint) {
                    let familyIndex = abs(
                        flamePoint.x &* 31 &+ flamePoint.y &* 17
                    ) % OriginalBuildingSpriteCatalog.operationsFireAnimationImageIDs.count
                    let frames = OriginalBuildingSpriteCatalog
                        .operationsFireAnimationImageIDs[familyIndex]
                    let frameIndex = min(max(0, animationFrame), frames.count - 1)
                    guard let sprite = buildingSprites[BuildingSpriteReference(
                        archiveBaseName: OriginalBuildingSpriteCatalog.destructionArchiveBaseName,
                        imageID: frames[frameIndex]
                    )] else { continue }
                    let center = point(
                        at: flamePoint,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        origin: origin,
                        viewport: viewport
                    )
                    let scale = tileWidth / CGFloat(96)
                    let drawWidth = CGFloat(sprite.width) * scale
                    let drawHeight = CGFloat(sprite.height) * scale
                    context.draw(
                        Image(decorative: sprite.image, scale: 1),
                        in: CGRect(
                            x: center.x - drawWidth / 2,
                            y: center.y + tileHeight / 2 - drawHeight,
                            width: drawWidth,
                            height: drawHeight
                        )
                    )
                }
                continue
            }
            // Collapse leaves a persistent #161 placement. Its rubble bed is
            // rendered with the other placed buildings instead of a text marker.
        }
    }

    func drawIndustry(
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport
    ) {
        for building in city.production.buildings {
            guard let roadPoint = building.roadAccessPoint else { continue }
            let placement = city.placement(
                category: .production,
                instanceID: building.id
            )
            if let placement, hasRenderableComponents(placement) { continue }
            let markerPoint = placement?.markerPoint ?? roadPoint
            let label: String
            let color: Color
            if let agriculture = building.agriculture {
                label = agricultureMarkerLabel(agriculture.crop)
                color = .green
            } else {
                label = switch building.buildingID {
                case 31: "渔"
                case 33: "猎"
                case 35: "泥"
                case 43: "窑"
                default: "产"
                }
                color = .brown
            }
            drawMarker(
                label,
                at: markerPoint,
                color: color,
                verticalOffset: -tileHeight * 0.75,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for warehouse in city.logistics.warehouses {
            let placement = city.placement(
                category: .warehouse,
                instanceID: warehouse.id
            )
            if let placement, hasRenderableComponents(placement) { continue }
            let markerPoint = placement?.markerPoint ?? warehouse.roadAccessPoint
            drawMarker(
                "仓",
                at: markerPoint,
                color: .indigo,
                verticalOffset: -tileHeight * 0.75,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for mill in city.logistics.mills {
            let placement = city.placement(
                category: .mill,
                instanceID: mill.id
            )
            if let placement, hasRenderableComponents(placement) { continue }
            let markerPoint = placement?.markerPoint ?? mill.roadAccessPoint
            drawMarker(
                "磨",
                at: markerPoint,
                color: .yellow,
                verticalOffset: -tileHeight * 0.75,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for market in city.markets.markets {
            let placement = city.placement(
                category: .market,
                instanceID: market.id
            )
            if let placement, hasRenderableComponents(placement) { continue }
            let markerPoint = placement?.markerPoint ?? market.roadAccessPoint
            drawMarker(
                "市",
                at: markerPoint,
                color: .green,
                verticalOffset: -tileHeight * 0.75,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for tradingBuilding in city.trade.buildings {
            let placement = city.placement(
                category: .trading,
                instanceID: tradingBuilding.id
            )
            if let placement, hasRenderableComponents(placement) { continue }
            let markerPoint = placement?.markerPoint ?? tradingBuilding.roadAccessPoint
            drawMarker(
                tradingBuilding.buildingID == TradeRouteKind.sea.buildingID ? "舶" : "贸",
                at: markerPoint,
                color: .teal,
                verticalOffset: -tileHeight * 0.75,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
        for serviceBuilding in city.residentialServiceBuildings {
            let placement = city.placement(
                category: .residentialService,
                instanceID: serviceBuilding.id
            )
            if let placement, hasRenderableComponents(placement) { continue }
            let markerPoint = placement?.markerPoint ?? serviceBuilding.roadAccessPoint
            drawMarker(
                serviceBuilding.service.marker,
                at: markerPoint,
                color: serviceBuilding.service == .tax ? .orange : .pink,
                verticalOffset: -tileHeight * 0.75,
                context: &context,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
        }
    }

    func agricultureMarkerLabel(_ crop: AgriculturalCrop) -> String {
        switch crop {
        case .soybeans: "豆"
        case .cabbage: "菜"
        case .millet: "粟"
        case .rice: "稻"
        case .wheat: "麦"
        case .hemp: "麻"
        case .tea: "茶"
        case .mulberry: "桑"
        case .lacquer: "漆"
        }
    }

    func drawMarker(
        _ label: String,
        at roadPoint: GridPoint,
        previous: GridPoint? = nil,
        movementProgress: CGFloat = 1,
        color: Color,
        verticalOffset: CGFloat = 0,
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport
    ) {
        guard viewport.contains(roadPoint) else { return }
        let center = interpolatedScreenPoint(
            current: roadPoint,
            previous: previous,
            progress: movementProgress,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport
        )
        let markerSize = max(CGFloat(18), tileWidth * 0.42)
        let marker = CGRect(
            x: center.x - markerSize * 0.5,
            y: center.y - markerSize * 0.8 + verticalOffset,
            width: markerSize,
            height: markerSize
        )
        context.fill(Path(ellipseIn: marker), with: .color(color))
        context.stroke(Path(ellipseIn: marker), with: .color(.white.opacity(0.85)), lineWidth: 1.5)
        context.draw(
            Text(label).font(EmperorTheme.bold(size: markerSize * 0.52)).foregroundColor(.white),
            at: CGPoint(x: marker.midX, y: marker.midY)
        )
    }

    func point(
        at point: GridPoint,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport
    ) -> CGPoint {
        let x = point.x - viewport.startX
        let y = point.y - viewport.startY
        return CGPoint(
            x: origin.x + CGFloat(x - y) * tileWidth * 0.5,
            y: origin.y + CGFloat(x + y) * tileHeight * 0.5
        )
    }

    func interpolatedScreenPoint(
        current: GridPoint,
        previous: GridPoint?,
        progress: CGFloat,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport
    ) -> CGPoint {
        let currentPoint = point(
            at: current,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport
        )
        guard let previous, previous != current, progress < 1 else {
            return currentPoint
        }
        let previousPoint = point(
            at: previous,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: origin,
            viewport: viewport
        )
        return CGPoint(
            x: previousPoint.x + (currentPoint.x - previousPoint.x) * progress,
            y: previousPoint.y + (currentPoint.y - previousPoint.y) * progress
        )
    }
}
