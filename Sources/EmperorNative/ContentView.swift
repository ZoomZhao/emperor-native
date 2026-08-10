import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var library: LibraryModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch library.state {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(EmperorTheme.primary)
                    Text("正在建立原版数据索引…")
                        .font(EmperorTheme.headlineSmall)
                        .foregroundStyle(EmperorTheme.onSurface)
                    Text("正在定位地图、战役与运行时素材")
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(EmperorTheme.backgroundApp)
            case .failed:
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 42))
                        .foregroundStyle(EmperorTheme.warning)
                    Text("无法读取游戏数据")
                        .font(EmperorTheme.headlineLarge)
                        .foregroundStyle(EmperorTheme.onSurface)
                    Text("请确认应用包或仓库中的 GameData 目录完整，然后重新打开。")
                        .font(EmperorTheme.bodyMedium)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(EmperorTheme.backgroundApp)
            case let .loaded(source, catalog, probes, models, economy, campaigns):
                Group {
                    if library.frontEndStage != .play {
                        ClassicFrontEndRoot(library: library)
                    } else if library.section == .city {
                        ClassicCityGameView(library: library, models: economy)
                    } else if library.section == .campaigns {
                        ClassicCampaignLobbyView(
                            library: library,
                            campaigns: campaigns,
                            economy: economy
                        )
                    } else if library.section == .saves {
                        ClassicSaveHistoryView(library: library)
                    } else if library.section == .maps {
                        ClassicLibraryView(
                            library: library,
                            source: source,
                            catalog: catalog,
                            models: models,
                            economy: economy
                        )
                    } else {
                        NavigationSplitView {
                    VStack(spacing: 0) {
                        Picker("资料类型", selection: $library.section) {
                            ForEach(LibrarySection.allCases) { section in
                                Text(section.rawValue)
                                    .tag(section)
                                    .accessibilityIdentifier("library-section-\(section.accessibilitySlug)")
                            }
                        }
                        .accessibilityIdentifier("library-section-picker")
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .padding(12)
                        Divider()

                        if library.section == .city {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    SidebarGroup("原生城市内核") {
                                    if let city = library.cityState {
                                        LabeledContent("住宅", value: "\(city.houses.count)")
                                        LabeledContent("人口", value: "\(city.population)")
                                        LabeledContent("道路格", value: "\(city.roadNetwork.points.count)")
                                        LabeledContent("国库", value: "\(city.economy.treasury)")
                                    }
                                    }
                                    SidebarGroup("当前范围") {
                                        Label("住宅建造", systemImage: "house")
                                        Label("人口入住", systemImage: "person.2")
                                        Label("逐月税收", systemImage: "calendar")
                                        Label("工业生产", systemImage: "shippingbox")
                                        Label("节气农业", systemImage: "leaf")
                                        Label("陆海贸易", systemImage: "arrow.left.arrow.right")
                                        Label("年度目标", systemImage: "chart.bar.xaxis")
                                        Label("市场配送", systemImage: "basket")
                                        Label("磨坊与食物质量", systemImage: "takeoutbag.and.cup.and.straw")
                                    }
                                    Text("这是用原版参数和素材驱动的可重放实验场；迁入、行人和运输按日推进，税务与生产在月末统一结算。")
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                }
                                .padding(12)
                            }
                        } else if library.section == .maps {
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(probes) { map in
                                        Button {
                                            library.select(map)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(ClassicTextLocalization.mapName(map.url))
                                                Text("\(map.width ?? 0) × \(map.height ?? 0) · \(map.chunkCount) 块")
                                                    .font(EmperorTheme.bodySmall)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                library.selectedMap?.url == map.url
                                                    ? EmperorTheme.primary.opacity(0.16) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(
                                                        library.selectedMap?.url == map.url
                                                            ? EmperorTheme.border
                                                            : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(8)
                            }
                        } else if library.section == .campaigns {
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(campaigns) { campaign in
                                        Button {
                                            library.select(campaign)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(
                                                    ClassicTextLocalization.campaignTitle(
                                                        campaign.title
                                                    )
                                                )
                                                Text("\(campaign.missions.count) 个任务")
                                                    .font(EmperorTheme.bodySmall)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                library.selectedCampaign?.url == campaign.url
                                                    ? EmperorTheme.primary.opacity(0.16) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(
                                                        library.selectedCampaign?.url == campaign.url
                                                            ? EmperorTheme.border
                                                            : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier(campaign.accessibilityIdentifier)
                                    }
                                }
                                .padding(8)
                            }
                        }
                    }
                    .navigationTitle(library.section.rawValue)
                    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
                } content: {
                    Group {
                        if library.section == .city {
                            CitySimulationView(library: library, models: economy)
                                .navigationTitle("原生城市内核实验场")
                        } else if library.section == .maps {
                            MapDiagnosticView(probe: library.selectedMap, rendered: library.renderedMap)
                                .navigationTitle(
                                    library.selectedMap.map {
                                        ClassicTextLocalization.mapName($0.url)
                                    } ?? "地图"
                                )
                        } else if library.section == .campaigns {
                            CampaignDiagnosticView(
                                campaign: library.selectedCampaign,
                                embeddedMaps: library.embeddedCampaignMaps,
                                isResolvingMaps: library.isResolvingCampaignMaps,
                                missionMaps: library.campaignMissionMaps,
                                missionSettings: library.campaignMissionSettings,
                                isResolvingSettings: library.isResolvingCampaignSettings,
                                goalArchive: library.campaignGoalArchive,
                                isResolvingGoals: library.isResolvingCampaignGoals,
                                eventArchive: library.campaignEventArchive,
                                isResolvingEvents: library.isResolvingCampaignEvents,
                                empireMap: library.campaignEmpireMap,
                                isResolvingEmpire: library.isResolvingCampaignEmpire,
                                cityNames: library.cityNames,
                                economy: economy,
                                city: library.cityState,
                                campaignRuntime: library.campaignRuntimeState,
                                activeMissionID: library.selectedMissionID,
                                onStartMission: library.startMission
                            )
                                .navigationTitle(
                                    library.selectedCampaign.map {
                                        ClassicTextLocalization.campaignTitle($0.title)
                                    } ?? "战役"
                                )
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 420, ideal: 560)
                } detail: {
                    InspectorView(
                        source: source,
                        catalog: catalog,
                        models: models,
                        economy: economy,
                        map: library.section == .maps ? library.selectedMap : nil,
                        campaign: library.section == .campaigns ? library.selectedCampaign : nil,
                        embeddedCampaignMapCount: library.section == .campaigns ? library.embeddedCampaignMaps.count : nil,
                        campaignMissionMaps: library.section == .campaigns ? library.campaignMissionMaps : nil,
                        campaignGoals: library.section == .campaigns ? library.campaignGoalArchive : nil,
                        campaignEvents: library.section == .campaigns ? library.campaignEventArchive : nil,
                        campaignEmpireMap: library.section == .campaigns ? library.campaignEmpireMap : nil,
                        city: library.section == .city ? library.cityState : nil,
                        latestSettlement: library.section == .city ? library.latestSettlement : nil
                    )
                        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
                        }
                    }
                }
                .id(library.section)
            }
        }
        .task { library.load() }
        .font(EmperorTheme.bodyMedium)
        .tint(EmperorTheme.primary)
        .preferredColorScheme(.dark)
        .background(EmperorTheme.backgroundApp)
        .accessibilityIdentifier("emperor-native-root")
        .onChange(of: scenePhase) { phase in
            if phase == .inactive || phase == .background {
                library.autosaveIfNeeded(force: true)
            }
        }
    }
}

extension LibrarySection {
    var accessibilitySlug: String {
        switch self {
        case .city: "city"
        case .maps: "maps"
        case .campaigns: "campaigns"
        case .saves: "saves"
        }
    }
}

extension CampaignArchive {
    var accessibilityIdentifier: String {
        if url.lastPathComponent == "1 Xia Dynasty - Tutorials.pak" {
            return "campaign-xia-tutorials"
        }
        let slug = url.deletingPathExtension().lastPathComponent.lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "campaign-\(slug)"
    }
}

/// Map-first city shell modelled after the original game's main screen:
/// a compact imperial status bar, the city map, a fixed ministry/building panel,
/// and panel-docked commands/minimap that never reduce the map's height.
private typealias ClassicPalette = EmperorTheme

private struct ClassicBronzeTexture: View {
    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [ClassicPalette.panelBrown, ClassicPalette.deepBrown]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            for x in stride(from: CGFloat(0), through: size.width, by: 22) {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(ClassicPalette.border.opacity(0.15)), lineWidth: 0.5)
            }
            for y in stride(from: CGFloat(0), through: size.height, by: 22) {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Color.black.opacity(0.16)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ClassicOriginalPanelTexture: View {
    let sprite: RenderedTerrainSprite?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ClassicBronzeTexture()

            if let sprite, let woodTileImage = panelWoodTileImage(sprite) {
                Image(decorative: woodTileImage, scale: 1)
                    .resizable(resizingMode: .tile)
                    .interpolation(.none)
            }

            if let sprite, let railImage = panelCategoryRailImage(sprite) {
                Image(decorative: railImage, scale: 1)
                    .interpolation(.none)
                    .frame(
                        width: EmperorTheme.categoryRailWidth,
                        height: CGFloat(railImage.height),
                        alignment: .topLeading
                    )
                    .clipped()
            }

            if let sprite, let advisorImage = panelAdvisorImage(sprite) {
                Image(decorative: advisorImage, scale: 1)
                    .interpolation(.none)
                    .frame(
                        width: EmperorTheme.panelWidth - EmperorTheme.categoryRailWidth,
                        height: CGFloat(advisorImage.height),
                        alignment: .topLeading
                    )
                    .clipped()
                    .offset(x: EmperorTheme.categoryRailWidth)
            }
        }
    }

    /// Keep the authored category slots, which remain fixed while the
    /// construction catalog scrolls independently.
    private func panelCategoryRailImage(_ sprite: RenderedTerrainSprite) -> CGImage? {
        let topInset = min(Int(EmperorTheme.hudHeight), sprite.image.height - 1)
        return sprite.image.cropping(
            to: CGRect(
                x: 0,
                y: topInset,
                width: Int(EmperorTheme.categoryRailWidth),
                height: sprite.image.height - topInset
            )
        )
    }

    /// Preserve only the fixed woven advisor field from `#1223`. Its original
    /// construction lines are deliberately excluded: grid borders belong to
    /// the catalog cells so they move with those cells when scrolled.
    private func panelAdvisorImage(_ sprite: RenderedTerrainSprite) -> CGImage? {
        let topInset = min(Int(EmperorTheme.hudHeight), sprite.image.height - 1)
        let railWidth = min(Int(EmperorTheme.categoryRailWidth), sprite.image.width - 1)
        let availableHeight = sprite.image.height - topInset
        let advisorHeight = min(Int(EmperorTheme.populationAdvisorHeight), availableHeight)
        return sprite.image.cropping(
            to: CGRect(
                x: railWidth,
                y: topInset,
                width: sprite.image.width - railWidth,
                height: advisorHeight
            )
        )
    }

    /// The original `#1223` slice is only 458 px tall. Continue the area below
    /// its fixed advisor chrome with a plain wood sample instead of stretching
    /// structural details across the full 728 px sidebar.
    private func panelWoodTileImage(_ sprite: RenderedTerrainSprite) -> CGImage? {
        let sampleOrigin = CGPoint(x: 64, y: 80)
        let sampleSize = CGSize(width: 128, height: 128)
        guard Int(sampleOrigin.x + sampleSize.width) <= sprite.image.width,
              Int(sampleOrigin.y + sampleSize.height) <= sprite.image.height else {
            return nil
        }
        return sprite.image.cropping(
            to: CGRect(origin: sampleOrigin, size: sampleSize)
        )
    }
}

private enum ClassicConstructionCatalogItem: Identifiable {
    case crop(AgriculturalCrop)
    case tool(NativeConstructionTool)

    var id: String {
        switch self {
        case let .crop(crop): "crop-\(crop.rawValue)"
        case let .tool(tool): "tool-\(tool.rawValue)"
        }
    }
}

private struct ClassicCityGameView: View {
    @ObservedObject var library: LibraryModel
    let models: OriginalEconomyModels
    @State private var cameraOffsetX = 0
    @State private var cameraOffsetY = 0
    @State private var selectedCategory: ConstructionToolCategory = .residential
    @State private var showsCitySummary = false

    var body: some View {
        GeometryReader { geometry in
            let scale = EmperorTheme.classicIntegerScale(fitting: geometry.size)

            ZStack {
                EmperorTheme.backgroundApp
                    .ignoresSafeArea()

                classicViewport
                    .frame(
                        width: EmperorTheme.classicViewportSize.width,
                        height: EmperorTheme.classicViewportSize.height
                    )
                    .scaleEffect(scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .onChange(of: library.selectedMissionID) { _ in
            cameraOffsetX = 0
            cameraOffsetY = 0
        }
    }

    @ViewBuilder
    private var classicViewport: some View {
        ZStack {
            EmperorTheme.backgroundApp

            if let city = library.cityState {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ClassicImperialHUD(
                            library: library,
                            city: city,
                            models: models
                        )
                        .frame(width: EmperorTheme.cityMapColumnWidth)

                        ClassicPanelHeader(
                            library: library,
                            title: selectedCategory.advisorTitle,
                            onOpenSummary: { showsCitySummary = true }
                        )
                        .frame(width: EmperorTheme.panelWidth)
                    }
                    .frame(height: EmperorTheme.hudHeight)

                    HStack(spacing: 0) {
                        CityCanvas(
                            city: city,
                            buildingSprites: library.buildingSprites,
                            interfaceSprites: library.interfaceSprites,
                            figureSprites: library.figureSprites,
                            originalMap: library.renderedMap,
                            constructionTool: library.constructionTool,
                            agriculturalCrop: library.selectedAgriculturalCrop,
                            constructionOrientation: library.constructionOrientation,
                            models: models,
                            activeResourceOverlays: library.activeResourceOverlays,
                            selectedMilitaryUnitIDs: library.selectedMilitaryUnitIDs,
                            gameSpeed: library.gameSpeed,
                            lastTickPresentationDate: library.lastCityTickPresentationDate,
                            onPlaceConstruction: library.placeConstruction,
                            onPlaceConstructionArea: library.placeConstructions,
                            onCancelInteraction: library.cancelCurrentInteraction,
                            onBuildingSettingChange: library.applyBuildingSetting,
                            cameraOffsetX: $cameraOffsetX,
                            cameraOffsetY: $cameraOffsetY,
                            showsNavigationOverlay: false
                        )
                        .id(library.selectedMap?.url)
                        .frame(width: EmperorTheme.cityMapColumnWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color.black)
                        .overlay(alignment: .topLeading) {
                            if library.constructionTool != .inspect {
                                ClassicMapHint(
                                    library: library,
                                    tool: library.constructionTool,
                                    instruction: library.saveStatus
                                        ?? constructionInstruction(
                                            library.constructionTool,
                                            orientation: library.constructionOrientation
                                        )
                                )
                                .padding(8)
                                .allowsHitTesting(false)
                            }
                        }
                        .overlay(alignment: .top) {
                            if library.gameSpeed == 0 {
                                ClassicPauseBanner()
                                    .padding(.top, 7)
                                    .allowsHitTesting(false)
                            }
                        }

                        ClassicControlPanel(
                            library: library,
                            city: city,
                            models: models,
                            selectedCategory: $selectedCategory,
                            cameraOffsetX: $cameraOffsetX,
                            cameraOffsetY: $cameraOffsetY
                        )
                        .frame(width: EmperorTheme.panelWidth)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(EmperorTheme.border)
                                .frame(width: 1)
                        }
                    }
                    .frame(
                        height: EmperorTheme.classicViewportSize.height
                            - EmperorTheme.hudHeight
                    )
                }

                if let runtime = library.campaignRuntimeState,
                   runtime.outcome != .running {
                    MissionOutcomeOverlay(
                        outcome: runtime.outcome,
                        missionTitle: activeMission?.title ?? "当前任务",
                        onNextMission: library.startNextMission,
                        onReplay: library.replayMission,
                        onLoadRecent: library.loadMostRecentSave,
                        onReturn: library.returnToCampaignList
                    )
                }
            } else {
                ProgressView("正在初始化城市状态…")
                    .tint(EmperorTheme.primary)
                    .foregroundStyle(EmperorTheme.onSurface)
            }
        }
        .sheet(isPresented: $showsCitySummary) {
            if let city = library.cityState {
                ClassicCitySummaryView(city: city, models: models)
            }
        }
    }

    private var activeMission: CampaignMission? {
        guard let missionID = library.selectedMissionID else { return nil }
        return library.selectedCampaign?.missions.first { $0.id == missionID }
    }
}

private struct ClassicPauseBanner: View {
    var body: some View {
        Text("游戏暂停（按 P 键继续）")
            .font(EmperorTheme.bold(size: 15))
            .foregroundStyle(ClassicPalette.gold)
            .frame(width: 448, height: 38)
            .background(ClassicPalette.deepBrown.opacity(0.94))
            .overlay {
                Rectangle()
                    .strokeBorder(ClassicPalette.gold.opacity(0.85), lineWidth: 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("游戏暂停，按 P 键继续")
            .accessibilityIdentifier("city-pause-banner")
    }
}

private struct ClassicPanelHeader: View {
    @ObservedObject var library: LibraryModel
    let title: String
    let onOpenSummary: () -> Void

    var body: some View {
        Button(action: onOpenSummary) {
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: EmperorTheme.categoryRailWidth)
                Text(title)
                    .font(EmperorTheme.headlineSmall)
                    .frame(maxWidth: .infinity)
            }
            .offset(y: EmperorTheme.hudRoofHeight / 2)
            .foregroundStyle(ClassicPalette.gold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(alignment: .top) {
            if let sprite = library.interfaceSprites[
                OriginalInterfaceChromeSpriteCatalog.cityPanelBackgroundImageID
            ] {
                Image(decorative: sprite.image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: EmperorTheme.panelWidth,
                        height: 454,
                        alignment: .top
                    )
                    .frame(
                        width: EmperorTheme.panelWidth,
                        height: EmperorTheme.hudHeight,
                        alignment: .top
                    )
                    .clipped()
            } else {
                ClassicPalette.panelHeader
            }
        }
        .help("打开城市状况总览")
        .accessibilityLabel("\(title)顾问")
        .accessibilityIdentifier("city-summary-open")
    }
}

private struct ClassicImperialHUD: View {
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    let models: OriginalEconomyModels

    var body: some View {
        HStack(spacing: 0) {
            menuBar
                .frame(width: 142, alignment: .leading)

            Spacer()
                .frame(width: 24)

            ClassicHUDSpriteMetric(
                library: library,
                imageID: OriginalInterfaceChromeSpriteCatalog.treasuryImageID,
                fallbackSymbol: "banknote.fill",
                label: "国库",
                value: "\(city.economy.treasury)"
            )
            .frame(width: 91)
            .accessibilityIdentifier("hud-treasury-metric")

            ClassicHUDSpriteMetric(
                library: library,
                imageID: OriginalInterfaceChromeSpriteCatalog.laborImageID,
                fallbackSymbol: "person.fill",
                label: "可用劳工",
                value: "\(city.workforceSnapshot(models: models.buildings).unemployedWorkers)"
            )
            .frame(width: 70)
            .accessibilityIdentifier("hud-population-metric")

            Spacer()
                .frame(width: 10)

            ClassicHUDZodiac(
                library: library,
                element: calendarElement,
                animal: calendarAnimal
            )
            .frame(width: 105)

            Spacer(minLength: 24)

            Text(imperialDate)
                .font(EmperorTheme.metric)
                .foregroundStyle(EmperorTheme.onSurface)
                .frame(width: 145, alignment: .trailing)
                .accessibilityLabel("日期 \(imperialDate)")
                .accessibilityIdentifier("hud-date-metric")
        }
        .offset(y: EmperorTheme.hudRoofHeight / 2)
        .padding(.horizontal, 8)
        .frame(height: EmperorTheme.hudHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            if let sprite = library.interfaceSprites[
                OriginalInterfaceChromeSpriteCatalog.cityHUDBackgroundImageID
            ] {
                Image(decorative: sprite.image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(
                        width: EmperorTheme.cityMapColumnWidth,
                        height: EmperorTheme.hudHeight
                    )
            } else {
                LinearGradient(
                    colors: [
                        ClassicPalette.warmBrown,
                        ClassicPalette.deepBrown,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .help(missionAccessibilityLabel)
    }

    private var menuBar: some View {
        HStack(spacing: 13) {
            Menu {
                Button("保存城市", action: library.saveCity)
                    .keyboardShortcut("s", modifiers: .command)
                Button("载入城市", action: library.loadCity)
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("返回战役", action: library.returnToCampaignList)
            } label: {
                Text("文件")
                    .font(EmperorTheme.labelMedium)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(EmperorTheme.onSurface)
            .tint(EmperorTheme.onSurface)
            .accessibilityIdentifier("classic-city-game")

            Menu {
                Button(
                    library.musicIsPlaying ? "暂停原版音乐" : "播放原版音乐",
                    action: library.toggleOriginalMusic
                )
                Button("旋转当前建筑", action: library.rotateConstructionTool)
                    .keyboardShortcut("r", modifiers: [])
                    .disabled(!library.constructionTool.supportsRotation)
            } label: {
                Text("选项")
                    .font(EmperorTheme.labelMedium)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(EmperorTheme.onSurface)
            .tint(EmperorTheme.onSurface)

            Button("帮助") {
                library.saveStatus = library.constructionTool == .inspect
                    ? "右键建筑查看详情 · 右键取消建造 · P／空格暂停 · 点击右栏标题查看城市状况"
                    : constructionInstruction(
                        library.constructionTool,
                        orientation: library.constructionOrientation
                    )
            }
            .buttonStyle(.plain)
            .font(EmperorTheme.labelMedium)
            .foregroundStyle(EmperorTheme.onSurface)
        }
    }

    private var activeMission: CampaignMission? {
        guard let campaign = library.selectedCampaign,
              let missionID = library.selectedMissionID,
              let mission = campaign.missions.first(where: { $0.id == missionID }) else {
            return nil
        }
        return mission
    }

    private var missionStage: String {
        guard let campaign = library.selectedCampaign,
              let mission = activeMission else {
            return "自由建造"
        }
        return "\(ClassicTextLocalization.campaignTitle(campaign.title)) · 第\(mission.sequenceNumber)关"
    }

    private var localizedMissionTitle: String {
        activeMission.map {
            ClassicTextLocalization.missionTitle($0.title)
        } ?? "无任务目标"
    }

    private var localizedCityName: String {
        ClassicTextLocalization.cityName(
            library.activeMissionWorld?.playerCityName ?? "原生城市"
        )
    }

    private var missionAccessibilityLabel: String {
        "\(missionStage) · \(localizedMissionTitle) · 当前城市 \(localizedCityName)"
    }

    private var imperialDate: String {
        let month = "\(city.calendar.month)月"
        if city.calendar.year < 0 {
            return "\(month) \(abs(city.calendar.year)) 公元前"
        }
        return "\(month) \(city.calendar.year) 年"
    }

    private var calendarAnimal: String {
        let animals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
        let astronomicalYear = city.calendar.year < 0
            ? city.calendar.year + 1
            : city.calendar.year
        return animals[positiveModulo(astronomicalYear - 4, divisor: animals.count)]
    }

    private var calendarElement: String {
        let elements = ["木", "木", "火", "火", "土", "土", "金", "金", "水", "水"]
        let astronomicalYear = city.calendar.year < 0
            ? city.calendar.year + 1
            : city.calendar.year
        return elements[positiveModulo(astronomicalYear - 4, divisor: elements.count)]
    }

    private func positiveModulo(_ value: Int, divisor: Int) -> Int {
        let result = value % divisor
        return result >= 0 ? result : result + divisor
    }
}

private struct ClassicHUDSpriteMetric: View {
    @ObservedObject var library: LibraryModel
    let imageID: Int?
    let fallbackSymbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let imageID, let sprite = library.interfaceSprites[imageID] {
                    Image(decorative: sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Image(systemName: fallbackSymbol)
                        .foregroundStyle(ClassicPalette.gold)
                }
            }
            .frame(width: 18, height: 18)
            Text(value)
                .font(EmperorTheme.metric)
                .foregroundStyle(EmperorTheme.onSurface)
        }
        .frame(height: 24)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
        .accessibilityValue(value)
    }
}

private struct ClassicHUDZodiac: View {
    @ObservedObject var library: LibraryModel
    let element: String
    let animal: String

    var body: some View {
        HStack(spacing: 7) {
            Text(element)
                .font(EmperorTheme.metric)
                .foregroundStyle(EmperorTheme.onSurface)
            Group {
                if let imageID = OriginalInterfaceChromeSpriteCatalog.zodiacImageID(
                    for: animal
                ),
                   let sprite = library.interfaceSprites[imageID] {
                    Image(decorative: sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Text(animal)
                        .font(EmperorTheme.metric)
                }
            }
            .frame(width: 22, height: 22)
            Text(animal)
                .font(EmperorTheme.metric)
                .foregroundStyle(EmperorTheme.onSurface)
        }
        .frame(height: 24)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(element)\(animal)年")
        .accessibilityIdentifier("hud-zodiac-metric")
    }
}

private struct ClassicMapHint: View {
    @ObservedObject var library: LibraryModel
    let tool: NativeConstructionTool
    let instruction: String

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if let sprite = originalConstructionSprite {
                    Image(decorative: sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Image(systemName: tool.symbol)
                        .foregroundStyle(EmperorTheme.primary)
                }
            }
            .frame(width: 26, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(tool.title)
                    .font(EmperorTheme.headlineSmall)
                    .foregroundStyle(EmperorTheme.onSurface)
                Text(instruction)
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(ClassicPalette.deepBrown.opacity(0.78))
        .overlay(
            Rectangle()
                .strokeBorder(ClassicPalette.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(instruction)
        .accessibilityIdentifier("player-command-status")
        .accessibilityValue(instruction)
    }

    private var originalConstructionSprite: RenderedTerrainSprite? {
        let reference: BuildingSpriteReference?
        if tool == .house {
            reference = OriginalBuildingSpriteCatalog.housingSprite(
                forHouseLevelID: 0,
                orientation: library.constructionOrientation
            )
        } else if let buildingID = tool.buildingID {
            reference = OriginalBuildingSpriteCatalog.buildingComponents(
                forBuildingID: buildingID,
                orientation: library.constructionOrientation
            ).first?.sprite
        } else {
            reference = nil
        }
        guard let reference else { return nil }
        return library.buildingSprites[reference]
    }
}

/// Fits the complete original isometric assembly into a classic construction
/// slot. Composite buildings such as warehouses and markets otherwise show
/// only one small bay, which makes adjacent catalog choices indistinguishable.
private struct ClassicBuildingCatalogThumbnail: View {
    struct Item: Identifiable {
        let id: Int
        let sprite: RenderedTerrainSprite
        let rectangle: CGRect
    }

    let components: [BuildingSpriteComponent]
    let sprites: [BuildingSpriteReference: RenderedTerrainSprite]

    var body: some View {
        GeometryReader { geometry in
            let items = layoutItems
            let bounds = items.reduce(CGRect.null) { $0.union($1.rectangle) }
            let scale = min(
                max(0, geometry.size.width - 2) / max(1, bounds.width),
                max(0, geometry.size.height - 2) / max(1, bounds.height)
            )
            ZStack {
                ForEach(items) { item in
                    Image(decorative: item.sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(
                            width: item.rectangle.width * scale,
                            height: item.rectangle.height * scale
                        )
                        .position(
                            x: geometry.size.width * 0.5
                                + (item.rectangle.midX - bounds.midX) * scale,
                            y: geometry.size.height * 0.5
                                + (item.rectangle.midY - bounds.midY) * scale
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }

    private var layoutItems: [Item] {
        components.sorted { lhs, rhs in
            let lhsDepth = lhs.tileOffsetX + lhs.tileOffsetY
                + lhs.footprint.width + lhs.footprint.height
            let rhsDepth = rhs.tileOffsetX + rhs.tileOffsetY
                + rhs.footprint.width + rhs.footprint.height
            return lhsDepth < rhsDepth
        }.enumerated().compactMap { index, component in
            guard let sprite = sprites[component.sprite] else { return nil }
            let tileWidth: CGFloat = 80
            let tileHeight: CGFloat = 40
            let centerX = CGFloat(component.tileOffsetX - component.tileOffsetY)
                * tileWidth * 0.5
            let centerY = CGFloat(component.tileOffsetX + component.tileOffsetY)
                * tileHeight * 0.5
            let imageCenterX = centerX
                + CGFloat(component.footprint.width - component.footprint.height)
                * tileWidth * 0.25
            let imageBottomY = centerY
                + CGFloat(component.footprint.width + component.footprint.height - 1)
                * tileHeight * 0.5
            return Item(
                id: index,
                sprite: sprite,
                rectangle: CGRect(
                    x: imageCenterX - CGFloat(sprite.width) * 0.5,
                    y: imageBottomY - CGFloat(sprite.height),
                    width: CGFloat(sprite.width),
                    height: CGFloat(sprite.height)
                )
            )
        }
    }
}

private struct ClassicControlPanel: View {
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    let models: OriginalEconomyModels
    @Binding var selectedCategory: ConstructionToolCategory
    @Binding var cameraOffsetX: Int
    @Binding var cameraOffsetY: Int
    @State private var showsObjectives = false
    @State private var showsWorldMap = false
    @State private var showsMessages = false
    @State private var showsAdvancedControls = false
    @State private var hoveredCategory: ConstructionToolCategory?
    @State private var hoveredConstructionTool: NativeConstructionTool?
    @State private var hoveredCrop: AgriculturalCrop?

    private let categoryOrder = ConstructionToolCategory.allCases

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                categoryRail
                VStack(spacing: 0) {
                    ClassicCategoryAdvisorPanel(
                        library: library,
                        city: city,
                        models: models,
                        category: selectedCategory
                    )

                    Divider().overlay(ClassicPalette.border)
                    constructionCatalog
                }
                .frame(
                    width: EmperorTheme.panelWidth
                        - EmperorTheme.categoryRailWidth
                )
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(ClassicPalette.border)
                        .frame(width: 1)
                }
            }
            .frame(width: EmperorTheme.panelWidth)
            .frame(maxHeight: .infinity)

            Divider().overlay(ClassicPalette.border)
            constructionUtilityStrip

            Divider().overlay(ClassicPalette.border)
            advancedControlsToggle

            if showsAdvancedControls {
                Divider().overlay(ClassicPalette.border)
                resourceOverlays

                Divider().overlay(ClassicPalette.border)
                ClassicPanelCommandDock(library: library, models: models)
            }

            Divider().overlay(ClassicPalette.border)
            classicMinimap

            Divider().overlay(ClassicPalette.border)
            ClassicCityNavigationBar(
                library: library,
                onCenterView: {
                    cameraOffsetX = 0
                    cameraOffsetY = 0
                },
                onOpenWorldMap: { showsWorldMap = true },
                onOpenObjectives: { showsObjectives = true },
                onOpenMessages: { showsMessages = true }
            )
        }
        .background(
            ClassicOriginalPanelTexture(
                sprite: library.interfaceSprites[
                    OriginalInterfaceChromeSpriteCatalog.cityPanelBackgroundImageID
                ]
            )
        )
        .sheet(isPresented: $showsObjectives) {
            ClassicMissionObjectivesView(library: library, city: city, models: models)
        }
        .sheet(isPresented: $showsWorldMap) {
            ClassicWorldMapView(library: library, models: models)
        }
        .sheet(isPresented: $showsMessages) {
            ClassicCityMessagesView(library: library, city: city, models: models)
        }
        .frame(width: EmperorTheme.panelWidth, alignment: .leading)
        .clipped()
    }

    private var advancedControlsToggle: some View {
        Button {
            showsAdvancedControls.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(EmperorTheme.bold(size: 9))
                Text("图层与城市控制")
                    .font(EmperorTheme.bold(size: 10))
                Spacer(minLength: 0)
                Image(systemName: showsAdvancedControls ? "chevron.down" : "chevron.right")
                    .font(EmperorTheme.bold(size: 8))
            }
            .foregroundStyle(ClassicPalette.gold)
            .padding(.horizontal, 10)
            .frame(width: EmperorTheme.panelWidth, height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(ClassicPalette.deepBrown.opacity(0.58))
        .accessibilityLabel("图层与城市控制")
        .accessibilityValue(showsAdvancedControls ? "已展开" : "已隐藏")
        .accessibilityIdentifier("city-advanced-controls-toggle")
        .help(showsAdvancedControls ? "隐藏图层、税率与速度控制" : "显示图层、税率与速度控制")
    }

    private var categoryRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 1) {
                ForEach(categoryOrder) { category in
                    let available = categoryIsAvailable(category)
                    Button {
                        if library.constructionTool != .inspect,
                           library.constructionTool.category != category {
                            library.cancelCurrentInteraction()
                        }
                        selectedCategory = category
                    } label: {
                        categoryIcon(
                            category,
                            state: categoryIconState(
                                for: category,
                                available: available
                            ),
                            width: 46,
                            height: 37
                        )
                        .frame(width: 48, height: 37)
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                    .onHover { hovering in
                        hoveredCategory = hovering ? category : nil
                    }
                    .accessibilityIdentifier(
                        "construction-category-\(categoryAccessibilitySlug(category))"
                    )
                    .help(category.rawValue)
                }
            }
            .padding(.horizontal, 3)
            .offset(y: -2)
        }
        .frame(width: 54)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var constructionCatalog: some View {
        // Keep always-visible utility tools out of the category grid so the
        // infrastructure page is not mistaken for a Great-Wall / monument menu.
        let utilityTools: Set<NativeConstructionTool> = [
            .inspect, .road, .clearLand, .demolish, .roadblock,
        ]
        let agriculturalProducerTools: Set<NativeConstructionTool> = [
            .farmland, .teaHouse, .lacquerGuild, .silkWeaver,
        ]
        let categoryTools = NativeConstructionTool.allCases.filter {
            $0.category == selectedCategory
                && !utilityTools.contains($0)
                && !agriculturalProducerTools.contains($0)
        }
        let availableTools = categoryTools.filter(isAvailable)
        let cropOrder: [AgriculturalCrop] = [
            .wheat, .soybeans, .rice, .millet, .cabbage,
            .hemp, .tea, .mulberry, .lacquer,
        ]
        let availableCrops = cropOrder.filter(isCropAvailable)
        let availableItems: [ClassicConstructionCatalogItem]
        if selectedCategory == .agriculture {
            availableItems = availableCrops.map(ClassicConstructionCatalogItem.crop)
                + availableTools.map(ClassicConstructionCatalogItem.tool)
        } else {
            availableItems = availableTools.map(ClassicConstructionCatalogItem.tool)
        }
        return ScrollView(.vertical, showsIndicators: true) {
            constructionCatalogGrid(availableItems)
                .padding(.horizontal, 4)
        }
    }

    private func constructionCatalogGrid(
        _ items: [ClassicConstructionCatalogItem]
    ) -> some View {
        let remainder = items.count % classicConstructionGridColumns.count
        let placeholderCount = remainder == 0
            ? 0
            : classicConstructionGridColumns.count - remainder
        return LazyVGrid(
            columns: classicConstructionGridColumns,
            alignment: .leading,
            spacing: 0
        ) {
            ForEach(items) { item in
                constructionCatalogButton(item)
            }
            ForEach(0..<placeholderCount, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 54, height: 53)
            }
        }
    }

    @ViewBuilder
    private func constructionCatalogButton(
        _ item: ClassicConstructionCatalogItem
    ) -> some View {
        switch item {
        case let .crop(crop):
            cropButton(crop)
        case let .tool(tool):
            constructionButton(tool)
        }
    }

    private var classicConstructionGridColumns: [GridItem] {
        [
            GridItem(.fixed(54), spacing: 0),
            GridItem(.fixed(54), spacing: 0),
            GridItem(.fixed(54), spacing: 0),
        ]
    }

    private func cropButton(_ crop: AgriculturalCrop) -> some View {
        let selected = library.constructionTool == .farmland
            && library.selectedAgriculturalCrop == crop
        return Button {
            library.selectAgriculturalCrop(crop)
        } label: {
            Group {
                if let sprite = originalCropButtonSprite(
                    for: crop,
                    state: constructionButtonState(
                        selected: selected,
                        hovered: hoveredCrop == crop
                    )
                ) {
                    Image(decorative: sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 54, height: 53)
                        .accessibilityHidden(true)
                } else if let sprite = agriculturalSprite(for: crop) {
                    Image(decorative: sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: 49, maxHeight: 46)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: crop.category == .orchard ? "tree.fill" : "leaf.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(height: 34)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 54, height: 53)
            .foregroundStyle(Color.white.opacity(0.92))
        }
        .buttonStyle(.plain)
        .disabled(!isCropAvailable(crop))
        .onHover { hovering in
            hoveredCrop = hovering ? crop : nil
        }
        .accessibilityIdentifier("construction-crop-\(crop.rawValue)")
        .help(
            isCropAvailable(crop)
                ? "\(crop.fieldTitle)：点击清地种植 1 格，须邻接道路"
                : "\(crop.fieldTitle)：本关暂未开放"
        )
    }

    /// Always-visible road / clear / demolish strip modeled on the original
    /// city panel tool row above the minimap.
    private var constructionUtilityStrip: some View {
        let tools: [NativeConstructionTool] = [
            .inspect, .road, .clearLand, .demolish, .roadblock,
        ]
        return HStack(spacing: 5) {
            ForEach(tools) { tool in
                Button {
                    library.selectConstructionTool(tool)
                } label: {
                    VStack(spacing: 2) {
                        constructionToolIcon(tool)
                        Text(tool.title)
                            .font(EmperorTheme.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(
                        library.constructionTool == tool
                            ? ClassicPalette.ink
                            : Color.white.opacity(0.92)
                    )
                    .background(
                        library.constructionTool == tool
                            ? ClassicPalette.gold
                            : ClassicPalette.tileBrown
                    )
                    .overlay(
                        Rectangle().strokeBorder(
                            library.constructionTool == tool
                                ? ClassicPalette.gold
                                : ClassicPalette.border,
                            lineWidth: library.constructionTool == tool ? 1.2 : 0.7
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable(tool))
                .accessibilityIdentifier("utility-tool-\(tool.rawValue)")
                .help(
                    isAvailable(tool)
                        ? constructionInstruction(
                            tool,
                            orientation: library.constructionOrientation
                        )
                        : "\(tool.title)：本关暂未开放"
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ClassicPalette.panelBrown)
    }

    private func constructionButton(_ tool: NativeConstructionTool) -> some View {
        let selected = library.constructionTool == tool
        return Button {
            library.selectConstructionTool(tool)
        } label: {
            constructionToolIcon(
                tool,
                buttonState: constructionButtonState(
                    selected: selected,
                    hovered: hoveredConstructionTool == tool
                )
            )
            .frame(width: 54, height: 53)
            .foregroundStyle(Color.white.opacity(0.92))
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable(tool))
        .onHover { hovering in
            hoveredConstructionTool = hovering ? tool : nil
        }
        .accessibilityIdentifier("construction-tool-\(tool.rawValue)")
        .help(
            isAvailable(tool)
                ? constructionInstruction(
                    tool,
                    orientation: library.constructionOrientation
                )
                : "\(tool.title)：本关暂未开放"
        )
    }

    @ViewBuilder
    private func constructionToolIcon(
        _ tool: NativeConstructionTool,
        buttonState: OriginalConstructionButtonState = .normal
    ) -> some View {
        if let sprite = originalConstructionButtonSprite(
            for: tool,
            state: buttonState
        ) {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 54, height: 53)
                .accessibilityHidden(true)
        } else if let sprite = utilityToolSprite(for: tool) {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: 48, maxHeight: 27)
                .accessibilityHidden(true)
        } else if !constructionCatalogComponents(for: tool).isEmpty,
                  constructionCatalogComponents(for: tool).contains(where: {
                      library.buildingSprites[$0.sprite] != nil
                  }) {
            ClassicBuildingCatalogThumbnail(
                components: constructionCatalogComponents(for: tool),
                sprites: library.buildingSprites
            )
            .frame(width: 50, height: 48)
        } else if let sprite = originalConstructionSprite(for: tool) {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: 49, maxHeight: 46)
                .accessibilityHidden(true)
        } else {
            Image(systemName: tool.symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(height: 27)
                .accessibilityHidden(true)
        }
    }

    private func constructionButtonState(
        selected: Bool,
        hovered: Bool
    ) -> OriginalConstructionButtonState {
        if selected { return .selected }
        if hovered { return .hover }
        return .normal
    }

    private func originalConstructionButtonSprite(
        for tool: NativeConstructionTool,
        state: OriginalConstructionButtonState
    ) -> RenderedTerrainSprite? {
        guard let buildingID = tool.buildingID,
              let imageID = OriginalConstructionButtonSpriteCatalog.imageID(
                forBuildingID: buildingID,
                state: state
              ) else { return nil }
        return library.interfaceSprites[imageID]
    }

    private func originalCropButtonSprite(
        for crop: AgriculturalCrop,
        state: OriginalConstructionButtonState
    ) -> RenderedTerrainSprite? {
        let imageID = OriginalConstructionButtonSpriteCatalog.cropImageID(
            isRice: crop == .rice,
            isOrchard: crop.category == .orchard,
            state: state
        )
        return library.interfaceSprites[imageID]
    }

    private func constructionCatalogComponents(
        for tool: NativeConstructionTool
    ) -> [BuildingSpriteComponent] {
        if tool == .house,
           let footprint = OriginalBuildingFootprintCatalog.footprint(forBuildingID: 2),
           let reference = OriginalBuildingSpriteCatalog.housingSprite(
            forHouseLevelID: 0,
            orientation: library.constructionOrientation
           ) {
            return [BuildingSpriteComponent(
                sprite: reference,
                tileOffsetX: 0,
                tileOffsetY: 0,
                footprint: footprint
            )]
        }
        guard tool.marketShopBuildingID == nil, let buildingID = tool.buildingID else {
            return []
        }
        return OriginalBuildingSpriteCatalog.buildingComponents(
            forBuildingID: buildingID,
            orientation: library.constructionOrientation
        )
    }

    private func utilityToolSprite(
        for tool: NativeConstructionTool
    ) -> RenderedTerrainSprite? {
        switch tool {
        case .clearLand:
            if let imageID = OriginalInterfaceUtilitySpriteCatalog.imageID(for: .clearLand) {
                return library.interfaceSprites[imageID]
            }
            return nil
        case .demolish:
            if let imageID = OriginalInterfaceUtilitySpriteCatalog.imageID(for: .demolish) {
                return library.interfaceSprites[imageID]
            }
            return nil
        case .road:
            return library.renderedMap?.roadToolIconSprite()
        default:
            return nil
        }
    }

    private func originalConstructionSprite(
        for tool: NativeConstructionTool
    ) -> RenderedTerrainSprite? {
        let reference: BuildingSpriteReference?
        if tool == .house {
            reference = OriginalBuildingSpriteCatalog.housingSprite(
                forHouseLevelID: 0,
                orientation: library.constructionOrientation
            )
        } else if tool == .farmland {
            reference = OriginalBuildingSpriteCatalog.agriculturalPlotSprite(
                for: library.selectedAgriculturalCrop
            )
        } else if let buildingID = tool.buildingID {
            reference = OriginalBuildingSpriteCatalog.constructionCatalogSprite(
                forBuildingID: buildingID,
                orientation: library.constructionOrientation
            )
        } else {
            reference = nil
        }
        guard let reference else { return nil }
        return library.buildingSprites[reference]
    }

    private func agriculturalSprite(
        for crop: AgriculturalCrop
    ) -> RenderedTerrainSprite? {
        library.buildingSprites[
            OriginalBuildingSpriteCatalog.agriculturalPlotSprite(for: crop)
        ]
    }

    @ViewBuilder
    private func categoryIcon(
        _ category: ConstructionToolCategory,
        state: OriginalInterfaceIconState,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        if let imageID = OriginalInterfaceSpriteCatalog.imageID(
            for: category.originalInterfaceIcon,
            state: state
           ),
           let sprite = library.interfaceSprites[imageID] {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: width, height: height)
                .accessibilityHidden(true)
        } else {
            Image(systemName: category.symbol)
                .font(.system(size: min(width, height) * 0.55, weight: .semibold))
                .frame(width: width, height: height)
                .foregroundStyle(
                    state == .selected
                        ? ClassicPalette.gold
                        : Color.white.opacity(state == .disabled ? 0.38 : 0.82)
                )
                .accessibilityHidden(true)
        }
    }

    private func categoryIconState(
        for category: ConstructionToolCategory,
        available: Bool
    ) -> OriginalInterfaceIconState {
        if !available { return .disabled }
        if selectedCategory == category { return .selected }
        if hoveredCategory == category { return .hover }
        return .normal
    }

    private func categoryIsAvailable(_ category: ConstructionToolCategory) -> Bool {
        if category == .agriculture {
            let crops: [AgriculturalCrop] = [
                .wheat, .soybeans, .rice, .millet, .cabbage,
                .hemp, .tea, .mulberry, .lacquer,
            ]
            if crops.contains(where: isCropAvailable) { return true }
        }
        let utilityTools: Set<NativeConstructionTool> = [
            .inspect, .road, .clearLand, .demolish, .roadblock,
        ]
        return NativeConstructionTool.allCases.contains {
            $0.category == category
                && !utilityTools.contains($0)
                && isAvailable($0)
        }
    }

    private var resourceOverlays: some View {
        HStack(spacing: 5) {
            Text("图层")
                .font(EmperorTheme.bold(size: 10))
                .foregroundStyle(.white.opacity(0.55))
            ForEach(ResourceOverlayKind.terrainCases) { kind in
                let isActive = library.activeResourceOverlays.contains(kind)
                Button {
                    library.toggleResourceOverlay(kind)
                } label: {
                    Image(systemName: kind.symbol)
                        .font(EmperorTheme.bodySmall)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(isActive ? Color.black : kind.color)
                        .background(isActive ? kind.color : ClassicPalette.tileBrown)
                        .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 0.7))
                }
                .buttonStyle(.plain)
                .help("高亮\(kind.rawValue)资源")
            }
            Menu {
                ForEach(ResourceOverlayKind.serviceCases) { kind in
                    Button {
                        library.toggleResourceOverlay(kind)
                    } label: {
                        Label(
                            kind.rawValue,
                            systemImage: library.activeResourceOverlays.contains(kind)
                                ? "checkmark.circle.fill"
                                : kind.symbol
                        )
                    }
                }
            } label: {
                let hasActiveServiceLayer = ResourceOverlayKind.serviceCases.contains {
                    library.activeResourceOverlays.contains($0)
                }
                Image(systemName: "person.line.dotted.person.fill")
                    .font(EmperorTheme.bodySmall)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(
                        hasActiveServiceLayer ? ClassicPalette.ink : ClassicPalette.gold
                    )
                    .background(
                        hasActiveServiceLayer ? ClassicPalette.gold : ClassicPalette.tileBrown
                    )
                    .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 0.7))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
            .help("查看住宅的供水、巡察、医疗、娱乐、宗教或税务覆盖")
            Spacer()
            Button {
                library.rotateConstructionTool()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "rotate.right")
                    Image(systemName: library.constructionOrientation.directionSymbol)
                        .font(EmperorTheme.labelSmall)
                }
                .frame(width: 36, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ClassicPalette.gold)
            .keyboardShortcut("r", modifiers: [])
            .disabled(!library.constructionTool.supportsRotation)
            .accessibilityLabel(
                "旋转\(library.constructionTool.title)，当前\(library.constructionOrientation.localizedTitle)"
            )
            .accessibilityIdentifier("construction-rotate")
            .help(
                library.constructionTool.supportsRotation
                    ? "旋转\(library.constructionTool.title)（R），当前\(library.constructionOrientation.localizedTitle)"
                    : "\(library.constructionTool.title)为对称占地，无需旋转"
            )
        }
        .padding(.horizontal, 10)
        .frame(height: EmperorTheme.panelHeaderHeight)
    }

    private var classicMinimap: some View {
        let columns = min(city.roadNetwork.width, 32)
        let rows = min(city.roadNetwork.height, 32)
        let base = classicBaseFocus(city)
        let focus = GridPoint(x: base.x + cameraOffsetX, y: base.y + cameraOffsetY)
        let startX = min(
            max(0, focus.x - columns / 2),
            max(0, city.roadNetwork.width - columns)
        )
        let startY = min(
            max(0, focus.y - rows / 2),
            max(0, city.roadNetwork.height - rows)
        )
        return HStack(spacing: 6) {
            MinimapView(
                city: city,
                mapWidth: city.roadNetwork.width,
                mapHeight: city.roadNetwork.height,
                viewportStartX: startX,
                viewportStartY: startY,
                viewportColumns: columns,
                viewportRows: rows,
                minimapSize: EmperorTheme.minimapSize
            ) { target in
                cameraOffsetX = target.x - base.x
                cameraOffsetY = target.y - base.y
            }
            VStack(spacing: 2) {
                panelPanButton(
                    "arrow.up",
                    originalIcon: .panUp,
                    x: 0,
                    y: -8,
                    label: "视野向北",
                    identifier: "city-pan-north"
                )
                panelPanButton(
                    "arrow.left",
                    originalIcon: .panLeft,
                    x: -8,
                    y: 0,
                    label: "视野向西",
                    identifier: "city-pan-west"
                )
                panelPanButton(
                    "circle.fill",
                    originalIcon: nil,
                    x: 0,
                    y: 0,
                    label: "保持当前视野",
                    identifier: "city-pan-reset"
                )
                panelPanButton(
                    "arrow.right",
                    originalIcon: .panRight,
                    x: 8,
                    y: 0,
                    label: "视野向东",
                    identifier: "city-pan-east"
                )
                panelPanButton(
                    "arrow.down",
                    originalIcon: .panDown,
                    x: 0,
                    y: 8,
                    label: "视野向南",
                    identifier: "city-pan-south"
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 40)
        .frame(height: 154)
    }

    private func panelPanButton(
        _ symbol: String,
        originalIcon: OriginalInterfaceIcon?,
        x: Int,
        y: Int,
        label: String,
        identifier: String
    ) -> some View {
        Button {
            if x == 0, y == 0 {
                cameraOffsetX = 0
                cameraOffsetY = 0
            } else {
                cameraOffsetX += x
                cameraOffsetY += y
            }
        } label: {
            Group {
                if let originalIcon,
                   let imageID = OriginalInterfaceSpriteCatalog.imageID(
                    for: originalIcon
                   ),
                   let sprite = library.interfaceSprites[imageID] {
                    Image(decorative: sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(
                            symbol == "circle.fill"
                                ? ClassicPalette.red
                                : ClassicPalette.gold
                        )
                }
            }
            .frame(width: 20, height: 20)
            .background(ClassicPalette.tileBrown)
            .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .help(label)
    }

    private func isAvailable(_ tool: NativeConstructionTool) -> Bool {
        if tool == .grandCanalSegment {
            return city.aesthetics.grandCanalProject?.isComplete == false
        }
        if tool == .earthenGreatWallSegment {
            return city.aesthetics.earthenGreatWallProject?.isComplete == false
        }
        if tool == .largePalacePhase {
            return city.aesthetics.largePalaceProject?.isComplete == false
        }
        if tool == .phasedMonumentPhase {
            return city.aesthetics.phasedMonumentProjects.contains { !$0.isComplete }
        }
        if tool == .rally {
            guard city.missionSettings != nil else { return true }
            return !city.military.forts.isEmpty || !city.military.defensiveStructures.isEmpty
        }
        return tool.buildingID.map(city.isBuildingAvailableInCampaign) ?? true
    }

    private func isCropAvailable(_ crop: AgriculturalCrop) -> Bool {
        city.isAgriculturalCropAvailable(crop)
    }

}

private struct ClassicCategoryAdvisorPanel: View {
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    let models: OriginalEconomyModels
    let category: ConstructionToolCategory

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            ForEach(advisorActions, id: \.identifier) { action in
                advisorButton(
                    title: action.title,
                    kind: action.kind,
                    identifier: action.identifier
                )
            }

            if let monumentID = activeMapMonumentID {
                Button {
                    library.beginMapMonument(buildingID: monumentID)
                } label: {
                    HStack {
                        Text(mapMonumentIsStarted(monumentID) ? "工程已经开工" : "开始营造")
                        Spacer()
                        Text("#\(monumentID)")
                    }
                    .font(EmperorTheme.bodySmall)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 20)
                    .background(EmperorTheme.surfaceControl)
                    .overlay(Rectangle().strokeBorder(EmperorTheme.secondary, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(mapMonumentIsStarted(monumentID))
                .accessibilityIdentifier("advisor-begin-map-monument")

                if monumentID == GrandCanalProjectRuntime.buildingID,
                   let canal = city.aesthetics.grandCanalProject,
                   !canal.isComplete {
                    Button {
                        library.selectConstructionTool(.grandCanalSegment)
                    } label: {
                        HStack {
                            Text("选择运河分段施工")
                            Spacer()
                            Text("\(canal.completionPercent)%")
                        }
                        .font(EmperorTheme.bodySmall)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .background(EmperorTheme.surfaceControl)
                        .overlay(Rectangle().strokeBorder(EmperorTheme.secondary, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("advisor-select-grand-canal-segment")
                }
                if monumentID == EarthenGreatWallProjectRuntime.buildingID,
                   let wall = city.aesthetics.earthenGreatWallProject,
                   !wall.isComplete {
                    Button {
                        library.selectConstructionTool(.earthenGreatWallSegment)
                    } label: {
                        HStack {
                            Text("选择土长城分段施工")
                            Spacer()
                            Text("\(wall.completionPercent)%")
                        }
                        .font(EmperorTheme.bodySmall)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .background(EmperorTheme.surfaceControl)
                        .overlay(Rectangle().strokeBorder(EmperorTheme.secondary, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("advisor-select-earthen-great-wall-segment")
                }
            }

            Rectangle()
                .fill(EmperorTheme.secondary.opacity(0.68))
                .frame(height: 1)
                .padding(.vertical, 1)

            ForEach(Array(advisorSummary.enumerated()), id: \.offset) { index, line in
                advisorSummaryRow(index: index, line: line)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(height: EmperorTheme.populationAdvisorHeight, alignment: .top)
        .clipped()
        .background(Color.black.opacity(0.06))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(category.advisorTitle)
        .accessibilityIdentifier(
            category == .residential
                ? "advisor-population-panel"
                : "advisor-category-\(category.accessibilitySlug)"
        )
    }

    private var advisorActions: [(title: String, kind: ResourceOverlayKind, identifier: String)] {
        switch category {
        case .residential:
            [
                ("查看住房供给", .housingSupply, "advisor-housing-supply"),
                ("查看城市行人", .walkers, "advisor-city-walkers"),
            ]
        case .agriculture:
            [
                ("查看农业生产", .food, "advisor-production-food"),
                ("查看居民用水", .water, "advisor-agriculture-water"),
            ]
        case .industry:
            [
                ("查看工业资源", .clay, "advisor-industry-resources"),
                ("查看城市行人", .walkers, "advisor-industry-walkers"),
            ]
        case .commerce:
            [
                ("查看商品分配", .walkers, "advisor-commerce-distribution"),
                ("查看税收征缴", .tax, "advisor-commerce-tax"),
            ]
        case .safety:
            [
                ("查看居民用水", .water, "advisor-safety-water"),
                ("查看巡察覆盖", .inspection, "advisor-safety-inspection"),
            ]
        case .government:
            [
                ("查看巡察覆盖", .inspection, "advisor-civic-inspection"),
                ("查看税收征缴", .tax, "advisor-civic-tax"),
            ]
        case .entertainment:
            [
                ("查看全部娱乐", .walkers, "advisor-entertainment-coverage"),
            ]
        case .religious:
            [
                ("查看宗教覆盖", .religion, "advisor-religion-coverage"),
                ("查看城市行人", .walkers, "advisor-religion-walkers"),
            ]
        case .military:
            [
                ("查看城防行人", .walkers, "advisor-military-walkers"),
                ("查看巡察覆盖", .inspection, "advisor-military-inspection"),
            ]
        case .aesthetics:
            [
                ("查看地区吸引力", .housingSupply, "advisor-aesthetics-appeal"),
                ("查看居民用水", .water, "advisor-aesthetics-water"),
            ]
        case .monuments:
            [
                ("查看城市行人", .walkers, "advisor-monuments-walkers"),
            ]
        }
    }

    private var activeMapMonumentID: Int? {
        guard category == .monuments,
              let missionID = library.selectedMissionID,
              let goalSet = library.campaignGoalArchive?.missions.first(where: {
                  $0.id == missionID
              }) else { return nil }
        return goalSet.goals.compactMap { goal in
            if case let .monument(buildingID) = goal.requirement,
               buildingID == 83 || buildingID == 85 {
                return buildingID
            }
            return nil
        }.first
    }

    private func mapMonumentIsStarted(_ buildingID: Int) -> Bool {
        city.aesthetics.monuments.contains { $0.buildingID == buildingID }
            || city.aesthetics.completedMonumentBuildingIDs.contains(buildingID)
    }

    private var advisorSummary: [String] {
        if category == .residential {
            return [
                "目前住宅还可容纳 \(availableHousingCapacity) 人居住",
                migrationStatus,
            ]
        }
        return [
            category.advisorSummary(in: city),
            category.advisorHint,
        ]
    }

    private func advisorButton(
        title: String,
        kind: ResourceOverlayKind,
        identifier: String
    ) -> some View {
        let isActive = library.activeResourceOverlays.contains(kind)
        return Button {
            library.toggleResourceOverlay(kind)
        } label: {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(EmperorTheme.bodySmall)
            .foregroundStyle(isActive ? ClassicPalette.ink : EmperorTheme.onSurface)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 20)
            .background(isActive ? ClassicPalette.gold : EmperorTheme.surfaceControl)
            .overlay(Rectangle().strokeBorder(EmperorTheme.secondary, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isActive ? "已开启" : "已关闭")
    }

    @ViewBuilder
    private func advisorSummaryRow(index: Int, line: String) -> some View {
        if category == .residential, index == 0 {
            VStack(spacing: 0) {
                Text("目前住宅还可容纳")
                    .foregroundStyle(EmperorTheme.onSurface)
                Text("\(availableHousingCapacity)")
                    .font(EmperorTheme.metric)
                    .foregroundStyle(ClassicPalette.gold)
                Text("人居住")
                    .foregroundStyle(EmperorTheme.onSurface)
            }
            .font(EmperorTheme.bodySmall)
            .multilineTextAlignment(.center)
        } else if category == .residential,
                  index == 1,
                  let status = migrationStatusParts {
            VStack(spacing: 1) {
                Text(status.lead)
                    .foregroundStyle(EmperorTheme.onSurface)
                Text(status.emphasis)
                    .foregroundStyle(EmperorTheme.warning)
            }
            .font(EmperorTheme.bodySmall)
            .multilineTextAlignment(.center)
        } else {
            highlightedAdvisorText(line)
                .font(EmperorTheme.bodySmall)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func highlightedAdvisorText(_ line: String) -> Text {
        let metric = category.advisorMetric(in: city)
        guard let range = line.range(of: metric) else {
            return Text(line).foregroundColor(EmperorTheme.onSurface)
        }
        return Text(String(line[..<range.lowerBound]))
            .foregroundColor(EmperorTheme.onSurface)
            + Text(metric).foregroundColor(ClassicPalette.gold)
            + Text(String(line[range.upperBound...]))
                .foregroundColor(EmperorTheme.onSurface)
    }

    private var migrationStatusParts: (lead: String, emphasis: String)? {
        let separator = "原因是："
        guard let range = migrationStatus.range(of: separator) else { return nil }
        return (
            String(migrationStatus[..<range.upperBound]),
            String(migrationStatus[range.upperBound...])
        )
    }

    private var availableHousingCapacity: Int {
        max(0, city.housingCapacity(using: models.buildings) - city.population)
    }

    private var migrationStatus: String {
        guard let assessment = city.migration.lastAssessment else {
            return availableHousingCapacity > 0
                ? "等待下一个模拟日评估迁入条件"
                : "移民受到限制，原因是：缺乏住房"
        }
        switch assessment.blockReason {
        case .none:
            if assessment.plannedImmigrants > 0 {
                return "人们希望迁居你的城市"
            }
            return "人口数较稳定"
        case .noEligibleHousing:
            return "移民受到限制，原因是：缺乏临路住房"
        case .negativeTreasury:
            return "移民受到限制，原因是：国库为负"
        case let .highUnemployment(percent):
            return "移民受到限制，原因是：失业率过高（\(percent)%）"
        }
    }
}

private struct ClassicCityNavigationBar: View {
    @ObservedObject var library: LibraryModel
    let onCenterView: () -> Void
    let onOpenWorldMap: () -> Void
    let onOpenObjectives: () -> Void
    let onOpenMessages: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            navigationButton(
                icon: .mainMenu,
                fallback: "envelope.fill",
                label: "消息",
                identifier: "city-button-messages",
                action: onOpenMessages
            )
            navigationButton(
                icon: .compass,
                fallback: "scope",
                label: "视角复位",
                identifier: "city-button-center-view",
                action: onCenterView
            )
            navigationButton(
                icon: .cityView,
                fallback: "building.2.fill",
                label: "城市",
                identifier: "city-button-city-view",
                action: {}
            )
            navigationButton(
                icon: .worldMap,
                fallback: "globe.asia.australia.fill",
                label: "世界地图",
                identifier: "city-button-world-map",
                disabled: library.campaignEmpireMap == nil,
                action: onOpenWorldMap
            )
            navigationButton(
                icon: .objectives,
                fallback: "scroll.fill",
                label: "任务目标",
                identifier: "city-button-objectives",
                action: onOpenObjectives
            )
        }
        .padding(.horizontal, 14)
        .frame(height: EmperorTheme.cityNavigationHeight)
    }

    private func navigationButton(
        icon: OriginalInterfaceIcon,
        fallback: String,
        label: String,
        identifier: String,
        selected: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                let state: OriginalInterfaceIconState = disabled
                    ? .disabled
                    : selected ? .selected : .normal
                if let imageID = OriginalInterfaceSpriteCatalog.imageID(
                    for: icon,
                    state: state
                ),
                   let sprite = library.interfaceSprites[imageID] {
                    Image(decorative: sprite.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Image(systemName: fallback)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            disabled ? EmperorTheme.onSurfaceMuted : ClassicPalette.gold
                        )
                }
            }
            .frame(width: 36, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(disabled ? "\(label)在本任务中不可用" : label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

private struct ClassicCityMessagesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    let models: OriginalEconomyModels

    var body: some View {
        VStack(spacing: 0) {
            classicDialogHeader(
                title: "城市消息",
                icon: .messages,
                closeIdentifier: "city-messages-close",
                dismiss: dismiss.callAsFunction
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if messageRows.isEmpty {
                        Text("目前没有城市消息")
                            .font(EmperorTheme.bodyMedium)
                            .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    } else {
                        ForEach(messageRows) { row in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: row.symbol)
                                    .foregroundStyle(row.color)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.title)
                                        .font(EmperorTheme.labelMedium)
                                    Text(row.detail)
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(EmperorTheme.surfaceControl)
                            .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 1))
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 400)
        .background(EmperorTheme.surface)
        .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 1))
        .accessibilityIdentifier("city-messages-dialog")
    }

    private var messageRows: [CityMessageRow] {
        let campaignRows = city.campaignEvents.messages.reversed().map { message in
            CityMessageRow(
                id: "campaign-\(message.id)",
                symbol: "envelope.fill",
                title: "战役消息",
                detail: "事件 \(message.kindRawValue)"
                    + (message.amount.map { " · 数量 \($0)" } ?? ""),
                color: ClassicPalette.gold
            )
        }
        let failureRows = (city.operations.lastSettlement?.failures ?? []).map { failure in
            CityMessageRow(
                id: "failure-\(failure.key.category.rawValue)-\(failure.key.instanceID)-\(failure.kind)",
                symbol: failure.kind == .fire ? "flame.fill" : "exclamationmark.triangle.fill",
                title: failure.kind == .fire ? "建筑失火" : "建筑倒塌",
                detail: "位置：\(failure.location.x), \(failure.location.y)",
                color: failure.kind == .fire ? EmperorTheme.warning : EmperorTheme.onSurfaceMuted
            )
        }
        return Array(campaignRows) + failureRows
    }

    private struct CityMessageRow: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
        let color: Color
    }
}

private struct ClassicMissionObjectivesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    let models: OriginalEconomyModels

    var body: some View {
        VStack(spacing: 0) {
            classicDialogHeader(
                title: "任务目标",
                icon: .objectives,
                closeIdentifier: "city-objectives-close",
                dismiss: dismiss.callAsFunction
            )
            ScrollView {
                ClassicMissionGuide(
                    library: library,
                    city: city,
                    models: models,
                    goalLimit: nil
                )
                .padding(16)
            }
        }
        .frame(width: 620, height: 430)
        .background(EmperorTheme.surface)
        .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 1))
        .accessibilityIdentifier("city-objectives-dialog")
    }
}

private struct ClassicWorldMapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryModel
    let models: OriginalEconomyModels

    var body: some View {
        VStack(spacing: 0) {
            classicDialogHeader(
                title: "世界地图",
                icon: .worldMap,
                closeIdentifier: "city-world-map-close",
                dismiss: dismiss.callAsFunction
            )
            if let empire = library.campaignEmpireMap {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(empire.activeCities) { city in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(cityName(city))
                                        .font(EmperorTheme.headlineSmall)
                                        .foregroundStyle(EmperorTheme.onSurface)
                                    Spacer()
                                    Text(routeName(city))
                                        .font(EmperorTheme.labelMedium)
                                        .foregroundStyle(ClassicPalette.gold)
                                }
                                Text("收购：\(commodityNames(city.demandCommodityIDs))")
                                Text("出售：\(commodityNames(city.supplyCommodityIDs))")
                            }
                            .font(EmperorTheme.bodySmall)
                            .foregroundStyle(EmperorTheme.onSurfaceMuted)
                            .padding(10)
                            .background(EmperorTheme.surfaceDeep)
                            .overlay(
                                Rectangle().strokeBorder(
                                    EmperorTheme.border.opacity(0.72),
                                    lineWidth: 1
                                )
                            )
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "globe.asia.australia")
                        .font(.system(size: 34))
                    Text("本任务没有可用的帝国地图")
                        .font(EmperorTheme.headlineSmall)
                }
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider().overlay(ClassicPalette.border)
            Button("返回城市") {
                dismiss()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ClassicPalette.gold)
            .padding(10)
            .accessibilityIdentifier("city-button-city-view")
        }
        .frame(width: 620, height: 480)
        .background(EmperorTheme.surface)
        .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 1))
        .accessibilityIdentifier("city-world-map-dialog")
    }

    private func cityName(_ city: CampaignEmpireCity) -> String {
        let authored = library.cityNames?[nameID: city.nameID] ?? "城市 #\(city.nameID)"
        return ClassicTextLocalization.cityName(authored)
    }

    private func routeName(_ city: CampaignEmpireCity) -> String {
        switch city.routeKind(using: models.trade) {
        case .land: "陆路"
        case .sea: "海路"
        case nil: "间隔 \(city.tradeVisitInterval)"
        }
    }

    private func commodityNames(_ commodityIDs: [Int]) -> String {
        guard !commodityIDs.isEmpty else { return "—" }
        return commodityIDs.map {
            models.trade[commodityID: $0]
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? "#\($0)"
        }.joined(separator: "、")
    }
}

private func classicDialogHeader(
    title: String,
    icon: OriginalInterfaceIcon,
    closeIdentifier: String,
    dismiss: @escaping () -> Void
) -> some View {
    let systemName: String = switch icon {
    case .worldMap: "globe.asia.australia.fill"
    case .messages: "envelope.fill"
    default: "scroll.fill"
    }
    return HStack(spacing: 8) {
        Image(systemName: systemName)
            .foregroundStyle(ClassicPalette.gold)
        Text(title)
            .font(EmperorTheme.headlineSmall)
            .foregroundStyle(ClassicPalette.gold)
        Spacer()
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(EmperorTheme.onSurfaceMuted)
        .help("关闭\(title)")
        .accessibilityIdentifier(closeIdentifier)
    }
    .padding(.horizontal, 12)
    .frame(height: 42)
    .background(ClassicPalette.panelHeader)
}

private struct ClassicCitySummaryView: View {
    @Environment(\.dismiss) private var dismiss

    private struct SummaryRow: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let value: String
        let detail: String
        let isHealthy: Bool
    }

    let city: DeterministicCityState
    let models: OriginalEconomyModels

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(ClassicPalette.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("城市状况总览")
                        .font(EmperorTheme.headlineSmall)
                        .foregroundStyle(ClassicPalette.gold)
                    Text("点击右侧栏标题可随时查看")
                        .font(EmperorTheme.labelSmall)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
                Spacer()
                Text("\(city.population) 人")
                    .font(EmperorTheme.metric)
                    .foregroundStyle(EmperorTheme.onSurface)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                .help("关闭城市状况总览")
            }
            .padding(12)
            .background(ClassicPalette.panelHeader)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(summaryRows) { row in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: row.symbol)
                                .frame(width: 18)
                                .foregroundStyle(
                                    row.isHealthy
                                        ? EmperorTheme.success
                                        : EmperorTheme.warning
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(row.title)
                                        .font(EmperorTheme.labelMedium)
                                    Spacer()
                                    Text(row.value)
                                        .font(EmperorTheme.metric)
                                }
                                Text(row.detail)
                                    .font(EmperorTheme.bodySmall)
                                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(EmperorTheme.onSurface)

                        if row.id != summaryRows.last?.id {
                            Divider()
                                .overlay(EmperorTheme.border.opacity(0.55))
                        }
                    }
                }
            }
            .frame(maxHeight: 470)
        }
        .frame(width: 390)
        .background(EmperorTheme.surface)
        .overlay(
            Rectangle()
                .strokeBorder(ClassicPalette.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("city-summary")
    }

    private var summaryRows: [SummaryRow] {
        let occupiedHouses = city.houses.filter { $0.residents > 0 }
        let occupiedCount = occupiedHouses.count
        let workforce = city.workforceSnapshot(models: models.buildings)
        let unemploymentPercent = workforce.availableWorkers > 0
            ? workforce.unemployedWorkers * 100 / workforce.availableWorkers
            : 0
        let assessment = city.migration.lastAssessment
        let migrationHealthy = assessment?.blockReason == nil
        let foodProduction = city.productionAccounting
            .currentProductionUnitsByCommodityID
            .filter { OriginalFoodCatalog.isMillCommodity($0.key) }
            .values
            .reduce(0, +) / 100
        let storedFood = city.logistics.mills.reduce(0) {
            $0 + $1.inventoryByCommodityID
                .filter { OriginalFoodCatalog.isMillCommodity($0.key) }
                .values
                .reduce(0, +)
        } / 100
        let medicalCoverage = coverageCount(in: occupiedHouses) {
            $0.serviceCoverage.contains(.water)
                || $0.serviceCoverage.contains(.herbalist)
                || $0.serviceCoverage.contains(.acupuncture)
        }
        let entertainmentCoverage = coverageCount(in: occupiedHouses) {
            $0.serviceCoverage.contains(.music)
                || $0.serviceCoverage.contains(.acrobat)
                || $0.serviceCoverage.contains(.drama)
        }
        let religionCoverage = coverageCount(in: occupiedHouses) {
            $0.serviceCoverage.contains(.ancestor)
                || $0.serviceCoverage.contains(.confucian)
                || $0.serviceCoverage.contains(.daoistOrBuddhist)
        }
        let constableCoverage = coverageCount(in: occupiedHouses) {
            $0.serviceCoverage.contains(.constable)
        }
        let worstCrimeRisk = city.publicHealthSafety.records.map(\.crimeRisk).max() ?? 0
        let currentProfit = city.productionAccounting.currentIncome
            - city.productionAccounting.currentExpenses
        let livingUnits = city.military.units.filter { $0.hitPoints > 0 }.count
        let invasionPending = city.campaignEvents.invasions.contains {
            $0.status == .awaitingDefense
        }

        return [
            SummaryRow(
                id: "popularity",
                symbol: "person.3.fill",
                title: "民心",
                value: migrationHealthy && unemploymentPercent <= 10 ? "稳定" : "承压",
                detail: unemploymentPercent > 10
                    ? "失业率偏高会阻碍移民进入城市。"
                    : "就业和国库目前没有阻断城市发展。",
                isHealthy: migrationHealthy && unemploymentPercent <= 10
            ),
            SummaryRow(
                id: "migration",
                symbol: "figure.walk.arrival",
                title: "移民",
                value: "本月 +\(city.migration.currentMonthImmigrants)",
                detail: migrationDetail(assessment),
                isHealthy: migrationHealthy
            ),
            SummaryRow(
                id: "food-production",
                symbol: "leaf.fill",
                title: "产粮",
                value: "\(foodProduction) 担／月",
                detail: foodProduction > 0 ? "本月已有粮食产出。" : "本月尚无粮食进入生产统计。",
                isHealthy: foodProduction > 0 || city.population == 0
            ),
            SummaryRow(
                id: "food-storage",
                symbol: "shippingbox.fill",
                title: "储粮",
                value: "\(storedFood) 担",
                detail: storedFood > 0 ? "磨坊中已有可供市场调取的粮食。" : "磨坊没有可用粮食库存。",
                isHealthy: storedFood > 0 || city.population == 0
            ),
            SummaryRow(
                id: "employment",
                symbol: "hammer.fill",
                title: "就业",
                value: "失业 \(unemploymentPercent)%",
                detail: workforce.workerShortage > 0
                    ? "仍缺少 \(workforce.workerShortage) 名劳工，部分设施可能停摆。"
                    : "现有设施的劳工需求已满足。",
                isHealthy: unemploymentPercent <= 10 && workforce.workerShortage == 0
            ),
            SummaryRow(
                id: "health",
                symbol: "cross.case.fill",
                title: "公共卫生",
                value: coverageText(medicalCoverage, total: occupiedCount),
                detail: (city.publicHealthSafety.lastSettlement?.diseaseDeaths ?? 0) > 0
                    ? "上月疾病造成 \(city.publicHealthSafety.lastSettlement?.diseaseDeaths ?? 0) 人死亡。"
                    : "供水或医疗服务覆盖 \(medicalCoverage) 户。",
                isHealthy: occupiedCount == 0 || medicalCoverage == occupiedCount
            ),
            SummaryRow(
                id: "unrest",
                symbol: "exclamationmark.shield.fill",
                title: "治安",
                value: "最高风险 \(worstCrimeRisk)",
                detail: "捕快覆盖 \(constableCoverage)/\(occupiedCount) 户；风险达到 100 会触发盗窃。",
                isHealthy: worstCrimeRisk < 70
            ),
            SummaryRow(
                id: "finance",
                symbol: "banknote.fill",
                title: "财政",
                value: "\(city.economy.treasury) 钱",
                detail: "本月净收支 \(currentProfit >= 0 ? "+" : "")\(currentProfit)。",
                isHealthy: city.economy.treasury >= 0 && currentProfit >= 0
            ),
            SummaryRow(
                id: "entertainment",
                symbol: "music.note",
                title: "娱乐",
                value: coverageText(entertainmentCoverage, total: occupiedCount),
                detail: "音乐、杂技或戏剧服务覆盖 \(entertainmentCoverage) 户。",
                isHealthy: occupiedCount == 0 || entertainmentCoverage == occupiedCount
            ),
            SummaryRow(
                id: "religion",
                symbol: "sparkles",
                title: "宗教",
                value: coverageText(religionCoverage, total: occupiedCount),
                detail: "祖先、儒家、道教或佛教服务覆盖 \(religionCoverage) 户。",
                isHealthy: occupiedCount == 0 || religionCoverage == occupiedCount
            ),
            SummaryRow(
                id: "defense",
                symbol: "shield.fill",
                title: "国防",
                value: "\(livingUnits) 支部队",
                detail: invasionPending
                    ? "敌军来袭，现有 \(city.military.forts.count) 座要塞可组织防御。"
                    : "当前没有等待处理的入侵警报。",
                isHealthy: !invasionPending || livingUnits > 0
            ),
        ]
    }

    private func coverageCount(
        in houses: [ResidentialUnit],
        matching predicate: (ResidentialUnit) -> Bool
    ) -> Int {
        houses.filter(predicate).count
    }

    private func coverageText(_ covered: Int, total: Int) -> String {
        guard total > 0 else { return "暂无住户" }
        return "\(covered)/\(total) 户"
    }

    private func migrationDetail(_ assessment: MigrationAssessment?) -> String {
        guard let assessment else { return "等待下一个模拟日评估迁入条件。" }
        switch assessment.blockReason {
        case .none:
            return "尚有 \(assessment.availableCapacity) 人容量，预计每日迁入 \(assessment.plannedImmigrants) 人。"
        case .noEligibleHousing:
            return "没有临路且仍有空位的住宅。"
        case .negativeTreasury:
            return "国库为负，暂时没有移民迁入。"
        case let .highUnemployment(percent):
            return "失业率 \(percent)% 过高，暂时没有移民迁入。"
        }
    }
}

private struct ClassicMissionGuide: View {
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    let models: OriginalEconomyModels
    var goalLimit: Int? = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 5) {
                    if let imageID = OriginalInterfaceSpriteCatalog.imageID(
                        for: .objectives
                    ),
                       let sprite = library.interfaceSprites[imageID] {
                        Image(decorative: sprite.image, scale: 1)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 22, height: 18)
                    } else {
                        Image(systemName: "scroll.fill")
                    }
                    Text("任务目标")
                }
                .font(EmperorTheme.bold(size: 12))
                .foregroundStyle(ClassicPalette.gold)
                Spacer()
                Text("\(imperialYear) · \(city.calendar.month) 月")
                    .font(EmperorTheme.metric)
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
            }

            if let goalSet, !goalSet.goals.isEmpty {
                let snapshot = city.campaignGoalProgressSnapshot()
                ForEach(displayedGoals) { goal in
                    CampaignGoalRow(
                        goal: goal,
                        economy: models,
                        progress: CampaignGoalEvaluator.evaluate(goal, against: snapshot)
                    )
                    .foregroundStyle(EmperorTheme.onSurface)
                }
            } else {
                Text("建设一座稳定繁荣的城市")
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
            }

            Divider().overlay(EmperorTheme.border.opacity(0.55))

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: nextStep.complete ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .foregroundStyle(nextStep.complete ? EmperorTheme.success : ClassicPalette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextStep.title)
                        .font(EmperorTheme.labelMedium)
                        .foregroundStyle(EmperorTheme.onSurface)
                    Text(nextStep.detail)
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("campaign-goal-status")
        .accessibilityValue(accessibilityStatus)
    }

    private var goalSet: CampaignMissionGoalSet? {
        guard let missionID = library.selectedMissionID else { return nil }
        return library.campaignGoalArchive?.missions.first { $0.id == missionID }
    }

    private var displayedGoals: [CampaignMissionGoal] {
        guard let goals = goalSet?.goals else { return [] }
        guard let goalLimit else { return goals }
        return Array(goals.prefix(goalLimit))
    }

    private var imperialYear: String {
        city.calendar.year < 0
            ? "\(abs(city.calendar.year)) 公元前"
            : "\(city.calendar.year) 年"
    }

    private var nextStep: (title: String, detail: String, complete: Bool) {
        let placements = city.placedBuildings
        let missionSequence = library.selectedCampaign?.missions
            .first(where: { $0.id == library.selectedMissionID })?
            .sequenceNumber ?? 1
        let goalSnapshot = city.campaignGoalProgressSnapshot()
        let housingGoal = goalSet?.goals.first(where: { $0.kind == .housing })
        let targetPopulation: Int = {
            if let housingGoal,
               case let .housing(_, residents) = housingGoal.requirement {
                return max(residents, 1)
            }
            return missionSequence <= 1 ? 150 : 250
        }()

        if city.houses.isEmpty {
            return ("先铺路，再建住宅", "选“基础设施 → 道路”，在空地延伸道路；再选“住宅”沿路放置。", false)
        }
        if !placements.contains(where: { $0.buildingID == 72 }) {
            return ("为住宅供水", "选分类中的水井，放在道路旁并覆盖住房。", false)
        }

        let hasHunting = placements.contains(where: { $0.buildingID == 33 })
        let hasMill = placements.contains(where: { $0.buildingID == 53 })
        let hasMarket = placements.contains(where: { $0.buildingID == 59 })
        if !(hasHunting && hasMill && hasMarket) {
            return (
                "建立食物供应链",
                missionSequence >= 2
                    ? "沿路建设猎场/农场、磨坊和市场；第二关起可用仓库缓冲货物。"
                    : "沿路建设猎场、磨坊和市场；猎场须靠近猎物资源。",
                false
            )
        }

        if missionSequence >= 2,
           city.isAgriculturalCropAvailable(.millet)
            || city.isAgriculturalCropAvailable(.wheat),
           !placements.contains(where: { $0.buildingID == 193 }) {
            return ("开垦粮田", "在低地清地种植粟/麦等本关允许的作物，并保证道路连到磨坊。", false)
        }

        if missionSequence >= 2,
           !placements.contains(where: { $0.buildingID == 54 }),
           city.campaignConstructionRestriction(forBuildingID: 54) == nil {
            return ("建造仓库", "仓库可缓存粮食与苎麻，避免磨坊和市场断供。", false)
        }

        if !placements.contains(where: { $0.buildingID == 214 }) {
            return ("供奉先祖", "建造祖庙，让祭司沿路服务住宅，以满足住房升级条件。", false)
        }

        if city.population < targetPopulation {
            return (
                "让时间运行",
                "在右栏选择 3×，等待移民入住；目标约 \(targetPopulation) 人。",
                false
            )
        }

        if let housingGoal {
            let progress = CampaignGoalEvaluator.evaluate(housingGoal, against: goalSnapshot)
            if !progress.isSatisfied {
                return ("继续提升住房", "保持供水、食物、服务与吸引力，推动住宅升到任务要求等级。", false)
            }
        }

        return ("城市已经可以运转", "继续满足上方原版任务目标，或保存当前进度。", true)
    }

    private var accessibilityStatus: String {
        let outcome: String
        switch library.campaignRuntimeState?.outcome {
        case .victory?: outcome = "victory"
        case .defeat?: outcome = "defeat"
        default: outcome = "running"
        }
        return "outcome=\(outcome);year=\(city.calendar.year);month=\(city.calendar.month);day=\(city.simulationClock.day);population=\(city.population);treasury=\(city.economy.treasury);debtMonths=\(library.campaignRuntimeState?.consecutiveDebtMonths ?? 0)"
    }
}

private struct ClassicPanelCommandDock: View {
    @ObservedObject var library: LibraryModel
    let models: OriginalEconomyModels

    var body: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(models.taxSentiment.bands) { band in
                    Button("税率 \(band.taxRatePercent)%") {
                        library.setTaxBand(band.id)
                    }
                }
            } label: {
                Text("税\(selectedTaxRatePercent)%")
                    .font(EmperorTheme.bold(size: 9))
                    .foregroundStyle(ClassicPalette.gold)
                    .frame(width: 40, height: 22)
                    .background(ClassicPalette.tileBrown)
                    .overlay(
                        Rectangle().strokeBorder(
                            ClassicPalette.border,
                            lineWidth: 0.7
                        )
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("调整税率")
            .accessibilityLabel("税率")
            .accessibilityValue("\(selectedTaxRatePercent)%")
            .accessibilityIdentifier("tax-rate-menu")

            commandButton(
                library.musicIsPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill",
                help: library.musicIsPlaying ? "暂停原版音乐" : "播放原版音乐",
                action: library.toggleOriginalMusic
            )
            commandButton("folder", help: "载入", action: library.loadCity)
                .keyboardShortcut("o", modifiers: .command)
            commandButton("square.and.arrow.down", help: "保存", action: library.saveCity)
                .keyboardShortcut("s", modifiers: .command)

            ForEach(Array(0...3), id: \.self) { speed in
                Button {
                    library.setGameSpeed(speed)
                } label: {
                    Text(speed == 0 ? "Ⅱ" : "\(speed)×")
                        .font(EmperorTheme.bold(size: 9))
                        .frame(width: 24, height: 22)
                        .foregroundStyle(
                            library.gameSpeed == speed ? ClassicPalette.ink : Color.white
                        )
                        .background(
                            library.gameSpeed == speed
                                ? ClassicPalette.gold
                                : ClassicPalette.tileBrown
                        )
                        .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 0.7))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("game-speed-\(speed)")
            }
        }
        .padding(.horizontal, 4)
        .frame(width: EmperorTheme.panelWidth)
        .frame(height: 36)
        .foregroundStyle(ClassicPalette.gold)
        .background(ClassicPalette.panelBrown)
    }

    private var selectedTaxRatePercent: Int {
        let selectedBandID = library.cityState?.taxBandID ?? 2
        return models.taxSentiment.bands.first {
            $0.id == selectedBandID
        }?.taxRatePercent ?? models.taxSentiment.bands.first?.taxRatePercent ?? 0
    }

    private func commandButton(
        _ symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(ClassicPalette.tileBrown)
                .overlay(Rectangle().strokeBorder(ClassicPalette.border, lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private func constructionInstruction(
    _ tool: NativeConstructionTool,
    orientation: IsometricBuildingOrientation
) -> String {
    switch tool {
    case .inspect:
        return "浏览模式：悬停住宅查看升级条件，点击查看详情"
    case .demolish:
        return "拆除工具：点击或拖动区域拆除建筑、住宅或道路；右键取消"
    case .clearLand:
        return "清理树木：点击或拖动区域清除树木与灌木；右键取消"
    case .road:
        return "道路：点击或拖动铺路，每格造价 2；右键取消"
    case .roadblock:
        return "路障：放在既有道路上；阻止漫游人员，放行采购、运输和移民；右键取消"
    case .rally:
        return "部队集结：先选编队，再点地图下令；右键取消"
    case .house:
        return "住宅：2×2 占地，当前\(orientation.localizedTitle)；点击或拖动连续建造；R 旋转；右键取消"
    case .eliteHouse:
        return "贵族住宅：2×2 占地，从空置贵族宅独立演化；须供应高品质食物、丝绸和奢侈品"
    case .farmland:
        return "作物田：先在农业分类选择具体作物，再点击或拖动清地种植；右键取消"
    case .market:
        return "普通市场：占地 7×4，可容纳 4 间商铺；放置市场后选择具体商铺，再点击市场内部的任意格"
    case .grandMarket:
        return "大市场：占地 7×6，可容纳 6 间商铺；适合供应贵族住宅所需的多种商品"
    case .foodShop, .hempShop, .ceramicsShop, .teaShop, .silkShop,
         .lacquerwareShop, .bronzewareShop:
        return "\(tool.title)：选择后点击仍有空铺位的市场；同类商铺可以重复建造；右键取消"
    case .irrigationPump:
        return "灌溉水车：放在河岸清地，须同时邻接水面与道路；右键取消"
    case .grandCanalSegment:
        return "郑国渠分段：点击地图中任意 4×4 预置渠段推进施工；跨路段完工后保留道路通行"
    case .earthenGreatWallSegment:
        return "土长城分段：点击八达岭山脊中的预置 4×4 墙段推进施工"
    case .largePalacePhase:
        return "大宫殿施工：点击已放置的 12×12 宫殿推进下一夯土、殿身、甬道或入口相位"
    case .phasedMonumentPhase:
        return "陵墓施工：点击已放置的大陵冢或地下兵马俑坑推进下一原版施工相位"
    default:
        guard let buildingID = tool.buildingID,
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: orientation
              ) else {
            return "请选择一项建造工具"
        }
        return "\(tool.title)：占地 \(footprint.width)×\(footprint.height)，须邻接道路"
            + (tool.supportsRotation
                ? "；当前\(orientation.localizedTitle)，R 旋转"
                : "")
            + "；右键取消"
    }
}

private func categoryAccessibilitySlug(_ category: ConstructionToolCategory) -> String {
    switch category {
    case .residential: "residential"
    case .agriculture: "agriculture"
    case .industry: "industry"
    case .commerce: "commerce"
    case .safety: "safety"
    case .government: "government"
    case .entertainment: "entertainment"
    case .religious: "religious"
    case .military: "military"
    case .aesthetics: "aesthetics"
    case .monuments: "monuments"
    }
}

private func classicBaseFocus(_ city: DeterministicCityState) -> GridPoint {
    let center = GridPoint(
        x: city.roadNetwork.width / 2,
        y: city.roadNetwork.height / 2
    )
    return city.roadNetwork.points.min { lhs, rhs in
            let lhsDX = lhs.x - center.x
            let lhsDY = lhs.y - center.y
            let rhsDX = rhs.x - center.x
            let rhsDY = rhs.y - center.y
            let lhsDistance = lhsDX * lhsDX + lhsDY * lhsDY
            let rhsDistance = rhsDX * rhsDX + rhsDY * rhsDY
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.x < rhs.x
        }
        ?? city.houses.compactMap(\.location).first
        ?? city.trade.buildings.first?.roadAccessPoint
        ?? center
}

private struct CitySimulationView: View {
    @ObservedObject var library: LibraryModel
    let models: OriginalEconomyModels
    @State private var cameraOffsetX = 0
    @State private var cameraOffsetY = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.12, blue: 0.10), Color(red: 0.18, green: 0.16, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let city = library.cityState {
                ScrollView {
                    VStack(spacing: 18) {
                        if let campaign = library.selectedCampaign,
                           let missionID = library.selectedMissionID,
                           let mission = campaign.missions.first(where: { $0.id == missionID }) {
                            HStack(spacing: 10) {
                                Image(systemName: "flag.pattern.checkered")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        "\(ClassicTextLocalization.campaignTitle(campaign.title))"
                                            + " · 第 \(mission.sequenceNumber) 关"
                                    )
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(.secondary)
                                    Text(
                                        ClassicTextLocalization.missionTitle(mission.title)
                                            + " · "
                                            + ClassicTextLocalization.cityName(
                                                library.activeMissionWorld?.playerCityName
                                                    ?? "原版任务城市"
                                            )
                                    )
                                        .font(EmperorTheme.headlineMedium)
                                }
                                Spacer()
                                if let world = library.activeMissionWorld {
                                    Label("\(world.tradePartners.count) 条贸易路线", systemImage: "arrow.left.arrow.right")
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(.teal)
                                }
                                if let settings = city.missionSettings {
                                    Label(
                                        "建筑许可 \(settings.allowedBuildingMenuIDs.count)/56",
                                        systemImage: "checklist"
                                    )
                                    .font(EmperorTheme.bodySmall)
                                    .foregroundStyle(.orange)
                                }
                            }
                            .padding(14)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        HStack(spacing: 12) {
                            CityMetricCard(title: "人口", value: "\(city.population) / \(city.housingCapacity(using: models.buildings))", symbol: "person.2.fill")
                            CityMetricCard(title: "住宅", value: "\(city.houses.count)", symbol: "house.fill")
                            CityMetricCard(title: "国库", value: "\(city.economy.treasury)", symbol: "building.columns.fill")
                            CityMetricCard(
                                title: "日期",
                                value: "\(city.calendar.year) · \(city.calendar.month) · \(city.simulationClock.day)",
                                symbol: "calendar"
                            )
                        }

                        MigrationStatusStrip(migration: city.migration)

                        ConstructionToolbar(library: library, city: city)

                        CityCanvas(
                            city: city,
                            buildingSprites: library.buildingSprites,
                            interfaceSprites: library.interfaceSprites,
                            figureSprites: library.figureSprites,
                            originalMap: library.renderedMap,
                            constructionTool: library.constructionTool,
                            agriculturalCrop: library.selectedAgriculturalCrop,
                            constructionOrientation: library.constructionOrientation,
                            models: models,
                            activeResourceOverlays: library.activeResourceOverlays,
                            selectedMilitaryUnitIDs: library.selectedMilitaryUnitIDs,
                            gameSpeed: library.gameSpeed,
                            lastTickPresentationDate: library.lastCityTickPresentationDate,
                            onPlaceConstruction: library.placeConstruction,
                            onPlaceConstructionArea: library.placeConstructions,
                            onCancelInteraction: library.cancelCurrentInteraction,
                            onBuildingSettingChange: library.applyBuildingSetting,
                            cameraOffsetX: $cameraOffsetX,
                            cameraOffsetY: $cameraOffsetY,
                            showsNavigationOverlay: true
                        )
                            .id(library.selectedMap?.url)
                            .frame(minHeight: 330, idealHeight: 380)
                            .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .topLeading) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(library.activeMissionWorld == nil ? "原版建筑精灵" : "原版任务地形与建筑")
                                        .font(EmperorTheme.headlineMedium)
                                    Text(
                                        library.activeMissionWorld == nil
                                            ? "模型状态由 Swift 原生确定性内核驱动"
                                            : "\(city.roadNetwork.width) × \(city.roadNetwork.height) 可玩区域 · 原版道路已进入模拟"
                                    )
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                            }

                        ProductionStatusStrip(
                            production: city.production,
                            logistics: city.logistics,
                            trade: city.trade,
                            models: models
                        )
                        AgricultureStatusStrip(
                            calendar: city.calendar,
                            production: city.production,
                            logistics: city.logistics,
                            models: models
                        )
                        TradeStatusStrip(
                            trade: city.trade,
                            accounting: city.productionAccounting,
                            models: models
                        )
                        MarketStatusStrip(
                            markets: city.markets,
                            houses: city.houses,
                            models: models
                        )
                        HousingEvolutionStatusStrip(
                            houses: city.houses,
                            serviceBuildings: city.residentialServiceBuildings,
                            settlement: city.lastHousingSettlement,
                            models: models
                        )
                        WalkerStatusStrip(walkers: city.walkers, houses: city.houses)
                        if !city.military.units.isEmpty
                            || !city.military.enemyForces.isEmpty
                            || !city.military.defensiveStructures.isEmpty {
                            MilitaryStatusStrip(
                                military: city.military,
                                selectedUnitIDs: library.selectedMilitaryUnitIDs,
                                onSelectAll: library.selectAllMilitaryUnits,
                                onClearSelection: library.clearMilitaryUnitSelection
                            )
                        }
                        if let runtime = library.campaignRuntimeState {
                            CampaignRuntimeStatusStrip(
                                runtime: runtime,
                                latestAdvance: library.latestCampaignAdvance,
                                city: city,
                                models: models,
                                onFulfillRequest: library.fulfillFirstCampaignRequest,
                                onStartNextMission: library.startNextMission
                            )
                            if let empire = runtime.empireState {
                                CampaignEmpireStatusStrip(
                                    empire: empire,
                                    onSendEmissary: library.sendCampaignEmissary,
                                    onSendSpy: library.sendCampaignSpy,
                                    onRequestAlliance: library.requestCampaignAlliance,
                                    onConquer: library.conquerCampaignCity,
                                    onRequestAnimal: library.requestCampaignMenagerieAnimal,
                                    onPrepayHomage: library.prepayCampaignHomage
                                )
                            }
                        }

                        GameControlsView(library: library, city: city, models: models)

                        CitySettlementStrip(settlement: library.latestSettlement)
                    }
                    .padding(24)
                }
                if let runtime = library.campaignRuntimeState,
                   runtime.outcome != .running {
                    MissionOutcomeOverlay(
                        outcome: runtime.outcome,
                        missionTitle: library.selectedCampaign?.missions.first {
                            $0.id == library.selectedMissionID
                        }.map {
                            ClassicTextLocalization.missionTitle($0.title)
                        } ?? "当前任务",
                        onNextMission: library.startNextMission,
                        onReplay: library.replayMission,
                        onLoadRecent: library.loadMostRecentSave,
                        onReturn: library.returnToCampaignList
                    )
                }
            } else {
                ProgressView("正在初始化城市状态…")
            }
        }
    }
}

private struct MissionOutcomeOverlay: View {
    let outcome: CampaignMissionOutcome
    let missionTitle: String
    let onNextMission: () -> Void
    let onReplay: () -> Void
    let onLoadRecent: () -> Void
    let onReturn: () -> Void

    var body: some View {
        ZStack {
            EmperorTheme.overlayScrim.ignoresSafeArea()
            VStack(spacing: 16) {
                switch outcome {
                case .running:
                    EmptyView()
                case let .victory(record):
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(EmperorTheme.success)
                    Text("任务胜利")
                        .font(EmperorTheme.display)
                        .foregroundStyle(EmperorTheme.success)
                        .accessibilityIdentifier("mission-outcome-victory")
                    Text(missionTitle)
                        .font(EmperorTheme.headlineMedium)
                        .foregroundStyle(EmperorTheme.onSurface)
                    Text("达成于 \(record.settlementYear) 年 \(record.month) 月")
                        .font(EmperorTheme.bodyMedium)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    Divider().overlay(EmperorTheme.border)
                    HStack(spacing: 8) {
                        Button("进入下一任务", action: onNextMission)
                            .buttonStyle(EmperorClassicButtonStyle(.primary))
                            .accessibilityIdentifier("mission-outcome-next")
                        Button("重玩本任务", action: onReplay)
                            .buttonStyle(EmperorClassicButtonStyle())
                            .accessibilityIdentifier("mission-outcome-replay")
                        Button("返回战役列表", action: onReturn)
                            .buttonStyle(EmperorClassicButtonStyle())
                            .accessibilityIdentifier("mission-outcome-return")
                    }
                case let .defeat(record):
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(EmperorTheme.error)
                    Text("任务失败")
                        .font(EmperorTheme.display)
                        .foregroundStyle(EmperorTheme.error)
                        .accessibilityIdentifier("mission-outcome-defeat")
                    Text(missionTitle)
                        .font(EmperorTheme.headlineMedium)
                        .foregroundStyle(EmperorTheme.onSurface)
                    Text(defeatDescription(record))
                        .font(EmperorTheme.bodyMedium)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    Divider().overlay(EmperorTheme.border)
                    HStack(spacing: 8) {
                        Button("从最近存档读取", action: onLoadRecent)
                            .buttonStyle(EmperorClassicButtonStyle(.primary))
                            .accessibilityIdentifier("mission-outcome-load-recent")
                        Button("重玩本任务", action: onReplay)
                            .buttonStyle(EmperorClassicButtonStyle())
                            .accessibilityIdentifier("mission-outcome-replay")
                        Button("返回战役列表", action: onReturn)
                            .buttonStyle(EmperorClassicButtonStyle())
                            .accessibilityIdentifier("mission-outcome-return")
                    }
                }
            }
            .padding(24)
            .frame(minWidth: 480, maxWidth: 620)
            .background(EmperorTheme.surfaceRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(EmperorTheme.secondary, lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .inset(by: 4)
                    .strokeBorder(EmperorTheme.primary.opacity(0.28), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.55), radius: 24, y: 10)
        }
    }

    private func defeatDescription(_ record: CampaignDefeatRecord) -> String {
        switch record.reason {
        case let .continuousDebt(months):
            "国库连续 \(months) 个月为负（当前 \(record.treasury)）· \(record.settlementYear) 年 \(record.month) 月"
        }
    }
}
