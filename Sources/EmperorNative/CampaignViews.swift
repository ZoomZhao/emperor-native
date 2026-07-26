import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct CampaignGoalRow: View {
    let goal: CampaignMissionGoal
    let economy: OriginalEconomyModels
    let progress: CampaignGoalProgress?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: goal.kind.systemImage)
                .frame(width: 15)
                .foregroundStyle(EmperorTheme.primary)
            Text(goal.kind.chineseTitle + "：")
                .font(EmperorTheme.labelMedium)
            Text(detail)
                .font(EmperorTheme.bodySmall)
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
            Spacer(minLength: 6)
            if let progress {
                Label(
                    "\(progress.currentValue) / \(progress.requiredValue)",
                    systemImage: progress.isSatisfied ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(EmperorTheme.metric)
                .foregroundStyle(
                    progress.isSatisfied
                        ? EmperorTheme.success
                        : EmperorTheme.onSurfaceMuted
                )
            }
        }
    }

    private var detail: String {
        switch goal.kind {
        case .alliedCities:
            return "结盟城市达到 \(value(at: 1)) 座"
        case .conquer:
            return "征服城市达到 \(value(at: 1)) 座"
        case .homage:
            return "累计进贡要求达到 \(value(at: 1))"
        case .housing:
            let levelCode = value(at: 0)
            let modelName = economy.buildings[houseLevelID: levelCode - 3]
                .map { ClassicTextLocalization.houseName($0.name) }
                ?? "住宅等级 #\(levelCode)"
            return "\(value(at: 1)) 人居住在 \(modelName) 或更高等级住宅"
        case .menagerie:
            return "宫廷珍禽异兽达到 \(value(at: 1)) 种"
        case .monument:
            let buildingID = value(at: 0)
            let name = economy.buildings[buildingID: buildingID]?.name ?? "建筑 #\(buildingID)"
            return "完成 \(ClassicTextLocalization.authoredName(Self.cleanBuildingName(name)))"
        case .population:
            return "城市人口达到 \(value(at: 0))"
        case .tradingPartners:
            return "贸易伙伴达到 \(value(at: 0)) 座城市"
        case .treasury:
            return "国库达到 \(value(at: 0).formatted()) 钱币"
        case .yearlyProduction:
            let commodityID = value(at: 0)
            let commodity = economy.trade[commodityID: commodityID]
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? "商品 #\(commodityID)"
            let internalAmount = value(at: 1)
            let crates = internalAmount.isMultiple(of: 100) ? "\(internalAmount / 100)" : String(format: "%.2f", Double(internalAmount) / 100)
            return "每年生产 \(crates) 箱 \(commodity)"
        case .yearlyProfit:
            return "年贸易利润达到 \(value(at: 0).formatted()) 钱币"
        }
    }

    private func value(at index: Int) -> Int {
        guard goal.values.indices.contains(index) else { return 0 }
        return Int(goal.values[index])
    }

    private static func cleanBuildingName(_ name: String) -> String {
        name.replacingOccurrences(of: "BUILD_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }
}

extension WalkerServiceKind {
    var chineseTitle: String {
        switch self {
        case .inspection: "巡察维修"
        case .constable: "治安巡逻"
        case .tax: "税务覆盖"
        case .water: "供水"
        case .herbalist: "草药师"
        case .acupuncture: "针灸"
        case .music: "音乐"
        case .acrobat: "杂技"
        case .drama: "戏剧"
        case .ancestor: "祖先祭祀"
        case .confucian: "儒家教化"
        case .daoistOrBuddhist: "道教或佛教"
        }
    }

    var marker: String {
        switch self {
        case .inspection: "巡"
        case .constable: "治"
        case .tax: "税"
        case .water: "水"
        case .herbalist: "药"
        case .acupuncture: "针"
        case .music: "乐"
        case .acrobat: "技"
        case .drama: "戏"
        case .ancestor: "祖"
        case .confucian: "儒"
        case .daoistOrBuddhist: "道"
        }
    }
}

extension CampaignGoalKind {
    var chineseTitle: String {
        switch self {
        case .alliedCities: "盟友"
        case .conquer: "征服"
        case .homage: "进贡"
        case .housing: "住宅"
        case .menagerie: "珍禽异兽"
        case .monument: "纪念建筑"
        case .population: "人口"
        case .tradingPartners: "贸易"
        case .treasury: "国库"
        case .yearlyProduction: "年产量"
        case .yearlyProfit: "年利润"
        }
    }

    var systemImage: String {
        switch self {
        case .alliedCities: "person.2.fill"
        case .conquer: "flag.fill"
        case .homage: "gift.fill"
        case .housing: "house.fill"
        case .menagerie: "pawprint.fill"
        case .monument: "building.columns.fill"
        case .population: "person.3.fill"
        case .tradingPartners: "arrow.left.arrow.right"
        case .treasury: "banknote.fill"
        case .yearlyProduction: "shippingbox.fill"
        case .yearlyProfit: "chart.line.uptrend.xyaxis"
        }
    }
}

extension CampaignEventKind {
    var chineseTitle: String {
        switch self {
        case .freeEvent: "事件"
        case .request: "请求"
        case .invasion: "入侵"
        case .earthquake: "地震"
        case .drought: "旱灾"
        case .flood: "洪水"
        case .seaTradeProblem: "海上贸易中断"
        case .landTradeProblem: "陆路贸易中断"
        case .wageIncrease: "工资上涨"
        case .wageDecrease: "工资下降"
        case .demandIncrease: "需求增加"
        case .demandDecrease: "需求减少"
        case .priceIncrease: "买价上涨"
        case .priceDecrease: "买价下降"
        case .sellerPriceIncrease: "卖价上涨"
        case .sellerPriceDecrease: "卖价下降"
        case .favorIncrease: "好感增加"
        case .favorDecrease: "好感下降"
        case .cityStatusChange: "城市状态变化"
        case .message: "消息"
        case .supplyIncrease: "供应增加"
        case .supplyDecrease: "供应减少"
        case .gift: "赠礼"
        case .tributeToPlayer: "收到进贡"
        case .tributeDemand: "进贡要求"
        case .cityMessage: "城市消息"
        case .requestFulfillment: "完成请求"
        case .demandRefusal: "拒绝要求"
        case .strike: "罢工"
        case .heroArrives: "英雄到来"
        case .emissaryStatus40, .emissaryStatus42: "使者状态"
        case .spyStatus41, .spyStatus43: "间谍状态"
        case .rivalArmyAway: "敌军外出"
        case .unused6, .unused11, .unused12, .unused13, .unused27, .unused28,
             .unused35, .unused36, .unused37, .unused38: "保留事件"
        }
    }

    var systemImage: String {
        switch self {
        case .request, .tributeDemand: "scroll.fill"
        case .invasion, .rivalArmyAway: "shield.lefthalf.filled"
        case .earthquake, .drought, .flood: "exclamationmark.triangle.fill"
        case .gift, .tributeToPlayer: "gift.fill"
        case .demandIncrease, .supplyIncrease, .priceIncrease, .sellerPriceIncrease,
             .favorIncrease, .wageIncrease: "arrow.up.right"
        case .demandDecrease, .supplyDecrease, .priceDecrease, .sellerPriceDecrease,
             .favorDecrease, .wageDecrease: "arrow.down.right"
        case .seaTradeProblem, .landTradeProblem: "arrow.left.arrow.right.square"
        case .cityStatusChange: "building.2.fill"
        case .strike: "person.3.fill"
        case .heroArrives: "star.fill"
        default: "envelope.fill"
        }
    }

    var usesProductSelection: Bool {
        switch self {
        case .request, .demandIncrease, .demandDecrease, .priceIncrease, .priceDecrease,
             .sellerPriceIncrease, .sellerPriceDecrease, .supplyIncrease, .supplyDecrease,
             .gift, .tributeToPlayer, .tributeDemand:
            true
        default:
            false
        }
    }
}

struct CampaignEventRow: View {
    let event: CampaignEventRecord
    let economy: OriginalEconomyModels

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: event.kind?.systemImage ?? "questionmark.circle")
                .frame(width: 15)
                .foregroundStyle(EmperorTheme.primary)
            Text(event.kind?.chineseTitle ?? "未知事件 #\(event.kindRawValue)")
                .font(EmperorTheme.labelMedium)
            Text(detail)
                .font(EmperorTheme.bodySmall)
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
        }
    }

    private var detail: String {
        var parts = [scheduleDescription]
        if event.kind?.usesProductSelection == true, let productID = event.product.bounds?.lowerBound {
            let name = economy.trade[commodityID: productID]
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? "对象 #\(productID)"
            parts.append(name)
        }
        if let amount = event.amount.bounds {
            parts.append(amount.lowerBound == amount.upperBound
                ? "数值 \(amount.lowerBound)"
                : "数值 \(amount.lowerBound)–\(amount.upperBound)")
        }
        if event.kind == .request, event.timeAllowed > 0 {
            parts.append("限期 \(event.timeAllowed) 个月")
        }
        return parts.joined(separator: " · ")
    }

    private var scheduleDescription: String {
        if event.triggerMode == .missionComplete { return "任务完成时触发" }
        guard let years = event.year.bounds else { return "触发时间未定" }
        if event.triggerMode == .recurring {
            let interval = years.lowerBound == years.upperBound
                ? "每隔 \(years.lowerBound) 年"
                : "每隔 \(years.lowerBound)–\(years.upperBound) 年"
            return "\(interval) · \(event.monthNumber) 月"
        }
        if years.lowerBound == 0, years.upperBound == 0 { return "当年 \(event.monthNumber) 月" }
        if years.lowerBound == years.upperBound { return "第 +\(years.lowerBound) 年 \(event.monthNumber) 月" }
        return "第 +\(years.lowerBound) 至 +\(years.upperBound) 年 · \(event.monthNumber) 月"
    }
}

struct CampaignDiagnosticView: View {
    let campaign: CampaignArchive?
    let embeddedMaps: [EmbeddedCampaignMap]
    let isResolvingMaps: Bool
    let missionMaps: CampaignMissionMapArchive?
    let missionSettings: CampaignMissionSettingsArchive?
    let isResolvingSettings: Bool
    let goalArchive: CampaignGoalArchive?
    let isResolvingGoals: Bool
    let eventArchive: CampaignEventArchive?
    let isResolvingEvents: Bool
    let empireMap: CampaignEmpireMap?
    let isResolvingEmpire: Bool
    let cityNames: OriginalCityNameCatalog?
    let economy: OriginalEconomyModels
    let city: DeterministicCityState?
    let campaignRuntime: CampaignMissionRuntimeState?
    let activeMissionID: Int?
    let onStartMission: (CampaignMission) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [EmperorTheme.backgroundApp, EmperorTheme.surfaceDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let campaign {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(ClassicTextLocalization.campaignTitle(campaign.title))
                            .font(EmperorTheme.display)
                            .foregroundStyle(EmperorTheme.primary)
                        if !campaign.campaignDescription.isEmpty {
                            Text(ClassicTextLocalization.campaignSummary(campaign.title))
                                .font(EmperorTheme.bodyMedium)
                                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                                .lineSpacing(4)
                        }
                        Divider().overlay(EmperorTheme.border)
                        Text("任务")
                            .font(EmperorTheme.headlineLarge)
                            .foregroundStyle(EmperorTheme.primary)
                        ForEach(campaign.missions) { mission in
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(mission.sequenceNumber)")
                                    .font(EmperorTheme.metric)
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(EmperorTheme.onPrimary)
                                    .background(
                                        activeMissionID == mission.id
                                            ? EmperorTheme.primary
                                            : EmperorTheme.secondary,
                                        in: Circle()
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ClassicTextLocalization.missionTitle(mission.title))
                                        .font(EmperorTheme.headlineMedium)
                                    Text(mission.isEnabled ? "可用任务" : "锁定任务")
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(.secondary)
                                    if let settings = missionSettings?.missions.first(where: { $0.id == mission.id }) {
                                        let year = settings.startYear < 0
                                            ? "公元前 \(-settings.startYear) 年"
                                            : "公元 \(settings.startYear) 年"
                                        HStack(spacing: 8) {
                                            Label(year, systemImage: "calendar")
                                            Text("国库 \(settings.initialFunds)")
                                            Text("建筑 \(settings.allowedBuildingMenuIDs.count) · 资源 \(settings.allowedResourceCommodityIDs.count)")
                                        }
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(EmperorTheme.primary)
                                    } else if isResolvingSettings {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    if let assignment = missionMaps?.missions.first(where: { $0.id == mission.id }) {
                                        VStack(alignment: .leading, spacing: 7) {
                                            HStack(spacing: 5) {
                                                Image(systemName: "map.fill")
                                                Text(
                                                    ClassicTextLocalization.mapName(
                                                        assignment.embeddedMap.mapURL
                                                    )
                                                )
                                                if assignment.isContinuation {
                                                    Text("· 延续任务 \(assignment.sourceMissionIndex + 1)")
                                                }
                                            }
                                            .font(EmperorTheme.bodySmall)
                                            .foregroundStyle(EmperorTheme.primary)
                                            HStack(spacing: 8) {
                                                if let empireMap,
                                                   empireMap.cities.indices.contains(
                                                    assignment.playerCityID
                                                   ) {
                                                    let playerCity = empireMap.cities[
                                                        assignment.playerCityID
                                                    ]
                                                    Label(
                                                        ClassicTextLocalization.cityName(
                                                            cityNames?[nameID: playerCity.nameID]
                                                                ?? "城市 #\(playerCity.nameID)"
                                                        ),
                                                        systemImage: "mappin.and.ellipse"
                                                    )
                                                    Text("玩家城市槽位 \(assignment.playerCityID)")
                                                        .foregroundStyle(.tertiary)
                                                } else {
                                                    Label("独立城市任务", systemImage: "house.and.flag")
                                                    Text("无帝国地图")
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                            .font(EmperorTheme.bodySmall)
                                            Button {
                                                onStartMission(mission)
                                            } label: {
                                                Label(
                                                    activeMissionID == mission.id ? "重新开始此任务" : "开始此任务",
                                                    systemImage: activeMissionID == mission.id
                                                        ? "arrow.counterclockwise" : "play.fill"
                                                )
                                            }
                                            .buttonStyle(EmperorClassicButtonStyle(.primary))
                                            .accessibilityIdentifier("mission-start-\(mission.id)")
                                        }
                                    } else if missionMaps?.isMaplessNetworkScenario == true {
                                        Label(
                                            "联机剧本：原包未指定唯一玩家城市地图",
                                            systemImage: "person.3.fill"
                                        )
                                        .font(EmperorTheme.bodySmall)
                                        .foregroundStyle(EmperorTheme.warning)
                                    }
                                    if let goalSet = goalArchive?.missions.first(where: { $0.id == mission.id }) {
                                        if goalSet.goals.isEmpty {
                                            Text("自由建造，无胜利目标")
                                                .font(EmperorTheme.bodySmall)
                                                .foregroundStyle(.tertiary)
                                        } else {
                                            VStack(alignment: .leading, spacing: 6) {
                                                ForEach(goalSet.goals) { goal in
                                                    CampaignGoalRow(
                                                        goal: goal,
                                                        economy: economy,
                                                        progress: city.map {
                                                            CampaignGoalEvaluator.evaluate(
                                                                goal,
                                                                against: $0.campaignGoalProgressSnapshot(
                                                                    alliedCityCount: activeMissionID == mission.id
                                                                        ? campaignRuntime?.empireState?.alliedCityCount ?? 0
                                                                        : 0,
                                                                    conqueredCityCount: activeMissionID == mission.id
                                                                        ? campaignRuntime?.empireState?.conqueredCityCount ?? 0
                                                                        : 0,
                                                                    homageProgress: activeMissionID == mission.id
                                                                        ? campaignRuntime?.empireState?.homageProgress ?? 0
                                                                        : 0,
                                                                    menagerieSpeciesCount: activeMissionID == mission.id
                                                                        ? campaignRuntime?.menagerieAnimalIDs.count ?? 0
                                                                        : 0
                                                                )
                                                            )
                                                        }
                                                    )
                                                }
                                            }
                                            .padding(.top, 5)
                                            if let city,
                                               CampaignGoalEvaluator.missionIsComplete(
                                                goalSet,
                                                against: city.campaignGoalProgressSnapshot(
                                                    alliedCityCount: activeMissionID == mission.id
                                                        ? campaignRuntime?.empireState?.alliedCityCount ?? 0
                                                        : 0,
                                                    conqueredCityCount: activeMissionID == mission.id
                                                        ? campaignRuntime?.empireState?.conqueredCityCount ?? 0
                                                        : 0,
                                                    homageProgress: activeMissionID == mission.id
                                                        ? campaignRuntime?.empireState?.homageProgress ?? 0
                                                        : 0,
                                                    menagerieSpeciesCount: activeMissionID == mission.id
                                                        ? campaignRuntime?.menagerieAnimalIDs.count ?? 0
                                                        : 0
                                                )
                                               ) {
                                                Label("当前实验城已满足全部目标", systemImage: "checkmark.seal.fill")
                                                    .font(EmperorTheme.labelMedium)
                                                    .foregroundStyle(EmperorTheme.success)
                                            }
                                        }
                                    } else if isResolvingGoals {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.top, 4)
                                    }
                                    if let eventSet = eventArchive?.missions.first(where: { $0.id == mission.id }) {
                                        if !eventSet.events.isEmpty {
                                            DisclosureGroup("原版事件（\(eventSet.events.count)）") {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ForEach(eventSet.events) { event in
                                                        CampaignEventRow(event: event, economy: economy)
                                                    }
                                                }
                                                .padding(.top, 6)
                                            }
                                            .font(EmperorTheme.labelMedium)
                                            .padding(.top, 5)
                                        }
                                    } else if isResolvingEvents {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            .padding(12)
                            .emperorNativeCard()
                        }
                        Divider().overlay(EmperorTheme.border)
                        Text("帝国与贸易")
                            .font(EmperorTheme.headlineLarge)
                            .foregroundStyle(EmperorTheme.primary)
                        if isResolvingEmpire {
                            ProgressView("正在解析原版帝国地图…")
                        } else if let empireMap {
                            HStack(spacing: 16) {
                                Label("活动城市 \(empireMap.activeCities.count)", systemImage: "building.2")
                                Label("贸易城市 \(empireMap.tradingCities.count)", systemImage: "arrow.left.arrow.right")
                                Text("归档 0x\(String(empireMap.decodedOffset, radix: 16))")
                            }
                            .font(EmperorTheme.bodySmall)
                            .foregroundStyle(.secondary)
                            ForEach(empireMap.activeCities) { empireCity in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(
                                            ClassicTextLocalization.cityName(
                                                cityNames?[nameID: empireCity.nameID]
                                                    ?? "城市 #\(empireCity.nameID)"
                                            )
                                        )
                                            .font(EmperorTheme.headlineMedium)
                                        Spacer()
                                        Text(routeName(for: empireCity))
                                            .font(EmperorTheme.labelMedium)
                                            .foregroundStyle(EmperorTheme.primary)
                                    }
                                    if empireCity.demandCommodityIDs.isEmpty && empireCity.supplyCommodityIDs.isEmpty {
                                        Text("没有初始贸易商品")
                                            .font(EmperorTheme.bodySmall)
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        Text("收购：\(tradeDescription(empireCity.demandCommodityIDs, city: empireCity))")
                                        Text("出售：\(tradeDescription(empireCity.supplyCommodityIDs, city: empireCity))")
                                    }
                                }
                                .font(EmperorTheme.bodySmall)
                                .padding(12)
                                .emperorNativeCard()
                            }
                        } else {
                            Text("这个旧版/自制战役没有嵌入帝国地图。")
                                .foregroundStyle(.secondary)
                        }
                        Divider().overlay(EmperorTheme.border)
                        Text("场景地图")
                            .font(EmperorTheme.headlineLarge)
                            .foregroundStyle(EmperorTheme.primary)
                        if isResolvingMaps {
                            ProgressView("正在匹配原版地图…")
                        } else if embeddedMaps.isEmpty {
                            Text(missionMaps?.isMaplessNetworkScenario == true
                                ? "这是原版联机剧本；地图由联机大厅按玩家城市选择，包内没有唯一单机地图。"
                                : "该战役没有可解析的城市地图引用。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(embeddedMaps) { map in
                                HStack(spacing: 12) {
                                    Image(systemName: "map")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ClassicTextLocalization.mapName(map.mapURL))
                                            .font(EmperorTheme.headlineMedium)
                                        Text(map.isEmbedded
                                            ? "战役数据块 \(map.campaignChunkRange.lowerBound)–\(map.campaignChunkRange.upperBound - 1)"
                                            : "Campaign Creator 外部地图引用")
                                            .font(EmperorTheme.bodySmall)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(36)
                    .foregroundStyle(EmperorTheme.onSurface)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "scroll")
                        .font(.system(size: 36))
                    Text("没有战役")
                        .font(EmperorTheme.headlineMedium)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func routeName(for city: CampaignEmpireCity) -> String {
        switch city.routeKind(using: economy.trade) {
        case .land: "陆路"
        case .sea: "海路"
        case nil: "间隔 \(city.tradeVisitInterval)"
        }
    }

    private func tradeDescription(_ commodityIDs: [Int], city: CampaignEmpireCity) -> String {
        guard !commodityIDs.isEmpty else { return "—" }
        return commodityIDs.map { commodityID in
            let name = economy.trade[commodityID: commodityID]
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? "#\(commodityID)"
            let loads = city.annualLoadsByCommodityID[commodityID, default: 0]
            return "\(name) \(loads)车/年"
        }.joined(separator: "、")
    }
}

struct MapDiagnosticView: View {
    let probe: MapProbe?
    let rendered: RenderedMap?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.12, blue: 0.11), Color(red: 0.15, green: 0.19, blue: 0.15)], startPoint: .top, endPoint: .bottom)
            if let rendered {
                Canvas { context, size in
                    let columns = min(rendered.map.width, 32)
                    let rows = min(rendered.map.height, 32)
                    let startX = max(0, (rendered.map.width - columns) / 2)
                    let startY = max(0, (rendered.map.height - rows) / 2)
                    let tileWidth = min(28.0, size.width / Double(columns + rows) * 1.9)
                    let tileHeight = tileWidth * 0.5
                    let origin = CGPoint(x: size.width * 0.5, y: max(70, size.height * 0.18))
                    for diagonal in 0..<(columns + rows - 1) {
                        for row in 0..<rows {
                            let column = diagonal - row
                            guard column >= 0, column < columns else { continue }
                            let center = CGPoint(
                                x: origin.x + Double(column - row) * tileWidth * 0.5,
                                y: origin.y + Double(column + row) * tileHeight * 0.5
                            )
                            let mapX = startX + column
                            let mapY = startY + row
                            if let sprite = rendered.sprite(x: mapX, y: mapY) {
                                let scale = tileWidth / 80
                                let drawWidth = Double(sprite.width) * scale
                                let drawHeight = Double(sprite.height) * scale
                                context.draw(
                                    Image(decorative: sprite.image, scale: 1),
                                    in: CGRect(
                                        x: center.x - drawWidth * 0.5,
                                        y: center.y + tileHeight * 0.5 - drawHeight,
                                        width: drawWidth,
                                        height: drawHeight
                                    )
                                )
                            } else {
                                var diamond = Path()
                                diamond.move(to: CGPoint(x: center.x, y: center.y - tileHeight * 0.5))
                                diamond.addLine(to: CGPoint(x: center.x + tileWidth * 0.5, y: center.y))
                                diamond.addLine(to: CGPoint(x: center.x, y: center.y + tileHeight * 0.5))
                                diamond.addLine(to: CGPoint(x: center.x - tileWidth * 0.5, y: center.y))
                                diamond.closeSubpath()
                                context.fill(diamond, with: .color(Color(red: 0.12, green: 0.15, blue: 0.13)))
                            }
                        }
                    }
                }
                VStack {
                    Spacer()
                    Text("原版地图原生预览")
                        .font(EmperorTheme.headlineMedium)
                    Text("读取真实 228×228 图像网格，并合成地形、高差、长城与运河图层。")
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            } else if probe != nil {
                ProgressView("正在解码地图地形…")
            }
        }
    }
}
