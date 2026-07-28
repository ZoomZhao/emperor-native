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

    var body: some View {
        ZStack {
            ClassicFrontEndBackdrop(screen: .mainMenu, sourceRoot: library.dataSourceRoot)
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    Text("皇帝：龙之崛起")
                        .font(EmperorTheme.headlineLarge)
                        .foregroundStyle(EmperorTheme.primary)
                        .accessibilityAddTraits(.isHeader)

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
                .padding(28)
                .frame(width: 360)
                .background(EmperorTheme.surface.opacity(0.92))
                .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 2))
                .padding(.trailing, 64)
                .padding(.bottom, 72)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
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
                .font(EmperorTheme.headlineSmall)
                .foregroundStyle(enabled ? EmperorTheme.onSurface : EmperorTheme.onSurfaceMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(EmperorTheme.surfaceControl.opacity(enabled ? 0.95 : 0.55))
                .overlay(Rectangle().strokeBorder(EmperorTheme.border))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
        .help(enabled ? title : "\(title)（本版暂未开放）")
    }
}

private struct ClassicAccountSelectView: View {
    @ObservedObject var library: LibraryModel
    @State private var newAccountName = ""
    @FocusState private var isAccountNameFocused: Bool

    var body: some View {
        ZStack {
            ClassicFrontEndBackdrop(screen: .registry, sourceRoot: library.dataSourceRoot)
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
        ZStack {
            ClassicFrontEndBackdrop(screen: .chooseGame, sourceRoot: library.dataSourceRoot)
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
                    .scaledToFill()
            } else {
                ClassicLobbyBackground()
            }
        }
        .ignoresSafeArea()
        .overlay(EmperorTheme.overlayScrim.opacity(0.18).ignoresSafeArea())
    }
}
