import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// A building (or house) selected in inspect mode, resolved into the info
/// popup. `Equatable` so SwiftUI can drive the popover/panel presentation.
enum InspectedTarget: Equatable {
    case placed(PlacedBuilding)
    case house(ResidentialUnit)
}

private struct IsometricTileHitShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Observes secondary clicks without becoming the hit-test target. The event
/// is consumed so a right-click performs one direct game action instead of
/// also opening a system context menu.
private struct CanvasRightClickMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let cursor: NSCursor?
    let onPointerMoved: (CGPoint?) -> Void
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> ConstructionCancelMonitorView {
        let view = ConstructionCancelMonitorView()
        view.isEnabled = isEnabled
        view.interactionCursor = cursor
        view.onPointerMoved = onPointerMoved
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(
        _ nsView: ConstructionCancelMonitorView,
        context: Context
    ) {
        nsView.isEnabled = isEnabled
        nsView.interactionCursor = cursor
        nsView.onPointerMoved = onPointerMoved
        nsView.onRightClick = onRightClick
    }
}

private final class ConstructionCancelMonitorView: NSView {
    var isEnabled = false
    var interactionCursor: NSCursor? {
        didSet {
            window?.invalidateCursorRects(for: self)
            applyInteractionCursorIfNeeded()
        }
    }
    var onPointerMoved: (CGPoint?) -> Void = { _ in }
    var onRightClick: () -> Void = {}
    private var eventMonitor: Any?
    private var pointerWasInside = false
    private var isApplyingInteractionCursor = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeEventMonitor()
        guard let window else { return }
        window.acceptsMouseMovedEvents = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .mouseMoved,
                .leftMouseDown,
                .leftMouseDragged,
                .rightMouseDown,
                .rightMouseDragged,
                .cursorUpdate,
            ]
        ) { [weak self] event in
            guard let self, event.window === self.window else {
                return event
            }
            let location = self.convert(event.locationInWindow, from: nil)
            let isInside = self.bounds.contains(location)
            self.updatePointer(location: location, isInside: isInside)
            guard event.type == .rightMouseDown,
                  self.isEnabled,
                  isInside else {
                return event
            }
            self.onRightClick()
            return nil
        }
        window.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if let interactionCursor {
            addCursorRect(bounds, cursor: interactionCursor)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    deinit {
        removeEventMonitor()
    }

    private func updatePointer(location: CGPoint, isInside: Bool) {
        if isInside {
            pointerWasInside = true
            onPointerMoved(
                CGPoint(
                    x: location.x,
                    y: bounds.height - location.y
                )
            )
            if let interactionCursor {
                interactionCursor.set()
                isApplyingInteractionCursor = true
            } else if isApplyingInteractionCursor {
                NSCursor.arrow.set()
                isApplyingInteractionCursor = false
            }
            DispatchQueue.main.async { [weak self] in
                self?.applyInteractionCursorIfNeeded()
            }
        } else if pointerWasInside {
            pointerWasInside = false
            onPointerMoved(nil)
            if isApplyingInteractionCursor {
                NSCursor.arrow.set()
                isApplyingInteractionCursor = false
            }
        }
    }

    private func applyInteractionCursorIfNeeded() {
        guard pointerWasInside else { return }
        if let interactionCursor {
            interactionCursor.set()
            isApplyingInteractionCursor = true
        } else if isApplyingInteractionCursor {
            NSCursor.arrow.set()
            isApplyingInteractionCursor = false
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
        if pointerWasInside {
            pointerWasInside = false
            onPointerMoved(nil)
        }
        if isApplyingInteractionCursor {
            NSCursor.arrow.set()
            isApplyingInteractionCursor = false
        }
    }
}

struct CityCanvas: View {
    let city: DeterministicCityState
    let buildingSprites: [BuildingSpriteReference: RenderedTerrainSprite]
    let interfaceSprites: [Int: RenderedTerrainSprite]
    let figureSprites: [FigureSpriteReference: RenderedTerrainSprite]
    let originalMap: RenderedMap?
    let constructionTool: NativeConstructionTool
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
    @State private var hoveredMapPoint: GridPoint?
    @State private var canvasHoverLocation: CGPoint?
    @State private var draggedPlacementPoints: [GridPoint] = []
    @State private var isDraggingCanvas = false
    @State private var canvasDragStartOffsetX: Int?
    @State private var canvasDragStartOffsetY: Int?
    @State private var inspectedTarget: InspectedTarget?
    @State private var edgeScrollDirectionX = 0
    @State private var edgeScrollDirectionY = 0
    @State private var edgeScrollStartedAt: Date?
    @State private var pointerEventSequence = 0
    @State private var lastPointerLocation: CGPoint?
    private let edgeScrollTimer = Timer.publish(
        every: 0.18,
        on: .main,
        in: .common
    ).autoconnect()

    private struct Viewport {
        let startX: Int
        let startY: Int
        let columns: Int
        let rows: Int

        func contains(_ point: GridPoint) -> Bool {
            point.x >= startX && point.x < startX + columns
                && point.y >= startY && point.y < startY + rows
        }
    }

    private struct RenderMetrics {
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

    private struct BuildingRenderItem {
        let buildingReference: BuildingSpriteReference?
        let figureReference: FigureSpriteReference?
        let mapOrigin: GridPoint
        let previousMapOrigin: GridPoint?
        let footprint: BuildingFootprint
        let usesLegacyHouseAnchor: Bool
        let isFigure: Bool
        let stableOrder: Int

        var farDepth: Int {
            mapOrigin.x + mapOrigin.y + footprint.width + footprint.height - 2
        }
    }

    private var activeConstructionBuildingID: Int? {
        constructionTool == .farmland
            ? agriculturalCrop.plotBuildingID
            : constructionTool.buildingID
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
                            movementProgress: movementProgress(at: timeline.date)
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
                                    draggedPlacementPoints = areaPlacementPoints(
                                        from: start,
                                        to: end
                                    )
                                } else {
                                    updateCameraForCanvasDrag(
                                        translation: value.translation,
                                        canvasSize: geometry.size
                                    )
                                }
                            }
                            .onEnded { value in
                                isDraggingCanvas = false
                                if constructionTool.supportsDragPlacement {
                                    let points: [GridPoint]
                                    if let start = mapPoint(
                                        at: value.startLocation,
                                        size: geometry.size
                                    ),
                                       let end = mapPoint(
                                        at: value.location,
                                        size: geometry.size
                                       ) {
                                        points = areaPlacementPoints(
                                            from: start,
                                            to: end
                                        )
                                    } else {
                                        points = draggedPlacementPoints
                                    }
                                    draggedPlacementPoints = []
                                    resetCanvasDragBaseline()
                                    if !points.isEmpty {
                                        onPlaceConstructionArea(points)
                                    }
                                    return
                                }
                                draggedPlacementPoints = []
                                updateCameraForCanvasDrag(
                                    translation: value.translation,
                                    canvasSize: geometry.size
                                )
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
                        draggedPlacementPoints = []
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
                guard !isDraggingCanvas, let canvasHoverLocation else {
                    resetEdgeScrollDelay()
                    return
                }
                scrollCameraAtEdge(
                    location: canvasHoverLocation,
                    canvasSize: geometry.size
                )
            }
            .overlay(alignment: .bottomTrailing) {
                if showsNavigationOverlay {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 5) {
                            cameraPanButton(
                                identifier: "city-pan-west",
                                systemImage: "arrow.left",
                                label: "视野向西",
                                deltaX: -8,
                                deltaY: 0
                            )
                            cameraPanButton(
                                identifier: "city-pan-north",
                                systemImage: "arrow.up",
                                label: "视野向北",
                                deltaX: 0,
                                deltaY: -8
                            )
                            cameraPanButton(
                                identifier: "city-pan-south",
                                systemImage: "arrow.down",
                                label: "视野向南",
                                deltaX: 0,
                                deltaY: 8
                            )
                            cameraPanButton(
                                identifier: "city-pan-east",
                                systemImage: "arrow.right",
                                label: "视野向东",
                                deltaX: 8,
                                deltaY: 0
                            )
                        }
                        minimap
                    }
                    .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let inspectedTarget {
                    BuildingInfoPopup(
                        target: inspectedTarget,
                        city: city,
                        models: models,
                        onSettingChange: onBuildingSettingChange,
                        onClose: { self.inspectedTarget = nil }
                    )
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                } else if constructionTool == .inspect,
                          let hoveredMapPoint,
                          let hoveredTarget = inspectedTarget(at: hoveredMapPoint) {
                    BuildingHoverStatusCard(
                        target: hoveredTarget,
                        city: city,
                        models: models
                    )
                    .padding(10)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.12), value: inspectedTarget)
            .animation(.easeOut(duration: 0.08), value: hoveredMapPoint)
        }
    }

    private func canvasAccessibilityValue(
        size: CGSize,
        globalFrame: CGRect
    ) -> String {
        let metrics = renderMetrics(for: size)
        let hover = hoveredMapPoint.map { "\($0.x),\($0.y)" } ?? "none"
        let lastPointer = lastPointerLocation.map { "\($0.x),\($0.y)" } ?? "none"
        return "startX=\(metrics.viewport.startX);startY=\(metrics.viewport.startY);columns=\(metrics.viewport.columns);rows=\(metrics.viewport.rows);mapWidth=\(city.roadNetwork.width);mapHeight=\(city.roadNetwork.height);tileWidth=\(metrics.tileWidth);tileHeight=\(metrics.tileHeight);originX=\(metrics.origin.x);originY=\(metrics.origin.y);globalX=\(globalFrame.minX);globalY=\(globalFrame.minY);globalWidth=\(globalFrame.width);globalHeight=\(globalFrame.height);hover=\(hover);pointerEvents=\(pointerEventSequence);lastPointer=\(lastPointer)"
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
            cameraOffsetX += deltaX
            cameraOffsetY += deltaY
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
        let edgeWidth = min(52, max(28, min(canvasSize.width, canvasSize.height) * 0.06))

        func signedSpeed(nearMinimum value: CGFloat, maximum: CGFloat) -> Int {
            if value <= edgeWidth { return -1 }
            if value >= maximum - edgeWidth { return 1 }
            return 0
        }

        let screenX = signedSpeed(nearMinimum: location.x, maximum: canvasSize.width)
        let screenY = signedSpeed(nearMinimum: location.y, maximum: canvasSize.height)
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
            return
        }
        guard let edgeScrollStartedAt,
              now.timeIntervalSince(edgeScrollStartedAt) >= 0.48 else { return }

        // Camera offsets use map axes, while the trigger zones are screen
        // edges. Convert the requested screen motion through the inverse
        // isometric basis so corners scroll diagonally as expected.
        let mapDX = screenX + screenY
        let mapDY = screenY - screenX
        moveViewportBy(deltaX: mapDX, deltaY: mapDY)
    }

    private func updateCameraForCanvasDrag(
        translation: CGSize,
        canvasSize: CGSize
    ) {
        if canvasDragStartOffsetX == nil {
            canvasDragStartOffsetX = cameraOffsetX
            canvasDragStartOffsetY = cameraOffsetY
        }
        guard let startX = canvasDragStartOffsetX,
              let startY = canvasDragStartOffsetY else { return }
        let metrics = renderMetrics(for: canvasSize)
        let mapDX = Int((
            translation.width / metrics.tileWidth
                + translation.height / metrics.tileHeight
        ).rounded())
        let mapDY = Int((
            -translation.width / metrics.tileWidth
                + translation.height / metrics.tileHeight
        ).rounded())
        cameraOffsetX = startX - mapDX
        cameraOffsetY = startY - mapDY
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
    }

    private func moveViewportBy(deltaX: Int, deltaY: Int) {
        let current = viewport
        let maximumStartX = max(0, city.roadNetwork.width - current.columns)
        let maximumStartY = max(0, city.roadNetwork.height - current.rows)
        let targetStartX = min(max(0, current.startX + deltaX), maximumStartX)
        let targetStartY = min(max(0, current.startY + deltaY), maximumStartY)
        guard targetStartX != current.startX || targetStartY != current.startY else { return }
        cameraOffsetX = targetStartX + current.columns / 2 - baseFocus.x
        cameraOffsetY = targetStartY + current.rows / 2 - baseFocus.y
    }

    private func drawCity(
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

    private func movementProgress(at date: Date) -> CGFloat {
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

    private func renderMetrics(for size: CGSize) -> RenderMetrics {
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
            let focusColumn = CGFloat(viewport.columns / 2)
            let focusRow = CGFloat(viewport.rows / 2)
            origin = CGPoint(
                x: size.width * 0.5 - (focusColumn - focusRow) * tileWidth * 0.5,
                y: size.height * 0.5 - (focusColumn + focusRow) * tileHeight * 0.5
            )
        } else {
            let availableWidth = size.width - CGFloat(36)
            let fittedWidth = availableWidth * CGFloat(2)
                / CGFloat(viewport.columns + viewport.rows)
            tileWidth = min(CGFloat(52), max(CGFloat(8), fittedWidth))
            origin = CGPoint(x: size.width * 0.5, y: 82)
        }
        return RenderMetrics(
            viewport: viewport,
            tileWidth: tileWidth,
            tileHeight: tileWidth * CGFloat(0.5),
            origin: origin
        )
    }

    private func mapPoint(at location: CGPoint, size: CGSize) -> GridPoint? {
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
    private func inspectedTarget(at point: GridPoint) -> InspectedTarget? {
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

    private func demolitionHighlightPoints(at point: GridPoint) -> [GridPoint] {
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

    private func areaPlacementPoints(from start: GridPoint, to end: GridPoint) -> [GridPoint] {
        switch constructionTool {
        case .road, .cityWall:
            let horizontal = inclusiveValues(from: start.x, to: end.x).map {
                GridPoint(x: $0, y: start.y)
            }
            let vertical = inclusiveValues(from: start.y, to: end.y).dropFirst().map {
                GridPoint(x: end.x, y: $0)
            }
            return horizontal + vertical
        case .house:
            return inclusiveValues(from: start.y, to: end.y, step: 2).flatMap { y in
                inclusiveValues(from: start.x, to: end.x, step: 2).map { x in
                    GridPoint(x: x, y: y)
                }
            }
        case .demolish, .clearLand:
            let minimumX = min(start.x, end.x)
            let maximumX = max(start.x, end.x)
            let minimumY = min(start.y, end.y)
            let maximumY = max(start.y, end.y)
            return (minimumY...maximumY).flatMap { y in
                (minimumX...maximumX).map { GridPoint(x: $0, y: y) }
            }
        default:
            return [start]
        }
    }

    private func inclusiveValues(from start: Int, to end: Int, step: Int = 1) -> [Int] {
        let signedStep = start <= end ? max(1, step) : -max(1, step)
        var result: [Int] = []
        var value = start
        while signedStep > 0 ? value <= end : value >= end {
            result.append(value)
            value += signedStep
        }
        return result
    }

    private func drawPlacementHighlight(
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

    private func constructionPreviewComponents(
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

    private func drawConstructionPreview(
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

    private func placementIsValid(at point: GridPoint) -> Bool {
        switch constructionTool {
        case .inspect: false
        case .demolish: city.canDemolish(at: point)
        case .clearLand: city.canClearVegetation(at: point)
        case .road: city.canConstructRoad(at: point)
        case .roadblock: city.canConstructRoadBlock(at: point)
        case .rally: city.canIssueMilitaryOrder(to: point)
        case .grandCanalSegment: city.canAdvanceGrandCanalSegment(at: point)
        case .largePalacePhase: city.canAdvanceLargePalacePhase(at: point)
        case .house: city.canConstructHouse(at: point)
        case .eliteHouse: city.canConstructHouse(at: point)
        case .farmland:
            city.canConstructAgriculturalPlot(crop: agriculturalCrop, at: point)
        case .garden, .decorativeSculpture, .ornateSculpture, .floweringTree,
             .waysidePavilion, .pond, .taiChiPark, .privateGarden,
             .laborersCamp, .carpentersGuild, .masonsGuild, .ceramistsGuild,
             .tumulus, .grandTumulus, .greatTemple, .splendidTemple, .grandPagoda,
             .largePalace:
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

    private func drawPlacedBuildingFootprints(
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
    private func drawRuinFootprint(
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

    private func tileDiamond(center: CGPoint, tileWidth: CGFloat, tileHeight: CGFloat) -> Path {
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
    private var baseFocus: GridPoint {
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

    private var viewport: Viewport {
        let columns = min(city.roadNetwork.width, originalMap == nil ? 12 : 32)
        let rows = min(city.roadNetwork.height, originalMap == nil ? 9 : 32)
        let focus = GridPoint(
            x: baseFocus.x + cameraOffsetX,
            y: baseFocus.y + cameraOffsetY
        )
        let startX = min(
            max(0, focus.x - columns / 2),
            max(0, city.roadNetwork.width - columns)
        )
        let startY = min(
            max(0, focus.y - rows / 2),
            max(0, city.roadNetwork.height - rows)
        )
        return Viewport(startX: startX, startY: startY, columns: columns, rows: rows)
    }

    /// Recentre the main viewport on a map tile chosen from the minimap by
    /// deriving the camera offset that makes `baseFocus + offset == target`.
    private func jumpCamera(to target: GridPoint) {
        let playableTarget = nearestPlayablePoint(to: target)
        cameraOffsetX = playableTarget.x - baseFocus.x
        cameraOffsetY = playableTarget.y - baseFocus.y
    }

    /// Map archives mark their inaccessible storage border with water-like
    /// flags. A minimap click there should snap to the nearest real terrain
    /// cell instead of centring the camera on the hidden border.
    private func nearestPlayablePoint(to target: GridPoint) -> GridPoint {
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
    private var minimap: some View {
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

    private func distanceSquared(_ lhs: GridPoint, _ rhs: GridPoint) -> Int {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private func drawGround(
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
                let drewOriginalTerrain = drawOriginalTerrain(
                    at: mapPoint,
                    center: center,
                    tileWidth: tileWidth,
                    tileHeight: tileHeight,
                    context: &context
                )
                if !drewOriginalTerrain {
                    context.stroke(diamond, with: .color(.black.opacity(0.16)), lineWidth: 0.5)
                }
                if drewOriginalTerrain,
                   city.roadNetwork.contains(mapPoint),
                   originalMap?.map.terrain(at: mapPoint)?.contains(.road) != true {
                    if let roadSprite = originalMap?.roadSprite(
                        connectionMask: roadConnectionMask(at: mapPoint)
                    ) {
                        drawOriginalSprite(
                            roadSprite,
                            center: center,
                            tileWidth: tileWidth,
                            tileHeight: tileHeight,
                            context: &context
                        )
                    } else {
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
    }

    /// Paints semi-transparent coloured diamonds over tiles that hold an active
    /// resource deposit (食物/木材/石材/粘土), reading the terrain flags directly
    /// from `city.terrain`.
    private func drawResourceOverlays(
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
    private func drawServiceCoverageOverlays(
        context: inout GraphicsContext,
        viewport: Viewport,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint
    ) {
        let activeServiceLayers = ResourceOverlayKind.serviceCases.filter {
            activeResourceOverlays.contains($0)
        }
        guard !activeServiceLayers.isEmpty else { return }
        let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2)
            ?? BuildingFootprint(width: 2, height: 2)

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

    private func drawOriginalTerrain(
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

    private func roadConnectionMask(at point: GridPoint) -> Int {
        var mask = 0
        if city.roadNetwork.contains(GridPoint(x: point.x, y: point.y - 1)) { mask |= 1 }
        if city.roadNetwork.contains(GridPoint(x: point.x + 1, y: point.y)) { mask |= 2 }
        if city.roadNetwork.contains(GridPoint(x: point.x, y: point.y + 1)) { mask |= 4 }
        if city.roadNetwork.contains(GridPoint(x: point.x - 1, y: point.y)) { mask |= 8 }
        return mask
    }

    private func drawFertileGrass(
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

    private func isPlainFertileLand(_ terrain: TerrainFlags) -> Bool {
        terrain.contains(.fertile)
            && terrain.intersection([
                .tree, .rock, .water, .building, .road, .flood,
                .elevation, .irrigation, .wall, .beach, .quarry,
                .saltMarsh, .offMap, .pinnacle, .deepWater, .monument
            ]).isEmpty
    }

    private func drawOriginalSprite(
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

    private func unresolvedLandBedSprite(
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

    private func drawRenderableBuildings(
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport,
        movementProgress: CGFloat
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
                quayWaterEdge: city.quayWaterEdge(for: placement)
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

    private func tutorialFigureRenderItems(in viewport: Viewport) -> [BuildingRenderItem] {
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
        return items
    }

    /// Straight wall pieces automatically follow their live neighbours. This
    /// keeps joins coherent after demolition or after a span is replaced by a
    /// gate/tower, without changing the save's authored construction facing.
    private func connectedWallOrientation(
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

    private func hasRenderableComponents(_ placement: PlacedBuilding) -> Bool {
        let components = OriginalBuildingSpriteCatalog.buildingComponents(
            forBuildingID: placement.buildingID,
            orientation: placement.orientation,
            quayWaterEdge: city.quayWaterEdge(for: placement)
        )
        return !components.isEmpty
            && components.allSatisfy { buildingSprites[$0.sprite] != nil }
    }

    private func drawWalkers(
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

    private func drawWalkerHighlights(
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

    private func drawOperationsFailures(
        context: inout GraphicsContext,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        origin: CGPoint,
        viewport: Viewport
    ) {
        for failure in city.operations.lastSettlement?.failures ?? [] {
            if failure.kind == .fire,
               let sprite = buildingSprites[BuildingSpriteReference(
                archiveBaseName: OriginalBuildingSpriteCatalog.generalArchiveBaseName,
                imageID: OriginalBuildingSpriteCatalog.operationsFireImageID
               )] {
                let center = point(
                    at: failure.location,
                    tileWidth: tileWidth,
                    tileHeight: tileHeight,
                    origin: origin,
                    viewport: viewport
                )
                let scale = tileWidth / CGFloat(80)
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
                continue
            }
            // Collapse leaves a persistent #161 placement. Its rubble bed is
            // rendered with the other placed buildings instead of a text marker.
        }
    }

    private func drawIndustry(
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

    private func agricultureMarkerLabel(_ crop: AgriculturalCrop) -> String {
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

    private func drawMarker(
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

    private func point(
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

    private func interpolatedScreenPoint(
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

// MARK: - Minimap

/// Consistent dot colours for the minimap: terrain green, roads gray, water
/// blue, rock gray, and buildings coloured by placement category.
private enum MinimapColors {
    static let terrain = Color(red: 0.48, green: 0.57, blue: 0.20)
    static let shallowWater = Color(red: 0.16, green: 0.43, blue: 0.46)
    static let deepWater = Color(red: 0.08, green: 0.27, blue: 0.34)
    static let shoreline = Color(red: 0.48, green: 0.43, blue: 0.25)
    static let offMap = Color(red: 0.09, green: 0.08, blue: 0.06)
    static let rock = Color(red: 0.51, green: 0.40, blue: 0.28)
    static let road = Color(red: 0.76, green: 0.67, blue: 0.43)
    static let house = Color(red: 0.94, green: 0.58, blue: 0.16)

    static func category(_ category: PlacedBuildingCategory) -> Color {
        switch category {
        case .production: .brown
        case .warehouse: .indigo
        case .mill: .yellow
        case .market: .green
        case .trading: .teal
        case .residentialService: .pink
        case .military: .red
        case .aesthetic: .purple
        }
    }
}

/// Bottom-right minimap (160×120pt). Renders the whole map as coloured dots and
/// overlays a white rectangle for the current camera viewport. Clicking or
/// dragging invokes `onJump` with the chosen map tile so the main camera can
/// recenter on it.
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
            let scaleX = size.width / CGFloat(mapWidth)
            let scaleY = size.height / CGFloat(mapHeight)

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.black.opacity(0.55))
            )

            let buildingColors = buildingColorByPoint()
            for y in 0..<mapHeight {
                for x in 0..<mapWidth {
                    let mapPoint = GridPoint(x: x, y: y)
                    // +0.5 overlap hides seams between tiny per-tile dots.
                    let rect = CGRect(
                        x: CGFloat(x) * scaleX,
                        y: CGFloat(y) * scaleY,
                        width: scaleX + 0.5,
                        height: scaleY + 0.5
                    )
                    context.fill(
                        Path(rect),
                        with: .color(tileColor(mapPoint, buildingColors: buildingColors))
                    )
                }
            }

            let viewportRect = CGRect(
                x: CGFloat(viewportStartX) * scaleX,
                y: CGFloat(viewportStartY) * scaleY,
                width: CGFloat(viewportColumns) * scaleX,
                height: CGFloat(viewportRows) * scaleY
            )
            context.fill(Path(viewportRect), with: .color(Color.white.opacity(0.10)))
            context.stroke(
                Path(viewportRect.insetBy(dx: -1.5, dy: -1.5)),
                with: .color(Color(red: 0.82, green: 0.13, blue: 0.08)),
                lineWidth: 3
            )
            context.stroke(Path(viewportRect), with: .color(.white), lineWidth: 1.2)
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
        let mapX = min(
            max(0, Int(location.x / minimapSize.width * CGFloat(mapWidth))),
            mapWidth - 1
        )
        let mapY = min(
            max(0, Int(location.y / minimapSize.height * CGFloat(mapHeight))),
            mapHeight - 1
        )
        onJump(GridPoint(x: mapX, y: mapY))
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

// MARK: - Building info popup

/// Compact, non-interactive status shown while the pointer rests on a
/// building in browse mode. Houses surface the exact next-month upgrade
/// blockers; clicking still opens the complete inspector.
private struct BuildingHoverStatusCard: View {
    let target: InspectedTarget
    let city: DeterministicCityState
    let models: OriginalEconomyModels

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: target.isHouse ? "house.fill" : "building.2.fill")
                    .foregroundStyle(EmperorTheme.primary)
                Text(title)
                    .font(EmperorTheme.headlineSmall)
                    .foregroundStyle(EmperorTheme.onSurface)
            }
            Text(summary)
                .font(EmperorTheme.bodySmall)
                .foregroundStyle(summaryColor)
                .fixedSize(horizontal: false, vertical: true)
            if !details.isEmpty {
                Divider().overlay(EmperorTheme.border.opacity(0.55))
                ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                    Label(detail, systemImage: "xmark.circle.fill")
                        .font(EmperorTheme.labelMedium)
                        .foregroundStyle(EmperorTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("左键或右键查看详情")
                .font(EmperorTheme.caption)
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
        }
        .padding(10)
        .frame(width: 272, alignment: .leading)
        .background(EmperorTheme.surfaceDeep.opacity(0.94))
        .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("building-hover-status")
        .accessibilityLabel(title)
        .accessibilityValue(([summary] + details).joined(separator: "；"))
    }

    private var title: String {
        switch target {
        case let .placed(placement):
            NativeConstructionTool.allCases.first {
                $0.buildingID == placement.buildingID
            }?.title ?? models.buildings[buildingID: placement.buildingID]
                .map { ClassicTextLocalization.authoredName($0.name) }
                ?? "建筑 #\(placement.buildingID)"
        case let .house(house):
            models.buildings[houseLevelID: house.houseLevelID]
                .map { ClassicTextLocalization.houseName($0.name) }
                ?? "住宅"
        }
    }

    private var summary: String {
        switch target {
        case .placed:
            return "右键可调整建筑设置"
        case let .house(house):
            guard house.residents > 0 else {
                return "尚未入住；有居民后才会在月末评估升级"
            }
            guard let evaluation = evaluation(for: house) else {
                return "当前住宅资料不足，暂时无法评估升级"
            }
            guard let nextLevelID = evaluation.nextLevelID else {
                return "已达到当前住宅序列的最高等级"
            }
            let nextName = models.buildings[houseLevelID: nextLevelID]
                .map { ClassicTextLocalization.houseName($0.name) }
                ?? "等级 #\(nextLevelID)"
            if evaluation.missingEvolutionRequirements.isEmpty {
                return "条件已满足，将在下次月结升级为 \(nextName)"
            }
            return "暂时不能升级为 \(nextName)"
        }
    }

    private var summaryColor: Color {
        switch target {
        case .placed:
            return EmperorTheme.onSurfaceMuted
        case let .house(house):
            guard let evaluation = evaluation(for: house),
                  evaluation.nextLevelID != nil else {
                return EmperorTheme.onSurfaceMuted
            }
            return evaluation.missingEvolutionRequirements.isEmpty
                ? EmperorTheme.success
                : EmperorTheme.warning
        }
    }

    private var details: [String] {
        guard case let .house(house) = target,
              let evaluation = evaluation(for: house) else { return [] }
        return evaluation.missingEvolutionRequirements.map {
            houseEvolutionRequirementDescription($0, models: models)
        }
    }

    private func evaluation(for house: ResidentialUnit) -> HouseEvolutionEvaluation? {
        DeterministicHousingEvolution.evaluate(
            house: house,
            models: models.buildings,
            difficulty: city.difficulty
        )
    }
}

/// Floating inspector panel shown when a building or house is clicked in
/// inspect mode. Resolves category-specific detail: production buildings show
/// their recipe output, warehouses show storage, service buildings show their
/// service type, and houses show level/residents.
struct BuildingInfoPopup: View {
    let target: InspectedTarget
    let city: DeterministicCityState
    let models: OriginalEconomyModels
    let onSettingChange: (NativeBuildingSettingChange) -> Void
    let onClose: () -> Void

    private struct InfoRow {
        let label: String
        let value: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(EmperorTheme.headlineSmall)
                        .foregroundStyle(EmperorTheme.primary)
                    Text(subtitle)
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            Divider().overlay(EmperorTheme.border)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                LabeledContent(row.label, value: row.value)
                    .font(EmperorTheme.bodySmall)
            }
            operationControls
        }
        .padding(14)
        .frame(width: 272, alignment: .leading)
        .foregroundStyle(EmperorTheme.onSurface)
        .background(EmperorTheme.surface)
        .overlay(
            Rectangle()
                .strokeBorder(EmperorTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }

    private var title: String {
        switch target {
        case let .placed(placement):
            chineseBuildingName(placement.buildingID)
        case .house:
            "住宅"
        }
    }

    private var subtitle: String {
        switch target {
        case let .placed(placement):
            placement.buildingID == 126
                ? "道路控制设施 · 建筑ID 126"
                : "\(categoryLabel(placement.category)) · 建筑ID \(placement.buildingID)"
        case let .house(house):
            "民居 · 等级ID \(house.houseLevelID)"
        }
    }

    private var rows: [InfoRow] {
        switch target {
        case let .placed(placement):
            placedRows(placement)
        case let .house(house):
            houseRows(house)
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        if case let .placed(placement) = target {
            switch placement.category {
            case .production:
                if let building = city.production.buildings.first(where: {
                    $0.id == placement.instanceID
                }) {
                    Divider()
                    settingHeader
                    Button {
                        onSettingChange(.productionEnabled(
                            instanceID: placement.instanceID,
                            enabled: !building.isEnabled
                        ))
                    } label: {
                        Label(
                            building.isEnabled ? "暂停生产" : "恢复生产",
                            systemImage: building.isEnabled ? "pause.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            case .warehouse:
                Divider()
                settingHeader
                Menu {
                    warehousePolicyButton("接收货物", policy: .accept, placement: placement)
                    warehousePolicyButton("拒收货物", policy: .doNotAccept, placement: placement)
                    warehousePolicyButton("主动调取", policy: .get, placement: placement)
                } label: {
                    Label("统一仓储模式", systemImage: "shippingbox.fill")
                        .frame(maxWidth: .infinity)
                }
                if let warehouse = city.logistics.warehouses.first(where: {
                    $0.id == placement.instanceID
                }) {
                    DisclosureGroup {
                        ScrollView {
                            LazyVStack(spacing: 5) {
                                ForEach(models.trade.commodities) { commodity in
                                    HStack(spacing: 6) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(ClassicTextLocalization.commodityName(commodity.name))
                                                .lineLimit(1)
                                            Text("库存 \(warehouse.inventoryByCommodityID[commodity.id, default: 0] / 100)")
                                                .font(EmperorTheme.labelSmall)
                                                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                                        }
                                        Spacer(minLength: 4)
                                        Menu {
                                            warehouseCommodityPolicyButton(
                                                "接收",
                                                policy: .accept,
                                                warehouseID: placement.instanceID,
                                                commodityID: commodity.id
                                            )
                                            warehouseCommodityPolicyButton(
                                                "拒收",
                                                policy: .doNotAccept,
                                                warehouseID: placement.instanceID,
                                                commodityID: commodity.id
                                            )
                                            warehouseCommodityPolicyButton(
                                                "调取",
                                                policy: .get,
                                                warehouseID: placement.instanceID,
                                                commodityID: commodity.id
                                            )
                                        } label: {
                                            Text(warehousePolicyTitle(
                                                warehouse.policy(for: commodity.id)
                                            ))
                                                .frame(minWidth: 58, alignment: .trailing)
                                        }
                                        .menuStyle(.borderlessButton)
                                    }
                                    .font(EmperorTheme.bodySmall)
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    } label: {
                        Label("按商品设置", systemImage: "slider.horizontal.3")
                            .font(EmperorTheme.bodySmall)
                    }
                }
            case .trading:
                if let trading = city.trade.buildings.first(where: {
                    $0.id == placement.instanceID
                }) {
                    let isEnabled = !trading.importingCommodityIDs.isEmpty
                        || !trading.exportingCommodityIDs.isEmpty
                    Divider()
                    settingHeader
                    Button {
                        onSettingChange(.tradeEnabled(
                            tradingBuildingID: placement.instanceID,
                            enabled: !isEnabled
                        ))
                    } label: {
                        Label(
                            isEnabled ? "暂停进出口" : "恢复进出口",
                            systemImage: isEnabled ? "pause.fill" : "arrow.left.arrow.right"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    private var settingHeader: some View {
        Text("操作模式")
            .font(EmperorTheme.bold(size: 12))
            .foregroundStyle(.secondary)
    }

    private func warehousePolicyButton(
        _ title: String,
        policy: WarehouseCommodityPolicy,
        placement: PlacedBuilding
    ) -> some View {
        Button(title) {
            onSettingChange(.warehousePolicy(
                warehouseID: placement.instanceID,
                policy: policy
            ))
        }
    }

    private func warehouseCommodityPolicyButton(
        _ title: String,
        policy: WarehouseCommodityPolicy,
        warehouseID: Int,
        commodityID: Int
    ) -> some View {
        Button(title) {
            onSettingChange(.warehouseCommodityPolicy(
                warehouseID: warehouseID,
                commodityID: commodityID,
                policy: policy
            ))
        }
    }

    private func warehousePolicyTitle(_ policy: WarehouseCommodityPolicy) -> String {
        switch policy {
        case .doNotAccept: "拒收"
        case .accept: "接收"
        case .get: "调取"
        }
    }

    private func placedRows(_ placement: PlacedBuilding) -> [InfoRow] {
        var rows: [InfoRow] = [
            InfoRow(label: "建筑ID", value: "\(placement.buildingID)"),
            InfoRow(
                label: "类型",
                value: placement.buildingID == 126
                    ? "道路控制设施"
                    : categoryLabel(placement.category)
            ),
            InfoRow(label: "占地", value: "\(placement.footprint.width)×\(placement.footprint.height)"),
            InfoRow(
                label: "道路接入点",
                value: "(\(placement.roadAccessPoint.x), \(placement.roadAccessPoint.y))"
            )
        ]
        if let assignment = city.workforceAssignment(
            for: placement,
            models: models.buildings
        ), assignment.requiredWorkers > 0 {
            rows.append(InfoRow(
                label: "劳工",
                value: "\(assignment.assignedWorkers)/\(assignment.requiredWorkers) 人"
            ))
            if !assignment.isFullyStaffed {
                rows.append(InfoRow(label: "运行状态", value: "缺少劳工，设施暂停"))
            }
        }

        switch placement.category {
        case .production:
            if let building = city.production.buildings.first(where: { $0.id == placement.instanceID }) {
                rows.append(InfoRow(
                    label: "操作模式",
                    value: building.isEnabled ? "运行" : "暂停"
                ))
                if let agriculture = building.agriculture {
                    let cropName = models.trade[
                        commodityID: agriculture.crop.outputCommodityID
                    ].map {
                        ClassicTextLocalization.commodityName($0.name)
                    } ?? ClassicTextLocalization.commodityName(agriculture.crop.rawValue)
                    rows.append(InfoRow(label: "作物", value: cropName))
                    rows.append(InfoRow(label: "田块", value: "\(agriculture.fieldCount) 块"))
                } else if let recipe = OriginalProductionCatalog.recipe(forBuildingID: placement.buildingID) {
                    let outputName = models.trade[commodityID: recipe.outputCommodityID]
                        .map { ClassicTextLocalization.commodityName($0.name) }
                        ?? "商品 #\(recipe.outputCommodityID)"
                    rows.append(InfoRow(label: "配方产出", value: "\(outputName) ×\(recipe.outputAmount / 100)"))
                }
                let stored = building.outputInventoryByCommodityID.values.reduce(0, +)
                rows.append(InfoRow(label: "待运库存", value: "\(stored / 100) 车"))
            } else {
                rows.append(InfoRow(label: "劳工", value: "未投产"))
            }
        case .warehouse:
            if let warehouse = city.logistics.warehouses.first(where: { $0.id == placement.instanceID }) {
                rows.append(
                    InfoRow(
                        label: "仓储",
                        value: "\(warehouse.storedAmount / 100)/\(warehouse.capacity / 100) 车"
                    )
                )
                let kinds = warehouse.inventoryByCommodityID.values.filter { $0 > 0 }.count
                rows.append(InfoRow(label: "存货种类", value: "\(kinds) 种"))
            } else {
                rows.append(InfoRow(label: "仓储", value: "—"))
            }
        case .mill:
            if let mill = city.logistics.mills.first(where: { $0.id == placement.instanceID }) {
                rows.append(InfoRow(label: "磨坊储粮", value: "\(mill.storedAmount / 100) 车"))
            } else {
                rows.append(InfoRow(label: "磨坊储粮", value: "—"))
            }
        case .market:
            rows.append(InfoRow(label: "职能", value: "向住宅配送食物与商品"))
        case .trading:
            rows.append(InfoRow(label: "职能", value: "陆海贸易集散"))
            if let trading = city.trade.buildings.first(where: {
                $0.id == placement.instanceID
            }) {
                let enabled = !trading.importingCommodityIDs.isEmpty
                    || !trading.exportingCommodityIDs.isEmpty
                rows.append(InfoRow(label: "操作模式", value: enabled ? "进出口开启" : "暂停"))
            }
        case .residentialService:
            if let service = city.residentialServiceBuildings.first(where: { $0.id == placement.instanceID }) {
                rows.append(InfoRow(label: "服务类型", value: service.service.chineseTitle))
            }
        case .military:
            if let fort = city.military.forts.first(where: { $0.id == placement.instanceID }),
               let unit = city.military.units.first(where: { $0.id == fort.unitID }) {
                let figure = models.figures[figureID: unit.figureID]
                rows.append(InfoRow(
                    label: "部队",
                    value: figure.map {
                        ClassicTextLocalization.authoredName($0.name)
                    } ?? "人物 #\(unit.figureID)"
                ))
                rows.append(InfoRow(
                    label: "兵力",
                    value: "\(unit.survivingSoldiers(model: figure))/\(unit.originalSoldierCount) 人"
                ))
                let status = switch unit.status {
                case .garrisoned: "驻防"
                case .marching: "行军"
                case .victorious: "获胜"
                case .destroyed: "覆灭"
                }
                rows.append(InfoRow(label: "状态", value: status))
                rows.append(InfoRow(label: "士气", value: "\(unit.morale)"))
            } else if let defense = city.military.defensiveStructures.first(where: {
                $0.id == placement.instanceID
            }) {
                let kind = switch defense.kind {
                case .cityWall: "城墙"
                case .cityGate: "城门"
                case .tower: "城防塔"
                }
                rows.append(InfoRow(label: "防御类型", value: kind))
                rows.append(InfoRow(
                    label: "耐久",
                    value: "\(defense.integrity)/\(defense.maximumIntegrity)"
                ))
                rows.append(InfoRow(
                    label: "哨兵",
                    value: "\(city.military.sentries.filter { $0.defenseID == defense.id }.count) 人"
                ))
            }
        case .aesthetic:
            if placement.buildingID == 126 {
                rows.append(InfoRow(label: "用途", value: "阻止无目的漫游人员通过"))
                rows.append(InfoRow(label: "放行", value: "采购、运输、移民等目的性人员"))
                break
            }
            if let construction = city.aesthetics.constructions.first(where: {
                $0.id == placement.instanceID
            }) {
                let purpose = switch construction.kind {
                case .scenery: "景观美化"
                case .irrigationPump: "灌溉水车"
                case .laborersCamp: "劳工营"
                case .carpentersGuild: "木匠行会"
                case .masonsGuild: "石匠行会"
                case .ceramistsGuild: "陶工行会"
                case .monument: "纪念建筑"
                }
                rows.append(InfoRow(label: "用途", value: purpose))
            }
            if let project = city.aesthetics.monuments.first(where: {
                $0.id == placement.instanceID
            }) {
                rows.append(InfoRow(label: "工程进度", value: "\(project.completionPercent)%"))
                rows.append(InfoRow(
                    label: "施工量",
                    value: "\(project.completedWork)/\(project.requiredWork)"
                ))
            }
            if let evaluation = city.fengShuiSummary(models: models.buildings)
                .evaluations.first(where: { $0.buildingKey.instanceID == placement.instanceID
                    && $0.buildingKey.category == .aesthetic }) {
                let quality = switch evaluation.quality {
                case .neutral: "中性"
                case .harmonious: "和谐"
                case .inauspicious: "不吉"
                }
                rows.append(InfoRow(label: "风水", value: quality))
            }
        }
        return rows
    }

    private func houseRows(_ house: ResidentialUnit) -> [InfoRow] {
        var rows: [InfoRow] = [
            InfoRow(label: "等级ID", value: "\(house.houseLevelID)"),
            InfoRow(label: "居民", value: "\(house.residents) 人"),
            InfoRow(label: "占地", value: "2×2"),
            InfoRow(label: "朝向", value: house.orientation.localizedTitle),
            InfoRow(label: "税务覆盖", value: house.hasTaxCoverage ? "是" : "否")
        ]
        if house.footprintMultiplier > 1 {
            rows.append(InfoRow(label: "合并户数", value: "\(house.footprintMultiplier)"))
        }
        if let levelName = models.buildings[houseLevelID: house.houseLevelID]?.name {
            rows.insert(
                InfoRow(
                    label: "等级名称",
                    value: ClassicTextLocalization.houseName(levelName)
                ),
                at: 1
            )
        }
        if let location = house.location {
            rows.append(InfoRow(label: "位置", value: "(\(location.x), \(location.y))"))
        }
        if house.residents == 0 {
            rows.append(InfoRow(label: "升级状态", value: "尚未入住"))
        } else if let evaluation = DeterministicHousingEvolution.evaluate(
            house: house,
            models: models.buildings,
            difficulty: city.difficulty
        ) {
            if let nextLevelID = evaluation.nextLevelID {
                let nextName = models.buildings[houseLevelID: nextLevelID]
                    .map { ClassicTextLocalization.houseName($0.name) }
                    ?? "等级 #\(nextLevelID)"
                rows.append(InfoRow(label: "下一等级", value: nextName))
            } else {
                rows.append(InfoRow(label: "升级状态", value: "已达最高等级"))
            }
            if evaluation.missingEvolutionRequirements.isEmpty,
               evaluation.nextLevelID != nil {
                rows.append(InfoRow(label: "升级状态", value: "条件已满足，等待月结"))
            } else if !evaluation.missingEvolutionRequirements.isEmpty {
                rows.append(InfoRow(
                    label: "升级缺口",
                    value: evaluation.missingEvolutionRequirements
                        .map {
                            houseEvolutionRequirementDescription($0, models: models)
                        }
                        .joined(separator: "、")
                ))
            }
        } else {
            rows.append(InfoRow(
                label: "升级状态",
                value: "当前住宅资料不足"
            ))
        }
        return rows
    }

    /// Chinese display name for a building ID, preferring the construction-tool
    /// title (all Chinese) and falling back to the original model name.
    private func chineseBuildingName(_ buildingID: Int) -> String {
        if let tool = NativeConstructionTool.allCases.first(where: { $0.buildingID == buildingID }) {
            return tool.title
        }
        return models.buildings[buildingID: buildingID]
            .map { ClassicTextLocalization.authoredName($0.name) }
            ?? "建筑 #\(buildingID)"
    }

    private func categoryLabel(_ category: PlacedBuildingCategory) -> String {
        switch category {
        case .production: "生产建筑"
        case .warehouse: "仓库"
        case .mill: "磨坊"
        case .market: "市场"
        case .trading: "贸易建筑"
        case .residentialService: "市政服务"
        case .military: "军事设施"
        case .aesthetic: "美化/纪念建筑"
        }
    }
}

private extension InspectedTarget {
    var isHouse: Bool {
        if case .house = self { return true }
        return false
    }
}

private func houseEvolutionRequirementDescription(
    _ requirement: HouseEvolutionRequirement,
    models: OriginalEconomyModels
) -> String {
    switch requirement {
    case let .desirability(current, required):
        "宜居度 \(current)/\(required)"
    case let .service(service):
        "缺\(service.chineseTitle)"
    case let .foodQuality(current, required):
        "食物品质 \(current)/\(required)"
    case let .commodityAlternatives(ids):
        "缺" + ids.map {
            models.trade[commodityID: $0]
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? "商品 #\($0)"
        }
            .joined(separator: "或")
    }
}
