import AppKit
import SwiftUI
import EmperorCore

/// A building (or house) selected in inspect mode, resolved into the info
/// popup. `Equatable` so SwiftUI can drive the popover/panel presentation.
enum InspectedTarget: Equatable {
    case placed(PlacedBuilding)
    case house(ResidentialUnit)
}
struct IsometricTileHitShape: Shape {
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
struct CanvasRightClickMonitor: NSViewRepresentable {
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

final class ConstructionCancelMonitorView: NSView {
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
