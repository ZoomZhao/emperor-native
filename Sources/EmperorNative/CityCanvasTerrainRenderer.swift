import EmperorCore
import AppKit
import SwiftUI

extension CityCanvas {
    func drawGround(
        context: inout GraphicsContext,
        viewport: Viewport,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint
    ) {
        for diagonal in 0..<(viewport.columns + viewport.rows - 1) {
            for row in 0..<viewport.rows {
                let column = diagonal - row
                guard column >= 0, column < viewport.columns else { continue }
                let mapPoint = GridPoint(
                    x: viewport.startX + column,
                    y: viewport.startY + row
                )
                let center = point(
                    at: mapPoint,
                    tileWidth: tileWidth,
                    tileHeight: tileHeight,
                    origin: origin,
                    viewport: viewport
                )
                var diamond = Path()
                diamond.move(to: CGPoint(x: center.x, y: center.y - tileHeight * 0.5))
                diamond.addLine(to: CGPoint(x: center.x + tileWidth * 0.5, y: center.y))
                diamond.addLine(to: CGPoint(x: center.x, y: center.y + tileHeight * 0.5))
                diamond.addLine(to: CGPoint(x: center.x - tileWidth * 0.5, y: center.y))
                diamond.closeSubpath()
                let flags = city.terrain?.terrain(at: mapPoint)
                if flags?.contains(.offMap) == true {
                    // The archive stores a padded, inaccessible border around
                    // the authored map. Leave it as one continuous dark canvas
                    // instead of exposing the storage grid as grey diamonds.
                    continue
                }
                let baseColor: Color = if flags?.contains(.deepWater) == true {
                    // Deep water is deliberately darker than the shoreline
                    // bed, matching the authored China_Terrain river family.
                    Color(red: 0.08, green: 0.25, blue: 0.32)
                } else if flags?.contains(.water) == true {
                    Color(red: 0.16, green: 0.38, blue: 0.41)
                } else if city.roadNetwork.contains(mapPoint) {
                    Color(red: 0.40, green: 0.31, blue: 0.20)
                } else if flags?.contains(.rock) == true {
                    Color(red: 0.36, green: 0.35, blue: 0.32)
                } else if flags?.contains(.elevation) == true
                            || flags?.contains(.pinnacle) == true {
                    Color(red: 0.34, green: 0.31, blue: 0.24)
                } else if originalMap != nil {
                    Color(red: 0.30, green: 0.47, blue: 0.10)
                } else {
                    Color(
                        red: 0.20,
                        green: (mapPoint.x + mapPoint.y).isMultiple(of: 2) ? 0.30 : 0.27,
                        blue: 0.16
                    )
                }
                // Isometric terrain sprites are 78 pixels wide on an 80-pixel
                // grid and deliberately contain transparent edge pixels.
                // The original renderer paints the terrain bed first; without
                // it, black one-pixel seams and empty diamonds show through.
                context.fill(diamond, with: .color(baseColor))
                let isPlayerBuiltRoad = city.roadNetwork.contains(mapPoint)
                    && originalMap?.map.terrain(at: mapPoint)?.contains(.road) != true
                let playerRoadSprite = isPlayerBuiltRoad
                    ? originalMap?.roadSprite(connectionMask: roadConnectionMask(at: mapPoint))
                    : nil
                let drewOriginalTerrain: Bool
                if let playerRoadSprite {
                    // A road tile replaces the land image for this grid cell.
                    // Drawing it after the authored grass sprite made the two
                    // opaque beds overlap and left newly built roads dirty.
                    drawOriginalSprite(
                        playerRoadSprite,
                        center: center,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        context: &context
                    )
                    drewOriginalTerrain = true
                } else {
                    drewOriginalTerrain = drawOriginalTerrain(
                        at: mapPoint,
                        center: center,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        context: &context
                    )
                }
                if !drewOriginalTerrain {
                    context.stroke(diamond, with: .color(.black.opacity(0.16)), lineWidth: 0.5)
                }
                if isPlayerBuiltRoad, playerRoadSprite == nil {
                    context.fill(
                        diamond,
                        with: .color(
                            Color(red: 0.46, green: 0.34, blue: 0.20).opacity(0.82)
                        )
                    )
                    context.stroke(
                        diamond,
                        with: .color(.black.opacity(0.38)),
                        lineWidth: 0.8
                    )
                }
            }
        }
    }

    /// Paints semi-transparent coloured diamonds over tiles that hold an active
    /// resource deposit (食物/木材/石材/粘土), reading the terrain flags directly
    /// from `city.terrain`.
    func drawResourceOverlays(
        context: inout GraphicsContext,
        viewport: Viewport,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint
    ) {
        let activeTerrainLayers = ResourceOverlayKind.terrainCases.filter {
            activeResourceOverlays.contains($0)
        }
        guard !activeTerrainLayers.isEmpty, let terrain = city.terrain else { return }
        for row in 0..<viewport.rows {
            for column in 0..<viewport.columns {
                let mapPoint = GridPoint(
                    x: viewport.startX + column,
                    y: viewport.startY + row
                )
                guard let flags = terrain.terrain(at: mapPoint),
                      !flags.contains(.offMap) else { continue }
                let matching = activeTerrainLayers.filter { $0.matches(flags) }
                guard !matching.isEmpty else { continue }
                let center = point(
                    at: mapPoint,
                    tileWidth: tileWidth,
                    tileHeight: tileHeight,
                    origin: origin,
                    viewport: viewport
                )
                let diamond = tileDiamond(
                    center: center,
                    tileWidth: tileWidth,
                    tileHeight: tileHeight
                )
                for kind in matching {
                    context.fill(diamond, with: .color(kind.color.opacity(0.38)))
                }
                if let strokeKind = matching.first {
                    context.stroke(
                        diamond,
                        with: .color(strokeKind.color.opacity(0.9)),
                        lineWidth: 1.2
                    )
                }
            }
        }
    }

    /// The original game exposes service views such as water and hazards.
    /// Highlight each residential footprint so gaps are visible without
    /// replacing the map: covered houses use the layer colour, uncovered
    /// houses receive a restrained red warning.
    func drawServiceCoverageOverlays(
        context: inout GraphicsContext,
        viewport: Viewport,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint
    ) {
        let activeServiceLayers = ResourceOverlayKind.serviceCases.filter {
            $0 != .inspection && activeResourceOverlays.contains($0)
        }
        let showsHazards = activeResourceOverlays.contains(.inspection)
        guard !activeServiceLayers.isEmpty || showsHazards else { return }
        let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)

        if !activeServiceLayers.isEmpty {
            for house in city.houses {
                guard let location = house.location else { continue }
                let matching = activeServiceLayers.filter {
                    $0.covers(house, models: models.buildings)
                }
                for mapPoint in footprint.points(at: location) where viewport.contains(mapPoint) {
                    let center = point(
                        at: mapPoint,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        origin: origin,
                        viewport: viewport
                    )
                    let diamond = tileDiamond(
                        center: center,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight
                    )
                    if matching.isEmpty {
                        context.fill(
                            diamond,
                            with: .color(EmperorTheme.error.opacity(0.24))
                        )
                        context.stroke(
                            diamond,
                            with: .color(EmperorTheme.error.opacity(0.82)),
                            lineWidth: 1
                        )
                    } else {
                        for kind in matching {
                            context.fill(
                                diamond,
                                with: .color(kind.color.opacity(0.28))
                            )
                        }
                        context.stroke(
                            diamond,
                            with: .color(matching[0].color.opacity(0.9)),
                            lineWidth: 1
                        )
                    }
                }
            }
        }

        guard showsHazards else { return }
        let rules = OriginalBuildingHazardRules(configuration: models.generalBuilding)
        for risk in city.operations.risks where viewport.contains(risk.location) {
            let fireRatio = min(1, CGFloat(risk.fireRisk) / CGFloat(rules.fireRiskLimit))
            let collapseRatio = min(
                1,
                CGFloat(risk.damageRisk) / CGFloat(rules.collapseRiskLimit)
            )
            let danger = max(fireRatio, collapseRatio)
            let center = point(
                at: risk.location,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                origin: origin,
                viewport: viewport
            )
            // The original Hazards overlay uses taller, redder pillars as a
            // building approaches fire or collapse, rather than binary route
            // coverage. Keep a small baseline so maintained buildings remain
            // discoverable in the overlay.
            let height = tileHeight * (0.35 + danger * 2.6)
            let width = max(3, tileWidth * 0.09)
            let pillar = CGRect(
                x: center.x - width * 0.5,
                y: center.y - height,
                width: width,
                height: height
            )
            let color = Color(
                red: 0.95,
                green: 0.78 * (1 - danger),
                blue: 0.12 * (1 - danger)
            )
            context.fill(Path(pillar), with: .color(color.opacity(0.9)))
            context.stroke(Path(pillar), with: .color(Color.black.opacity(0.75)), lineWidth: 1)
        }
    }

    func drawOriginalTerrain(
        at point: GridPoint,
        center: CGPoint,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        context: inout GraphicsContext
    ) -> Bool {
        guard let originalMap,
              originalMap.map.width == city.roadNetwork.width,
              originalMap.map.height == city.roadNetwork.height else { return false }
        let terrain = city.terrain?.terrain(at: point)
        let originalTerrain = originalMap.map.terrain(at: point)

        // The authored map stores the same 4x4 canal reserve image in every
        // one of its 528 cells. The Windows runtime immediately replaces that
        // grid cache per SB_CANAL object: phase zero restores terrain #247
        // (with per-cell variations only in crossing parts) and its four-cell
        // road centre line, while phases 1...4 are drawn once as a depth-
        // sorted 4x4 body in the entity pass. Never draw the authored #201
        // once per cell here.
        if let canalPart = grandCanalMapPart(containing: point) {
            if canalPart.currentSubBuildingPhase == 0 {
                let crossing = GrandCanalLayout.original.segments.first {
                    $0.index == canalPart.subBuildingIndex
                }?.isRoadCrossing == true
                let isCrossingRoadCell = crossing
                    && point.y == canalPart.worldOrigin.y + 2
                let variation = originalMap.map.terrainVisualVariationValue(
                    x: point.x,
                    y: point.y
                ) ?? 0
                let localImageID = OriginalBuildingSpriteCatalog
                    .grandCanalPhaseZeroTerrainImageID(
                        isRoadCrossing: crossing,
                        isCrossingRoadCell: isCrossingRoadCell,
                        terrainVariation: variation
                    )
                if let sprite = originalMap.terrainSprite(localImageID: localImageID) {
                    drawOriginalSprite(
                        sprite,
                        center: center,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        context: &context
                    )
                }
            }
            return true
        }

        // The editor-authored Badaling archive repeats a Great Wall reserve
        // image across each part footprint. The original city renderer
        // replaces that cache from the live multipart object and draws one
        // depth-sorted sprite per wall/tower/gate/road part. Suppress the
        // repeated reserve here whenever that object state is present.
        if greatWallKind != nil, greatWallMapPart(containing: point) != nil {
            return true
        }

        // Cliff faces and slope transitions must win over fertility, including
        // Banpo's 0x40000 object encoding. Ordinary China_Terrain records do
        // not win here: most are only the bare-soil bed underneath grass.
        if let sprite = originalMap.elevationSprite(x: point.x, y: point.y) {
            drawOriginalSprite(
                sprite,
                center: center,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                context: &context
            )
            return true
        }

        // Clearing vegetation must not redraw the authored tree object.
        if originalTerrain?.intersection([.tree, .scrub]).isEmpty == false,
           terrain?.intersection([.tree, .scrub]).isEmpty == true {
            drawFertileGrass(
                at: point,
                center: center,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                context: &context
            )
            return true
        }

        // Fertile terrain is a green bed plus the original vegetation-only
        // layer. Drawing the authored ochre bed first produced the repeated
        // yellow diamonds that regressed across the whole map.
        if terrain.map(isPlainFertileLand) == true {
            drawFertileGrass(
                at: point,
                center: center,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                context: &context
            )
            return true
        }

        if let sprite = originalMap.sprite(x: point.x, y: point.y) {
            drawOriginalSprite(
                sprite,
                center: center,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                context: &context
            )
            return true
        }

        // Never substitute grass under elevation / cliff / rock cells when the
        // authored sprite is still unresolved — leave the diamond bed instead.
        if terrain?.contains(.elevation) == true
            || terrain?.contains(.rock) == true
            || terrain?.contains(.pinnacle) == true {
            return false
        }

        guard let landBed = unresolvedLandBedSprite(at: point, originalMap: originalMap) else {
            return false
        }
        drawOriginalSprite(
            landBed,
            center: center,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            context: &context
        )
        if terrain?.contains(.tree) == true,
           let tree = originalMap.treeSprite(x: point.x, y: point.y) {
            drawOriginalSprite(
                tree,
                center: center,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                context: &context
            )
        }
        return true
    }

    private func grandCanalMapPart(containing point: GridPoint) -> GrandCanalMapPartState? {
        return city.aesthetics.grandCanalMapPartStates.first {
            point.x >= $0.worldOrigin.x && point.x < $0.worldOrigin.x + 4
                && point.y >= $0.worldOrigin.y && point.y < $0.worldOrigin.y + 4
        }
    }

    private func greatWallMapPart(containing point: GridPoint) -> GreatWallMapPartState? {
        city.aesthetics.greatWallMapPartStates.first { part in
            guard let kind = OriginalGreatWallLayoutCatalog.subBuildingKind(
                buildingID: part.buildingID,
                subBuildingIndex: part.subBuildingIndex
            ) else { return false }
            return BuildingFootprint(
                width: kind.footprintSide,
                height: kind.footprintSide
            ).points(at: part.worldOrigin).contains(point)
        }
    }

    func roadConnectionMask(at point: GridPoint) -> Int {
        var mask = 0
        if city.roadNetwork.contains(GridPoint(x: point.x, y: point.y - 1)) { mask |= 1 }
        if city.roadNetwork.contains(GridPoint(x: point.x + 1, y: point.y)) { mask |= 2 }
        if city.roadNetwork.contains(GridPoint(x: point.x, y: point.y + 1)) { mask |= 4 }
        if city.roadNetwork.contains(GridPoint(x: point.x - 1, y: point.y)) { mask |= 8 }
        return mask
    }

    func drawFertileGrass(
        at point: GridPoint,
        center: CGPoint,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        context: inout GraphicsContext
    ) {
        if let grass = originalMap?.baseLandSprite(x: point.x, y: point.y) {
            let scale = tileWidth / 80 * 1.10
            let drawWidth = CGFloat(grass.width) * scale
            let drawHeight = CGFloat(grass.height) * scale
            context.draw(
                Image(decorative: grass.image, scale: 1),
                in: CGRect(
                    x: center.x - drawWidth * 0.5,
                    y: center.y + tileHeight * 0.5 - drawHeight,
                    width: drawWidth,
                    height: drawHeight
                )
            )
        }
    }

    func isPlainFertileLand(_ terrain: TerrainFlags) -> Bool {
        terrain.contains(.fertile)
            && terrain.intersection([
                .tree, .rock, .water, .building, .road, .flood,
                .elevation, .irrigation, .wall, .beach, .quarry,
                .saltMarsh, .offMap, .pinnacle, .deepWater, .monument
            ]).isEmpty
    }

    func drawOriginalSprite(
        _ sprite: RenderedTerrainSprite,
        center: CGPoint,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        context: inout GraphicsContext
    ) {
        let scale = tileWidth / 80
        let drawWidth = CGFloat(sprite.width) * scale
        let drawHeight = CGFloat(sprite.height) * scale
        context.draw(
            Image(decorative: sprite.image, scale: 1),
            in: CGRect(
                x: center.x - drawWidth * 0.5,
                y: center.y + tileHeight * 0.5 - drawHeight,
                width: drawWidth,
                height: drawHeight
            )
        )
    }

    func unresolvedLandBedSprite(
        at point: GridPoint,
        originalMap: RenderedMap
    ) -> RenderedTerrainSprite? {
        guard let flags = city.terrain?.terrain(at: point),
              !flags.contains(.water),
              !flags.contains(.deepWater),
              !flags.contains(.offMap),
              !flags.contains(.elevation),
              !flags.contains(.rock),
              !flags.contains(.pinnacle) else { return nil }
        return originalMap.baseLandSprite(x: point.x, y: point.y)
    }

}
