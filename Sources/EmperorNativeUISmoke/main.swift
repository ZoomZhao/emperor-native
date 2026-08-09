import AppKit
import ApplicationServices
import EmperorCore
import EmperorGameplay
import Foundation

private enum SmokeExit {
    static let usage: Int32 = 64
    static let data: Int32 = 66
    static let software: Int32 = 70
    static let accessibility: Int32 = 77
    static let timeout: Int32 = 124
}

private struct Arguments {
    let appURL: URL
    let logDirectory: URL
    let timeout: TimeInterval
    let snapshotLibrary: Bool
    let snapshotQin: Bool

    init() throws {
        let values = Array(CommandLine.arguments.dropFirst())
        func value(after option: String) -> String? {
            guard let index = values.firstIndex(of: option), values.indices.contains(index + 1) else {
                return nil
            }
            return values[index + 1]
        }
        guard let appPath = value(after: "--app") else {
            throw SmokeFailure(
                "usage: emperor-ui-smoke --app /path/EmperorNative.app "
                    + "[--log-dir path] [--timeout seconds] "
                    + "[--snapshot-library | --snapshot-qin]",
                code: SmokeExit.usage
            )
        }
        appURL = URL(fileURLWithPath: appPath).standardizedFileURL
        logDirectory = URL(fileURLWithPath: value(after: "--log-dir") ?? NSTemporaryDirectory())
            .standardizedFileURL
        timeout = value(after: "--timeout").flatMap(TimeInterval.init) ?? 480
        snapshotLibrary = values.contains("--snapshot-library")
        snapshotQin = values.contains("--snapshot-qin")
    }
}

private struct SmokeFailure: Error {
    let message: String
    let code: Int32

    init(_ message: String, code: Int32 = SmokeExit.software) {
        self.message = message
        self.code = code
    }
}

private final class EvidenceLog {
    let directory: URL
    private let logURL: URL
    private var lines: [String] = []
    private let formatter = ISO8601DateFormatter()

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        logURL = directory.appendingPathComponent("xia1-ui-smoke.log")
    }

    func record(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)"
        lines.append(line)
        print(line)
        try? (lines.joined(separator: "\n") + "\n").write(
            to: logURL,
            atomically: true,
            encoding: .utf8
        )
    }
}

private struct MapClick {
    let toolIdentifier: String
    let point: GridPoint
}

private struct AXFrame {
    let origin: CGPoint
    let size: CGSize

    var rect: CGRect { CGRect(origin: origin, size: size) }
}

private func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
        return nil
    }
    return value
}

private func attributeProbe(_ element: AXUIElement, _ attribute: CFString) -> String {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    let count = (value as? [AXUIElement])?.count
    return "\(attribute)=error(\(result.rawValue)),count=\(count.map(String.init) ?? "n/a"),value=\(String(describing: value))"
}

private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
    copyAttribute(element, attribute) as? String
}

private func boolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
    copyAttribute(element, attribute) as? Bool
}

private func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
    guard let value = copyAttribute(element, attribute),
          CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

private func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? []
}

private func findElement(in application: AXUIElement, identifier: String) -> AXUIElement? {
    let windows = copyAttribute(
        application,
        kAXWindowsAttribute as CFString
    ) as? [AXUIElement] ?? []
    let focusedWindow = elementAttribute(application, kAXFocusedWindowAttribute as CFString)
    let mainWindow = elementAttribute(application, kAXMainWindowAttribute as CFString)
    let contentRoots = children(of: application).filter {
        stringAttribute($0, kAXRoleAttribute as CFString) != kAXMenuBarRole
    }
    var queue = [focusedWindow, mainWindow].compactMap { $0 } + windows + contentRoots
    if queue.isEmpty { queue = [application] }
    var index = 0
    var visited: Set<CFHashCode> = []
    while index < queue.count, index < 12_000 {
        let element = queue[index]
        index += 1
        guard visited.insert(CFHash(element)).inserted else { continue }
        if stringAttribute(element, kAXIdentifierAttribute as CFString) == identifier {
            return element
        }
        queue.append(contentsOf: children(of: element))
    }
    return nil
}

private func findElement(
    in application: AXUIElement,
    role: String,
    title: String
) -> AXUIElement? {
    let windows = copyAttribute(
        application,
        kAXWindowsAttribute as CFString
    ) as? [AXUIElement] ?? []
    var queue = windows + children(of: application)
    var index = 0
    var visited: Set<CFHashCode> = []
    while index < queue.count, index < 12_000 {
        let element = queue[index]
        index += 1
        guard visited.insert(CFHash(element)).inserted else { continue }
        if stringAttribute(element, kAXRoleAttribute as CFString) == role,
           (stringAttribute(element, kAXTitleAttribute as CFString)
                ?? stringAttribute(element, kAXDescriptionAttribute as CFString)) == title {
            return element
        }
        queue.append(contentsOf: children(of: element))
    }
    return nil
}

private func accessibilityIdentifierSnapshot(in application: AXUIElement) -> String {
    let windows = copyAttribute(
        application,
        kAXWindowsAttribute as CFString
    ) as? [AXUIElement] ?? []
    let focusedWindow = elementAttribute(application, kAXFocusedWindowAttribute as CFString)
    let mainWindow = elementAttribute(application, kAXMainWindowAttribute as CFString)
    var queue = [focusedWindow, mainWindow].compactMap { $0 } + windows + [application]
    var index = 0
    var values: [String] = []
    var visited: Set<CFHashCode> = []
    while index < queue.count, index < 12_000, values.count < 120 {
        let element = queue[index]
        index += 1
        guard visited.insert(CFHash(element)).inserted else { continue }
        if let identifier = stringAttribute(element, kAXIdentifierAttribute as CFString),
           !identifier.isEmpty {
            let role = stringAttribute(element, kAXRoleAttribute as CFString) ?? "?"
            let title = stringAttribute(element, kAXTitleAttribute as CFString)
                ?? stringAttribute(element, kAXDescriptionAttribute as CFString)
                ?? ""
            if role != kAXMenuItemRole as String {
                values.append("\(role):\(identifier):\(title)")
            }
        }
        queue.append(contentsOf: children(of: element))
    }
    return values.joined(separator: " | ")
}

private func waitForElement(
    in application: AXUIElement,
    identifier: String,
    timeout: TimeInterval,
    requireEnabled: Bool = true
) throws -> AXUIElement {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if let element = findElement(in: application, identifier: identifier),
           !requireEnabled || boolAttribute(element, kAXEnabledAttribute as CFString) != false {
            return element
        }
        Thread.sleep(forTimeInterval: 0.15)
    } while Date() < deadline
    throw SmokeFailure("timed out waiting for accessibility identifier \(identifier)", code: SmokeExit.timeout)
}

private func parent(of element: AXUIElement) -> AXUIElement? {
    copyAttribute(element, kAXParentAttribute as CFString) as! AXUIElement?
}

private func press(_ identifiedElement: AXUIElement, identifier: String) throws {
    var candidate: AXUIElement? = identifiedElement
    for _ in 0..<6 {
        guard let element = candidate else { break }
        _ = AXUIElementPerformAction(element, "AXScrollToVisible" as CFString)
        if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
            return
        }
        candidate = parent(of: element)
    }
    throw SmokeFailure("accessibility element \(identifier) does not support AXPress")
}

private func revealAdvancedCityControls(in application: AXUIElement) throws {
    if findElement(in: application, identifier: "game-speed-3") != nil { return }
    let toggle = try waitForElement(
        in: application,
        identifier: "city-advanced-controls-toggle",
        timeout: 15
    )
    try press(toggle, identifier: "city-advanced-controls-toggle")
    _ = try waitForElement(
        in: application,
        identifier: "game-speed-3",
        timeout: 15
    )
}

private func axFrame(of element: AXUIElement) -> AXFrame? {
    guard let positionValue = copyAttribute(element, kAXPositionAttribute as CFString),
          let sizeValue = copyAttribute(element, kAXSizeAttribute as CFString),
          CFGetTypeID(positionValue) == AXValueGetTypeID(),
          CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
          AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
    return AXFrame(origin: origin, size: size)
}

private func windowServerFrame(of application: AXUIElement) -> CGRect? {
    var pid: pid_t = 0
    AXUIElementGetPid(application, &pid)
    guard let window = (
        CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]
    )?.first(where: { candidate in
        (candidate[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
            && (candidate[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
    }), let bounds = window[kCGWindowBounds as String] as? [String: Any],
       let x = bounds["X"] as? NSNumber,
       let y = bounds["Y"] as? NSNumber,
       let width = bounds["Width"] as? NSNumber,
       let height = bounds["Height"] as? NSNumber else {
        return nil
    }
    return CGRect(
        x: x.doubleValue,
        y: y.doubleValue,
        width: width.doubleValue,
        height: height.doubleValue
    )
}

private func clickScreenPoint(_ point: CGPoint) throws {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left),
          let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
          let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
        throw SmokeFailure("could not create CGEvent mouse click")
    }
    down.setIntegerValueField(.mouseEventClickState, value: 1)
    up.setIntegerValueField(.mouseEventClickState, value: 1)
    move.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.03)
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.03)
    up.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
}

private func pressKey(_ keyCode: CGKeyCode) throws {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let down = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
          ),
          let up = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: false
          ) else {
        throw SmokeFailure("could not create CGEvent key press")
    }
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.04)
    up.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.1)
}

private func hitTestDescription(
    at point: CGPoint,
    application: AXUIElement
) -> String {
    var hit: AXUIElement?
    let result = AXUIElementCopyElementAtPosition(
        application,
        Float(point.x),
        Float(point.y),
        &hit
    )
    guard result == .success, let hit else {
        return "unavailable(\(result.rawValue))"
    }
    let role = stringAttribute(hit, kAXRoleAttribute as CFString) ?? "unknown-role"
    let identifier = stringAttribute(hit, kAXIdentifierAttribute as CFString) ?? "no-identifier"
    return "\(role):\(identifier)"
}

private func bringToFront(_ application: AXUIElement) {
    var pid: pid_t = 0
    if AXUIElementGetPid(application, &pid) == .success,
       let runningApplication = NSRunningApplication(processIdentifier: pid) {
        runningApplication.unhide()
        runningApplication.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
    _ = AXUIElementSetAttributeValue(
        application,
        kAXFrontmostAttribute as CFString,
        kCFBooleanTrue
    )
    if let window = (copyAttribute(
        application,
        kAXWindowsAttribute as CFString
    ) as? [AXUIElement])?.first {
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }
    Thread.sleep(forTimeInterval: 0.15)
}

private func parsedAccessibilityValue(_ element: AXUIElement) -> [String: Double] {
    guard let value = stringAttribute(element, kAXValueAttribute as CFString)
        ?? stringAttribute(element, kAXHelpAttribute as CFString)
        ?? stringAttribute(element, kAXDescriptionAttribute as CFString) else {
        return [:]
    }
    return Dictionary(uniqueKeysWithValues: value.split(separator: ";").compactMap { pair in
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2, let number = Double(parts[1]) else { return nil }
        return (parts[0], number)
    })
}

private func verticalScrollBar(containing element: AXUIElement) -> AXUIElement? {
    var candidate = parent(of: element)
    var remainingAncestors = 20
    while let current = candidate, remainingAncestors > 0 {
        remainingAncestors -= 1
        if stringAttribute(current, kAXRoleAttribute as CFString) == kAXScrollAreaRole,
           let rawScrollBar = copyAttribute(current, kAXVerticalScrollBarAttribute as CFString),
           CFGetTypeID(rawScrollBar) == AXUIElementGetTypeID() {
            return (rawScrollBar as! AXUIElement)
        }
        candidate = parent(of: current)
    }
    return nil
}

private func setVerticalScroll(
    containing element: AXUIElement,
    value: Double
) -> Bool {
    guard let scrollBar = verticalScrollBar(containing: element) else { return false }
    let result = AXUIElementSetAttributeValue(
        scrollBar,
        kAXValueAttribute as CFString,
        NSNumber(value: min(1, max(0, value)))
    )
    guard result == .success else { return false }
    Thread.sleep(forTimeInterval: 0.12)
    return true
}

private func adjustVerticalScroll(
    containing element: AXUIElement,
    towardBottom: Bool
) -> Bool {
    guard let scrollBar = verticalScrollBar(containing: element) else { return false }
    let currentValue = (copyAttribute(
        scrollBar,
        kAXValueAttribute as CFString
    ) as? NSNumber)?.doubleValue ?? 0
    let nextValue = min(1, max(0, currentValue + (towardBottom ? 0.08 : -0.08)))
    guard nextValue != currentValue else { return false }
    return setVerticalScroll(containing: element, value: nextValue)
}

private func mapPointToScreen(
    _ point: GridPoint,
    application: AXUIElement
) throws -> CGPoint {
    bringToFront(application)
    let deadline = Date().addingTimeInterval(10)
    var lastCanvasValues: [String: Double] = [:]
    var lastCanvasAttributes = "unread"
    repeat {
        let canvas = try waitForElement(
            in: application,
            identifier: "city-canvas-metrics",
            timeout: 1
        )
        let values = parsedAccessibilityValue(canvas)
        lastCanvasValues = values
        lastCanvasAttributes = [
            "value=\(String(describing: copyAttribute(canvas, kAXValueAttribute as CFString)))",
            "description=\(String(describing: copyAttribute(canvas, kAXDescriptionAttribute as CFString)))",
            "title=\(String(describing: copyAttribute(canvas, kAXTitleAttribute as CFString)))",
            "help=\(String(describing: copyAttribute(canvas, kAXHelpAttribute as CFString)))",
        ].joined(separator: ";")
        guard let frame = axFrame(of: canvas),
              let startX = values["startX"], let startY = values["startY"],
              let columns = values["columns"], let rows = values["rows"],
              let tileWidth = values["tileWidth"], let tileHeight = values["tileHeight"],
              let originX = values["originX"], let originY = values["originY"] else {
            Thread.sleep(forTimeInterval: 0.1)
            continue
        }
        let windowOrigin = (
            copyAttribute(application, kAXWindowsAttribute as CFString) as? [AXUIElement]
        )?.first.flatMap(axFrame(of:))?.origin
        var canvasOriginX = frame.origin.x
        var canvasOriginY = frame.origin.y
        if let globalX = values["globalX"], let windowOrigin {
            canvasOriginX = windowOrigin.x + globalX
        }
        if let globalY = values["globalY"], let windowOrigin {
            canvasOriginY = windowOrigin.y + globalY
        }
        let column = Double(point.x) - startX
        let row = Double(point.y) - startY
        let horizontalMargin = min(8.0, columns / 4)
        let verticalMargin = min(8.0, rows / 4)
        let localPoint = CGPoint(
            x: originX + (column - row) * tileWidth / 2,
            y: originY + (column + row) * tileHeight / 2
        )
        let canvasWidth = values["globalWidth"] ?? frame.size.width
        let canvasHeight = values["globalHeight"] ?? frame.size.height
        let screenMarginX = tileWidth / 2
        let screenMarginY = tileHeight / 2
        if column >= horizontalMargin,
           row >= verticalMargin,
           column < columns - horizontalMargin,
           row < rows - verticalMargin,
           localPoint.x >= screenMarginX,
           localPoint.x < canvasWidth - screenMarginX,
           localPoint.y >= screenMarginY,
           localPoint.y < canvasHeight - screenMarginY {
            let screenPoint = CGPoint(
                x: canvasOriginX + localPoint.x,
                y: canvasOriginY + localPoint.y
            )
            let safeDisplayBounds = CGDisplayBounds(CGMainDisplayID())
                .insetBy(dx: 24, dy: 140)
            if screenPoint.y > safeDisplayBounds.maxY,
               adjustVerticalScroll(containing: canvas, towardBottom: true) {
                continue
            }
            if screenPoint.y < safeDisplayBounds.minY,
               adjustVerticalScroll(containing: canvas, towardBottom: false) {
                continue
            }
            return screenPoint
        }
        let maximumStartX = max(0, (values["mapWidth"] ?? columns) - columns)
        let maximumStartY = max(0, (values["mapHeight"] ?? rows) - rows)
        let canPanWest = startX > 0
        let canPanEast = startX < maximumStartX
        let canPanNorth = startY > 0
        let canPanSouth = startY < maximumStartY
        let panIdentifier: String
        if localPoint.x < screenMarginX {
            panIdentifier = canPanWest ? "city-pan-west" : "city-pan-south"
        } else if localPoint.x >= canvasWidth - screenMarginX {
            panIdentifier = canPanEast ? "city-pan-east" : "city-pan-north"
        } else if localPoint.y < screenMarginY {
            panIdentifier = canPanNorth ? "city-pan-north" : "city-pan-west"
        } else if localPoint.y >= canvasHeight - screenMarginY {
            panIdentifier = canPanSouth ? "city-pan-south" : "city-pan-east"
        } else if column < horizontalMargin {
            panIdentifier = canPanWest ? "city-pan-west" : "city-pan-south"
        } else if column >= columns - horizontalMargin {
            panIdentifier = canPanEast ? "city-pan-east" : "city-pan-north"
        } else if row < verticalMargin {
            panIdentifier = canPanNorth ? "city-pan-north" : "city-pan-west"
        } else {
            panIdentifier = canPanSouth ? "city-pan-south" : "city-pan-east"
        }
        let pan = try waitForElement(
            in: application,
            identifier: panIdentifier,
            timeout: 2
        )
        try press(pan, identifier: panIdentifier)
        Thread.sleep(forTimeInterval: 0.1)
    } while Date() < deadline
    throw SmokeFailure(
        "map point \(point.x),\(point.y) did not enter the canvas viewport; "
            + "canvas=\(lastCanvasValues); attributes=\(lastCanvasAttributes)"
    )
}

private func commandStatus(in application: AXUIElement) -> String {
    guard let status = findElement(in: application, identifier: "player-command-status") else {
        return "status unavailable"
    }
    return stringAttribute(status, kAXValueAttribute as CFString)
        ?? stringAttribute(status, kAXDescriptionAttribute as CFString)
        ?? "status unreadable"
}

@discardableResult
private func captureWindow(
    application: AXUIElement,
    to url: URL
) -> Bool {
    var pid: pid_t = 0
    AXUIElementGetPid(application, &pid)
    let accessibilityFrame = (
        copyAttribute(application, kAXWindowsAttribute as CFString) as? [AXUIElement]
    )?.first.flatMap(axFrame(of:))?.rect
    let windowServerWindow = (
        CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
    )?.first(where: { window in
        (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
            && (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
    })
    let image: CGImage?
    if let rawWindowID = windowServerWindow?[kCGWindowNumber as String] as? NSNumber {
        image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(rawWindowID.uint32Value),
            [.bestResolution, .boundsIgnoreFraming]
        )
    } else if let accessibilityFrame {
        image = CGWindowListCreateImage(
            accessibilityFrame,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    } else {
        image = nil
    }
    guard let image,
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        return false
    }
    do {
        try data.write(to: url)
        return true
    } catch {
        return false
    }
}

private func captureFailure(application: AXUIElement, log: EvidenceLog) {
    let url = log.directory.appendingPathComponent("xia1-ui-smoke-failure.png")
    if captureWindow(application: application, to: url) {
        log.record("failure screenshot=\(url.path)")
    } else {
        log.record("failure screenshot unavailable")
    }
}

private func launch(
    _ appURL: URL,
    logDirectory: URL,
    autoStartCampaign: String?
) throws -> NSRunningApplication {
    guard FileManager.default.fileExists(atPath: appURL.path) else {
        throw SmokeFailure("app bundle does not exist: \(appURL.path)", code: SmokeExit.data)
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.addsToRecentItems = false
    configuration.createsNewApplicationInstance = true
    configuration.arguments = [
        "--ui-smoke-fixed-window",
        "--ui-smoke-log-dir", logDirectory.path,
        "--save-directory", logDirectory.appendingPathComponent("saves").path,
    ]
    if autoStartCampaign == "xia" {
        configuration.arguments.append("--ui-smoke-auto-start-xia")
    } else if autoStartCampaign == "qin" {
        configuration.arguments.append("--ui-smoke-auto-start-qin")
    }
    let semaphore = DispatchSemaphore(value: 0)
    var launched: NSRunningApplication?
    var launchError: Error?
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
        launched = app
        launchError = error
        semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + 20) == .success else {
        throw SmokeFailure("app launch timed out", code: SmokeExit.timeout)
    }
    if let launchError { throw SmokeFailure("app launch failed: \(launchError.localizedDescription)") }
    guard let launched else { throw SmokeFailure("workspace returned no running application") }
    launched.unhide()
    launched.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    // Fresh SwiftUI instances can register with LaunchServices before their
    // initial WindowGroup scene is opened on macOS 15. A normal reopen event
    // creates that first window while preserving the launch arguments above.
    _ = NSWorkspace.shared.open(appURL)
    return launched
}

private func commandTable() throws -> [MapClick] {
    let controller = try GameSessionController()
    guard let campaignID = controller.campaignID(
        fileName: "1 Xia Dynasty - Tutorials.pak"
    ) else {
        throw SmokeFailure("Xia tutorial campaign is unavailable", code: SmokeExit.data)
    }
    let start = controller.perform(
        .startCampaignMission(campaignID: campaignID, missionID: 0)
    )
    guard start.wasApplied else {
        throw SmokeFailure("could not prepare Xia tutorial shadow state: \(start.message)")
    }

    var commands: [MapClick] = []

    func place(_ tool: PlayerConstructionTool, count: Int = 1) throws {
        for _ in 0..<count {
            guard let city = controller.city else {
                throw SmokeFailure("shadow city disappeared while planning \(tool.rawValue)")
            }
            let point: GridPoint?
            if tool == .house {
                point = city.nextHouseConstructionLocation()
            } else if OriginalMarketCatalog.supports(shopBuildingID: tool.buildingID ?? -1) {
                point = city.placedBuildings.first(where: {
                    $0.category == .market
                        && city.canConstructMarketShop(
                            shopBuildingID: tool.buildingID ?? -1,
                            at: $0.origin
                        )
                })?.origin
            } else {
                point = tool.buildingID.flatMap {
                    city.nextBuildingConstructionLocation(buildingID: $0)
                }
            }
            guard let point else {
                throw SmokeFailure("no valid UI smoke site for \(tool.rawValue)")
            }
            let select = controller.perform(.selectConstruction(tool))
            guard select.wasApplied else {
                throw SmokeFailure("could not select \(tool.rawValue): \(select.message)")
            }
            let result = controller.perform(
                .placeSelectedConstruction(at: point, orientation: .northSouth)
            )
            guard result.wasApplied else {
                throw SmokeFailure(
                    "could not prepare \(tool.rawValue) at \(point.x),\(point.y): \(result.message)"
                )
            }
            commands.append(MapClick(toolIdentifier: tool.rawValue, point: point))
        }
    }

    try place(.huntingCamp)
    try place(.mill)
    try place(.market)
    try place(.foodShop)
    try place(.well, count: 8)
    try place(.inspectorTower)
    try place(.ancestralShrine, count: 6)
    try place(.house, count: 26)
    return commands
}

private func constructionCategoryIdentifier(for toolIdentifier: String) -> String {
    switch toolIdentifier {
    case "house":
        "residential"
    case "huntingCamp", "mill":
        "agriculture"
    case "market", "foodShop", "hempShop", "ceramicsShop", "teaShop",
         "silkShop", "lacquerwareShop", "bronzewareShop":
        "commerce"
    case "well":
        "safety"
    case "inspectorTower":
        "government"
    case "ancestralShrine":
        "religious"
    default:
        "monuments"
    }
}

private func runSmoke(arguments: Arguments) throws {
    guard AXIsProcessTrusted() else {
        throw SmokeFailure(
            "需要在 系统设置 → 隐私与安全性 → 辅助功能 中授权 emperor-ui-smoke（或启动它的 Codex/终端），然后重试",
            code: SmokeExit.accessibility
        )
    }
    guard FileManager.default.fileExists(atPath: GameDataSource.defaultRoot.path) else {
        throw SmokeFailure("未找到默认原版资料：\(GameDataSource.defaultRoot.path)", code: SmokeExit.data)
    }
    let log = try EvidenceLog(directory: arguments.logDirectory)
    let app = try launch(
        arguments.appURL,
        logDirectory: arguments.logDirectory,
        autoStartCampaign: arguments.snapshotLibrary
            ? nil
            : arguments.snapshotQin ? "qin" : "xia"
    )
    let application = AXUIElementCreateApplication(app.processIdentifier)
    log.record("launched pid=\(app.processIdentifier) app=\(arguments.appURL.path)")
    log.record(
        "initial AX "
            + attributeProbe(application, kAXRoleAttribute as CFString) + " "
            + attributeProbe(application, kAXChildrenAttribute as CFString) + " "
            + attributeProbe(application, kAXWindowsAttribute as CFString)
    )
    defer {
        if !app.isTerminated { app.terminate() }
        log.record("terminated owned pid=\(app.processIdentifier)")
    }
    do {
        if arguments.snapshotLibrary {
            let mapsSection = try waitForElement(
                in: application,
                identifier: "library-section-maps",
                timeout: 30
            )
            try press(mapsSection, identifier: "library-section-maps")
            _ = try waitForElement(
                in: application,
                identifier: "library-map-search",
                timeout: 30
            )
            Thread.sleep(forTimeInterval: 2)
            let screenshotURL = arguments.logDirectory
                .appendingPathComponent("library-ui-smoke.png")
            guard captureWindow(application: application, to: screenshotURL) else {
                throw SmokeFailure("could not capture the classic library window")
            }
            log.record("library screenshot=\(screenshotURL.path)")
            return
        }

        if arguments.snapshotQin {
            _ = try waitForElement(
                in: application,
                identifier: "city-canvas",
                timeout: 45
            )
            let treasury = try waitForElement(
                in: application,
                identifier: "hud-treasury-metric",
                timeout: 15,
                requireEnabled: false
            )
            let treasuryValue = stringAttribute(
                treasury,
                kAXValueAttribute as CFString
            ) ?? stringAttribute(treasury, kAXDescriptionAttribute as CFString) ?? ""
            guard treasuryValue.contains("15000") || treasuryValue.contains("15,000") else {
                throw SmokeFailure(
                    "Qin M1 HUD did not expose the authored treasury: \(treasuryValue)"
                )
            }
            _ = try waitForElement(
                in: application,
                identifier: "hud-zodiac-metric",
                timeout: 15,
                requireEnabled: false
            )
            let originalCategoryOrder = [
                "residential", "agriculture", "industry", "commerce",
                "safety", "government", "entertainment", "religious",
                "military", "aesthetics", "monuments",
            ]
            for category in originalCategoryOrder {
                _ = try waitForElement(
                    in: application,
                    identifier: "construction-category-\(category)",
                    timeout: 15,
                    requireEnabled: false
                )
            }

            let agricultureCategory = try waitForElement(
                in: application,
                identifier: "construction-category-agriculture",
                timeout: 15
            )
            try press(
                agricultureCategory,
                identifier: "construction-category-agriculture"
            )
            let cropElements = try AgriculturalCrop.allCases.map { crop in
                try waitForElement(
                    in: application,
                    identifier: "construction-crop-\(crop.rawValue)",
                    timeout: 15,
                    requireEnabled: false
                )
            }
            let availableCropFrames = cropElements.compactMap { element -> CGRect? in
                guard boolAttribute(element, kAXEnabledAttribute as CFString) != false else {
                    return nil
                }
                return axFrame(of: element)?.rect
            }
            let unavailableCropFrames = cropElements.compactMap { element -> CGRect? in
                guard boolAttribute(element, kAXEnabledAttribute as CFString) == false else {
                    return nil
                }
                return axFrame(of: element)?.rect
            }
            if let lastAvailableY = availableCropFrames.map(\.minY).max(),
               let firstUnavailableY = unavailableCropFrames.map(\.minY).min(),
               lastAvailableY > firstUnavailableY {
                throw SmokeFailure(
                    "available construction choices must precede unavailable choices"
                )
            }
            guard let firstCrop = cropElements.first,
                  setVerticalScroll(containing: firstCrop, value: 1) else {
                throw SmokeFailure("construction catalog did not expose a working scroll bar")
            }
            Thread.sleep(forTimeInterval: 0.3)
            let scrolledCatalogScreenshotURL = arguments.logDirectory
                .appendingPathComponent("qin-m1-construction-catalog-scrolled.png")
            guard captureWindow(
                application: application,
                to: scrolledCatalogScreenshotURL
            ) else {
                throw SmokeFailure("could not capture the scrolled construction catalog")
            }
            log.record("scrolled construction catalog=\(scrolledCatalogScreenshotURL.path)")
            _ = setVerticalScroll(containing: firstCrop, value: 0)

            let residentialCategory = try waitForElement(
                in: application,
                identifier: "construction-category-residential",
                timeout: 15
            )
            try press(
                residentialCategory,
                identifier: "construction-category-residential"
            )
            let advancedControlsToggle = try waitForElement(
                in: application,
                identifier: "city-advanced-controls-toggle",
                timeout: 15
            )
            guard findElement(in: application, identifier: "tax-rate-menu") == nil,
                  findElement(in: application, identifier: "game-speed-3") == nil else {
                throw SmokeFailure("advanced city controls should be hidden by default")
            }
            Thread.sleep(forTimeInterval: 2)
            let screenshotURL = arguments.logDirectory
                .appendingPathComponent("qin-m1-native-city-baseline.png")
            guard captureWindow(application: application, to: screenshotURL) else {
                throw SmokeFailure("could not capture the Qin M1 city baseline")
            }
            log.record("Qin M1 city baseline=\(screenshotURL.path)")

            try press(
                advancedControlsToggle,
                identifier: "city-advanced-controls-toggle"
            )
            let taxRateMenu = try waitForElement(
                in: application,
                identifier: "tax-rate-menu",
                timeout: 15
            )
            let fastestSpeed = try waitForElement(
                in: application,
                identifier: "game-speed-3",
                timeout: 15
            )
            guard let taxRateFrame = axFrame(of: taxRateMenu)?.rect,
                  let fastestSpeedFrame = axFrame(of: fastestSpeed)?.rect else {
                throw SmokeFailure("could not measure the compact command dock")
            }
            let commandDockSpan = fastestSpeedFrame.maxX - taxRateFrame.minX
            guard taxRateFrame.maxX <= fastestSpeedFrame.minX,
                  commandDockSpan <= 216 else {
                throw SmokeFailure(
                    "tax and speed controls overflow the 224px panel: "
                        + "span=\(commandDockSpan), tax=\(taxRateFrame), "
                        + "speed3=\(fastestSpeedFrame)"
                )
            }
            return
        }

        if findElement(in: application, identifier: "city-canvas") == nil,
           let campaignSection = findElement(
            in: application,
            identifier: "library-section-campaigns"
        ) {
            try press(campaignSection, identifier: "library-section-campaigns")
            log.record("pressed library-section-campaigns")
        } else {
            log.record("campaign lobby is already active; AX did not expose its selected tab")
        }

        if findElement(in: application, identifier: "city-canvas") == nil,
           let campaign = findElement(
            in: application,
            identifier: "campaign-xia-tutorials"
        ) {
            try press(campaign, identifier: "campaign-xia-tutorials")
            log.record("pressed campaign-xia-tutorials")
        } else {
            log.record("Xia tutorial is the default campaign; AX did not expose its selected row")
        }
        Thread.sleep(forTimeInterval: 1)

        if findElement(in: application, identifier: "city-canvas") != nil {
            log.record("smoke launch opened the Xia mission directly")
        } else if let start = try? waitForElement(
            in: application,
            identifier: "mission-start-0",
            timeout: 30
        ) {
            try press(start, identifier: "mission-start-0")
            log.record("pressed enabled mission-start-0")
        } else {
            try pressKey(36)
            log.record("pressed Return to start the default Xia mission")
        }
        _ = try waitForElement(in: application, identifier: "city-canvas", timeout: 45)
        Thread.sleep(forTimeInterval: 0.5)
        if findElement(in: application, identifier: "library-section-picker") != nil {
            throw SmokeFailure("mission stayed inside the diagnostic browser instead of opening the classic city shell")
        }
        log.record("started original Xia tutorial mission 0")

        _ = try waitForElement(
            in: application,
            identifier: "advisor-population-panel",
            timeout: 15,
            requireEnabled: false
        )
        let housingSupply = try waitForElement(
            in: application,
            identifier: "advisor-housing-supply",
            timeout: 15
        )
        try press(housingSupply, identifier: "advisor-housing-supply")
        try press(
            try waitForElement(
                in: application,
                identifier: "advisor-housing-supply",
                timeout: 15
            ),
            identifier: "advisor-housing-supply"
        )
        let cityWalkers = try waitForElement(
            in: application,
            identifier: "advisor-city-walkers",
            timeout: 15
        )
        try press(cityWalkers, identifier: "advisor-city-walkers")
        try press(
            try waitForElement(
                in: application,
                identifier: "advisor-city-walkers",
                timeout: 15
            ),
            identifier: "advisor-city-walkers"
        )

        let objectives = try waitForElement(
            in: application,
            identifier: "city-button-objectives",
            timeout: 15
        )
        try press(objectives, identifier: "city-button-objectives")
        _ = try waitForElement(
            in: application,
            identifier: "city-objectives-dialog",
            timeout: 15,
            requireEnabled: false
        )
        let closeObjectives = findElement(
            in: application,
            identifier: "city-objectives-close"
        ) ?? findElement(in: application, role: kAXButtonRole as String, title: "关闭")
        guard let closeObjectives else {
            throw SmokeFailure("could not find the objectives close button")
        }
        try press(closeObjectives, identifier: "city-objectives-close")

        let worldMap = try waitForElement(
            in: application,
            identifier: "city-button-world-map",
            timeout: 15,
            requireEnabled: false
        )
        if boolAttribute(worldMap, kAXEnabledAttribute as CFString) != false {
            try press(worldMap, identifier: "city-button-world-map")
            _ = try waitForElement(
                in: application,
                identifier: "city-world-map-dialog",
                timeout: 15,
                requireEnabled: false
            )
            let closeWorldMap = findElement(
                in: application,
                identifier: "city-world-map-close"
            ) ?? findElement(in: application, role: kAXButtonRole as String, title: "关闭")
            guard let closeWorldMap else {
                throw SmokeFailure("could not find the world-map close button")
            }
            try press(closeWorldMap, identifier: "city-world-map-close")
        }
        log.record("verified classic population advisor and city navigation")

        let savesDirectory = arguments.logDirectory.appendingPathComponent("saves")
        let autosaveDeadline = Date().addingTimeInterval(10)
        var autosaveFiles: [URL] = []
        repeat {
            autosaveFiles = (
                try? FileManager.default.contentsOfDirectory(
                    at: savesDirectory,
                    includingPropertiesForKeys: nil
                )
            )?.filter { $0.lastPathComponent.hasPrefix("auto-") } ?? []
            if !autosaveFiles.isEmpty { break }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < autosaveDeadline
        guard !autosaveFiles.isEmpty else {
            throw SmokeFailure("mission start did not create an automatic save")
        }
        log.record("verified mission-start autosave=\(autosaveFiles[0].lastPathComponent)")

        let commands = try commandTable()
        log.record("planned \(commands.count) legal construction commands from current mission state")
        var selectedCategory = ""
        var selectedTool = ""
        for (index, command) in commands.enumerated() {
            let category = constructionCategoryIdentifier(for: command.toolIdentifier)
            if selectedCategory != category {
                let identifier = "construction-category-\(category)"
                let categoryButton = try waitForElement(
                    in: application,
                    identifier: identifier,
                    timeout: 15
                )
                try press(categoryButton, identifier: identifier)
                selectedCategory = category
                selectedTool = ""
                log.record("selected \(identifier)")
            }
            if selectedTool != command.toolIdentifier {
                let identifier = "construction-tool-\(command.toolIdentifier)"
                let tool = try waitForElement(in: application, identifier: identifier, timeout: 15)
                try press(tool, identifier: identifier)
                selectedTool = command.toolIdentifier
                log.record("selected \(identifier)")
            }
            let screenPoint = try mapPointToScreen(command.point, application: application)
            let canvasElement = findElement(
                in: application,
                identifier: "city-canvas-metrics"
            )
            let canvasFrame = canvasElement
                .flatMap(axFrame(of:))
                .map { NSStringFromRect($0.rect) }
                ?? "unavailable"
            let hitTarget = hitTestDescription(at: screenPoint, application: application)
            let frontmost = NSWorkspace.shared.frontmostApplication
                .map { "\($0.bundleIdentifier ?? "unknown"):\($0.processIdentifier)" }
                ?? "none"
            let expectedCoordinates = [
                "at \(command.point.x),\(command.point.y)",
                "\(command.point.x), \(command.point.y)",
            ]
            func statusMatchesExpectedCoordinate(_ status: String) -> Bool {
                expectedCoordinates.contains { status.contains($0) }
            }
            let tileIdentifier = "city-tile-\(command.point.x)-\(command.point.y)"
            var status = commandStatus(in: application)
            for _ in 0..<3 where !statusMatchesExpectedCoordinate(status) {
                if let tile = findElement(in: application, identifier: tileIdentifier) {
                    try press(tile, identifier: tileIdentifier)
                } else {
                    try clickScreenPoint(screenPoint)
                }
                let responseDeadline = Date().addingTimeInterval(0.35)
                repeat {
                    Thread.sleep(forTimeInterval: 0.04)
                    status = commandStatus(in: application)
                } while !statusMatchesExpectedCoordinate(status) && Date() < responseDeadline
            }
            log.record(
                "command=\(index + 1) tool=\(command.toolIdentifier) map=\(command.point.x),\(command.point.y) screen=\(Int(screenPoint.x)),\(Int(screenPoint.y)) canvas=\(canvasFrame) frontmost=\(frontmost) hit=\(hitTarget) observed=\(status)"
            )
            if !statusMatchesExpectedCoordinate(status) {
                if let canvasElement {
                    log.record(
                        "canvas metrics="
                            + (
                                stringAttribute(canvasElement, kAXHelpAttribute as CFString)
                                    ?? stringAttribute(
                                        canvasElement,
                                        kAXValueAttribute as CFString
                                    )
                                    ?? "unavailable"
                            )
                    )
                }
                throw SmokeFailure("construction command \(index + 1) was rejected: \(status)")
            }
        }

        let builtCityScreenshot = arguments.logDirectory
            .appendingPathComponent("xia1-ui-smoke-built-city.png")
        if captureWindow(application: application, to: builtCityScreenshot) {
            log.record("built city screenshot=\(builtCityScreenshot.path)")
        }

        if let canvas = findElement(in: application, identifier: "city-canvas") {
            _ = setVerticalScroll(containing: canvas, value: 1)
        }
        try revealAdvancedCityControls(in: application)
        let speed = try waitForElement(in: application, identifier: "game-speed-3", timeout: 15)
        try press(speed, identifier: "game-speed-3")
        log.record("pressed game-speed-3")

        let deadline = Date().addingTimeInterval(arguments.timeout)
        var nextProgressLog = Date()
        var capturedLiveCity = false
        while Date() < deadline {
            if findElement(in: application, identifier: "mission-outcome-victory") != nil {
                let screenshotURL = arguments.logDirectory.appendingPathComponent("xia1-ui-smoke-victory.png")
                if let canvas = findElement(in: application, identifier: "city-canvas") {
                    _ = setVerticalScroll(containing: canvas, value: 0.18)
                }
                _ = captureWindow(application: application, to: screenshotURL)
                log.record("victory observed screenshot=\(screenshotURL.path)")
                return
            }
            if findElement(in: application, identifier: "mission-outcome-defeat") != nil {
                throw SmokeFailure("UI replay reached defeat instead of victory")
            }
            if Date() >= nextProgressLog {
                let statusElement = findElement(in: application, identifier: "campaign-goal-status")
                let status = statusElement.flatMap {
                    stringAttribute($0, kAXValueAttribute as CFString)
                } ?? "goal status unavailable"
                log.record("waiting \(status)")
                if !capturedLiveCity,
                   let canvas = findElement(in: application, identifier: "city-canvas") {
                    _ = setVerticalScroll(containing: canvas, value: 0.18)
                    let liveCityScreenshot = arguments.logDirectory
                        .appendingPathComponent("xia1-ui-smoke-live-city.png")
                    if captureWindow(application: application, to: liveCityScreenshot) {
                        log.record("live city screenshot=\(liveCityScreenshot.path)")
                        capturedLiveCity = true
                    }
                }
                nextProgressLog = Date().addingTimeInterval(10)
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        throw SmokeFailure("victory UI did not appear within \(Int(arguments.timeout)) seconds", code: SmokeExit.timeout)
    } catch {
        log.record("AX identifiers=\(accessibilityIdentifierSnapshot(in: application))")
        captureFailure(application: application, log: log)
        throw error
    }
}

do {
    try runSmoke(arguments: try Arguments())
    exit(EXIT_SUCCESS)
} catch let failure as SmokeFailure {
    FileHandle.standardError.write(Data("ui-smoke: \(failure.message)\n".utf8))
    exit(failure.code)
} catch {
    FileHandle.standardError.write(Data("ui-smoke: \(error.localizedDescription)\n".utf8))
    exit(SmokeExit.software)
}
