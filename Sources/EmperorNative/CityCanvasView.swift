import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct CityCanvas: View {
    let city: DeterministicCityState
    let buildingSprites: [BuildingSpriteReference: RenderedTerrainSprite]
    let interfaceSprites: [Int: RenderedTerrainSprite]
    let figureSprites: [FigureSpriteReference: RenderedTerrainSprite]
    let originalMap: RenderedMap?
    let greatWallKind: OriginalGreatWallLayoutCatalog.WallKind?
    let constructionTool: NativeConstructionTool
    let selectedTradePartnerID: Int?
    let agriculturalCrop: AgriculturalCrop
    let constructionOrientation: IsometricBuildingOrientation
    let models: OriginalEconomyModels
    let activeResourceOverlays: Set<ResourceOverlayKind>
    let selectedMilitaryUnitIDs: Set<Int>
    let gameSpeed: Int
    let lastTickPresentationDate: Date
    let onPlaceConstruction: (GridPoint) -> Void
    let onPlaceConstructionArea: ([GridPoint]) -> Void
    let onCancelInteraction: () -> Void
    let onBuildingSettingChange: (NativeBuildingSettingChange) -> Void
    @Binding var cameraOffsetX: Int
    @Binding var cameraOffsetY: Int
    let showsNavigationOverlay: Bool
    @State var hoveredMapPoint: GridPoint?
    @State private var canvasHoverLocation: CGPoint?
    @State var draggedPlacementPoints: [GridPoint] = []
    @State private var dragPlacementStart: GridPoint?
    @State private var isDraggingCanvas = false
    @State private var canvasDragStartOffsetX: Double?
    @State private var canvasDragStartOffsetY: Double?
    @State private var inspectedTarget: InspectedTarget?
    @State private var edgeScrollDirectionX = 0
    @State private var edgeScrollDirectionY = 0
    @State private var edgeScrollStartedAt: Date?
    @State private var lastEdgeScrollTick: Date?
    @State var cameraPositionX: Double?
    @State var cameraPositionY: Double?
    @State private var lastPublishedCameraOffsetX: Int?
    @State private var lastPublishedCameraOffsetY: Int?
    @State private var pointerEventSequence = 0
    @State private var lastPointerLocation: CGPoint?
    private let edgeScrollTimer = Timer.publish(
        every: 1.0 / 30.0,
        on: .main,
        in: .common
    ).autoconnect()

    struct Viewport {
        let startX: Int
        let startY: Int
        let columns: Int
        let rows: Int

        func contains(_ point: GridPoint) -> Bool {
            point.x >= startX && point.x < startX + columns
                && point.y >= startY && point.y < startY + rows
        }
    }

    struct RenderMetrics {
        let viewport: Viewport
        let tileWidth: CGFloat
        let tileHeight: CGFloat
        let origin: CGPoint

        var projection: IsometricViewportProjection {
            IsometricViewportProjection(
                startX: viewport.startX,
                startY: viewport.startY,
                tileWidth: Double(tileWidth),
                tileHeight: Double(tileHeight),
                originX: Double(origin.x),
                originY: Double(origin.y)
            )
        }
    }

    struct BuildingRenderItem {
        let buildingReference: BuildingSpriteReference?
        let figureReference: FigureSpriteReference?
        let mapOrigin: GridPoint
        let previousMapOrigin: GridPoint?
        let footprint: BuildingFootprint
        let usesLegacyHouseAnchor: Bool
        let isFigure: Bool
        let isMillAnimationOverlay: Bool
        let sourceTopLeftOffsetX: Int?
        let sourceTopLeftOffsetY: Int?
        let stableOrder: Int

        init(
            buildingReference: BuildingSpriteReference?,
            figureReference: FigureSpriteReference?,
            mapOrigin: GridPoint,
            previousMapOrigin: GridPoint?,
            footprint: BuildingFootprint,
            usesLegacyHouseAnchor: Bool,
            isFigure: Bool,
            isMillAnimationOverlay: Bool = false,
            sourceTopLeftOffsetX: Int? = nil,
            sourceTopLeftOffsetY: Int? = nil,
            stableOrder: Int
        ) {
            self.buildingReference = buildingReference
            self.figureReference = figureReference
            self.mapOrigin = mapOrigin
            self.previousMapOrigin = previousMapOrigin
            self.footprint = footprint
            self.usesLegacyHouseAnchor = usesLegacyHouseAnchor
            self.isFigure = isFigure
            self.isMillAnimationOverlay = isMillAnimationOverlay
            self.sourceTopLeftOffsetX = sourceTopLeftOffsetX
            self.sourceTopLeftOffsetY = sourceTopLeftOffsetY
            self.stableOrder = stableOrder
        }

        var farDepth: Int {
            mapOrigin.x + mapOrigin.y + footprint.width + footprint.height - 2
        }
    }

    var activeConstructionBuildingID: Int? {
        if constructionTool.marketShopBuildingID != nil { return nil }
        if constructionTool == .cropFarm { return agriculturalCrop.producerBuildingID }
        if constructionTool == .farmland { return agriculturalCrop.plotBuildingID }
        return constructionTool.buildingID
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TimelineView(
                    .animation(minimumInterval: 1.0 / 60.0, paused: gameSpeed == 0)
                ) { timeline in
                    Canvas { context, size in
                        drawCity(
                            context: &context,
                            size: size,
                            movementProgress: movementProgress(at: timeline.date),
                            fireAnimationFrame: Int(
                                timeline.date.timeIntervalSinceReferenceDate * 12
                            ) % 50
                        )
                    }
                }
                .allowsHitTesting(false)

                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                isDraggingCanvas = true
                                if constructionTool.supportsDragPlacement {
                                    guard let start = mapPoint(
                                        at: value.startLocation,
                                        size: geometry.size
                                    ),
                                    let end = mapPoint(
                                        at: value.location,
                                        size: geometry.size
                                    ) else { return }
                                    updateDraggedPlacement(from: start, to: end)
                                } else if constructionTool == .inspect {
                                    updateCameraForCanvasDrag(
                                        translation: value.translation,
                                        canvasSize: geometry.size
                                    )
                                }
                            }
                            .onEnded { value in
                                isDraggingCanvas = false
                                if constructionTool.supportsDragPlacement {
                                    if let start = dragPlacementStart ?? mapPoint(
                                        at: value.startLocation,
                                        size: geometry.size
                                    ),
                                       let end = mapPoint(
                                        at: value.location,
                                        size: geometry.size
                                       ) {
                                        updateDraggedPlacement(from: start, to: end)
                                    }
                                    let points = draggedPlacementPoints
                                    resetDraggedPlacement()
                                    resetCanvasDragBaseline()
                                    if !points.isEmpty {
                                        onPlaceConstructionArea(points)
                                    }
                                    return
                                }
                                draggedPlacementPoints = []
                                if constructionTool == .inspect {
                                    updateCameraForCanvasDrag(
                                        translation: value.translation,
                                        canvasSize: geometry.size
                                    )
                                }
                                resetCanvasDragBaseline()
                            }
                    )
                    .simultaneousGesture(
                        SpatialTapGesture().onEnded { value in
                            if isUISmokeMode {
                                pointerEventSequence += 1
                                lastPointerLocation = value.location
                            }
                            guard let point = mapPoint(
                                at: value.location,
                                size: geometry.size
                            ) else { return }
                            if constructionTool == .inspect {
                                inspectedTarget = inspectedTarget(at: point)
                            } else {
                                onPlaceConstruction(point)
                            }
                        }
                    )
                if isUISmokeMode {
                    Color.black.opacity(0.001)
                        .allowsHitTesting(false)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("城市画布坐标")
                        .accessibilityIdentifier("city-canvas-metrics")
                        .accessibilityValue(
                            canvasAccessibilityValue(
                                size: geometry.size,
                                globalFrame: geometry.frame(in: .global)
                            )
                        )
                        .accessibilityHint(
                            canvasAccessibilityValue(
                                size: geometry.size,
                                globalFrame: geometry.frame(in: .global)
                            )
                        )
                    uiSmokeTileTargets(size: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay {
                CanvasRightClickMonitor(
                    isEnabled: true,
                    cursor: constructionCursor,
                    onPointerMoved: { location in
                        canvasHoverLocation = location
                        hoveredMapPoint = location.flatMap {
                            mapPoint(at: $0, size: geometry.size)
                        }
                        if location == nil {
                            resetEdgeScrollDelay()
                        }
                    }
                ) {
                    if constructionTool == .inspect {
                        inspectedTarget = hoveredMapPoint.flatMap {
                            inspectedTarget(at: $0)
                        }
                    } else {
                        resetDraggedPlacement()
                        isDraggingCanvas = false
                        resetCanvasDragBaseline()
                        inspectedTarget = nil
                        resetEdgeScrollDelay()
                        onCancelInteraction()
                    }
                }
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: isUISmokeMode ? .contain : .ignore)
            .accessibilityLabel("可拖拽并可点击建造的原版任务等距城市画布")
            .accessibilityIdentifier("city-canvas")
            .accessibilityValue(
                canvasAccessibilityValue(
                    size: geometry.size,
                    globalFrame: geometry.frame(in: .global)
                )
            )
            .accessibilityHint(
                canvasAccessibilityValue(
                    size: geometry.size,
                    globalFrame: geometry.frame(in: .global)
                )
            )
            .onReceive(edgeScrollTimer) { _ in
                // The smoke harness drives map tiles through accessibility and
                // separately validates the edge-scroll transform in core tests.
                // Suppress timer-driven camera drift only for that synthetic run.
                guard !isUISmokeMode,
                      let canvasHoverLocation,
                      !isDraggingCanvas || constructionTool.supportsDragPlacement else {
                    resetEdgeScrollDelay()
                    return
                }
                scrollCameraAtEdge(
                    location: canvasHoverLocation,
                    canvasSize: geometry.size
                )
                if isDraggingCanvas,
                   constructionTool.supportsDragPlacement,
                   let start = dragPlacementStart,
                   let end = mapPoint(at: canvasHoverLocation, size: geometry.size) {
                    hoveredMapPoint = end
                    updateDraggedPlacement(from: start, to: end)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showsNavigationOverlay {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 5) {
                            cameraPanButton(
                                identifier: "city-pan-west",
                                systemImage: "arrow.left",
                                label: "视野向西",
                                deltaX: -4,
                                deltaY: 4
                            )
                            cameraPanButton(
                                identifier: "city-pan-north",
                                systemImage: "arrow.up",
                                label: "视野向北",
                                deltaX: -4,
                                deltaY: -4
                            )
                            cameraPanButton(
                                identifier: "city-pan-south",
                                systemImage: "arrow.down",
                                label: "视野向南",
                                deltaX: 4,
                                deltaY: 4
                            )
                            cameraPanButton(
                                identifier: "city-pan-east",
                                systemImage: "arrow.right",
                                label: "视野向东",
                                deltaX: 4,
                                deltaY: -4
                            )
                        }
                        minimap
                    }
                    .padding(10)
                }
            }
            .overlay(alignment: .topLeading) {
                if let inspectedTarget {
                    BuildingInfoPopup(
                        target: inspectedTarget,
                        city: city,
                        models: models,
                        onSettingChange: onBuildingSettingChange,
                        onClose: { self.inspectedTarget = nil }
                    )
                    .padding(10)
                    .transition(.opacity)
                }
            }
            .onAppear {
                synchronizeCameraPositionFromBindings()
            }
            .onChange(of: cameraOffsetX) { value in
                guard value != lastPublishedCameraOffsetX else { return }
                cameraPositionX = Double(value)
            }
            .onChange(of: cameraOffsetY) { value in
                guard value != lastPublishedCameraOffsetY else { return }
                cameraPositionY = Double(value)
            }
            .onChange(of: constructionTool) { _ in
                resetDraggedPlacement()
                isDraggingCanvas = false
                inspectedTarget = nil
            }
        }
    }

    private func updateDraggedPlacement(from start: GridPoint, to end: GridPoint) {
        if dragPlacementStart == nil {
            dragPlacementStart = start
        }
        switch constructionTool {
        case .road, .cityWall:
            if draggedPlacementPoints.isEmpty {
                draggedPlacementPoints = ConstructionDragPlanner.orthogonalSegment(
                    from: start,
                    to: end
                )
            } else {
                draggedPlacementPoints = ConstructionDragPlanner.appendingOrthogonalSegment(
                    to: draggedPlacementPoints,
                    endingAt: end
                )
            }
        default:
            draggedPlacementPoints = areaPlacementPoints(from: start, to: end)
        }
    }

    private func resetDraggedPlacement() {
        draggedPlacementPoints = []
        dragPlacementStart = nil
    }

    private func canvasAccessibilityValue(
        size: CGSize,
        globalFrame: CGRect
    ) -> String {
        let metrics = renderMetrics(for: size)
        let hover = hoveredMapPoint.map { "\($0.x),\($0.y)" } ?? "none"
        let lastPointer = lastPointerLocation.map { "\($0.x),\($0.y)" } ?? "none"
        let placement: String
        if constructionTool == .inspect || constructionTool == .rally {
            placement = "none"
        } else if let hoveredMapPoint {
            placement = placementIsValid(at: hoveredMapPoint) ? "valid" : "invalid"
        } else {
            placement = "none"
        }
        return "startX=\(metrics.viewport.startX);startY=\(metrics.viewport.startY);columns=\(metrics.viewport.columns);rows=\(metrics.viewport.rows);mapWidth=\(city.roadNetwork.width);mapHeight=\(city.roadNetwork.height);tileWidth=\(metrics.tileWidth);tileHeight=\(metrics.tileHeight);originX=\(metrics.origin.x);originY=\(metrics.origin.y);globalX=\(globalFrame.minX);globalY=\(globalFrame.minY);globalWidth=\(globalFrame.width);globalHeight=\(globalFrame.height);hover=\(hover);placement=\(placement);dragCount=\(draggedPlacementPoints.count);pointerEvents=\(pointerEventSequence);lastPointer=\(lastPointer)"
    }

    private var isUISmokeMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-smoke-fixed-window")
    }

    private func uiSmokeTileTargets(size: CGSize) -> some View {
        let metrics = renderMetrics(for: size)
        let points = (0..<metrics.viewport.rows).flatMap { row in
            (0..<metrics.viewport.columns).map { column in
                GridPoint(
                    x: metrics.viewport.startX + column,
                    y: metrics.viewport.startY + row
                )
            }
        }.filter { point in
            let center = metrics.projection.screenPoint(for: point)
            return center.x >= 0 && center.x <= size.width
                && center.y >= 0 && center.y <= size.height
        }
        return ForEach(points, id: \.self) { point in
            let center = metrics.projection.screenPoint(for: point)
            Button {
                pointerEventSequence += 1
                lastPointerLocation = CGPoint(x: center.x, y: center.y)
                if constructionTool == .inspect {
                    inspectedTarget = inspectedTarget(at: point)
                } else {
                    onPlaceConstruction(point)
                }
            } label: {
                Color.black.opacity(0.001)
            }
            .buttonStyle(.plain)
            .frame(width: metrics.tileWidth, height: metrics.tileHeight)
            .contentShape(IsometricTileHitShape())
            .position(x: center.x, y: center.y)
            .accessibilityLabel("地图格 \(point.x),\(point.y)")
            .accessibilityIdentifier("city-tile-\(point.x)-\(point.y)")
        }
    }

    private func cameraPanButton(
        identifier: String,
        systemImage: String,
        label: String,
        deltaX: Int,
        deltaY: Int
    ) -> some View {
        Button {
            applyCameraDelta(x: Double(deltaX), y: Double(deltaY))
        } label: {
            Image(systemName: systemImage)
                .frame(width: 22, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func scrollCameraAtEdge(location: CGPoint, canvasSize: CGSize) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        let direction = IsometricEdgeScrollPolicy.screenDirection(
            pointerX: Double(location.x),
            pointerY: Double(location.y),
            viewportWidth: Double(canvasSize.width),
            viewportHeight: Double(canvasSize.height)
        )
        let screenX = Int(direction.x)
        let screenY = Int(direction.y)
        guard screenX != 0 || screenY != 0 else {
            resetEdgeScrollDelay()
            return
        }

        let directionX = screenX.signum()
        let directionY = screenY.signum()
        let now = Date()
        if directionX != edgeScrollDirectionX || directionY != edgeScrollDirectionY {
            edgeScrollDirectionX = directionX
            edgeScrollDirectionY = directionY
            edgeScrollStartedAt = now
            lastEdgeScrollTick = now
            return
        }
        guard let edgeScrollStartedAt,
              now.timeIntervalSince(edgeScrollStartedAt)
                >= IsometricEdgeScrollPolicy.activationDelay else {
            lastEdgeScrollTick = now
            return
        }
        let elapsed = min(1.0 / 15.0, now.timeIntervalSince(lastEdgeScrollTick ?? now))
        lastEdgeScrollTick = now
        let metrics = renderMetrics(for: canvasSize)
        let delta = IsometricEdgeScrollPolicy.mapDelta(
            for: direction,
            elapsed: elapsed,
            tileWidth: Double(metrics.tileWidth),
            tileHeight: Double(metrics.tileHeight)
        )
        applyCameraDelta(x: delta.x, y: delta.y)
    }

    private func updateCameraForCanvasDrag(
        translation: CGSize,
        canvasSize: CGSize
    ) {
        if canvasDragStartOffsetX == nil {
            canvasDragStartOffsetX = effectiveCameraOffsetX
            canvasDragStartOffsetY = effectiveCameraOffsetY
        }
        guard let startX = canvasDragStartOffsetX,
              let startY = canvasDragStartOffsetY else { return }
        let metrics = renderMetrics(for: canvasSize)
        let mapDX = Double(
            translation.width / metrics.tileWidth
                + translation.height / metrics.tileHeight
        )
        let mapDY = Double(
            -translation.width / metrics.tileWidth
                + translation.height / metrics.tileHeight
        )
        setCameraPosition(x: startX - mapDX, y: startY - mapDY)
    }

    private func resetCanvasDragBaseline() {
        canvasDragStartOffsetX = nil
        canvasDragStartOffsetY = nil
    }

    private var constructionCursor: NSCursor? {
        guard constructionTool == .clearLand,
              let imageID = OriginalInterfaceUtilitySpriteCatalog.imageID(
                for: .clearLand
              ),
              let sprite = interfaceSprites[imageID] else {
            return nil
        }
        let pixelWidth = CGFloat(max(1, sprite.image.width))
        let pixelHeight = CGFloat(max(1, sprite.image.height))
        let scale = min(1, 40 / max(pixelWidth, pixelHeight))
        let size = NSSize(
            width: pixelWidth * scale,
            height: pixelHeight * scale
        )
        let image = NSImage(cgImage: sprite.image, size: size)
        return NSCursor(
            image: image,
            hotSpot: NSPoint(
                x: size.width * 0.5,
                y: min(size.height - 1, size.height * 0.10)
            )
        )
    }

    private func resetEdgeScrollDelay() {
        edgeScrollDirectionX = 0
        edgeScrollDirectionY = 0
        edgeScrollStartedAt = nil
        lastEdgeScrollTick = nil
    }

    var effectiveCameraOffsetX: Double {
        cameraPositionX ?? Double(cameraOffsetX)
    }

    var effectiveCameraOffsetY: Double {
        cameraPositionY ?? Double(cameraOffsetY)
    }

    private func synchronizeCameraPositionFromBindings() {
        cameraPositionX = Double(cameraOffsetX)
        cameraPositionY = Double(cameraOffsetY)
        lastPublishedCameraOffsetX = cameraOffsetX
        lastPublishedCameraOffsetY = cameraOffsetY
    }

    private func applyCameraDelta(x: Double, y: Double) {
        setCameraPosition(
            x: effectiveCameraOffsetX + x,
            y: effectiveCameraOffsetY + y
        )
    }

    func setCameraPosition(x: Double, y: Double) {
        let columns = min(city.roadNetwork.width, originalMap == nil ? 12 : 32)
        let rows = min(city.roadNetwork.height, originalMap == nil ? 9 : 32)
        let minimumFocusX = Double(columns) * 0.5
        let minimumFocusY = Double(rows) * 0.5
        let maximumFocusX = max(minimumFocusX, Double(city.roadNetwork.width) - minimumFocusX)
        let maximumFocusY = max(minimumFocusY, Double(city.roadNetwork.height) - minimumFocusY)
        let clampedX = min(max(x, minimumFocusX - Double(baseFocus.x)), maximumFocusX - Double(baseFocus.x))
        let clampedY = min(max(y, minimumFocusY - Double(baseFocus.y)), maximumFocusY - Double(baseFocus.y))
        cameraPositionX = clampedX
        cameraPositionY = clampedY

        let publishedX = Int(clampedX.rounded())
        let publishedY = Int(clampedY.rounded())
        lastPublishedCameraOffsetX = publishedX
        lastPublishedCameraOffsetY = publishedY
        if cameraOffsetX != publishedX { cameraOffsetX = publishedX }
        if cameraOffsetY != publishedY { cameraOffsetY = publishedY }
    }

}
