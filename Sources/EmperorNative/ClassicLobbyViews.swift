import EmperorCore
import SwiftUI

struct ClassicCampaignLobbyView: View {
    @ObservedObject var library: LibraryModel
    let campaigns: [CampaignArchive]
    let economy: OriginalEconomyModels
    @State private var previewMissionID: Int?

    var body: some View {
        VStack(spacing: 0) {
            ClassicLobbyHeader(library: library, activeSection: .campaigns)

            HStack(spacing: 0) {
                campaignPage
                    .frame(width: 330)
                Rectangle()
                    .fill(EmperorTheme.secondary.opacity(0.82))
                    .frame(width: 3)
                    .overlay(Color.black.opacity(0.28).frame(width: 1))
                missionPage
            }
            .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 1))
            .padding(16)

            ClassicLobbyFooter(library: library)
        }
        .background(ClassicLobbyBackground())
        .onAppear(perform: normalizePreviewMission)
        .onChange(of: library.selectedCampaign?.url) { _ in
            normalizePreviewMission()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("classic-campaign-lobby")
    }

    private var campaignPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            ClassicPageHeading(
                eyebrow: "王朝典籍",
                title: "选择战役",
                symbol: "books.vertical.fill"
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(campaigns.enumerated()), id: \.element.id) { index, campaign in
                        Button {
                            library.select(campaign)
                            previewMissionID = campaign.missions.first?.id
                        } label: {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(EmperorTheme.metric)
                                    .foregroundStyle(
                                        library.selectedCampaign?.url == campaign.url
                                            ? EmperorTheme.onPrimary
                                            : EmperorTheme.primary
                                    )
                                    .frame(width: 28, height: 28)
                                    .background(
                                        library.selectedCampaign?.url == campaign.url
                                            ? EmperorTheme.primary
                                            : EmperorTheme.surfaceDeep
                                    )
                                    .overlay(Rectangle().strokeBorder(EmperorTheme.border))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ClassicTextLocalization.campaignTitle(campaign.title))
                                        .font(EmperorTheme.headlineSmall)
                                        .foregroundStyle(
                                            library.selectedCampaign?.url == campaign.url
                                                ? EmperorTheme.onPrimary
                                                : EmperorTheme.onSurface
                                        )
                                        .lineLimit(1)
                                    Text("\(campaign.missions.count) 个任务")
                                        .font(EmperorTheme.caption)
                                        .foregroundStyle(
                                            library.selectedCampaign?.url == campaign.url
                                                ? EmperorTheme.onPrimary.opacity(0.72)
                                                : EmperorTheme.onSurfaceMuted
                                        )
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(EmperorTheme.labelSmall)
                                    .foregroundStyle(
                                        library.selectedCampaign?.url == campaign.url
                                            ? EmperorTheme.onPrimary
                                            : EmperorTheme.primary
                                    )
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                library.selectedCampaign?.url == campaign.url
                                    ? EmperorTheme.primary
                                    : (index.isMultiple(of: 2)
                                        ? EmperorTheme.surface.opacity(0.76)
                                        : EmperorTheme.surfaceDeep.opacity(0.5))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\(ClassicTextLocalization.campaignTitle(campaign.title))，\(campaign.missions.count) 个任务"
                        )
                        .accessibilityIdentifier(campaign.accessibilityIdentifier)
                    }
                }
            }

            HStack {
                Label("\(campaigns.count) 部战役", systemImage: "checkmark.seal.fill")
                Spacer()
                Text("原版资料实时读取")
            }
            .font(EmperorTheme.caption)
            .foregroundStyle(EmperorTheme.onSurfaceMuted)
            .padding(10)
            .background(EmperorTheme.surfaceDeep)
            .overlay(alignment: .top) {
                Rectangle().fill(EmperorTheme.border).frame(height: 1)
            }
        }
        .background(EmperorTheme.surface.opacity(0.96))
    }

    @ViewBuilder
    private var missionPage: some View {
        if let campaign = library.selectedCampaign {
            VStack(alignment: .leading, spacing: 0) {
                ClassicPageHeading(
                    eyebrow: "战役卷宗",
                    title: ClassicTextLocalization.campaignTitle(campaign.title),
                    symbol: "map.fill"
                )

                if let art = ClassicFrontEndArt.campaignIllustration(
                    for: campaign,
                    sourceRoot: library.dataSourceRoot
                ) {
                    Image(nsImage: art)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 168)
                        .clipped()
                        .overlay(alignment: .bottomLeading) {
                            Text(ClassicTextLocalization.campaignSummary(campaign.title))
                                .font(EmperorTheme.bodySmall)
                                .foregroundStyle(EmperorTheme.onSurface)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(EmperorTheme.surfaceDeep.opacity(0.82))
                        }
                        .overlay(Rectangle().strokeBorder(EmperorTheme.border))
                } else {
                    Text(ClassicTextLocalization.campaignSummary(campaign.title))
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(EmperorTheme.surfaceDeep.opacity(0.72))
                }

                missionTimeline(campaign)

                if let mission = previewMission(in: campaign) {
                    missionDetail(mission)
                } else {
                    ClassicEmptyState(
                        title: "没有可用任务",
                        symbol: "map",
                        detail: "此战役没有可供单人游玩的地图任务。"
                    )
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
            }
            .background(EmperorTheme.surface.opacity(0.96))
        } else {
            ClassicEmptyState(
                title: "选择一部战役",
                symbol: "books.vertical",
                detail: "从左侧卷宗中选择一部战役。"
            )
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(EmperorTheme.surface.opacity(0.96))
        }
    }

    private func missionTimeline(_ campaign: CampaignArchive) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(campaign.missions) { mission in
                    Button {
                        previewMissionID = mission.id
                    } label: {
                        VStack(spacing: 5) {
                            Text("\(mission.sequenceNumber)")
                                .font(EmperorTheme.metric)
                                .frame(width: 30, height: 30)
                                .foregroundStyle(
                                    previewMissionID == mission.id
                                        ? EmperorTheme.onPrimary
                                        : EmperorTheme.onSurface
                                )
                                .background(
                                    previewMissionID == mission.id
                                        ? EmperorTheme.primary
                                        : EmperorTheme.surfaceControl
                                )
                                .overlay(Rectangle().strokeBorder(EmperorTheme.border))
                            Text("第 \(mission.sequenceNumber) 关")
                                .font(EmperorTheme.caption)
                                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                        }
                        .frame(width: 66)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    if mission.id != campaign.missions.last?.id {
                        Rectangle()
                            .fill(EmperorTheme.secondary)
                            .frame(width: 18, height: 2)
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .background(EmperorTheme.surfaceDeep.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EmperorTheme.border).frame(height: 1)
        }
    }

    private func missionDetail(_ mission: CampaignMission) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("第 \(mission.sequenceNumber) 关")
                            .font(EmperorTheme.labelMedium)
                            .foregroundStyle(EmperorTheme.primary)
                        Text(ClassicTextLocalization.missionTitle(mission.title))
                            .font(EmperorTheme.display)
                            .foregroundStyle(EmperorTheme.onSurface)
                    }
                    Spacer()
                    missionAvailabilityBadge(mission)
                }

                HStack(spacing: 0) {
                    missionMetric(
                        "年代",
                        value: missionSettings(mission).map {
                            $0.startYear < 0 ? "公元前 \(-$0.startYear) 年" : "公元 \($0.startYear) 年"
                        } ?? "读取中",
                        symbol: "calendar"
                    )
                    missionMetric(
                        "初始国库",
                        value: missionSettings(mission).map {
                            $0.requiresInheritedTreasury ? "继承前关" : $0.initialFunds.formatted()
                        } ?? "读取中",
                        symbol: "banknote.fill"
                    )
                    missionMetric(
                        "城市",
                        value: missionCityName(mission),
                        symbol: "mappin.and.ellipse"
                    )
                }
                .overlay(Rectangle().strokeBorder(EmperorTheme.border))

                VStack(alignment: .leading, spacing: 9) {
                    Label("目标", systemImage: "flag.fill")
                        .font(EmperorTheme.headlineMedium)
                        .foregroundStyle(EmperorTheme.primary)

                    if let goalSet = library.campaignGoalArchive?.missions.first(where: { $0.id == mission.id }) {
                        if goalSet.goals.isEmpty {
                            Label("自由建造任务，没有强制胜利目标", systemImage: "leaf.fill")
                                .font(EmperorTheme.bodyMedium)
                                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                        } else {
                            ForEach(goalSet.goals) { goal in
                                CampaignGoalRow(goal: goal, economy: economy, progress: nil)
                                    .padding(.vertical, 2)
                            }
                        }
                    } else {
                        ProgressView("正在读取原版任务目标…")
                            .controlSize(.small)
                            .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    }

                    Text(ClassicTextLocalization.missionBriefing(mission.title))
                        .font(EmperorTheme.bodyMedium)
                        .foregroundStyle(EmperorTheme.primary.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(14)
                .background(EmperorTheme.surfaceDeep.opacity(0.68))
                .overlay(Rectangle().strokeBorder(EmperorTheme.border))

                if library.campaignMissionMaps?.isMaplessNetworkScenario == true {
                    Label(
                        "这是原版联机剧本，没有唯一的单人玩家地图；当前版本将它保留在资料库中。",
                        systemImage: "person.3.fill"
                    )
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(EmperorTheme.warning)
                }

                HStack(alignment: .center, spacing: 12) {
                    Text("难度等级")
                        .font(EmperorTheme.labelMedium)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    Picker(
                        "难度等级",
                        selection: Binding(
                            get: { library.selectedDifficulty },
                            set: { library.selectedDifficulty = $0 }
                        )
                    ) {
                        ForEach(GameDifficulty.allCases, id: \.self) { difficulty in
                            Text(ClassicTextLocalization.difficultyTitle(difficulty))
                                .tag(difficulty)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("mission-difficulty-picker")

                    Spacer()

                    if let status = library.saveStatus {
                        Text(status)
                            .font(EmperorTheme.bodySmall)
                            .foregroundStyle(EmperorTheme.onSurfaceMuted)
                            .lineLimit(2)
                    }

                    Button {
                        library.startMission(mission)
                    } label: {
                        Label(
                            library.selectedMissionID == mission.id ? "重新开始本关" : "到城市去",
                            systemImage: "play.fill"
                        )
                        .frame(minWidth: 120)
                    }
                    .buttonStyle(EmperorClassicButtonStyle(.primary))
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!canStart(mission))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        library.selectedMissionID == mission.id ? "重新开始本关" : "到城市去"
                    )
                    .accessibilityIdentifier("mission-start-\(mission.id)")
                }
            }
            .padding(18)
        }
    }

    private func missionMetric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(EmperorTheme.caption)
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
            Text(value)
                .font(EmperorTheme.metric)
                .foregroundStyle(EmperorTheme.onSurface)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmperorTheme.surfaceControl.opacity(0.58))
    }

    private func missionAvailabilityBadge(_ mission: CampaignMission) -> some View {
        Label(
            canStart(mission) ? "可开始" : "暂不可用",
            systemImage: canStart(mission) ? "checkmark.circle.fill" : "clock.fill"
        )
        .font(EmperorTheme.labelMedium)
        .foregroundStyle(canStart(mission) ? EmperorTheme.success : EmperorTheme.warning)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(EmperorTheme.surfaceDeep)
        .overlay(Rectangle().strokeBorder(EmperorTheme.border))
    }

    private func normalizePreviewMission() {
        guard let campaign = library.selectedCampaign else {
            previewMissionID = nil
            return
        }
        if !campaign.missions.contains(where: { $0.id == previewMissionID }) {
            previewMissionID = campaign.missions.first?.id
        }
    }

    private func previewMission(in campaign: CampaignArchive) -> CampaignMission? {
        campaign.missions.first { $0.id == previewMissionID } ?? campaign.missions.first
    }

    private func missionSettings(_ mission: CampaignMission) -> CampaignMissionStartSettings? {
        library.campaignMissionSettings?.missions.first { $0.id == mission.id }
    }

    private func missionCityName(_ mission: CampaignMission) -> String {
        guard let assignment = library.campaignMissionMaps?.missions.first(where: { $0.id == mission.id }),
              let empire = library.campaignEmpireMap,
              empire.cities.indices.contains(assignment.playerCityID) else {
            return library.isResolvingCampaignMaps ? "读取中" : "独立城市"
        }
        let city = empire.cities[assignment.playerCityID]
        let name = library.cityNames?[nameID: city.nameID] ?? "城市 \(assignment.playerCityID)"
        return ClassicTextLocalization.cityName(name)
    }

    private func canStart(_ mission: CampaignMission) -> Bool {
        guard mission.isEnabled,
              library.campaignMissionMaps?.isMaplessNetworkScenario != true else { return false }
        return library.campaignMissionMaps?.missions.contains(where: { $0.id == mission.id }) == true
    }
}

struct ClassicSaveHistoryView: View {
    @ObservedObject var library: LibraryModel
    @State private var pendingDeletion: NativeSaveHistoryEntry?
    @State private var showsDeletionConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ClassicLobbyHeader(library: library, activeSection: .saves)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("存档记录")
                            .font(EmperorTheme.display)
                            .foregroundStyle(EmperorTheme.onSurface)
                        Text("每个任务保留最近 24 个自动存档；快速存档不会自动清理。")
                            .font(EmperorTheme.bodySmall)
                            .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    }
                    Spacer()
                    Button("载入外部存档", action: library.loadCity)
                        .buttonStyle(EmperorClassicButtonStyle())
                    Button("刷新", action: library.refreshSaveHistory)
                        .buttonStyle(EmperorClassicButtonStyle())
                }

                if library.saveHistory.isEmpty {
                    ClassicEmptyState(
                        title: "还没有存档",
                        symbol: "archivebox",
                        detail: "进入任务时会立即创建第一份自动存档。"
                    )
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EmperorTheme.surface.opacity(0.9))
                    .overlay(Rectangle().strokeBorder(EmperorTheme.border))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(library.saveHistory) { entry in
                                saveRow(entry)
                            }
                        }
                    }
                    .background(EmperorTheme.surface.opacity(0.92))
                    .overlay(Rectangle().strokeBorder(EmperorTheme.border))
                }
            }
            .padding(18)

            ClassicLobbyFooter(library: library)
        }
        .background(ClassicLobbyBackground())
        .confirmationDialog(
            "删除这份存档？",
            isPresented: $showsDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let pendingDeletion {
                    library.deleteSaveHistoryEntry(pendingDeletion)
                }
                pendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("删除后无法从游戏内恢复。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("classic-save-history")
    }

    private func saveRow(_ entry: NativeSaveHistoryEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.errorDescription == nil ? entry.kind.symbol : "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(entry.errorDescription == nil ? EmperorTheme.primary : EmperorTheme.error)
                .frame(width: 34, height: 34)
                .background(EmperorTheme.surfaceDeep)
                .overlay(Rectangle().strokeBorder(EmperorTheme.border))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(entry.kind.title)
                        .font(EmperorTheme.headlineSmall)
                    Text(entry.savedAt.formatted(date: .abbreviated, time: .standard))
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
                Text(saveDescription(entry))
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(entry.isReadable ? EmperorTheme.onSurfaceMuted : EmperorTheme.error)
                    .lineLimit(1)
            }

            Spacer()

            if entry.isReadable {
                Button("载入") {
                    library.loadSaveHistoryEntry(entry)
                }
                .buttonStyle(EmperorClassicButtonStyle(.primary))
            }
            Button {
                pendingDeletion = entry
                showsDeletionConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(EmperorClassicButtonStyle(.danger))
            .help("删除这份存档")
        }
        .padding(10)
        .background(EmperorTheme.surface.opacity(0.82))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EmperorTheme.border.opacity(0.65)).frame(height: 1)
        }
    }

    private func saveDescription(_ entry: NativeSaveHistoryEntry) -> String {
        if let error = entry.errorDescription {
            return "存档损坏：\(error)"
        }
        let mission = entry.missionIndex.map { "第 \($0 + 1) 关" } ?? "自由城市"
        let date = entry.year.map {
            $0 < 0 ? "公元前 \(-$0) 年" : "公元 \($0) 年"
        } ?? "未知年代"
        let month = entry.month.map { " · \($0) 月" } ?? ""
        let population = entry.population.map { " · 人口 \($0)" } ?? ""
        let treasury = entry.treasury.map { " · 国库 \($0.formatted())" } ?? ""
        return "\(mission) · \(date)\(month)\(population)\(treasury)"
    }
}

struct ClassicLobbyHeader: View {
    @ObservedObject var library: LibraryModel
    let activeSection: LibrarySection

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "seal.fill")
                    .foregroundStyle(EmperorTheme.primary)
                VStack(alignment: .leading, spacing: 0) {
                    Text("皇帝：龙之崛起")
                        .font(EmperorTheme.headlineMedium)
                        .foregroundStyle(EmperorTheme.onSurface)
                    Text("原生引擎")
                        .font(EmperorTheme.caption)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
            }
            .frame(width: 250, alignment: .leading)

            navButton("继续游戏", symbol: "play.fill", section: nil, identifier: "library-continue-game") {
                library.loadMostRecentSave()
            }
            .disabled(!library.saveHistory.contains(where: \.isReadable))
            navButton("战役", symbol: "map.fill", section: .campaigns) {
                library.section = .campaigns
            }
            navButton("存档记录", symbol: "archivebox.fill", section: .saves) {
                library.section = .saves
            }
            navButton("资料库", symbol: "books.vertical.fill", section: .maps) {
                library.section = .maps
            }
            navButton(
                "返回帐号",
                symbol: "person.crop.circle",
                section: nil,
                identifier: "library-return-account"
            ) {
                library.returnToClassicFrontEnd()
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: library.isAutosaving ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                Text(library.isAutosaving ? "正在自动存档" : autosaveLabel)
            }
            .font(EmperorTheme.labelSmall)
            .foregroundStyle(library.isAutosaving ? EmperorTheme.warning : EmperorTheme.success)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(EmperorTheme.surfaceDeep)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EmperorTheme.primary).frame(height: 2)
        }
    }

    private func navButton(
        _ title: String,
        symbol: String,
        section: LibrarySection?,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(EmperorTheme.labelMedium)
                .foregroundStyle(
                    activeSection == section ? EmperorTheme.onPrimary : EmperorTheme.onSurface
                )
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(
                    activeSection == section ? EmperorTheme.primary : Color.clear
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(
            identifier
                ?? section.map { "library-section-\($0.accessibilitySlug)" }
                ?? "library-continue-game"
        )
    }

    private var autosaveLabel: String {
        guard let date = library.lastAutosaveDate else {
            return library.saveHistory.isEmpty ? "自动存档已开启" : "存档记录已就绪"
        }
        return "已保存 \(date.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ClassicPageHeading: View {
    let eyebrow: String
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(EmperorTheme.primary)
                .frame(width: 36, height: 36)
                .background(EmperorTheme.surfaceDeep)
                .overlay(Rectangle().strokeBorder(EmperorTheme.border))
            VStack(alignment: .leading, spacing: 1) {
                Text(eyebrow)
                    .font(EmperorTheme.caption)
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                Text(title)
                    .font(EmperorTheme.headlineLarge)
                    .foregroundStyle(EmperorTheme.onSurface)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmperorTheme.surfaceRaised.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EmperorTheme.border).frame(height: 1)
        }
    }
}

private struct ClassicLobbyFooter: View {
    @ObservedObject var library: LibraryModel

    var body: some View {
        HStack {
            Label("游戏菜单可查看全部快捷键", systemImage: "keyboard")
            Spacer()
            Text("⌘S 快速存档 · ⇧⌘S 另存为 · ⌘O 载入 · P／空格 暂停")
            Spacer()
            Text(library.saveStatus ?? "请选择一部战役，查看任务目标与初始条件。")
                .lineLimit(1)
        }
        .font(EmperorTheme.caption)
        .foregroundStyle(EmperorTheme.onSurfaceMuted)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(EmperorTheme.surfaceDeep)
        .overlay(alignment: .top) {
            Rectangle().fill(EmperorTheme.border).frame(height: 1)
        }
    }
}

struct ClassicLobbyBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [
                        EmperorTheme.surfaceDeep,
                        EmperorTheme.backgroundApp,
                        EmperorTheme.surface
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            for x in stride(from: CGFloat(0), through: size.width, by: 34) {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(
                    line,
                    with: .color(EmperorTheme.secondary.opacity(0.08)),
                    lineWidth: 0.5
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct ClassicEmptyState: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(EmperorTheme.primary)
            Text(title)
                .font(EmperorTheme.headlineLarge)
                .foregroundStyle(EmperorTheme.onSurface)
            Text(detail)
                .font(EmperorTheme.bodySmall)
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
