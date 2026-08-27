import AppKit
import EmperorCore
import SwiftUI

/// Classic front-end stages matching the original Wine-wrapped entry flow:
/// main menu → player account → choose game mode → campaign/city shell.
enum ClassicFrontEndStage: String, CaseIterable, Identifiable {
    case mainMenu
    case accountSelect
    case accountHome
    case play

    var id: Self { self }
}

/// Loads original `DATA/China_FE_*.jpg` art shipped with GameData.
enum ClassicFrontEndArt {
    enum Screen: String {
        case mainMenu = "China_FE_MainMenu"
        case registry = "China_FE_Registry"
        case chooseGame = "China_FE_ChooseGame"
        case campaignSelection = "China_FE_CampaignSelection"
        case missionIntroduction = "China_FE_MissionIntroduction"
        case openPlay = "China_FE_OpenPlay"
        case highScores = "China_FE_HighScores"
        case tutorials = "China_FE_tutorials"
    }

    static func image(for screen: Screen, sourceRoot: URL?) -> NSImage? {
        let candidates: [URL] = [
            sourceRoot?.appendingPathComponent("DATA/\(screen.rawValue).jpg"),
            GameDataSource.defaultRoot.appendingPathComponent("DATA/\(screen.rawValue).jpg"),
        ].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    static func campaignIllustration(
        for campaign: CampaignArchive,
        sourceRoot: URL?
    ) -> NSImage? {
        let fileName = campaign.url.lastPathComponent.lowercased()
        if fileName.contains("xia") {
            return image(for: .tutorials, sourceRoot: sourceRoot)
        }
        return image(for: .campaignSelection, sourceRoot: sourceRoot)
    }

    /// Fallback when a synthesized fill cannot be built from the shipping JPG.
    static let letterboxFallbackColor = NSColor(calibratedRed: 94 / 255, green: 0, blue: 1 / 255, alpha: 1)

    private static var letterboxFillCache: [String: NSImage] = [:]

    /// Large non-repeating crimson field synthesized from a quiet crop of the
    /// screen art (texture-bombing), so enlarged windows don't show a tiled grid.
    static func letterboxFill(for screen: Screen, sourceRoot: URL?) -> NSImage? {
        let cacheKey = screen.rawValue
        if let cached = letterboxFillCache[cacheKey] {
            return cached
        }
        guard let synthesized = synthesizeLetterboxFill(for: screen, sourceRoot: sourceRoot) else {
            return nil
        }
        letterboxFillCache[cacheKey] = synthesized
        return synthesized
    }

    private static func synthesizeLetterboxFill(for screen: Screen, sourceRoot: URL?) -> NSImage? {
        guard let source = image(for: screen, sourceRoot: sourceRoot),
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let patchSide = 160
        let origin = CGPoint(x: 12, y: 12)
        let maxX = max(0, cgImage.width - patchSide)
        let maxY = max(0, cgImage.height - patchSide)
        let crop = CGRect(
            x: min(Int(origin.x), maxX),
            y: min(Int(origin.y), maxY),
            width: patchSide,
            height: patchSide
        )
        guard let patch = cgImage.cropping(to: crop) else {
            return nil
        }

        let outputSide = 1536
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: outputSide,
            pixelsHigh: outputSide,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        defer { NSGraphicsContext.restoreGraphicsState() }

        letterboxFallbackColor.setFill()
        NSRect(x: 0, y: 0, width: outputSide, height: outputSide).fill()

        let patchImage = NSImage(cgImage: patch, size: NSSize(width: patchSide, height: patchSide))
        let seed: UInt64
        switch screen {
        case .mainMenu: seed = 0xE4E7_4D01
        case .registry: seed = 0xE4E7_4D02
        case .chooseGame: seed = 0xE4E7_4D03
        default: seed = 0xE4E7_4D00
        }
        var rng = LetterboxRNG(seed: seed)
        let step = 52
        var stampY = -patchSide / 2
        while stampY < outputSide + patchSide {
            var stampX = -patchSide / 2
            while stampX < outputSide + patchSide {
                let jitterX = rng.nextInt(in: -14...14)
                let jitterY = rng.nextInt(in: -14...14)
                let dest = NSRect(
                    x: stampX + jitterX,
                    y: stampY + jitterY,
                    width: patchSide,
                    height: patchSide
                )
                let alpha = CGFloat(0.34 + Double(rng.nextInt(in: 0...24)) / 100)
                patchImage.draw(
                    in: dest,
                    from: NSRect(origin: .zero, size: patchImage.size),
                    operation: .sourceOver,
                    fraction: alpha
                )
                stampX += step
            }
            stampY += step
        }

        let image = NSImage(size: NSSize(width: outputSide, height: outputSide))
        image.addRepresentation(rep)
        return image
    }
}

/// Tiny deterministic RNG for texture bombing (no Foundation GameplayKit dependency).
private struct LetterboxRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}

struct ClassicFrontEndRoot: View {
    @ObservedObject var library: LibraryModel

    var body: some View {
        switch library.frontEndStage {
        case .mainMenu:
            ClassicMainMenuView(library: library)
        case .accountSelect:
            ClassicAccountSelectView(library: library)
        case .accountHome:
            ClassicAccountHomeView(library: library)
        case .play:
            EmptyView()
        }
    }
}

private struct ClassicMainMenuView: View {
    @ObservedObject var library: LibraryModel

    /// Hotspots over the empty parchment in `China_FE_MainMenu.jpg` (1024×768),
    /// matching the original Wine front-end button column under the logo banner.
    private static let menuRect = CGRect(x: 266, y: 324, width: 192, height: 234)
    private static let menuSpacing: CGFloat = 18

    var body: some View {
        ClassicFrontEndCanvas(screen: .mainMenu, sourceRoot: library.dataSourceRoot) { layout in
            VStack(spacing: Self.menuSpacing) {
                menuButton("单人游戏", identifier: "frontend-single-player") {
                    library.frontEndStage = .accountSelect
                }
                menuButton("多人游戏", identifier: "frontend-multiplayer", enabled: false) {}
                menuButton("最高得分", identifier: "frontend-high-scores", enabled: false) {}
                menuButton("游戏网站", identifier: "frontend-website", enabled: false) {}
                menuButton("战役编辑", identifier: "frontend-campaign-editor", enabled: false) {}
                menuButton("退出游戏", identifier: "frontend-quit") {
                    NSApp.terminate(nil)
                }
            }
            .frame(width: Self.menuRect.width, height: Self.menuRect.height)
            .position(layout.point(for: CGPoint(x: Self.menuRect.midX, y: Self.menuRect.midY)))
        }
        .accessibilityIdentifier("classic-main-menu")
    }

    private func menuButton(
        _ title: String,
        identifier: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(ClassicMainMenuButtonStyle())
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
        .help(enabled ? title : "\(title)（本版暂未开放）")
    }
}

private struct ClassicMainMenuButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EmperorTheme.headlineSmall)
            .foregroundStyle(isEnabled ? EmperorTheme.onSurface : EmperorTheme.onSurfaceMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                EmperorTheme.surfaceControl.opacity(
                    configuration.isPressed ? 0.32 : (isEnabled ? 0.22 : 0.12)
                )
            )
            .overlay(
                Rectangle()
                    .strokeBorder(
                        EmperorTheme.border.opacity(isEnabled ? 0.86 : 0.62),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
    }
}

/// Places the 1024×768 front-end plate at native 1×, centered in the window.
struct ClassicFrontEndLayout {
    let container: CGSize

    var viewport: CGSize { EmperorTheme.classicViewportSize }

    var artOrigin: CGPoint {
        CGPoint(
            x: (container.width - viewport.width) * 0.5,
            y: (container.height - viewport.height) * 0.5
        )
    }

    /// Maps a point from the 1024×768 art into the window.
    func point(for artPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: artOrigin.x + artPoint.x,
            y: artOrigin.y + artPoint.y
        )
    }
}

/// Centers classic front-end art at 1×; extra window space uses a matching field.
struct ClassicFrontEndCanvas<Content: View>: View {
    let screen: ClassicFrontEndArt.Screen
    let sourceRoot: URL?
    @ViewBuilder var content: (ClassicFrontEndLayout) -> Content

    var body: some View {
        GeometryReader { geometry in
            let layout = ClassicFrontEndLayout(container: geometry.size)
            ZStack {
                ClassicFrontEndLetterboxFill(
                    screen: screen,
                    sourceRoot: sourceRoot,
                    artFrame: CGRect(
                        origin: layout.artOrigin,
                        size: layout.viewport
                    )
                )

                ClassicFrontEndBackdrop(screen: screen, sourceRoot: sourceRoot)
                    .frame(width: layout.viewport.width, height: layout.viewport.height)
                    .position(
                        x: layout.artOrigin.x + layout.viewport.width * 0.5,
                        y: layout.artOrigin.y + layout.viewport.height * 0.5
                    )
                    .allowsHitTesting(false)

                content(layout)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

/// Fills enlarged-window gutters with a synthesized crimson field, then feathers
/// real art edge strips near the plate so the join is continuous.
private struct ClassicFrontEndLetterboxFill: View {
    let screen: ClassicFrontEndArt.Screen
    let sourceRoot: URL?
    let artFrame: CGRect

    var body: some View {
        Canvas { context, size in
            let fallback = Color(
                red: 94 / 255,
                green: 0 / 255,
                blue: 1 / 255
            )
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(fallback))

            if let fill = ClassicFrontEndArt.letterboxFill(for: screen, sourceRoot: sourceRoot) {
                context.draw(
                    Image(nsImage: fill),
                    in: CGRect(origin: .zero, size: size)
                )
            }

            if let art = ClassicFrontEndArt.image(for: screen, sourceRoot: sourceRoot),
               let cgImage = art.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                drawEdgeFeather(
                    context: context,
                    cgImage: cgImage,
                    artFrame: artFrame,
                    containerSize: size,
                    feather: 48
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Copies a short band of real art texels into the adjacent gutter so the
    /// 1× plate does not sit on a hard seam. Farther gutters keep the fill.
    private func drawEdgeFeather(
        context: GraphicsContext,
        cgImage: CGImage,
        artFrame: CGRect,
        containerSize: CGSize,
        feather: CGFloat
    ) {
        let iw = CGFloat(cgImage.width)
        let ih = CGFloat(cgImage.height)

        func drawCrop(_ crop: CGRect, into dest: CGRect, opacity: Double) {
            guard crop.width > 1, crop.height > 1, dest.width > 0, dest.height > 0,
                  let piece = cgImage.cropping(to: crop) else { return }
            var rectContext = context
            rectContext.opacity = opacity
            rectContext.draw(
                Image(nsImage: NSImage(
                    cgImage: piece,
                    size: NSSize(width: crop.width, height: crop.height)
                )),
                in: dest
            )
        }

        // Top feather
        if artFrame.minY > 0 {
            let height = min(feather, artFrame.minY)
            drawCrop(
                CGRect(x: 0, y: 0, width: iw, height: min(feather, ih)),
                into: CGRect(x: artFrame.minX, y: artFrame.minY - height, width: artFrame.width, height: height),
                opacity: 0.92
            )
        }

        // Bottom feather
        let bottomGutter = containerSize.height - artFrame.maxY
        if bottomGutter > 0 {
            let height = min(feather, bottomGutter)
            drawCrop(
                CGRect(x: 0, y: ih - min(feather, ih), width: iw, height: min(feather, ih)),
                into: CGRect(x: artFrame.minX, y: artFrame.maxY, width: artFrame.width, height: height),
                opacity: 0.92
            )
        }

        // Left feather from quiet left columns
        if artFrame.minX > 0 {
            let width = min(feather, artFrame.minX)
            drawCrop(
                CGRect(x: 0, y: 0, width: min(feather, iw), height: ih),
                into: CGRect(x: artFrame.minX - width, y: artFrame.minY, width: width, height: artFrame.height),
                opacity: 0.92
            )
        }

        // Right feather also from quiet left columns (avoid stretching the dragon)
        let rightGutter = containerSize.width - artFrame.maxX
        if rightGutter > 0 {
            let width = min(feather, rightGutter)
            drawCrop(
                CGRect(x: 0, y: 0, width: min(feather, iw), height: ih),
                into: CGRect(x: artFrame.maxX, y: artFrame.minY, width: width, height: artFrame.height),
                opacity: 0.85
            )
        }
    }
}

private struct ClassicAccountSelectView: View {
    @ObservedObject var library: LibraryModel
    @State private var newAccountName = ""
    @FocusState private var isAccountNameFocused: Bool

    var body: some View {
        ClassicFrontEndCanvas(screen: .registry, sourceRoot: library.dataSourceRoot) { _ in
            VStack(spacing: 0) {
                Text("选择玩家帐号")
                    .font(EmperorTheme.display)
                    .foregroundStyle(EmperorTheme.primary)
                    .padding(.top, 28)
                    .padding(.bottom, 18)

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("帐号列表")
                            .font(EmperorTheme.labelMedium)
                            .foregroundStyle(EmperorTheme.onSurfaceMuted)
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(library.playerAccounts, id: \.self) { name in
                                    Button {
                                        library.selectedPlayerAccount = name
                                    } label: {
                                        HStack {
                                            Text(name)
                                                .font(EmperorTheme.headlineSmall)
                                            Spacer()
                                            if library.selectedPlayerAccount == name {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                        .foregroundStyle(
                                            library.selectedPlayerAccount == name
                                                ? EmperorTheme.onPrimary
                                                : EmperorTheme.onSurface
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            library.selectedPlayerAccount == name
                                                ? EmperorTheme.primary
                                                : EmperorTheme.surfaceDeep.opacity(0.8)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("frontend-account-\(name)")
                                }
                            }
                        }
                        .frame(height: 220)
                        .background(EmperorTheme.surfaceDeep.opacity(0.85))
                        .overlay(Rectangle().strokeBorder(EmperorTheme.border))
                    }
                    .frame(width: 280)

                    VStack(spacing: 12) {
                        TextField("输入统治的名字", text: $newAccountName)
                            .textFieldStyle(.plain)
                            .focused($isAccountNameFocused)
                            .padding(10)
                            .background(EmperorTheme.surfaceDeep)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(EmperorTheme.border)
                                    .allowsHitTesting(false)
                            )
                            .foregroundStyle(EmperorTheme.onSurface)
                            .accessibilityIdentifier("frontend-account-name-field")

                        Button("创建玩家帐号") {
                            library.createPlayerAccount(newAccountName)
                            newAccountName = ""
                        }
                        .buttonStyle(EmperorClassicButtonStyle(.primary))
                        .disabled(newAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("frontend-create-account")

                        Button("删除玩家帐号") {
                            library.deleteSelectedPlayerAccount()
                        }
                        .buttonStyle(EmperorClassicButtonStyle(.danger))
                        .disabled(library.selectedPlayerAccount == nil)
                        .accessibilityIdentifier("frontend-delete-account")
                    }
                    .frame(width: 220)
                }
                .padding(.horizontal, 36)

                Spacer()

                HStack {
                    Button("返回主菜单") {
                        library.frontEndStage = .mainMenu
                    }
                    .buttonStyle(EmperorClassicButtonStyle())
                    .accessibilityIdentifier("frontend-back-main-menu")

                    Spacer()

                    Button("继续") {
                        library.confirmSelectedPlayerAccount()
                    }
                    .buttonStyle(EmperorClassicButtonStyle(.primary))
                    .disabled(library.selectedPlayerAccount == nil)
                    .accessibilityIdentifier("frontend-account-continue")
                }
                .padding(28)
            }
            .frame(width: 640, height: 460)
            .background(EmperorTheme.surface.opacity(0.94))
            .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 2))
        }
        .accessibilityIdentifier("classic-account-select")
        .onAppear {
            isAccountNameFocused = true
        }
    }
}

private struct ClassicAccountHomeView: View {
    @ObservedObject var library: LibraryModel

    var body: some View {
        ClassicFrontEndCanvas(screen: .chooseGame, sourceRoot: library.dataSourceRoot) { _ in
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("玩家帐号")
                        .font(EmperorTheme.headlineMedium)
                        .foregroundStyle(EmperorTheme.primary)
                    Text(library.selectedPlayerAccount ?? "未选择")
                        .font(EmperorTheme.display)
                        .foregroundStyle(EmperorTheme.onSurface)
                }
                .padding(.top, 8)

                VStack(spacing: 10) {
                    modeButton("历史战役", identifier: "frontend-historical-campaigns") {
                        library.enterPlaySection(.campaigns)
                    }
                    modeButton("自定战役", identifier: "frontend-custom-campaigns", enabled: false) {}
                    modeButton("开放游戏", identifier: "frontend-open-play", enabled: false) {}
                    modeButton("读取存档", identifier: "frontend-load-save") {
                        library.enterPlaySection(.saves)
                    }
                }
                .frame(width: 280)

                HStack {
                    Button("返回帐号") {
                        library.frontEndStage = .accountSelect
                    }
                    .buttonStyle(EmperorClassicButtonStyle())
                    .accessibilityIdentifier("frontend-back-account")

                    Spacer()

                    Button("恢复游戏") {
                        library.enterPlaySection(.campaigns)
                        library.loadMostRecentSave()
                    }
                    .buttonStyle(EmperorClassicButtonStyle(.primary))
                    .disabled(!library.saveHistory.contains(where: \.isReadable))
                    .accessibilityIdentifier("frontend-resume-game")
                }
                .frame(width: 420)
            }
            .padding(32)
            .frame(width: 520)
            .background(EmperorTheme.surface.opacity(0.94))
            .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 2))
        }
        .accessibilityIdentifier("classic-account-home")
    }

    private func modeButton(
        _ title: String,
        identifier: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(EmperorTheme.headlineSmall)
                .foregroundStyle(enabled ? EmperorTheme.onSurface : EmperorTheme.onSurfaceMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(EmperorTheme.surfaceControl.opacity(enabled ? 0.95 : 0.5))
                .overlay(Rectangle().strokeBorder(EmperorTheme.border))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }
}

private struct ClassicFrontEndBackdrop: View {
    let screen: ClassicFrontEndArt.Screen
    let sourceRoot: URL?

    var body: some View {
        Group {
            if let image = ClassicFrontEndArt.image(for: screen, sourceRoot: sourceRoot) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: EmperorTheme.classicViewportSize.width,
                        height: EmperorTheme.classicViewportSize.height
                    )
            } else {
                ClassicLobbyBackground()
            }
        }
        .frame(
            width: EmperorTheme.classicViewportSize.width,
            height: EmperorTheme.classicViewportSize.height
        )
        .clipped()
    }
}
