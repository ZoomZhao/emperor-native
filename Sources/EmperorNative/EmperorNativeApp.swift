import AppKit
import SwiftUI

@main
struct EmperorNativeApp: App {
    @StateObject private var library = LibraryModel()
    private let usesFixedSmokeWindow: Bool
    private let defaultWidth: CGFloat
    private let defaultHeight: CGFloat

    init() {
        usesFixedSmokeWindow = ProcessInfo.processInfo.arguments.contains("--ui-smoke-fixed-window")
        defaultWidth = EmperorTheme.classicViewportSize.width
        defaultHeight = EmperorTheme.classicViewportSize.height
        NativeDiagnostics.record("Emperor Native 1.0.0 starting")
    }

    var body: some Scene {
        WindowGroup("皇帝：龙之崛起") {
            ContentView(library: library)
                .frame(
                    minWidth: EmperorTheme.classicViewportSize.width,
                    minHeight: EmperorTheme.classicViewportSize.height
                )
                .background(
                    FixedWindowConfigurator(
                        contentSize: usesFixedSmokeWindow
                            ? CGSize(width: defaultWidth, height: defaultHeight)
                            : nil
                    )
                )
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(
            width: defaultWidth,
            height: defaultHeight
        )
        .commands {
            EmperorAppCommands(library: library)
        }
    }
}

private struct EmperorAppCommands: Commands {
    @ObservedObject var library: LibraryModel

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("快速存档") {
                library.saveCity()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(library.section != .city || library.cityState == nil)

            Button("另存为…") {
                library.saveCityAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(library.section != .city || library.cityState == nil)
        }

        CommandGroup(after: .saveItem) {
            Button("载入外部存档…") {
                library.loadCity()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("载入最近存档") {
                library.loadMostRecentSave()
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(!library.saveHistory.contains(where: \.isReadable))
        }

        CommandMenu("游戏") {
            Button(library.gameSpeed == 0 ? "继续时间" : "暂停时间") {
                library.setGameSpeed(library.gameSpeed == 0 ? 1 : 0)
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(library.section != .city)
            Button("暂停／继续（P）") {
                library.setGameSpeed(library.gameSpeed == 0 ? 1 : 0)
            }
            .keyboardShortcut("p", modifiers: [])
            .disabled(library.section != .city)

            Divider()

            Button("暂停") {
                library.setGameSpeed(0)
            }
            .keyboardShortcut("0", modifiers: [])
            .disabled(library.section != .city)
            Button("一倍速度") {
                library.setGameSpeed(1)
            }
            .keyboardShortcut("1", modifiers: [])
            .disabled(library.section != .city)
            Button("二倍速度") {
                library.setGameSpeed(2)
            }
            .keyboardShortcut("2", modifiers: [])
            .disabled(library.section != .city)
            Button("三倍速度") {
                library.setGameSpeed(3)
            }
            .keyboardShortcut("3", modifiers: [])
            .disabled(library.section != .city)

            Divider()

            Button("浏览工具") {
                library.selectConstructionTool(.inspect)
            }
            .keyboardShortcut("b", modifiers: [])
            .disabled(library.section != .city)
            Button("住宅工具") {
                library.selectConstructionTool(.house)
            }
            .keyboardShortcut("h", modifiers: [])
            .disabled(library.section != .city)
            Button("道路工具") {
                library.selectConstructionTool(.road)
            }
            .keyboardShortcut("g", modifiers: [])
            .disabled(library.section != .city)
            Button("清理树木") {
                library.selectConstructionTool(.clearLand)
            }
            .keyboardShortcut("c", modifiers: [])
            .disabled(library.section != .city)
            Button("拆除工具") {
                library.selectConstructionTool(.demolish)
            }
            .keyboardShortcut("x", modifiers: [])
            .disabled(library.section != .city)
            Button("旋转建筑") {
                library.rotateConstructionTool()
            }
            .keyboardShortcut("r", modifiers: [])
            .disabled(
                library.section != .city
                    || !library.constructionTool.supportsRotation
            )
            Button("取消当前操作") {
                library.cancelCurrentInteraction()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(
                library.section != .city
                    || (
                        library.constructionTool == .inspect
                            && library.selectedMilitaryUnitIDs.isEmpty
                    )
            )

            Divider()

            Button("返回战役大厅") {
                library.returnToCampaignList()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(library.section != .city)
        }
    }
}

private struct FixedWindowConfigurator: NSViewRepresentable {
    let contentSize: CGSize?

    func makeNSView(context: Context) -> FixedWindowSizingView {
        FixedWindowSizingView(contentSize: contentSize)
    }

    func updateNSView(_ nsView: FixedWindowSizingView, context: Context) {}
}

private final class FixedWindowSizingView: NSView {
    private let targetContentSize: CGSize?
    private var didConfigure = false

    init(contentSize: CGSize?) {
        targetContentSize = contentSize
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didConfigure, let window, let targetContentSize else { return }
        didConfigure = true
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            let contentRect = CGRect(origin: .zero, size: targetContentSize)
            let frameSize = window.frameRect(forContentRect: contentRect).size
            let visibleFrame = window.screen?.visibleFrame
                ?? NSScreen.main?.visibleFrame
                ?? CGRect(origin: .zero, size: frameSize)
            let origin = CGPoint(
                x: visibleFrame.midX - frameSize.width / 2,
                y: visibleFrame.midY - frameSize.height / 2
            )
            window.setFrame(CGRect(origin: origin, size: frameSize), display: true)
        }
    }
}
